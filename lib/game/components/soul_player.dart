import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// The Soul — Pixar-3D volumetric golden sun-child (`SOUL: DUSK RUN` S20):
///
///  1. **Close-Up Front-Facing Living Main Screen (`06-22-47.png`)**: floats
///     large & close to the camera in 3/4 front view, smiling, blinking
///     naturally, breathing, and trailing curved golden sky ribbons;
///  2. **4-Phase Click-to-Ground Cinematic Dive (`06-22-59` -> `06-23-20`)**:
///     * `0.00..0.16`: closes eyes peacefully with a warm smile (`06-22-59`);
///     * `0.16..0.34`: spins 180° in mid-air away from camera (`06-23-08`);
///     * `0.34..0.74`: dives diagonally as a blazing golden comet waterfall
///       while the camera swoops down behind him (`06-23-12`);
///     * `0.74..1.00`: glides low with arms spread wide over the chiseled stone
///       causeway shooting golden sparks (`06-23-20`) -> cushioned touchdown;
///  3. **Close Over-the-Shoulder Sprint (`06-22-12` & `06-22-29`)**: runs
///     forward casting BOTH a diagonal directional stone shadow to the left AND
///     a blazing golden foot-reflection streak + sparks behind his feet!
class SoulPlayer extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  SoulPlayer() : super(priority: 2000);

  static const int _maxTrailPoints = 24;

  double _laneX = GameConfig.initialLane.toDouble();
  double _hopStartLane = GameConfig.initialLane.toDouble();
  int _hopTargetLane = GameConfig.initialLane;
  double _hopProgress = 1.0;
  double _elapsed = 0;
  double _runFrameCursor = 0;
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
    _landingTimer = 0.15;
  }

  /// Natural organic blinking while Soul hovers close-up on the Main Screen!
  bool get _isNaturalBlinkActive {
    final cycleIndex = (_elapsed / 3.4).floor();
    final t = _elapsed % 3.4;
    if (t >= 2.85 && t <= 3.01) {
      return true;
    }
    if (cycleIndex.isOdd && t >= 3.12 && t <= 3.25) {
      return true;
    }
    return false;
  }

  Offset _closeUpHoverScreenCenter() {
    final gw = game.size.x;
    final gh = game.size.y;
    final dx = math.sin(_elapsed * 1.35) * gw * 0.020;
    final dy = math.sin(_elapsed * 2.10) * gh * 0.016;
    return Offset(gw * 0.34 + dx, gh * 0.43 + dy);
  }

  /// Computes Soul's exact screen-space center during `isIntroFlying` so
  /// `u = 0` matches `_closeUpHoverScreenCenter()` and `u = 1` lands smoothly
  /// on `(position.x, chaseBodyY)`!
  Offset _introDiveScreenCenter(double chaseScreenX, double chaseScreenY) {
    final u = game.introFlightProgress.clamp(0.0, 1.0).toDouble();
    final start = _closeUpHoverScreenCenter();
    if (u <= 0.22) {
      final a = (u / 0.22).clamp(0.0, 1.0).toDouble();
      final lift = math.sin(a * math.pi * 0.5);
      return Offset(
        start.dx - game.size.x * 0.018 * lift,
        start.dy - game.size.y * 0.024 * lift,
      );
    }

    final p0 = Offset(
      start.dx - game.size.x * 0.018,
      start.dy - game.size.y * 0.024,
    );
    final t = ((u - 0.22) / 0.78).clamp(0.0, 1.0).toDouble();
    final s = t * t * (3.0 - 2.0 * t);
    // Graceful arcing swoop down from upper-left sky into the center lane!
    final arcX = math.sin(t * math.pi) * game.size.x * 0.06;
    final arcY = -math.sin(t * math.pi) * game.size.y * 0.04;
    return Offset(
      p0.dx + (chaseScreenX - p0.dx) * s + arcX,
      p0.dy + (chaseScreenY - p0.dy) * s + arcY,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (game.isGroundRunning &&
        !game.verticalMotion.isJumping &&
        !game.verticalMotion.isSliding &&
        !game.powerUps.isSolarDashing) {
      final speedRatio = (game.currentSpeed / GameConfig.startSpeed)
          .clamp(1.0, 1.42)
          .toDouble();
      _runFrameCursor = (_runFrameCursor +
              dt * GameConfig.runCycleFps * speedRatio) %
          GameConfig.runFrameCount;
    }

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
      _lean = math.sin(_elapsed * 1.35) * 0.22;
    } else if (game.isIntroFlying) {
      final u = game.introFlightProgress.clamp(0.0, 1.0).toDouble();
      _lean = (math.sin(u * math.pi * 1.4) * (1.0 - u) * 0.95)
          .clamp(-1.0, 1.0)
          .toDouble();
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

    // Record screen-space curved golden comet ribbon during intro dive!
    if (game.isIntroFlying) {
      _trailFade = 1.0;
      _trailSampleTimer += dt;
      if (_trailSampleTimer >= 0.016 || _flightTrail.isEmpty) {
        _trailSampleTimer = 0;
        final liftPx = game.effectivePlayerElevation *
            game.size.y *
            GameConfig.jumpHeightRatio;
        final chaseY = position.y - liftPx - size.y * 0.34;
        final pt = _introDiveScreenCenter(position.x, chaseY);
        _flightTrail.add(pt);
        if (_flightTrail.length > _maxTrailPoints) {
          _flightTrail.removeAt(0);
        }
      }
    } else if (_trailFade > 0) {
      _trailFade = math.max(0.0, _trailFade - dt * 3.4);
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
    _runFrameCursor = 0;
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

    // 1. Living Close-Up Front-Facing Main Screen (`06-22-47.png`)!
    if (game.isTitleHovering) {
      _renderCloseUpTitleHero(canvas);
      return;
    }

    // 2. 4-Phase Cinematic Spin & Golden Comet Dive (`06-22-59` -> `06-23-20`)!
    if (game.isIntroFlying) {
      _renderIntroDiveSequence(canvas);
      return;
    }

    // 3. Close Over-the-Shoulder Ground Sprint / Jump / Slide (`06-22-12`)!
    final frames = game.runFrames;
    final jumping =
        game.verticalMotion.isJumping || game.powerUps.isSolarDashing;
    final sliding =
        game.verticalMotion.isSliding && !game.powerUps.isSolarDashing;

    if (jumping && game.soulJumpSprite != null) {
      _renderChaseFrame(canvas, game.soulJumpSprite!, isDedicatedPose: true);
      return;
    }
    if (sliding && game.soulSlideSprite != null) {
      _renderChaseFrame(canvas, game.soulSlideSprite!, isDedicatedPose: true);
      return;
    }
    if (frames.isNotEmpty) {
      final int index;
      if (jumping || game.powerUps.hasShield) {
        index = (game.powerUps.hasShield ? 5 : 0) % frames.length;
      } else if (sliding) {
        index = 4 % frames.length;
      } else {
        index = _runFrameCursor.floor() % frames.length;
      }
      _renderChaseFrame(canvas, frames[index], isDedicatedPose: false);
      return;
    }

    final sprite = game.soulSprite;
    if (sprite == null) {
      _renderPlaceholder(canvas);
      return;
    }
    _renderFallbackSprite(canvas, sprite);
  }

  // ---------------------------------------------------------------
  // Stage 1: Close-Up Front-Facing Living Main Screen (`06-22-47.png`)
  // ---------------------------------------------------------------

  void _renderCloseUpTitleHero(Canvas canvas) {
    final originX = position.x - size.x / 2;
    final originY = position.y - size.y / 2;
    final screenCenter = _closeUpHoverScreenCenter();
    final cx = screenCenter.dx - originX;
    final cy = screenCenter.dy - originY;
    final heroD = math.min(game.size.x * 0.64, game.size.y * 0.42);

    // 1. Curved undulating golden stardust ribbons streaming from bottom-left!
    _renderCloseUpSkyRibbons(
      canvas,
      originX: originX,
      originY: originY,
      heroScreenX: screenCenter.dx,
      heroScreenY: screenCenter.dy,
      heroD: heroD,
      alpha: 1.0,
    );

    // 2. Warm breathing golden solar corona behind close-up Soul!
    final pulse = 0.92 + 0.08 * math.sin(_elapsed * 3.1);
    final auraR = heroD * 0.62 * pulse;
    canvas.drawCircle(
      Offset(cx, cy),
      auraR,
      Paint()
        ..shader = Gradient.radial(
          Offset(cx, cy),
          auraR,
          const [
            Color(0x66FFF2BE),
            Color(0x2EFFAE42),
            Color(0x00FF9028),
          ],
          const [0.0, 0.54, 1.0],
        ),
    );

    // 3. Close-up Pixar-3D Soul (`hover_open.png` <-> `hover_blink.png`)!
    final blinking = _isNaturalBlinkActive;
    final sprite = blinking
        ? (game.soulHoverBlinkSprite ?? game.soulHoverOpenSprite)
        : (game.soulHoverOpenSprite ?? game.soulHoverBlinkSprite);

    if (sprite != null) {
      final breath = math.sin(_elapsed * 2.6) * 0.022;
      final blinkDip = blinking ? 0.018 : 0.0;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(_lean * 0.14);
      canvas.scale(1.0 + breath + blinkDip, 1.0 - breath * 0.6 - blinkDip);
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
            0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: heroD, height: heroD),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      _renderPlaceholderAt(canvas, Offset(cx, cy), heroD * 0.34);
    }
  }

  /// Paints the flowing curved golden-white light streams & sparkles behind
  /// close-up Soul (`06-22-47.png` & `06-22-59.png`)!
  void _renderCloseUpSkyRibbons(
    Canvas canvas, {
    required double originX,
    required double originY,
    required double heroScreenX,
    required double heroScreenY,
    required double heroD,
    required double alpha,
  }) {
    final gw = game.size.x;
    final gh = game.size.y;
    final bodyTail = Offset(
      heroScreenX - heroD * 0.16 - originX,
      heroScreenY + heroD * 0.14 - originY,
    );

    for (var r = 0; r < 4; r++) {
      final wave = math.sin(_elapsed * 2.2 + r * 1.4) * heroD * 0.06;
      final startPt = Offset(
        -gw * 0.06 - originX,
        heroScreenY + gh * (0.14 + r * 0.065) - originY,
      );
      final ctrl1 = Offset(
        heroScreenX * 0.32 - originX,
        heroScreenY + heroD * (0.42 - r * 0.06) + wave - originY,
      );
      final ctrl2 = Offset(
        heroScreenX - heroD * 0.34 - originX,
        heroScreenY + heroD * (0.28 - r * 0.05) - wave - originY,
      );
      final endPt = Offset(
        bodyTail.dx + (r - 1.5) * heroD * 0.04,
        bodyTail.dy + (r - 1.5) * heroD * 0.05,
      );

      final path = Path()
        ..moveTo(startPt.dx, startPt.dy)
        ..cubicTo(
          ctrl1.dx,
          ctrl1.dy,
          ctrl2.dx,
          ctrl2.dy,
          endPt.dx,
          endPt.dy,
        );

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFB23E)
              .withValues(alpha: (0.34 - r * 0.05) * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = heroD * (0.065 - r * 0.010)
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFF6CC)
              .withValues(alpha: (0.68 - r * 0.10) * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = heroD * (0.018 - r * 0.002)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Drifting golden stardust motes rising along the ribbons!
    for (var i = 0; i < 16; i++) {
      final prog = ((_elapsed * 0.42 + i * 0.0625) % 1.0);
      final spread = math.sin(i * 2.7 + _elapsed * 1.8) * heroD * 0.16;
      final sx = (-gw * 0.02 + (heroScreenX - heroD * 0.05 + gw * 0.02) * prog) -
          originX;
      final sy = (heroScreenY +
              gh * 0.24 * (1.0 - prog) * (1.0 - prog) +
              spread * (1.0 - prog * 0.5)) -
          originY;
      final mr = (1.6 + (i % 3) * 1.1) * math.sin(prog * math.pi);
      if (mr <= 0.2) {
        continue;
      }
      canvas.drawCircle(
        Offset(sx, sy),
        mr * 2.2,
        Paint()..color = const Color(0xFFFFBC44).withValues(alpha: 0.40 * alpha),
      );
      canvas.drawCircle(
        Offset(sx, sy),
        mr * 0.85,
        Paint()..color = const Color(0xFFFFFDE8).withValues(alpha: 0.90 * alpha),
      );
    }
  }

  // ---------------------------------------------------------------
  // Stage 2: 4-Phase Spin & Golden Comet Dive (`06-22-59` -> `06-23-20`)
  // ---------------------------------------------------------------

  void _renderIntroDiveSequence(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final originX = position.x - w / 2;
    final originY = position.y - h / 2;
    final u = game.introFlightProgress.clamp(0.0, 1.0).toDouble();

    final closeUpD = math.min(game.size.x * 0.64, game.size.y * 0.42);
    final chaseBaseD = w * 1.24 * GameConfig.runCycleFitBoost;

    final totalLiftPx =
        game.effectivePlayerElevation * game.size.y * GameConfig.jumpHeightRatio;
    final chaseFootY = position.y - totalLiftPx;
    final chaseBodyScreenY = chaseFootY - chaseBaseD * 0.39;

    final screenPt = _introDiveScreenCenter(position.x, chaseBodyScreenY);
    final cx = screenPt.dx - originX;
    final cy = screenPt.dy - originY;

    final sizeBlend =
        ((u - 0.18) / 0.68).clamp(0.0, 1.0).toDouble();
    final smoothSize = sizeBlend * sizeBlend * (3.0 - 2.0 * sizeBlend);
    final drawD = closeUpD * (1.0 - smoothSize) + chaseBaseD * smoothSize;

    // A) Fade out close-up sky ribbons during early spin (`0.00..0.35`)
    if (u < 0.36) {
      final ribAlpha = (1.0 - u / 0.36).clamp(0.0, 1.0).toDouble();
      _renderCloseUpSkyRibbons(
        canvas,
        originX: originX,
        originY: originY,
        heroScreenX: screenPt.dx,
        heroScreenY: screenPt.dy,
        heroD: drawD,
        alpha: ribAlpha,
      );
    }

    // B) Screen-space curved golden comet ribbon (`06-23-12` & `06-23-20`)!
    if (_trailFade > 0 && _flightTrail.length >= 2) {
      _renderCurvedFlightRibbon(canvas, w, h);
    }

    // C) Blazing Golden Comet Waterfall Plume during high-speed dive (`0.26..0.76`, `06-23-12`)!
    if (u >= 0.24 && u <= 0.80) {
      final plumeBell =
          math.sin(((u - 0.24) / 0.56).clamp(0.0, 1.0) * math.pi);
      final plumePath = Path()
        ..moveTo(cx - drawD * 0.30, cy - drawD * 0.18)
        ..quadraticBezierTo(
          cx + drawD * 0.18,
          cy + drawD * 0.38,
          cx + drawD * 0.42,
          cy + drawD * 1.15,
        )
        ..lineTo(cx - drawD * 0.12, cy + drawD * 1.18)
        ..quadraticBezierTo(
          cx - drawD * 0.24,
          cy + drawD * 0.42,
          cx - drawD * 0.30,
          cy - drawD * 0.18,
        )
        ..close();
      canvas.drawPath(
        plumePath,
        Paint()
          ..shader = Gradient.linear(
            Offset(cx - drawD * 0.15, cy - drawD * 0.10),
            Offset(cx + drawD * 0.25, cy + drawD * 1.15),
            [
              const Color(0xFFFFF6C4).withValues(alpha: 0.72 * plumeBell),
              const Color(0xFFFFA834).withValues(alpha: 0.54 * plumeBell),
              const Color(0x00FF7A18),
            ],
            const [0.0, 0.55, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9.0),
      );
    }

    // D) Low-glide diagonal golden spark jet & bridge shadow (`u >= 0.58`, `06-23-20`)!
    if (u >= 0.58) {
      final glideVis = ((u - 0.58) / 0.42).clamp(0.0, 1.0).toDouble();
      final floorY = h / 2;
      _renderStoneShadowAndGoldenStreak(
        canvas,
        centerX: cx,
        supportFloorY: floorY,
        dw: drawD,
        dh: drawD,
        shadowScale: 0.45 + 0.55 * glideVis,
        isDiagonalGlideJet: true,
      );
    }

    // E) Render Soul's exact pose across Phases 1..4!
    Image? poseImg;
    var turnScaleX = 1.0;
    if (u < 0.25) {
      // Phase 1 (`0.00..0.16`, `06-22-59`) + first half of 180° spin (`0.16..0.25`)!
      poseImg = game.soulHoverBlinkSprite ?? game.soulHoverOpenSprite;
      if (u >= 0.16) {
        final spinHalf = ((u - 0.16) / 0.18).clamp(0.0, 1.0).toDouble();
        turnScaleX = math.cos(spinHalf * math.pi).abs().clamp(0.24, 1.0).toDouble();
      }
    } else if (u < 0.90) {
      // Second half of 180° spin (`06-23-08`) -> Dive -> Arms-spread glide (`06-23-20`)!
      poseImg = game.soulJumpSprite ??
          (game.runFrames.isNotEmpty ? game.runFrames.first : game.soulSprite);
      if (u < 0.34) {
        final spinHalf = ((u - 0.16) / 0.18).clamp(0.0, 1.0).toDouble();
        turnScaleX = math.cos(spinHalf * math.pi).abs().clamp(0.24, 1.0).toDouble();
      }
    } else {
      // Final touchdown stride reach (`0.90..1.00`)!
      poseImg = game.runFrames.isNotEmpty
          ? game.runFrames[3 % game.runFrames.length]
          : (game.soulJumpSprite ?? game.soulSprite);
    }

    // 180° Spin Golden Sun-Ray Whip Burst (`0.16..0.36`, `06-23-08.png`)!
    if (u >= 0.15 && u <= 0.38) {
      final whip = math.sin(((u - 0.15) / 0.23).clamp(0.0, 1.0) * math.pi);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: drawD * 1.18,
          height: drawD * 0.78,
        ),
        Paint()
          ..color = const Color(0xFFFFD66E).withValues(alpha: 0.56 * whip)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
      );
    }

    if (poseImg != null) {
      final fit = math.min(drawD / poseImg.width, drawD / poseImg.height);
      final dw = poseImg.width * fit;
      final dh = poseImg.height * fit;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(_lean * GameConfig.playerLeanAngle);
      canvas.scale(turnScaleX, 1.0);
      canvas.drawImageRect(
        poseImg,
        Rect.fromLTWH(
            0, 0, poseImg.width.toDouble(), poseImg.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: dw, height: dh),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      _renderPlaceholderAt(canvas, Offset(cx, cy), drawD * 0.34);
    }
  }

  // ---------------------------------------------------------------
  // Stage 3: Close Over-the-Shoulder Chase Sprint (`06-22-12` & `06-22-29`)
  // ---------------------------------------------------------------

  void _renderChaseFrame(
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
        ? math.sin((_landingTimer / 0.15).clamp(0.0, 1.0) * math.pi) * dh * 0.038
        : 0.0;

    final footAnchorShift = dh * 0.39;
    final supportFloorY = h / 2 - supportLiftPx;
    final centerX = w / 2;
    final strideTheta =
        (_runFrameCursor / GameConfig.runFrameCount) * 2.0 * math.pi;
    final strideContactPulse = (!isDedicatedPose && airAboveSupport <= 0.02)
        ? 0.94 + 0.08 * math.cos(2.0 * (strideTheta - 0.24 * math.pi))
        : 1.0;
    final shadowScale = ((1.0 - airAboveSupport * 0.36) * strideContactPulse)
        .clamp(0.34, 1.06)
        .toDouble();

    if (_trailFade > 0 && _flightTrail.length >= 2) {
      _renderCurvedFlightRibbon(canvas, w, h);
    }

    // 1. Diagonal Directional Stone Shadow + Blazing Golden Sunbeam Reflection
    //    + Trailing Footstep Sparks (`06-22-12.png` & `06-22-29.png`)!
    _renderStoneShadowAndGoldenStreak(
      canvas,
      centerX: centerX,
      supportFloorY: supportFloorY,
      dw: dw,
      dh: dh,
      shadowScale: shadowScale,
      isDiagonalGlideJet: false,
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

    // 2. Radiant Celestial Golden Sun-Disk (`hasShield`)!
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

    // 3. Pixar-3D Soul Character Render!
    canvas.save();
    canvas.translate(centerX, bodyCenterY);
    canvas.rotate(_lean * GameConfig.playerLeanAngle);

    final landingSquash = _landingTimer > 0
        ? math.sin((_landingTimer / 0.15).clamp(0.0, 1.0) * math.pi) * 0.058
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

  /// Renders BOTH the crisp diagonal cast shadow (`06-22-12.png`) AND the
  /// fiery golden sunbeam reflection + sparks trailing behind Soul's feet!
  void _renderStoneShadowAndGoldenStreak(
    Canvas canvas, {
    required double centerX,
    required double supportFloorY,
    required double dw,
    required double dh,
    required double shadowScale,
    required bool isDiagonalGlideJet,
  }) {
    final trailLen =
        math.max(dh * 0.75, (game.size.y - position.y) + supportFloorY);
    final shimmer = 0.90 + 0.10 * math.sin(_elapsed * 10.5);
    final trailAlpha = (shadowScale * shimmer).clamp(0.28, 1.0).toDouble();

    // A) Diagonal Directional Cast Shadow stretching down-left (`06-22-12.png`)!
    final diagShadow = Path()
      ..moveTo(centerX - dw * 0.09 * shadowScale, supportFloorY + 2)
      ..lineTo(centerX + dw * 0.08 * shadowScale, supportFloorY + 4)
      ..lineTo(centerX - dw * 0.46 * shadowScale, supportFloorY + dh * 0.42)
      ..lineTo(centerX - dw * 0.68 * shadowScale, supportFloorY + dh * 0.34)
      ..close();
    canvas.drawPath(
      diagShadow,
      Paint()
        ..shader = Gradient.linear(
          Offset(centerX, supportFloorY),
          Offset(centerX - dw * 0.58, supportFloorY + dh * 0.38),
          [
            const Color(0x8C180E30).withValues(alpha: 0.56 * shadowScale),
            const Color(0x44180E30).withValues(alpha: 0.28 * shadowScale),
            const Color(0x00180E30),
          ],
          const [0.0, 0.60, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // B) Warm radial golden pool right beneath Soul's feet
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, supportFloorY + 5),
        width: dw * 0.88 * shadowScale,
        height: dh * 0.20 * shadowScale,
      ),
      Paint()
        ..color = const Color(0xFFFFB844).withValues(alpha: 0.38 * trailAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
    );

    // C) Long Blazing Golden Reflection Streak (`06-22-12`, `06-23-20`, `06-22-29`)!
    final tailSkewX = isDiagonalGlideJet ? -dw * 0.34 : 0.0;
    final streakOuter = Path()
      ..moveTo(centerX - dw * 0.15 * shadowScale, supportFloorY + 2)
      ..lineTo(centerX + dw * 0.15 * shadowScale, supportFloorY + 2)
      ..lineTo(centerX + tailSkewX + dw * 0.08, supportFloorY + trailLen)
      ..lineTo(centerX + tailSkewX - dw * 0.08, supportFloorY + trailLen)
      ..close();
    canvas.drawPath(
      streakOuter,
      Paint()
        ..shader = Gradient.linear(
          Offset(centerX, supportFloorY),
          Offset(centerX + tailSkewX, supportFloorY + trailLen),
          [
            const Color(0xFFFFC04C).withValues(alpha: 0.62 * trailAlpha),
            const Color(0xFFFF922C).withValues(alpha: 0.28 * trailAlpha),
            const Color(0x00FF801E),
          ],
          const [0.0, 0.58, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
    );

    final streakCore = Path()
      ..moveTo(centerX - dw * 0.055 * shadowScale, supportFloorY + 1)
      ..lineTo(centerX + dw * 0.055 * shadowScale, supportFloorY + 1)
      ..lineTo(
          centerX + tailSkewX * 0.88 + dw * 0.022, supportFloorY + trailLen * 0.90)
      ..lineTo(
          centerX + tailSkewX * 0.88 - dw * 0.022, supportFloorY + trailLen * 0.90)
      ..close();
    canvas.drawPath(
      streakCore,
      Paint()
        ..shader = Gradient.linear(
          Offset(centerX, supportFloorY),
          Offset(centerX + tailSkewX * 0.88, supportFloorY + trailLen * 0.90),
          [
            const Color(0xFFFFF8D0).withValues(alpha: 0.86 * trailAlpha),
            const Color(0xFFFFCA58).withValues(alpha: 0.40 * trailAlpha),
            const Color(0x00FFB438),
          ],
          const [0.0, 0.52, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8),
    );

    // D) Trailing golden sparks skimming across the flagstones (`06-23-20`)!
    if (shadowScale > 0.55) {
      for (var i = 0; i < 7; i++) {
        final prog = ((_elapsed * 2.6 + i * 0.142) % 1.0);
        final jitter = math.sin(i * 3.7 + _elapsed * 6.0) * dw * 0.11 * prog;
        final sx = centerX + tailSkewX * prog + jitter;
        final sy = supportFloorY + 4 + trailLen * 0.82 * prog;
        final sr = (1.6 + (i % 2) * 1.1) * (1.0 - prog * 0.65);
        canvas.drawCircle(
          Offset(sx, sy),
          sr,
          Paint()
            ..color = const Color(0xFFFFF4B8)
                .withValues(alpha: 0.82 * (1.0 - prog) * trailAlpha),
        );
      }
    }
  }

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
      final strokeOuter = (w * 0.18 * frac).clamp(2.0, 30.0).toDouble();
      final strokeCore = (w * 0.06 * frac).clamp(1.0, 10.0).toDouble();

      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0xFFFFB23A).withValues(alpha: 0.46 * alpha)
          ..strokeWidth = strokeOuter
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
      );
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0xFFFFF8D4).withValues(alpha: 0.86 * alpha)
          ..strokeWidth = strokeCore
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _renderFallbackSprite(Canvas canvas, Image sprite) {
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
    _renderPlaceholderAt(
      canvas,
      Offset(w / 2, h / 2 - jumpLiftPx),
      w * 0.36,
    );
  }

  void _renderPlaceholderAt(Canvas canvas, Offset center, double radius) {
    final rayPaint = Paint()..color = const Color(0xFFFF9F68);
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5 + _elapsed * 0.8;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final perp = Offset(-dir.dy, dir.dx) * (radius * 0.14);
      final inner = center + dir * radius * 0.88;
      final tip = center + dir * (radius * 1.32);
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
