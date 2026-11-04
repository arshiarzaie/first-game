import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// The Soul — Pixar-3D volumetric golden sun-child runner (`SOUL: DUSK RUN`
/// S18, low over-the-shoulder chase camera + silky golden sunbeam reflection
/// streaming down the chiseled stone slabs!).
class SoulPlayer extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  SoulPlayer() : super(priority: 2000);

  double _laneX = GameConfig.initialLane.toDouble();
  double _hopStartLane = GameConfig.initialLane.toDouble();
  int _hopTargetLane = GameConfig.initialLane;
  double _hopProgress = 1.0;
  double _elapsed = 0;
  double _lean = 0;
  bool _wasJumping = false;
  double _landingTimer = 0;

  double get currentLane => _laneX;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.playerWidthRatio;
    size = Vector2(width, width);
    _laneX = game.laneSystem.lane.toDouble();
    _hopStartLane = _laneX;
    _hopTargetLane = game.laneSystem.lane;
    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    final targetInt = game.laneSystem.lane;
    if (targetInt != _hopTargetLane) {
      _hopStartLane = _laneX;
      _hopTargetLane = targetInt;
      _hopProgress = 0.0;
    }

    if (_hopProgress < 1.0) {
      _hopProgress = (_hopProgress + dt / GameConfig.laneSwitchSeconds)
          .clamp(0.0, 1.0)
          .toDouble();
      final u = 1.0 - math.pow(1.0 - _hopProgress, 3).toDouble();
      _laneX = _hopStartLane + (_hopTargetLane - _hopStartLane) * u;
    } else {
      _laneX = _hopTargetLane.toDouble();
    }

    final remaining = _hopTargetLane - _laneX;
    _lean = (remaining * 1.35).clamp(-1.0, 1.0).toDouble();

    final jumpingNow = game.verticalMotion.isJumping;
    if (_wasJumping && !jumpingNow && game.isRunStarted) {
      _landingTimer = 0.11;
    }
    _wasJumping = jumpingNow;
    if (_landingTimer > 0) {
      _landingTimer = math.max(0.0, _landingTimer - dt);
    }

    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);
  }

  void reset() {
    _laneX = game.laneSystem.lane.toDouble();
    _hopStartLane = _laneX;
    _hopTargetLane = game.laneSystem.lane;
    _hopProgress = 1.0;
    _lean = 0;
    _wasJumping = false;
    _landingTimer = 0;
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
      } else if (jumping || game.powerUps.hasShield) {
        index = game.powerUps.hasShield ? 1 : 0;
      } else if (sliding) {
        index = 4 % frames.length;
      } else {
        final speedRatio = (game.currentSpeed / GameConfig.startSpeed)
            .clamp(1.0, 1.38)
            .toDouble();
        index = (_elapsed * GameConfig.runCycleFps * speedRatio).floor() %
            frames.length;
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

    final supportElev = game.baseSupportElevation;
    final totalElev = game.effectivePlayerElevation;
    final airAboveSupport = math.max(0.0, totalElev - supportElev);

    final supportLiftPx = supportElev * game.size.y * GameConfig.jumpHeightRatio;
    final totalLiftPx = totalElev * game.size.y * GameConfig.jumpHeightRatio;
    final sliding =
        game.verticalMotion.isSliding && !game.powerUps.isSolarDashing;

    final hopLiftPx = (!sliding && airAboveSupport <= 0.02 && _hopProgress < 1.0)
        ? math.sin(_hopProgress * math.pi) * game.size.y * 0.015
        : 0.0;

    final landingDipPx = _landingTimer > 0
        ? math.sin((_landingTimer / 0.11) * math.pi) * dh * 0.032
        : 0.0;

    final footAnchorShift = dh * 0.37;
    final supportFloorY = h / 2 - supportLiftPx;
    final shadowScale =
        (1.0 - airAboveSupport * 0.42).clamp(0.42, 1.0).toDouble();

    // S18 Signature Silky Golden Sunbeam Ground Reflection & Trail on Flagstones!
    final trailLen =
        math.max(dh * 0.65, (game.size.y - position.y) + supportFloorY);
    final shimmer = 0.90 + 0.10 * math.sin(_elapsed * 9.5);
    final trailAlpha = (shadowScale * shimmer).clamp(0.32, 1.0).toDouble();

    // Wide warm golden specular pool on the stone slabs around Soul
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, supportFloorY + 5),
        width: dw * 0.92 * shadowScale,
        height: dh * 0.20 * shadowScale,
      ),
      Paint()
        ..color = const Color(0xFFFFB844).withValues(alpha: 0.34 * trailAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
    );

    // Streaming golden reflection streak toward the camera behind Soul's feet!
    final streakOuter = Path()
      ..moveTo(w / 2 - dw * 0.15 * shadowScale, supportFloorY + 2)
      ..lineTo(w / 2 + dw * 0.15 * shadowScale, supportFloorY + 2)
      ..lineTo(w / 2 + dw * 0.055, supportFloorY + trailLen)
      ..lineTo(w / 2 - dw * 0.055, supportFloorY + trailLen)
      ..close();
    canvas.drawPath(
      streakOuter,
      Paint()
        ..shader = Gradient.linear(
          Offset(w / 2, supportFloorY),
          Offset(w / 2, supportFloorY + trailLen),
          [
            const Color(0xFFFFBC48).withValues(alpha: 0.56 * trailAlpha),
            const Color(0xFFFF9632).withValues(alpha: 0.24 * trailAlpha),
            const Color(0x00FF8424),
          ],
          const [0.0, 0.55, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.5),
    );

    if (game.isRunStarted) {
      final streakCore = Path()
        ..moveTo(w / 2 - dw * 0.055 * shadowScale, supportFloorY + 1)
        ..lineTo(w / 2 + dw * 0.055 * shadowScale, supportFloorY + 1)
        ..lineTo(w / 2 + dw * 0.018, supportFloorY + trailLen * 0.88)
        ..lineTo(w / 2 - dw * 0.018, supportFloorY + trailLen * 0.88)
        ..close();
      canvas.drawPath(
        streakCore,
        Paint()
          ..shader = Gradient.linear(
            Offset(w / 2, supportFloorY),
            Offset(w / 2, supportFloorY + trailLen * 0.88),
            [
              const Color(0xFFFFF8CA).withValues(alpha: 0.78 * trailAlpha),
              const Color(0xFFFFCA58).withValues(alpha: 0.34 * trailAlpha),
              const Color(0x00FFB438),
            ],
            const [0.0, 0.50, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );
    }

    // Grounded contact shadow directly beneath Soul's feet
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2 - dw * 0.04, supportFloorY + 3),
        width: dw * 0.44 * shadowScale,
        height: dh * 0.085 * shadowScale,
      ),
      Paint()..color = const Color(0x701C122C),
    );

    final hoverSurfBob = game.powerUps.hasShield
        ? math.sin(_elapsed * 5.8) * 3.5 - 5.0
        : 0.0;

    final footY = h / 2 - totalLiftPx - hopLiftPx + hoverSurfBob;

    // 1. Radiant Celestial Golden Sun-Disk beneath Soul's feet (`hasShield`)!
    if (game.powerUps.hasShield) {
      canvas.save();
      canvas.translate(w / 2, footY + 3);
      canvas.rotate(_lean * 0.20);
      final bw = dw * 0.44;
      final bh = dh * 0.10;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: bw * 2.2,
          height: bh * 2.5,
        ),
        Paint()..color = const Color(0x55FFD058),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: bw * 1.85,
          height: bh * 1.9,
        ),
        Paint()..color = const Color(0xEEFFC446),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: bw * 1.85,
          height: bh * 1.9,
        ),
        Paint()
          ..color = const Color(0xFFFFF6CC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      canvas.restore();
    }

    // 2. Sky-Leap golden blessing ring around Soul's feet (`hasSuperSneakers`)
    if (game.powerUps.hasSuperSneakers && !game.powerUps.isSolarDashing) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, footY + 2),
          width: dw * 0.50,
          height: dh * 0.11,
        ),
        Paint()
          ..color = const Color(0xDDFFDF72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }

    final slideDropPx = (sliding && !isDedicatedPose) ? dh * 0.12 : 0.0;
    final bodyCenterY = footY -
        footAnchorShift +
        landingDipPx +
        slideDropPx +
        (sliding && isDedicatedPose ? dh * 0.05 : 0.0);

    // 3. Solar Comet Flight golden light trail (`isSolarDashing`)
    if (game.powerUps.isSolarDashing) {
      final tail = Path()
        ..moveTo(w / 2 - dw * 0.20, bodyCenterY + dh * 0.14)
        ..lineTo(w / 2 + dw * 0.20, bodyCenterY + dh * 0.14)
        ..lineTo(w / 2, bodyCenterY + dh * 0.85)
        ..close();
      canvas.drawPath(
        tail,
        Paint()..color = const Color(0xAAFFC44C),
      );
    }

    // 4. Pixar-3D Soul render
    canvas.save();
    canvas.translate(w / 2, bodyCenterY);
    canvas.rotate(_lean * GameConfig.playerLeanAngle);
    final landingSquash = _landingTimer > 0
        ? math.sin((_landingTimer / 0.11) * math.pi) * 0.045
        : 0.0;
    final sx = ((sliding && !isDedicatedPose) ? 1.12 : 1.0) + landingSquash;
    final sy = ((sliding && !isDedicatedPose) ? 0.72 : 1.0) - landingSquash;
    canvas.scale(sx, sy);

    canvas.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromCenter(center: Offset.zero, width: dw, height: dh),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    if (game.isStumbling) {
      final pulse = 0.55 + 0.45 * math.sin(_elapsed * 14).abs();
      canvas.drawCircle(
        Offset(w / 2, bodyCenterY + dh * 0.04),
        dw * 0.40,
        Paint()
          ..color = const Color(0xFFFF8864).withValues(alpha: 0.65 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    } else if (game.powerUps.hasMagnet) {
      final pulse = 1 + math.sin(_elapsed * 8) * 0.04;
      canvas.drawCircle(
        Offset(w / 2, bodyCenterY + dh * 0.02),
        dw * 0.39 * pulse,
        Paint()
          ..color = const Color(0x99C49BFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
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
    final radius = w * 0.36;

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
