import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// The Soul — golden humanoid sun hero (S12: supports 4-way Subway-tier
/// lane glide, parabolic jump lift with grounded floor shadow, aerodynamic
/// tuck-slide with floor sparks, Solar Aegis crash shield aura, and
/// airborne Sunburst Sky-Dash comet trail).
class SoulPlayer extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  SoulPlayer() : super(priority: 20);

  /// Continuous lane position; fractional while switching lanes.
  double _laneX = GameConfig.initialLane.toDouble();

  /// Animation clock (seconds).
  double _elapsed = 0;

  /// Remaining lane slide (-1..1) — drives lean and stretch.
  double _lean = 0;

  double get currentLane => _laneX;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.playerWidthRatio;
    size = Vector2(width, width * 0.92);
    _laneX = game.laneSystem.lane.toDouble();
    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final target = game.laneSystem.lane.toDouble();
    if (target != _laneX) {
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
      final int index;
      if (!game.isRunStarted) {
        index = GameConfig.runIdleFrame;
      } else if (game.verticalMotion.isJumping ||
          game.powerUps.isSolarDashing) {
        // Hold dynamic airborne stride pose while vaulting or sky-dashing.
        index = 0;
      } else if (game.verticalMotion.isSliding) {
        // Compact tucked pose during a ground slide.
        index = 4 % frames.length;
      } else {
        index = (_elapsed * GameConfig.runCycleFps).floor() % frames.length;
      }
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

  void _renderFrame(Canvas canvas, Image frame) {
    final w = size.x;
    final h = size.y;
    final imgW = frame.width.toDouble();
    final imgH = frame.height.toDouble();
    final fit = math.min(
      (w * 1.30 * GameConfig.runCycleFitBoost) / imgW,
      (h * 1.30 * GameConfig.runCycleFitBoost) / imgH,
    );
    final dw = imgW * fit;
    final dh = imgH * fit;

    final elev = game.effectivePlayerElevation;
    final jumpLiftPx = elev * game.size.y * GameConfig.jumpHeightRatio;
    final sliding =
        game.verticalMotion.isSliding && !game.powerUps.isSolarDashing;
    final slideDropPx = sliding ? dh * 0.14 : 0.0;

    // 1. Grounded floor aura + contact shadow stay on the stone track even
    // while Soul leaps high into the air, shrinking with height for crisp
    // 3D altitude readability.
    final shadowScale = (1.0 - elev * 0.45).clamp(0.45, 1.0);
    final footFloorY = h / 2 + dh * 0.37;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, footFloorY),
        width: dw * 0.64 * shadowScale,
        height: dh * 0.15 * shadowScale,
      ),
      Paint()
        ..color = const Color(0x42FFB830)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, footFloorY + 2),
        width: dw * 0.40 * shadowScale,
        height: dh * 0.09 * shadowScale,
      ),
      Paint()
        ..color = const Color(0x9010061E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final bodyCenterY = h / 2 - jumpLiftPx + slideDropPx;

    // 2. Sunburst Sky-Dash comet tail when flying above the track.
    if (game.powerUps.isSolarDashing) {
      final tail = Path()
        ..moveTo(w / 2 - dw * 0.24, bodyCenterY + dh * 0.10)
        ..lineTo(w / 2 + dw * 0.24, bodyCenterY + dh * 0.10)
        ..lineTo(w / 2, bodyCenterY + dh * 0.85)
        ..close();
      canvas.drawPath(
        tail,
        Paint()
          ..color = const Color(0x88FFB300)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..blendMode = BlendMode.plus,
      );
    }

    // 3. Slide friction sparks on the stone masonry.
    if (sliding) {
      final sparkPaint = Paint()
        ..color = const Color(0xCCFFE082)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;
      for (var i = -1; i <= 1; i += 2) {
        final sx = w / 2 + i * dw * 0.22;
        final jitter = math.sin(_elapsed * 38 + i) * 5;
        canvas.drawLine(
          Offset(sx, footFloorY - 2),
          Offset(sx + i * (14 + jitter.abs()), footFloorY + 8),
          sparkPaint,
        );
      }
    }

    // 4. Character body with jump stretch / slide tuck / lane lean.
    canvas.save();
    canvas.translate(w / 2, bodyCenterY);
    final slideTilt = sliding ? -0.10 : 0.0;
    canvas.rotate(_lean * GameConfig.playerLeanAngle + slideTilt);
    final sx = sliding
        ? 1.15
        : (1 + _lean.abs() * 0.08 - elev * 0.04);
    final sy = sliding
        ? 0.68
        : (1 - _lean.abs() * 0.06 + elev * 0.07);
    canvas.scale(sx, sy);

    canvas.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromCenter(center: Offset.zero, width: dw, height: dh),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    // 5. Solar Aegis crash-shield barrier ring + sun-magnet halo.
    if (game.powerUps.hasShield) {
      final pulse = 1 + math.sin(_elapsed * 7) * 0.04;
      final shieldRadius = dw * 0.48 * pulse;
      final center = Offset(w / 2, bodyCenterY);
      canvas.drawCircle(
        center,
        shieldRadius,
        Paint()
          ..color = const Color(0x28FFD54F)
          ..blendMode = BlendMode.plus,
      );
      canvas.drawCircle(
        center,
        shieldRadius,
        Paint()
          ..color = const Color(0xCCFFE082)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..blendMode = BlendMode.plus,
      );
      canvas.drawCircle(
        center,
        shieldRadius * 1.08,
        Paint()
          ..color = const Color(0x884DD8FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..blendMode = BlendMode.plus,
      );
    } else if (game.powerUps.hasMagnet) {
      final pulse = 1 + math.sin(_elapsed * 9) * 0.06;
      canvas.drawCircle(
        Offset(w / 2, bodyCenterY),
        dw * 0.44 * pulse,
        Paint()
          ..color = const Color(0x774DD8FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..blendMode = BlendMode.plus,
      );
    }
  }

  void _renderSprite(Canvas canvas, Image sprite) {
    final w = size.x;
    final h = size.y;
    final elev = game.effectivePlayerElevation;
    final jumpLiftPx = elev * game.size.y * GameConfig.jumpHeightRatio;
    final bob =
        math.sin(_elapsed * 2 * math.pi * 1.6) * h * GameConfig.playerBobRatio;

    canvas.save();
    canvas.translate(w / 2, h / 2 + bob - jumpLiftPx);
    canvas.rotate(_lean * GameConfig.playerLeanAngle);
    canvas.scale(1 + _lean.abs() * 0.08, 1 - _lean.abs() * 0.06);

    final imgW = sprite.width.toDouble();
    final imgH = sprite.height.toDouble();
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

  void _renderPlaceholder(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final elev = game.effectivePlayerElevation;
    final jumpLiftPx = elev * game.size.y * GameConfig.jumpHeightRatio;
    final center = Offset(w / 2, h / 2 - jumpLiftPx);
    final radius = w * 0.40;

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

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(
      center - Offset(w * 0.05, h * 0.08),
      radius * 0.6,
      Paint()..color = const Color(0x2EFFFFFF),
    );
  }
}
