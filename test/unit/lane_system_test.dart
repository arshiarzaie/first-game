import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/config/game_config.dart';
import 'package:soul_dusk_run/game/systems/lane_system.dart';

void main() {
  group('LaneSystem', () {
    test('starts in the configured initial lane', () {
      final lanes = LaneSystem();
      expect(lanes.lane, GameConfig.initialLane);
      expect(lanes.laneCount, GameConfig.laneCount);
    });

    test('moveLeft clamps at lane 0 on repeated moves', () {
      final lanes = LaneSystem();
      var movedAtLeastOnce = false;
      for (var i = 0; i < 10; i++) {
        movedAtLeastOnce = lanes.moveLeft() || movedAtLeastOnce;
      }
      expect(movedAtLeastOnce, isTrue);
      expect(lanes.lane, 0);
    });

    test('moveRight clamps at laneCount - 1 on repeated moves', () {
      final lanes = LaneSystem();
      for (var i = 0; i < 10; i++) {
        lanes.moveRight();
      }
      expect(lanes.lane, GameConfig.laneCount - 1);
    });

    test('lane index stays in [0, 2] for arbitrary move sequences', () {
      final lanes = LaneSystem();
      const moves = [
        true, false, true, true, false, false, true, false, true, false,
        false, true, true, true, false, true, false, false, false, true,
        true, false, true, false, true, true, false, true, false, true,
      ];
      for (final left in moves) {
        if (left) {
          lanes.moveLeft();
        } else {
          lanes.moveRight();
        }
        expect(lanes.lane, inInclusiveRange(0, GameConfig.laneCount - 1));
      }
    });

    test('reset returns to the initial lane', () {
      final lanes = LaneSystem()..moveLeft();
      expect(lanes.lane, 0);
      lanes.reset();
      expect(lanes.lane, GameConfig.initialLane);
    });
  });
}
