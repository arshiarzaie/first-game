import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import 'soul_player.dart';

/// A shadow spike the player must dodge by changing lanes.
/// S5: renders the pre-rendered dark crystal-spike sprite (chroma-keyed
/// at load); if the sprite is unavailable the approved canvas crystal
/// placeholder is drawn instead (never a blank obstacle).
///
/// Spawns at the horizon (depth 1), approaches the player as depth
/// decreases towards 0, and is recycled when it passes the player plane.
class Obstacle extends PositionComponent
    with CollisionCallbacks, HasGameReference<SoulDuskRunGame> {
  Obstacle({required this.lane}) : super(priority: 10);

  final int lane;
  double _depth = 1.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.entityWidthRatio;
    size = Vector2(width, width);

    final factor = GameConfig.hitboxFactor;
    add(RectangleHitbox(
      size: Vector2(width * factor, width * factor),
      position:
          Vector2(width * (1 - factor) / 2, width * (1 - factor) / 2),
      collisionType: CollisionType.passive,
    ));

    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;
    if (_depth <= 0) {
      removeFromParent(); // passed the player without a hit
      return;
    }
    _applyProjection();
  }

  void _applyProjection() {
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth),
    );
    scale = Vector2.all(game.scaleForDepth(_depth));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;

    final sprite = game.obstacleSprite;
    if (sprite != null) {
      // Contain-fit: keep the sprite's aspect inside the (unchanged)
      // gameplay box; the hitbox contract is unaffected by art.
      final fit = (w / sprite.width < h / sprite.height)
          ? w / sprite.width
          : h / sprite.height;
      final dw = sprite.width * fit;
      final dh = sprite.height * fit;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.93),
          width: dw * 0.80,
          height: dh * 0.22,
        ),
        Paint()
          ..color = const Color(0x800D051A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(),
            sprite.height.toDouble()),
        Rect.fromLTWH((w - dw) / 2, h - dh, dw, dh),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }

    final fill = Paint()..color = const Color(0xFF1C1030);
    final edge = Paint()
      ..color = const Color(0xFF8E7CC3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeJoin = StrokeJoin.round;

    final spike = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(spike, fill);
    canvas.drawPath(spike, edge);

    // inner facet so it reads as a stylized crystal, not a flat triangle
    final facet = Path()
      ..moveTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.62, h * 0.85)
      ..lineTo(w * 0.38, h * 0.85)
      ..close();
    canvas.drawPath(facet, Paint()..color = const Color(0xFF3A2660));
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is SoulPlayer) {
      game.onPlayerHit();
    }
  }
}
