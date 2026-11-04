import 'package:flutter/material.dart';

import 'game_screen.dart';

/// Entry route for `SOUL: DUSK RUN` (`0.19.0+19`), booting directly into the
/// unified Living 3D Main Screen where Soul hovers alive in the sky and swoops
/// down onto the ancient stone causeway upon tapping `START`.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  static const String keyArtAsset = 'assets/images/ui/title_key_art.png';

  @override
  Widget build(BuildContext context) {
    return const GameScreen();
  }
}
