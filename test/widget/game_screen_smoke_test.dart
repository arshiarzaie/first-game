import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';
import 'package:soul_dusk_run/game/soul_dusk_run_game.dart';

/// End-to-end smoke test for S19 (`0.19.0+19`):
///  1. Launch -> Living 3D Main Screen with Soul hovering alive in the sky;
///  2. Tap START -> Soul arcs and flies down through the air (`isIntroFlying`);
///  3. Touchdown -> Soul lands on the stone bridge (`elevation == 0`) and
///     sprints forward on the ground (`isGroundRunning`, `travelled > 0`).
void main() {
  testWidgets(
      'launch -> living Soul hover -> START -> flight descent -> ground run',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SoulDuskRunApp());
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Step 1: Living 3D Main Screen is visible and Soul hovers alive in sky.
    expect(find.text('SOUL: DUSK RUN'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);

    final gamePre = tester
        .widget<GameWidget<SoulDuskRunGame>>(
          find.byType(GameWidget<SoulDuskRunGame>),
        )
        .game!;
    expect(gamePre.isTitleHovering, isTrue);
    expect(gamePre.isRunStarted, isFalse);
    expect(gamePre.travelled, equals(0));
    expect(gamePre.effectivePlayerElevation, greaterThan(1.0));

    // Step 2: Tap START -> Soul enters animated sky-flight descent!
    await tester.tap(find.text('START'));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(gamePre.isIntroFlying, isTrue,
        reason: 'Soul should be flying toward the bridge right after START');
    expect(gamePre.effectivePlayerElevation, greaterThan(0.4));

    // Step 3: Pump past touchdown -> Soul lands on the ground and runs!
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final exception = tester.takeException();
    expect(exception, isNull,
        reason: 'startup/flight/render path threw: $exception');

    expect(gamePre.isIntroFlying, isFalse);
    expect(gamePre.isGroundRunning, isTrue);
    expect(gamePre.effectivePlayerElevation, closeTo(0.0, 0.001));
    expect(gamePre.paused, isFalse);
    expect(gamePre.isEnded, isFalse);
    expect(gamePre.player.isMounted, isTrue);
    expect(gamePre.player.size.x, greaterThan(0));
    expect(gamePre.player.position.x, inInclusiveRange(0, gamePre.size.x));
    expect(gamePre.player.position.y, inInclusiveRange(0, gamePre.size.y));
    expect(gamePre.travelled, greaterThan(200));
    expect(gamePre.overlays.isActive(SoulDuskRunGame.gameOverOverlayId),
        isFalse);
    expect(gamePre.overlays.isActive(SoulDuskRunGame.pauseOverlayId), isFalse);
  });
}
