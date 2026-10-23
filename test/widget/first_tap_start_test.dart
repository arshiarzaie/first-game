import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';
import 'package:soul_dusk_run/game/soul_dusk_run_game.dart';

/// P4 mandatory start behavior (acceptance criteria §6):
/// A1) freshly entered game scene is alive AND idle — Soul standing still,
///     time/score/travel frozen, no automatic start.
/// A2) the first tap starts the run exactly once; the starting input is not
///     a lane move; further taps act normally and never restart the run.
void main() {
  testWidgets('game waits idle for first tap, then runs exactly once',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    // S3: PLAY leads to World Select; enter the game via DUSK HOLLOW.
    await tester.pumpAndSettle();
    await tester.tap(find.text('DUSK HOLLOW'));

    // A1: settle into the scene; assert still idle (auto-start would break
    // this — the game ticker pumps real frames here).
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final gameWidget = tester.widget<GameWidget<SoulDuskRunGame>>(
      find.byType(GameWidget<SoulDuskRunGame>),
    );
    final game = gameWidget.game!;
    expect(game.isRunStarted, isFalse);
    expect(game.travelled, equals(0));
    expect(game.elapsedSeconds, equals(0));
    expect(game.score.totalScore, equals(0));
    expect(game.paused, isFalse);
    expect(game.isEnded, isFalse);
    expect(game.player.isMounted, isTrue);
    expect(tester.takeException(), isNull);

    // A2a: first tap starts the run (swallowed — not a lane move).
    final laneBefore = game.laneSystem.lane;
    await tester.tapAt(const Offset(120, 400)); // left half
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.isRunStarted, isTrue);
    expect(game.laneSystem.lane, equals(laneBefore),
        reason: 'starting tap must not change lanes');
    expect(game.travelled, greaterThan(0),
        reason: 'world must move after the first tap');

    // A2b: run progression continues; second tap DOES move lanes now.
    await tester.tapAt(const Offset(120, 400)); // left half -> lane left
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.laneSystem.lane, equals(laneBefore - 1),
        reason: 'post-start taps route to lane moves');

    // A2c: direct double start calls are idempotent (no restart/duplicate).
    game.startRun();
    game.startRun();
    expect(game.isRunStarted, isTrue);
    expect(game.isEnded, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gesture-tap routing: first drag starts run, not a lane move',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    // S3: PLAY leads to World Select; enter the game via DUSK HOLLOW.
    await tester.pumpAndSettle();
    await tester.tap(find.text('DUSK HOLLOW'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final game = tester
        .widget<GameWidget<SoulDuskRunGame>>(
            find.byType(GameWidget<SoulDuskRunGame>))
        .game!;
    expect(game.isRunStarted, isFalse);

    await tester.dragFrom(const Offset(180, 400), const Offset(120, 0));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.isRunStarted, isTrue);
    expect(game.laneSystem.lane, equals(1),
        reason: 'starting drag must not lane-jump the player');
    expect(tester.takeException(), isNull);
  });
}
