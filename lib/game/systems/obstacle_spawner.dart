import 'dart:math';

import '../config/game_config.dart';

/// One spawn wave.
///
/// [blockedLanes] is the set of lane indices occupied by obstacles.
/// The fairness invariant `blockedLanes.length < laneCount` always holds,
/// so at least one lane is passable in every wave.
///
/// [orbLane] optionally marks a lane where an energy orb spawns; it is never
/// a blocked lane.
///
/// [distanceToNext] is the forward distance (world units) before the next
/// wave may spawn. It always leaves room for the worst-case maneuver
/// (every lane switch the track can require) plus reaction time at the
/// current speed.
class SpawnWave {
  const SpawnWave({
    required this.blockedLanes,
    required this.orbLane,
    required this.distanceToNext,
  });

  final Set<int> blockedLanes;
  final int? orbLane;
  final double distanceToNext;
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

  /// Minimum forward distance between waves at [speed] so the player can
  /// always perform the worst-case maneuver (laneCount - 1 lane switches)
  /// plus the configured reaction time.
  double minGapFor(double speed) {
    assert(speed > 0, 'speed must be positive');
    final worstCaseSwitches = laneCount - 1;
    return speed *
        (GameConfig.reactionTimeSeconds +
            GameConfig.laneSwitchSeconds * worstCaseSwitches);
  }

  SpawnWave nextWave({required double speed, double difficulty = 0}) {
    assert(speed > 0, 'speed must be positive');
    final d = difficulty.clamp(0.0, 1.0).toDouble();

    final blocked = <int>{_random.nextInt(laneCount)};

    final twoLaneChance = GameConfig.twoLaneBlockBaseChance +
        (GameConfig.twoLaneBlockMaxChance -
                GameConfig.twoLaneBlockBaseChance) *
            d;
    if (laneCount > 2 && _random.nextDouble() < twoLaneChance) {
      var second = _random.nextInt(laneCount);
      while (blocked.contains(second)) {
        second = _random.nextInt(laneCount);
      }
      blocked.add(second);
    }

    // Fairness invariant: never block every lane.
    assert(blocked.length < laneCount);

    int? orbLane;
    if (_random.nextDouble() < GameConfig.orbChance) {
      final freeLanes = <int>[
        for (var i = 0; i < laneCount; i++)
          if (!blocked.contains(i)) i,
      ];
      orbLane = freeLanes[_random.nextInt(freeLanes.length)];
    }

    // Spacing: 5%..55% slack above the fairness minimum.
    final jitterFactor = 1.05 + _random.nextDouble() * 0.5;
    final gap = minGapFor(speed) * jitterFactor;

    return SpawnWave(
      blockedLanes: Set.unmodifiable(blocked),
      orbLane: orbLane,
      distanceToNext: gap,
    );
  }
}
