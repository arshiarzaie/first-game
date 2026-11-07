import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';
import 'package:soul_dusk_run/game/config/game_config.dart';
import 'package:soul_dusk_run/game/soul_dusk_run_game.dart';

/// S20 Start, Direct-Hero-Tap & Crystal Portal contracts:
///  1. Main Screen stays in living `titleHover` (score/travel frozen) until
///     Soul himself OR `START` is tapped;
///  2. Tapping directly on Soul (`soulHeroTapTarget`) launches the 180° turn &
///     golden comet dive onto the stone causeway -> ground running;
///  3. Passing through a Crystal Portal (`enterCrystalPortal`) seamlessly
///     switches `currentWorld` while running, and `returnToTitleHover()` resets
///     back to the starting world.
void main() {
  testWidgets(
      'tapping directly on Soul or START launches dive to bridge and runs',
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

    // Background drag on Main Screen before tap does not start run or move lane
    await tester.dragFrom(const Offset(180, 400), const Offset(120, 0));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.isTitleHovering, isTrue);
    expect(game.laneSystem.lane, equals(1));

    // Tapping directly on close-up Soul launches spin + dive -> ground run!
    final laneBefore = game.laneSystem.lane;
    await tester.tap(find.byKey(const Key('soulHeroTapTarget')));
    for (var i = 0; i < 105; i++) {
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

    // Live Crystal Portal transitions active biome seamlessly while running!
    expect(game.currentWorld, equals(GameWorld.duskHollow));
    game.enterCrystalPortal(GameWorld.moonveilMarsh);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.currentWorld, equals(GameWorld.moonveilMarsh));
    expect(game.showPortalArrivalBanner, isTrue);

    // Returning to Main Menu restores Living Sky-Hover & starting world
    game.returnToTitleHover();
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.isTitleHovering, isTrue);
    expect(game.currentWorld, equals(GameWorld.duskHollow));
    expect(game.travelled, equals(0));

    // Tapping START button also launches the run cleanly!
    await tester.tap(find.text('START'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.isIntroFlying, isTrue);
    expect(tester.takeException(), isNull);
  });
}
