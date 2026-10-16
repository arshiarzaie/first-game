import 'package:flutter/material.dart';

/// Shown when the run is paused (pause button or app backgrounding).
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({required this.onResume, super.key});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: const Color(0x99120B24),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PAUSED',
              style: textTheme.headlineMedium?.copyWith(
                color: const Color(0xFFF6E7C8),
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('RESUME'),
            ),
          ],
        ),
      ),
    );
  }
}
