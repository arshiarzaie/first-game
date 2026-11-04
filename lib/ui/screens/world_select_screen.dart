import 'package:flutter/material.dart';

import '../../game/config/game_config.dart';
import '../../game/systems/progress_store.dart';
import 'game_screen.dart';

/// World Select screen (`0.19.0+19`): lists the three fantasy biomes
/// (`Dusk Hollow`, `Moonveil Marsh`, `Emberfall Canyon`) with banked-sun
/// unlock thresholds (`0`, `25`, `60`).
///
/// When opened from the Living 3D Main Screen ([popWithSelection] = `true`),
/// tapping an unlocked world pops that [GameWorld] back so the single active
/// 3D scene switches worlds cleanly without stacking duplicate game instances.
class WorldSelectScreen extends StatefulWidget {
  const WorldSelectScreen({
    super.key,
    this.currentWorld,
    this.popWithSelection = false,
  });

  final GameWorld? currentWorld;
  final bool popWithSelection;

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

  void _selectWorld(GameWorld world) {
    if (widget.popWithSelection) {
      Navigator.of(context).pop(world);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(world: world),
      ),
    );
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
                  color: Color(0xFFFFD166),
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
                          isSelected:
                              widget.currentWorld == GameWorld.duskHollow,
                          onTap: () => _selectWorld(GameWorld.duskHollow),
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
                          isSelected:
                              widget.currentWorld == GameWorld.moonveilMarsh,
                          requirement: GameConfig.worldUnlockSunsFor(
                              GameWorld.moonveilMarsh),
                          currentSuns: suns,
                          onTap: () => _selectWorld(GameWorld.moonveilMarsh),
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
                          isSelected:
                              widget.currentWorld == GameWorld.emberfallCanyon,
                          requirement: GameConfig.worldUnlockSunsFor(
                              GameWorld.emberfallCanyon),
                          currentSuns: suns,
                          onTap: () => _selectWorld(GameWorld.emberfallCanyon),
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
    this.isSelected = false,
    this.requirement = 0,
    this.currentSuns = 0,
    this.onTap,
  });

  final String title;
  final String imageAsset;
  final Color accent;
  final bool unlocked;
  final bool isSelected;
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
          if (isSelected && unlocked)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCC24183C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent, width: 1.2),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: accent,
                  ),
                ),
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
          width: isSelected ? 2.4 : 1.6,
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
