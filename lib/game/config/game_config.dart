/// All tunable gameplay values for SOUL: DUSK RUN live in this single
/// configuration file so balance changes stay small and reviewable.
///
/// Pure Dart: no Flutter/Flame imports, so it can be unit-tested directly.
class GameConfig {
  const GameConfig._();

  // ---- Lanes ----
  static const int laneCount = 3;
  static const int initialLane = 1;

  // ---- Speed / difficulty (S15: smooth Subway-Surfers pacing) ----
  static const double startSpeed = 280;
  static const double maxSpeed = 540;
  static const double speedRampPerSecond = 5.5;

  /// Extra oncoming speed of moving Crimson Express trains (world units/sec).
  static const double movingTrainExtraSpeed = 115;

  // ---- World geometry ----
  static const double trackLength = 960;

  /// 3D depth length of an extruded Subway Train carriage (`zFront -> zBack`).
  static const double trainLengthDepth = 0.28;

  /// 3D depth length of a sloped wooden Boarding Ramp in front of a train.
  static const double rampLengthDepth = 0.058;

  /// Normalized elevation of walkable 3D train roofs (`0.90` jump units).
  static const double trainRoofElevation = 0.90;

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

  // ---- S15 Rock-Steady Sunlit `2.30x` Subway-Surfers Camera ----
  static const double farDepthRatio = 2.30;
  static const double horizonRatio = 0.25;
  static const double playerPlaneRatio = 0.78;
  static const double farScale = 1.0 / farDepthRatio;

  /// Half-width of the 3-lane railway bed at Soul's plane (`70%` width).
  static const double trackBottomHalfWidthRatio = 0.35;
  static const double trackTopHalfWidthRatio =
      trackBottomHalfWidthRatio / farDepthRatio;

  static const double trackTileRepeats = 1.6;
  static const double cameraFollowRatio = 0.32;
  static const double laneSpreadRatio = 0.578125;

  // ---- Entity sizing & Subway-Surfers stumble fairness ----
  static const double playerWidthRatio = 0.22;
  static const double entityWidthRatio = 0.205;
  static const double hitboxFactor = 0.72;
  static const double collisionLaneThreshold = 0.27;
  static const double stumbleLaneThreshold = 0.44;
  static const double stumbleRecoverySeconds = 2.6;

  // ---- 4-way vertical kinetics & full Subway-Surfers power-up suite ----
  static const double jumpDurationSeconds = 0.62;
  static const double jumpClearThreshold = 0.20;
  static const double jumpHeightRatio = 0.165;
  static const double fastFallMultiplier = 3.8;
  static const double slideDurationSeconds = 0.54;

  /// Jump-height boost multiplier while Super Sneakers are active (`1.42x`
  /// vaults effortlessly onto full-height 3D train roofs!).
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

  static const double backdropHorizonFraction = 0.685;

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

  /// Bright sunlit ballast / boulevard ground tint per world (alpha > 0x40).
  static int trackFillArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xFFC8B8A6;
      case GameWorld.moonveilMarsh:
        return 0xFFACC4C2;
      case GameWorld.emberfallCanyon:
        return 0xFFCCA280;
    }
  }

  /// Sunlit sidewalk curb tint per world (alpha > 0x40).
  static int trackEdgeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xFFDACCBA;
      case GameWorld.moonveilMarsh:
        return 0xFFC2D6D4;
      case GameWorld.emberfallCanyon:
        return 0xFFE0B896;
    }
  }

  /// Sleek steel tram rail tint per world (alpha > 0x40).
  static int trackLaneArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xCC707A8C;
      case GameWorld.moonveilMarsh:
        return 0xCC627A86;
      case GameWorld.emberfallCanyon:
        return 0xCC7C6E6C;
    }
  }

  /// Soft low-contrast wooden sleeper tint per world (alpha > 0x40).
  static int trackStripeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0x66B09E8C;
      case GameWorld.moonveilMarsh:
        return 0x6698B0AE;
      case GameWorld.emberfallCanyon:
        return 0x66B68E6E;
    }
  }

  static int lanternAuraArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xFFFFCA58;
      case GameWorld.moonveilMarsh:
        return 0xFF64E2D8;
      case GameWorld.emberfallCanyon:
        return 0xFFFFA84C;
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
  static const int ambientParticleCount = 0;
  static const double playerBobRatio = 0.024;
  static const double playerLeanAngle = 0.16;

  // ---- Soul run-cycle animation ----
  static const String runFramesPrefix = 'soul/run/frame_';
  static const int runFrameCount = 8;
  static const double runCycleFps = 13.5;
  static const int runIdleFrame = 1;
  static const double runCycleFitBoost = 1.10;
}

enum GameWorld { duskHollow, moonveilMarsh, emberfallCanyon }
