import 'package:flutter/material.dart';

import 'settings_screen.dart';
import 'world_select_screen.dart';

/// Cinematic title screen (S1 UI shell, concept-board direction):
/// full-bleed approved key art, cream/gold wordmark, tagline and the
/// PLAY action. Test contract: the exact texts 'SOUL: DUSK RUN' and
/// 'PLAY' must remain findable.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  static const String keyArtAsset = 'assets/images/ui/title_key_art.png';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Key art, covering the whole viewport. errorBuilder keeps the
          // screen alive (and widget tests green) when the asset cannot be
          // decoded — e.g. test environments without bundled assets.
          Image.asset(
            keyArtAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: const Color(0xFF1C1236)),
          ),
          // Readability scrims (top for the wordmark, bottom for PLAY).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x99120B24), Color(0x00120B24)],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00120B24), Color(0xE6120B24)],
                ),
              ),
              child: SizedBox(width: double.infinity, height: 260),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Color(0xB3F6E7C8)),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 28),
                Text(
                  'SOUL: DUSK RUN',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFFF6E7C8),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    shadows: const [
                      Shadow(
                        color: Color(0xB3000000),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Run · Explore · Find Your Light',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xD8F6E7C8),
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WorldSelectScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('PLAY'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9F68),
                    foregroundColor: const Color(0xFF241327),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 42,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tap to begin the journey',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0x99F6E7C8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
