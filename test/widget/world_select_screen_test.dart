import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';

/// S3 World Select shell contracts:
/// - PLAY on the title screen opens the world-select screen;
/// - all three board worlds are listed;
/// - only Dusk Hollow is selectable (others read 'COMING SOON');
/// - choosing a locked world does NOT navigate into the game.
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
    expect(find.text('COMING SOON'), findsNWidgets(2));
    expect(find.byType(GameWidget), findsNothing);
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
