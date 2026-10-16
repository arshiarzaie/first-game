import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import 'soul_player.dart';

/// A collectible energy orb. Greybox placeholder: cyan glow ring with a
/// cream core. Approach/recycle behavior matches [Obstacle].
class EnergyOrb extends PositionComponent
    with CollisionCallbacks, HasGameReference<SoulDuskRunGame> {
  EnergyOrb({required this.lane}) : super(priority: 9);

  final int lane;
  double _depth = 1.0;
  double _pulsePhase = 0;
  bool _collected = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.entityWidthRatio * 0.75;
    size = Vector2.all(width);

    final factor = GameConfig.hitboxFactor;
    add(RectangleHitbox(
      size: Vector2.all(width * factor),
      position: Vector2.all(width * (1 - factor) / 2),
      collisionType: CollisionType.passive,
    ));

    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 4;
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;
    if (_depth <= 0) {
      removeFromParent(); // missed orbs simply pass by
      return;
    }
    _applyProjection();
  }

  void _applyProjection() {
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth) - size.y * 0.1, // floats above the spikes
    );
    scale = Vector2.all(game.scaleForDepth(_depth));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final center = Offset(w / 2, w / 2);
    final pulse = 1 + math.sin(_pulsePhase) * 0.07;

    // glow
    canvas.drawCircle(
      center,
      w * 0.46 * pulse,
      Paint()..color = const Color(0x404DD8FF),
    );
    // core
    canvas.drawCircle(
      center,
      w * 0.30 * pulse,
      Paint()..color = const Color(0xFFF6E7C8),
    );
    // heart
    canvas.drawCircle(
      center,
      w * 0.14,
      Paint()..color = const Color(0xFF4DD8FF),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_collected || other is! SoulPlayer) {
      return;
    }
    _collected = true;
    game.onOrbCollected();
    removeFromParent();
  }
}
