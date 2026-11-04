import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/obstacle_spawner.dart';

/// S16 Cinematic `SOUL: DUSK RUN` 3D Fantasy Obstacles & Walkable Ancient
/// Stone Sanctuary Platforms (matching the Official Concept Board 1-to-1):
///  * [ObstacleKind.lowSpikes] — Pre-rendered 3D Dark Obsidian & Glowing
///    Crystal Spike Cluster (jump over);
///  * [ObstacleKind.highArch] — Pre-rendered 3D Carved Ancient Stone Rune
///    Archway Gate (slide/tuck under);
///  * [ObstacleKind.tallMonolith] — True `1/Z` 3D Elevated Ancient Stone
///    Sanctuary Platform (stationary world-stone block OR oncoming gliding
///    Obsidian Sentinel Monolith; walkable stone top deck!);
///  * [ObstacleKind.trainWithRamp] — True `1/Z` 3D Elevated Ancient Stone
///    Sanctuary Platform with a Carved Stone Stair-Ramp in front -> run right
///    up onto the rune-lit stone platform top!
class Obstacle extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  Obstacle({
    required this.lane,
    this.kind = ObstacleKind.lowSpikes,
    this.isMoving = false,
    double initialDepth = 1.0,
  })  : _depth = initialDepth,
        super(priority: 1000);

  static final Float64List _identityMatrix4 = Float64List.fromList(const [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
  ]);
  static final Uint16List _quadIndices =
      Uint16List.fromList(const [0, 1, 3, 1, 2, 3]);

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
        size = Vector2(base * 1.08, base * 0.92);
      } else {
        size = Vector2(base * 1.42, base * 1.42);
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
      if (elev >= GameConfig.trainRoofElevation * 0.76) {
        return;
      }

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
      final playerAbovePlatform =
          game.effectivePlayerElevation >= GameConfig.trainRoofElevation * 0.76;
      if (playerAbovePlatform && _depth <= 0.08 && backDepth >= -0.08) {
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

  ({Color modulate, Color sideWall, Color runeGlow}) get _worldStoneStyle {
    if (isMoving) {
      return (
        modulate: const Color(0xFFB8789E),
        sideWall: const Color(0xFF2C1C38),
        runeGlow: const Color(0xFFFF784A),
      );
    }
    switch (game.selectedWorld) {
      case GameWorld.duskHollow:
        return (
          modulate: const Color(0xFFE0CEF6),
          sideWall: const Color(0xFF3E3258),
          runeGlow: const Color(0xFFFFD276),
        );
      case GameWorld.moonveilMarsh:
        return (
          modulate: const Color(0xFFBCEEEB),
          sideWall: const Color(0xFF284A54),
          runeGlow: const Color(0xFF7AF6E4),
        );
      case GameWorld.emberfallCanyon:
        return (
          modulate: const Color(0xFFFFD4A4),
          sideWall: const Color(0xFF784A30),
          runeGlow: const Color(0xFFFFCE64),
        );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (isTrain) {
      _renderExtruded3DStonePlatform(canvas);
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
            width: dw * 0.82,
            height: h * 0.14,
          ),
          Paint()
            ..color =
                const Color(0x77160E24).withValues(alpha: 0.48 * horizonAlpha),
        );
      }

      final paint = Paint()
        ..color = Color.fromARGB((horizonAlpha * 255).round(), 255, 255, 255)
        ..filterQuality = FilterQuality.medium;
      if (kind == ObstacleKind.highArch) {
        paint.colorFilter =
            ColorFilter.mode(_worldStoneStyle.modulate, BlendMode.modulate);
      }

      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
            0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH((w - dw) / 2, h - dh, dw, dh),
        paint,
      );
      return;
    }

    _renderFallback(canvas, w, h);
  }

  // ---------------------------------------------------------------------------
  // True `1/Z` 3D Extruded Ancient Carved Stone Sanctuary Platform & Stair-Ramp
  // ---------------------------------------------------------------------------
  ({double xl, double xr, double yt, double yb, double sc}) _boxSlice(
      double d) {
    final sc = game.scaleForDepth(d);
    final cx = game.laneXForDepth(lane.toDouble(), d);
    final yb = game.yForDepth(d);
    final hw = game.halfWidthForDepth(d) * GameConfig.laneSpreadRatio * 0.44;
    final hRef =
        game.size.y * GameConfig.jumpHeightRatio * GameConfig.trainRoofElevation;
    final yt = yb - hRef * sc;
    return (xl: cx - hw, xr: cx + hw, yt: yt, yb: yb, sc: sc);
  }

  void _renderExtruded3DStonePlatform(Canvas canvas) {
    if (_depth > 1.03) {
      return;
    }
    final zbClamped = math.min(1.02, backDepth);
    final zfClamped = math.max(-0.24, _depth);
    if (zfClamped < zbClamped) {
      _draw3DStoneBody(canvas, zfClamped, zbClamped);
    }

    if (kind == ObstacleKind.trainWithRamp) {
      final rFront = _depth - GameConfig.rampLengthDepth;
      final rBack = _depth;
      if (rFront < 1.02 && rBack > -0.22) {
        _draw3DStoneStairRamp(
          canvas,
          math.max(-0.22, rFront),
          math.min(1.02, rBack),
        );
      }
    }
  }

  void _drawTexturedStoneQuad(
    Canvas canvas,
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3, {
    required Color fallbackColor,
    required double alpha,
    Color? tintOverlay,
  }) {
    final strip = game.trackStrip;
    if (strip != null && alpha > 0.04) {
      final sw = strip.width.toDouble();
      final sh = strip.height.toDouble();
      final pos = Float32List.fromList([
        p0.dx, p0.dy,
        p1.dx, p1.dy,
        p2.dx, p2.dy,
        p3.dx, p3.dy,
      ]);
      final tex = Float32List.fromList([
        sw * 0.18, sh * 0.55,
        sw * 0.82, sh * 0.55,
        sw * 0.82, sh * 0.12,
        sw * 0.18, sh * 0.12,
      ]);
      final verts = Vertices.raw(
        VertexMode.triangles,
        pos,
        textureCoordinates: tex,
        indices: _quadIndices,
      );
      canvas.drawVertices(
        verts,
        BlendMode.srcOver,
        Paint()
          ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
          ..shader = ImageShader(
            strip,
            TileMode.clamp,
            TileMode.clamp,
            _identityMatrix4,
            filterQuality: FilterQuality.medium,
          ),
      );
      if (tintOverlay != null) {
        final over = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();
        canvas.drawPath(over, Paint()..color = tintOverlay);
      }
      return;
    }

    final quad = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(
      quad,
      Paint()..color = fallbackColor.withValues(alpha: alpha),
    );
  }

  void _draw3DStoneBody(Canvas canvas, double zf, double zb) {
    final f = _boxSlice(zf);
    final b = _boxSlice(zb);
    final alpha = ((1.03 - zf) / 0.10).clamp(0.0, 1.0).toDouble();
    final style = _worldStoneStyle;

    // 1. Grounded ambient shadow under full 3D stone sanctuary block
    final shadowPath = Path()
      ..moveTo(f.xl - 6 * f.sc, f.yb + 3)
      ..lineTo(f.xr + 6 * f.sc, f.yb + 3)
      ..lineTo(b.xr + 4 * b.sc, b.yb + 2)
      ..lineTo(b.xl - 4 * b.sc, b.yb + 2)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()..color = const Color(0x78140C24).withValues(alpha: 0.52 * alpha),
    );

    final outlinePaint = Paint()
      ..color = const Color(0xFF1A1228).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.8 * f.sc).clamp(1.0, 2.8).toDouble();

    // 2. 3D Perspective Carved Stone Side Wall + Glowing Rune Ledge Trim
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
      canvas.drawPath(
        sidePath,
        Paint()..color = style.sideWall.withValues(alpha: alpha),
      );
      canvas.drawPath(sidePath, outlinePaint);

      final yrf = f.yt + (f.yb - f.yt) * 0.18;
      final yrb = b.yt + (b.yb - b.yt) * 0.18;
      canvas.drawLine(
        Offset(xfS, yrf),
        Offset(xbS, yrb),
        Paint()
          ..color = style.runeGlow.withValues(alpha: 0.88 * alpha)
          ..strokeWidth = (2.8 * f.sc).clamp(1.0, 4.0).toDouble(),
      );
    }

    // 3. Walkable 3D Textured Ancient Stone Top Deck
    if (f.yt > b.yt + 0.5) {
      _drawTexturedStoneQuad(
        canvas,
        Offset(f.xl, f.yt),
        Offset(f.xr, f.yt),
        Offset(b.xr, b.yt),
        Offset(b.xl, b.yt),
        fallbackColor: style.modulate,
        alpha: alpha,
        tintOverlay: isMoving
            ? const Color(0x442A0E24).withValues(alpha: 0.30 * alpha)
            : null,
      );
      final roofOutline = Path()
        ..moveTo(f.xl, f.yt)
        ..lineTo(f.xr, f.yt)
        ..lineTo(b.xr, b.yt)
        ..lineTo(b.xl, b.yt)
        ..close();
      canvas.drawPath(
        roofOutline,
        Paint()
          ..color = style.runeGlow.withValues(alpha: 0.82 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.8 * f.sc).clamp(1.0, 2.8).toDouble(),
      );
    }

    // 4. Pre-Rendered 3D Carved Rune Stone Front Face!
    if (_depth >= -0.23) {
      final fw = math.max(2.0, f.xr - f.xl);
      final fh = math.max(2.0, f.yb - f.yt);
      final mono = game.obstacleMonolithSprite;
      if (mono != null) {
        final mw = mono.width.toDouble();
        final mh = mono.height.toDouble();
        canvas.drawImageRect(
          mono,
          Rect.fromLTWH(mw * 0.09, mh * 0.185, mw * 0.82, mh * 0.785),
          Rect.fromLTWH(f.xl, f.yt, fw, fh),
          Paint()
            ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
            ..colorFilter = ColorFilter.mode(style.modulate, BlendMode.modulate)
            ..filterQuality = FilterQuality.medium,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(f.xl, f.yt, fw, fh),
          Paint()..color = style.sideWall.withValues(alpha: alpha),
        );
      }
      // Glowing rune cornice along top front edge
      canvas.drawRect(
        Rect.fromLTWH(f.xl, f.yt, fw, math.max(2.0, 4.0 * f.sc)),
        Paint()..color = style.runeGlow.withValues(alpha: 0.92 * alpha),
      );
    }
  }

  void _draw3DStoneStairRamp(Canvas canvas, double zf, double zb) {
    final f = _boxSlice(zf);
    final b = _boxSlice(zb);
    final alpha = ((1.03 - zf) / 0.10).clamp(0.0, 1.0).toDouble();
    final style = _worldStoneStyle;

    // Carved stone side cheek wall
    final cheekPaint = Paint()..color = style.sideWall.withValues(alpha: alpha);
    if (f.xr < b.xr - 1.0) {
      final wedge = Path()
        ..moveTo(f.xr, f.yb)
        ..lineTo(b.xr, b.yb)
        ..lineTo(b.xr, b.yt)
        ..close();
      canvas.drawPath(wedge, cheekPaint);
    } else if (f.xl > b.xl + 1.0) {
      final wedge = Path()
        ..moveTo(f.xl, f.yb)
        ..lineTo(b.xl, b.yb)
        ..lineTo(b.xl, b.yt)
        ..close();
      canvas.drawPath(wedge, cheekPaint);
    }

    // Sloped textured stone staircase ramp deck (warm golden rune wash!)
    _drawTexturedStoneQuad(
      canvas,
      Offset(f.xl, f.yb),
      Offset(f.xr, f.yb),
      Offset(b.xr, b.yt),
      Offset(b.xl, b.yt),
      fallbackColor: style.modulate,
      alpha: alpha,
      tintOverlay: style.runeGlow.withValues(alpha: 0.24 * alpha),
    );

    final rampBorder = Path()
      ..moveTo(f.xl, f.yb)
      ..lineTo(f.xr, f.yb)
      ..lineTo(b.xr, b.yt)
      ..lineTo(b.xl, b.yt)
      ..close();
    canvas.drawPath(
      rampBorder,
      Paint()
        ..color = style.runeGlow.withValues(alpha: 0.90 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.0 * f.sc).clamp(1.0, 3.0).toDouble(),
    );

    // Carved glowing stone stair-riser steps
    final stepPaint = Paint()
      ..color = style.runeGlow.withValues(alpha: 0.85 * alpha)
      ..strokeWidth = (2.2 * f.sc).clamp(1.0, 3.2).toDouble();
    for (final u in const [0.26, 0.52, 0.78]) {
      final ym = f.yb + (b.yt - f.yb) * u;
      final xml = f.xl + (b.xl - f.xl) * u + 4 * f.sc;
      final xmr = f.xr + (b.xr - f.xr) * u - 4 * f.sc;
      canvas.drawLine(Offset(xml, ym), Offset(xmr, ym), stepPaint);
    }

    // Upward radiant golden rune chevron
    final ymA = f.yb + (b.yt - f.yb) * 0.50;
    final xmlA = f.xl + (b.xl - f.xl) * 0.50;
    final xmrA = f.xr + (b.xr - f.xr) * 0.50;
    final xmcA = (xmlA + xmrA) * 0.5;
    final arrow = Path()
      ..moveTo(xmcA - (xmrA - xmlA) * 0.22, ymA + 6 * f.sc)
      ..lineTo(xmcA + (xmrA - xmlA) * 0.22, ymA + 6 * f.sc)
      ..lineTo(xmcA, ymA - 8 * f.sc)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()..color = const Color(0xFFFFF4C2).withValues(alpha: alpha),
    );
  }

  void _renderFallback(Canvas canvas, double w, double h) {
    final fill = Paint()..color = const Color(0xFF4C3A6E);
    if (kind == ObstacleKind.lowSpikes) {
      final spike = Path()
        ..moveTo(w * 0.18, h)
        ..lineTo(w * 0.50, h * 0.18)
        ..lineTo(w * 0.82, h)
        ..close();
      canvas.drawPath(spike, fill);
    } else {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.06, h * 0.14, w * 0.88, h * 0.24),
        fill,
      );
    }
  }
}
