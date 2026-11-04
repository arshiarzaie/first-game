/// All tunable gameplay values for SOUL: DUSK RUN live in this single
/// configuration file so balance changes stay small and reviewable.
///
/// Pure Dart: no Flutter/Flame imports, so it can be unit-tested directly.
class GameConfig {
  const GameConfig._();

  // ---- Lanes ----
  static const int laneCount = 3;
  static const int initialLane = 1;

  // ---- Speed / difficulty (S16: silky-smooth Soul Runner pacing) ----
  static const double startSpeed = 280;
  static const double maxSpeed = 540;
  static const double speedRampPerSecond = 5.5;

  /// Extra oncoming speed of awakened sliding Obsidian Rune Monoliths.
  static const double movingTrainExtraSpeed = 110;

  // ---- World geometry ----
  static const double trackLength = 960;

  /// 3D depth length of an elevated Ancient Stone Sanctuary Platform.
  static const double trainLengthDepth = 0.28;

  /// 3D depth length of a Carved Stone Stair-Ramp leading onto a platform.
  static const double rampLengthDepth = 0.052;

  /// Normalized elevation of walkable 3D Ancient Stone Platforms (`0.90`).
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

  // ---- S16 Cinematic `SOUL: DUSK RUN` 3D Camera (Concept Board Camera A) ----
  static const double farDepthRatio = 2.30;
  static const double horizonRatio = 0.28;
  static const double playerPlaneRatio = 0.78;
  static const double farScale = 1.0 / farDepthRatio;

  /// Half-width of the floating 3-lane ancient stone causeway at Soul's plane
  /// (`68%` width so both lush painted fantasy valley flanks stay visible!).
  static const double trackBottomHalfWidthRatio = 0.34;
  static const double trackTopHalfWidthRatio =
      trackBottomHalfWidthRatio / farDepthRatio;

  static const double trackTileRepeats = 1.5;
  static const double cameraFollowRatio = 0.30;
  static const double laneSpreadRatio = 0.58;

  // ---- Entity sizing & forgiving side-bump stumble ----
  static const double playerWidthRatio = 0.235;
  static const double entityWidthRatio = 0.215;
  static const double hitboxFactor = 0.72;
  static const double collisionLaneThreshold = 0.27;
  static const double stumbleLaneThreshold = 0.44;
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

  /// Horizon fraction of the full-portrait `900×1680` cinematic world vistas.
  static const double backdropHorizonFraction = 0.28;

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

  /// Ancient stone causeway base tint per world (alpha > 0x40).
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

  /// Carved stone parapet curb tint per world (alpha > 0x40).
  static int trackEdgeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xFF8876A8;
      case GameWorld.moonveilMarsh:
        return 0xFF5CA8AE;
      case GameWorld.emberfallCanyon:
        return 0xFFE2AE74;
    }
  }

  /// Glowing magical lane-channel rune light tint per world (alpha > 0x40).
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

  /// Subtle weathered stone joint tint per world (alpha > 0x40).
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
  static const double cameraSwayPerLane = 10;
  static const int ambientParticleCount = 0;
  static const double playerBobRatio = 0.024;
  static const double playerLeanAngle = 0.15;

  // ---- Soul run-cycle animation ----
  static const String runFramesPrefix = 'soul/run/frame_';
  static const int runFrameCount = 8;
  static const double runCycleFps = 13.5;
  static const int runIdleFrame = 1;
  static const double runCycleFitBoost = 1.12;
}

enum GameWorld { duskHollow, moonveilMarsh, emberfallCanyon }
