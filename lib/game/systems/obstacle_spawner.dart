import 'dart:math';

import '../config/game_config.dart';
import 'power_up_system.dart';

/// Obstacle archetype (S13 Subway-tier vertical decision matrix):
///  * [lowSpikes]: low faceted crystal barricade — switch lanes OR jump over;
///  * [highArch]: overhead rune portal gate — switch lanes OR slide under;
///  * [tallMonolith]: towering stone obelisk — must switch lanes.
enum ObstacleKind {
  lowSpikes,
  highArch,
  tallMonolith,
}

/// One spawn wave.
///
/// [blockedLanes] is the set of lane indices occupied by obstacles.
/// Fairness invariants:
///  1. `blockedLanes.length < laneCount` always holds (at least one open lane).
///  2. A 2-lane wave never places two [ObstacleKind.tallMonolith] walls side by
///     side — at least one blocked lane is vaultable or duckable.
class SpawnWave {
  const SpawnWave({
    required this.blockedLanes,
    required this.orbLane,
    required this.distanceToNext,
    this.obstacleKinds = const {},
    this.orbTrailCount = 1,
    this.jumpArcLane,
    this.powerUpLane,
    this.powerUpKind,
  });

  final Set<int> blockedLanes;
  final int? orbLane;
  final double distanceToNext;
  final Map<int, ObstacleKind> obstacleKinds;
  final int orbTrailCount;
  final int? jumpArcLane;
  final int? powerUpLane;
  final PowerUpKind? powerUpKind;

  ObstacleKind kindForLane(int lane) =>
      obstacleKinds[lane] ?? ObstacleKind.lowSpikes;
}

/// Generates obstacle waves from a seeded RNG so runs are reproducible
/// (same seed + same calls = identical sequence — unit-tested) and fair.
class SeededObstacleGenerator {
  SeededObstacleGenerator({
    int seed = 0,
    this.laneCount = GameConfig.laneCount,
    Random? random,
  })  : assert(laneCount >= 2, 'need at least 2 lanes for fair waves'),
        _random = random ?? Random(seed);

  final int laneCount;
  final Random _random;
  int _waveIndex = 0;

  /// Minimum forward distance between waves at [speed] so the player can
  /// complete either a full jump arc OR worst-case lane switches AND still
  /// have a full human reaction window before the next wave arrives (S13:
  /// eliminates unavoidable post-jump Wave-2 collisions).
  double minGapFor(double speed) {
    assert(speed > 0, 'speed must be positive');
    final worstCaseSwitches =
        GameConfig.laneSwitchSeconds * (laneCount - 1);
    final maneuverSeconds =
        max(worstCaseSwitches, GameConfig.jumpDurationSeconds * 0.86);
    return speed * (GameConfig.reactionTimeSeconds + maneuverSeconds);
  }

  ObstacleKind _pickObstacleKind(double d, {required bool allowMonolith}) {
    final roll = _random.nextDouble();
    final monolithChance = allowMonolith ? (0.12 + 0.24 * d) : 0.0;
    final archChance = 0.30 + 0.10 * d;
    if (roll < monolithChance) {
      return ObstacleKind.tallMonolith;
    }
    if (roll < monolithChance + archChance) {
      return ObstacleKind.highArch;
    }
    return ObstacleKind.lowSpikes;
  }

  SpawnWave nextWave({required double speed, double difficulty = 0}) {
    assert(speed > 0, 'speed must be positive');
    _waveIndex += 1;
    final d = difficulty.clamp(0.0, 1.0).toDouble();

    final blocked = <int>{_random.nextInt(laneCount)};

    // Gentle onboarding on Wave 1 at low difficulty so the run settles cleanly.
    final canBlockTwo = laneCount > 2 && !(_waveIndex == 1 && d < 0.15);
    final twoLaneChance = GameConfig.twoLaneBlockBaseChance +
        (GameConfig.twoLaneBlockMaxChance -
                GameConfig.twoLaneBlockBaseChance) *
            d;
    if (canBlockTwo && _random.nextDouble() < twoLaneChance) {
      var second = _random.nextInt(laneCount);
      while (blocked.contains(second)) {
        second = _random.nextInt(laneCount);
      }
      blocked.add(second);
    }

    assert(blocked.length < laneCount);

    // Assign archetypes while guaranteeing at most ONE tallMonolith per wave.
    final kinds = <int, ObstacleKind>{};
    var hasMonolith = false;
    final allowMonolithInWave = _waveIndex > 1 || d >= 0.15;
    for (final lane in blocked) {
      final kind = _pickObstacleKind(
        d,
        allowMonolith: allowMonolithInWave && !hasMonolith,
      );
      if (kind == ObstacleKind.tallMonolith) {
        hasMonolith = true;
      }
      kinds[lane] = kind;
    }

    final freeLanes = <int>[
      for (var i = 0; i < laneCount; i++)
        if (!blocked.contains(i)) i,
    ];

    int? orbLane;
    var orbTrailCount = 0;
    if (_random.nextDouble() < GameConfig.orbChance) {
      orbLane = freeLanes[_random.nextInt(freeLanes.length)];
      orbTrailCount = 3 + _random.nextInt(3); // 3..5 orbs in a clean line
    }

    // Optional jump-reward arc centered over a lowSpikes obstacle.
    int? jumpArcLane;
    final lowLanes = <int>[
      for (final entry in kinds.entries)
        if (entry.value == ObstacleKind.lowSpikes) entry.key,
    ];
    if (lowLanes.isNotEmpty && _random.nextDouble() < 0.38) {
      jumpArcLane = lowLanes[_random.nextInt(lowLanes.length)];
    }

    // Periodic power-up pickup on a free lane.
    int? powerUpLane;
    PowerUpKind? powerUpKind;
    if (_waveIndex >= 3 && _random.nextDouble() < 0.20) {
      final candidateLanes = freeLanes.length > 1 && orbLane != null
          ? [for (final l in freeLanes) if (l != orbLane) l]
          : freeLanes;
      powerUpLane = candidateLanes[_random.nextInt(candidateLanes.length)];
      const allPowerUps = PowerUpKind.values;
      powerUpKind = allPowerUps[_random.nextInt(allPowerUps.length)];
    }

    final jitterFactor = 1.14 + _random.nextDouble() * 0.42;
    final gap = minGapFor(speed) * jitterFactor;

    return SpawnWave(
      blockedLanes: Set.unmodifiable(blocked),
      orbLane: orbLane,
      distanceToNext: gap,
      obstacleKinds: Map.unmodifiable(kinds),
      orbTrailCount: orbTrailCount,
      jumpArcLane: jumpArcLane,
      powerUpLane: powerUpLane,
      powerUpKind: powerUpKind,
    );
  }
}
