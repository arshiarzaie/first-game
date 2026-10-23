import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'components/energy_orb.dart';
import 'components/obstacle.dart';
import 'components/soul_player.dart';
import 'components/track_scene.dart';
import 'config/game_config.dart';
import 'presentation/chroma_key.dart';
import 'systems/difficulty_manager.dart';
import 'systems/lane_system.dart';
import 'systems/obstacle_spawner.dart';
import 'systems/score_manager.dart';

/// Flame game root for SOUL: DUSK RUN (Phase 1 greybox).
///
/// Owns the run state (elapsed time, travelled distance, score), spawns fair
/// obstacle waves from a seeded generator, projects world depth to screen
/// space (the 2.5D illusion), and bridges to Flutter overlays for Game Over
/// and Pause. The player runs in place; the world moves towards them.
class SoulDuskRunGame extends FlameGame with HasCollisionDetection {
  SoulDuskRunGame({int seed = 0, this.selectedWorld = GameWorld.duskHollow})
      : _seed = seed;

  /// The selected world (S4): selects backdrop asset, painted-horizon
  /// anchor and track palette. Gameplay numbers are world-agnostic.
  final GameWorld selectedWorld;

  /// Overlay identifiers used in the GameWidget's overlayBuilderMap.
  static const String gameOverOverlayId = 'gameOver';
  static const String pauseOverlayId = 'pauseMenu';

  final int _seed;

  // Pure-Dart gameplay systems (unit-tested in isolation).
  final LaneSystem laneSystem = LaneSystem();
  final DifficultyManager difficulty = const DifficultyManager();
  final ScoreManager score = ScoreManager();

  late SeededObstacleGenerator _generator;
  late final SoulPlayer player;
  late final TextComponent _hudText;

  // P2 visual slice: pre-rendered production art, decoded once at load.
  // Either may remain null (e.g. asset missing in a test environment);
  // components fall back to their canvas placeholders so the scene never
  // renders blank.
  ui.Image? soulSprite;
  /// Decoded backdrop of the selected world (null until preloaded /
  /// when the asset is unavailable — TrackScene falls back to canvas).
  ui.Image? worldBackdrop;

  // P3B: approved 8-frame run cycle (pre-keyed RGBA plates). Empty when
  // frames could not be decoded — the player then falls back to the
  // single hero sprite, then to the canvas placeholder.
  List<ui.Image> runFrames = const [];

  double _elapsedSeconds = 0;
  double _travelled = 0;
  double _distanceSinceWave = 0;
  double _distanceToNextWave = GameConfig.firstWaveDistance;
  bool _ended = false;
  int _runNumber = 0;

  /// P4 start gate: the scene is alive with Soul standing still until the
  /// player's first tap. Time, score, spawning and difficulty must NOT
  /// advance while awaiting the first input (mandatory start behavior).
  bool _runStarted = false;

  double get elapsedSeconds => _elapsedSeconds;
  double get travelled => _travelled;
  bool get isEnded => _ended;
  bool get isRunStarted => _runStarted;
  double get currentSpeed =>
      _runStarted ? difficulty.speedAt(_elapsedSeconds) : 0;

  // ---------------------------------------------------------------
  // 2.5D projection helpers (shared by the scene and all entities).
  // Depth 1 = horizon, depth 0 = player plane.
  // ---------------------------------------------------------------

  double get horizonY => size.y * GameConfig.horizonRatio;
  double get playerPlaneY => size.y * GameConfig.playerPlaneRatio;

  /// Eased approach factor: 0 at the horizon, 1 at the player plane.
  double _approach(double depth) {
    final linear = (1.0 - depth).clamp(0.0, 1.0).toDouble();
    return math.pow(linear, GameConfig.perspectiveExponent).toDouble();
  }

  /// Screen-space Y for a world depth.
  double yForDepth(double depth) =>
      horizonY + (playerPlaneY - horizonY) * _approach(depth);

  /// Track half-width in px at a depth.
  double halfWidthForDepth(double depth) {
    final top = size.x * GameConfig.trackTopHalfWidthRatio;
    final bottom = size.x * GameConfig.trackBottomHalfWidthRatio;
    return top + (bottom - top) * _approach(depth);
  }

  /// Screen-space X of a lane center at a depth. [lane] may be fractional
  /// during lane switches.
  double laneXForDepth(double lane, double depth) {
    final center = (GameConfig.laneCount - 1) / 2;
    final offset = lane - center;
    return size.x / 2 +
        offset * halfWidthForDepth(depth) * GameConfig.laneSpreadRatio;
  }

  /// Lane-center X on the player plane (used by the player itself).
  double laneXOnPlayerPlane(double lane) => laneXForDepth(lane, 0);

  /// Visual scale for entities at a depth (gentler easing than the
  /// vertical motion so far objects don't shrink too aggressively).
  double scaleForDepth(double depth) {
    final linear = (1.0 - depth).clamp(0.0, 1.0).toDouble();
    final eased = math.pow(linear, GameConfig.scaleExponent).toDouble();
    return GameConfig.farScale + (1 - GameConfig.farScale) * eased;
  }

  // --------------------------------------------------------------- lifecycle

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _generator = SeededObstacleGenerator(seed: _seed);

    // Components attach immediately so the scene is interactive at once;
    // production art decodes in the background and the components pick it
    // up on a later frame (they re-check the game fields every render).
    unawaited(_preloadArt());

    add(TrackScene());
    player = SoulPlayer();
    add(player);

    _hudText = TextComponent(
      text: _hudString,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFF6E7C8),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Color(0xB3000000),
              blurRadius: 8,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
      position: Vector2(16, 48),
      priority: 1000,
    );
    add(_hudText);
  }

  /// Background decode of the P2 slice art. Fields stay null until
  /// decoded; any failure leaves the Canvas placeholders active.
  Future<void> _preloadArt() async {
    try {
      worldBackdrop = await images.load(GameConfig.backdropKeyFor(world));
    } catch (error) {
      debugPrint('P2 art: world backdrop unavailable ($error). '
          'Using canvas placeholder.');
      worldBackdrop = null;
    }
    try {
      soulSprite = await loadKeyedSprite(GameConfig.soulSpriteAsset);
    } catch (error) {
      debugPrint('P2 art: Soul sprite unavailable ($error). '
          'Using canvas placeholder.');
      soulSprite = null;
    }
    try {
      final loaded = <ui.Image>[];
      for (var i = 1; i <= GameConfig.runFrameCount; i++) {
        final index = i.toString().padLeft(2, '0');
        loaded.add(await images.load('${GameConfig.runFramesPrefix}$index.png'));
      }
      runFrames = loaded;
    } catch (error) {
      debugPrint('P3B art: run-cycle frames unavailable ($error). '
          'Using static hero sprite / placeholder.');
      runFrames = const [];
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_ended || !_runStarted) {
      return;
    }

    _elapsedSeconds += dt;
    final ds = currentSpeed * dt;
    _travelled += ds;
    _distanceSinceWave += ds;

    if (_distanceSinceWave >= _distanceToNextWave) {
      _spawnWave();
    }

    score.addDistance(ds);
    _hudText.text = _hudString;
  }

  String get _hudString => _runStarted
      ? 'Score: ${score.totalScore}   Orbs: ${score.orbsCollected}'
      : 'TAP TO RUN';

  // --------------------------------------------------------------- gameplay

  /// First-input start. Transitions Soul from standing idle to running and
  /// activates gameplay exactly once. Subsequent calls are no-ops, so the
  /// starting tap can never double-start or restart the run. The starting
  /// input is intentionally NOT a lane move (handled at the gesture layer).
  void startRun() {
    if (_runStarted || _ended || paused) {
      return;
    }
    _runStarted = true;
    _hudText.text = _hudString;
  }

  /// Lane-move intent from the gesture layer. [direction] < 0 = left,
  /// [direction] > 0 = right. Ignored before the run starts (the first
  /// input starts the run; it must not move lanes).
  void moveLane(int direction) {
    if (_ended || paused || !_runStarted) {
      return;
    }
    if (direction < 0) {
      laneSystem.moveLeft();
    } else if (direction > 0) {
      laneSystem.moveRight();
    }
  }

  void onPlayerHit() {
    if (_ended) {
      return;
    }
    _ended = true;
    pauseEngine();
    overlays.add(gameOverOverlayId);
  }

  void onOrbCollected() {
    if (!_ended) {
      score.addOrb();
    }
  }

  void _spawnWave() {
    final wave = _generator.nextWave(
      speed: currentSpeed,
      difficulty: difficulty.levelAt(_elapsedSeconds),
    );
    _distanceSinceWave = 0;
    _distanceToNextWave = wave.distanceToNext;

    for (final lane in wave.blockedLanes) {
      add(Obstacle(lane: lane));
    }
    final orbLane = wave.orbLane;
    if (orbLane != null) {
      add(EnergyOrb(lane: orbLane));
    }
  }

  // --------------------------------------------------------------- pause

  void pauseWithMenu() {
    if (_ended || paused) {
      return;
    }
    pauseEngine();
    overlays.add(pauseOverlayId);
  }

  void resumeFromMenu() {
    overlays.remove(pauseOverlayId);
    if (!_ended && paused) {
      resumeEngine();
    }
  }

  /// Called by the app-lifecycle observer. Safe to call repeatedly and in
  /// any state (ignored while the Game Over overlay is already up).
  void pauseByLifecycle() => pauseWithMenu();

  // --------------------------------------------------------------- replay

  /// Restarts the run (PLAY AGAIN).
  void resetRun() {
    _runNumber += 1;
    _generator = SeededObstacleGenerator(seed: _seed + _runNumber);

    for (final obstacle in children.whereType<Obstacle>().toList()) {
      obstacle.removeFromParent();
    }
    for (final orb in children.whereType<EnergyOrb>().toList()) {
      orb.removeFromParent();
    }

    laneSystem.reset();
    score.reset();
    player.reset();

    _elapsedSeconds = 0;
    _travelled = 0;
    _distanceSinceWave = 0;
    _distanceToNextWave = GameConfig.firstWaveDistance;
    _ended = false;
    // Replay returns to the standing-idle state: the next run also begins
    // with a deliberate tap (same start contract as a fresh session).
    _runStarted = false;

    overlays.remove(gameOverOverlayId);
    overlays.remove(pauseOverlayId);
    if (paused) {
      resumeEngine();
    }

    _hudText.text = _hudString;
  }
}
