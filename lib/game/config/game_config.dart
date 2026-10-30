/// All tunable gameplay values for SOUL: DUSK RUN live in this single
/// configuration file so balance changes stay small and reviewable.
///
/// Pure Dart: no Flutter/Flame imports, so it can be unit-tested directly.
class GameConfig {
  const GameConfig._();

  // ---- Lanes ----
  /// Number of lanes on the track.
  static const int laneCount = 3;

  /// Lane the player starts in (0 = leftmost).
  static const int initialLane = 1;

  // ---- Speed / difficulty ----
  /// Forward speed in world units per second at run start (S13: smooth,
  /// readable Subway-grade initial cadence under true 1/Z perspective).
  static const double startSpeed = 295;

  /// Hard upper cap for forward speed. Never exceeded.
  static const double maxSpeed = 640;

  /// Speed gained per second of survival.
  static const double speedRampPerSecond = 8.0;

  // ---- World geometry ----
  /// Abstract depth length of the track in world units. Entities spawn at
  /// depth 1 (the horizon) and reach the player at depth 0.
  static const double trackLength = 900;

  // ---- Spawning fairness ----
  /// Human reaction time budget (seconds) reserved before maneuvering.
  static const double reactionTimeSeconds = 0.48;

  /// Time needed for one lane switch (seconds). Snappy instant lane glide.
  static const double laneSwitchSeconds = 0.13;

  /// Chance (at difficulty 0) that a wave blocks two lanes instead of one.
  static const double twoLaneBlockBaseChance = 0.24;

  /// Chance (at difficulty 1) that a wave blocks two lanes instead of one.
  static const double twoLaneBlockMaxChance = 0.66;

  /// Chance that a wave also spawns a flowing energy-orb trail on a free lane.
  static const double orbChance = 0.82;

  /// Initial distance before the first wave spawns (lets the run settle in).
  static const double firstWaveDistance = 440;

  // ---- Score ----
  /// Points per world unit travelled.
  static const double scorePerWorldUnit = 0.02;

  /// Flat score for one collected orb.
  static const int orbScore = 10;

  // ---- True 1/Z 3D Pinhole Camera Projection (S13) ----
  /// Ratio of 3D camera distance at the horizon (`depth = 1`) to Soul's
  /// player plane (`depth = 0`). Governs unified `1 / Z` foreshortening so
  /// road width, entity scale, and stone paver density stay 1:1 locked from
  /// horizon to screen bottom without foreground stretching.
  static const double farDepthRatio = 4.8;

  /// Vertical position of the horizon line as a fraction of screen height.
  static const double horizonRatio = 0.34;

  /// Vertical position of the player plane as a fraction of screen height.
  static const double playerPlaneRatio = 0.84;

  /// Entity scale at the horizon (`depth = 1`), equal to `1 / farDepthRatio`.
  static const double farScale = 1.0 / farDepthRatio;

  /// Half-width of the track on the player plane (`depth = 0`), as a
  /// fraction of screen width. Extrapolates cleanly along `1 / Z` to ~0.55w
  /// at the bottom screen edge so raised stone parapets & lantern pylons
  /// stay framed on both sides.
  static const double trackBottomHalfWidthRatio = 0.45;

  /// Half-width of the track at the horizon (`depth = 1`), exact `1 / Z`
  /// foreshortening of [trackBottomHalfWidthRatio].
  static const double trackTopHalfWidthRatio =
      trackBottomHalfWidthRatio / farDepthRatio;

  /// Number of seamless vertical repeats of `track_strip.png` (`1024x2048`)
  /// per [trackLength] so foreground stone pavers stay >=1:1 crisp on 1080p+
  /// screens instead of stretching near Soul.
  static const double trackTileRepeats = 3.0;

  /// Lane center offset from track center as a fraction of current
  /// half-width. Matches the exact lane centers `(216, 512, 808) / 1024`
  /// between the 68px outer stone curbs of `track_strip.png` (`296 / 512`).
  static const double laneSpreadRatio = 0.578125;

  // ---- Entity sizing & forgiving hitboxes ----
  /// Player body width as a fraction of screen width.
  static const double playerWidthRatio = 0.26;

  /// Obstacle/orb base width as a fraction of screen width.
  static const double entityWidthRatio = 0.21;

  /// Hitbox size relative to the visual size (grace margin for fairness).
  static const double hitboxFactor = 0.72;

  /// Maximum `|playerLane - obstacleLane|` that registers a solid collision
  /// (Subway-style forgiving corner-dodge threshold).
  static const double collisionLaneThreshold = 0.36;

  // ---- 4-way vertical kinetics & Subway-tier power-ups ----
  /// Total duration of one full parabolic jump arc (seconds).
  static const double jumpDurationSeconds = 0.62;

  /// Normalized jump height (0..1) above which low crystal barriers are
  /// cleared (~89% of the jump arc clears cleanly).
  static const double jumpClearThreshold = 0.20;

  /// Peak jump lift on screen as a fraction of screen height.
  static const double jumpHeightRatio = 0.17;

  /// Descent speed multiplier when swiping down mid-air (fast-fall slam).
  static const double fastFallMultiplier = 3.8;

  /// Duration of a ground tuck-slide under overhead rune gates (seconds).
  static const double slideDurationSeconds = 0.54;

  /// Active duration of the crash-absorbing Solar Aegis shield (seconds).
  static const double solarShieldDuration = 8.0;

  /// Recharge cooldown after Solar Aegis expires or absorbs a crash (seconds).
  static const double solarShieldCooldown = 14.0;

  /// Active duration of the cross-lane Sun Magnet pickup (seconds).
  static const double magnetDuration = 8.0;

  /// Active duration of the 2x Solar Surge score multiplier pickup (seconds).
  static const double multiplierDuration = 10.0;

  /// Active duration of the airborne Sunburst Sky-Dash pickup (seconds).
  static const double solarDashDuration = 4.5;

  /// Forward speed boost factor while Sunburst Sky-Dash is active.
  static const double solarDashSpeedBoost = 1.55;

  // ---- Presentation assets ----
  static const String soulSpriteAsset = 'assets/images/soul/soul_hero.png';
  static const String soulJumpSpriteKey = 'soul/jump.png';
  static const String soulSlideSpriteKey = 'soul/slide.png';

  /// Flame `images` cache keys for baked-alpha prop sprites (relative to
  /// `assets/images/`).
  static const String orbSpriteAsset = 'props/energy_orb.png';
  static const String obstacleSpriteAsset = 'props/obstacle_spikes.png';
  static const String obstacleArchSpriteAsset = 'props/obstacle_arch.png';
  static const String obstacleMonolithSpriteAsset =
      'props/obstacle_monolith.png';

  /// Roadside 3D corridor lantern pillars per world (relative to `assets/images/`).
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

  /// Painted horizon anchor inside our `1200x1000` portrait sky/horizon
  /// backdrops (~685/1000 places the Citadel gate / Moon / Sunrise Mesa right
  /// on `horizonY`).
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

  /// Deep chasm & viaduct base tint per world (alpha > 0x40 per contract).
  static int trackFillArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xCC22123A;
      case GameWorld.moonveilMarsh:
        return 0xCC0C2630;
      case GameWorld.emberfallCanyon:
        return 0xCC2E1610;
    }
  }

  /// Viaduct parapet / rim accent per world.
  static int trackEdgeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xAA9E6BFF;
      case GameWorld.moonveilMarsh:
        return 0xAA5CE6D6;
      case GameWorld.emberfallCanyon:
        return 0xAAFF9E52;
    }
  }

  /// Lane rune glow per world.
  static int trackLaneArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0x66FFD166;
      case GameWorld.moonveilMarsh:
        return 0x667CF5E4;
      case GameWorld.emberfallCanyon:
        return 0x66FFC46B;
    }
  }

  /// Flowing depth-stripe / masonry joint highlight per world.
  static int trackStripeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0x558B65C9;
      case GameWorld.moonveilMarsh:
        return 0x5556B8B4;
      case GameWorld.emberfallCanyon:
        return 0x55C97448;
    }
  }

  /// Lantern aura color per world.
  static int lanternAuraArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xFFFFC857;
      case GameWorld.moonveilMarsh:
        return 0xFF64FFDA;
      case GameWorld.emberfallCanyon:
        return 0xFFFF8F00;
    }
  }

  // ---- World unlocking (S8) ----
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

  static const double backdropDriftAmplitude = 4;
  static const double cameraSwayPerLane = 8;
  static const int ambientParticleCount = 20;
  static const double playerBobRatio = 0.035;
  static const double playerLeanAngle = 0.14;

  // ---- Soul run-cycle animation ----
  static const String runFramesPrefix = 'soul/run/frame_';
  static const int runFrameCount = 8;
  static const double runCycleFps = 14;
  static const int runIdleFrame = 1;
  static const double runCycleFitBoost = 1.18;
}

/// Playable worlds. World choice changes assets/palette only — never
/// the gameplay projection, difficulty or identity.
enum GameWorld { duskHollow, moonveilMarsh, emberfallCanyon }
