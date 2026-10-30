import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// The Soul — golden humanoid sun hero (S13: locked circular 3D sun-head
/// silhouette across all 8 symmetrical run frames, dedicated 3D `jump.png`
/// sky-vault & `slide.png` parkour tuck poses, crisp grounded shadow,
/// Solar Aegis barrier ring, and Sunburst Sky-Dash comet tail).
class SoulPlayer extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  SoulPlayer() : super(priority: 20);

  double _laneX = GameConfig.initialLane.toDouble();
  double _elapsed = 0;
  double _lean = 0;

  double get currentLane => _laneX;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.playerWidthRatio;
    size = Vector2(width, width);
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
    final jumping =
        game.verticalMotion.isJumping || game.powerUps.isSolarDashing;
    final sliding =
        game.verticalMotion.isSliding && !game.powerUps.isSolarDashing;

    if (jumping && game.soulJumpSprite != null) {
      _renderFrame(canvas, game.soulJumpSprite!, isDedicatedPose: true);
      return;
    }
    if (sliding && game.soulSlideSprite != null) {
      _renderFrame(canvas, game.soulSlideSprite!, isDedicatedPose: true);
      return;
    }
    if (frames.isNotEmpty) {
      final int index;
      if (!game.isRunStarted) {
        index = GameConfig.runIdleFrame;
      } else if (jumping) {
        index = 0;
      } else if (sliding) {
        index = 4 % frames.length;
      } else {
        index = (_elapsed * GameConfig.runCycleFps).floor() % frames.length;
      }
      _renderFrame(canvas, frames[index], isDedicatedPose: false);
      return;
    }

    final sprite = game.soulSprite;
    if (sprite == null) {
      _renderPlaceholder(canvas);
      return;
    }
    _renderSprite(canvas, sprite);
  }

  void _renderFrame(
    Canvas canvas,
    Image frame, {
    required bool isDedicatedPose,
  }) {
    final w = size.x;
    final h = size.y;
    final imgW = frame.width.toDouble();
    final imgH = frame.height.toDouble();
    final fit = math.min(
      (w * 1.24 * GameConfig.runCycleFitBoost) / imgW,
      (h * 1.24 * GameConfig.runCycleFitBoost) / imgH,
    );
    final dw = imgW * fit;
    final dh = imgH * fit;

    final elev = game.effectivePlayerElevation;
    final jumpLiftPx = elev * game.size.y * GameConfig.jumpHeightRatio;
    final sliding =
        game.verticalMotion.isSliding && !game.powerUps.isSolarDashing;

    // In our 640x640 S13 sprites, Soul's planted feet sit at y ≈ 546/640
    // (+0.353 * dh below sprite center). Shift sprite upward so feet rest
    // cleanly right at SoulPlayer's center (`playerPlaneY`)!
    final footAnchorShift = dh * 0.35;
    final footFloorY = h / 2;

    // 1. Soft feathered ground shadow + warm solar floor reflection.
    final shadowScale = (1.0 - elev * 0.48).clamp(0.42, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, footFloorY),
        width: dw * 0.56 * shadowScale,
        height: dh * 0.13 * shadowScale,
      ),
      Paint()
        ..color = const Color(0x36FFB830)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, footFloorY + 2),
        width: dw * 0.36 * shadowScale,
        height: dh * 0.08 * shadowScale,
      ),
      Paint()
        ..color = const Color(0x960D051A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final slideDropPx = (sliding && !isDedicatedPose) ? dh * 0.12 : 0.0;
    final bodyCenterY =
        h / 2 - footAnchorShift - jumpLiftPx + slideDropPx + (sliding && isDedicatedPose ? dh * 0.06 : 0.0);

    // 2. Sunburst Sky-Dash comet tail when flying above the track.
    if (game.powerUps.isSolarDashing) {
      final tail = Path()
        ..moveTo(w / 2 - dw * 0.22, bodyCenterY + dh * 0.14)
        ..lineTo(w / 2 + dw * 0.22, bodyCenterY + dh * 0.14)
        ..lineTo(w / 2, bodyCenterY + dh * 0.86)
        ..close();
      canvas.drawPath(
        tail,
        Paint()
          ..color = const Color(0x88FFB300)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..blendMode = BlendMode.plus,
      );
    }

    // 3. Slide friction sparks on the stone flagstones.
    if (sliding) {
      final sparkPaint = Paint()
        ..color = const Color(0xDDFFE082)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;
      for (var i = -1; i <= 1; i += 2) {
        final sx = w / 2 + i * dw * 0.18;
        final jitter = math.sin(_elapsed * 40 + i) * 5;
        canvas.drawLine(
          Offset(sx, footFloorY - 2),
          Offset(sx + i * (13 + jitter.abs()), footFloorY + 7),
          sparkPaint,
        );
      }
    }

    // 4. Crisp high-DPI character render (no rubber-band head squash!).
    canvas.save();
    canvas.translate(w / 2, bodyCenterY);
    canvas.rotate(_lean * GameConfig.playerLeanAngle);
    final sx = (sliding && !isDedicatedPose) ? 1.12 : 1.0;
    final sy = (sliding && !isDedicatedPose) ? 0.72 : 1.0;
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
      final shieldRadius = dw * 0.44 * pulse;
      final center = Offset(w / 2, bodyCenterY + dh * 0.02);
      canvas.drawCircle(
        center,
        shieldRadius,
        Paint()
          ..color = const Color(0x26FFD54F)
          ..blendMode = BlendMode.plus,
      );
      canvas.drawCircle(
        center,
        shieldRadius,
        Paint()
          ..color = const Color(0xCCFFE082)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..blendMode = BlendMode.plus,
      );
      canvas.drawCircle(
        center,
        shieldRadius * 1.07,
        Paint()
          ..color = const Color(0x884DD8FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..blendMode = BlendMode.plus,
      );
    } else if (game.powerUps.hasMagnet) {
      final pulse = 1 + math.sin(_elapsed * 9) * 0.05;
      canvas.drawCircle(
        Offset(w / 2, bodyCenterY + dh * 0.02),
        dw * 0.40 * pulse,
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

    final imgW = sprite.width.toDouble();
    final imgH = sprite.height.toDouble();
    final fit = math.min((w * 1.25) / imgW, (h * 1.25) / imgH);
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
    final radius = w * 0.38;

    final rayPaint = Paint()..color = const Color(0xFFFF9F68);
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final perp = Offset(-dir.dy, dir.dx) * (w * 0.05);
      final inner = center + dir * radius * 0.88;
      final tip = center + dir * (radius + w * 0.12);
      final ray = Path()
        ..moveTo(inner.dx + perp.dx, inner.dy + perp.dy)
        ..lineTo(inner.dx - perp.dx, inner.dy - perp.dy)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      canvas.drawPath(ray, rayPaint);
    }

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFD166));
  }
}
