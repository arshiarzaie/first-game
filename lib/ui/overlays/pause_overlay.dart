import 'package:flutter/material.dart';

/// Shown when the run is paused (pause button or app backgrounding).
/// S1 UI shell: concept-board dim + styled card. Test contract: the
/// 'PAUSED' and 'RESUME' texts must remain findable.
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
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
                'PAUSED',
                style: textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFF6E7C8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('RESUME'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F68),
                  foregroundColor: const Color(0xFF241327),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
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
