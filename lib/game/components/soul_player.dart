import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// The Soul — the game's central character. P2 visual slice: renders the
/// production hero sprite (pre-rendered stylized 3D-cartoon sun loaded on
/// the game; magenta plate keyed to real alpha at load time) with light
/// idle bob and lane-switch lean. When the sprite is unavailable it falls
/// back to the original canvas placeholder so the character is never
/// invisible (notably in test environments without bundled assets).
///
/// Lane movement, hitbox and seat/size math are unchanged from Phase 1 —
/// only the presentation layer is re-skinned.
class SoulPlayer extends PositionComponent
    with CollisionCallbacks, HasGameReference<SoulDuskRunGame> {
  SoulPlayer() : super(priority: 20);

  /// Continuous lane position; fractional while switching lanes.
  double _laneX = GameConfig.initialLane.toDouble();

  /// Idle-animation clock (seconds).
  double _elapsed = 0;

  /// Remaining lane slide (-1..1) — drives lean and stretch.
  double _lean = 0;

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
    _elapsed += dt;
    final target = game.laneSystem.lane.toDouble();
    if (target != _laneX) {
      // Linear slide completing one lane change in laneSwitchSeconds.
      final maxDelta = dt / GameConfig.laneSwitchSeconds;
      final delta = (target - _laneX).clamp(-maxDelta, maxDelta).toDouble();
      _laneX += delta;
    }
    _lean = (target - _laneX).clamp(-1.0, 1.0).toDouble();
    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);
  }

  void reset() {
    _laneX = game.laneSystem.lane.toDouble();
    _lean = 0;
    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final frames = game.runFrames;
    if (frames.isNotEmpty) {
      final index =
          (_elapsed * GameConfig.runCycleFps).floor() % frames.length;
      _renderFrame(canvas, frames[index]);
      return;
    }
    final sprite = game.soulSprite;
    if (sprite == null) {
      _renderPlaceholder(canvas);
      return;
    }
    _renderSprite(canvas, sprite);
  }

  /// P3B production render: the approved 8-frame run cycle (pre-keyed
  /// RGBA, 12 fps). Lane-switch lean/squash are kept; the sine idle-bob
  /// is intentionally absent — the frames carry their own bounce and
  /// stride, so the character's position stays stable across the loop.
  void _renderFrame(Canvas canvas, Image frame) {
    final w = size.x;
    final h = size.y;
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(_lean * GameConfig.playerLeanAngle);
    canvas.scale(1 + _lean.abs() * 0.08, 1 - _lean.abs() * 0.06);

    final imgW = frame.width.toDouble();
    final imgH = frame.height.toDouble();
    // Frames hold ~53% content inside a 512×512 plate; the fit boost
    // normalizes the drawn silhouette to the established hero size.
    final fit = math.min(
      (w * 1.30 * GameConfig.runCycleFitBoost) / imgW,
      (h * 1.30 * GameConfig.runCycleFitBoost) / imgH,
    );
    canvas.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromCenter(
        center: Offset.zero,
        width: imgW * fit,
        height: imgH * fit,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  /// Production render: keyed sprite, gentle idle bob, roll + squash while
  /// sliding lanes. All motion is decorative — hitbox stays fixed.
  void _renderSprite(Canvas canvas, Image sprite) {
    final w = size.x;
    final h = size.y;
    final bob =
        math.sin(_elapsed * 2 * math.pi * 1.6) * h * GameConfig.playerBobRatio;

    canvas.save();
    canvas.translate(w / 2, h / 2 + bob);
    canvas.rotate(_lean * GameConfig.playerLeanAngle);
    // Light stretch in glide direction, slight squash vertically.
    canvas.scale(1 + _lean.abs() * 0.08, 1 - _lean.abs() * 0.06);

    final imgW = sprite.width.toDouble();
    final imgH = sprite.height.toDouble();
    // Contain-fit into a slightly enlarged box: the cropped sprite's own
    // bounding box includes the ray tips, so scale up a touch to keep the
    // body mass comparable to the Phase 1 silhouette.
    final boxW = w * 1.30;
    final boxH = h * 1.30;
    final fit = math.min(boxW / imgW, boxH / imgH);
    canvas.drawImageRect(
      sprite,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromCenter(
        center: Offset.zero,
        width: imgW * fit,
        height: imgH * fit,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  /// Canvas placeholder (Phase 1 greybox): golden sun with rays and a
  /// friendly face. Kept as the no-asset fallback.
  void _renderPlaceholder(Canvas canvas) {
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
