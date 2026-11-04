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

/// Flame game root for `SOUL: DUSK RUN` (`0.18.0+18` — 100% Modular 3D Element
/// World, Low Over-the-Shoulder Chase Camera, Full-Width `1/Z` 3D Water/Valley
/// Plane, 3D Extruded Stone Causeway Curbs, Sky Citadels & Canyon Cliffs).
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
  ui.Image? valleyFloor;
  ui.Image? canyonWall;
  ui.Image? skyCitadel;
  ui.Image? viaductRuin;
  ui.Image? skyCloud;
  ui.Image? corridorPillar;
  ui.Image? floatingIsland;
  ui.Image? cliffSide;
  ui.Image? orbSprite;
  ui.Image? obstacleSprite;
  ui.Image? obstacleArchSprite;
  ui.Image? obstacleMonolithSprite;
  ui.Image? goldenCloudSprite;
  List<ui.Image> runFrames = const [];

  double _elapsedSeconds = 0;
  double _travelled = 0;
  double _distanceSinceWave = 0;
  double _distanceToNextWave = GameConfig.firstWaveDistance;
  double _dashOrbTimer = 0;
  double _hudNotifyTimer = 0;
  double _cameraLane = GameConfig.initialLane.toDouble();
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
  double get baseSupportElevation => 0.0;

  double get currentSpeed {
    if (!_runStarted) {
      return 0;
    }
    final base = difficulty.speedAt(_elapsedSeconds);
    return powerUps.isSolarDashing
        ? base * GameConfig.solarDashSpeedBoost
        : base;
  }

  double get effectivePlayerElevation {
    if (powerUps.isSolarDashing) {
      return 1.38;
    }
    final jumpMult = powerUps.hasSuperSneakers
        ? GameConfig.superSneakersJumpMultiplier
        : 1.0;
    return verticalMotion.jumpHeight * jumpMult;
  }

  // ---------------------------------------------------------------
  // S18 Low Over-the-Shoulder `3.60x` 3D Chase Camera
  // ---------------------------------------------------------------

  double get horizonY => size.y * GameConfig.horizonRatio;
  double get playerPlaneY => size.y * GameConfig.playerPlaneRatio;

  /// Smooth scenic winding S-curve factor (`-1..1`), `0.0` while idle before
  /// the first tap so Soul stands symmetrically framed at run start.
  double get roadCurveFactor {
    if (!_runStarted) {
      return 0.0;
    }
    return math.sin(_travelled * 0.00135) * 0.65 +
        math.sin(_travelled * 0.00055) * 0.35;
  }

  double curveOffsetForDepth(double depth) {
    if (depth <= 0.0) {
      return 0.0;
    }
    final d = depth.clamp(0.0, 1.15).toDouble();
    return roadCurveFactor * (d * d) * size.x * GameConfig.roadCurveRatio;
  }

  double archLiftForDepth(double depth) {
    if (depth <= 0.0 || depth >= 1.0) {
      return 0.0;
    }
    return math.sin(depth * math.pi) * size.y * GameConfig.bridgeArchRatio;
  }

  double perspectiveFactor(double depth) {
    final z = (1.0 + depth * (GameConfig.farDepthRatio - 1.0))
        .clamp(0.45, 8.0)
        .toDouble();
    return 1.0 / z;
  }

  double depthForScreenY(double y) {
    final span = math.max(1.0, playerPlaneY - horizonY);
    const pFar = GameConfig.farScale;
    final t = (y - horizonY) / span;
    final p = (pFar + t * (1.0 - pFar)).clamp(0.125, 2.25).toDouble();
    final z = 1.0 / p;
    return (z - 1.0) / (GameConfig.farDepthRatio - 1.0);
  }

  double yForDepth(double depth) {
    const pFar = GameConfig.farScale;
    final p = perspectiveFactor(depth);
    final t = (p - pFar) / (1.0 - pFar);
    return horizonY + (playerPlaneY - horizonY) * t - archLiftForDepth(depth);
  }

  /// Screen Y on the sunken 3D water/valley floor plane below the elevated
  /// ancient stone causeway.
  double valleyYForDepth(double depth) {
    return yForDepth(depth) +
        size.y * GameConfig.valleyDropRatio * perspectiveFactor(depth);
  }

  double halfWidthForDepth(double depth) =>
      size.x * GameConfig.trackBottomHalfWidthRatio * perspectiveFactor(depth);

  double trackCenterXForDepth(double depth) {
    final center = (GameConfig.laneCount - 1) / 2;
    final camOffset = (_cameraLane - center) * GameConfig.cameraFollowRatio;
    return size.x / 2 +
        curveOffsetForDepth(depth) -
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
      'Sky atmosphere dome',
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
    valleyFloor = await _tryLoadImage(
      GameConfig.valleyFloorKeyFor(selectedWorld),
      '3D valley/water floor',
    );
    canyonWall = await _tryLoadImage(
      GameConfig.canyonWallKeyFor(selectedWorld),
      '3D canyon cliff wall',
    );
    skyCitadel = await _tryLoadImage(
      GameConfig.skyCitadelKeyFor(selectedWorld),
      '3D levitating sky citadel',
    );
    viaductRuin = await _tryLoadImage(
      GameConfig.viaductRuinSpriteAsset,
      '3D stone viaduct ruin',
    );
    skyCloud = await _tryLoadImage(
      GameConfig.skyCloudSpriteAsset,
      '3D volumetric sky cloud',
    );
    corridorPillar = await _tryLoadImage(
      GameConfig.corridorPillarKeyFor(selectedWorld),
      'Parapet lantern',
    );
    floatingIsland = await _tryLoadImage(
      GameConfig.floatingIslandKeyFor(selectedWorld),
      'Floating valley island',
    );
    cliffSide = await _tryLoadImage(
      GameConfig.cliffSideKeyFor(selectedWorld),
      'Bridge-edge flora & crystals',
    );
    obstacleSprite =
        await _tryLoadImage(GameConfig.obstacleSpriteAsset, 'Crystal spikes');
    obstacleArchSprite = await _tryLoadImage(
      GameConfig.obstacleArchSpriteAsset,
      'Rune stone archway',
    );
    obstacleMonolithSprite = await _tryLoadImage(
      GameConfig.obstacleMonolithSpriteAsset,
      'Dark storm cloud',
    );
    goldenCloudSprite = await _tryLoadImage(
      GameConfig.goldenCloudSpriteAsset,
      'Golden dawn bounce cloud',
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
        Vector2(player.position.x, playerPlaneY + player.size.y * 0.34),
      ));
    }
  }

  void triggerCloudBounce(Vector2 cloudCenter) {
    if (_ended || paused || !_runStarted) {
      return;
    }
    verticalMotion.bounce();
    add(VfxBurst.shieldShatter(cloudCenter));
    hudTick.value += 1;
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
      for (final obs in children.whereType<Obstacle>().toList()) {
        if (!obs.isGoldenBounceCloud && obs.frontDepth <= 0.28) {
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

    const waveCoreDepth = 1.06;
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

    final arcLane = wave.jumpArcLane;
    if (arcLane != null && !powerUps.isSolarDashing) {
      const arcCount = 5;
      for (var i = 0; i < arcCount; i++) {
        final t = i / (arcCount - 1);
        add(EnergyOrb(
          lane: arcLane,
          initialDepth: 1.00 + i * 0.04,
          elevation: math.sin(t * math.pi) * 0.94,
        ));
      }
    }

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

    final bounceLane = wave.roofCoinLane;
    if (bounceLane != null && !powerUps.isSolarDashing) {
      const skyArcCount = 5;
      for (var i = 0; i < skyArcCount; i++) {
        final u = (i + 0.5) / skyArcCount;
        add(EnergyOrb(
          lane: bounceLane,
          initialDepth: waveCoreDepth + 0.05 + i * 0.065,
          elevation: math.sin(u * math.pi) * 1.32,
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
