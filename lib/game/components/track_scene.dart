import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// S17 Living 6-Layer 3D `SOUL: DUSK RUN` Fantasy World (`TrackScene`).
///
/// Transforms the static background into a deep, breathing, moving 3D world:
///  1. Full-portrait atmospheric twilight/moonveil/emberfall horizon & misty
///     chasm vista (`backdrop.png`);
///  2. Soft diagonal God-rays (sunbeams/moonbeams) slanting from the horizon
///     citadel across the valley;
///  3. Outer-valley 3D Floating Fantasy Islands (`floating_island.png`)
///     streaming forward in true `1/Z` depth on both left & right sides with
///     gentle vertical levitation;
///  4. Drifting atmospheric valley mist bands below the stone causeway;
///  5. Smooth `12×48` `1/Z` perspective-foreshortened ancient stone bridge
///     (`track_strip.png`) converging naturally toward the horizon citadel;
///  6. Synchronized `1.0x` bridge-edge 3D Crystal/Flora Outcrops
///     (`cliff_side.png`) alternating with 3D Parapet Lantern-Pillars
///     (`corridor_pillar.png`), plus dreamy floating Firefly Light Motes!
class TrackScene extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  TrackScene() : super(priority: -100);

  static const int _meshCols = 12;
  static const int _meshRows = 48;
  static final Float64List _identityMatrix4 = Float64List.fromList(const [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
  ]);

  final Float32List _meshPos =
      Float32List((_meshRows + 1) * (_meshCols + 1) * 2);
  final Float32List _meshTex =
      Float32List((_meshRows + 1) * (_meshCols + 1) * 2);
  late final Uint16List _meshIdx = _buildMeshIndices();

  static Uint16List _buildMeshIndices() {
    const stride = _meshCols + 1;
    final out = Uint16List(_meshRows * _meshCols * 6);
    var k = 0;
    for (var r = 0; r < _meshRows; r++) {
      final row0 = r * stride;
      final row1 = (r + 1) * stride;
      for (var c = 0; c < _meshCols; c++) {
        final a = row0 + c;
        final b = a + 1;
        final d = row1 + c;
        final e = d + 1;
        out[k++] = a;
        out[k++] = b;
        out[k++] = d;
        out[k++] = b;
        out[k++] = e;
        out[k++] = d;
      }
    }
    return out;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topLeft;
    position = Vector2.zero();
    size = game.size.clone();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
  }

  @override
  bool containsLocalPoint(Vector2 point) => false;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) {
      return;
    }

    final backdrop = game.worldBackdrop;
    if (backdrop != null) {
      _renderWorldBackdrop(canvas, w, h, backdrop);
    } else {
      _renderPlaceholderBackdrop(canvas, w, h);
    }
    _renderAtmosphericGodRays(canvas, w, h);
    _renderStreamingFloatingIslands(canvas, w, h);
    _renderDriftingValleyMist(canvas, w, h);
    _renderBridgeStoneApron(canvas, w, h);
    _renderTrack(canvas, w, h);
    _renderBridgeCurbFloraAndLanterns(canvas, w, h);
    _renderFloatingFireflyMotes(canvas, w, h);
    _renderSolarFlightStreaks(canvas, w, h);
  }

  Color get _worldLightColor {
    switch (game.selectedWorld) {
      case GameWorld.duskHollow:
        return const Color(0xFFFFD494);
      case GameWorld.moonveilMarsh:
        return const Color(0xFF82F8E8);
      case GameWorld.emberfallCanyon:
        return const Color(0xFFFFC66C);
    }
  }

  void _renderWorldBackdrop(
      Canvas canvas, double w, double h, Image backdrop) {
    final horizonY = game.horizonY;
    final imgW = backdrop.width.toDouble();
    final imgH = backdrop.height.toDouble();
    final baseFill =
        Color(GameConfig.trackFillArgbFor(game.selectedWorld) | 0xFF000000);

    canvas.drawRect(Offset.zero & Size(w, h), Paint()..color = baseFill);

    final horizonFrac =
        GameConfig.backdropHorizonFractionFor(game.selectedWorld);
    final minScaleForSky =
        (horizonY + 6) / math.max(1.0, imgH * horizonFrac);
    final scale = math.max(math.max(w / imgW, h / imgH), minScaleForSky) * 1.05;

    final laneCenter = (GameConfig.laneCount - 1) / 2;
    final sway = (game.cameraLane - laneCenter) * -GameConfig.cameraSwayPerLane;
    final dx = (w - imgW * scale) / 2 + sway;
    final dy = (horizonY - imgH * horizonFrac * scale)
        .clamp(math.min(0.0, h - imgH * scale), 0.0)
        .toDouble();

    canvas.drawImageRect(
      backdrop,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(dx, dy, imgW * scale, imgH * scale),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// Soft slanting sunbeams / moonbeams radiating from the horizon citadel.
  void _renderAtmosphericGodRays(Canvas canvas, double w, double h) {
    final lightCol = _worldLightColor;
    final breath = 0.85 + 0.15 * math.sin(game.elapsedSeconds * 0.9);
    const rays = [
      (0.46, 0.06, 0.14, 0.22, 0.085),
      (0.51, 0.08, 0.52, 0.28, 0.105),
      (0.56, 0.06, 0.88, 0.21, 0.075),
    ];
    for (final r in rays) {
      final topX = w * r.$1;
      final topW = w * r.$2;
      final botX = w * r.$3;
      final botW = w * r.$4;
      final alpha = r.$5 * breath;
      final path = Path()
        ..moveTo(topX - topW, h * 0.17)
        ..lineTo(topX + topW, h * 0.17)
        ..lineTo(botX + botW, h * 0.94)
        ..lineTo(botX - botW, h * 0.94)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = Gradient.linear(
            Offset(topX, h * 0.17),
            Offset(botX, h * 0.94),
            [
              lightCol.withValues(alpha: alpha),
              lightCol.withValues(alpha: 0.0),
            ],
          ),
      );
    }
  }

  /// Streams pre-rendered 3D Floating Fantasy Islands (`floating_island.png`)
  /// through the outer valley on both sides of the bridge in true `1/Z` depth!
  void _renderStreamingFloatingIslands(Canvas canvas, double w, double h) {
    final island = game.floatingIsland;
    if (island == null || h <= game.horizonY) {
      return;
    }
    const islandCount = 4;
    const span = 1.36;
    const step = span / islandCount;
    // Outer valley islands glide at 0.58x world speed for rich 3D depth parallax!
    final scroll = (game.travelled * 0.58) / GameConfig.trackLength;
    final slotBase = scroll.floor();
    final phase = scroll % step;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;
    final aspect = island.height / island.width;

    for (var k = 0; k < islandCount; k++) {
      final distH = phase + k * step;
      final depth = 1.05 - distH;
      if (depth > 1.02 || depth < -0.28) {
        continue;
      }
      final slotId = slotBase * islandCount - k;
      final sc = game.perspectiveFactor(depth);
      final hw = halfPlayer * sc;
      final cx = game.trackCenterXForDepth(depth);
      final yb = game.yForDepth(depth);
      final fade = ((1.04 - depth) / 0.22).clamp(0.0, 1.0).toDouble();

      final iw = w * 0.44 * sc;
      final ih = iw * aspect;
      final bob =
          math.sin(game.elapsedSeconds * 1.4 + slotId * 1.9) * h * 0.012 * sc;

      // Alternate staggered heights & lateral offsets on left and right flanks!
      for (final side in const [-1.0, 1.0]) {
        final stagger = (side > 0) ? 0.14 : 0.0;
        final dSide = depth - stagger;
        if (dSide > 1.02 || dSide < -0.28) {
          continue;
        }
        final scS = game.perspectiveFactor(dSide);
        final hwS = halfPlayer * scS;
        final cxS = game.trackCenterXForDepth(dSide);
        final ybS = game.yForDepth(dSide);
        final fadeS = ((1.04 - dSide) / 0.22).clamp(0.0, 1.0).toDouble() * fade;
        final iwS = w * 0.44 * scS;
        final ihS = iwS * aspect;

        final xMult = 1.72 + 0.28 * ((slotId.abs() + (side > 0 ? 1 : 0)) % 2);
        final yLift = h * (0.04 - 0.05 * (1.0 - dSide)) + bob;
        final ix = cxS + side * hwS * xMult;
        final iy = ybS + h * 0.11 * scS - yLift;

        canvas.save();
        canvas.translate(ix, iy - ihS / 2);
        if (side > 0) {
          canvas.scale(-1.0, 1.0);
        }
        canvas.drawImageRect(
          island,
          Rect.fromLTWH(
              0, 0, island.width.toDouble(), island.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: iwS, height: ihS),
          Paint()
            ..color = Color.fromARGB((fadeS * 255).round(), 255, 255, 255)
            ..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
      }
    }
  }

  /// Gentle drifting valley mist below the floating stone bridge.
  void _renderDriftingValleyMist(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final mistCol = _worldLightColor;
    final t = game.elapsedSeconds * 0.22;
    for (var i = 0; i < 3; i++) {
      final yFrac = 0.36 + i * 0.22;
      final driftX = math.sin(t + i * 2.1) * w * 0.12;
      final cy = h * yFrac;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5 + driftX, cy),
          width: w * 1.35,
          height: h * 0.15,
        ),
        Paint()..color = mistCol.withValues(alpha: 0.08),
      );
    }
  }

  void _renderBridgeStoneApron(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final depthBottom = game.depthForScreenY(h);
    const pFar = GameConfig.farScale;
    final pBottom = game.perspectiveFactor(depthBottom);

    final cxTop = game.trackCenterXForDepth(1.0);
    final cxBot = game.trackCenterXForDepth(depthBottom);
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;
    final apronPlayer = w * 0.022;

    final hTop = halfPlayer * pFar;
    final hBot = halfPlayer * pBottom;
    final aTop = apronPlayer * pFar;
    final aBot = apronPlayer * pBottom;

    final Color apronCol;
    switch (game.selectedWorld) {
      case GameWorld.duskHollow:
        apronCol = const Color(0xCC3C3058);
      case GameWorld.moonveilMarsh:
        apronCol = const Color(0xCC22444E);
      case GameWorld.emberfallCanyon:
        apronCol = const Color(0xCC7E5034);
    }

    final paint = Paint()..color = apronCol;
    for (final side in const [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(cxTop + side * hTop, horizonY)
        ..lineTo(cxTop + side * (hTop + aTop), horizonY + 3)
        ..lineTo(cxBot + side * (hBot + aBot), h)
        ..lineTo(cxBot + side * hBot, h)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  /// Alternates pre-rendered 3D Bridge-Edge Crystal/Flora Outcrops
  /// (`cliff_side.png`) and 3D Parapet Lantern-Pillars (`corridor_pillar.png`)
  /// moving at exact `1.0x` synchronized `1/Z` speed along both bridge curbs!
  void _renderBridgeCurbFloraAndLanterns(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final pillar = game.corridorPillar;
    final cliff = game.cliffSide;
    final auraColor = Color(GameConfig.lanternAuraArgbFor(game.selectedWorld));

    const slotCount = 6;
    const depthSpan = 1.20;
    const step = depthSpan / slotCount;
    final scroll = game.travelled / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    for (var k = 0; k < slotCount; k++) {
      final distH = phase + k * step;
      final depth = 1.0 - distH;
      if (depth > 0.99 || depth < -0.18) {
        continue;
      }
      final sc = game.perspectiveFactor(depth);
      final yb = game.yForDepth(depth);
      final cx = game.trackCenterXForDepth(depth);
      final hw = halfPlayer * sc;
      final fade = (distH / 0.14).clamp(0.0, 1.0).toDouble();
      final worldSlot = slotBase - k;
      final isLanternSlot = worldSlot.isEven;

      for (final side in const [-1.0, 1.0]) {
        if (isLanternSlot || cliff == null) {
          final px = cx + side * hw * 0.95;
          final pw = w * 0.165 * sc;
          final aspect = pillar != null ? pillar.height / pillar.width : 1.75;
          final ph = pw * aspect;

          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(px - side * pw * 0.18, yb),
              width: pw * 0.95,
              height: pw * 0.24,
            ),
            Paint()..color = auraColor.withValues(alpha: 0.22 * fade),
          );

          if (pillar != null) {
            canvas.drawImageRect(
              pillar,
              Rect.fromLTWH(
                  0, 0, pillar.width.toDouble(), pillar.height.toDouble()),
              Rect.fromLTWH(px - pw / 2, yb + ph * 0.04 - ph, pw, ph),
              Paint()
                ..color = Color.fromARGB((fade * 255).round(), 255, 255, 255)
                ..filterQuality = FilterQuality.medium,
            );
          }
        } else {
          final px = cx + side * hw * 1.02;
          final cw = w * 0.245 * sc;
          final ch = cw * (cliff.height / cliff.width);

          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(px - side * cw * 0.12, yb + ch * 0.04),
              width: cw * 0.72,
              height: cw * 0.18,
            ),
            Paint()..color = auraColor.withValues(alpha: 0.16 * fade),
          );

          canvas.save();
          canvas.translate(px, yb + ch * 0.06 - ch / 2);
          if (side > 0) {
            canvas.scale(-1.0, 1.0);
          }
          canvas.drawImageRect(
            cliff,
            Rect.fromLTWH(
                0, 0, cliff.width.toDouble(), cliff.height.toDouble()),
            Rect.fromCenter(center: Offset.zero, width: cw, height: ch),
            Paint()
              ..color = Color.fromARGB((fade * 255).round(), 255, 255, 255)
              ..filterQuality = FilterQuality.medium,
          );
          canvas.restore();
        }
      }
    }
  }

  /// Dreamy floating golden/cyan firefly motes drifting gently through 3D space.
  void _renderFloatingFireflyMotes(Canvas canvas, double w, double h) {
    const count = GameConfig.ambientParticleCount;
    if (count <= 0) {
      return;
    }
    final glowCol = _worldLightColor;
    final scroll = game.travelled / GameConfig.trackLength;
    final t = game.elapsedSeconds;

    for (var i = 0; i < count; i++) {
      final seed = i * 0.6180339887;
      final depth = 1.0 - ((scroll * 0.45 + seed) % 1.12);
      if (depth > 0.98 || depth < -0.10) {
        continue;
      }
      final sc = game.perspectiveFactor(depth);
      final laneOffset = math.sin(seed * 19.3 + t * 0.55) * 1.65;
      final mx = game.laneXForDepth(1.0 + laneOffset, depth);
      final floatH = (0.15 + 0.55 * ((seed * 7.13) % 1.0)) +
          math.sin(t * 1.3 + i) * 0.08;
      final my = game.yForDepth(depth) - h * 0.22 * floatH * sc;
      final pulse = 0.55 + 0.45 * math.sin(t * 2.4 + i * 1.7);
      final fade =
          ((1.0 - depth) / 0.20).clamp(0.0, 1.0).toDouble() * pulse;
      final r = (3.4 * sc).clamp(1.2, 4.8).toDouble();

      canvas.drawCircle(
        Offset(mx, my),
        r * 2.3,
        Paint()..color = glowCol.withValues(alpha: 0.22 * fade),
      );
      canvas.drawCircle(
        Offset(mx, my),
        r * 0.75,
        Paint()
          ..color = const Color(0xFFFFFCE8).withValues(alpha: 0.78 * fade),
      );
    }
  }

  void _renderSolarFlightStreaks(Canvas canvas, double w, double h) {
    if (!game.isRunStarted || !game.powerUps.isSolarDashing) {
      return;
    }
    final horizonY = game.horizonY;
    final cx = w / 2;
    final paint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const streakCount = 6;
    final phaseBase = game.travelled / GameConfig.trackLength * 1.4;
    for (var i = 0; i < streakCount; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final t = (phaseBase + i * 0.167) % 1.0;
      final r0 = 0.34 + t * 0.48;
      final r1 = (r0 + 0.10).clamp(0.0, 1.0).toDouble();
      final spreadY = 0.16 + (i % 3) * 0.20;
      final p0 = Offset(
        cx + side * w * 0.44 * r0,
        horizonY + (h - horizonY) * spreadY * r0,
      );
      final p1 = Offset(
        cx + side * w * 0.44 * r1,
        horizonY + (h - horizonY) * spreadY * r1,
      );
      final fade = (math.sin(t * math.pi) * 0.36).clamp(0.0, 1.0).toDouble();
      paint.color = const Color(0xFFFFECA8).withValues(alpha: fade);
      canvas.drawLine(p0, p1, paint);
    }
  }

  void _renderTrack(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final depthBottom = game.depthForScreenY(h);
    const pFar = GameConfig.farScale;
    final pBottom = game.perspectiveFactor(depthBottom);

    final cxTop = game.trackCenterXForDepth(1.0);
    final cxBot = game.trackCenterXForDepth(depthBottom);
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;
    final halfTop = halfPlayer * pFar;
    final halfBottom = halfPlayer * pBottom;

    final strip = game.trackStrip;
    if (strip != null && h > horizonY) {
      final trackBounds = Rect.fromLTWH(0, horizonY, w, h - horizonY);
      canvas.saveLayer(trackBounds, Paint());
      _renderStripMesh(
        canvas,
        strip,
        horizonY: horizonY,
        h: h,
        spanToPlayer: spanToPlayer,
        halfPlayer: halfPlayer,
      );

      final fadeEnd = horizonY + (h - horizonY) * 0.065;
      canvas.drawRect(
        Rect.fromLTWH(0, horizonY, w, fadeEnd - horizonY + 1),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = Gradient.linear(
            Offset(0, horizonY),
            Offset(0, fadeEnd),
            const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
          ),
      );
      canvas.restore();
      return;
    }

    final track = Path()
      ..moveTo(cxTop - halfTop, horizonY)
      ..lineTo(cxTop + halfTop, horizonY)
      ..lineTo(cxBot + halfBottom, h)
      ..lineTo(cxBot - halfBottom, h)
      ..close();
    canvas.drawPath(
      track,
      Paint()
        ..color =
            Color(GameConfig.trackFillArgbFor(game.selectedWorld) | 0xFF000000),
    );
    final runePaint = Paint()
      ..color = Color(GameConfig.trackLaneArgbFor(game.selectedWorld))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (final div in const [-0.5, 0.5]) {
      canvas.drawLine(
        Offset(game.laneXForDepth(1.0 + div, 1.0), horizonY),
        Offset(game.laneXForDepth(1.0 + div, depthBottom), h),
        runePaint,
      );
    }
  }

  void _renderStripMesh(
    Canvas canvas,
    Image strip, {
    required double horizonY,
    required double h,
    required double spanToPlayer,
    required double halfPlayer,
  }) {
    final stripW = strip.width.toDouble();
    final stripH = strip.height.toDouble();
    const pFar = GameConfig.farScale;
    final tBottom = (h - horizonY) / spanToPlayer;
    final scroll =
        (game.travelled / GameConfig.trackLength) * GameConfig.trackTileRepeats;

    var idx = 0;
    for (var r = 0; r <= _meshRows; r++) {
      final rowFrac = r / _meshRows;
      final t = rowFrac * tBottom;
      final y = horizonY + spanToPlayer * t;
      final p = pFar + t * (1.0 - pFar);
      final z = 1.0 / p;
      final depth = (z - 1.0) / (GameConfig.farDepthRatio - 1.0);
      final distFromHorizon = 1.0 - depth;
      final vUnwrapped =
          (distFromHorizon * GameConfig.trackTileRepeats - (scroll % 1.0)) *
              stripH;
      final cxRow = game.trackCenterXForDepth(depth);
      final half = halfPlayer * p;
      final left = cxRow - half;
      final width = half * 2;

      for (var c = 0; c <= _meshCols; c++) {
        final fx = c / _meshCols;
        _meshPos[idx] = left + width * fx;
        _meshPos[idx + 1] = y;
        _meshTex[idx] = stripW * fx;
        _meshTex[idx + 1] = vUnwrapped;
        idx += 2;
      }
    }

    final vertices = Vertices.raw(
      VertexMode.triangles,
      _meshPos,
      textureCoordinates: _meshTex,
      indices: _meshIdx,
    );
    final paint = Paint()
      ..shader = ImageShader(
        strip,
        TileMode.clamp,
        TileMode.repeated,
        _identityMatrix4,
        filterQuality: FilterQuality.medium,
      );
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
  }

  void _renderPlaceholderBackdrop(Canvas canvas, double w, double h) {
    final sky = Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, h),
        const [Color(0xFF5A4888), Color(0xFFD89882), Color(0xFF48386E)],
        const [0.0, 0.32, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);
  }
}
