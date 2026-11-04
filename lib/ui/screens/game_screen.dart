import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/config/game_config.dart';
import '../../game/input/lane_gesture_controller.dart';
import '../../game/soul_dusk_run_game.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/pause_overlay.dart';

/// Hosts `SOUL: DUSK RUN` (`0.16.0+16`), matching the Official Concept Board's
/// `حین بازی` HUD layout (clean golden orb/score badge top-left, circular pause
/// top-right, radiant Sun-Shield button bottom-left/right, and translucent
/// twilight-gold fantasy badges).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.world = GameWorld.duskHollow});

  final GameWorld world;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final SoulDuskRunGame _game;
  late final LaneGestureController _gestures;

  @override
  void initState() {
    super.initState();
    _game = SoulDuskRunGame(selectedWorld: widget.world);
    _gestures = LaneGestureController(
      onMove: _game.moveLane,
      onJump: _game.jump,
      onSlide: _game.slide,
      onDoubleTap: _game.activateSolarShield,
      isRunStarted: () => _game.isRunStarted,
      onStartRun: _game.startRun,
    );
    WidgetsBinding.instance.addObserver(this);
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
                  if (_game.paused || _game.isEnded) {
                    return;
                  }
                  _gestures.onPointerDown(
                    event.pointer,
                    event.localPosition.dx,
                    event.localPosition.dy,
                  );
                },
                onPointerMove: (event) {
                  if (_game.paused || _game.isEnded) {
                    return;
                  }
                  _gestures.onPointerMove(
                    event.pointer,
                    event.localPosition.dx,
                    event.localPosition.dy,
                  );
                },
                onPointerUp: (event) {
                  if (_game.paused || _game.isEnded) {
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
                        ),
                    SoulDuskRunGame.pauseOverlayId: (context, game) =>
                        PauseOverlay(onResume: game.resumeFromMenu),
                  },
                ),
              ),

              ValueListenableBuilder<int>(
                valueListenable: _game.hudTick,
                builder: (context, _, _) {
                  return Stack(
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
                      if (!_game.isRunStarted && !_game.isEnded)
                        const IgnorePointer(
                          child: Align(
                            alignment: Alignment(0, 0.14),
                            child: _StartPromptBanner(),
                          ),
                        ),
                      if (_game.isRunStarted && !_game.isEnded)
                        Positioned(
                          left: 16,
                          bottom: bottomPad + 20,
                          child: _SunShieldOrbButton(game: _game),
                        ),
                    ],
                  );
                },
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
          );
        },
      ),
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

class _StartPromptBanner extends StatelessWidget {
  const _StartPromptBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC24183C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xDDFFD66E), width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x48000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TAP TO FIND YOUR LIGHT',
            style: TextStyle(
              color: Color(0xFFFFEEAE),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '◀ ▶ LANE   •   ▲ LEAP   •   ▼ SLIDE   •   2× SUN SHIELD',
            style: TextStyle(
              color: Color(0xFFEDE4FF),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
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
