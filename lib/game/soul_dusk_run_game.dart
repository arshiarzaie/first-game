import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'components/energy_orb.dart';
import 'components/obstacle.dart';
import 'components/power_up_pickup.dart';
import 'components/soul_player.dart';
import 'components/track_scene.dart';
import 'components/vfx_burst.dart';
import 'config/game_config.dart';
import 'presentation/chroma_key.dart';
import 'systems/difficulty_manager.dart';
import 'systems/lane_system.dart';
import 'systems/obstacle_spawner.dart';
import 'systems/power_up_system.dart';
import 'systems/progress_store.dart';
import 'systems/score_manager.dart';
import 'systems/vertical_motion.dart';

/// Flame game root for SOUL: DUSK RUN (S12 Subway-tier runner).
///
/// Owns run state, 4-way movement (lane switch + parabolic jump + tuck-slide
/// + mid-air fast-fall), seeded multi-archetype obstacle waves, flowing
/// sun-orb trails & jump arcs, Subway-style power-ups + Solar Aegis crash
/// shield, and shared 2.5D world-to-screen projection.
class SoulDuskRunGame extends FlameGame {
  SoulDuskRunGame({int seed = 0, this.selectedWorld = GameWorld.duskHollow})
      : _seed = seed;

  final GameWorld selectedWorld;

  static const String gameOverOverlayId = 'gameOver';
  static const String pauseOverlayId = 'pauseMenu';

  final int _seed;

  // Pure-Dart gameplay systems (unit-tested in isolation).
  final LaneSystem laneSystem = LaneSystem();
  final VerticalMotion verticalMotion = VerticalMotion();
  final PowerUpSystem powerUps = PowerUpSystem();
  final DifficultyManager difficulty = const DifficultyManager();
  final ScoreManager score = ScoreManager();

  /// Notifies the Flutter HUD layer whenever score, orbs, run-start, or
  /// power-up timers update.
  final ValueNotifier<int> hudTick = ValueNotifier<int>(0);

  late SeededObstacleGenerator _generator;
  late final SoulPlayer player;

  // Pre-decoded production art assets (null until loaded; components render
  // crisp canvas fallbacks whenever an asset is unavailable).
  ui.Image? soulSprite;
  ui.Image? worldBackdrop;
  ui.Image? trackStrip;
  ui.Image? corridorPillar;
  ui.Image? orbSprite;
  ui.Image? obstacleSprite;
  ui.Image? obstacleArchSprite;
  ui.Image? obstacleMonolithSprite;
  List<ui.Image> runFrames = const [];

  double _elapsedSeconds = 0;
  double _travelled = 0;
  double _distanceSinceWave = 0;
  double _distanceToNextWave = GameConfig.firstWaveDistance;
  double _dashOrbTimer = 0;
  double _hudNotifyTimer = 0;
  bool _ended = false;
  int _runNumber = 0;
  bool _runStarted = false;

  ProgressStore? _progress;

  double get elapsedSeconds => _elapsedSeconds;
  double get travelled => _travelled;
  bool get isEnded => _ended;
  bool get isRunStarted => _runStarted;

  double get currentSpeed {
    if (!_runStarted) {
      return 0;
    }
    final base = difficulty.speedAt(_elapsedSeconds);
    return powerUps.isSolarDashing
        ? base * GameConfig.solarDashSpeedBoost
        : base;
  }

  /// Normalized vertical elevation of Soul in `[0, 1]` (accounts for both
  /// jumps and airborne Sunburst Sky-Dash).
  double get effectivePlayerElevation =>
      powerUps.isSolarDashing ? 0.92 : verticalMotion.jumpHeight;

  // ---------------------------------------------------------------
  // 2.5D projection helpers (shared by the scene and all entities).
  // Depth 1 = horizon, depth 0 = player plane, depth < 0 = foreground
  // passing the camera towards the bottom screen edge.
  // ---------------------------------------------------------------

  double get horizonY => size.y * GameConfig.horizonRatio;
  double get playerPlaneY => size.y * GameConfig.playerPlaneRatio;

  double _approach(double depth) {
    final linear = (1.0 - depth).clamp(0.0, 1.35).toDouble();
    return math.pow(linear, GameConfig.perspectiveExponent).toDouble();
  }

  double yForDepth(double depth) =>
      horizonY + (playerPlaneY - horizonY) * _approach(depth);

  double halfWidthForDepth(double depth) {
    final top = size.x * GameConfig.trackTopHalfWidthRatio;
    final bottom = size.x * GameConfig.trackBottomHalfWidthRatio;
    return top + (bottom - top) * _approach(depth);
  }

  double laneXForDepth(double lane, double depth) {
    final center = (GameConfig.laneCount - 1) / 2;
    final offset = lane - center;
    return size.x / 2 +
        offset * halfWidthForDepth(depth) * GameConfig.laneSpreadRatio;
  }

  double laneXOnPlayerPlane(double lane) => laneXForDepth(lane, 0);

  double scaleForDepth(double depth) {
    final linear = (1.0 - depth).clamp(0.0, 1.35).toDouble();
    final eased = math.pow(linear, GameConfig.scaleExponent).toDouble();
    return GameConfig.farScale + (1 - GameConfig.farScale) * eased;
  }

  // --------------------------------------------------------------- lifecycle

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _generator = SeededObstacleGenerator(seed: _seed);
    unawaited(ProgressStore.load().then((store) => _progress = store));
    unawaited(_preloadArt());

    add(TrackScene());
    player = SoulPlayer();
    add(player);
  }

  Future<ui.Image?> _tryLoadImage(String key, String label) async {
    try {
      return await images.load(key);
    } catch (error) {
      debugPrint('$label unavailable ($error). Using canvas fallback.');
      return null;
    }
  }

  Future<void> _preloadArt() async {
    worldBackdrop = await _tryLoadImage(
      GameConfig.backdropKeyFor(selectedWorld),
      'World backdrop',
    );
    try {
      soulSprite = await loadKeyedSprite(GameConfig.soulSpriteAsset);
    } catch (error) {
      debugPrint('Soul sprite unavailable ($error). Using fallback.');
      soulSprite = null;
    }
    final trackKey = GameConfig.trackStripKeyFor(selectedWorld);
    trackStrip = trackKey == null
        ? null
        : await _tryLoadImage(trackKey, 'Track strip');
    corridorPillar = await _tryLoadImage(
      GameConfig.corridorPillarKeyFor(selectedWorld),
      'Corridor pillar',
    );
    obstacleSprite =
        await _tryLoadImage(GameConfig.obstacleSpriteAsset, 'Low spikes');
    obstacleArchSprite = await _tryLoadImage(
      GameConfig.obstacleArchSpriteAsset,
      'High arch obstacle',
    );
    obstacleMonolithSprite = await _tryLoadImage(
      GameConfig.obstacleMonolithSpriteAsset,
      'Tall monolith obstacle',
    );
    orbSprite = await _tryLoadImage(GameConfig.orbSpriteAsset, 'Energy orb');

    try {
      final loaded = <ui.Image>[];
      for (var i = 1; i <= GameConfig.runFrameCount; i++) {
        final index = i.toString().padLeft(2, '0');
        loaded.add(
          await images.load('${GameConfig.runFramesPrefix}$index.png'),
        );
      }
      runFrames = loaded;
    } catch (error) {
      debugPrint('Run-cycle frames unavailable ($error). Using fallback.');
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
    verticalMotion.update(dt);
    powerUps.update(dt);

    final ds = currentSpeed * dt;
    _travelled += ds;
    _distanceSinceWave += ds;

    if (powerUps.isSolarDashing) {
      _dashOrbTimer += dt;
      if (_dashOrbTimer >= 0.20) {
        _dashOrbTimer = 0;
        add(EnergyOrb(
          lane: laneSystem.lane,
          initialDepth: 0.96,
          elevation: 0.92,
        ));
      }
    } else {
      _dashOrbTimer = 0;
    }

    if (_distanceSinceWave >= _distanceToNextWave) {
      _spawnWave();
    }

    score.addDistance(ds, multiplier: powerUps.scoreMultiplier);

    _hudNotifyTimer += dt;
    if (_hudNotifyTimer >= 0.08) {
      _hudNotifyTimer = 0;
      hudTick.value += 1;
    }
  }

  // --------------------------------------------------------------- gameplay

  void startRun() {
    if (_runStarted || _ended || paused) {
      return;
    }
    _runStarted = true;
    hudTick.value += 1;
  }

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

  void jump() {
    if (_ended || paused || !_runStarted || powerUps.isSolarDashing) {
      return;
    }
    if (verticalMotion.jump()) {
      add(VfxBurst.jumpRipple(
        Vector2(player.position.x, playerPlaneY + player.size.y * 0.36),
      ));
    }
  }

  void slide() {
    if (_ended || paused || !_runStarted || powerUps.isSolarDashing) {
      return;
    }
    verticalMotion.slide();
  }

  bool activateSolarShield() {
    if (_ended || paused || !_runStarted) {
      return false;
    }
    final activated = powerUps.activateShield();
    if (activated) {
      add(VfxBurst.shieldShatter(player.position.clone()));
      hudTick.value += 1;
    }
    return activated;
  }

  /// Called when Soul collides with a non-cleared obstacle. Returns true if
  /// Solar Aegis absorbed and shattered the obstacle; false if the run ends.
  bool onObstacleImpact(Vector2 impactCenter) {
    if (_ended) {
      return false;
    }
    if (powerUps.consumeShieldOnHit()) {
      add(VfxBurst.shieldShatter(impactCenter));
      hudTick.value += 1;
      return true;
    }
    onPlayerHit();
    return false;
  }

  void onPlayerHit() {
    if (_ended) {
      return;
    }
    _ended = true;
    unawaited(_progress?.addSuns(score.orbsCollected) ?? Future.value());
    hudTick.value += 1;
    pauseEngine();
    overlays.add(gameOverOverlayId);
  }

  void onOrbCollected({Vector2? position}) {
    if (_ended) {
      return;
    }
    score.addOrb(multiplier: powerUps.scoreMultiplier);
    if (position != null) {
      add(VfxBurst.orbCollect(position));
    }
    hudTick.value += 1;
  }

  void onPowerUpCollected(PowerUpKind kind, Vector2 position) {
    if (_ended) {
      return;
    }
    powerUps.activate(kind);
    add(VfxBurst.shieldShatter(position));
    hudTick.value += 1;
  }

  void _spawnWave() {
    final wave = _generator.nextWave(
      speed: currentSpeed,
      difficulty: difficulty.levelAt(_elapsedSeconds),
    );
    _distanceSinceWave = 0;
    _distanceToNextWave = wave.distanceToNext;

    if (!powerUps.isSolarDashing) {
      for (final lane in wave.blockedLanes) {
        add(Obstacle(lane: lane, kind: wave.kindForLane(lane)));
      }
    }

    final orbLane = wave.orbLane;
    if (orbLane != null && wave.orbTrailCount > 0) {
      for (var i = 0; i < wave.orbTrailCount; i++) {
        add(EnergyOrb(
          lane: orbLane,
          initialDepth: 1.0 + i * 0.065,
        ));
      }
    }

    final arcLane = wave.jumpArcLane;
    if (arcLane != null && !powerUps.isSolarDashing) {
      const arcCount = 5;
      for (var i = 0; i < arcCount; i++) {
        final t = i / (arcCount - 1);
        add(EnergyOrb(
          lane: arcLane,
          initialDepth: 0.87 + i * 0.065,
          elevation: math.sin(t * math.pi) * 1.05,
        ));
      }
    }

    if (wave.powerUpLane != null && wave.powerUpKind != null) {
      add(PowerUpPickup(
        lane: wave.powerUpLane!,
        kind: wave.powerUpKind!,
        initialDepth: 1.06,
      ));
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

  void pauseByLifecycle() => pauseWithMenu();

  // --------------------------------------------------------------- replay

  void resetRun() {
    _runNumber += 1;
    _generator = SeededObstacleGenerator(seed: _seed + _runNumber);

    for (final c in children.whereType<Obstacle>().toList()) {
      c.removeFromParent();
    }
    for (final c in children.whereType<EnergyOrb>().toList()) {
      c.removeFromParent();
    }
    for (final c in children.whereType<PowerUpPickup>().toList()) {
      c.removeFromParent();
    }
    for (final c in children.whereType<VfxBurst>().toList()) {
      c.removeFromParent();
    }

    laneSystem.reset();
    verticalMotion.reset();
    powerUps.reset();
    score.reset();
    player.reset();

    _elapsedSeconds = 0;
    _travelled = 0;
    _distanceSinceWave = 0;
    _distanceToNextWave = GameConfig.firstWaveDistance;
    _dashOrbTimer = 0;
    _ended = false;
    _runStarted = false;

    overlays.remove(gameOverOverlayId);
    overlays.remove(pauseOverlayId);
    if (paused) {
      resumeEngine();
    }
    hudTick.value += 1;
  }
}
