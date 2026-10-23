import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';

/// S6 Settings shell contracts:
/// - the gear icon on the title screen opens the settings shell;
/// - the shell lists SOUND/MUSIC (disabled, pending audio pass),
///   LANGUAGE (display-only English) and VERSION;
/// - the back arrow returns to the title screen.
void main() {
  testWidgets('gear icon opens the settings shell', (tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('SOUND'), findsOneWidget);
    expect(find.text('MUSIC'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('VERSION'), findsOneWidget);
    // both switches are intentionally disabled for now
    for (final widget in tester.widgetList<Switch>(find.byType(Switch))) {
      expect(widget.onChanged, isNull);
    }
  });

  testWidgets('settings back arrow returns to the title screen',
      (tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());
    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('SOUL: DUSK RUN'), findsOneWidget);
    expect(find.text('SETTINGS'), findsNothing);
  });
}
