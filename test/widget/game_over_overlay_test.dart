import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/ui/overlays/game_over_overlay.dart';

void main() {
  testWidgets('game over overlay displays the score and PLAY AGAIN',
      (tester) async {
    var playAgainTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          score: 123,
          onPlayAgain: () => playAgainTaps += 1,
        ),
      ),
    );

    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('Score: 123'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsOneWidget);

    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pump();
    expect(playAgainTaps, 1);
  });
}
