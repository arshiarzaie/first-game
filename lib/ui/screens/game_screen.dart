import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/config/game_config.dart';
import '../../game/input/lane_gesture_controller.dart';
import '../../game/soul_dusk_run_game.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/pause_overlay.dart';

/// Hosts the Flame game, instant zero-lag 4-way Subway-Surfers pointer routing
/// (swipe left/right, swipe up to jump, swipe down to roll/fast-fall,
/// chainable L-swipes, center double-tap Hoverboard), sunlit crisp HUD pills,
/// and active power-up timers (S15: Jetpack, Super Sneakers, Magnet, 2x,
/// and Solar Hoverboard).
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
                    color: const Color(0xFF1C2C44),
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
                          right: 16,
                          bottom: bottomPad + 20,
                          child: _HoverboardButton(game: _game),
                        ),
                    ],
                  );
                },
              ),

              Positioned(
                top: topPad + 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xAA1C2C44),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: IconButton(
                    tooltip: 'Pause',
                    onPressed: _game.pauseWithMenu,
                    icon: const Icon(
                      Icons.pause_rounded,
                      color: Color(0xFFFFF8EB),
                      size: 28,
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
              borderColor: const Color(0xCCFFFFFF),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${game.score.totalScore}'.padLeft(5, '0'),
                    style: const TextStyle(
                      color: Color(0xFFFFF8EB),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
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
                        color: const Color(0xFFFFB82E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '2x',
                        style: TextStyle(
                          color: Color(0xFF1C2C44),
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
              borderColor: const Color(0xDDFFD65C),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wb_sunny_rounded,
                    size: 17,
                    color: Color(0xFFFFD65C),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${game.score.orbsCollected}',
                    style: const TextStyle(
                      color: Color(0xFFFFECA6),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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
                label: 'JETPACK',
                remaining: p.dashRemaining,
                total: p.solarDashDuration,
                color: const Color(0xFFFF7A38),
              ),
            if (p.hasSuperSneakers)
              _ActiveTimerBadge(
                label: 'SNEAKERS',
                remaining: p.sneakersRemaining,
                total: p.superSneakersDuration,
                color: const Color(0xFF42D678),
              ),
            if (p.hasMagnet)
              _ActiveTimerBadge(
                label: 'MAGNET',
                remaining: p.magnetRemaining,
                total: p.magnetDuration,
                color: const Color(0xFF48B8F0),
              ),
            if (p.hasMultiplier)
              _ActiveTimerBadge(
                label: '2x SCORE',
                remaining: p.multiplierRemaining,
                total: p.multiplierDuration,
                color: const Color(0xFFFFCA42),
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
        color: const Color(0xD41C2C44),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 6,
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
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD81C2C44),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ${remaining.ceil()}s',
            style: TextStyle(
              color: color,
              fontSize: 10.5,
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
        color: const Color(0xDD1C2C44),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD65C), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TAP TO RUN',
            style: TextStyle(
              color: Color(0xFFFFEEAA),
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '◀ ▶ LANE   •   ▲ JUMP   •   ▼ ROLL   •   2× BOARD',
            style: TextStyle(
              color: Color(0xFFE6F4FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverboardButton extends StatelessWidget {
  const _HoverboardButton({required this.game});

  final SoulDuskRunGame game;

  @override
  Widget build(BuildContext context) {
    final p = game.powerUps;
    final active = p.hasShield;
    final ready = p.canActivateShield;
    final label = active
        ? 'BOARD ${p.shieldRemaining.ceil()}s'
        : ready
            ? 'HOVERBOARD'
            : '${p.shieldCooldownRemaining.ceil()}s';
    final accent = active
        ? const Color(0xFF48D4F4)
        : ready
            ? const Color(0xFFFFD65C)
            : const Color(0x88B0BCCB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: ready ? game.activateSolarShield : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xDD1C2C44),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent, width: 1.6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x38000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.surfing_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: ready || active
                      ? const Color(0xFFFFF8EB)
                      : const Color(0xAAB8C6D8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
