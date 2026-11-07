import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'components/crystal_portal_gate.dart';
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

/// Lifecycle stages of `SOUL: DUSK RUN` (`0.20.0+20`):
///  * [RunStage.titleHover] — Main Screen: close-up front-facing Soul hovers
///    alive in the 3D sky (blinking, smiling, streaming golden ribbons);
///  * [RunStage.introFlight] — Soul clicked / START pressed: Soul closes his
///    eyes, spins 180° away from the camera, dives like a golden comet down to
///    the stone causeway while the camera swoops close behind him;
///  * [RunStage.running] — Soul glides onto the flagstones and sprints forward
///    in close over-the-shoulder chase view, with Crystal Portals ahead!
enum RunStage { titleHover, introFlight, running }

class _WorldArtBundle {
  ui.Image? backdrop;
  ui.Image? trackStrip;
  ui.Image? valleyFloor;
  ui.Image? canyonWall;
  ui.Image? skyCitadel;
  ui.Image? corridorPillar;
  ui.Image? floatingIsland;
  ui.Image? cliffSide;
}

/// Flame game root for `SOUL: DUSK RUN` (`0.20.0+20` — Close-Up Front-Facing
/// Living Main Screen, 180° Spin & Golden Comet Dive, Closer Over-the-Shoulder
/// Chase Camera, Asymmetric Cliffside World & Crystal Portal Gateways).
class SoulDuskRunGame extends FlameGame {
  SoulDuskRunGame({
    int seed = 0,
    this.selectedWorld = GameWorld.duskHollow,
    bool startInTitleHover = true,
  })  : _seed = seed,
        _currentWorld = selectedWorld,
        _stage =
            startInTitleHover ? RunStage.titleHover : RunStage.introFlight;

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

  final Map<GameWorld, _WorldArtBundle> _worldBundles =
      <GameWorld, _WorldArtBundle>{};

  ui.Image? soulSprite;
  ui.Image? soulHoverOpenSprite;
  ui.Image? soulHoverBlinkSprite;
  ui.Image? soulJumpSprite;
  ui.Image? soulSlideSprite;
  ui.Image? viaductRuin;
  ui.Image? skyCloud;
  ui.Image? crystalPortalSprite;
  ui.Image? orbSprite;
  ui.Image? obstacleSprite;
  ui.Image? obstacleArchSprite;
  ui.Image? obstacleMonolithSprite;
  ui.Image? goldenCloudSprite;
  List<ui.Image> runFrames = const [];

  GameWorld _currentWorld;
  RunStage _stage;
  double _introProgress = 0;
  double _ambientSeconds = 0;
  double _elapsedSeconds = 0;
  double _travelled = 0;
  double _distanceSinceWave = 0;
  double _distanceSincePortal = 0;
  double _distanceToNextWave = GameConfig.firstWaveDistance;
  double _dashOrbTimer = 0;
  double _hudNotifyTimer = 0;
  double _cameraLane = GameConfig.initialLane.toDouble();
  double _stumbleTimer = 0;
  double _portalFlashTimer = 0;
  double _portalBannerTimer = 0;
  bool _ended = false;
  int _runNumber = 0;

  ProgressStore? _progress;

  GameWorld get currentWorld => _currentWorld;
  RunStage get stage => _stage;
  bool get isTitleHovering => _stage == RunStage.titleHover;
  bool get isIntroFlying => _stage == RunStage.introFlight;
  bool get isGroundRunning => _stage == RunStage.running;
  bool get isRunStarted => _stage != RunStage.titleHover;
  double get introFlightProgress => _introProgress;

  double get ambientSeconds => _ambientSeconds;
  double get elapsedSeconds => _elapsedSeconds;
  double get travelled => _travelled;
  bool get isEnded => _ended;
  bool get isStumbling => _stumbleTimer > 0;
  double get cameraLane => _cameraLane;
  double get baseSupportElevation => 0.0;

  double get portalFlashProgress =>
      (_portalFlashTimer / 0.65).clamp(0.0, 1.0).toDouble();
  bool get showPortalArrivalBanner => _portalBannerTimer > 0;

  ui.Image? get worldBackdrop => _worldBundles[_currentWorld]?.backdrop;
  ui.Image? get trackStrip => _worldBundles[_currentWorld]?.trackStrip;
  ui.Image? get valleyFloor => _worldBundles[_currentWorld]?.valleyFloor;
  ui.Image? get canyonWall => _worldBundles[_currentWorld]?.canyonWall;
  ui.Image? get skyCitadel => _worldBundles[_currentWorld]?.skyCitadel;
  ui.Image? get corridorPillar => _worldBundles[_currentWorld]?.corridorPillar;
  ui.Image? get floatingIsland => _worldBundles[_currentWorld]?.floatingIsland;
  ui.Image? get cliffSide => _worldBundles[_currentWorld]?.cliffSide;

  /// Smooth camera blend (`1.0` on Sky-High Main Screen -> `0.0` in close
  /// over-the-shoulder chase view behind Soul!).
  double get introCameraBlend {
    switch (_stage) {
      case RunStage.titleHover:
        return 1.0;
      case RunStage.introFlight:
        // Hold sky camera briefly for Soul's serene eye-close & start of 180°
        // spin (`0.00..0.18`), then swoop down smoothly (`0.18..0.88`)!
        final u =
            ((_introProgress - 0.18) / 0.70).clamp(0.0, 1.0).toDouble();
        final s = u * u * (3.0 - 2.0 * u);
        return 1.0 - s;
      case RunStage.running:
        return 0.0;
    }
  }

  double get currentSpeed {
    switch (_stage) {
      case RunStage.titleHover:
        return 0.0;
      case RunStage.introFlight:
        final u =
            ((_introProgress - 0.18) / 0.82).clamp(0.0, 1.0).toDouble();
        final smooth = u * u * (3.0 - 2.0 * u);
        return GameConfig.startSpeed * (0.12 + 0.88 * smooth);
      case RunStage.running:
        final base = difficulty.speedAt(_elapsedSeconds);
        return powerUps.isSolarDashing
            ? base * GameConfig.solarDashSpeedBoost
            : base;
    }
  }

  double get effectivePlayerElevation {
    switch (_stage) {
      case RunStage.titleHover:
        return GameConfig.titleHoverElevation +
            math.sin(_ambientSeconds * 2.15) * 0.10 +
            math.sin(_ambientSeconds * 1.08) * 0.04;
      case RunStage.introFlight:
        final u = _introProgress.clamp(0.0, 1.0).toDouble();
        const startE = GameConfig.titleHoverElevation;
        const peakE = GameConfig.introFlightPeakElevation;
        const apexU = 0.24;
        if (u < apexU) {
          final tUp = u / apexU;
          return startE + (peakE - startE) * math.sin(tUp * math.pi * 0.5);
        }
        final tDn = (u - apexU) / (1.0 - apexU);
        final descent = 0.5 * (1.0 + math.cos(tDn * math.pi));
        return peakE * descent + verticalMotion.jumpHeight;
      case RunStage.running:
        if (powerUps.isSolarDashing) {
          return 1.38;
        }
        final jumpMult = powerUps.hasSuperSneakers
            ? GameConfig.superSneakersJumpMultiplier
            : 1.0;
        return verticalMotion.jumpHeight * jumpMult;
    }
  }

  bool get _acceptsRunnerControls =>
      _stage == RunStage.running ||
      (_stage == RunStage.introFlight && _introProgress >= 0.80);

  // ---------------------------------------------------------------
  // S20 Closer, Lower Over-the-Shoulder `4.15x` 3D Chase Camera
  // ---------------------------------------------------------------

  double get horizonY =>
      size.y *
      (GameConfig.horizonRatio +
          GameConfig.titleHorizonLiftRatio * introCameraBlend);

  double get playerPlaneY =>
      size.y * (GameConfig.playerPlaneRatio + 0.06 * introCameraBlend);

  double get roadCurveFactor {
    if (_stage != RunStage.running) {
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
        .clamp(0.42, 8.5)
        .toDouble();
    return 1.0 / z;
  }

  double depthForScreenY(double y) {
    final span = math.max(1.0, playerPlaneY - horizonY);
    const pFar = GameConfig.farScale;
    final t = (y - horizonY) / span;
    final p = (pFar + t * (1.0 - pFar)).clamp(0.118, 2.38).toDouble();
    final z = 1.0 / p;
    return (z - 1.0) / (GameConfig.farDepthRatio - 1.0);
  }

  double yForDepth(double depth) {
    const pFar = GameConfig.farScale;
    final p = perspectiveFactor(depth);
    final t = (p - pFar) / (1.0 - pFar);
    return horizonY + (playerPlaneY - horizonY) * t - archLiftForDepth(depth);
  }

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

  Future<_WorldArtBundle> _loadWorldBundle(GameWorld world) async {
    final bundle = _WorldArtBundle();
    bundle.backdrop = await _tryLoadImage(
      GameConfig.backdropKeyFor(world),
      'Sky atmosphere dome ($world)',
    );
    final trackKey = GameConfig.trackStripKeyFor(world);
    bundle.trackStrip = trackKey == null
        ? null
        : await _tryLoadImage(trackKey, 'Track strip ($world)');
    bundle.valleyFloor = await _tryLoadImage(
      GameConfig.valleyFloorKeyFor(world),
      '3D valley/water floor ($world)',
    );
    bundle.canyonWall = await _tryLoadImage(
      GameConfig.canyonWallKeyFor(world),
      '3D canyon cliff wall ($world)',
    );
    bundle.skyCitadel = await _tryLoadImage(
      GameConfig.skyCitadelKeyFor(world),
      '3D levitating sky citadel ($world)',
    );
    bundle.corridorPillar = await _tryLoadImage(
      GameConfig.corridorPillarKeyFor(world),
      'Parapet lantern ($world)',
    );
    bundle.floatingIsland = await _tryLoadImage(
      GameConfig.floatingIslandKeyFor(world),
      'Floating valley island ($world)',
    );
    bundle.cliffSide = await _tryLoadImage(
      GameConfig.cliffSideKeyFor(world),
      'Bridge-edge flora & crystals ($world)',
    );
    return bundle;
  }

  Future<void> _preloadArt() async {
    // 1. Load close-up Main Screen Soul sprites & active world bundle FIRST!
    soulHoverOpenSprite = await _tryLoadImage(
      GameConfig.soulHoverOpenSpriteKey,
      'Soul close-up hover open-eyes',
    );
    soulHoverBlinkSprite = await _tryLoadImage(
      GameConfig.soulHoverBlinkSpriteKey,
      'Soul close-up hover blink-eyes',
    );
    _worldBundles[selectedWorld] = await _loadWorldBundle(selectedWorld);

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

    viaductRuin = await _tryLoadImage(
      GameConfig.viaductRuinSpriteAsset,
      '3D stone viaduct ruin',
    );
    skyCloud = await _tryLoadImage(
      GameConfig.skyCloudSpriteAsset,
      '3D volumetric sky cloud',
    );
    crystalPortalSprite = await _tryLoadImage(
      GameConfig.crystalPortalSpriteAsset,
      '3D faceted crystal portal gate',
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

    // 2. Warm-cache remaining worlds so Crystal Portal transitions have 0ms hitch!
    for (final world in GameWorld.values) {
      if (!_worldBundles.containsKey(world)) {
        _worldBundles[world] = await _loadWorldBundle(world);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    final camFollow = (1.0 - math.exp(-dt * 10.5)).clamp(0.0, 1.0).toDouble();
    _cameraLane += (player.currentLane - _cameraLane) * camFollow;

    if (_ended) {
      return;
    }

    _ambientSeconds += dt;

    if (_portalFlashTimer > 0) {
      _portalFlashTimer = math.max(0.0, _portalFlashTimer - dt);
    }
    if (_portalBannerTimer > 0) {
      _portalBannerTimer = math.max(0.0, _portalBannerTimer - dt);
      if (_portalBannerTimer <= 0) {
        hudTick.value += 1;
      }
    }

    if (_stage == RunStage.titleHover) {
      return;
    }

    if (_stage == RunStage.introFlight) {
      _introProgress += dt / GameConfig.introFlightDurationSeconds;
      verticalMotion.update(dt);
      _travelled += currentSpeed * dt;

      if (_introProgress >= 1.0) {
        _introProgress = 1.0;
        _stage = RunStage.running;
        if (player.isMounted) {
          player.onIntroTouchdown();
          final landingPos = Vector2(
            player.position.x,
            playerPlaneY + player.size.y * 0.28,
          );
          add(VfxBurst.jumpRipple(landingPos));
          add(VfxBurst.orbCollect(landingPos));
        }
        hudTick.value += 1;
      }
      return;
    }

    // RunStage.running
    if (_stumbleTimer > 0) {
      _stumbleTimer = math.max(0.0, _stumbleTimer - dt);
    }

    _elapsedSeconds += dt;
    verticalMotion.update(dt);
    powerUps.update(dt);

    final ds = currentSpeed * dt;
    _travelled += ds;
    _distanceSinceWave += ds;
    _distanceSincePortal += ds;

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

  /// Tapping directly on Soul OR clicking START launches Soul's 4-phase
  /// serene blink -> 180° spin -> golden comet dive -> low stone-slab glide!
  void startRun() {
    if (_stage != RunStage.titleHover || _ended || paused) {
      return;
    }
    _stage = RunStage.introFlight;
    _introProgress = 0.0;
    if (player.isMounted && size.x > 0 && size.y > 0) {
      final skyBurstPos = Vector2(size.x * 0.35, size.y * 0.43);
      add(VfxBurst.shieldShatter(skyBurstPos));
    }
    hudTick.value += 1;
  }

  /// Triggered when Soul sprints through a 3D `CrystalPortalGate` (`06-22-22`
  /// -> `06-22-29`), transforming the surrounding biome on the fly!
  void enterCrystalPortal(GameWorld nextWorld) {
    if (_ended) {
      return;
    }
    _currentWorld = nextWorld;
    _portalFlashTimer = 0.65;
    _portalBannerTimer = 2.6;
    for (final obs in children.whereType<Obstacle>().toList()) {
      if (!obs.isGoldenBounceCloud && obs.frontDepth <= 0.24) {
        obs.removeFromParent();
      }
    }
    if (player.isMounted) {
      final burstPos = Vector2(player.position.x, playerPlaneY - size.y * 0.06);
      add(VfxBurst.shieldShatter(burstPos));
      add(VfxBurst.jumpRipple(burstPos));
    }
    hudTick.value += 1;
  }

  void moveLane(int direction) {
    if (_ended || paused || !_acceptsRunnerControls) {
      return;
    }
    if (direction < 0) {
      laneSystem.moveLeft();
    } else if (direction > 0) {
      laneSystem.moveRight();
    }
  }

  void jump() {
    if (_ended ||
        paused ||
        !_acceptsRunnerControls ||
        powerUps.isSolarDashing) {
      return;
    }
    if (verticalMotion.jump()) {
      add(VfxBurst.jumpRipple(
        Vector2(player.position.x, playerPlaneY + player.size.y * 0.34),
      ));
    }
  }

  void triggerCloudBounce(Vector2 cloudCenter) {
    if (_ended || paused || !isGroundRunning) {
      return;
    }
    verticalMotion.bounce();
    add(VfxBurst.shieldShatter(cloudCenter));
    hudTick.value += 1;
  }

  void slide() {
    if (_ended ||
        paused ||
        !_acceptsRunnerControls ||
        powerUps.isSolarDashing) {
      return;
    }
    verticalMotion.slide();
  }

  bool activateSolarShield() {
    if (_ended || paused || !isGroundRunning) {
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
    // Spawn a majestic 3D Crystal Portal Gateway every `portalIntervalDistance`!
    if (_distanceSincePortal >= GameConfig.portalIntervalDistance) {
      _distanceSincePortal = 0;
      _distanceSinceWave = 0;
      _distanceToNextWave = 460;

      final targetBiome = GameConfig.nextWorldAfter(_currentWorld);
      add(CrystalPortalGate(targetWorld: targetBiome, initialDepth: 1.06));
      for (var i = 0; i < 5; i++) {
        add(EnergyOrb(
          lane: 1,
          initialDepth: 0.90 + i * 0.05,
        ));
      }
      return;
    }

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
    if (_ended || paused || isTitleHovering) {
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

  void pauseByLifecycle() {
    if (isTitleHovering) {
      return;
    }
    pauseWithMenu();
  }

  // --------------------------------------------------------------- replay

  void _clearWorldEntities() {
    for (final c in children.whereType<Obstacle>().toList()) {
      c.removeFromParent();
    }
    for (final c in children.whereType<CrystalPortalGate>().toList()) {
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

    _currentWorld = selectedWorld;
    _elapsedSeconds = 0;
    _travelled = 0;
    _distanceSinceWave = 0;
    _distanceSincePortal = 0;
    _distanceToNextWave = GameConfig.firstWaveDistance;
    _dashOrbTimer = 0;
    _cameraLane = GameConfig.initialLane.toDouble();
    _stumbleTimer = 0;
    _portalFlashTimer = 0;
    _portalBannerTimer = 0;
    _ended = false;
  }

  /// PLAY AGAIN: resets and immediately launches Soul's sky-flight dive onto
  /// the stone bridge!
  void resetRun() {
    _runNumber += 1;
    _generator = SeededObstacleGenerator(seed: _seed + _runNumber);
    _clearWorldEntities();

    _stage = RunStage.introFlight;
    _introProgress = 0.0;

    overlays.remove(gameOverOverlayId);
    overlays.remove(pauseOverlayId);
    if (paused) {
      resumeEngine();
    }
    hudTick.value += 1;
  }

  /// Returns cleanly to the Living 3D Main Screen (`RunStage.titleHover`) with
  /// close-up Soul hovering alive in the sky!
  void returnToTitleHover() {
    _runNumber += 1;
    _generator = SeededObstacleGenerator(seed: _seed + _runNumber);
    _clearWorldEntities();

    _stage = RunStage.titleHover;
    _introProgress = 0.0;

    overlays.remove(gameOverOverlayId);
    overlays.remove(pauseOverlayId);
    if (paused) {
      resumeEngine();
    }
    hudTick.value += 1;
  }
}
