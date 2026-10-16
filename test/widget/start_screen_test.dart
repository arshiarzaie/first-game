import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/app.dart';

void main() {
  testWidgets('start screen displays SOUL: DUSK RUN and PLAY',
      (tester) async {
    await tester.pumpWidget(const SoulDuskRunApp());

    expect(find.text('SOUL: DUSK RUN'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}
