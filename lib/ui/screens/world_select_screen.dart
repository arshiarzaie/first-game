import 'package:flutter/material.dart';

import '../../game/config/game_config.dart';
import '../../game/systems/progress_store.dart';
import 'game_screen.dart';

/// World Select screen (S3 shell; S4/S7 worlds; S8 sun-gating): the
/// three world cards per concept board. Dusk Hollow is always open;
/// Moonveil Marsh and Emberfall Canyon unlock once the player has
/// banked enough suns (energy orbs) across runs — thresholds in
/// GameConfig.worldUnlockSunsFor.
class WorldSelectScreen extends StatefulWidget {
  const WorldSelectScreen({super.key});

  @override
  State<WorldSelectScreen> createState() => _WorldSelectScreenState();
}

class _WorldSelectScreenState extends State<WorldSelectScreen> {
  ProgressStore? _progress;

  @override
  void initState() {
    super.initState();
    ProgressStore.load().then((store) {
      if (mounted) {
        setState(() => _progress = store);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suns = _progress?.totalSuns ?? 0;

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
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  const Icon(Icons.wb_sunny_rounded,
                      color: Color(0xFFFFD166), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'SUNS: $suns',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: Color(0xFFFFD166),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'SELECT WORLD',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: Color(0xFFFFD166), // Soul gold
                  shadows: [
                    Shadow(
                      color: Color(0x99FF9F68),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Expanded(
                        child: _WorldCard(
                          title: 'DUSK HOLLOW',
                          imageAsset: 'assets/images/ui/world_dusk_hollow.png',
                          accent: const Color(0xFFFFD166),
                          unlocked: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GameScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _WorldCard(
                          title: 'MOONVEIL MARSH',
                          imageAsset: 'assets/images/ui/world_moonveil.png',
                          accent: const Color(0xFF6FDCD2),
                          unlocked: suns >=
                              GameConfig.worldUnlockSunsFor(
                                  GameWorld.moonveilMarsh),
                          requirement:
                              GameConfig.worldUnlockSunsFor(
                                  GameWorld.moonveilMarsh),
                          currentSuns: suns,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GameScreen(
                                  world: GameWorld.moonveilMarsh,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _WorldCard(
                          title: 'EMBERFALL CANYON',
                          imageAsset: 'assets/images/ui/world_emberfall.png',
                          accent: const Color(0xFFFF9F68),
                          unlocked: suns >=
                              GameConfig.worldUnlockSunsFor(
                                  GameWorld.emberfallCanyon),
                          requirement:
                              GameConfig.worldUnlockSunsFor(
                                  GameWorld.emberfallCanyon),
                          currentSuns: suns,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GameScreen(
                                  world: GameWorld.emberfallCanyon,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.title,
    required this.imageAsset,
    required this.accent,
    required this.unlocked,
    this.requirement = 0,
    this.currentSuns = 0,
    this.onTap,
  });

  final String title;
  final String imageAsset;
  final Color accent;
  final bool unlocked;

  /// Suns needed to unlock (locked cards only) and current total shown
  /// as progress (`$currentSuns / $requirement SUNS`).
  final int requirement;
  final int currentSuns;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: const Color(0xFF241A40)),
          ),
          // Bottom gradient for label readability.
          const Align(
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xDD000000)],
                ),
              ),
              child: SizedBox(height: 96, width: double.infinity),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 12,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: Colors.white,
                shadows: [
                  Shadow(color: accent, blurRadius: 12),
                ],
              ),
            ),
          ),
          if (!unlocked)
            Container(
              color: const Color(0xAA140D26),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: Colors.white70, size: 22),
                  const SizedBox(height: 6),
                  const Text(
                    'LOCKED',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currentSuns / $requirement SUNS',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Color(0xB3FFD166),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? accent : const Color(0x44FFFFFF),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: unlocked ? 0.35 : 0.0),
            blurRadius: 18,
          ),
        ],
      ),
      child: unlocked && onTap != null
          ? GestureDetector(onTap: onTap, child: body)
          : body,
    );
  }
}
