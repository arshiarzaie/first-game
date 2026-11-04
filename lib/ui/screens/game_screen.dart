import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/config/game_config.dart';
import '../../game/input/lane_gesture_controller.dart';
import '../../game/soul_dusk_run_game.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/pause_overlay.dart';
import 'settings_screen.dart';
import 'world_select_screen.dart';

/// Unified Living 3D Main Screen & Gameplay Host (`0.19.0+19`):
///  * **Main Screen (`isTitleHovering`)**: renders the live 9-layer 3D world
///    with Soul hovering alive in the sky, paired with `SOUL: DUSK RUN`,
///    `WORLDS`, `Settings`, and the glowing `START` button;
///  * **On `START` click**: fades out the title UI while Soul arcs upward,
///    flies down onto the stone bridge, and transitions seamlessly into full
///    ground running with the gameplay HUD!
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.world = GameWorld.duskHollow,
    this.startInTitleHover = true,
  });

  final GameWorld world;
  final bool startInTitleHover;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameWorld _activeWorld;
  late SoulDuskRunGame _game;
  late LaneGestureController _gestures;

  @override
  void initState() {
    super.initState();
    _activeWorld = widget.world;
    _initGame(startInTitleHover: widget.startInTitleHover);
    WidgetsBinding.instance.addObserver(this);
  }

  void _initGame({required bool startInTitleHover}) {
    _game = SoulDuskRunGame(
      selectedWorld: _activeWorld,
      startInTitleHover: startInTitleHover,
    );
    _gestures = LaneGestureController(
      onMove: _game.moveLane,
      onJump: _game.jump,
      onSlide: _game.slide,
      onDoubleTap: _game.activateSolarShield,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.hudTick.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _game.pauseByLifecycle();
    }
  }

  Future<void> _openSettings() async {
    _game.pauseEngine();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
    if (mounted && !_game.isEnded) {
      _game.resumeEngine();
    }
  }

  Future<void> _openWorldSelect() async {
    _game.pauseEngine();
    final chosen = await Navigator.of(context).push<GameWorld>(
      MaterialPageRoute<GameWorld>(
        builder: (_) => WorldSelectScreen(
          currentWorld: _activeWorld,
          popWithSelection: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (chosen != null && chosen != _activeWorld) {
      final oldNotifier = _game.hudTick;
      setState(() {
        _activeWorld = chosen;
        _initGame(startInTitleHover: true);
      });
      oldNotifier.dispose();
    } else if (!_game.isEnded) {
      _game.resumeEngine();
    }
  }

  static String _worldDisplayName(GameWorld world) {
    switch (world) {
      case GameWorld.duskHollow:
        return 'DUSK HOLLOW';
      case GameWorld.moonveilMarsh:
        return 'MOONVEIL MARSH';
      case GameWorld.emberfallCanyon:
        return 'EMBERFALL CANYON';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          return Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (_game.paused || _game.isEnded || _game.isTitleHovering) {
                    return;
                  }
                  _gestures.onPointerDown(
                    event.pointer,
                    event.localPosition.dx,
                    event.localPosition.dy,
                  );
                },
                onPointerMove: (event) {
                  if (_game.paused || _game.isEnded || _game.isTitleHovering) {
                    return;
                  }
                  _gestures.onPointerMove(
                    event.pointer,
                    event.localPosition.dx,
                    event.localPosition.dy,
                  );
                },
                onPointerUp: (event) {
                  if (_game.paused || _game.isEnded || _game.isTitleHovering) {
                    _gestures.onPointerCancel(event.pointer);
                    return;
                  }
                  _gestures.onPointerUp(
                    event.pointer,
                    event.localPosition.dx,
                    event.localPosition.dy,
                    screenWidth,
                    timestampMs: event.timeStamp.inMilliseconds,
                  );
                },
                onPointerCancel: (event) {
                  _gestures.onPointerCancel(event.pointer);
                },
                child: GameWidget<SoulDuskRunGame>(
                  key: ValueKey<GameWorld>(_activeWorld),
                  game: _game,
                  errorBuilder: (context, error) => Material(
                    color: const Color(0xFF1E1633),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'The scene failed to load.\n$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFF6E5),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  overlayBuilderMap: {
                    SoulDuskRunGame.gameOverOverlayId: (context, game) =>
                        GameOverOverlay(
                          score: game.score.totalScore,
                          onPlayAgain: game.resetRun,
                          onMainMenu: game.returnToTitleHover,
                        ),
                    SoulDuskRunGame.pauseOverlayId: (context, game) =>
                        PauseOverlay(
                          onResume: game.resumeFromMenu,
                          onMainMenu: game.returnToTitleHover,
                        ),
                  },
                ),
              ),

              ValueListenableBuilder<int>(
                valueListenable: _game.hudTick,
                builder: (context, _, _) {
                  final inTitle = _game.isTitleHovering;
                  final inGameplay = !_game.isTitleHovering && !_game.isEnded;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Living 3D Main Screen Overlay (fades out on START!)
                      IgnorePointer(
                        ignoring: !inTitle,
                        child: AnimatedOpacity(
                          opacity: inTitle ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: _LivingTitleOverlay(
                            worldLabel: _worldDisplayName(_activeWorld),
                            onStart: _game.startRun,
                            onOpenWorlds: _openWorldSelect,
                            onOpenSettings: _openSettings,
                          ),
                        ),
                      ),

                      // 2. Gameplay HUD (fades in smoothly as Soul flies in!)
                      IgnorePointer(
                        ignoring: !inGameplay,
                        child: AnimatedOpacity(
                          opacity: inGameplay ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned(
                                top: topPad + 12,
                                left: 14,
                                right: 60,
                                child: IgnorePointer(
                                  child: _TopHudBar(game: _game),
                                ),
                              ),
                              if (_game.isGroundRunning)
                                Positioned(
                                  left: 16,
                                  bottom: bottomPad + 20,
                                  child: _SunShieldOrbButton(game: _game),
                                ),
                              Positioned(
                                top: topPad + 8,
                                right: 10,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0x9924183C),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0x66FFE29E),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Pause',
                                    onPressed: _game.pauseWithMenu,
                                    icon: const Icon(
                                      Icons.pause_rounded,
                                      color: Color(0xFFFFF8EB),
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Overlay shown over the live 3D world while Soul hovers alive in the sky.
class _LivingTitleOverlay extends StatelessWidget {
  const _LivingTitleOverlay({
    required this.worldLabel,
    required this.onStart,
    required this.onOpenWorlds,
    required this.onOpenSettings,
  });

  final String worldLabel;
  final VoidCallback onStart;
  final VoidCallback onOpenWorlds;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Subtle top & bottom readability vignettes (leaving center 100% clear
        // so Living Hovering Soul shines unobstructed!).
        const Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x88100A22), Color(0x00100A22)],
                ),
              ),
              child: SizedBox(width: double.infinity, height: 190),
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00100A22), Color(0xBF100A22)],
                ),
              ),
              child: SizedBox(width: double.infinity, height: 210),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onOpenWorlds,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xAA24183C),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0x99FFD166),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 17,
                                color: Color(0xFFFFD166),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'WORLDS',
                                style: TextStyle(
                                  color: Color(0xFFF6E7C8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0x9924183C),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x66FFE29E),
                          width: 1.1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.settings,
                          color: Color(0xE6F6E7C8),
                        ),
                        tooltip: 'Settings',
                        onPressed: onOpenSettings,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'SOUL: DUSK RUN',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFFFF4D8),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.2,
                  shadows: const [
                    Shadow(
                      color: Color(0xCC120824),
                      blurRadius: 14,
                      offset: Offset(0, 3),
                    ),
                    Shadow(
                      color: Color(0x88FFAA52),
                      blurRadius: 22,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Run · Explore · Find Your Light',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xDCF6E7C8),
                  letterSpacing: 1.1,
                  shadows: const [
                    Shadow(
                      color: Color(0xAA000000),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x7724183C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x55FFD166),
                  ),
                ),
                child: Text(
                  worldLabel,
                  style: const TextStyle(
                    color: Color(0xFFFFDC8A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
              ),

              // Open center viewport showcasing Living Hovering Soul!
              const Spacer(),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x77FFA854),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text('START'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB5E),
                    foregroundColor: const Color(0xFF241327),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 52,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tap START to soar into the dusk',
                style: textTheme.bodySmall?.copyWith(
                  color: const Color(0xCCF6E7C8),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopHudBar extends StatelessWidget {
  const _TopHudBar({required this.game});

  final SoulDuskRunGame game;

  @override
  Widget build(BuildContext context) {
    final p = game.powerUps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _HudPill(
              borderColor: const Color(0xAAFFE29A),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0xFFFFFBE0), Color(0xFFFFB838)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xAAFFB838),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${game.score.totalScore}',
                    style: const TextStyle(
                      color: Color(0xFFFFF8EB),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (p.hasMultiplier) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC446),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '2x',
                        style: TextStyle(
                          color: Color(0xFF24183C),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _HudPill(
              borderColor: const Color(0x88D8B8FF),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wb_sunny_rounded,
                    size: 16,
                    color: Color(0xFFFFD666),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${game.score.orbsCollected}',
                    style: const TextStyle(
                      color: Color(0xFFFFECA8),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (p.isSolarDashing)
              _ActiveTimerBadge(
                label: 'SOLAR WINGS',
                remaining: p.dashRemaining,
                total: p.solarDashDuration,
                color: const Color(0xFFFF9E4C),
              ),
            if (p.hasSuperSneakers)
              _ActiveTimerBadge(
                label: 'SKY LEAP',
                remaining: p.sneakersRemaining,
                total: p.superSneakersDuration,
                color: const Color(0xFF72F2DC),
              ),
            if (p.hasMagnet)
              _ActiveTimerBadge(
                label: 'LIGHT AURA',
                remaining: p.magnetRemaining,
                total: p.magnetDuration,
                color: const Color(0xFFC49BFF),
              ),
            if (p.hasMultiplier)
              _ActiveTimerBadge(
                label: '2x LIGHT',
                remaining: p.multiplierRemaining,
                total: p.multiplierDuration,
                color: const Color(0xFFFFCF5C),
              ),
          ],
        ),
      ],
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({required this.borderColor, required this.child});

  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xB824183C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActiveTimerBadge extends StatelessWidget {
  const _ActiveTimerBadge({
    required this.label,
    required this.remaining,
    required this.total,
    required this.color,
  });

  final String label;
  final double remaining;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xC824183C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ${remaining.ceil()}s',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular golden emblem button at bottom-left matching `حین بازی` on the
/// Official Concept Board!
class _SunShieldOrbButton extends StatelessWidget {
  const _SunShieldOrbButton({required this.game});

  final SoulDuskRunGame game;

  @override
  Widget build(BuildContext context) {
    final p = game.powerUps;
    final active = p.hasShield;
    final ready = p.canActivateShield;
    final accent = active
        ? const Color(0xFFFFE484)
        : ready
            ? const Color(0xFFFFC854)
            : const Color(0x77B8AED0);

    final subText = active
        ? '${p.shieldRemaining.ceil()}s'
        : ready
            ? 'SHIELD'
            : '${p.shieldCooldownRemaining.ceil()}s';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: ready ? game.activateSolarShield : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xCC24183C),
            border: Border.all(color: accent, width: 2.0),
            boxShadow: [
              if (ready || active)
                BoxShadow(
                  color: accent.withValues(alpha: 0.42),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: accent,
              ),
              Text(
                subText,
                style: TextStyle(
                  color: ready || active
                      ? const Color(0xFFFFF8EB)
                      : const Color(0x99C4BCDA),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
