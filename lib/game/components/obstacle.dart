import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/obstacle_spawner.dart';

/// S15 Subway-Surfers-Grade 3D Obstacles & Walkable Extruded Trains:
///  * [ObstacleKind.lowSpikes] — Red & White 3D track hurdle (jump over);
///  * [ObstacleKind.highArch] — Brass & Teal 3D roll gate (slide under);
///  * [ObstacleKind.tallMonolith] — True 8-vertex `1/Z` 3D extruded Subway
///    Train (parked Royal-Blue or oncoming Crimson Express; walkable roof!);
///  * [ObstacleKind.trainWithRamp] — True 3D extruded Subway Train with a
///    6-vertex sloped wooden Boarding Ramp in front -> climb onto the roof!
class Obstacle extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  Obstacle({
    required this.lane,
    this.kind = ObstacleKind.lowSpikes,
    this.isMoving = false,
    double initialDepth = 1.0,
  })  : _depth = initialDepth,
        super(priority: 1000);

  final int lane;
  final ObstacleKind kind;
  final bool isMoving;

  double _depth;
  bool _resolvedFrontImpact = false;
  bool _resolvedSideBump = false;

  bool get isTrain =>
      kind == ObstacleKind.tallMonolith || kind == ObstacleKind.trainWithRamp;

  double get frontDepth => _depth;
  double get backDepth => _depth + GameConfig.trainLengthDepth;

  /// Returns the walkable surface elevation (`0.0 .. trainRoofElevation`)
  /// beneath Soul when Soul is aligned with this 3D ramp or train roof!
  double supportElevationForPlayer(
    double playerLane,
    double currentWorldElevation,
  ) {
    if (!isTrain || (playerLane - lane).abs() >= 0.43) {
      return 0.0;
    }

    if (kind == ObstacleKind.trainWithRamp) {
      final rampStart = _depth - GameConfig.rampLengthDepth;
      if (rampStart <= 0.025 && _depth >= -0.015) {
        final u = ((0.02 - rampStart) / (GameConfig.rampLengthDepth + 0.02))
            .clamp(0.0, 1.0)
            .toDouble();
        return u * GameConfig.trainRoofElevation;
      }
    }

    if (_depth <= 0.035 && backDepth >= -0.025) {
      if (kind == ObstacleKind.trainWithRamp ||
          currentWorldElevation >= GameConfig.trainRoofElevation * 0.76) {
        return GameConfig.trainRoofElevation;
      }
    }
    return 0.0;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (isTrain) {
      anchor = Anchor.topLeft;
      position = Vector2.zero();
      size = game.size.clone();
    } else {
      anchor = Anchor.bottomCenter;
      final base = game.size.x * GameConfig.entityWidthRatio;
      if (kind == ObstacleKind.lowSpikes) {
        size = Vector2(base * 1.12, base * 0.82);
      } else {
        size = Vector2(base * 1.26, base * 1.42);
      }
    }
    _applyProjection();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isTrain) {
      this.size = size.clone();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final approachSpeed = game.currentSpeed +
        (isMoving && game.isRunStarted ? GameConfig.movingTrainExtraSpeed : 0);
    _depth -= (approachSpeed / GameConfig.trackLength) * dt;

    if (!game.powerUps.isSolarDashing) {
      _evaluateCollisions();
    }

    final clearPastCamera = isTrain ? -0.56 : -0.22;
    if (_depth <= clearPastCamera) {
      removeFromParent();
      return;
    }
    _applyProjection();
  }

  void _evaluateCollisions() {
    final laneDiff = (game.player.currentLane - lane).abs();
    final elev = game.effectivePlayerElevation;

    if (isTrain) {
      // Running above roof height clears the entire 3D train cleanly!
      if (elev >= GameConfig.trainRoofElevation * 0.76) {
        return;
      }

      // 1. Frontal impact check at `zFront` (ONLY for unramped `tallMonolith`)
      if (kind == ObstacleKind.tallMonolith &&
          !_resolvedFrontImpact &&
          _depth <= 0.034 &&
          _depth >= -0.030) {
        final impactPt = Vector2(
          game.laneXOnPlayerPlane(lane.toDouble()),
          game.playerPlaneY - game.size.y * 0.08,
        );
        if (laneDiff < GameConfig.collisionLaneThreshold) {
          _resolvedFrontImpact = true;
          if (game.onObstacleImpact(impactPt)) {
            removeFromParent();
            return;
          }
        } else if (laneDiff < GameConfig.stumbleLaneThreshold) {
          _resolvedFrontImpact = true;
          game.onObstacleSideStumble(lane, impactPt);
        }
      }

      // 2. Side-wall bump check if Soul swipes sideways against a passing train
      if (!_resolvedSideBump &&
          _depth < -0.030 &&
          backDepth > 0.025 &&
          laneDiff < GameConfig.stumbleLaneThreshold) {
        _resolvedSideBump = true;
        final bumpPt = Vector2(
          game.laneXOnPlayerPlane(lane.toDouble()),
          game.playerPlaneY - game.size.y * 0.07,
        );
        game.onObstacleSideStumble(lane, bumpPt);
      }
      return;
    }

    // Standard 3D Hurdle / Roll Gate check
    if (!_resolvedFrontImpact && _depth <= 0.032 && _depth >= -0.028) {
      if (!_isClearedVertically(elev)) {
        final contactPoint =
            Vector2(position.x, position.y - size.y * scale.y * 0.45);
        if (laneDiff < GameConfig.collisionLaneThreshold) {
          _resolvedFrontImpact = true;
          if (game.onObstacleImpact(contactPoint)) {
            removeFromParent();
            return;
          }
        } else if (laneDiff < GameConfig.stumbleLaneThreshold) {
          _resolvedFrontImpact = true;
          game.onObstacleSideStumble(lane, contactPoint);
        } else if (laneDiff < 0.50) {
          _resolvedFrontImpact = true;
          game.onNearMissSpark(contactPoint);
        }
      }
    }
  }

  bool _isClearedVertically(double elev) {
    switch (kind) {
      case ObstacleKind.lowSpikes:
        return elev >= GameConfig.jumpClearThreshold;
      case ObstacleKind.highArch:
        return game.verticalMotion.isDuckingHigh ||
            elev >= GameConfig.trainRoofElevation * 0.95;
      case ObstacleKind.tallMonolith:
      case ObstacleKind.trainWithRamp:
        return elev >= GameConfig.trainRoofElevation * 0.76;
    }
  }

  void _applyProjection() {
    if (isTrain) {
      position = Vector2.zero();
      scale = Vector2.all(1.0);
      final playerAboveTrain =
          game.effectivePlayerElevation >= GameConfig.trainRoofElevation * 0.76;
      if (playerAboveTrain && _depth <= 0.08 && backDepth >= -0.08) {
        // Keep train underneath Soul (`priority = 2000`) while surfing on roof!
        priority = 1910;
      } else {
        priority = ((2.0 - _depth) * 1000).round();
      }
      return;
    }

    if (_depth > 1.03) {
      scale = Vector2.zero();
      return;
    }
    final sc = game.scaleForDepth(_depth);
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth) + size.y * sc * 0.03,
    );
    scale = Vector2.all(sc);

    final basePriority = ((2.0 - _depth) * 1000).round();
    priority =
        kind == ObstacleKind.highArch ? basePriority + 90 : basePriority;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (isTrain) {
      _renderExtruded3DTrainAndRamp(canvas);
      return;
    }
    if (_depth > 1.03) {
      return;
    }
    final w = size.x;
    final h = size.y;
    final horizonAlpha = ((1.03 - _depth) / 0.11).clamp(0.0, 1.0).toDouble();

    final sprite = kind == ObstacleKind.lowSpikes
        ? game.obstacleSprite
        : game.obstacleArchSprite;
    if (sprite != null) {
      final double dw;
      final double dh;
      if (kind == ObstacleKind.highArch) {
        dw = w;
        dh = h;
      } else {
        final fit = math.min(w / sprite.width, h / sprite.height);
        dw = sprite.width * fit;
        dh = sprite.height * fit;
      }

      if (kind == ObstacleKind.lowSpikes) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w / 2, h * 0.96),
            width: dw * 0.84,
            height: h * 0.13,
          ),
          Paint()
            ..color = const Color(0x663A342E).withValues(alpha: 0.42 * horizonAlpha),
        );
      }

      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
            0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH((w - dw) / 2, h - dh, dw, dh),
        Paint()
          ..color = Color.fromARGB((horizonAlpha * 255).round(), 255, 255, 255)
          ..filterQuality = FilterQuality.medium,
      );
      return;
    }

    _renderBarrierFallback(canvas, w, h);
  }

  // ---------------------------------------------------------------------------
  // True 8-Vertex `1/Z` 3D Extruded Subway Train & 6-Vertex Boarding Ramp!
  // ---------------------------------------------------------------------------
  ({double xl, double xr, double yt, double yb, double sc}) _boxSlice(
      double d) {
    final sc = game.scaleForDepth(d);
    final cx = game.laneXForDepth(lane.toDouble(), d);
    final yb = game.yForDepth(d);
    final hw = game.halfWidthForDepth(d) * GameConfig.laneSpreadRatio * 0.44;
    final trainHRef =
        game.size.y * GameConfig.jumpHeightRatio * GameConfig.trainRoofElevation;
    final yt = yb - trainHRef * sc;
    return (xl: cx - hw, xr: cx + hw, yt: yt, yb: yb, sc: sc);
  }

  void _renderExtruded3DTrainAndRamp(Canvas canvas) {
    if (_depth > 1.03) {
      return;
    }
    final zbClamped = math.min(1.02, backDepth);
    final zfClamped = math.max(-0.24, _depth);
    if (zfClamped < zbClamped) {
      _draw3DTrainBody(canvas, zfClamped, zbClamped);
    }

    if (kind == ObstacleKind.trainWithRamp) {
      final rFront = _depth - GameConfig.rampLengthDepth;
      final rBack = _depth;
      if (rFront < 1.02 && rBack > -0.22) {
        _draw3DBoardingRamp(
          canvas,
          math.max(-0.22, rFront),
          math.min(1.02, rBack),
        );
      }
    }
  }

  void _draw3DTrainBody(Canvas canvas, double zf, double zb) {
    final f = _boxSlice(zf);
    final b = _boxSlice(zb);
    final alpha = ((1.03 - zf) / 0.10).clamp(0.0, 1.0).toDouble();

    final Color cFront;
    final Color cSide;
    final Color cRoof;
    const cStripe = Color(0xFFFAD056);
    if (isMoving) {
      cFront = const Color(0xFFD63A36);
      cSide = const Color(0xFFB22C2A);
      cRoof = const Color(0xFFECE4DC);
    } else {
      cFront = const Color(0xFF2C70BA);
      cSide = const Color(0xFF225898);
      cRoof = const Color(0xFFE6ECF4);
    }

    final outlinePaint = Paint()
      ..color = const Color(0xFF1A2434).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * f.sc).clamp(1.0, 3.0).toDouble();

    // 1. Ground contact shadow under full 3D train footprint
    final shadowPath = Path()
      ..moveTo(f.xl - 5 * f.sc, f.yb + 3)
      ..lineTo(f.xr + 5 * f.sc, f.yb + 3)
      ..lineTo(b.xr + 4 * b.sc, b.yb + 2)
      ..lineTo(b.xl - 4 * b.sc, b.yb + 2)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()..color = const Color(0x6636302C).withValues(alpha: 0.48 * alpha),
    );

    // 2. Visible 3D Perspective Side Wall + Windows + Gold Belt Stripe
    for (final isRight in const [true, false]) {
      final visible = isRight ? (f.xr < b.xr - 1.2) : (f.xl > b.xl + 1.2);
      if (!visible) {
        continue;
      }
      final xfS = isRight ? f.xr : f.xl;
      final xbS = isRight ? b.xr : b.xl;

      final sidePath = Path()
        ..moveTo(xfS, f.yb)
        ..lineTo(xbS, b.yb)
        ..lineTo(xbS, b.yt)
        ..lineTo(xfS, f.yt)
        ..close();
      canvas.drawPath(sidePath, Paint()..color = cSide.withValues(alpha: alpha));
      canvas.drawPath(sidePath, outlinePaint);

      final ymf1 = f.yt + (f.yb - f.yt) * 0.52;
      final ymf2 = f.yt + (f.yb - f.yt) * 0.64;
      final ymb1 = b.yt + (b.yb - b.yt) * 0.52;
      final ymb2 = b.yt + (b.yb - b.yt) * 0.64;
      final beltPath = Path()
        ..moveTo(xfS, ymf1)
        ..lineTo(xbS, ymb1)
        ..lineTo(xbS, ymb2)
        ..lineTo(xfS, ymf2)
        ..close();
      canvas.drawPath(
          beltPath, Paint()..color = cStripe.withValues(alpha: alpha));

      final winPaint = Paint()
        ..color = const Color(0xFF24384E).withValues(alpha: alpha);
      for (var wi = 0; wi < 3; wi++) {
        final u0 = 0.10 + wi * 0.29;
        final u1 = 0.31 + wi * 0.29;
        final wx0 = xfS + (xbS - xfS) * u0;
        final wx1 = xfS + (xbS - xfS) * u1;
        final h0 = (f.yb - f.yt) * (1 - u0) + (b.yb - b.yt) * u0;
        final h1 = (f.yb - f.yt) * (1 - u1) + (b.yb - b.yt) * u1;
        final yt0 = f.yt + (b.yt - f.yt) * u0;
        final yt1 = f.yt + (b.yt - f.yt) * u1;
        final wPath = Path()
          ..moveTo(wx0, yt0 + h0 * 0.16)
          ..lineTo(wx1, yt1 + h1 * 0.16)
          ..lineTo(wx1, yt1 + h1 * 0.45)
          ..lineTo(wx0, yt0 + h0 * 0.45)
          ..close();
        canvas.drawPath(wPath, winPaint);
      }
    }

    // 3. Walkable 3D Roof Deck + Rooftop AC Vents
    if (f.yt > b.yt) {
      final roofPath = Path()
        ..moveTo(f.xl, f.yt)
        ..lineTo(f.xr, f.yt)
        ..lineTo(b.xr, b.yt)
        ..lineTo(b.xl, b.yt)
        ..close();
      canvas.drawPath(roofPath, Paint()..color = cRoof.withValues(alpha: alpha));
      canvas.drawPath(roofPath, outlinePaint);

      final ventFill = Paint()
        ..color = const Color(0xFFC0CAD6).withValues(alpha: alpha);
      for (final spanU in const [(0.16, 0.42), (0.56, 0.82)]) {
        final u0 = spanU.$1;
        final u1 = spanU.$2;
        final w0 = (f.xr - f.xl) * (1 - u0) + (b.xr - b.xl) * u0;
        final w1 = (f.xr - f.xl) * (1 - u1) + (b.xr - b.xl) * u1;
        final axLf = f.xl + (b.xl - f.xl) * u0 + w0 * 0.22;
        final axRf = f.xr + (b.xr - f.xr) * u0 - w0 * 0.22;
        final axLb = f.xl + (b.xl - f.xl) * u1 + w1 * 0.22;
        final axRb = f.xr + (b.xr - f.xr) * u1 - w1 * 0.22;
        final ayF = f.yt + (b.yt - f.yt) * u0;
        final ayB = f.yt + (b.yt - f.yt) * u1;
        final vent = Path()
          ..moveTo(axLf, ayF)
          ..lineTo(axRf, ayF)
          ..lineTo(axRb, ayB)
          ..lineTo(axLb, ayB)
          ..close();
        canvas.drawPath(vent, ventFill);
      }
    }

    // 4. Crisp Cab Front Face (drawn when front is ahead of camera clip)
    if (_depth >= -0.23) {
      final fw = f.xr - f.xl;
      final fh = f.yb - f.yt;

      // Dark wheel bogie undercarriage
      canvas.drawRect(
        Rect.fromLTWH(
            f.xl + fw * 0.12, f.yb - fh * 0.08, fw * 0.76, fh * 0.09),
        Paint()..color = const Color(0xFF20242E).withValues(alpha: alpha),
      );

      final cabRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(f.xl, f.yt, fw, fh * 0.96),
        Radius.circular((fw * 0.10).clamp(3.0, 18.0).toDouble()),
      );
      canvas.drawRRect(
          cabRRect, Paint()..color = cFront.withValues(alpha: alpha));
      canvas.drawRRect(cabRRect, outlinePaint);

      // Gold belt stripe
      canvas.drawRect(
        Rect.fromLTWH(f.xl + 2, f.yt + fh * 0.52, math.max(0, fw - 4), fh * 0.12),
        Paint()..color = cStripe.withValues(alpha: alpha),
      );

      // Panoramic driver windshield + diagonal sky reflection
      final glassRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(f.xl + fw * 0.11, f.yt + fh * 0.14, fw * 0.78, fh * 0.32),
        Radius.circular((fw * 0.06).clamp(2.0, 10.0).toDouble()),
      );
      canvas.drawRRect(
        glassRRect,
        Paint()..color = const Color(0xFF22344A).withValues(alpha: alpha),
      );
      final glint = Path()
        ..moveTo(f.xl + fw * 0.17, f.yt + fh * 0.43)
        ..lineTo(f.xl + fw * 0.33, f.yt + fh * 0.43)
        ..lineTo(f.xl + fw * 0.47, f.yt + fh * 0.17)
        ..lineTo(f.xl + fw * 0.31, f.yt + fh * 0.17)
        ..close();
      canvas.drawPath(
        glint,
        Paint()..color = const Color(0x9984B2D6).withValues(alpha: 0.6 * alpha),
      );

      // Twin warm headlights & steel bumper
      final hlR = (fw * 0.085).clamp(2.5, 14.0).toDouble();
      final hlPaint = Paint()
        ..color = const Color(0xFFFFF6BC).withValues(alpha: alpha);
      for (final sHl in const [-1.0, 1.0]) {
        canvas.drawCircle(
          Offset((f.xl + f.xr) * 0.5 + sHl * fw * 0.27, f.yt + fh * 0.74),
          hlR,
          hlPaint,
        );
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              f.xl - fw * 0.03, f.yb - fh * 0.14, fw * 1.06, fh * 0.11),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF586274).withValues(alpha: alpha),
      );
    }
  }

  void _draw3DBoardingRamp(Canvas canvas, double zf, double zb) {
    final f = _boxSlice(zf);
    final b = _boxSlice(zb);
    final alpha = ((1.03 - zf) / 0.10).clamp(0.0, 1.0).toDouble();

    final sidePaint = Paint()
      ..color = const Color(0xFF805226).withValues(alpha: alpha);
    if (f.xr < b.xr - 1.0) {
      final wedge = Path()
        ..moveTo(f.xr, f.yb)
        ..lineTo(b.xr, b.yb)
        ..lineTo(b.xr, b.yt)
        ..close();
      canvas.drawPath(wedge, sidePaint);
    } else if (f.xl > b.xl + 1.0) {
      final wedge = Path()
        ..moveTo(f.xl, f.yb)
        ..lineTo(b.xl, b.yb)
        ..lineTo(b.xl, b.yt)
        ..close();
      canvas.drawPath(wedge, sidePaint);
    }

    final rampDeck = Path()
      ..moveTo(f.xl, f.yb)
      ..lineTo(f.xr, f.yb)
      ..lineTo(b.xr, b.yt)
      ..lineTo(b.xl, b.yt)
      ..close();
    canvas.drawPath(
      rampDeck,
      Paint()..color = const Color(0xFFE8A63A).withValues(alpha: alpha),
    );
    canvas.drawPath(
      rampDeck,
      Paint()
        ..color = const Color(0xFF3A2818).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.0 * f.sc).clamp(1.0, 3.0).toDouble(),
    );

    // Wooden grip slats
    final slatPaint = Paint()
      ..color = const Color(0xFF9C6220).withValues(alpha: alpha)
      ..strokeWidth = (2.2 * f.sc).clamp(1.0, 3.5).toDouble();
    for (final u in const [0.25, 0.50, 0.75]) {
      final ym = f.yb + (b.yt - f.yb) * u;
      final xml = f.xl + (b.xl - f.xl) * u + 4 * f.sc;
      final xmr = f.xr + (b.xr - f.xr) * u - 4 * f.sc;
      canvas.drawLine(Offset(xml, ym), Offset(xmr, ym), slatPaint);
    }

    // Upward cream chevron arrow
    final ymA = f.yb + (b.yt - f.yb) * 0.52;
    final xmlA = f.xl + (b.xl - f.xl) * 0.52;
    final xmrA = f.xr + (b.xr - f.xr) * 0.52;
    final xmcA = (xmlA + xmrA) * 0.5;
    final arrow = Path()
      ..moveTo(xmcA - (xmrA - xmlA) * 0.22, ymA + 7 * f.sc)
      ..lineTo(xmcA + (xmrA - xmlA) * 0.22, ymA + 7 * f.sc)
      ..lineTo(xmcA, ymA - 9 * f.sc)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()..color = const Color(0xFFFFF8DA).withValues(alpha: alpha),
    );
  }

  void _renderBarrierFallback(Canvas canvas, double w, double h) {
    final fill = Paint()..color = const Color(0xFFE2443E);
    if (kind == ObstacleKind.lowSpikes) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.08, h * 0.36, w * 0.84, h * 0.34),
          Radius.circular(w * 0.05),
        ),
        fill,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.04, h * 0.10, w * 0.92, h * 0.26),
        Paint()..color = const Color(0xFF20728A),
      );
    }
  }
}
