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
}
