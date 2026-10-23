import 'package:flutter/material.dart';

/// Shown when the run ends. Displays the score and the PLAY AGAIN action.
/// S1 UI shell: concept-board styled card (violet glass panel, gold score
/// pill, warm coral CTA). Test contract: 'GAME OVER', `'Score: N'` and
/// 'PLAY AGAIN' texts must remain findable.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    required this.score,
    required this.onPlayAgain,
    super.key,
  });

  final int score;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: const Color(0xB8120B24),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF33205A), Color(0xFF1C1236)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x55F6E7C8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GAME OVER',
                style: textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFFF6E7C8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFD166),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x66FFD166)),
                ),
                child: Text(
                  'Score: $score',
                  style: textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFFFD166),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: onPlayAgain,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('PLAY AGAIN'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F68),
                  foregroundColor: const Color(0xFF241327),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
