import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soul_dusk_run/app.dart';
import 'package:soul_dusk_run/game/config/game_config.dart';
import 'package:soul_dusk_run/game/soul_dusk_run_game.dart';

/// World Select contracts (S3 shell / S4+S7 worlds / S8 sun-gating):
/// - PLAY on the title screen opens the world-select screen;
/// - all three board worlds are listed with the banked-suns header;
/// - Dusk Hollow is always playable; Moonveil Marsh and Emberfall Canyon
///   stay LOCKED until the banked-sun thresholds (25 / 60) are met;
/// - locked worlds do NOT navigate into the game;
/// - unlocked worlds open the game wired to that world;
/// - the back arrow returns to the title screen.
void main() {
  Future<void> pumpToWorldSelect(WidgetTester tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
  }

  testWidgets('PLAY opens world select: all worlds listed, suns header',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpToWorldSelect(tester);

    expect(find.text('SELECT WORLD'), findsOneWidget);
    expect(find.text('DUSK HOLLOW'), findsOneWidget);
    expect(find.text('MOONVEIL MARSH'), findsOneWidget);
    expect(find.text('EMBERFALL CANYON'), findsOneWidget);
    expect(find.text('SUNS: 0'), findsOneWidget);
    expect(find.byType(GameWidget), findsNothing);
  });

  testWidgets('worlds are locked until their sun thresholds are met',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpToWorldSelect(tester);

    expect(find.text('LOCKED'), findsNWidgets(2));
    expect(find.text('0 / 25 SUNS'), findsOneWidget);
    expect(find.text('0 / 60 SUNS'), findsOneWidget);
    expect(find.text('COMING SOON'), findsNothing);

    await tester.tap(find.text('MOONVEIL MARSH'));
    await tester.pumpAndSettle();
    expect(find.text('SELECT WORLD'), findsOneWidget);
    expect(find.byType(GameWidget), findsNothing);
  });

  testWidgets('Moonveil Marsh opens the game in the marsh world',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sdr_total_suns': 30});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpToWorldSelect(tester);

    expect(find.text('SUNS: 30'), findsOneWidget);
    expect(find.text('LOCKED'), findsNWidgets(1)); // only Emberfall now

    await tester.tap(find.text('MOONVEIL MARSH'));
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final game = tester
        .widget<GameWidget<SoulDuskRunGame>>(
            find.byType(GameWidget<SoulDuskRunGame>))
        .game!;
    expect(game.selectedWorld, equals(GameWorld.moonveilMarsh));
    expect(game.isRunStarted, isFalse);
    expect(game.travelled, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Emberfall Canyon opens the game in the canyon world',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sdr_total_suns': 65});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpToWorldSelect(tester);

    await tester.tap(find.text('EMBERFALL CANYON'));
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final game = tester
        .widget<GameWidget<SoulDuskRunGame>>(
            find.byType(GameWidget<SoulDuskRunGame>))
        .game!;
    expect(game.selectedWorld, equals(GameWorld.emberfallCanyon));
    expect(game.isRunStarted, isFalse);
    expect(game.travelled, equals(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('back arrow returns to the title screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpToWorldSelect(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('SOUL: DUSK RUN'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('SELECT WORLD'), findsNothing);
  });
}
