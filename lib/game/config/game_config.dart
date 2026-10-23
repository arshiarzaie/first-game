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
  /// Forward speed in world units per second at run start.
  static const double startSpeed = 240;

  /// Hard upper cap for forward speed. Never exceeded.
  static const double maxSpeed = 640;

  /// Speed gained per second of survival.
  static const double speedRampPerSecond = 8;

  // ---- World geometry ----
  /// Abstract depth length of the track in world units. Entities spawn at
  /// depth 1 (the horizon) and reach the player at depth 0.
  static const double trackLength = 900;

  // ---- Spawning fairness ----
  /// Human reaction time budget (seconds) reserved before maneuvering.
  static const double reactionTimeSeconds = 0.45;

  /// Time needed for one lane switch (seconds). Used for fairness spacing.
  static const double laneSwitchSeconds = 0.15;

  /// Chance (at difficulty 0) that a wave blocks two lanes instead of one.
  static const double twoLaneBlockBaseChance = 0.25;

  /// Chance (at difficulty 1) that a wave blocks two lanes instead of one.
  static const double twoLaneBlockMaxChance = 0.65;

  /// Chance that a wave also spawns an energy orb on a free lane.
  static const double orbChance = 0.55;

  /// Initial distance before the first wave spawns (lets the run settle in).
  static const double firstWaveDistance = 700;

  // ---- Score ----
  /// Points per world unit travelled.
  static const double scorePerWorldUnit = 0.02;

  /// Flat score for one collected orb.
  static const int orbScore = 10;

  // ---- 2.5D projection ----
  /// Vertical position of the horizon line as a fraction of screen height.
  static const double horizonRatio = 0.30;

  /// Vertical position of the player plane as a fraction of screen height.
  static const double playerPlaneRatio = 0.86;

  /// Entity scale at the horizon (depth 1).
  static const double farScale = 0.16;

  /// Half-width of the track at the horizon, as a fraction of screen width.
  static const double trackTopHalfWidthRatio = 0.13;

  /// Half-width of the track at the bottom edge, as a fraction of screen width.
  static const double trackBottomHalfWidthRatio = 0.55;

  /// Lane center offset from track center as a fraction of current
  /// half-width (lane N sits at (N - 1) * this value for 3 lanes).
  static const double laneSpreadRatio = 0.66;

  /// Exponent of the depth->screen easing curve (>1 = slow far, fast near).
  static const double perspectiveExponent = 2.0;

  /// Scale easing exponent (gentler than the vertical easing).
  static const double scaleExponent = 1.3;

  // ---- Entity sizing ----
  /// Player body width as a fraction of screen width.
  static const double playerWidthRatio = 0.15;

  /// Obstacle/orb base width as a fraction of screen width.
  static const double entityWidthRatio = 0.16;

  /// Hitbox size relative to the visual size (grace margin for fairness).
  static const double hitboxFactor = 0.78;

  // ---- Presentation (P2 visual prototype) ----
  /// Bundle path of the Soul hero sprite. The PNG is rendered on a pure
  /// magenta plate; lib/game/presentation/chroma_key.dart converts that
  /// plate to real alpha at load time and crops to the character.
  static const String soulSpriteAsset = 'assets/images/soul/soul_hero.png';

  /// Flame `images` cache key for the Dusk Hollow backdrop (cache paths
  /// are relative to `assets/images/`).
  static const String duskHollowBackdropKey =
      'worlds/dusk_hollow/backdrop.png';

  /// Flame `images` cache key for the Moonveil Marsh backdrop (S4).
  static const String moonveilMarshBackdropKey =
      'worlds/moonveil_marsh/backdrop.png';

  /// Where the backdrop's painted horizon sits inside the image, as a
  /// fraction of image height (tuned to the current asset; S2 backdrop
  /// v2 carries its golden glow/citadel horizon at ~245/768).
  static const double backdropHorizonFraction = 0.319;

  // ---- World selection (S4) ----
  /// Asset/palette resolver per world. Presentation values only — the
  /// gameplay projection and difficulty numbers are identical in every
  /// world.
  static String backdropKeyFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return duskHollowBackdropKey;
      case GameWorld.moonveilMarsh:
        return moonveilMarshBackdropKey;
    }
  }

  /// Painted-horizon fraction of each world's backdrop (Moonveil's S4
  /// backdrop is squeezed to carry its citadel/moon horizon at the same
  /// ~245/768 mark as Dusk Hollow v2).
  static double backdropHorizonFractionFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
      case GameWorld.moonveilMarsh:
        return backdropHorizonFraction;
    }
  }

  /// Semi-transparent track fill per world (values carry the Dusk Hollow
  /// teal tint vs the Moonveil deep-night teal tint).
  static int trackFillArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0xB3241738;
      case GameWorld.moonveilMarsh:
        return 0xB30E2B32;
    }
  }

  /// Track edge glow per world.
  static int trackEdgeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0x884DD8FF;
      case GameWorld.moonveilMarsh:
        return 0x886FDCD2;
    }
  }

  /// Lane divider glow per world.
  static int trackLaneArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0x444DD8FF;
      case GameWorld.moonveilMarsh:
        return 0x446FDCD2;
    }
  }

  /// Flowing depth-stripe color per world.
  static int trackStripeArgbFor(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 0x44806FB8;
      case GameWorld.moonveilMarsh:
        return 0x448FBFC0;
    }
  }

  /// Gentle idle float of the world backdrop, in px (world breathing).
  static const double backdropDriftAmplitude = 5;

  /// Camera sway (px of backdrop shift) per lane of player offset — a
  /// subtle parallax cue that reinforces the elevated ¾ camera.
  static const double cameraSwayPerLane = 7;

  /// Count of ambient luminous motes drifting over the valley.
  static const int ambientParticleCount = 16;

  /// Player idle bob amplitude as a fraction of player height.
  static const double playerBobRatio = 0.045;

  /// Max roll angle (radians per lane of slide) while switching lanes.
  static const double playerLeanAngle = 0.16;

  // ---- Soul run-cycle animation (P3B) ----
  /// Flame `images` cache key prefix for the pre-keyed run frames; files
  /// are `frame_01.png` … `frame_08.png` under `assets/images/soul/run/`.
  static const String runFramesPrefix = 'soul/run/frame_';

  /// Number of frames in the approved run cycle.
  static const int runFrameCount = 8;

  /// Playback rate of the run cycle.
  static const double runCycleFps = 12;

  /// Frame index shown while Soul stands idle awaiting the first tap
  /// (frame 2 = weight-down pose: upright, both feet planted).
  static const int runIdleFrame = 1;

  /// Extra fit factor for run frames. The P3C frames hold the chibi
  /// humanoid silhouette at ≈ 76–82% of the 512×512 plate height (vs ≈
  /// 53% for the retired ball-design frames → boost scale ≈53/80); this
  /// boost normalizes the drawn silhouette to the established hero size.
  static const double runCycleFitBoost = 1.22;
}

/// Playable worlds (S4). Emberfall Canyon stays concept-only until its
/// stage ships. World choice changes assets/palette only — never the
/// gameplay projection, difficulty or identity.
enum GameWorld { duskHollow, moonveilMarsh }
