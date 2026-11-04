import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// The Soul — Pixar-3D volumetric golden sun-child runner (`SOUL: DUSK RUN`
/// S19):
///  * **Living Main Screen (`isTitleHovering`)**: floats alive in the twilight
///    sky with figure-8 levitation, animated buoyant poses, gently flapping
///    golden Solar Light-Wings, and 3D-orbiting stardust motes;
///  * **Cinematic Flight Descent (`isIntroFlying`)**: arcs upward on `START`,
///    swoops gracefully down onto the ancient stone bridge with a curved golden
///    comet ribbon and dynamic aerial banking;
///  * **Ground Running (`isGroundRunning`)**: lands with a cushioned knee-dip
///    and sprints forward down the stone slabs casting a silky golden sunbeam
///    ground reflection!
class SoulPlayer extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  SoulPlayer() : super(priority: 2000);

  static const List<int> _hoverFrameCycle = [1, 2, 3, 2, 1, 0, 7, 0];
  static const int _maxTrailPoints = 20;

  double _laneX = GameConfig.initialLane.toDouble();
  double _hopStartLane = GameConfig.initialLane.toDouble();
  int _hopTargetLane = GameConfig.initialLane;
  double _hopProgress = 1.0;
  double _elapsed = 0;
  double _lean = 0;
  bool _wasJumping = false;
  double _landingTimer = 0;
  double _trailFade = 0;
  double _trailSampleTimer = 0;
  final List<Offset> _flightTrail = <Offset>[];

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

  /// Triggered at the exact frame Soul's sky-flight touches down on the bridge.
  void onIntroTouchdown() {
    _landingTimer = 0.14;
  }

  double get _aerialOffsetX {
    final w = size.x;
    if (game.isTitleHovering) {
      return math.sin(_elapsed * 1.45) * w * 0.16;
    }
    if (game.isIntroFlying) {
      final u = game.introFlightProgress.clamp(0.0, 1.0).toDouble();
      return math.sin(u * math.pi) * math.sin(u * math.pi * 1.65) * w * 0.42;
    }
    return 0.0;
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

    if (game.isTitleHovering) {
      _lean = math.cos(_elapsed * 1.45) * 0.48;
    } else if (game.isIntroFlying) {
      final u = game.introFlightProgress.clamp(0.0, 1.0).toDouble();
      final bankWave = math.cos(u * math.pi * 1.65) * math.sin(u * math.pi);
      _lean = (bankWave * 1.25).clamp(-1.0, 1.0).toDouble();
    } else {
      final remaining = _hopTargetLane - _laneX;
      _lean = (remaining * 1.35).clamp(-1.0, 1.0).toDouble();
    }

    final jumpingNow = game.verticalMotion.isJumping;
    if (_wasJumping && !jumpingNow && game.isGroundRunning) {
      _landingTimer = 0.11;
    }
    _wasJumping = jumpingNow;
    if (_landingTimer > 0) {
      _landingTimer = math.max(0.0, _landingTimer - dt);
    }

    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);

    // Sample curved screen-space comet ribbon during intro flight!
    if (game.isIntroFlying) {
      _trailFade = 1.0;
      _trailSampleTimer += dt;
      if (_trailSampleTimer >= 0.016 || _flightTrail.isEmpty) {
        _trailSampleTimer = 0;
        final liftPx =
            game.effectivePlayerElevation * game.size.y * GameConfig.jumpHeightRatio;
        final worldPt = Offset(
          position.x + _aerialOffsetX,
          position.y - liftPx - size.y * 0.30,
        );
        _flightTrail.add(worldPt);
        if (_flightTrail.length > _maxTrailPoints) {
          _flightTrail.removeAt(0);
        }
      }
    } else if (_trailFade > 0) {
      _trailFade = math.max(0.0, _trailFade - dt * 3.6);
      if (_trailFade <= 0) {
        _flightTrail.clear();
      }
    }
  }

  void reset() {
    _laneX = game.laneSystem.lane.toDouble();
    _hopStartLane = _laneX;
    _hopTargetLane = game.laneSystem.lane;
    _hopProgress = 1.0;
    _lean = 0;
    _wasJumping = false;
    _landingTimer = 0;
    _trailFade = 0;
    _trailSampleTimer = 0;
    _flightTrail.clear();
    position = Vector2(game.laneXOnPlayerPlane(_laneX), game.playerPlaneY);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final frames = game.runFrames;
    final inIntroSoar = game.isIntroFlying && game.introFlightProgress < 0.84;
    final jumping = inIntroSoar ||
        game.verticalMotion.isJumping ||
        game.powerUps.isSolarDashing;
    final sliding = !game.isTitleHovering &&
        !game.isIntroFlying &&
        game.verticalMotion.isSliding &&
        !game.powerUps.isSolarDashing;

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
      if (game.isTitleHovering) {
        final step = (_elapsed * 4.2).floor() % _hoverFrameCycle.length;
        index = _hoverFrameCycle[step] % frames.length;
      } else if (game.isIntroFlying) {
        // Final pre-touchdown stride reach (`u >= 0.84`)
        index = 2 % frames.length;
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

    final skyZoom = game.isTitleHovering
        ? 1.12
        : (game.isIntroFlying
            ? 1.0 + 0.14 * (1.0 - game.introFlightProgress)
            : 1.0);

    final fit = math.min(
          (w * 1.24 * GameConfig.runCycleFitBoost) / imgW,
          (h * 1.24 * GameConfig.runCycleFitBoost) / imgH,
        ) *
        skyZoom;
    final dw = imgW * fit;
    final dh = imgH * fit;

    final supportElev = game.baseSupportElevation;
    final totalElev = game.effectivePlayerElevation;
    final airAboveSupport = math.max(0.0, totalElev - supportElev);

    final supportLiftPx = supportElev * game.size.y * GameConfig.jumpHeightRatio;
    final totalLiftPx = totalElev * game.size.y * GameConfig.jumpHeightRatio;
    final sliding = !game.isTitleHovering &&
        !game.isIntroFlying &&
        game.verticalMotion.isSliding &&
        !game.powerUps.isSolarDashing;

    final hopLiftPx = (!sliding && airAboveSupport <= 0.02 && _hopProgress < 1.0)
        ? math.sin(_hopProgress * math.pi) * game.size.y * 0.015
        : 0.0;

    final landingDipPx = _landingTimer > 0
        ? math.sin((_landingTimer / 0.14).clamp(0.0, 1.0) * math.pi) * dh * 0.036
        : 0.0;

    final footAnchorShift = dh * 0.37;
    final supportFloorY = h / 2 - supportLiftPx;
    final aerialDx = _aerialOffsetX;
    final centerX = w / 2 + aerialDx;
    final shadowScale =
        (1.0 - airAboveSupport * 0.36).clamp(0.34, 1.0).toDouble();

    // 1. Curved Golden Comet Flight Ribbon (during START sky-flight descent!)
    if (_trailFade > 0 && _flightTrail.length >= 2) {
      _renderCurvedFlightRibbon(canvas, w, h);
    }

    // 2. Signature Silky Golden Sunbeam Ground Reflection on the Stone Slabs!
    final trailLen =
        math.max(dh * 0.65, (game.size.y - position.y) + supportFloorY);
    final shimmer = 0.90 + 0.10 * math.sin(_elapsed * 9.5);
    final trailAlpha = (shadowScale * shimmer).clamp(0.28, 1.0).toDouble();

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, supportFloorY + 5),
        width: dw * 0.92 * shadowScale,
        height: dh * 0.20 * shadowScale,
      ),
      Paint()
        ..color = const Color(0xFFFFB844).withValues(alpha: 0.34 * trailAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
    );

    final streakOuter = Path()
      ..moveTo(centerX - dw * 0.15 * shadowScale, supportFloorY + 2)
      ..lineTo(centerX + dw * 0.15 * shadowScale, supportFloorY + 2)
      ..lineTo(centerX + dw * 0.055, supportFloorY + trailLen)
      ..lineTo(centerX - dw * 0.055, supportFloorY + trailLen)
      ..close();
    canvas.drawPath(
      streakOuter,
      Paint()
        ..shader = Gradient.linear(
          Offset(centerX, supportFloorY),
          Offset(centerX, supportFloorY + trailLen),
          [
            const Color(0xFFFFBC48).withValues(alpha: 0.54 * trailAlpha),
            const Color(0xFFFF9632).withValues(alpha: 0.22 * trailAlpha),
            const Color(0x00FF8424),
          ],
          const [0.0, 0.55, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.5),
    );

    if (game.isGroundRunning) {
      final streakCore = Path()
        ..moveTo(centerX - dw * 0.055 * shadowScale, supportFloorY + 1)
        ..lineTo(centerX + dw * 0.055 * shadowScale, supportFloorY + 1)
        ..lineTo(centerX + dw * 0.018, supportFloorY + trailLen * 0.88)
        ..lineTo(centerX - dw * 0.018, supportFloorY + trailLen * 0.88)
        ..close();
      canvas.drawPath(
        streakCore,
        Paint()
          ..shader = Gradient.linear(
            Offset(centerX, supportFloorY),
            Offset(centerX, supportFloorY + trailLen * 0.88),
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

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX - dw * 0.04, supportFloorY + 3),
        width: dw * 0.44 * shadowScale,
        height: dh * 0.085 * shadowScale,
      ),
      Paint()..color = Color.fromARGB((112 * shadowScale).round(), 28, 18, 44),
    );

    final hoverSurfBob = game.powerUps.hasShield
        ? math.sin(_elapsed * 5.8) * 3.5 - 5.0
        : 0.0;

    final footY = h / 2 - totalLiftPx - hopLiftPx + hoverSurfBob;
    final slideDropPx = (sliding && !isDedicatedPose) ? dh * 0.12 : 0.0;
    final bodyCenterY = footY -
        footAnchorShift +
        landingDipPx +
        slideDropPx +
        (sliding && isDedicatedPose ? dh * 0.05 : 0.0);

    // 3. Living Sky-Hover & Flight Solar Aura + Flapping Light-Wings + Back Motes!
    if (game.isTitleHovering || game.isIntroFlying) {
      _renderCelestialHoverAuraAndWings(
        canvas,
        cx: centerX,
        cy: bodyCenterY + dh * 0.04,
        dw: dw,
        dh: dh,
      );
      _renderOrbitingStardustMotes(
        canvas,
        cx: centerX,
        cy: bodyCenterY + dh * 0.04,
        dw: dw,
        frontHalf: false,
      );
    }

    // 4. Radiant Celestial Golden Sun-Disk (`hasShield`)!
    if (game.powerUps.hasShield) {
      canvas.save();
      canvas.translate(centerX, footY + 3);
      canvas.rotate(_lean * 0.20);
      final bw = dw * 0.44;
      final bh = dh * 0.10;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: bw * 2.2, height: bh * 2.5),
        Paint()..color = const Color(0x55FFD058),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: bw * 1.85, height: bh * 1.9),
        Paint()..color = const Color(0xEEFFC446),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: bw * 1.85, height: bh * 1.9),
        Paint()
          ..color = const Color(0xFFFFF6CC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      canvas.restore();
    }

    if (game.powerUps.hasSuperSneakers && !game.powerUps.isSolarDashing) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centerX, footY + 2),
          width: dw * 0.50,
          height: dh * 0.11,
        ),
        Paint()
          ..color = const Color(0xDDFFDF72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }

    if (game.powerUps.isSolarDashing) {
      final tail = Path()
        ..moveTo(centerX - dw * 0.20, bodyCenterY + dh * 0.14)
        ..lineTo(centerX + dw * 0.20, bodyCenterY + dh * 0.14)
        ..lineTo(centerX, bodyCenterY + dh * 0.85)
        ..close();
      canvas.drawPath(tail, Paint()..color = const Color(0xAAFFC44C));
    }

    // 5. Pixar-3D Soul Render (with living breathing scale in Title Hover!)
    canvas.save();
    canvas.translate(centerX, bodyCenterY);
    canvas.rotate(_lean * GameConfig.playerLeanAngle);

    final breathWave =
        game.isTitleHovering ? math.sin(_elapsed * 2.8) * 0.026 : 0.0;
    final landingSquash = _landingTimer > 0
        ? math.sin((_landingTimer / 0.14).clamp(0.0, 1.0) * math.pi) * 0.055
        : 0.0;
    final sx =
        ((sliding && !isDedicatedPose) ? 1.12 : 1.0) + landingSquash + breathWave;
    final sy =
        ((sliding && !isDedicatedPose) ? 0.72 : 1.0) - landingSquash - breathWave * 0.8;
    canvas.scale(sx, sy);

    canvas.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromCenter(center: Offset.zero, width: dw, height: dh),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    // Front half of 3D orbiting golden stardust motes!
    if (game.isTitleHovering || game.isIntroFlying) {
      _renderOrbitingStardustMotes(
        canvas,
        cx: centerX,
        cy: bodyCenterY + dh * 0.04,
        dw: dw,
        frontHalf: true,
      );
    }

    if (game.isStumbling) {
      final pulse = 0.55 + 0.45 * math.sin(_elapsed * 14).abs();
      canvas.drawCircle(
        Offset(centerX, bodyCenterY + dh * 0.04),
        dw * 0.40,
        Paint()
          ..color = const Color(0xFFFF8864).withValues(alpha: 0.65 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    } else if (game.powerUps.hasMagnet) {
      final pulse = 1 + math.sin(_elapsed * 8) * 0.04;
      canvas.drawCircle(
        Offset(centerX, bodyCenterY + dh * 0.02),
        dw * 0.39 * pulse,
        Paint()
          ..color = const Color(0x99C49BFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  /// Renders Soul's warm breathing solar halo and gently flapping golden
  /// Solar Light-Wings while hovering on the Main Screen or flying down!
  void _renderCelestialHoverAuraAndWings(
    Canvas canvas, {
    required double cx,
    required double cy,
    required double dw,
    required double dh,
  }) {
    final fade = game.isIntroFlying
        ? (1.0 - ((game.introFlightProgress - 0.65) / 0.35).clamp(0.0, 1.0))
            .toDouble()
        : 1.0;
    if (fade <= 0.01) {
      return;
    }

    final pulse = 0.90 + 0.10 * math.sin(_elapsed * 3.4);
    final auraR = dw * 0.72 * pulse;
    canvas.drawCircle(
      Offset(cx, cy),
      auraR,
      Paint()
        ..shader = Gradient.radial(
          Offset(cx, cy),
          auraR,
          [
            const Color(0xFFFFF4C4).withValues(alpha: 0.44 * fade),
            const Color(0xFFFFB84C).withValues(alpha: 0.20 * fade),
            const Color(0x00FF9838),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // Sculpted translucent golden Solar Light-Wings flapping gently!
    final flapSpeed = game.isIntroFlying ? 9.5 : 2.6;
    final flap = math.sin(_elapsed * flapSpeed);
    final wingSpan = dw * (game.isIntroFlying ? 0.64 : 0.52);
    final wingLift = dh * (0.16 + 0.10 * flap);

    for (final side in const [-1.0, 1.0]) {
      final wing = Path()
        ..moveTo(cx + side * dw * 0.10, cy + dh * 0.02)
        ..quadraticBezierTo(
          cx + side * wingSpan * 0.72,
          cy - wingLift - dh * 0.14,
          cx + side * wingSpan,
          cy - wingLift * 0.45,
        )
        ..quadraticBezierTo(
          cx + side * wingSpan * 0.58,
          cy + dh * 0.12,
          cx + side * dw * 0.12,
          cy + dh * 0.12,
        )
        ..close();

      canvas.drawPath(
        wing,
        Paint()
          ..shader = Gradient.linear(
            Offset(cx + side * dw * 0.10, cy),
            Offset(cx + side * wingSpan, cy - wingLift * 0.45),
            [
              const Color(0xFFFFF4B8).withValues(alpha: 0.62 * fade),
              const Color(0xFFFFAE42).withValues(alpha: 0.12 * fade),
            ],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );
    }
  }

  /// Renders 8 golden stardust motes orbiting Soul in a tilted 3D ring.
  void _renderOrbitingStardustMotes(
    Canvas canvas, {
    required double cx,
    required double cy,
    required double dw,
    required bool frontHalf,
  }) {
    final fade = game.isIntroFlying
        ? (1.0 - game.introFlightProgress).clamp(0.0, 1.0).toDouble()
        : 1.0;
    if (fade <= 0.02) {
      return;
    }

    const moteCount = 8;
    final rx = dw * 0.54;
    final ry = dw * 0.18;
    for (var i = 0; i < moteCount; i++) {
      final angle = _elapsed * 1.9 + (i * 2 * math.pi / moteCount);
      final sinA = math.sin(angle);
      final isFront = sinA >= 0;
      if (isFront != frontHalf) {
        continue;
      }
      final mx = cx + math.cos(angle) * rx;
      final my = cy + sinA * ry - math.cos(angle * 2.0 + i) * dw * 0.05;
      final r = (2.4 + 1.2 * (sinA * 0.5 + 0.5));
      canvas.drawCircle(
        Offset(mx, my),
        r * 2.1,
        Paint()..color = const Color(0xFFFFC854).withValues(alpha: 0.36 * fade),
      );
      canvas.drawCircle(
        Offset(mx, my),
        r * 0.85,
        Paint()..color = const Color(0xFFFFFCE8).withValues(alpha: 0.88 * fade),
      );
    }
  }

  /// Draws the curved golden-white comet flight ribbon recorded in screen space!
  void _renderCurvedFlightRibbon(Canvas canvas, double w, double h) {
    final originX = position.x - w / 2;
    final originY = position.y - h / 2;
    final n = _flightTrail.length;

    for (var i = 1; i < n; i++) {
      final frac = i / n;
      final p0 = Offset(
        _flightTrail[i - 1].dx - originX,
        _flightTrail[i - 1].dy - originY,
      );
      final p1 = Offset(
        _flightTrail[i].dx - originX,
        _flightTrail[i].dy - originY,
      );
      final alpha = (frac * frac * _trailFade).clamp(0.0, 1.0).toDouble();
      final strokeOuter = (w * 0.16 * frac).clamp(2.0, 26.0).toDouble();
      final strokeCore = (w * 0.055 * frac).clamp(1.0, 9.0).toDouble();

      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0xFFFFB43E).withValues(alpha: 0.42 * alpha)
          ..strokeWidth = strokeOuter
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
      );
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0xFFFFF8D2).withValues(alpha: 0.82 * alpha)
          ..strokeWidth = strokeCore
          ..strokeCap = StrokeCap.round,
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
    canvas.translate(w / 2 + _aerialOffsetX, h / 2 + bob - jumpLiftPx);
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
    final center = Offset(w / 2 + _aerialOffsetX, h / 2 - jumpLiftPx);
    final radius = w * 0.36;

    final rayPaint = Paint()..color = const Color(0xFFFF9F68);
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5 + _elapsed * 0.8;
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
