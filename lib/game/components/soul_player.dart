import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// Greybox Soul placeholder: a golden sun drawn with the Canvas (circle body,
/// triangle rays, friendly face). This is NOT final character art — it only
/// captures the recognizable identity cues (rounded sun, rays, gold) while
/// production Soul assets are pending approval.
class SoulPlayer extends PositionComponent
    with CollisionCallbacks, HasGameReference<SoulDuskRunGame> {
  SoulPlayer() : super(priority: 20);

  /// Continuous lane position; fractional while switching lanes.
  double _laneX = GameConfig.initialLane.toDouble();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.playerWidthRatio;
    size = Vector2(width, width * 0.92);
    _laneX = game.laneSystem.lane.toDouble();
    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);

    // Grace-margin hitbox: smaller than the visual so collisions feel fair.
    final factor = GameConfig.hitboxFactor;
    add(RectangleHitbox(
      size: Vector2(size.x * factor, size.y * factor),
      position:
          Vector2(size.x * (1 - factor) / 2, size.y * (1 - factor) / 2),
      collisionType: CollisionType.active,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = game.laneSystem.lane.toDouble();
    if (target != _laneX) {
      // Linear slide completing one lane change in laneSwitchSeconds.
      final maxDelta = dt / GameConfig.laneSwitchSeconds;
      final delta = (target - _laneX).clamp(-maxDelta, maxDelta).toDouble();
      _laneX += delta;
    }
    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);
  }

  void reset() {
    _laneX = game.laneSystem.lane.toDouble();
    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.40;

    // --- rays ---
    final rayPaint = Paint()..color = const Color(0xFFFF9F68);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final perp = Offset(-dir.dy, dir.dx) * (w * 0.055);
      final inner = center + dir * radius * 0.9;
      final tip = center + dir * (radius + w * 0.13);
      final ray = Path()
        ..moveTo(inner.dx + perp.dx, inner.dy + perp.dy)
        ..lineTo(inner.dx - perp.dx, inner.dy - perp.dy)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      canvas.drawPath(ray, rayPaint);
    }

    // --- body ---
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFD166));

    // --- soft top-left highlight ---
    canvas.drawCircle(
      center - Offset(w * 0.05, h * 0.08),
      radius * 0.6,
      Paint()..color = const Color(0x2EFFFFFF),
    );

    // --- eyes ---
    final eyePaint = Paint()..color = const Color(0xFF3A2A28);
    final eyeY = center.dy - radius * 0.12;
    final eyeDx = radius * 0.42;
    final eyeR = w * 0.065;
    final glint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(Offset(center.dx - eyeDx, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(center.dx + eyeDx, eyeY), eyeR, eyePaint);
    canvas.drawCircle(
        Offset(center.dx - eyeDx + eyeR * 0.35, eyeY - eyeR * 0.35),
        eyeR * 0.32,
        glint);
    canvas.drawCircle(
        Offset(center.dx + eyeDx + eyeR * 0.35, eyeY - eyeR * 0.35),
        eyeR * 0.32,
        glint);

    // --- smile ---
    final smileRect = Rect.fromCenter(
      center: center + Offset(0, radius * 0.28),
      width: radius * 0.9,
      height: radius * 0.55,
    );
    final smilePaint = Paint()
      ..color = const Color(0xFF3A2A28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(smileRect, math.pi * 0.15, math.pi * 0.7, false, smilePaint);
  }
}
