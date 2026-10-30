import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/input/lane_gesture_controller.dart';

void main() {
  group('LaneGestureController (S13 instant pointer swipes & taps)', () {
    test('fires 4-way swipes immediately on pointer move before finger lift',
        () {
      final events = <String>[];
      final ctrl = LaneGestureController(
        onMove: (d) => events.add(d < 0 ? 'left' : 'right'),
        onJump: () => events.add('jump'),
        onSlide: () => events.add('slide'),
        isRunStarted: () => true,
      );

      // Swipe up -> jump fires BEFORE onPointerUp!
      ctrl.onPointerDown(1, 180, 400);
      ctrl.onPointerMove(1, 180, 370); // dy = -30
      expect(events, ['jump']);
      ctrl.onPointerUp(1, 180, 360, 360);
      expect(events, ['jump'], reason: 'release must not trigger extra tap');

      // Swipe down -> slide
      ctrl.onPointerDown(2, 180, 400);
      ctrl.onPointerMove(2, 182, 430); // dy = +30
      expect(events, ['jump', 'slide']);
      ctrl.onPointerUp(2, 182, 435, 360);

      // Swipe left & right
      ctrl.onPointerDown(3, 180, 400);
      ctrl.onPointerMove(3, 150, 402); // dx = -30
      ctrl.onPointerUp(3, 145, 402, 360);
      ctrl.onPointerDown(4, 180, 400);
      ctrl.onPointerMove(4, 210, 400); // dx = +30
      ctrl.onPointerUp(4, 215, 400, 360);
      expect(events, ['jump', 'slide', 'left', 'right']);
    });

    test('short incomplete vertical flick never misfires as sideways lane tap',
        () {
      final events = <String>[];
      final ctrl = LaneGestureController(
        onMove: (d) => events.add(d < 0 ? 'left' : 'right'),
        onJump: () => events.add('jump'),
        isRunStarted: () => true,
      );

      // 16px upward flick (> tapMaxSlop 10, < swipeDistanceThreshold 22)
      ctrl.onPointerDown(1, 80, 400); // on left half of screen!
      ctrl.onPointerMove(1, 80, 384);
      ctrl.onPointerUp(1, 80, 384, 360);
      expect(events, isEmpty,
          reason: 'must never accidentally move left when trying to flick up');
    });

    test('chains orthogonal L-swipe (lane switch -> slide) in one stroke', () {
      final events = <String>[];
      final ctrl = LaneGestureController(
        onMove: (d) => events.add(d < 0 ? 'left' : 'right'),
        onJump: () => events.add('jump'),
        onSlide: () => events.add('slide'),
        isRunStarted: () => true,
      );

      ctrl.onPointerDown(1, 180, 400);
      ctrl.onPointerMove(1, 152, 402); // -28px horizontal -> left
      ctrl.onPointerMove(1, 150, 442); // +40px vertical from anchor -> slide!
      ctrl.onPointerUp(1, 150, 442, 360);
      expect(events, ['left', 'slide']);
    });

    test('first drag or tap starts run once without moving lanes', () {
      var started = false;
      var startCalls = 0;
      final events = <String>[];
      final ctrl = LaneGestureController(
        onMove: (d) => events.add('move:$d'),
        onJump: () => events.add('jump'),
        isRunStarted: () => started,
        onStartRun: () {
          started = true;
          startCalls += 1;
        },
      );

      ctrl.onPointerDown(1, 100, 400);
      ctrl.onPointerMove(1, 140, 400);
      ctrl.onPointerUp(1, 150, 400, 360);
      expect(started, isTrue);
      expect(startCalls, 1);
      expect(events, isEmpty);
    });
  });
}
