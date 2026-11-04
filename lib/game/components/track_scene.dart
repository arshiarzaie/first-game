import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// S15 Sunlit Subway-Surfers-Grade Full-Width 3D Boulevard & 3-Lane Railway.
///
/// Eliminates all dark-tunnel eye strain and 2D flatness:
///  1. Bright, high-key sunlit morning/golden-hour sky & painted horizon;
///  2. Full-width sunlit stone sidewalks (`0..W`, zero dark empty abyss);
///  3. Zero-flicker 3-lane twin-steel railway bed (`track_strip.png`);
///  4. True `1/Z` 3D perspective-extruded sunlit boulevard buildings with solid
///     3D roofs, receding inner walls, recessed windows, terracotta cornices,
///     and lush shaded sidewalk trees/cacti (`corridor_pillar.png`).
class TrackScene extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  TrackScene() : super(priority: -100);

  static const int _meshCols = 10;
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
    _renderSunlitSidewalks(canvas, w, h);
    _renderTrack(canvas, w, h);
    _renderBoulevardBuildingsAndTrees(canvas, w, h);
    _renderSkyDashWind(canvas, w, h);
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
        (horizonY + 8) / math.max(1.0, imgH * horizonFrac);
    final scale = math.max(w / imgW, minScaleForSky) * 1.08;

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

  /// Full-width sunlit boulevard ground & raised stone sidewalks (`0..W`,
  /// eliminating all dark side voids!).
  void _renderSunlitSidewalks(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final Color walkCol;
    final Color outerCol;
    final Color lipCol;
    switch (game.selectedWorld) {
      case GameWorld.duskHollow:
        walkCol = const Color(0xFFDACCB8);
        outerCol = const Color(0xFFC8B8A4);
        lipCol = const Color(0xFFA69684);
      case GameWorld.moonveilMarsh:
        walkCol = const Color(0xFFC2D6D4);
        outerCol = const Color(0xFFACC4C2);
        lipCol = const Color(0xFF8AA6A6);
      case GameWorld.emberfallCanyon:
        walkCol = const Color(0xFFE0B896);
        outerCol = const Color(0xFFCCA280);
        lipCol = const Color(0xFFAA8264);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, h - horizonY),
      Paint()..color = outerCol,
    );

    final depthBottom = game.depthForScreenY(h);
    const pFar = GameConfig.farScale;
    final pBottom = game.perspectiveFactor(depthBottom);

    final cxTop = game.trackCenterXForDepth(1.0);
    final cxBot = game.trackCenterXForDepth(depthBottom);
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;
    final walkPlayer = w * 0.135;

    final hTop = halfPlayer * pFar;
    final hBot = halfPlayer * pBottom;
    final wTop = walkPlayer * pFar;
    final wBot = walkPlayer * pBottom;

    final walkPaint = Paint()..color = walkCol;
    final lipPaint = Paint()
      ..color = lipCol
      ..strokeWidth = 2.2;

    for (final side in const [-1.0, 1.0]) {
      final sxTop = cxTop + side * (hTop + wTop);
      final sxBot = cxBot + side * (hBot + wBot);
      final walkPath = Path()
        ..moveTo(cxTop + side * hTop, horizonY)
        ..lineTo(sxTop, horizonY)
        ..lineTo(sxBot, h)
        ..lineTo(cxBot + side * hBot, h)
        ..close();
      canvas.drawPath(walkPath, walkPaint);
      canvas.drawLine(Offset(sxTop, horizonY), Offset(sxBot, h), lipPaint);
    }
  }

  /// True `1/Z` 3D perspective-extruded sunlit boulevard buildings + lush
  /// shaded sidewalk trees/cacti along both sides of the railway!
  void _renderBoulevardBuildingsAndTrees(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }

    final List<Color> frontCols;
    final List<Color> sideCols;
    final Color roofDeckCol;
    final Color roofTrimCol;
    switch (game.selectedWorld) {
      case GameWorld.duskHollow:
        frontCols = const [
          Color(0xFFF0D6B6),
          Color(0xFFEAC2AC),
          Color(0xFFDED4C6),
        ];
        sideCols = const [
          Color(0xFFDABE9E),
          Color(0xFFD2A894),
          Color(0xFFC6BCAC),
        ];
        roofDeckCol = const Color(0xFFD88864);
        roofTrimCol = const Color(0xFFBC6244);
      case GameWorld.moonveilMarsh:
        frontCols = const [
          Color(0xFFD4E8E4),
          Color(0xFFC4E0E2),
          Color(0xFFDCECE2),
        ];
        sideCols = const [
          Color(0xFFB8D0CC),
          Color(0xFFA8C6CA),
          Color(0xFFC0D4CA),
        ];
        roofDeckCol = const Color(0xFF5CA6AC);
        roofTrimCol = const Color(0xFF3A888E);
      case GameWorld.emberfallCanyon:
        frontCols = const [
          Color(0xFFEEBA90),
          Color(0xFFE29C76),
          Color(0xFFECAE84),
        ];
        sideCols = const [
          Color(0xFFD29E76),
          Color(0xFFC68260),
          Color(0xFFD0946E),
        ];
        roofDeckCol = const Color(0xFFC86A48);
        roofTrimCol = const Color(0xFFA84E32);
    }

    final hp = w * GameConfig.trackBottomHalfWidthRatio;
    final walkW = w * 0.135;
    final pillar = game.corridorPillar;

    const bldgCount = 4;
    const bldgSpan = 1.28;
    const bStep = bldgSpan / bldgCount;
    final bScroll = game.travelled / GameConfig.trackLength;
    final slotBase = bScroll.floor();
    final bPhase = bScroll % bStep;

    final outlinePaint = Paint()
      ..color = const Color(0x99706054)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final winPaint = Paint()..color = const Color(0xE640607C);

    // Draw back-to-front (`k = 0` is closest to horizon).
    for (var k = 0; k < bldgCount; k++) {
      final distH = bPhase + k * bStep;
      final zfRaw = 1.0 - distH;
      final zb = math.min(1.0, zfRaw + bStep * 0.78);
      if (zfRaw >= zb - 0.02 || zfRaw < -0.25) {
        continue;
      }
      final zf = math.max(-0.22, zfRaw);
      final pf = game.perspectiveFactor(zf);
      final pb = game.perspectiveFactor(zb);
      final yf = game.yForDepth(zf);
      final yb = game.yForDepth(zb);
      final cxf = game.trackCenterXForDepth(zf);
      final cxb = game.trackCenterXForDepth(zb);

      final styleIdx = ((slotBase - k) % 3 + 3) % 3;
      final bldgH = h * (0.18 + 0.035 * (styleIdx % 2));
      final colF = frontCols[styleIdx];
      final colS = sideCols[styleIdx];
      final alpha = (distH / 0.10).clamp(0.0, 1.0).toDouble();

      for (final side in const [-1.0, 1.0]) {
        final ixF = cxf + side * (hp + walkW) * pf;
        final ixB = cxb + side * (hp + walkW) * pb;
        final oxF = side < 0 ? -12.0 : w + 12.0;
        final oxB = cxb + side * (hp + walkW + w * 0.40) * pb;
        final ytF = yf - bldgH * pf;
        final ytB = yb - bldgH * pb;

        // 1. Solid 3D Roof Deck (when viewed from slightly above)
        if (ytF > ytB) {
          final roofPath = Path()
            ..moveTo(ixF, ytF)
            ..lineTo(oxF, ytF)
            ..lineTo(oxB, ytB)
            ..lineTo(ixB, ytB)
            ..close();
          canvas.drawPath(
            roofPath,
            Paint()..color = roofDeckCol.withValues(alpha: alpha),
          );
        }

        // 2. 3D Perspective Inner Facade Wall facing the railway
        final sideWall = Path()
          ..moveTo(ixF, yf)
          ..lineTo(ixB, yb)
          ..lineTo(ixB, ytB)
          ..lineTo(ixF, ytF)
          ..close();
        canvas.drawPath(
          sideWall,
          Paint()..color = colS.withValues(alpha: alpha),
        );
        canvas.drawPath(sideWall, outlinePaint);

        // Two perspective-foreshortened windows along inner facade
        winPaint.color = const Color(0xE640607C).withValues(alpha: alpha);
        for (final spanU in const [(0.18, 0.42), (0.58, 0.82)]) {
          final u0 = spanU.$1;
          final u1 = spanU.$2;
          final wx0 = ixF + (ixB - ixF) * u0;
          final wx1 = ixF + (ixB - ixF) * u1;
          final wyt0 = ytF + (ytB - ytF) * u0;
          final wyt1 = ytF + (ytB - ytF) * u1;
          final hh0 = (yf - ytF) * (1 - u0) + (yb - ytB) * u0;
          final hh1 = (yf - ytF) * (1 - u1) + (yb - ytB) * u1;
          final winPath = Path()
            ..moveTo(wx0, wyt0 + hh0 * 0.20)
            ..lineTo(wx1, wyt1 + hh1 * 0.20)
            ..lineTo(wx1, wyt1 + hh1 * 0.52)
            ..lineTo(wx0, wyt0 + hh0 * 0.52)
            ..close();
          canvas.drawPath(winPath, winPaint);
        }

        // Terracotta / tile cornice along inner roof edge
        final trimPaint = Paint()
          ..color = roofTrimCol.withValues(alpha: alpha)
          ..strokeWidth = (4.5 * pf).clamp(1.5, 6.0).toDouble()
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(ixF, ytF), Offset(ixB, ytB), trimPaint);

        // 3. Front Wall facing the player at zf
        final frontWall = Path()
          ..moveTo(ixF, yf)
          ..lineTo(oxF, yf)
          ..lineTo(oxF, ytF)
          ..lineTo(ixF, ytF)
          ..close();
        canvas.drawPath(
          frontWall,
          Paint()..color = colF.withValues(alpha: alpha),
        );
        canvas.drawPath(frontWall, outlinePaint);
        canvas.drawLine(Offset(ixF, ytF), Offset(oxF, ytF), trimPaint);

        // 4. Lush Sidewalk Tree / Cactus in stone planter!
        final zm = (zf + zb) * 0.5;
        final pm = game.perspectiveFactor(zm);
        final ym = game.yForDepth(zm);
        final pw = w * 0.145 * pm;
        final aspect = pillar != null ? pillar.height / pillar.width : 1.71;
        final ph = pw * aspect;
        final tx = game.trackCenterXForDepth(zm) +
            side * (hp + walkW * 0.52) * pm;

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(tx, ym),
            width: pw * 0.58,
            height: pw * 0.15,
          ),
          Paint()..color = const Color(0x484E463E).withValues(alpha: 0.30 * alpha),
        );

        if (pillar != null) {
          canvas.drawImageRect(
            pillar,
            Rect.fromLTWH(
                0, 0, pillar.width.toDouble(), pillar.height.toDouble()),
            Rect.fromLTWH(tx - pw / 2, ym + ph * 0.02 - ph, pw, ph),
            Paint()
              ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
              ..filterQuality = FilterQuality.medium,
          );
        } else {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(tx, ym - ph * 0.52),
              width: pw * 0.65,
              height: ph * 0.55,
            ),
            Paint()..color = const Color(0xFF569E60).withValues(alpha: alpha),
          );
        }
      }
    }
  }

  void _renderSkyDashWind(Canvas canvas, double w, double h) {
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
        cx + side * w * 0.46 * r0,
        horizonY + (h - horizonY) * spreadY * r0,
      );
      final p1 = Offset(
        cx + side * w * 0.46 * r1,
        horizonY + (h - horizonY) * spreadY * r1,
      );
      final fade = (math.sin(t * math.pi) * 0.32).clamp(0.0, 1.0).toDouble();
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: fade);
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

      final fadeEnd = horizonY + (h - horizonY) * 0.04;
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

    // Sunlit railway fallback for headless widget tests without loaded images.
    final railPaint = Paint()
      ..color = Color(GameConfig.trackLaneArgbFor(game.selectedWorld))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (var lane = 0; lane < GameConfig.laneCount; lane++) {
      for (final rOff in const [-0.18, 0.18]) {
        canvas.drawLine(
          Offset(game.laneXForDepth(lane + rOff, 1.0), horizonY),
          Offset(game.laneXForDepth(lane + rOff, depthBottom), h),
          railPaint,
        );
      }
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
    final horizonY = game.horizonY;
    final sky = Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, horizonY),
        const [Color(0xFF4A94DC), Color(0xFF98CAEE), Color(0xFFFCE4C0)],
        const [0.0, 0.58, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizonY), sky);
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, w, h - horizonY),
      Paint()..color = const Color(0xFFC8B8A4),
    );
  }
}
