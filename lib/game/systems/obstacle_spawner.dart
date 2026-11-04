import 'dart:math';

import '../config/game_config.dart';
import 'power_up_system.dart';

/// S15 Subway-Surfers-Grade 3D Obstacle & Terrain Archetypes:
///  * [lowSpikes] — 3D red-and-white track barrier -> JUMP OVER;
///  * [highArch] — 3D tall overhead roll gate -> SLIDE / ROLL UNDER;
///  * [tallMonolith] — True-3D extruded Subway Train carriage (dodge sideways,
///    OR leap onto its walkable roof with Super Sneakers / from another train!);
///  * [trainWithRamp] — True-3D extruded Subway Train WITH a sloped wooden
///    Boarding Ramp in front -> RUN STRAIGHT UP ONTO THE TRAIN ROOF!
enum ObstacleKind {
  lowSpikes,
  highArch,
  tallMonolith,
  trainWithRamp,
}

enum WavePatternKind {
  hurdleVault,
  gantryTunnel,
  rampedTrainRun,
  slalomFlow,
  decisionGate,
}

/// One authored Subway-Surfers-style spawn wave.
class SpawnWave {
  const SpawnWave({
    required this.blockedLanes,
    required this.orbLane,
    required this.distanceToNext,
    this.pattern = WavePatternKind.slalomFlow,
    this.obstacleKinds = const {},
    this.movingTrainLanes = const {},
    this.orbTrailCount = 1,
    this.slalomLanes,
    this.jumpArcLane,
    this.slideTunnelLane,
    this.roofCoinLane,
    this.powerUpLane,
    this.powerUpKind,
  });

  final Set<int> blockedLanes;
  final int? orbLane;
  final double distanceToNext;
  final WavePatternKind pattern;
  final Map<int, ObstacleKind> obstacleKinds;

  /// Subset of [blockedLanes] whose 3D train is an oncoming Red Express Train.
  final Set<int> movingTrainLanes;

  final int orbTrailCount;
  final List<int>? slalomLanes;
  final int? jumpArcLane;
  final int? slideTunnelLane;

  /// Lane with a `trainWithRamp` carrying ramp-climb + roof-top gold coins!
  final int? roofCoinLane;

  final int? powerUpLane;
  final PowerUpKind? powerUpKind;

  ObstacleKind kindForLane(int lane) =>
      obstacleKinds[lane] ?? ObstacleKind.lowSpikes;

  bool isMovingTrain(int lane) => movingTrainLanes.contains(lane);
}

/// Generates authored Subway-Surfers-style patterns (ramped 3D trains with
/// walkable roofs, moving express trains, jump hurdles, roll gates, and curved
/// coin guides) from a seeded RNG.
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
  int _lastSafeLane = GameConfig.initialLane;

  double minGapFor(double speed) {
    assert(speed > 0, 'speed must be positive');
    final worstCaseSwitches =
        GameConfig.laneSwitchSeconds * (laneCount - 1);
    final maneuverSeconds =
        max(worstCaseSwitches, GameConfig.jumpDurationSeconds * 0.88);
    return speed * (GameConfig.reactionTimeSeconds + maneuverSeconds);
  }

  WavePatternKind _selectPattern(double d) {
    if (_waveIndex == 1 && d < 0.25) {
      return WavePatternKind.hurdleVault;
    }
    if (_waveIndex == 2 && d < 0.25) {
      return WavePatternKind.rampedTrainRun;
    }
    if (_waveIndex == 3 && d < 0.25) {
      return WavePatternKind.gantryTunnel;
    }

    final roll = _random.nextDouble();
    final gateChance = (laneCount > 2)
        ? GameConfig.twoLaneBlockBaseChance +
            (GameConfig.twoLaneBlockMaxChance -
                    GameConfig.twoLaneBlockBaseChance) *
                d
        : 0.0;
    if (roll < gateChance) {
      return WavePatternKind.decisionGate;
    }
    final sub = _random.nextDouble();
    if (sub < 0.30) {
      return WavePatternKind.rampedTrainRun;
    }
    if (sub < 0.56) {
      return WavePatternKind.hurdleVault;
    }
    if (sub < 0.80) {
      return WavePatternKind.gantryTunnel;
    }
    return WavePatternKind.slalomFlow;
  }

  SpawnWave nextWave({required double speed, double difficulty = 0}) {
    assert(speed > 0, 'speed must be positive');
    _waveIndex += 1;
    final d = difficulty.clamp(0.0, 1.0).toDouble();

    final pattern = _selectPattern(d);
    final blocked = <int>{};
    final kinds = <int, ObstacleKind>{};
    final moving = <int>{};

    switch (pattern) {
      case WavePatternKind.hurdleVault:
        final lane = _random.nextInt(laneCount);
        blocked.add(lane);
        kinds[lane] = ObstacleKind.lowSpikes;

      case WavePatternKind.gantryTunnel:
        final lane = _random.nextInt(laneCount);
        blocked.add(lane);
        kinds[lane] = ObstacleKind.highArch;

      case WavePatternKind.rampedTrainRun:
        final lane = _random.nextInt(laneCount);
        blocked.add(lane);
        kinds[lane] = ObstacleKind.trainWithRamp;

      case WavePatternKind.slalomFlow:
        final preferred = _lastSafeLane.clamp(0, laneCount - 1);
        final lane =
            _random.nextDouble() < 0.72 ? preferred : _random.nextInt(laneCount);
        blocked.add(lane);
        kinds[lane] = ObstacleKind.tallMonolith;
        if (_waveIndex >= 5 && _random.nextDouble() < (0.22 + 0.35 * d)) {
          moving.add(lane);
        }

      case WavePatternKind.decisionGate:
        final first = _random.nextInt(laneCount);
        var second = _random.nextInt(laneCount);
        while (second == first) {
          second = _random.nextInt(laneCount);
        }
        blocked
          ..add(first)
          ..add(second);
        // At most ONE impassable `tallMonolith` train; second lane is either a
        // climbable `trainWithRamp`, jumpable `lowSpikes`, or roll `highArch`!
        kinds[first] = _random.nextDouble() < (0.55 + 0.25 * d)
            ? ObstacleKind.tallMonolith
            : ObstacleKind.trainWithRamp;
        if (kinds[first] == ObstacleKind.tallMonolith &&
            _waveIndex >= 5 &&
            _random.nextDouble() < (0.20 + 0.32 * d)) {
          moving.add(first);
        }
        final secRoll = _random.nextDouble();
        kinds[second] = secRoll < 0.38
            ? ObstacleKind.trainWithRamp
            : (secRoll < 0.70
                ? ObstacleKind.lowSpikes
                : ObstacleKind.highArch);
    }

    assert(blocked.length < laneCount);

    final freeLanes = <int>[
      for (var i = 0; i < laneCount; i++)
        if (!blocked.contains(i)) i,
    ];

    int? orbLane;
    var orbTrailCount = 0;
    List<int>? slalomLanes;
    if (_random.nextDouble() < GameConfig.orbChance) {
      orbLane = freeLanes[_random.nextInt(freeLanes.length)];
      orbTrailCount = 4 + _random.nextInt(2);
      if (_lastSafeLane != orbLane &&
          !blocked.contains(_lastSafeLane) &&
          orbTrailCount >= 4) {
        final midLane = ((_lastSafeLane + orbLane) / 2).round();
        slalomLanes = <int>[
          _lastSafeLane,
          blocked.contains(midLane) ? orbLane : midLane,
          for (var k = 2; k < orbTrailCount; k++) orbLane,
        ];
      }
    }
    _lastSafeLane = orbLane ?? freeLanes.first;

    int? jumpArcLane;
    final lowLanes = <int>[
      for (final e in kinds.entries)
        if (e.value == ObstacleKind.lowSpikes) e.key,
    ];
    if (lowLanes.isNotEmpty &&
        (pattern == WavePatternKind.hurdleVault ||
            _random.nextDouble() < 0.65)) {
      jumpArcLane = lowLanes[_random.nextInt(lowLanes.length)];
    }

    int? slideTunnelLane;
    final archLanes = <int>[
      for (final e in kinds.entries)
        if (e.value == ObstacleKind.highArch) e.key,
    ];
    if (archLanes.isNotEmpty &&
        (pattern == WavePatternKind.gantryTunnel ||
            _random.nextDouble() < 0.75)) {
      slideTunnelLane = archLanes[_random.nextInt(archLanes.length)];
    }

    int? roofCoinLane;
    final rampLanes = <int>[
      for (final e in kinds.entries)
        if (e.value == ObstacleKind.trainWithRamp) e.key,
    ];
    if (rampLanes.isNotEmpty) {
      roofCoinLane = rampLanes[_random.nextInt(rampLanes.length)];
    }

    int? powerUpLane;
    PowerUpKind? powerUpKind;
    if (_waveIndex >= 3 && _random.nextDouble() < 0.24) {
      final candidateLanes = freeLanes.length > 1 && orbLane != null
          ? [for (final l in freeLanes) if (l != orbLane) l]
          : freeLanes;
      powerUpLane = candidateLanes[_random.nextInt(candidateLanes.length)];
      const allPowerUps = PowerUpKind.values;
      powerUpKind = allPowerUps[_random.nextInt(allPowerUps.length)];
    }

    // Add generous spacing whenever 3D trains are present so carriages never
    // overlap the next wave!
    final hasAnyTrain = kinds.values.any(
      (k) => k == ObstacleKind.tallMonolith || k == ObstacleKind.trainWithRamp,
    );
    final baseJitter = hasAnyTrain ? 1.52 : 1.18;
    final gap = minGapFor(speed) * (baseJitter + _random.nextDouble() * 0.34);

    return SpawnWave(
      blockedLanes: Set.unmodifiable(blocked),
      orbLane: orbLane,
      distanceToNext: gap,
      pattern: pattern,
      obstacleKinds: Map.unmodifiable(kinds),
      movingTrainLanes: Set.unmodifiable(moving),
      orbTrailCount: orbTrailCount,
      slalomLanes: slalomLanes == null ? null : List.unmodifiable(slalomLanes),
      jumpArcLane: jumpArcLane,
      slideTunnelLane: slideTunnelLane,
      roofCoinLane: roofCoinLane,
      powerUpLane: powerUpLane,
      powerUpKind: powerUpKind,
    );
  }
}
