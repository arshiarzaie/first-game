import 'package:flutter/material.dart';

import 'game_screen.dart';

/// Title screen with the game name and the PLAY action.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Greybox Soul placeholder icon (production art pending).
                const Icon(
                  Icons.wb_sunny_rounded,
                  size: 96,
                  color: Color(0xFFFFD166),
                ),
                const SizedBox(height: 24),
                Text(
                  'SOUL: DUSK RUN',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFFF6E7C8),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dodge the shadows. Collect the light.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB9B3D6),
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GameScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('PLAY'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
