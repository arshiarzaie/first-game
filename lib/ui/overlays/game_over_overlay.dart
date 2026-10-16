import 'package:flutter/material.dart';

/// Shown when the run ends. Displays the score and the PLAY AGAIN action.
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1236),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x40F6E7C8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GAME OVER',
                style: textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFFF6E7C8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Score: $score',
                style: textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFD166),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onPlayAgain,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('PLAY AGAIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
