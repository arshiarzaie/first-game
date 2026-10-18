import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/input/lane_gesture_controller.dart';
import '../../game/soul_dusk_run_game.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/pause_overlay.dart';

/// Hosts the Flame game plus its Flutter overlays and owns:
///  * gesture routing (swipe + tap-halves) into lane moves;
///  * app-lifecycle auto-pause (background/hidden/inactive) and a pause
///    button; resume always goes through the pause menu so the player is
///    never dropped back into motion unexpectedly.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final SoulDuskRunGame _game;
  late final LaneGestureController _gestures;

  @override
  void initState() {
    super.initState();
    _game = SoulDuskRunGame();
    _gestures = LaneGestureController(onMove: _game.moveLane);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              // First input of a session starts the run and is swallowed —
              // it must not double as a lane move (start contract).
              if (!_game.isRunStarted) {
                _game.startRun();
                return;
              }
              _gestures.onHorizontalDragEnd(details.primaryVelocity ?? 0.0);
            },
            onTapUp: (details) {
              if (!_game.isRunStarted) {
                _game.startRun();
                return;
              }
              _gestures.onTapUp(
                details.localPosition.dx,
                constraints.maxWidth,
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                GameWidget<SoulDuskRunGame>(
                  game: _game,
                  // Surface scene-load errors visibly instead of rendering
                  // nothing (Flame's default propagates the error, which can
                  // present as a black screen on real devices).
                  errorBuilder: (context, error) => Material(
                    color: const Color(0xFF140D26),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'The scene failed to load.\n$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF6E7C8),
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
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Pause',
                    onPressed: _game.pauseWithMenu,
                    icon: const Icon(
                      Icons.pause_rounded,
                      color: Color(0xFFF6E7C8),
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
