import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/config/game_config.dart';
import 'package:soul_dusk_run/game/systems/obstacle_spawner.dart';

void main() {
  group('SeededObstacleGenerator (S15 Subway-Surfers 3D trains & ramps)', () {
    test('same seed produces an identical wave sequence (reproducible)', () {
      final a = SeededObstacleGenerator(seed: 42);
      final b = SeededObstacleGenerator(seed: 42);
      for (var i = 0; i < 50; i++) {
        final waveA = a.nextWave(speed: 360, difficulty: 0.5);
        final waveB = b.nextWave(speed: 360, difficulty: 0.5);
        expect(waveA.blockedLanes, waveB.blockedLanes);
        expect(waveA.orbLane, waveB.orbLane);
        expect(waveA.pattern, waveB.pattern);
        expect(waveA.roofCoinLane, waveB.roofCoinLane);
        expect(waveA.movingTrainLanes, waveB.movingTrainLanes);
        expect(waveA.distanceToNext, waveB.distanceToNext);
      }
    });

    test('different seeds produce different sequences', () {
      final a = SeededObstacleGenerator(seed: 1);
      final b = SeededObstacleGenerator(seed: 2);
      final signatureA = <String>[
        for (var i = 0; i < 20; i++)
          a.nextWave(speed: 400, difficulty: 1).blockedLanes.join(','),
      ];
      final signatureB = <String>[
        for (var i = 0; i < 20; i++)
          b.nextWave(speed: 400, difficulty: 1).blockedLanes.join(','),
      ];
      expect(signatureA, isNot(equals(signatureB)));
    });

    test('every wave leaves at least one open lane and aligns bonus trails '
        'with hurdles, roll gates, and ramped 3D trains', () {
      var sawJumpArc = false;
      var sawSlideTunnel = false;
      var sawRampedTrain = false;
      var sawMovingExpress = false;

      for (var seed = 0; seed < 120; seed++) {
        final generator = SeededObstacleGenerator(seed: seed);
        for (var speed = GameConfig.startSpeed;
            speed <= GameConfig.maxSpeed;
            speed += 50) {
          for (var difficulty = 0.0;
              difficulty <= 1.0;
              difficulty += 0.25) {
            final wave =
                generator.nextWave(speed: speed, difficulty: difficulty);

            expect(wave.blockedLanes.length, lessThan(GameConfig.laneCount));

            for (final lane in wave.blockedLanes) {
              expect(lane, inInclusiveRange(0, GameConfig.laneCount - 1));
            }

            final orbLane = wave.orbLane;
            if (orbLane != null) {
              expect(wave.blockedLanes.contains(orbLane), isFalse);
              expect(orbLane, inInclusiveRange(0, GameConfig.laneCount - 1));
            }

            if (wave.slalomLanes != null) {
              for (final sl in wave.slalomLanes!) {
                expect(wave.blockedLanes.contains(sl), isFalse);
              }
            }

            if (wave.jumpArcLane != null) {
              sawJumpArc = true;
              expect(
                  wave.kindForLane(wave.jumpArcLane!), ObstacleKind.lowSpikes);
            }

            if (wave.slideTunnelLane != null) {
              sawSlideTunnel = true;
              expect(wave.kindForLane(wave.slideTunnelLane!),
                  ObstacleKind.highArch);
            }

            if (wave.roofCoinLane != null) {
              sawRampedTrain = true;
              expect(wave.kindForLane(wave.roofCoinLane!),
                  ObstacleKind.trainWithRamp);
            }

            if (wave.movingTrainLanes.isNotEmpty) {
              sawMovingExpress = true;
              for (final ml in wave.movingTrainLanes) {
                expect(wave.kindForLane(ml), ObstacleKind.tallMonolith);
              }
            }
          }
        }
      }

      expect(sawJumpArc, isTrue);
      expect(sawSlideTunnel, isTrue);
      expect(sawRampedTrain, isTrue);
      expect(sawMovingExpress, isTrue);
    });

    test('wave spacing always covers worst-case maneuver time', () {
      final generator = SeededObstacleGenerator();
      for (var speed in [240.0, 360.0, 500.0, 640.0]) {
        for (var difficulty in [0.0, 0.5, 1.0]) {
          final wave = generator.nextWave(speed: speed, difficulty: difficulty);
          expect(
            wave.distanceToNext,
            greaterThanOrEqualTo(generator.minGapFor(speed)),
          );
        }
      }
    });

    test('minGapFor scales with speed and guarantees >=1.0s post-jump spacing',
        () {
      final generator = SeededObstacleGenerator();
      expect(generator.minGapFor(640), greaterThan(generator.minGapFor(240)));
      expect(generator.minGapFor(300) / 300, greaterThanOrEqualTo(1.0));
    });

    test('two-lane waves never place two impassable tallMonoliths side by side',
        () {
      final generator = SeededObstacleGenerator(seed: 99);
      for (var i = 0; i < 400; i++) {
        final wave = generator.nextWave(speed: 520, difficulty: 1.0);
        final monolithCount = wave.blockedLanes
            .where((l) => wave.kindForLane(l) == ObstacleKind.tallMonolith)
            .length;
        expect(monolithCount, lessThanOrEqualTo(1));
      }
    });
  });
}
