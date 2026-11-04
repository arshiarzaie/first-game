/// All tunable gameplay values for SOUL: DUSK RUN live in this single
/// configuration file so balance changes stay small and reviewable.
///
/// Pure Dart: no Flutter/Flame imports, so it can be unit-tested directly.
class GameConfig {
  const GameConfig._();

  // ---- Lanes ----
  static const int laneCount = 3;
  static const int initialLane = 1;

  // ---- Speed / difficulty (S18: silky-smooth Soul Runner pacing) ----
  static const double startSpeed = 280;
  static const double maxSpeed = 540;
  static const double speedRampPerSecond = 5.5;

  /// Extra oncoming drift speed of Tempest Dark Storm Clouds.
  static const double movingTrainExtraSpeed = 95;

  // ---- World geometry ----
  static const double trackLength = 960;

  /// Normalized clearance threshold to soar cleanly above Dark Storm Clouds.
  static const double stormCloudClearElevation = 0.88;

  /// Peak height boost of a Golden Dawn Bounce-Cloud sky-arc (`1.45x` jump).
  static const double goldenCloudBounceMultiplier = 1.45;

  /// Duration scale of a Golden Dawn Bounce-Cloud sky-arc (`1.38x` floatier).
  static const double goldenCloudDurationScale = 1.38;

  // ---- Spawning fairness ----
  static const double reactionTimeSeconds = 0.52;
  static const double laneSwitchSeconds = 0.135;
  static const double twoLaneBlockBaseChance = 0.24;
  static const double twoLaneBlockMaxChance = 0.65;
  static const double orbChance = 0.88;
  static const double firstWaveDistance = 360;

  // ---- Score ----
  static const double scorePerWorldUnit = 0.025;
  static const int orbScore = 10;

  // ---- S18/S19 Low Over-the-Shoulder 3D Chase Camera & Sky-Flight Intro ----
  static const double farDepthRatio = 3.60;
  static const double horizonRatio = 0.38;
  static const double playerPlaneRatio = 0.75;
  static const double farScale = 1.0 / farDepthRatio;

  /// Extra sky framing on the Living Main Screen before camera swoops down.
  static const double titleHorizonLiftRatio = 0.08;

  /// Soul's living mid-air hover altitude on the Main Title Screen.
  static const double titleHoverElevation = 1.44;

  /// Peak soaring altitude reached right after clicking START before swooping
  /// down onto the ancient stone causeway.
  static const double introFlightPeakElevation = 1.84;

  /// Duration of Soul's animated sky-flight -> bridge touchdown sequence.
  static const double introFlightDurationSeconds = 1.24;

  /// Subtle sculpted 3D crown/arch of the ancient stone causeway.
  static const double bridgeArchRatio = 0.007;

  /// 3D elevation drop of the valley/water plane beneath the stone bridge.
  static const double valleyDropRatio = 0.085;

  /// Gentle scenic S-curve amplitude toward the distant horizon.
  static const double roadCurveRatio = 0.095;

  /// Half-width of the floating ancient stone bridge at Soul's plane.
  static const double trackBottomHalfWidthRatio = 0.355;
  static const double trackTopHalfWidthRatio =
      trackBottomHalfWidthRatio / farDepthRatio;

  static const double trackTileRepeats = 2.05;
  static const double valleyTileRepeats = 2.40;
  static const double cameraFollowRatio = 0.30;
  static const double laneSpreadRatio = 0.58;

  // ---- Entity sizing & forgiving side-bump stumble ----
  static const double playerWidthRatio = 0.255;
  static const double entityWidthRatio = 0.22;
  static const double hitboxFactor = 0.72;
  static const double collisionLaneThreshold = 0.27;
  static const double stumbleLaneThreshold = 0.43;
  static const double stumbleRecoverySeconds = 2.6;

  // ---- 4-way vertical kinetics & Soul Light Blessings ----
  static const double jumpDurationSeconds = 0.62;
  static const double jumpClearThreshold = 0.20;
  static const double jumpHeightRatio = 0.165;
  static const double fastFallMultiplier = 3.8;
  static const double slideDurationSeconds = 0.54;
  static const double superSneakersJumpMultiplier = 1.42;

  static const double solarShieldDuration = 10.0;
  static const double solarShieldCooldown = 12.0;
  static const double magnetDuration = 9.0;
  static const double multiplierDuration = 10.0;
  static const double superSneakersDuration = 10.0;
  static const double solarDashDuration = 4.8;
  static const double solarDashSpeedBoost = 1.50;

  // ---- Presentation assets ----
  static const String soulSpriteAsset = 'assets/images/soul/soul_hero.png';
  static const String soulJumpSpriteKey = 'soul/jump.png';
  static const String soulSlideSpriteKey = 'soul/slide.png';

  static const String orbSpriteAsset = 'props/energy_orb.png';
  static const String obstacleSpriteAsset = 'props/obstacle_spikes.png';
  static const String obstacleArchSpriteAsset = 'props/obstacle_arch.png';
  static const String obstacleMonolithSpriteAsset =
      'props/obstacle_monolith.png';
  static const String goldenCloudSpriteAsset = 'props/golden_cloud.png';
  static const String viaductRuinSpriteAsset = 'props/viaduct_ruin.png';
  static const String skyCloudSpriteAsset = 'props/sky_cloud.png';

  static const String duskHollowPillarKey =
      'worlds/dusk_hollow/corridor_pillar.png';
  static const String moonveilMarshPillarKey =
      'worlds/moonveil_marsh/corridor_pillar.png';
  static const String emberfallCanyonPillarKey =
      'worlds/emberfall_canyon/corridor_pillar.png';

  static String corridorPillarKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return duskHollowPillarKey;
      case GameWorld.moonveilMarsh:
        return moonveilMarshPillarKey;
      case GameWorld.emberfallCanyon:
        return emberfallCanyonPillarKey;
    }
  }

  static String floatingIslandKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 'worlds/dusk_hollow/floating_island.png';
      case GameWorld.moonveilMarsh:
        return 'worlds/moonveil_marsh/floating_island.png';
      case GameWorld.emberfallCanyon:
        return 'worlds/emberfall_canyon/floating_island.png';
    }
  }

  static String cliffSideKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 'worlds/dusk_hollow/cliff_side.png';
      case GameWorld.moonveilMarsh:
        return 'worlds/moonveil_marsh/cliff_side.png';
      case GameWorld.emberfallCanyon:
        return 'worlds/emberfall_canyon/cliff_side.png';
    }
  }

  static String valleyFloorKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 'worlds/dusk_hollow/valley_floor.png';
      case GameWorld.moonveilMarsh:
        return 'worlds/moonveil_marsh/valley_floor.png';
      case GameWorld.emberfallCanyon:
        return 'worlds/emberfall_canyon/valley_floor.png';
    }
  }

  static String canyonWallKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 'worlds/dusk_hollow/canyon_wall.png';
      case GameWorld.moonveilMarsh:
        return 'worlds/moonveil_marsh/canyon_wall.png';
      case GameWorld.emberfallCanyon:
        return 'worlds/emberfall_canyon/canyon_wall.png';
    }
  }

  static String skyCitadelKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 'worlds/dusk_hollow/sky_citadel.png';
      case GameWorld.moonveilMarsh:
        return 'worlds/moonveil_marsh/sky_citadel.png';
      case GameWorld.emberfallCanyon:
        return 'worlds/emberfall_canyon/sky_citadel.png';
    }
  }

  static const String duskHollowBackdropKey =
      'worlds/dusk_hollow/backdrop.png';
  static const String moonveilMarshBackdropKey =
      'worlds/moonveil_marsh/backdrop.png';
  static const String emberfallCanyonBackdropKey =
      'worlds/emberfall_canyon/backdrop.png';

  static const String duskHollowTrackStripKey =
      'worlds/dusk_hollow/track_strip.png';
  static const String moonveilMarshTrackStripKey =
      'worlds/moonveil_marsh/track_strip.png';
  static const String emberfallCanyonTrackStripKey =
      'worlds/emberfall_canyon/track_strip.png';

  static String? trackStripKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return duskHollowTrackStripKey;
      case GameWorld.moonveilMarsh:
        return moonveilMarshTrackStripKey;
      case GameWorld.emberfallCanyon:
        return emberfallCanyonTrackStripKey;
    }
  }

  static const double backdropHorizonFraction = 0.42;

  static String backdropKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return duskHollowBackdropKey;
      case GameWorld.moonveilMarsh:
        return moonveilMarshBackdropKey;
      case GameWorld.emberfallCanyon:
        return emberfallCanyonBackdropKey;
    }
  }

  static double backdropHorizonFractionFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
      case GameWorld.moonveilMarsh:
      case GameWorld.emberfallCanyon:
        return backdropHorizonFraction;
    }
  }

  static int trackFillArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xFF665884;
      case GameWorld.moonveilMarsh:
        return 0xFF3E707A;
      case GameWorld.emberfallCanyon:
        return 0xFFC28E5C;
    }
  }

  static int trackEdgeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xFF8E7EAE;
      case GameWorld.moonveilMarsh:
        return 0xFF4E828E;
      case GameWorld.emberfallCanyon:
        return 0xFFD69E68;
    }
  }

  static int trackLaneArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xCCF6C892;
      case GameWorld.moonveilMarsh:
        return 0xCC7AF2E2;
      case GameWorld.emberfallCanyon:
        return 0xCCFFCE70;
    }
  }

  static int trackStripeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0x66524670;
      case GameWorld.moonveilMarsh:
        return 0x662E5A64;
      case GameWorld.emberfallCanyon:
        return 0x669E7046;
    }
  }

  static int lanternAuraArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xFFFFCA68;
      case GameWorld.moonveilMarsh:
        return 0xFF6CF4E4;
      case GameWorld.emberfallCanyon:
        return 0xFFFFB454;
    }
  }

  static int worldUnlockSunsFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0;
      case GameWorld.moonveilMarsh:
        return 25;
      case GameWorld.emberfallCanyon:
        return 60;
    }
  }

  static const double backdropDriftAmplitude = 0.0;
  static const double cameraSwayPerLane = 12;
  static const int ambientParticleCount = 20;
  static const double playerBobRatio = 0.024;
  static const double playerLeanAngle = 0.15;

  // ---- Soul run-cycle animation ----
  static const String runFramesPrefix = 'soul/run/frame_';
  static const int runFrameCount = 8;
  static const double runCycleFps = 13.5;
  static const int runIdleFrame = 1;
  static const double runCycleFitBoost = 1.14;
}

enum GameWorld { duskHollow, moonveilMarsh, emberfallCanyon }
