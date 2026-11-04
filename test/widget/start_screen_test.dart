import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';
import 'package:soul_dusk_run/game/soul_dusk_run_game.dart';

void main() {
  testWidgets(
      'main screen renders live 3D world with hovering alive Soul and START',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SoulDuskRunApp());
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('SOUL: DUSK RUN'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('WORLDS'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    final game = tester
        .widget<GameWidget<SoulDuskRunGame>>(
          find.byType(GameWidget<SoulDuskRunGame>),
        )
        .game!;
    expect(game.isTitleHovering, isTrue);
    expect(game.ambientSeconds, greaterThan(0));
    expect(game.effectivePlayerElevation, greaterThan(1.0),
        reason: 'Soul hovers alive in the sky on the Main Screen');
    expect(tester.takeException(), isNull);
  });
}
