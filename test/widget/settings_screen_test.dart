import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';

/// Settings shell contracts on top of the S19 Living 3D Main Screen:
/// - the gear icon pauses the 3D scene and opens the settings shell;
/// - the shell lists SOUND/MUSIC (disabled, pending audio pass),
///   LANGUAGE (display-only English) and VERSION;
/// - the back arrow resumes and returns to the Living 3D Main Screen.
void main() {
  testWidgets('gear icon opens the settings shell', (tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('SOUND'), findsOneWidget);
    expect(find.text('MUSIC'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('VERSION'), findsOneWidget);
    for (final widget in tester.widgetList<Switch>(find.byType(Switch))) {
      expect(widget.onChanged, isNull);
    }
  });

  testWidgets('settings back arrow returns to the living main screen',
      (tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('SOUL: DUSK RUN'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('SETTINGS'), findsNothing);
  });
}
