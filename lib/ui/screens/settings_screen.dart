import 'package:flutter/material.dart';

/// Settings shell (S6): structure only, no behavior yet.
///
/// - SOUND and MUSIC rows ship disabled until the audio pass lands
///   (audio is deliberately out of scope for now);
/// - LANGUAGE is display-only — the game is English-only;
/// - VERSION mirrors pubspec.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF140D26), Color(0xFF241A40)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Color(0xFFFFD166), // Soul gold
                    shadows: [Shadow(color: Color(0x99FF9F68), blurRadius: 18)],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SettingRow(
                icon: Icons.volume_up_outlined,
                title: 'SOUND',
                trailing: Switch(value: false, onChanged: null),
                caption: 'Coming with the audio pass',
              ),
              const _SettingRow(
                icon: Icons.music_note_outlined,
                title: 'MUSIC',
                trailing: Switch(value: false, onChanged: null),
                caption: 'Coming with the audio pass',
              ),
              const _SettingRow(
                icon: Icons.language_rounded,
                title: 'LANGUAGE',
                trailing: Text('ENGLISH',
                    style: TextStyle(
                        color: Colors.white70, letterSpacing: 2, fontSize: 14)),
                caption: 'English-only for now',
              ),
              const _SettingRow(
                icon: Icons.info_outline_rounded,
                title: 'VERSION',
                trailing: Text('0.1.0',
                    style: TextStyle(
                        color: Colors.white70, letterSpacing: 2, fontSize: 14)),
                caption: 'Early access build',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xB3F6E7C8)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
