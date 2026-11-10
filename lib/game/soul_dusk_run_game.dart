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

/// Lifecycle stages of `SOUL: DUSK RUN`:
///  * [RunStage.titleHover] — Main Screen: close-up front-facing Soul hovers
///    alive in the 3D sky (blinking, smiling, streaming golden ribbons);
///  * [RunStage.introFlight] — Soul clicked / START pressed: Soul closes his
///    eyes, spins 180° away from the camera, dives like a golden comet down to
///    the stone causeway while the camera swoops close behind him;
///  * [RunStage.running] — Soul glides onto the flagstones and sprints forward
///    in close over-the-shoulder chase view toward Abyssal Portal Gateways!
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

/// Flame game root for `SOUL: DUSK RUN` (Stage 3 Upgrade:
/// Abyssal World-Termination Portal Logic where the road & world physically end
/// at the portal cliff-edge with nothing behind it, plus a sensational
/// `1.35s` Dimensional Rift Breach & unfurling new-world highway!).
class SoulDuskRunGame extends FlameGame {
  SoulDuskRunGame({
    int seed = 0,
    GameWorld selectedWorld = GameWorld.duskHollow,
    bool startInTitleHover = true,
  })  : _seed = seed,
        _selectedWorld = selectedWorld,
        _currentWorld = selectedWorld,
        _stage =
            startInTitleHover ? RunStage.titleHover : RunStage.introFlight;

  static const String gameOverOverlayId = 'gameOver';
  static const String pauseOverlayId = 'pauseMenu';

  static const double maxFrameDt = 0.05;
  static const double portalWarpDurationSeconds = 1.35;

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
  final Map<GameWorld, Future<_WorldArtBundle>> _worldLoadFutures =
      <GameWorld, Future<_WorldArtBundle>>{};

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

  CrystalPortalGate? _activePortal;

  GameWorld _selectedWorld;
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
  double _cameraLane = GameConfig.initialLane.toDouble();
  double _stumbleTimer = 0;
  double _portalWarpTimer = 0;
  double _portalBannerTimer = 0;
  double _cameraShakeTimer = 0;
  double _cameraShakeIntensity = 0;
  bool _ended = false;
  bool _disposed = false;
  int _runNumber = 0;
  int _lastHudSignature = -1;

  ProgressStore? _progress;

  GameWorld get selectedWorld => _selectedWorld;
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

  // ---- Stage 3 Abyssal Portal & Dimensional Rift State ----

  /// True while an un-crossed Abyssal Portal Gate sits ahead on the causeway.
  /// While true, the current world's road, curbs, props, and wave spawner
  /// terminate cleanly at [activePortalCutoffDepth] ("پشتش هیچی نباشد")!
  bool get hasPendingPortal {
    final p = _activePortal;
    return p != null && p.isMounted && !p.hasTriggered;
  }

  /// Exact depth (`0.02..1.25`) where the current world's road & cliffs end in
  /// a sheer cosmic abyss right beneath the Portal Gateway, or `null` if no
  /// un-crossed portal is ahead.
  double? get activePortalCutoffDepth {
    final p = _activePortal;
    if (p == null || !p.isMounted || p.hasTriggered) {
      return null;
    }
    return p.currentDepth.clamp(0.02, 1.25).toDouble();
  }

  /// Maximum depth (`0.02..1.00`) to render the active stone causeway:
  ///  * Terminates at the portal threshold while approaching an Abyssal Portal;
  ///  * Rapidly unfurls from `0.18 -> 1.00` during the first `0.58s` after
  ///    breaching into a new world so the fresh causeway materializes ahead!
  double get activeRoadMaxDepth {
    final cutoff = activePortalCutoffDepth;
    if (cutoff != null) {
      return cutoff.clamp(0.02, 1.0).toDouble();
    }
    if (isPortalWarping) {
      final u = portalWarpProgress;
      if (u < 0.44) {
        final t = (u / 0.44).clamp(0.0, 1.0).toDouble();
        final s = t * t * (3.0 - 2.0 * t);
        return (0.18 + 0.82 * s).clamp(0.18, 1.0).toDouble();
      }
    }
    return 1.0;
  }

  bool get isPortalWarping => _portalWarpTimer > 0;

  /// Normalized progress (`0.0 -> 1.0`) through the `1.35s` Dimensional Breach
  /// spectacle after crossing a Portal (`-1.0` when inactive).
  double get portalWarpProgress => _portalWarpTimer > 0
      ? (1.0 - _portalWarpTimer / portalWarpDurationSeconds)
          .clamp(0.0, 1.0)
          .toDouble()
      : -1.0;

  double get portalFlashProgress => _portalWarpTimer > 0
      ? (_portalWarpTimer / portalWarpDurationSeconds)
          .clamp(0.0, 1.0)
          .toDouble()
      : 0.0;

  bool get showPortalArrivalBanner => _portalBannerTimer > 0;

  /// Damped screen-space camera impact shake (in logical pixels) for portal
  /// breaches, cloud-bounces, touchdowns, and stumbles!
  Offset get cameraShakeOffset {
    if (_cameraShakeTimer <= 0 || _cameraShakeIntensity <= 0) {
      return Offset.zero;
    }
    final decay = (_cameraShakeTimer / 0.45).clamp(0.0, 1.0).toDouble();
    final amp = _cameraShakeIntensity * decay * decay;
    final dx = math.sin(_ambientSeconds * 67.0) * amp;
    final dy = math.cos(_ambientSeconds * 53.0) * amp * 0.75;
    return Offset(dx, dy);
  }

  void triggerCameraShake(double intensity, {double duration = 0.36}) {
    _cameraShakeIntensity = math.max(_cameraShakeIntensity, intensity);
    _cameraShakeTimer = math.max(_cameraShakeTimer, duration);
  }

  ui.Image? backdropForWorld(GameWorld world) => _worldBundles[world]?.backdrop;
  ui.Image? trackStripForWorld(GameWorld world) =>
      _worldBundles[world]?.trackStrip;

  ui.Image? get worldBackdrop => _worldBundles[_currentWorld]?.backdrop;
  ui.Image? get trackStrip => _worldBundles[_currentWorld]?.trackStrip;
  ui.Image? get valleyFloor => _worldBundles[_currentWorld]?.valleyFloor;
  ui.Image? get canyonWall => _worldBundles[_currentWorld]?.canyonWall;
  ui.Image? get skyCitadel => _worldBundles[_currentWorld]?.skyCitadel;
  ui.Image? get corridorPillar => _worldBundles[_currentWorld]?.corridorPillar;
  ui.Image? get floatingIsland => _worldBundles[_currentWorld]?.floatingIsland;
  ui.Image? get cliffSide => _worldBundles[_currentWorld]?.cliffSide;

  double get introCameraBlend {
    switch (_stage) {
      case RunStage.titleHover:
        return 1.0;
      case RunStage.introFlight:
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
        var base = difficulty.speedAt(_elapsedSeconds);
        if (powerUps.isSolarDashing) {
          base *= GameConfig.solarDashSpeedBoost;
        }
        // Stage 3 Dimensional Breach Slingshot Curve: brief impact beat (`0.78x`)
        // followed by exhilarating `1.32x` warp burst into the new realm!
        if (isPortalWarping) {
          final u = portalWarpProgress;
          if (u < 0.12) {
            base *= 0.78 + 0.22 * (u / 0.12);
          } else if (u < 0.65) {
            final bell = math.sin(((u - 0.12) / 0.53) * math.pi);
            base *= 1.0 + 0.32 * bell;
          }
        }
        return base;
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
  // Non-Freezing `1/Z` 3D Perspective Camera + Warp FOV Surge
  // ---------------------------------------------------------------

  double get horizonY {
    final warpDip = isPortalWarping
        ? -math.sin(portalWarpProgress * math.pi) * size.y * 0.028
        : 0.0;
    return size.y *
            (GameConfig.horizonRatio +
                GameConfig.titleHorizonLiftRatio * introCameraBlend) +
        warpDip +
        cameraShakeOffset.dy;
  }

  double get playerPlaneY =>
      size.y * (GameConfig.playerPlaneRatio + 0.06 * introCameraBlend) +
      cameraShakeOffset.dy * 0.55;

  double get roadCurveFactor {
    if (_stage != RunStage.running) {
      return 0.0;
    }
    // Straighten road gently when approaching the Abyssal Portal so the cliff
    // termination & grand gateway frame heroically center-screen!
    final cutoff = activePortalCutoffDepth;
    final portalStraighten = cutoff != null
        ? (cutoff / 0.85).clamp(0.15, 1.0).toDouble()
        : 1.0;
    return (math.sin(_travelled * 0.00135) * 0.65 +
            math.sin(_travelled * 0.00055) * 0.35) *
        portalStraighten;
  }

  double curveOffsetForDepth(double depth) {
    if (depth <= 0.0) {
      return 0.0;
    }
    final d = depth.clamp(0.0, 1.35).toDouble();
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
        .clamp(0.16, 12.0)
        .toDouble();
    return 1.0 / z;
  }

  double depthForScreenY(double y) {
    final span = math.max(1.0, playerPlaneY - horizonY);
    const pFar = GameConfig.farScale;
    final t = (y - horizonY) / span;
    final p = (pFar + t * (1.0 - pFar)).clamp(0.085, 6.25).toDouble();
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
        cameraShakeOffset.dx +
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
  void updateTree(double dt) {
    final clampedDt = dt.clamp(0.0, maxFrameDt).toDouble();
    super.updateTree(clampedDt);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _generator = SeededObstacleGenerator(seed: _seed);
    unawaited(ProgressStore.load().then((store) {
      if (!_disposed) {
        _progress = store;
      }
    }));
    unawaited(_preloadArt());

    add(TrackScene());
    player = SoulPlayer();
    add(player);
    if (_stage == RunStage.introFlight) {
      _seedInitialVistaElements();
    }
  }

  @override
  void onRemove() {
    _disposed = true;
    _activePortal = null;
    _worldBundles.clear();
    _worldLoadFutures.clear();
    soulSprite?.dispose();
    soulSprite = null;
    images.clearCache();
    super.onRemove();
  }

  Future<ui.Image?> _tryLoadImage(String key, String label) async {
    if (_disposed) {
      return null;
    }
    try {
      return await images.load(key);
    } catch (error) {
      debugPrint('$label unavailable ($error). Using canvas fallback.');
      return null;
    }
  }

  Future<_WorldArtBundle> _ensureWorldBundle(GameWorld world) {
    final existing = _worldBundles[world];
    if (existing != null) {
      return Future<_WorldArtBundle>.value(existing);
    }
    return _worldLoadFutures.putIfAbsent(world, () async {
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
      if (!_disposed) {
        _worldBundles[world] = bundle;
      }
      return bundle;
    });
  }

  Future<void> _preloadArt() async {
    soulHoverOpenSprite = await _tryLoadImage(
      GameConfig.soulHoverOpenSpriteKey,
      'Soul close-up hover open-eyes',
    );
    soulHoverBlinkSprite = await _tryLoadImage(
      GameConfig.soulHoverBlinkSpriteKey,
      'Soul close-up hover blink-eyes',
    );
    if (_disposed) {
      return;
    }
    await _ensureWorldBundle(_selectedWorld);
    if (_disposed) {
      return;
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

    if (_disposed) {
      return;
    }

    try {
      final loaded = <ui.Image>[];
      for (var i = 1; i <= GameConfig.runFrameCount; i++) {
        if (_disposed) {
          return;
        }
        final index = i.toString().padLeft(2, '0');
        loaded.add(
          await images.load('${GameConfig.runFramesPrefix}$index.png'),
        );
        if (i % 6 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (!_disposed) {
        runFrames = loaded;
      }
    } catch (error) {
      debugPrint('Run-cycle frames unavailable ($error). Loading fallback.');
      runFrames = const [];
      if (!_disposed) {
        try {
          soulSprite = await loadKeyedSprite(GameConfig.soulSpriteAsset);
        } catch (_) {
          soulSprite = null;
        }
      }
    }

    final nextWorld = GameConfig.nextWorldAfter(_currentWorld);
    if (!_disposed) {
      await Future<void>.delayed(Duration.zero);
      await _ensureWorldBundle(nextWorld);
    }
  }

  Future<void> selectWorld(GameWorld world) async {
    _selectedWorld = world;
    await _ensureWorldBundle(world);
    if (_disposed) {
      return;
    }
    returnToTitleHover();
    final nextWorld = GameConfig.nextWorldAfter(world);
    unawaited(_ensureWorldBundle(nextWorld));
  }

  int _computeHudSignature() {
    return Object.hash(
      _stage,
      _ended,
      _currentWorld,
      showPortalArrivalBanner,
      score.totalScore,
      score.orbsCollected,
      powerUps.hasShield,
      powerUps.canActivateShield,
      powerUps.shieldRemaining.ceil(),
      powerUps.shieldCooldownRemaining.ceil(),
      powerUps.isSolarDashing ? powerUps.dashRemaining.ceil() : 0,
      powerUps.hasSuperSneakers ? powerUps.sneakersRemaining.ceil() : 0,
      powerUps.hasMagnet ? powerUps.magnetRemaining.ceil() : 0,
      powerUps.hasMultiplier ? powerUps.multiplierRemaining.ceil() : 0,
    );
  }

  void _notifyHudIfChanged({bool force = false}) {
    final sig = _computeHudSignature();
    if (force || sig != _lastHudSignature) {
      _lastHudSignature = sig;
      hudTick.value += 1;
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

    if (_cameraShakeTimer > 0) {
      _cameraShakeTimer = math.max(0.0, _cameraShakeTimer - dt);
      if (_cameraShakeTimer <= 0) {
        _cameraShakeIntensity = 0;
      }
    }

    if (_portalWarpTimer > 0) {
      _portalWarpTimer = math.max(0.0, _portalWarpTimer - dt);
    }
    if (_portalBannerTimer > 0) {
      _portalBannerTimer = math.max(0.0, _portalBannerTimer - dt);
      if (_portalBannerTimer <= 0) {
        _notifyHudIfChanged(force: true);
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
        triggerCameraShake(3.8, duration: 0.24);
        if (player.isMounted) {
          player.onIntroTouchdown();
          final landingPos = Vector2(
            player.position.x,
            playerPlaneY + player.size.y * 0.28,
          );
          add(VfxBurst.jumpRipple(landingPos));
          add(VfxBurst.orbCollect(landingPos));
        }
        _notifyHudIfChanged(force: true);
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

    // Freeze wave & portal distance accumulation while an Abyssal Portal sits
    // ahead so NOTHING ever spawns behind the end-of-world portal threshold!
    if (!hasPendingPortal) {
      _distanceSinceWave += ds;
      if (!isPortalWarping) {
        _distanceSincePortal += ds;
      }
    }

    if (powerUps.isSolarDashing && !hasPendingPortal) {
      _dashOrbTimer += dt;
      if (_dashOrbTimer >= 0.17) {
        _dashOrbTimer = 0;
        add(EnergyOrb(
          lane: laneSystem.lane,
          initialDepth: 1.18,
          elevation: 1.38,
        ));
      }
    } else {
      _dashOrbTimer = 0;
    }

    if (!hasPendingPortal && _distanceSinceWave >= _distanceToNextWave) {
      _spawnWave();
    }

    score.addDistance(ds, multiplier: powerUps.scoreMultiplier);
    _notifyHudIfChanged();
  }

  // --------------------------------------------------------------- gameplay

  void startRun() {
    if (_stage != RunStage.titleHover || _ended || paused) {
      return;
    }
    _stage = RunStage.introFlight;
    _introProgress = 0.0;
    _seedInitialVistaElements();
    if (player.isMounted && size.x > 0 && size.y > 0) {
      final skyBurstPos = Vector2(size.x * 0.35, size.y * 0.43);
      add(VfxBurst.shieldShatter(skyBurstPos));
    }
    _notifyHudIfChanged(force: true);
  }

  void _seedInitialVistaElements() {
    const ribbonLanes = [1, 1, 2, 2, 1, 0, 0, 1];
    for (var i = 0; i < ribbonLanes.length; i++) {
      add(EnergyOrb(
        lane: ribbonLanes[i],
        initialDepth: 0.60 + i * 0.06,
        fadeInSeconds: 0.36 + i * 0.03,
      ));
    }

    add(Obstacle(
      lane: 2,
      kind: ObstacleKind.trainWithRamp,
      initialDepth: 0.86,
      fadeInSeconds: 0.42,
    ));
    for (var k = 0; k < 4; k++) {
      final u = (k + 0.5) / 4;
      add(EnergyOrb(
        lane: 2,
        initialDepth: 0.91 + k * 0.045,
        elevation: math.sin(u * math.pi) * 1.25,
        fadeInSeconds: 0.44,
      ));
    }

    add(PowerUpPickup(
      lane: 0,
      kind: PowerUpKind.magnet,
      initialDepth: 1.04,
      fadeInSeconds: 0.45,
    ));
  }

  /// Triggered at the exact instant Soul leaps across the Abyssal Portal
  /// threshold: shatters the dimensional barrier, shakes the camera, launches
  /// the `1.35s` Hyperspace Rift Vortex, and unfurls the new world's causeway!
  void enterCrystalPortal(GameWorld nextWorld) {
    if (_ended) {
      return;
    }
    _currentWorld = nextWorld;
    unawaited(_ensureWorldBundle(nextWorld));
    unawaited(_ensureWorldBundle(GameConfig.nextWorldAfter(nextWorld)));

    _portalWarpTimer = portalWarpDurationSeconds;
    _portalBannerTimer = 3.2;
    _distanceSinceWave = 0;
    _distanceToNextWave = 360;
    triggerCameraShake(8.5, duration: 0.44);

    for (final obs in children.whereType<Obstacle>().toList()) {
      if (!obs.isGoldenBounceCloud) {
        obs.dissolveOut();
      }
    }
    if (player.isMounted) {
      final burstPos = Vector2(player.position.x, playerPlaneY - size.y * 0.08);
      add(VfxBurst.shieldShatter(burstPos));
      add(VfxBurst.jumpRipple(
        Vector2(player.position.x, playerPlaneY + player.size.y * 0.22),
      ));
    }
    _notifyHudIfChanged(force: true);
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
    triggerCameraShake(4.2, duration: 0.24);
    add(VfxBurst.shieldShatter(cloudCenter));
    _notifyHudIfChanged();
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
      triggerCameraShake(3.2, duration: 0.20);
      add(VfxBurst.shieldShatter(player.position.clone()));
      _notifyHudIfChanged(force: true);
    }
    return activated;
  }

  bool onObstacleImpact(Vector2 impactCenter) {
    if (_ended) {
      return false;
    }
    // Dimensional breach rush grants brief Rift Invulnerability!
    if (isPortalWarping && portalWarpProgress < 0.72) {
      add(VfxBurst.shieldShatter(impactCenter));
      return true;
    }
    if (powerUps.consumeShieldOnHit()) {
      _stumbleTimer = 0;
      triggerCameraShake(6.5, duration: 0.32);
      for (final obs in children.whereType<Obstacle>().toList()) {
        if (!obs.isGoldenBounceCloud && obs.frontDepth <= 0.28) {
          obs.dissolveOut();
        }
      }
      add(VfxBurst.shieldShatter(impactCenter));
      _notifyHudIfChanged(force: true);
      return true;
    }
    onPlayerHit();
    return false;
  }

  void onObstacleSideStumble(int blockedLane, Vector2 contactPoint) {
    if (_ended) {
      return;
    }
    if (isPortalWarping && portalWarpProgress < 0.72) {
      return;
    }
    if (_stumbleTimer > 0) {
      onObstacleImpact(contactPoint);
      return;
    }
    laneSystem.bounceFromBlockedLane(blockedLane);
    _stumbleTimer = GameConfig.stumbleRecoverySeconds;
    triggerCameraShake(5.0, duration: 0.28);
    add(VfxBurst.orbCollect(contactPoint));
    _notifyHudIfChanged();
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
    _notifyHudIfChanged(force: true);
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
    _notifyHudIfChanged();
  }

  void onPowerUpCollected(PowerUpKind kind, Vector2 position) {
    if (_ended) {
      return;
    }
    powerUps.activate(kind);
    add(VfxBurst.shieldShatter(position));
    _notifyHudIfChanged(force: true);
  }

  void _spawnWave() {
    // Stage 3 Abyssal Portal Spawn: terminates the current world at `portalDepth`
    // and freezes all subsequent wave spawns until Soul breaches into `targetBiome`!
    if (_distanceSincePortal >= GameConfig.portalIntervalDistance) {
      _distanceSincePortal = 0;
      _distanceSinceWave = 0;
      _distanceToNextWave = 420;

      final targetBiome = GameConfig.nextWorldAfter(_currentWorld);
      unawaited(_ensureWorldBundle(targetBiome));

      const portalDepth = 1.22;
      final gate = CrystalPortalGate(
        targetWorld: targetBiome,
        initialDepth: portalDepth,
      );
      _activePortal = gate;
      add(gate);

      // Guiding golden sun-orb runway strictly IN FRONT of the portal threshold
      // (`0.84..1.12 < 1.22` — ZERO items behind the portal!)
      for (var i = 0; i < 6; i++) {
        add(EnergyOrb(
          lane: 1,
          initialDepth: 0.84 + i * 0.052,
        ));
      }
      add(EnergyOrb(lane: 0, initialDepth: 1.04));
      add(EnergyOrb(lane: 2, initialDepth: 1.04));
      return;
    }

    final wave = _generator.nextWave(
      speed: currentSpeed,
      difficulty: difficulty.levelAt(_elapsedSeconds),
    );
    _distanceSinceWave = 0;
    _distanceToNextWave = wave.distanceToNext;

    const waveCoreDepth = 1.18;
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
          initialDepth: 1.06 + i * 0.048,
        ));
      }
    }

    final bonusLane = wave.bonusOrbLane;
    if (bonusLane != null) {
      for (var i = 0; i < 3; i++) {
        add(EnergyOrb(
          lane: bonusLane,
          initialDepth: 1.12 + i * 0.052,
        ));
      }
    }

    final arcLane = wave.jumpArcLane;
    if (arcLane != null && !powerUps.isSolarDashing) {
      const arcCount = 6;
      for (var i = 0; i < arcCount; i++) {
        final t = i / (arcCount - 1);
        add(EnergyOrb(
          lane: arcLane,
          initialDepth: 1.11 + i * 0.036,
          elevation: math.sin(t * math.pi) * 0.96,
        ));
      }
    }

    final slideLane = wave.slideTunnelLane;
    if (slideLane != null && !powerUps.isSolarDashing) {
      const tunnelOrbs = 5;
      for (var i = 0; i < tunnelOrbs; i++) {
        add(EnergyOrb(
          lane: slideLane,
          initialDepth: 1.13 + i * 0.038,
          elevation: 0.0,
        ));
      }
    }

    final bounceLane = wave.roofCoinLane;
    if (bounceLane != null && !powerUps.isSolarDashing) {
      const skyArcCount = 6;
      for (var i = 0; i < skyArcCount; i++) {
        final u = (i + 0.5) / skyArcCount;
        add(EnergyOrb(
          lane: bounceLane,
          initialDepth: waveCoreDepth + 0.04 + i * 0.058,
          elevation: math.sin(u * math.pi) * 1.34,
        ));
      }
    }

    if (wave.powerUpLane != null && wave.powerUpKind != null) {
      add(PowerUpPickup(
        lane: wave.powerUpLane!,
        kind: wave.powerUpKind!,
        initialDepth: 1.24,
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
    _activePortal = null;
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
    if (player.isMounted) {
      player.reset();
    }

    _currentWorld = _selectedWorld;
    _elapsedSeconds = 0;
    _travelled = 0;
    _distanceSinceWave = 0;
    _distanceSincePortal = 0;
    _distanceToNextWave = GameConfig.firstWaveDistance;
    _dashOrbTimer = 0;
    _cameraLane = GameConfig.initialLane.toDouble();
    _stumbleTimer = 0;
    _portalWarpTimer = 0;
    _portalBannerTimer = 0;
    _cameraShakeTimer = 0;
    _cameraShakeIntensity = 0;
    _ended = false;
  }

  void resetRun() {
    _runNumber += 1;
    _generator = SeededObstacleGenerator(seed: _seed + _runNumber);
    _clearWorldEntities();

    _stage = RunStage.introFlight;
    _introProgress = 0.0;
    _seedInitialVistaElements();

    overlays.remove(gameOverOverlayId);
    overlays.remove(pauseOverlayId);
    if (paused) {
      resumeEngine();
    }
    _notifyHudIfChanged(force: true);
  }

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
    _notifyHudIfChanged(force: true);
  }
}
