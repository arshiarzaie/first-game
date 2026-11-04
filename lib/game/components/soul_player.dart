import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// The Soul — crisp sunlit golden humanoid sun runner (S15 Subway-Surfers
/// Grade).
///
/// Features:
///  * Crisp warm-umber cartoon silhouette outline across all 8 athletic run
///    frames, sky-vault jump, and parkour roll poses;
///  * Real 3D Hoverboard (`hasShield`) rendered directly beneath Soul's feet
///    with banked surfing tilt;
///  * Glowing green-gold Super Sneakers aura around Soul's feet when active;
///  * Smooth cubic ease-out lane carve + athletic step-hop arc + touchdown
///    cushion on both ground rails AND 3D train roofs!
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
        // Surfing on Hoverboard holds an athletic poised stance with gentle carve!
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
    // Shadow sits right on the active support surface (track rails OR train roof!)
    final supportFloorY = h / 2 - supportLiftPx;
    final shadowScale =
        (1.0 - airAboveSupport * 0.42).clamp(0.45, 1.0).toDouble();

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, supportFloorY + 2),
        width: dw * 0.46 * shadowScale,
        height: dh * 0.085 * shadowScale,
      ),
      Paint()..color = const Color(0x78302A24),
    );

    final hoverSurfBob = game.powerUps.hasShield
        ? math.sin(_elapsed * 6.0) * 3.5 - 5.0
        : 0.0;

    final footY = h / 2 - totalLiftPx - hopLiftPx + hoverSurfBob;

    // 1. Sleek 3D Teal-and-Gold Subway Hoverboard beneath Soul's feet!
    if (game.powerUps.hasShield) {
      canvas.save();
      canvas.translate(w / 2, footY + 3);
      canvas.rotate(_lean * 0.22);
      final bw = dw * 0.42;
      final bh = dh * 0.095;
      final board = Path()
        ..moveTo(-bw, 0)
        ..lineTo(-bw * 0.38, -bh)
        ..lineTo(bw * 0.38, -bh)
        ..lineTo(bw, 0)
        ..lineTo(bw * 0.52, bh)
        ..lineTo(-bw * 0.52, bh)
        ..close();
      canvas.drawPath(board, Paint()..color = const Color(0xFF26A4C4));
      canvas.drawPath(
        board,
        Paint()
          ..color = const Color(0xFFFFD64E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
      canvas.restore();
    }

    // 2. Super Sneakers emerald-gold foot rings when active!
    if (game.powerUps.hasSuperSneakers && !game.powerUps.isSolarDashing) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, footY + 2),
          width: dw * 0.48,
          height: dh * 0.11,
        ),
        Paint()
          ..color = const Color(0xCC34B864)
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

    // 3. Jetpack golden-orange sky stream when flying high above trains!
    if (game.powerUps.isSolarDashing) {
      final tail = Path()
        ..moveTo(w / 2 - dw * 0.18, bodyCenterY + dh * 0.16)
        ..lineTo(w / 2 + dw * 0.18, bodyCenterY + dh * 0.16)
        ..lineTo(w / 2, bodyCenterY + dh * 0.82)
        ..close();
      canvas.drawPath(
        tail,
        Paint()..color = const Color(0xAAFF9828),
      );
    }

    // 4. Crisp character render
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

    // 5. Magnet / Stumble indicators
    if (game.isStumbling) {
      final pulse = 0.55 + 0.45 * math.sin(_elapsed * 14).abs();
      canvas.drawCircle(
        Offset(w / 2, bodyCenterY + dh * 0.04),
        dw * 0.40,
        Paint()
          ..color = const Color(0xFFE04840).withValues(alpha: 0.70 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    } else if (game.powerUps.hasMagnet) {
      final pulse = 1 + math.sin(_elapsed * 8) * 0.04;
      canvas.drawCircle(
        Offset(w / 2, bodyCenterY + dh * 0.02),
        dw * 0.39 * pulse,
        Paint()
          ..color = const Color(0x992898D8)
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
