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

/// Flame game root for SOUL: DUSK RUN (S15 Subway-Surfers-Grade Sunlit 3D
/// Overhaul).
///
/// Delivers the complete Subway Surfers gameplay loop & eye-friendly polish:
///  * Bright sunlit full-width 3D boulevard worlds with rock-steady horizon
///    (zero dark tunnel glare, zero horizon bobbing, zero screen-shake eye
///    strain);
///  * True 8-vertex `1/Z` 3D extruded Subway Trains (parked Blue & oncoming
///    Red Express), 6-vertex 3D Boarding Ramps, and walkable 3D Train Roofs
///    with roof-to-roof jumping & smooth gravity drop-off;
///  * Full Subway Surfers power-up suite: Hoverboard (`activateSolarShield`),
///    Jetpack (`solarDash`), Super Sneakers (`superSneakers`), Coin Magnet,
///    and 2x Multiplier;
///  * Side-clip stumble bounce recovery (`onObstacleSideStumble`).
class SoulDuskRunGame extends FlameGame {
  SoulDuskRunGame({int seed = 0, this.selectedWorld = GameWorld.duskHollow})
      : _seed = seed;

  final GameWorld selectedWorld;

  static const String gameOverOverlayId = 'gameOver';
  static const String pauseOverlayId = 'pauseMenu';

  final int _seed;

  final LaneSystem laneSystem = LaneSystem();
  final VerticalMotion verticalMotion = VerticalMotion();
  final PowerUpSystem powerUps = PowerUpSystem();
  final DifficultyManager difficulty = const DifficultyManager();
  final ScoreManager score = ScoreManager();

  final ValueNotifier<int> hudTick = ValueNotifier<int>(0);

  late SeededObstacleGenerator _generator;
  late final SoulPlayer player;

  ui.Image? soulSprite;
  ui.Image? soulJumpSprite;
  ui.Image? soulSlideSprite;
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
  double _cameraLane = GameConfig.initialLane.toDouble();
  double _baseSupportElevation = 0;
  double _fallVelocity = 0;
  double _stumbleTimer = 0;
  bool _ended = false;
  int _runNumber = 0;
  bool _runStarted = false;

  ProgressStore? _progress;

  double get elapsedSeconds => _elapsedSeconds;
  double get travelled => _travelled;
  bool get isEnded => _ended;
  bool get isRunStarted => _runStarted;
  bool get isStumbling => _stumbleTimer > 0;
  double get cameraLane => _cameraLane;

  /// Active floor height under Soul (`0.0` on rails, `0.90` when running on
  /// top of a 3D train roof!).
  double get baseSupportElevation => _baseSupportElevation;

  double get currentSpeed {
    if (!_runStarted) {
      return 0;
    }
    final base = difficulty.speedAt(_elapsedSeconds);
    return powerUps.isSolarDashing
        ? base * GameConfig.solarDashSpeedBoost
        : base;
  }

  /// Total vertical elevation of Soul above the rails.
  double get effectivePlayerElevation {
    if (powerUps.isSolarDashing) {
      return 1.38;
    }
    final jumpMult = powerUps.hasSuperSneakers
        ? GameConfig.superSneakersJumpMultiplier
        : 1.0;
    return _baseSupportElevation + verticalMotion.jumpHeight * jumpMult;
  }

  // ---------------------------------------------------------------
  // S15 Rock-Steady `2.30x` 3D Chase Camera (zero horizon jitter!)
  // ---------------------------------------------------------------

  double get horizonY => size.y * GameConfig.horizonRatio;
  double get playerPlaneY => size.y * GameConfig.playerPlaneRatio;

  double perspectiveFactor(double depth) {
    final z = (1.0 + depth * (GameConfig.farDepthRatio - 1.0))
        .clamp(0.74, 8.0)
        .toDouble();
    return 1.0 / z;
  }

  double depthForScreenY(double y) {
    final span = math.max(1.0, playerPlaneY - horizonY);
    const pFar = GameConfig.farScale;
    final t = (y - horizonY) / span;
    final p = (pFar + t * (1.0 - pFar)).clamp(0.125, 1.35).toDouble();
    final z = 1.0 / p;
    return (z - 1.0) / (GameConfig.farDepthRatio - 1.0);
  }

  double yForDepth(double depth) {
    const pFar = GameConfig.farScale;
    final p = perspectiveFactor(depth);
    final t = (p - pFar) / (1.0 - pFar);
    return horizonY + (playerPlaneY - horizonY) * t;
  }

  double halfWidthForDepth(double depth) =>
      size.x * GameConfig.trackBottomHalfWidthRatio * perspectiveFactor(depth);

  double trackCenterXForDepth(double depth) {
    final center = (GameConfig.laneCount - 1) / 2;
    final camOffset = (_cameraLane - center) * GameConfig.cameraFollowRatio;
    return size.x / 2 -
        camOffset * halfWidthForDepth(depth) * GameConfig.laneSpreadRatio;
  }

  double laneXForDepth(double lane, double depth) {
    final center = (GameConfig.laneCount - 1) / 2;
    final offset = lane - center;
    return trackCenterXForDepth(depth) +
        offset * halfWidthForDepth(depth) * GameConfig.laneSpreadRatio;
  }

  double laneXOnPlayerPlane(double lane) => laneXForDepth(lane, 0);

  double scaleForDepth(double depth) => perspectiveFactor(depth);

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
    soulJumpSprite =
        await _tryLoadImage(GameConfig.soulJumpSpriteKey, 'Soul jump pose');
    soulSlideSprite =
        await _tryLoadImage(GameConfig.soulSlideSpriteKey, 'Soul slide pose');

    final trackKey = GameConfig.trackStripKeyFor(selectedWorld);
    trackStrip = trackKey == null
        ? null
        : await _tryLoadImage(trackKey, 'Track strip');
    corridorPillar = await _tryLoadImage(
      GameConfig.corridorPillarKeyFor(selectedWorld),
      'Corridor pillar',
    );
    obstacleSprite =
        await _tryLoadImage(GameConfig.obstacleSpriteAsset, 'Low barrier');
    obstacleArchSprite = await _tryLoadImage(
      GameConfig.obstacleArchSpriteAsset,
      'High roll barrier',
    );
    obstacleMonolithSprite = await _tryLoadImage(
      GameConfig.obstacleMonolithSpriteAsset,
      'Subway train',
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

    // Smooth critically-damped lateral chase camera follow (zero jitter!).
    final camFollow = (1.0 - math.exp(-dt * 9.0)).clamp(0.0, 1.0).toDouble();
    _cameraLane += (player.currentLane - _cameraLane) * camFollow;

    if (_ended || !_runStarted) {
      return;
    }

    if (_stumbleTimer > 0) {
      _stumbleTimer = math.max(0.0, _stumbleTimer - dt);
    }

    _elapsedSeconds += dt;
    verticalMotion.update(dt);
    powerUps.update(dt);

    // Update 3D Train Roof & Boarding Ramp floor elevation under Soul!
    _updateTrainRoofSupport(dt);

    final ds = currentSpeed * dt;
    _travelled += ds;
    _distanceSinceWave += ds;

    if (powerUps.isSolarDashing) {
      _dashOrbTimer += dt;
      if (_dashOrbTimer >= 0.17) {
        _dashOrbTimer = 0;
        add(EnergyOrb(
          lane: laneSystem.lane,
          initialDepth: 1.0,
          elevation: 1.38,
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

  void _updateTrainRoofSupport(double dt) {
    var targetSupport = 0.0;
    final currentTotal = effectivePlayerElevation;
    for (final obs in children.whereType<Obstacle>()) {
      final s = obs.supportElevationForPlayer(player.currentLane, currentTotal);
      if (s > targetSupport) {
        targetSupport = s;
      }
    }

    if (targetSupport >= _baseSupportElevation) {
      // Climbing ramp or running across train roof!
      _baseSupportElevation = targetSupport;
      _fallVelocity = 0;
    } else if (!verticalMotion.isJumping) {
      // Stepped off the back or side of a train roof -> smooth gravity drop!
      final gravity = verticalMotion.isFastFalling ? 14.0 : 5.2;
      _fallVelocity += gravity * dt;
      _baseSupportElevation =
          math.max(targetSupport, _baseSupportElevation - _fallVelocity * dt);
      if (_baseSupportElevation <= targetSupport + 1e-4) {
        _baseSupportElevation = targetSupport;
        _fallVelocity = 0;
      }
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
      final supportPx =
          _baseSupportElevation * size.y * GameConfig.jumpHeightRatio;
      add(VfxBurst.jumpRipple(
        Vector2(
            player.position.x, playerPlaneY - supportPx + player.size.y * 0.34),
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

  bool onObstacleImpact(Vector2 impactCenter) {
    if (_ended) {
      return false;
    }
    if (powerUps.consumeShieldOnHit()) {
      _stumbleTimer = 0;
      // Subway Surfers Hoverboard crash-clear: clear nearby foreground hazards
      // so Soul keeps surfing forward cleanly!
      for (final obs in children.whereType<Obstacle>().toList()) {
        if (obs.frontDepth <= 0.28) {
          obs.removeFromParent();
        }
      }
      add(VfxBurst.shieldShatter(impactCenter));
      hudTick.value += 1;
      return true;
    }
    onPlayerHit();
    return false;
  }

  void onObstacleSideStumble(int blockedLane, Vector2 contactPoint) {
    if (_ended) {
      return;
    }
    if (_stumbleTimer > 0) {
      onObstacleImpact(contactPoint);
      return;
    }
    laneSystem.bounceFromBlockedLane(blockedLane);
    _stumbleTimer = GameConfig.stumbleRecoverySeconds;
    add(VfxBurst.orbCollect(contactPoint));
    hudTick.value += 1;
  }

  void onNearMissSpark(Vector2 grazePoint) {
    if (_ended) {
      return;
    }
    add(VfxBurst.orbCollect(grazePoint));
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

    const waveCoreDepth = 1.08;
    if (!powerUps.isSolarDashing) {
      for (final lane in wave.blockedLanes) {
        add(Obstacle(
          lane: lane,
          kind: wave.kindForLane(lane),
          isMoving: wave.isMovingTrain(lane),
          initialDepth: waveCoreDepth,
        ));
      }
    }

    // 1. Safe-lane / S-curve coin guide
    final orbLane = wave.orbLane;
    if (orbLane != null && wave.orbTrailCount > 0) {
      final slalom = wave.slalomLanes;
      for (var i = 0; i < wave.orbTrailCount; i++) {
        final itemLane =
            (slalom != null && i < slalom.length) ? slalom[i] : orbLane;
        add(EnergyOrb(
          lane: itemLane,
          initialDepth: 0.96 + i * 0.055,
        ));
      }
    }

    // 2. Parabolic jump-reward arc over low hurdles
    final arcLane = wave.jumpArcLane;
    if (arcLane != null && !powerUps.isSolarDashing) {
      const arcCount = 5;
      for (var i = 0; i < arcCount; i++) {
        final t = i / (arcCount - 1);
        add(EnergyOrb(
          lane: arcLane,
          initialDepth: 1.00 + i * 0.04,
          elevation: math.sin(t * math.pi) * 0.96,
        ));
      }
    }

    // 3. Slide-tunnel coins directly underneath overhead roll gates
    final slideLane = wave.slideTunnelLane;
    if (slideLane != null && !powerUps.isSolarDashing) {
      const tunnelOrbs = 4;
      for (var i = 0; i < tunnelOrbs; i++) {
        add(EnergyOrb(
          lane: slideLane,
          initialDepth: 1.02 + i * 0.04,
          elevation: 0.0,
        ));
      }
    }

    // 4. Ramp-climb + 3D Train Roof coin trail on `trainWithRamp`!
    final roofLane = wave.roofCoinLane;
    if (roofLane != null && !powerUps.isSolarDashing) {
      add(EnergyOrb(
        lane: roofLane,
        initialDepth: waveCoreDepth - 0.045,
        elevation: GameConfig.trainRoofElevation * 0.36,
      ));
      add(EnergyOrb(
        lane: roofLane,
        initialDepth: waveCoreDepth - 0.015,
        elevation: GameConfig.trainRoofElevation * 0.78,
      ));
      for (var i = 0; i < 4; i++) {
        add(EnergyOrb(
          lane: roofLane,
          initialDepth: waveCoreDepth + 0.03 + i * 0.065,
          elevation: GameConfig.trainRoofElevation + 0.04,
        ));
      }
    }

    if (wave.powerUpLane != null && wave.powerUpKind != null) {
      add(PowerUpPickup(
        lane: wave.powerUpLane!,
        kind: wave.powerUpKind!,
        initialDepth: 1.14,
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
    _cameraLane = GameConfig.initialLane.toDouble();
    _baseSupportElevation = 0;
    _fallVelocity = 0;
    _stumbleTimer = 0;
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
