import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';
import 'package:soul_dusk_run/game/soul_dusk_run_game.dart';

/// S19 Start & Flight-to-Ground behavior:
///  1. Main Screen stays in living `titleHover` (score/travel frozen) until
///     `START` is clicked;
///  2. Clicking `START` launches the animated sky-flight descent onto the
///     center lane of the bridge (`lane == 1`) and transitions smoothly into
///     ground running;
///  3. Once running on the ground, taps & swipes move lanes cleanly, and
///     `returnToTitleHover()` restores the Living Main Screen.
void main() {
  testWidgets('Soul hovers until START, flies down to bridge, then runs',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SoulDuskRunApp());
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final game = tester
        .widget<GameWidget<SoulDuskRunGame>>(
          find.byType(GameWidget<SoulDuskRunGame>),
        )
        .game!;
    expect(game.isTitleHovering, isTrue);
    expect(game.isRunStarted, isFalse);
    expect(game.travelled, equals(0));
    expect(game.elapsedSeconds, equals(0));
    expect(game.score.totalScore, equals(0));

    // Background drag on Main Screen before START does not start run or move lane
    await tester.dragFrom(const Offset(180, 400), const Offset(120, 0));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.isTitleHovering, isTrue);
    expect(game.laneSystem.lane, equals(1));

    // Clicking START launches flight descent -> touchdown -> ground running!
    final laneBefore = game.laneSystem.lane;
    await tester.tap(find.text('START'));
    for (var i = 0; i < 95; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.isGroundRunning, isTrue);
    expect(game.laneSystem.lane, equals(laneBefore));
    expect(game.travelled, greaterThan(0));
    expect(game.score.totalScore, greaterThan(0));

    // Post-landing tap moves lane cleanly
    await tester.tapAt(const Offset(90, 400));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.laneSystem.lane, equals(laneBefore - 1));

    // Double startRun() calls are idempotent
    game.startRun();
    game.startRun();
    expect(game.isGroundRunning, isTrue);
    expect(game.isEnded, isFalse);

    // Returning to Main Menu restores Living Sky-Hover state
    game.returnToTitleHover();
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.isTitleHovering, isTrue);
    expect(game.travelled, equals(0));
    expect(tester.takeException(), isNull);
  });
}
