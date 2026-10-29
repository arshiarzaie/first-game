import 'dart:math';

import '../config/game_config.dart';
import 'power_up_system.dart';

/// Obstacle archetype (S12 Subway-tier vertical decision matrix):
///  * [lowSpikes]: ground shadow crystals — switch lanes OR jump over;
///  * [highArch]: overhead crystal beam — switch lanes OR slide under;
///  * [tallMonolith]: full-height obsidian pillar — must switch lanes.
enum ObstacleKind {
  lowSpikes,
  highArch,
  tallMonolith,
}

/// One spawn wave.
///
/// [blockedLanes] is the set of lane indices occupied by obstacles.
/// The fairness invariant `blockedLanes.length < laneCount` always holds,
/// so at least one lane is completely unobstructed in every wave.
///
/// [orbLane] optionally marks a free lane where a flowing trail of
/// [orbTrailCount] energy orbs spawns; it is never a blocked lane.
///
/// [jumpArcLane] optionally marks a [ObstacleKind.lowSpikes] lane topped
/// with a parabolic arc of airborne orbs rewarding a timed jump.
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
  /// always perform the worst-case maneuver (laneCount - 1 lane switches)
  /// plus the configured reaction time.
  double minGapFor(double speed) {
    assert(speed > 0, 'speed must be positive');
    final worstCaseSwitches = laneCount - 1;
    return speed *
        (GameConfig.reactionTimeSeconds +
            GameConfig.laneSwitchSeconds * worstCaseSwitches);
  }

  ObstacleKind _pickObstacleKind(double d) {
    final roll = _random.nextDouble();
    final monolithChance = 0.14 + 0.24 * d;
    final archChance = 0.28 + 0.10 * d;
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

    final kinds = <int, ObstacleKind>{
      for (final lane in blocked) lane: _pickObstacleKind(d),
    };

    final freeLanes = <int>[
      for (var i = 0; i < laneCount; i++)
        if (!blocked.contains(i)) i,
    ];

    int? orbLane;
    var orbTrailCount = 0;
    if (_random.nextDouble() < GameConfig.orbChance) {
      orbLane = freeLanes[_random.nextInt(freeLanes.length)];
      orbTrailCount = 3 + _random.nextInt(3); // 3..5 orbs in a Subway line
    }

    // Optional jump-reward arc over a lowSpikes obstacle.
    int? jumpArcLane;
    final lowLanes = <int>[
      for (final entry in kinds.entries)
        if (entry.value == ObstacleKind.lowSpikes) entry.key,
    ];
    if (lowLanes.isNotEmpty && _random.nextDouble() < 0.34) {
      jumpArcLane = lowLanes[_random.nextInt(lowLanes.length)];
    }

    // Periodic power-up pickup on a free lane (every ~4-5 waves).
    int? powerUpLane;
    PowerUpKind? powerUpKind;
    if (_waveIndex >= 2 && _random.nextDouble() < 0.22) {
      final candidateLanes = freeLanes.length > 1 && orbLane != null
          ? [for (final l in freeLanes) if (l != orbLane) l]
          : freeLanes;
      powerUpLane = candidateLanes[_random.nextInt(candidateLanes.length)];
      const allPowerUps = PowerUpKind.values;
      powerUpKind = allPowerUps[_random.nextInt(allPowerUps.length)];
    }

    // Spacing: 12%..58% slack above the fairness minimum so 4-orb trails fit
    // cleanly without overlapping the next wave.
    final jitterFactor = 1.12 + _random.nextDouble() * 0.46;
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
