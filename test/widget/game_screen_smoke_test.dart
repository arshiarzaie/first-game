import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';
import 'package:soul_dusk_run/game/soul_dusk_run_game.dart';

/// Diagnostic smoke test for the reported on-device black screen.
///
/// Exercises the real startup path end-to-end (app launch -> visible start
/// screen -> PLAY -> live game scene) and fails if ANY exception is thrown
/// in the load/render path or if the scene is not actually alive.
///
/// NOTE: never use pumpAndSettle here — the game ticker never idles.
void main() {
  testWidgets('launch -> start screen visible -> PLAY -> game scene renders',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // logical 360x800
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();

    // Step 1: start screen content must be visible (not a black screen).
    expect(find.text('SOUL: DUSK RUN'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);

    // Step 2: navigate into the game and run real frames.
    await tester.tap(find.text('PLAY'));
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Step 2b: P4 start contract — the scene is alive but the run has NOT
    // begun yet: Soul stands idle until the first tap.
    {
      final gameWidgetPre =
          tester.widget<GameWidget<SoulDuskRunGame>>(
        find.byType(GameWidget<SoulDuskRunGame>),
      );
      final gamePre = gameWidgetPre.game!;
      expect(gamePre.isRunStarted, isFalse,
          reason: 'run must await the first tap');
      expect(gamePre.travelled, equals(0),
          reason: 'world/score must not progress before the first tap');
    }

    // Step 2c: first tap starts the run exactly once (and is swallowed —
    // it must not move lanes).
    await tester.tapAt(const Offset(180, 400));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Step 3: nothing in the startup/render path may throw.
    final exception = tester.takeException();
    expect(exception, isNull,
        reason: 'startup/render path threw: $exception');

    // Step 4: the game scene must be alive with sane geometry.
    final gameWidget =
        tester.widget<GameWidget<SoulDuskRunGame>>(
      find.byType(GameWidget<SoulDuskRunGame>),
    );
    final game = gameWidget.game!;

    expect(game.size.x, greaterThan(0));
    expect(game.size.y, greaterThan(0));
    expect(game.paused, isFalse);
    expect(game.isEnded, isFalse);

    // The player exists, has a real size, and sits inside the visible area.
    expect(game.player.isMounted, isTrue);
    expect(game.player.size.x, greaterThan(0),
        reason: 'player has zero size — invisible');
    expect(game.player.position.x, inInclusiveRange(0, game.size.x));
    expect(game.player.position.y, inInclusiveRange(0, game.size.y));

    // The run is progressing (world moving, speed ramp active).
    expect(game.travelled, greaterThan(0));

    // No overlay should be active straight after starting.
    expect(game.overlays.isActive(SoulDuskRunGame.gameOverOverlayId),
        isFalse);
    expect(game.overlays.isActive(SoulDuskRunGame.pauseOverlayId), isFalse);
  });
}
