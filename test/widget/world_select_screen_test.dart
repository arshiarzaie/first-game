import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';
import 'package:soul_dusk_run/game/config/game_config.dart';
import 'package:soul_dusk_run/game/soul_dusk_run_game.dart';

/// S3/S4 World Select shell contracts:
/// - PLAY on the title screen opens the world-select screen;
/// - all three board worlds are listed;
/// - Dusk Hollow and Moonveil Marsh are playable, Emberfall Canyon stays
///   locked ('COMING SOON');
/// - choosing a locked world does NOT navigate into the game;
/// - choosing Moonveil Marsh opens the game wired to that world.
void main() {
  testWidgets('PLAY opens world select with all three worlds', (tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    expect(find.text('SELECT WORLD'), findsOneWidget);
    expect(find.text('DUSK HOLLOW'), findsOneWidget);
    expect(find.text('EMBERFALL CANYON'), findsOneWidget);
    expect(find.text('MOONVEIL MARSH'), findsOneWidget);
    expect(find.text('COMING SOON'), findsOneWidget);
    expect(find.byType(GameWidget), findsNothing);
  });

  testWidgets('Moonveil Marsh opens the game in the marsh world',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('MOONVEIL MARSH'));
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final game = tester
        .widget<GameWidget<SoulDuskRunGame>>(
            find.byType(GameWidget<SoulDuskRunGame>))
        .game!;
    expect(game.world, equals(GameWorld.moonveilMarsh));
    expect(game.isRunStarted, isFalse);
    expect(game.travelled, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked world does not open the game', (tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EMBERFALL CANYON'));
    await tester.pumpAndSettle();

    expect(find.text('SELECT WORLD'), findsOneWidget);
    expect(find.byType(GameWidget), findsNothing);
  });

  testWidgets('back arrow returns to the title screen', (tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('SOUL: DUSK RUN'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('SELECT WORLD'), findsNothing);
  });
}
