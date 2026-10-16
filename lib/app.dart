import 'package:flutter/material.dart';

import 'ui/screens/start_screen.dart';

/// App shell for SOUL: DUSK RUN. English-only UI.
class SoulDuskRunApp extends StatelessWidget {
  const SoulDuskRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOUL: DUSK RUN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD166), // Soul gold
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF140D26), // midnight violet
      ),
      home: const StartScreen(),
    );
  }
}
