import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/systems/difficulty_manager.dart';

void main() {
  group('DifficultyManager', () {
    const difficulty = DifficultyManager();

    test('speed at t=0 equals startSpeed', () {
      expect(difficulty.speedAt(0), difficulty.startSpeed);
    });

    test('speed is monotonically non-decreasing over time', () {
      var previous = 0.0;
      for (var t = 0.0; t <= 300; t += 0.5) {
        final speed = difficulty.speedAt(t);
        expect(speed, greaterThanOrEqualTo(previous),
            reason: 'speed dropped at t=$t');
        previous = speed;
      }
    });

    test('speed never exceeds the configured cap', () {
      for (var t in [10.0, 60.0, 300.0, 1e6, 1e12]) {
        expect(difficulty.speedAt(t), lessThanOrEqualTo(difficulty.maxSpeed));
      }
      expect(difficulty.speedAt(1e12), difficulty.maxSpeed);
    });

    test('levelAt stays within [0, 1] and reaches 1 at the cap', () {
      expect(difficulty.levelAt(0), 0);
      for (var t = 0.0; t <= 500; t += 7) {
        final level = difficulty.levelAt(t);
        expect(level, inInclusiveRange(0, 1));
      }
      expect(difficulty.levelAt(1e9), 1);
    });
  });
}
