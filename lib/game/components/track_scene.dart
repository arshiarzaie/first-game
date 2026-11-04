import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// S16 Cinematic `SOUL: DUSK RUN` Floating Ancient Stone Causeway & Fantasy
/// Valley Vista (faithful 1-to-1 implementation of the Official Concept Board).
///
/// Renders:
///  1. Full-bleed vertical pre-rendered fantasy world painting (`backdrop.png`)
///     covering 100% of screen width and height (`0..W`, `0..H`) so both lush
///     fantasy valley flanks remain completely visible with zero dark void;
///  2. Sculpted 3D stone bridge side-apron depth bevels along the floating
///     causeway edges;
///  3. Smooth zero-flicker `12×48` `1/Z` perspective-foreshortened ancient
///     stone causeway (`track_strip.png`);
///  4. Pre-rendered 3D parapet lantern-pillars (`corridor_pillar.png`) with
///     warm magical lantern light pools streaming along the bridge curbs.
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
    _renderBridgeStoneApron(canvas, w, h);
    _renderTrack(canvas, w, h);
    _renderParapetLanternPillars(canvas, w, h);
    _renderSolarFlightStreaks(canvas, w, h);
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
    // Cover 100% of screen width AND height so lush painted valley cliffs
    // extend all the way to the bottom corners (`0%` black border!).
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

  /// Subtle 3D carved stone thickness under the outer edges of the floating
  /// ancient bridge so it sits naturally inside the valley chasm.
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

  /// Streams pre-rendered 3D fantasy lantern-pillars (`corridor_pillar.png`)
  /// synchronously with the bridge masonry along both stone parapets!
  void _renderParapetLanternPillars(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final pillar = game.corridorPillar;
    final auraColor = Color(GameConfig.lanternAuraArgbFor(game.selectedWorld));

    const pairCount = 4;
    const depthSpan = 1.16;
    const step = depthSpan / pairCount;
    final phase = (game.travelled / GameConfig.trackLength) % step;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    for (var k = 0; k < pairCount; k++) {
      final distH = phase + k * step;
      final depth = 1.0 - distH;
      if (depth > 0.99 || depth < -0.16) {
        continue;
      }
      final sc = game.perspectiveFactor(depth);
      final yb = game.yForDepth(depth);
      final cx = game.trackCenterXForDepth(depth);
      final hw = halfPlayer * sc;
      final fade = (distH / 0.12).clamp(0.0, 1.0).toDouble();

      final pw = w * 0.165 * sc;
      final aspect = pillar != null ? pillar.height / pillar.width : 1.75;
      final ph = pw * aspect;

      for (final side in const [-1.0, 1.0]) {
        final px = cx + side * hw * 0.95;

        // Soft warm magical lantern glow pool cast onto the stone curb!
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px - side * pw * 0.18, yb),
            width: pw * 0.95,
            height: pw * 0.24,
          ),
          Paint()..color = auraColor.withValues(alpha: 0.20 * fade),
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
        } else {
          canvas.drawRect(
            Rect.fromLTWH(px - pw * 0.18, yb - ph * 0.8, pw * 0.36, ph * 0.8),
            Paint()..color = auraColor.withValues(alpha: 0.75 * fade),
          );
        }
      }
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

      final fadeEnd = horizonY + (h - horizonY) * 0.045;
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
