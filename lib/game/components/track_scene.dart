import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// Stage 3 3D `SOUL: DUSK RUN` World Engine (`TrackScene`):
///  * **Abyssal World Termination ("پشتش هیچی نباشد")**: when a
///    `CrystalPortalGate` approaches, the stone causeway, curbs, curb props,
///    cliff corridors, and valley floor physically terminate at
///    `game.activeRoadMaxDepth` into a cosmic star-lit abyss with levitating
///    shattered stone fragments;
///  * **Sensational Dimensional Breach ("تغییر محیط جنجالی")**: explosive
///    prismatic shockwave rings, 28 radial hyperspace warp streaks, shattering
///    crystal prism shards, and a lightspeed unfurling new-world stone highway;
///  * **Zero `MaskFilter.blur` & Cached `ImageShader`s** for locked 60/120fps!
class TrackScene extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  TrackScene() : super(priority: -100);

  static const int _meshCols = 12;
  static const int _meshRows = 48;

  static const int _valCols = 16;
  static const int _valRows = 32;

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
  late final Uint16List _meshIdx = _buildGridIndices(_meshRows, _meshCols);

  final Float32List _valPos =
      Float32List((_valRows + 1) * (_valCols + 1) * 2);
  final Float32List _valTex =
      Float32List((_valRows + 1) * (_valCols + 1) * 2);
  late final Uint16List _valIdx = _buildGridIndices(_valRows, _valCols);

  Image? _cachedValleyImg;
  Paint? _cachedValleyPaint;

  Image? _cachedStripImg;
  Paint? _cachedStripPaint;

  static Uint16List _buildGridIndices(int rows, int cols) {
    final stride = cols + 1;
    final out = Uint16List(rows * cols * 6);
    var k = 0;
    for (var r = 0; r < rows; r++) {
      final row0 = r * stride;
      final row1 = (r + 1) * stride;
      for (var c = 0; c < cols; c++) {
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

  static double _smoothstep01(double x) {
    final t = x.clamp(0.0, 1.0).toDouble();
    return t * t * (3.0 - 2.0 * t);
  }

  static void _drawSoftRadialOval(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color color,
    required double alpha,
  }) {
    if (width <= 1.0 || height <= 1.0 || alpha <= 0.005) {
      return;
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, height / width);
    final r = width * 0.5;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = Gradient.radial(
          Offset.zero,
          r,
          [
            color.withValues(alpha: alpha.clamp(0.0, 1.0).toDouble()),
            color.withValues(alpha: (alpha * 0.36).clamp(0.0, 1.0).toDouble()),
            color.withValues(alpha: 0.0),
          ],
          const [0.0, 0.54, 1.0],
        ),
    );
    canvas.restore();
  }

  Paint _valleyPaintFor(Image vFloor) {
    if (!identical(_cachedValleyImg, vFloor) || _cachedValleyPaint == null) {
      _cachedValleyImg = vFloor;
      _cachedValleyPaint = Paint()
        ..shader = ImageShader(
          vFloor,
          TileMode.repeated,
          TileMode.repeated,
          _identityMatrix4,
          filterQuality: FilterQuality.medium,
        );
    }
    return _cachedValleyPaint!;
  }

  Paint _stripPaintFor(Image strip) {
    if (!identical(_cachedStripImg, strip) || _cachedStripPaint == null) {
      _cachedStripImg = strip;
      _cachedStripPaint = Paint()
        ..shader = ImageShader(
          strip,
          TileMode.clamp,
          TileMode.repeated,
          _identityMatrix4,
          filterQuality: FilterQuality.medium,
        );
    }
    return _cachedStripPaint!;
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

  GameWorld get _world => game.currentWorld;

  Color get _worldLightColor {
    switch (_world) {
      case GameWorld.duskHollow:
        return const Color(0xFFFFD494);
      case GameWorld.moonveilMarsh:
        return const Color(0xFF82F8E8);
      case GameWorld.emberfallCanyon:
        return const Color(0xFFFFC66C);
    }
  }

  Color get _horizonFogColor {
    switch (_world) {
      case GameWorld.duskHollow:
        return const Color(0xFFD68E9E);
      case GameWorld.moonveilMarsh:
        return const Color(0xFF2E8A98);
      case GameWorld.emberfallCanyon:
        return const Color(0xFFE89E5A);
    }
  }

  double get _skyParallaxX {
    final laneCenter = (GameConfig.laneCount - 1) / 2;
    return (game.cameraLane - laneCenter) * -GameConfig.cameraSwayPerLane +
        game.roadCurveFactor * size.x * 0.06;
  }

  /// `0.0` during normal play -> `1.0` as an Abyssal Portal approaches so the
  /// old horizon dissolves into pure cosmic end-of-world void behind the gate!
  double get _abyssBlend {
    final cutoff = game.activePortalCutoffDepth;
    if (cutoff == null) {
      return 0.0;
    }
    return _smoothstep01((1.20 - cutoff) / 0.78);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) {
      return;
    }

    _renderSkyDomeAndCelestialOrb(canvas, w, h);
    _renderParallax3DSkyClouds(canvas, w);
    _renderMountainRidgesAndSkyCitadels(canvas, w, h);
    _renderHighSkyIslandsAndWaterfalls(canvas, w, h);
    _renderFullWidth3DValleyFloor(canvas, w, h);
    _renderCosmicAbyssBehindPortal(canvas, w, h);
    _renderStreaming3DValleyCorridors(canvas, w, h);
    _renderDriftingValleyMist(canvas, w, h);
    _render3DExtrudedStoneCauseway(canvas, w, h);
    _renderBridgeCurbPropsAndShadows(canvas, w, h);
    _renderFloatingFireflyMotes(canvas, h);
    _renderTitleDepthOfFieldAndPortalVeil(canvas, w, h);
    _renderDimensionalBreachSpectacle(canvas, w, h);
    _renderSolarFlightStreaks(canvas, w, h);
  }

  // ---------------------------------------------------------------
  // 1. Sky Atmosphere Dome + Twinkling Stars + Celestial Moon / Sun
  // ---------------------------------------------------------------

  void _renderSkyDomeAndCelestialOrb(Canvas canvas, double w, double h) {
    final backdrop = game.worldBackdrop;
    final horizonY = game.horizonY;
    if (backdrop != null) {
      final imgW = backdrop.width.toDouble();
      final imgH = backdrop.height.toDouble();
      final horizonFrac = GameConfig.backdropHorizonFractionFor(_world);
      final minScale = (horizonY + 8) / math.max(1.0, imgH * horizonFrac);
      final scale = math.max(math.max(w / imgW, h / imgH), minScale) * 1.06;
      final dx = (w - imgW * scale) / 2 + _skyParallaxX * 0.45;
      final dy = (horizonY - imgH * horizonFrac * scale)
          .clamp(math.min(0.0, h - imgH * scale), 0.0)
          .toDouble();
      canvas.drawImageRect(
        backdrop,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(dx, dy, imgW * scale, imgH * scale),
        Paint()..filterQuality = FilterQuality.low,
      );
    } else {
      _renderPlaceholderBackdrop(canvas, w, h);
    }

    if (_world != GameWorld.emberfallCanyon) {
      final starAlphaBase = _world == GameWorld.moonveilMarsh ? 0.65 : 0.40;
      for (var i = 0; i < 34; i++) {
        final sx = ((i * 0.371 + 0.11) % 1.0) * w + _skyParallaxX * 0.25;
        final sy = ((i * 0.619 + 0.04) % 1.0) * horizonY * 0.72;
        final twinkle =
            0.45 + 0.55 * math.sin(game.ambientSeconds * 2.1 + i * 1.7);
        canvas.drawCircle(
          Offset(sx % w, sy),
          (i % 3 == 0) ? 1.7 : 1.1,
          Paint()
            ..color = const Color(0xFFFFFBE8)
                .withValues(alpha: starAlphaBase * twinkle),
        );
      }
    }

    final skyVis = (1.0 - _abyssBlend * 0.90).clamp(0.0, 1.0).toDouble();
    if (skyVis <= 0.02) {
      return;
    }

    final titleBlend = game.introCameraBlend;
    final double cx;
    final double cy;
    final double radius;
    final Color coreCol;
    final Color haloCol;
    switch (_world) {
      case GameWorld.moonveilMarsh:
        cx = w * (0.56 + 0.14 * titleBlend) + _skyParallaxX * 0.55;
        cy = horizonY * (0.34 - 0.08 * titleBlend);
        radius = w * 0.145;
        coreCol = const Color(0xFFD8FFFA);
        haloCol = const Color(0xFF4EF2E6);
      case GameWorld.duskHollow:
        cx = w * (0.60 + 0.16 * titleBlend) + _skyParallaxX * 0.55;
        cy = horizonY * (0.56 - 0.28 * titleBlend);
        radius = w * (0.056 + 0.046 * titleBlend);
        coreCol = const Color(0xFFFFF4D2);
        haloCol = const Color(0xFFFF9868);
      case GameWorld.emberfallCanyon:
        cx = w * (0.56 + 0.16 * titleBlend) + _skyParallaxX * 0.55;
        cy = horizonY * (0.54 - 0.26 * titleBlend);
        radius = w * (0.078 + 0.036 * titleBlend);
        coreCol = const Color(0xFFFFF6CE);
        haloCol = const Color(0xFFFF9A42);
    }

    final bloomR = radius * 3.2;
    canvas.drawCircle(
      Offset(cx, cy),
      bloomR,
      Paint()
        ..shader = Gradient.radial(
          Offset(cx, cy),
          bloomR,
          [
            haloCol.withValues(alpha: 0.46 * skyVis),
            haloCol.withValues(alpha: 0.16 * skyVis),
            haloCol.withValues(alpha: 0.0),
          ],
          const [0.0, 0.48, 1.0],
        ),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..shader = Gradient.radial(
          Offset(cx - radius * 0.22, cy - radius * 0.22),
          radius * 1.25,
          [
            coreCol.withValues(alpha: skyVis),
            haloCol.withValues(alpha: 0.92 * skyVis),
          ],
        ),
    );

    if (_world == GameWorld.moonveilMarsh) {
      final craterPaint = Paint()
        ..color = const Color(0x28248A8A).withValues(alpha: 0.16 * skyVis);
      canvas.drawCircle(
          Offset(cx - radius * 0.28, cy - radius * 0.12), radius * 0.24, craterPaint);
      canvas.drawCircle(
          Offset(cx + radius * 0.24, cy + radius * 0.20), radius * 0.19, craterPaint);
      canvas.drawCircle(
          Offset(cx + radius * 0.10, cy - radius * 0.34), radius * 0.13, craterPaint);
    }
  }

  // ---------------------------------------------------------------
  // 2. Multi-Layer Volumetric 3D Sky Cloud Elements
  // ---------------------------------------------------------------

  void _renderParallax3DSkyClouds(Canvas canvas, double w) {
    final cloud = game.skyCloud;
    final skyVis = (1.0 - _abyssBlend * 0.92).clamp(0.0, 1.0).toDouble();
    if (cloud == null || skyVis <= 0.02) {
      return;
    }
    final horizonY = game.horizonY;
    final aspect = cloud.height / cloud.width;
    final Color tintCol;
    final double tintAmt;
    switch (_world) {
      case GameWorld.moonveilMarsh:
        tintCol = const Color(0xFF22768A);
        tintAmt = 0.58;
      case GameWorld.duskHollow:
        tintCol = const Color(0xFFC87498);
        tintAmt = 0.48;
      case GameWorld.emberfallCanyon:
        tintCol = const Color(0xFFE49252);
        tintAmt = 0.50;
    }

    const specs = [
      (0.12, 0.78, 0.66, 0.010, 0.52, false),
      (0.78, 0.72, 0.70, 0.013, 0.56, true),
      (0.46, 0.86, 0.76, 0.008, 0.44, false),
      (0.22, 0.52, 0.60, 0.016, 0.60, true),
      (0.82, 0.48, 0.64, 0.018, 0.62, false),
      (0.50, 0.36, 0.54, 0.014, 0.54, false),
      (0.16, 0.24, 0.56, 0.021, 0.70, true),
      (0.86, 0.20, 0.60, 0.024, 0.74, false),
    ];

    final src =
        Rect.fromLTWH(0, 0, cloud.width.toDouble(), cloud.height.toDouble());
    for (final s in specs) {
      final cw = w * s.$3;
      final ch = cw * aspect;
      final spanW = w + cw * 1.3;
      final rawX = ((s.$1 * spanW +
                  game.ambientSeconds * w * s.$4 +
                  _skyParallaxX * 0.7) %
              spanW) -
          cw * 0.65;
      final cy = horizonY * s.$2;

      canvas.save();
      canvas.translate(rawX + cw / 2, cy);
      if (s.$6) {
        canvas.scale(-1.0, 1.0);
      }
      canvas.drawImageRect(
        cloud,
        src,
        Rect.fromCenter(center: Offset.zero, width: cw, height: ch),
        Paint()
          ..color =
              Color.fromARGB((s.$5 * skyVis * 255).round(), 255, 255, 255)
          ..colorFilter = ColorFilter.mode(
            tintCol.withValues(alpha: tintAmt),
            BlendMode.srcATop,
          )
          ..filterQuality = FilterQuality.low,
      );
      canvas.restore();
    }
  }

  // ---------------------------------------------------------------
  // 3. Spire Mountain Ridges & Pop-Free 3D Sky Citadel Castle Islands
  // ---------------------------------------------------------------

  void _renderMountainRidgesAndSkyCitadels(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    final skyVis = (1.0 - _abyssBlend * 0.96).clamp(0.0, 1.0).toDouble();
    if (horizonY <= 0 || skyVis <= 0.02) {
      return;
    }

    final fogCol = _horizonFogColor;
    final Color farPeak;
    final Color midPeak;
    final Color nearPeak;
    switch (_world) {
      case GameWorld.moonveilMarsh:
        farPeak = const Color(0xFF1F6E7E);
        midPeak = const Color(0xFF155160);
        nearPeak = const Color(0xFF0E3946);
      case GameWorld.duskHollow:
        farPeak = const Color(0xFF8C529E);
        midPeak = const Color(0xFF643B80);
        nearPeak = const Color(0xFF452862);
      case GameWorld.emberfallCanyon:
        farPeak = const Color(0xFFC86C42);
        midPeak = const Color(0xFF96482E);
        nearPeak = const Color(0xFF6C3020);
    }

    // Soft celestial horizon scatter glow behind the mountain silhouettes!
    final glowTop = horizonY - horizonY * 0.34;
    canvas.drawRect(
      Rect.fromLTWH(0, glowTop, w, horizonY - glowTop + 8),
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.5, glowTop),
          Offset(w * 0.5, horizonY + 8),
          [
            _worldLightColor.withValues(alpha: 0.0),
            _worldLightColor.withValues(alpha: 0.24 * skyVis),
            fogCol.withValues(alpha: 0.42 * skyVis),
          ],
          const [0.0, 0.62, 1.0],
        ),
    );

    final bridgeHorizonX = game.trackCenterXForDepth(1.0);
    final peakColors = [farPeak, midPeak, nearPeak];
    final amps = [0.27, 0.19, 0.12];
    final parallaxFactors = [0.65, 1.05, 1.45];
    final peakAlphas = [0.68, 0.82, 0.94];

    for (var layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(-12, horizonY + 10);
      final amp = horizonY * amps[layer];
      final phaseShift =
          _skyParallaxX * parallaxFactors[layer] / math.max(1.0, w);
      const segs = 48;
      for (var i = 0; i <= segs; i++) {
        final fx = i / segs;
        final x = -12 + (w + 24) * fx;
        final u = fx + phaseShift;
        double rawWave;
        if (_world == GameWorld.emberfallCanyon) {
          // Stepped flat-top sandstone canyon mesas & buttes!
          final baseSlope =
              (math.sin(u * 8.2 + layer * 2.1) * 0.5 + 0.5) * 0.72 +
                  (math.sin(u * 19.0 + layer * 1.3) * 0.5 + 0.5) * 0.28;
          rawWave = (baseSlope * 5.0).floorToDouble() / 5.0 * 0.68 +
              baseSlope * 0.32;
        } else if (_world == GameWorld.moonveilMarsh) {
          // Slender sanctuary spires & misty karst crags!
          rawWave = (math.sin(u * 9.0 + layer * 2.4) * 0.5 + 0.5) * 0.52 +
              math.pow(math.sin(u * 27.0 + layer * 1.7).abs(), 2.4) * 0.48;
        } else {
          // Soaring twilight crystalline peaks!
          rawWave = (math.sin(u * 8.8 + layer * 2.2) * 0.5 + 0.5) * 0.58 +
              math.pow(math.sin(u * 21.0 + layer * 1.5).abs(), 1.7) * 0.42;
        }
        final distToGap = (x - bridgeHorizonX) / (w * 0.22);
        final valleyNotch = 1.0 - 0.78 * math.exp(-distToGap * distToGap);
        path.lineTo(x, horizonY + 3 - amp * rawWave * valleyNotch);
      }
      path
        ..lineTo(w + 12, horizonY + 10)
        ..close();

      final topY = horizonY - amp;
      final pCol = peakColors[layer];
      final pAlpha = peakAlphas[layer] * skyVis;
      canvas.drawPath(
        path,
        Paint()
          ..shader = Gradient.linear(
            Offset(w * 0.5, topY),
            Offset(w * 0.5, horizonY + 8),
            [
              pCol.withValues(alpha: pAlpha),
              fogCol.withValues(alpha: (pAlpha * 0.92).clamp(0.0, 1.0).toDouble()),
            ],
          ),
      );
    }

    final citadel = game.skyCitadel;
    if (citadel == null) {
      return;
    }
    final aspect = citadel.height / citadel.width;
    final src =
        Rect.fromLTWH(0, 0, citadel.width.toDouble(), citadel.height.toDouble());
    final titleBlend = game.introCameraBlend;
    final portalCap = game.activePortalCutoffDepth;

    const count = 8;
    const span = 1.88;
    const step = span / count;
    final scroll = (game.travelled * 0.30) / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;

    for (var k = 0; k < count; k++) {
      final depth = 1.28 - (phase + k * step);
      if (depth > 1.28 || depth < -0.56) {
        continue;
      }
      if (portalCap != null && depth > portalCap - 0.04) {
        continue;
      }
      final slotId = slotBase - k;
      final mod3 = slotId.abs() % 3;
      final side = (mod3 == 1) ? -1.0 : (mod3 == 2 ? 1.0 : 0.42);
      final sc = game.perspectiveFactor(depth);
      final horizonFade = _smoothstep01((1.28 - depth) / 0.36);
      final nearFade =
          depth < -0.24 ? _smoothstep01((depth + 0.54) / 0.30) : 1.0;
      final fade = (horizonFade * nearFade * skyVis).clamp(0.0, 1.0).toDouble();
      if (fade <= 0.01) {
        continue;
      }

      final fogAmt = (depth * 0.44).clamp(0.06, 0.54).toDouble();
      final bob =
          math.sin(game.ambientSeconds * 1.15 + slotId * 2.1) * h * 0.008 * sc;

      final cw = w * (0.78 + 0.10 * titleBlend) * sc;
      final ch = cw * aspect;
      final lateralSpread =
          (mod3 == 0) ? w * (0.15 + 0.14 * sc) : w * (0.24 + 0.22 * sc);
      final chaseCx =
          game.trackCenterXForDepth(depth.clamp(0.0, 1.28).toDouble()) +
              (side >= 0 ? 1.0 : -1.0) * lateralSpread;
      final titleSlotX = (k == 1)
          ? w * 0.62
          : (k == 2 ? w * 0.88 : (side < 0 ? w * 0.16 : w * 0.74));
      final titleSlotY = (k == 1) ? horizonY * 0.42 : horizonY * 0.54;
      final altBoost = (mod3 == 0) ? 0.09 : 0.04;
      final chaseCy = horizonY - h * (altBoost + 0.17 * sc) + bob;

      final cx = chaseCx * (1.0 - titleBlend) +
          (titleSlotX + _skyParallaxX * 0.5) * titleBlend;
      final cy = chaseCy * (1.0 - titleBlend) + (titleSlotY + bob) * titleBlend;

      if (cx + cw * 0.55 < -16 ||
          cx - cw * 0.55 > w + 16 ||
          cy + ch * 0.55 < -16) {
        continue;
      }

      canvas.save();
      canvas.translate(cx, cy);
      if (side > 0) {
        canvas.scale(-1.0, 1.0);
      }
      canvas.drawImageRect(
        citadel,
        src,
        Rect.fromCenter(center: Offset.zero, width: cw, height: ch),
        Paint()
          ..color = Color.fromARGB((fade * 255).round(), 255, 255, 255)
          ..colorFilter = ColorFilter.mode(
            fogCol.withValues(alpha: fogAmt),
            BlendMode.srcATop,
          )
          ..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }
  }

  // ---------------------------------------------------------------
  // 3B. Pop-Free High-Sky Floating Island Archipelago & Blur-Free Waterfalls
  // ---------------------------------------------------------------

  void _renderHighSkyIslandsAndWaterfalls(
    Canvas canvas,
    double w,
    double h,
  ) {
    final island = game.floatingIsland;
    final horizonY = game.horizonY;
    final skyVis = (1.0 - _abyssBlend * 0.96).clamp(0.0, 1.0).toDouble();
    if (island == null || horizonY <= 0 || skyVis <= 0.02) {
      return;
    }

    final aspect = island.height / island.width;
    final fogCol = _horizonFogColor;
    final isMarsh = _world == GameWorld.moonveilMarsh;
    final isEmber = _world == GameWorld.emberfallCanyon;
    final fallTopCol = isEmber
        ? const Color(0xFFFFD878)
        : (isMarsh ? const Color(0xFF74FFF4) : const Color(0xFF6CF2FF));
    final fallMidCol = isEmber
        ? const Color(0xFFFF8836)
        : (isMarsh ? const Color(0xFF2ED8E8) : const Color(0xFF3CC8F8));
    final portalCap = game.activePortalCutoffDepth;

    const slotCount = 10;
    const span = 1.92;
    const step = span / slotCount;
    final scroll = (game.travelled * 0.52) / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;

    for (var k = 0; k < slotCount; k++) {
      final depth = 1.26 - (phase + k * step);
      if (depth > 1.26 || depth < -0.60) {
        continue;
      }
      if (portalCap != null && depth > portalCap - 0.04) {
        continue;
      }
      final worldSlot = slotBase - k;
      final side = worldSlot.isEven ? -1.0 : 1.0;
      final sc = game.perspectiveFactor(depth);
      final horizonFade = _smoothstep01((1.26 - depth) / 0.34);
      final nearFade =
          depth < -0.24 ? _smoothstep01((depth + 0.56) / 0.32) : 1.0;
      final fade = (horizonFade * nearFade * skyVis).clamp(0.0, 1.0).toDouble();
      if (fade <= 0.01) {
        continue;
      }
      final fogAmt = (depth * 0.46).clamp(0.05, 0.54).toDouble();

      final bob = math.sin(game.ambientSeconds * 1.4 + worldSlot * 1.9) *
          h *
          0.009 *
          sc;
      final tier = (worldSlot.abs() % 3);
      final lateralFrac = 0.24 + tier * 0.10 + 0.16 * sc;
      final skyLiftFrac = 0.05 + tier * 0.065 + 0.13 * sc;

      final cx =
          game.trackCenterXForDepth(depth.clamp(0.0, 1.26).toDouble()) +
              side * w * lateralFrac;
      final bottomY = horizonY - h * skyLiftFrac + bob;
      final iw = w * (0.42 + (tier == 1 ? 0.08 : 0.0)) * sc;
      final ih = iw * aspect;

      if (cx + iw * 0.60 < -16 ||
          cx - iw * 0.60 > w + 16 ||
          bottomY + ih * 1.1 < -16) {
        continue;
      }

      if (worldSlot.abs() % 2 == 0) {
        final fallH = ih * 1.25;
        final fallWTop = iw * 0.095;
        final fallWBot = iw * 0.18;
        final fallX = cx - side * iw * 0.06;
        final fallStartY = bottomY - ih * 0.24;
        final shimmer =
            0.82 + 0.18 * math.sin(game.ambientSeconds * 7.5 + worldSlot);

        final fallPath = Path()
          ..moveTo(fallX - fallWTop * 0.5, fallStartY)
          ..lineTo(fallX + fallWTop * 0.5, fallStartY)
          ..lineTo(fallX + fallWBot * 0.5, fallStartY + fallH)
          ..lineTo(fallX - fallWBot * 0.5, fallStartY + fallH)
          ..close();
        canvas.drawPath(
          fallPath,
          Paint()
            ..shader = Gradient.linear(
              Offset(fallX, fallStartY),
              Offset(fallX, fallStartY + fallH),
              [
                fallTopCol.withValues(alpha: 0.62 * fade * shimmer),
                fallMidCol.withValues(alpha: 0.30 * fade * shimmer),
                fallMidCol.withValues(alpha: 0.0),
              ],
              const [0.0, 0.54, 1.0],
            ),
        );
        _drawSoftRadialOval(
          canvas,
          center: Offset(fallX, fallStartY + fallH * 0.78),
          width: fallWBot * 2.8,
          height: fallWBot * 2.4,
          color: fallTopCol,
          alpha: 0.28 * fade * shimmer,
        );
      }

      _drawFoggedElement(
        canvas,
        island,
        cx: cx,
        bottomY: bottomY,
        dw: iw,
        dh: ih,
        flipX: side > 0,
        alpha: fade,
        fogColor: fogCol,
        fogAmount: fogAmt,
      );
    }
  }

  // ---------------------------------------------------------------
  // 4. Full-Width `1/Z` Valley Floor + Stage 3 Cosmic Abyssal Void!
  // ---------------------------------------------------------------

  void _renderFullWidth3DValleyFloor(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final maxD = game.activeRoadMaxDepth;
    final topValleyY =
        maxD < 0.995 ? game.valleyYForDepth(maxD).clamp(horizonY, h) : horizonY;
    if (h <= topValleyY + 2) {
      return;
    }

    final vFloor = game.valleyFloor;
    final fogCol = _horizonFogColor;

    if (vFloor == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, topValleyY.toDouble(), w, h - topValleyY),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, topValleyY.toDouble()),
            Offset(0, h),
            [
              fogCol,
              Color(GameConfig.trackFillArgbFor(_world) | 0xFF000000),
            ],
          ),
      );
      return;
    }

    final texW = vFloor.width.toDouble();
    final texH = vFloor.height.toDouble();
    const pFar = GameConfig.farScale;
    final playerValleyY = game.valleyYForDepth(0.0);
    final spanValley = math.max(1.0, playerValleyY - horizonY);
    final tTop = ((topValleyY - horizonY) / spanValley).clamp(0.0, 2.5).toDouble();
    final tBottom = (h - horizonY) / spanValley;

    final scrollV =
        (game.travelled / GameConfig.trackLength) * GameConfig.valleyTileRepeats;
    final driftU = math.sin(game.ambientSeconds * 0.45) * 0.08;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    var idx = 0;
    for (var r = 0; r <= _valRows; r++) {
      final rf = r / _valRows;
      final curved = rf * rf * 0.45 + rf * 0.55;
      final t = tTop + (tBottom - tTop) * curved;
      final y = horizonY + spanValley * t;
      final p = (pFar + t * (1.0 - pFar)).clamp(0.085, 6.25).toDouble();
      final z = 1.0 / p;
      final depth = (z - 1.0) / (GameConfig.farDepthRatio - 1.0);
      final distFromHorizon = 1.0 - depth;
      final vCoord =
          (distFromHorizon * GameConfig.valleyTileRepeats - (scrollV % 1.0)) *
              texH;

      final cxRow =
          game.trackCenterXForDepth(depth.clamp(0.0, 1.25).toDouble());
      final unitWorldPx = math.max(1.0, halfPlayer * p);

      for (var c = 0; c <= _valCols; c++) {
        final sx = w * (c / _valCols);
        final worldX = (sx - cxRow) / unitWorldPx;
        _valPos[idx] = sx;
        _valPos[idx + 1] = y;
        _valTex[idx] = (worldX * 0.36 + driftU) * texW;
        _valTex[idx + 1] = vCoord;
        idx += 2;
      }
    }

    final vertices = Vertices.raw(
      VertexMode.triangles,
      _valPos,
      textureCoordinates: _valTex,
      indices: _valIdx,
    );
    canvas.drawVertices(
      vertices,
      BlendMode.srcOver,
      _valleyPaintFor(vFloor),
    );

    // Seamless volumetric horizon mist cushion (only when road extends to horizon!)
    if (_abyssBlend < 0.98) {
      final mistVis = (1.0 - _abyssBlend).clamp(0.0, 1.0).toDouble();
      final mistAbove = h * 0.045;
      final mistBelow = (h - horizonY) * 0.28;
      canvas.drawRect(
        Rect.fromLTWH(0, horizonY - mistAbove, w, mistAbove + mistBelow),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, horizonY - mistAbove),
            Offset(0, horizonY + mistBelow),
            [
              fogCol.withValues(alpha: 0.0),
              fogCol.withValues(alpha: 0.88 * mistVis),
              fogCol.withValues(alpha: 0.38 * mistVis),
              fogCol.withValues(alpha: 0.0),
            ],
            const [0.0, 0.28, 0.62, 1.0],
          ),
      );
    }
  }

  /// Renders the pure Cosmic Dimensional Void behind an Abyssal Portal
  /// ("پشتش هیچی نباشد") — everything beyond the terminated cliff lip (`cutoff`)
  /// dissolves into deep astral space with rising gravity-defying embers!
  void _renderCosmicAbyssBehindPortal(Canvas canvas, double w, double h) {
    final cutoff = game.activePortalCutoffDepth;
    final abyss = _abyssBlend;
    if (cutoff == null || abyss <= 0.01) {
      return;
    }

    final lipY = game.yForDepth(cutoff.clamp(0.02, 1.0).toDouble());
    final voidBottomY = (lipY + h * 0.14).clamp(0.0, h).toDouble();

    // 1. Deep astral void enveloping everything behind the broken world lip!
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, voidBottomY),
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.5, 0),
          Offset(w * 0.5, voidBottomY),
          [
            const Color(0xFF060312).withValues(alpha: 0.96 * abyss),
            const Color(0xFF130A2E).withValues(alpha: 0.94 * abyss),
            const Color(0xFF1B1040).withValues(alpha: 0.86 * abyss),
            const Color(0x001B1040),
          ],
          const [0.0, 0.52, 0.82, 1.0],
        ),
    );

    // 2. Swirling astral nebula glow centered behind the Portal Gateway!
    final portalCx = game.trackCenterXForDepth(cutoff.clamp(0.0, 1.0).toDouble());
    final nebCenter = Offset(portalCx, (lipY - h * 0.14).clamp(h * 0.18, h * 0.72));
    final nebR = w * 0.68;
    canvas.drawCircle(
      nebCenter,
      nebR,
      Paint()
        ..shader = Gradient.radial(
          nebCenter,
          nebR,
          [
            const Color(0xFF4CEEFF).withValues(alpha: 0.24 * abyss),
            const Color(0xFF7B3FE4).withValues(alpha: 0.22 * abyss),
            const Color(0x00090418),
          ],
          const [0.0, 0.50, 1.0],
        ),
    );

    // 3. Cosmic stars & upward-floating anti-gravity shards in the void!
    final t = game.ambientSeconds;
    for (var i = 0; i < 42; i++) {
      final sx = ((i * 0.317 + 0.09) % 1.0) * w;
      final rise = ((i * 0.531 + t * (0.04 + (i % 3) * 0.018)) % 1.0);
      final sy = voidBottomY * (1.0 - rise);
      final tw = 0.45 + 0.55 * math.sin(t * 3.1 + i * 2.3);
      final col = (i % 3 == 0)
          ? const Color(0xFF88F8FF)
          : (i % 3 == 1 ? const Color(0xFFFFE29A) : const Color(0xFFFFFFFF));
      canvas.drawCircle(
        Offset(sx, sy),
        (i % 4 == 0) ? 2.1 : 1.3,
        Paint()..color = col.withValues(alpha: 0.82 * tw * abyss),
      );
    }
  }

  // ---------------------------------------------------------------
  // 5. Pop-Free 16-Slot Asymmetric 3D Cliff Terraces (Clipped at Portal!)
  // ---------------------------------------------------------------

  void _renderStreaming3DValleyCorridors(Canvas canvas, double w, double h) {
    if (h <= game.horizonY) {
      return;
    }
    final canyon = game.canyonWall;
    final island = game.floatingIsland;
    final viaduct = game.viaductRuin;
    if (canyon == null && island == null && viaduct == null) {
      return;
    }

    final fogCol = _horizonFogColor;
    final lightCol = _worldLightColor;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;
    final isMarsh = _world == GameWorld.moonveilMarsh;
    final maxSceneD = game.activeRoadMaxDepth;
    final hasPortalCap = game.activePortalCutoffDepth != null;

    const slotCount = 16;
    const span = 1.96;
    const step = span / slotCount;
    final scroll = game.travelled / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;

    for (var k = 0; k < slotCount; k++) {
      final distH = phase + k * step;
      final depth = 1.24 - distH;
      if (depth > 1.24 || depth < -0.72) {
        continue;
      }
      // NOTHING exists behind the Abyssal Portal or ahead of the unfurling road!
      if ((hasPortalCap || game.isPortalWarping) && depth > maxSceneD - 0.03) {
        continue;
      }

      final worldSlot = slotBase - k;
      final sc = game.perspectiveFactor(depth);
      final hw = halfPlayer * sc;
      final cx = game.trackCenterXForDepth(depth.clamp(0.0, 1.24).toDouble());
      final ybDeck = game.yForDepth(depth);
      final yVal = game.valleyYForDepth(depth);

      final horizonFade = _smoothstep01((1.24 - depth) / 0.34);
      final portalEdgeFade = (hasPortalCap || game.isPortalWarping)
          ? _smoothstep01((maxSceneD - depth) / 0.14)
          : 1.0;
      final nearFade =
          depth < -0.34 ? _smoothstep01((depth + 0.68) / 0.34) : 1.0;
      final fade =
          (horizonFade * portalEdgeFade * nearFade).clamp(0.0, 1.0).toDouble();
      if (fade <= 0.01) {
        continue;
      }
      final fogAmt = (depth * 0.50).clamp(0.0, 0.56).toDouble();

      if (canyon != null) {
        final cw = w * 0.88 * sc;
        final ch = cw * (canyon.height / canyon.width);

        if (worldSlot.isEven) {
          final outerX = cx - hw * 2.42;
          final outerBotY = ybDeck + ch * 0.18;
          final outerDh = ch * 1.12;
          final outerDw = cw * 1.06;
          if (outerBotY - outerDh <= h + 24 && outerX + outerDw * 0.55 >= -20) {
            _drawFoggedElement(
              canvas,
              canyon,
              cx: outerX,
              bottomY: outerBotY,
              dw: outerDw,
              dh: outerDh,
              flipX: true,
              alpha: fade * 0.92,
              fogColor: fogCol,
              fogAmount: (fogAmt + 0.12).clamp(0.0, 0.66).toDouble(),
            );
          }
        }

        final leftX = cx - hw * (worldSlot.isEven ? 1.50 : 1.76);
        final leftBottomY = ybDeck + ch * 0.34;

        if (leftBottomY - ch <= h + 24 && leftX + cw * 0.55 >= -20) {
          final cyanCol =
              isMarsh ? const Color(0xFF42FAEA) : const Color(0xFF38ECFF);
          _drawSoftRadialOval(
            canvas,
            center: Offset(leftX + cw * 0.20, ybDeck - ch * 0.08),
            width: cw * 0.92,
            height: cw * 0.22,
            color: cyanCol,
            alpha: 0.34 * fade,
          );

          _drawFoggedElement(
            canvas,
            canyon,
            cx: leftX,
            bottomY: leftBottomY,
            dw: cw,
            dh: ch,
            flipX: false,
            alpha: fade,
            fogColor: fogCol,
            fogAmount: fogAmt,
          );
        }

        if (isMarsh && worldSlot.isOdd) {
          final rightBankX = cx + hw * 1.54;
          final rightBotY = ybDeck + ch * 0.36;
          if (rightBotY - ch * 0.96 <= h + 24 &&
              rightBankX - cw * 0.52 <= w + 20) {
            _drawSoftRadialOval(
              canvas,
              center: Offset(rightBankX - cw * 0.18, yVal),
              width: cw * 0.98,
              height: cw * 0.26,
              color: const Color(0xFF3EF6EA),
              alpha: 0.38 * fade,
            );
            _drawFoggedElement(
              canvas,
              canyon,
              cx: rightBankX,
              bottomY: rightBotY,
              dw: cw * 0.96,
              dh: ch * 0.96,
              flipX: true,
              alpha: fade,
              fogColor: fogCol,
              fogAmount: fogAmt,
            );
          }
        } else if (!isMarsh && worldSlot.abs() % 3 == 2) {
          final rightX = cx + hw * 2.38;
          final rightBotY = ybDeck + ch * 0.24;
          if (rightBotY - ch * 1.04 <= h + 24 &&
              rightX - cw * 0.52 <= w + 20) {
            _drawFoggedElement(
              canvas,
              canyon,
              cx: rightX,
              bottomY: rightBotY,
              dw: cw * 0.96,
              dh: ch * 1.04,
              flipX: true,
              alpha: fade * 0.90,
              fogColor: fogCol,
              fogAmount: (fogAmt + 0.10).clamp(0.0, 0.64).toDouble(),
            );
          }
        }
      }

      final useViaduct = (worldSlot.abs() % 3 == 1) && viaduct != null;
      if (useViaduct) {
        final vw = w * 0.66 * sc;
        final vh = vw * (viaduct.height / viaduct.width);
        final px = cx + hw * 1.56;
        final py = yVal + vh * 0.06;

        if (py - vh <= h + 24 && px - vw * 0.55 <= w + 20) {
          _drawFoggedElement(
            canvas,
            viaduct,
            cx: px,
            bottomY: py,
            dw: vw,
            dh: vh,
            flipX: true,
            alpha: fade,
            fogColor: fogCol,
            fogAmount: fogAmt * 0.88,
          );
        }
      }

      if (island != null) {
        final bob = math.sin(game.ambientSeconds * 1.5 + worldSlot * 1.7) *
            h *
            0.009 *
            sc;
        final iw = w * (useViaduct ? 0.44 : 0.58) * sc;
        final ih = iw * (island.height / island.width);
        final highFloat = worldSlot.isEven || useViaduct;
        final px = cx + hw * (useViaduct ? 2.18 : (highFloat ? 1.80 : 1.44));
        final py = (highFloat ? ybDeck - ih * 0.14 : yVal + ih * 0.08) - bob;

        if (py - ih <= h + 24 && px - iw * 0.55 <= w + 20) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(px, yVal + ih * 0.02),
              width: iw * 0.72,
              height: iw * 0.14,
            ),
            Paint()..color = lightCol.withValues(alpha: 0.15 * fade),
          );

          _drawFoggedElement(
            canvas,
            island,
            cx: px,
            bottomY: py,
            dw: iw,
            dh: ih,
            flipX: true,
            alpha: fade,
            fogColor: fogCol,
            fogAmount: fogAmt * 0.84,
          );
        }
      }
    }
  }

  void _drawFoggedElement(
    Canvas canvas,
    Image img, {
    required double cx,
    required double bottomY,
    required double dw,
    required double dh,
    required bool flipX,
    required double alpha,
    required Color fogColor,
    required double fogAmount,
  }) {
    final paint = Paint()
      ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
      ..filterQuality = FilterQuality.medium;
    if (fogAmount > 0.01) {
      paint.colorFilter = ColorFilter.mode(
        fogColor.withValues(alpha: fogAmount.clamp(0.0, 0.85).toDouble()),
        BlendMode.srcATop,
      );
    }

    canvas.save();
    canvas.translate(cx, bottomY - dh / 2);
    if (flipX) {
      canvas.scale(-1.0, 1.0);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: dw, height: dh),
      paint,
    );
    canvas.restore();
  }

  void _renderDriftingValleyMist(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    final mistVis = (1.0 - _abyssBlend).clamp(0.0, 1.0).toDouble();
    if (h <= horizonY || mistVis <= 0.02) {
      return;
    }
    final mistCol = _worldLightColor;
    final t = game.ambientSeconds * 0.25;
    for (var i = 0; i < 3; i++) {
      final yFrac = horizonY + (h - horizonY) * (0.18 + i * 0.26);
      final driftX = math.sin(t + i * 2.1) * w * 0.14;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5 + driftX, yFrac),
          width: w * 1.30,
          height: h * 0.11,
        ),
        Paint()..color = mistCol.withValues(alpha: 0.068 * mistVis),
      );
    }
  }

  // ---------------------------------------------------------------
  // 6. Wide 3D Stone Causeway + Abyssal Termination Lip / Unfurl Crest!
  // ---------------------------------------------------------------

  void _render3DExtrudedStoneCauseway(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    final blend = game.introCameraBlend;
    if (h <= horizonY || blend > 0.96) {
      return;
    }

    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final depthBottom = game.depthForScreenY(h);
    final maxD = game.activeRoadMaxDepth;
    if (maxD <= depthBottom + 0.02) {
      return;
    }
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    // A) Under-bridge shadow (terminates cleanly at `maxD`!)
    final shadowPath = Path();
    const sideSteps = 16;
    for (var i = 0; i <= sideSteps; i++) {
      final d = maxD - (i / sideSteps) * (maxD - depthBottom);
      final sc = game.perspectiveFactor(d);
      final cx = game.trackCenterXForDepth(d);
      final yv = game.valleyYForDepth(d);
      final hw = halfPlayer * sc * 1.16;
      if (i == 0) {
        shadowPath.moveTo(cx - hw, yv);
      } else {
        shadowPath.lineTo(cx - hw, yv);
      }
    }
    for (var i = sideSteps; i >= 0; i--) {
      final d = maxD - (i / sideSteps) * (maxD - depthBottom);
      final sc = game.perspectiveFactor(d);
      final cx = game.trackCenterXForDepth(d);
      final yv = game.valleyYForDepth(d);
      final hw = halfPlayer * sc * 1.16;
      shadowPath.lineTo(cx + hw, yv);
    }
    shadowPath.close();
    canvas.drawPath(shadowPath, Paint()..color = const Color(0x5A080E18));

    // A2) Sculpted 3D Abyssal Broken Cliff Face under the terminated road lip!
    if (game.activePortalCutoffDepth != null && maxD < 0.995) {
      _renderAbyssalRoadCliffFace(canvas, w, h, maxD, halfPlayer);
    }

    // B) 12x48 Flagstone Slab Deck (`track_strip.png`) clamped cleanly to `maxD`!
    final strip = game.trackStrip;
    if (strip != null) {
      _renderStripMesh(
        canvas,
        strip,
        horizonY: horizonY,
        h: h,
        spanToPlayer: spanToPlayer,
        halfPlayer: halfPlayer,
        maxD: maxD,
      );
    } else {
      final cxTop = game.trackCenterXForDepth(maxD);
      final cxBot = game.trackCenterXForDepth(depthBottom);
      final yTop = game.yForDepth(maxD);
      final halfTop = halfPlayer * game.perspectiveFactor(maxD);
      final halfBot = halfPlayer * game.perspectiveFactor(depthBottom);
      final fallback = Path()
        ..moveTo(cxTop - halfTop, yTop)
        ..lineTo(cxTop + halfTop, yTop)
        ..lineTo(cxBot + halfBot, h)
        ..lineTo(cxBot - halfBot, h)
        ..close();
      canvas.drawPath(
        fallback,
        Paint()..color = Color(GameConfig.trackFillArgbFor(_world) | 0xFF000000),
      );
    }

    // C) Extruded Stone Parapets & Curbs terminating cleanly at `maxD`!
    _render3DExtrudedCurbs(canvas, w, h, depthBottom, maxD, halfPlayer);

    // D) Leading Edge Feature:
    //  * Unfurling New-World Prismatic Construction Wave (`isPortalWarping`);
    //  * OR Normal Celestial Horizon Ring when road extends to `1.0`!
    if (game.isPortalWarping && maxD < 0.995) {
      _renderUnfurlingRoadCrestWave(canvas, w, maxD, halfPlayer);
    } else if (maxD >= 0.995) {
      final crestX = game.trackCenterXForDepth(1.0);
      final crestY = game.yForDepth(1.0);
      final ringR = w * 0.036;
      final lightCol = _worldLightColor;

      canvas.drawCircle(
        Offset(crestX, crestY - ringR * 0.35),
        ringR * 3.0,
        Paint()
          ..shader = Gradient.radial(
            Offset(crestX, crestY - ringR * 0.35),
            ringR * 3.0,
            [
              lightCol.withValues(alpha: 0.44),
              _horizonFogColor.withValues(alpha: 0.18),
              _horizonFogColor.withValues(alpha: 0.0),
            ],
            const [0.0, 0.50, 1.0],
          ),
      );
      canvas.drawCircle(
        Offset(crestX, crestY - ringR * 0.45),
        ringR * 0.72,
        Paint()
          ..color = lightCol.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  /// Draws the dramatic broken stone cliff-face & levitating rock shards where
  /// the current world's causeway terminates at the Abyssal Portal!
  void _renderAbyssalRoadCliffFace(
    Canvas canvas,
    double w,
    double h,
    double maxD,
    double halfPlayer,
  ) {
    final sc = game.perspectiveFactor(maxD);
    final cx = game.trackCenterXForDepth(maxD);
    final yLip = game.yForDepth(maxD);
    final hw = halfPlayer * sc * 1.06;
    final cliffDropH = h * 0.14 * sc;

    final face = Path()
      ..moveTo(cx - hw, yLip)
      ..lineTo(cx + hw, yLip)
      ..lineTo(cx + hw * 0.88, yLip + cliffDropH)
      ..lineTo(cx + hw * 0.38, yLip + cliffDropH * 1.28)
      ..lineTo(cx - hw * 0.10, yLip + cliffDropH * 0.96)
      ..lineTo(cx - hw * 0.52, yLip + cliffDropH * 1.32)
      ..lineTo(cx - hw * 0.90, yLip + cliffDropH * 0.92)
      ..close();
    canvas.drawPath(
      face,
      Paint()
        ..shader = Gradient.linear(
          Offset(cx, yLip),
          Offset(cx, yLip + cliffDropH * 1.32),
          const [
            Color(0xFF3E2E64),
            Color(0xFF1A1034),
            Color(0x000A051A),
          ],
          const [0.0, 0.58, 1.0],
        ),
    );

    // Levitating shattered stone fragments & rising cyan/gold rift sparks!
    final t = game.ambientSeconds;
    for (var i = 0; i < 9; i++) {
      final frac = -1.15 + (i / 8.0) * 2.30;
      final bob = math.sin(t * 2.6 + i * 1.7) * h * 0.018 * sc;
      final sx = cx + hw * frac;
      final sy = yLip - h * (0.015 + (i % 3) * 0.026) * sc + bob;
      final rw = (w * (0.022 + (i % 2) * 0.012) * sc).clamp(2.5, 22.0).toDouble();

      final shard = Path()
        ..moveTo(sx, sy - rw * 0.9)
        ..lineTo(sx + rw * 0.75, sy)
        ..lineTo(sx, sy + rw * 0.85)
        ..lineTo(sx - rw * 0.75, sy)
        ..close();
      canvas.drawPath(shard, Paint()..color = const Color(0xDD4B3A76));
      canvas.drawPath(
        shard,
        Paint()
          ..color = const Color(0xAA68F4FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  /// Blazing golden-cyan dimensional wave leading the unfurling new-world road!
  void _renderUnfurlingRoadCrestWave(
    Canvas canvas,
    double w,
    double maxD,
    double halfPlayer,
  ) {
    final sc = game.perspectiveFactor(maxD);
    final cx = game.trackCenterXForDepth(maxD);
    final yEdge = game.yForDepth(maxD);
    final hw = halfPlayer * sc * 1.15;

    _drawSoftRadialOval(
      canvas,
      center: Offset(cx, yEdge),
      width: hw * 2.5,
      height: (w * 0.14 * sc).clamp(10.0, 64.0).toDouble(),
      color: const Color(0xFF7AF8FF),
      alpha: 0.78,
    );
    canvas.drawLine(
      Offset(cx - hw, yEdge),
      Offset(cx + hw, yEdge),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = (4.2 * sc).clamp(2.0, 6.5).toDouble()
        ..strokeCap = StrokeCap.round,
    );
  }

  void _render3DExtrudedCurbs(
    Canvas canvas,
    double w,
    double h,
    double depthBottom,
    double maxD,
    double halfPlayer,
  ) {
    final isMarsh = _world == GameWorld.moonveilMarsh;
    final Color curbTop;
    final Color curbInner;
    final Color curbOuter;
    final Color jointCol;
    final Color runeGlow;
    final Color mossCol;
    switch (_world) {
      case GameWorld.duskHollow:
        curbTop = const Color(0xFFA696C4);
        curbInner = const Color(0xFF524472);
        curbOuter = const Color(0xFF2E2248);
        jointCol = const Color(0xAA32264C);
        runeGlow = const Color(0xFF4CF6FF);
        mossCol = const Color(0xFF567A52);
      case GameWorld.moonveilMarsh:
        curbTop = const Color(0xFF5A909C);
        curbInner = const Color(0xFF244E58);
        curbOuter = const Color(0xFF122C36);
        jointCol = const Color(0xAA16343E);
        runeGlow = const Color(0xFF58FFF2);
        mossCol = const Color(0xFF3E7850);
      case GameWorld.emberfallCanyon:
        curbTop = const Color(0xFFDEA66E);
        curbInner = const Color(0xFF804E30);
        curbOuter = const Color(0xFF4C2A1A);
        jointCol = const Color(0xAA5A321E);
        runeGlow = const Color(0xFFFFCE5C);
        mossCol = const Color(0xFF7A6838);
    }

    const segs = 28;
    final extBottom = depthBottom - 0.08;
    final dSpan = maxD - extBottom;
    if (dSpan <= 0.01) {
      return;
    }
    final scrollBlocks =
        (game.travelled / GameConfig.trackLength) * GameConfig.trackTileRepeats * 6.0;

    final pOuter = Paint()..color = curbOuter;
    final pInner = Paint()..color = curbInner;
    final pTop = Paint()..color = curbTop;

    for (final side in const [-1.0, 1.0]) {
      final isOpenCliffEdge = (side > 0) && !isMarsh;
      final curbWFactor = isOpenCliffEdge ? 0.024 : 0.052;
      final curbHFactor = isOpenCliffEdge ? 0.008 : 0.032;
      final dropFactor = isOpenCliffEdge ? 0.095 : 0.055;

      final pathOuter = Path();
      final pathInner = Path();
      final pathTop = Path();

      for (var i = 0; i <= segs; i++) {
        final d = maxD - (i / segs) * dSpan;
        final sc = game.perspectiveFactor(d);
        final cx = game.trackCenterXForDepth(d);
        final yb = game.yForDepth(d);
        final hw = halfPlayer * sc;
        final cw = w * curbWFactor * sc;
        final ch = w * curbHFactor * sc;

        final inX = cx + side * hw;
        final outX = cx + side * (hw + cw);
        if (i == 0) {
          pathInner.moveTo(inX, yb);
          pathTop.moveTo(inX, yb - ch);
          pathOuter.moveTo(outX, yb - ch);
        } else {
          pathInner.lineTo(inX, yb);
          pathTop.lineTo(inX, yb - ch);
          pathOuter.lineTo(outX, yb - ch);
        }
      }

      for (var i = segs; i >= 0; i--) {
        final d = maxD - (i / segs) * dSpan;
        final sc = game.perspectiveFactor(d);
        final cx = game.trackCenterXForDepth(d);
        final yb = game.yForDepth(d);
        final hw = halfPlayer * sc;
        final cw = w * curbWFactor * sc;
        final ch = w * curbHFactor * sc;
        final drop = h * dropFactor * sc;

        final inX = cx + side * hw;
        final outX = cx + side * (hw + cw);
        pathInner.lineTo(inX, yb - ch);
        pathTop.lineTo(outX, yb - ch);
        pathOuter.lineTo(outX, yb + drop);
      }
      pathOuter.close();
      pathInner.close();
      pathTop.close();

      canvas.drawPath(pathOuter, pOuter);
      canvas.drawPath(pathInner, pInner);
      canvas.drawPath(pathTop, pTop);

      const blockCount = 13;
      final phase = scrollBlocks % 1.0;
      for (var b = 0; b < blockCount; b++) {
        final distH = (b + phase) / blockCount * 1.30;
        final d = 1.0 - distH;
        if (d > maxD - 0.015 || d < extBottom) {
          continue;
        }
        final sc = game.perspectiveFactor(d);
        final cx = game.trackCenterXForDepth(d);
        final yb = game.yForDepth(d);
        if (yb > h + 28) {
          continue;
        }
        final hw = halfPlayer * sc;
        final cw = w * curbWFactor * sc;
        final ch = w * curbHFactor * sc;
        final fade = _smoothstep01((1.0 - d) / 0.22);

        final inX = cx + side * hw;
        final outX = cx + side * (hw + cw);
        canvas.drawLine(
          Offset(inX, yb - ch),
          Offset(outX, yb - ch),
          Paint()
            ..color = jointCol.withValues(alpha: 0.72 * fade)
            ..strokeWidth = (1.9 * sc).clamp(0.8, 3.0).toDouble(),
        );

        final worldBlock = (scrollBlocks.floor() - b).abs();
        if (worldBlock % 3 == 0) {
          final mr = (6.0 * sc).clamp(1.8, 9.5).toDouble();
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(inX - side * mr * 0.25, yb + 1.0 * sc),
              width: mr * 1.6,
              height: mr * 2.8,
            ),
            Paint()..color = mossCol.withValues(alpha: 0.62 * fade),
          );
        }

        if ((worldBlock + (side > 0 ? 1 : 0)) % 2 == 0) {
          final rGlow = (6.8 * sc).clamp(2.0, 11.0).toDouble();
          _drawSoftRadialOval(
            canvas,
            center: Offset(inX - side * rGlow * 0.45, yb + 1.5 * sc),
            width: rGlow * 2.6,
            height: rGlow * 4.0,
            color: runeGlow,
            alpha: 0.62 * fade,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(inX - side * rGlow * 0.18, yb + 1.0 * sc),
              width: rGlow * 0.65,
              height: rGlow * 1.7,
            ),
            Paint()
              ..color = const Color(0xFFEFFFFF).withValues(alpha: 0.88 * fade),
          );
        }
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
    required double maxD,
  }) {
    final stripW = strip.width.toDouble();
    final stripH = strip.height.toDouble();
    const pFar = GameConfig.farScale;
    final pTop = game.perspectiveFactor(maxD);
    final tBottom = (h - horizonY) / spanToPlayer;
    final pBot = pFar + tBottom * (1.0 - pFar);
    final scroll =
        (game.travelled / GameConfig.trackLength) * GameConfig.trackTileRepeats;

    var idx = 0;
    for (var r = 0; r <= _meshRows; r++) {
      final rowFrac = r / _meshRows;
      final p = pTop + rowFrac * (pBot - pTop);
      final z = 1.0 / p;
      final depth = (z - 1.0) / (GameConfig.farDepthRatio - 1.0);
      final t = (p - pFar) / (1.0 - pFar);
      final y = horizonY + spanToPlayer * t - game.archLiftForDepth(depth);
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
    canvas.drawVertices(
      vertices,
      BlendMode.srcOver,
      _stripPaintFor(strip),
    );

    final depthBot = game.depthForScreenY(h);
    final cxTop = game.trackCenterXForDepth(maxD);
    final cxBot = game.trackCenterXForDepth(depthBot);
    final yTop = game.yForDepth(maxD);
    final hwTop = halfPlayer * pTop;
    final hwBot = halfPlayer * game.perspectiveFactor(depthBot);

    final sheenPath = Path()
      ..moveTo(cxTop - hwTop * 0.55, yTop)
      ..lineTo(cxTop + hwTop * 0.25, yTop)
      ..lineTo(cxBot + hwBot * 0.25, h)
      ..lineTo(cxBot - hwBot * 0.55, h)
      ..close();
    canvas.drawPath(
      sheenPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(cxTop, yTop),
          Offset(cxBot, h),
          [
            const Color(0x28B8CCFF),
            const Color(0x1898B4F8),
            const Color(0x08809CE8),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    if (_world != GameWorld.moonveilMarsh) {
      final rightShade = Path()
        ..moveTo(cxTop + hwTop * 0.36, yTop)
        ..lineTo(cxTop + hwTop, yTop)
        ..lineTo(cxBot + hwBot, h)
        ..lineTo(cxBot + hwBot * 0.42, h)
        ..close();
      canvas.drawPath(
        rightShade,
        Paint()..color = const Color(0x28181030),
      );
    }

    _renderEmbeddedCausewayRunes(canvas, halfPlayer, h, maxD);

    // Distance atmospheric haze only when road reaches the far horizon
    if (maxD >= 0.995 && _abyssBlend < 0.95) {
      final hazeVis = (1.0 - _abyssBlend).clamp(0.0, 1.0).toDouble();
      final fogCol = _horizonFogColor;
      final cxMid = game.trackCenterXForDepth(0.64);
      final hwMid = halfPlayer * game.perspectiveFactor(0.64) * 1.15;
      final yMid = game.yForDepth(0.64);
      final hazePath = Path()
        ..moveTo(cxTop - hwTop * 1.18, horizonY - 3)
        ..lineTo(cxTop + hwTop * 1.18, horizonY - 3)
        ..lineTo(cxMid + hwMid, yMid)
        ..lineTo(cxMid - hwMid, yMid)
        ..close();
      canvas.drawPath(
        hazePath,
        Paint()
          ..shader = Gradient.linear(
            Offset(cxTop, horizonY),
            Offset(cxMid, yMid),
            [
              fogCol.withValues(alpha: 0.78 * hazeVis),
              fogCol.withValues(alpha: 0.0),
            ],
          ),
      );
    }
  }

  void _renderEmbeddedCausewayRunes(
    Canvas canvas,
    double halfPlayer,
    double screenH,
    double maxD,
  ) {
    final runeCol = Color(GameConfig.trackLaneArgbFor(_world));
    const runeSlots = 9;
    const span = 1.36;
    const step = span / runeSlots;
    final scroll = (game.travelled / GameConfig.trackLength) * 1.35;
    final phase = scroll % step;
    final slotBase = (scroll / step).floor();

    for (var k = 0; k < runeSlots; k++) {
      final d = 1.02 - (phase + k * step);
      if (d > maxD - 0.035 || d < -0.34) {
        continue;
      }
      final dTip = (d + 0.028).clamp(-0.34, maxD - 0.005).toDouble();
      final sc = game.perspectiveFactor(d);
      final scTip = game.perspectiveFactor(dTip);
      final yBase = game.yForDepth(d);
      final yTip = game.yForDepth(dTip);
      if (yTip > screenH + 16) {
        continue;
      }
      final fade = _smoothstep01((0.98 - d) / 0.24);

      final worldIdx = (slotBase - k).abs();
      final lane = worldIdx % GameConfig.laneCount;
      final xBase = game.laneXForDepth(lane.toDouble(), d);
      final xTip = game.laneXForDepth(lane.toDouble(), dTip);
      final wSpan = halfPlayer * sc * 0.18;
      final wTip = halfPlayer * scTip * 0.04;

      final chevron = Path()
        ..moveTo(xBase - wSpan, yBase)
        ..lineTo(xTip - wTip, yTip)
        ..lineTo(xTip + wTip, yTip)
        ..lineTo(xBase + wSpan, yBase)
        ..lineTo(xBase + wSpan * 0.52, yBase)
        ..lineTo(xTip, yTip + (yBase - yTip) * 0.35)
        ..lineTo(xBase - wSpan * 0.52, yBase)
        ..close();

      canvas.drawPath(
        chevron,
        Paint()..color = runeCol.withValues(alpha: 0.28 * fade),
      );
    }
  }

  // ---------------------------------------------------------------
  // 7. Curb-Mounted 3D Lanterns & Crystal Shrines (Terminated at Portal!)
  // ---------------------------------------------------------------

  void _renderBridgeCurbPropsAndShadows(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY || game.introCameraBlend > 0.94) {
      return;
    }
    final pillar = game.corridorPillar;
    final cliff = game.cliffSide;
    final auraColor = Color(GameConfig.lanternAuraArgbFor(_world));
    final fogCol = _horizonFogColor;
    final isMarsh = _world == GameWorld.moonveilMarsh;
    final maxD = game.activeRoadMaxDepth;
    final hasCap = game.activePortalCutoffDepth != null || game.isPortalWarping;

    const slotCount = 14;
    const depthSpan = 1.72;
    const step = depthSpan / slotCount;
    final scroll = game.travelled / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    for (var k = 0; k < slotCount; k++) {
      final distH = phase + k * step;
      final depth = 1.18 - distH;
      if (depth > 1.18 || depth < -0.54) {
        continue;
      }
      // Strictly terminate curb props at the Portal threshold!
      if (hasCap && depth > maxD - 0.025) {
        continue;
      }

      final sc = game.perspectiveFactor(depth);
      final ybDeck = game.yForDepth(depth);
      final cx = game.trackCenterXForDepth(depth.clamp(0.0, 1.18).toDouble());
      final hw = halfPlayer * sc;

      final horizonFade = _smoothstep01((1.18 - depth) / 0.30);
      final capFade = hasCap ? _smoothstep01((maxD - depth) / 0.12) : 1.0;
      final nearFade =
          depth < -0.26 ? _smoothstep01((depth + 0.52) / 0.26) : 1.0;
      final fade = (horizonFade * capFade * nearFade).clamp(0.0, 1.0).toDouble();
      if (fade <= 0.01) {
        continue;
      }
      final fogAmt = (depth * 0.42).clamp(0.0, 0.46).toDouble();
      final worldSlot = slotBase - k;

      for (final side in const [-1.0, 1.0]) {
        if (!isMarsh && side > 0 && (worldSlot.abs() % 2 != 1)) {
          continue;
        }

        final useLantern = isMarsh
            ? (worldSlot.abs() % 3 != 2 || cliff == null)
            : (side < 0
                    ? (worldSlot.abs() % 2 == 0)
                    : (worldSlot.abs() % 4 == 3)) ||
                cliff == null;
        final curbCenterX = cx + side * (hw + w * 0.020 * sc);
        final ybCurb = ybDeck - w * (side < 0 || isMarsh ? 0.024 : 0.006) * sc;

        if (useLantern) {
          final pw = w * (isMarsh ? 0.135 : 0.145) * sc;
          final aspect = pillar != null ? pillar.height / pillar.width : 1.75;
          final ph = pw * aspect;

          if (ybCurb - ph > h + 24 ||
              curbCenterX + pw < -20 ||
              curbCenterX - pw > w + 20) {
            continue;
          }

          _drawSoftRadialOval(
            canvas,
            center: Offset(curbCenterX - side * pw * 0.34, ybDeck + 2 * sc),
            width: pw * 1.55,
            height: pw * 0.46,
            color: auraColor,
            alpha: 0.36 * fade,
          );

          if (pillar != null) {
            _drawFoggedElement(
              canvas,
              pillar,
              cx: curbCenterX,
              bottomY: ybCurb + ph * 0.04,
              dw: pw,
              dh: ph,
              flipX: false,
              alpha: fade,
              fogColor: fogCol,
              fogAmount: fogAmt,
            );
          }
        } else {
          final cw = w * 0.205 * sc;
          final ch = cw * (cliff.height / cliff.width);

          if (ybCurb - ch > h + 24 ||
              curbCenterX + cw < -20 ||
              curbCenterX - cw > w + 20) {
            continue;
          }

          final shadowPoly = Path()
            ..moveTo(curbCenterX - cw * 0.35, ybDeck)
            ..lineTo(curbCenterX + cw * 0.25, ybDeck)
            ..lineTo(curbCenterX - cw * 1.05, ybDeck + cw * 0.34)
            ..lineTo(curbCenterX - cw * 1.45, ybDeck + cw * 0.24)
            ..close();
          canvas.drawPath(
            shadowPoly,
            Paint()
              ..shader = Gradient.linear(
                Offset(curbCenterX, ybDeck),
                Offset(curbCenterX - cw * 1.25, ybDeck + cw * 0.30),
                [
                  const Color(0x68140C28).withValues(alpha: 0.46 * fade),
                  const Color(0x00140C28),
                ],
              ),
          );

          _drawFoggedElement(
            canvas,
            cliff,
            cx: curbCenterX,
            bottomY: ybCurb + ch * 0.06,
            dw: cw,
            dh: ch,
            flipX: side > 0,
            alpha: fade,
            fogColor: fogCol,
            fogAmount: fogAmt,
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------
  // 8. Fireflies, Title DoF & Stage 3 Dimensional Breach Spectacle!
  // ---------------------------------------------------------------

  void _renderFloatingFireflyMotes(Canvas canvas, double h) {
    const count = GameConfig.ambientParticleCount;
    if (count <= 0) {
      return;
    }
    final glowCol = _worldLightColor;
    final scroll = game.travelled / GameConfig.trackLength;
    final t = game.ambientSeconds;
    final maxD = game.activeRoadMaxDepth;

    for (var i = 0; i < count; i++) {
      final seed = i * 0.6180339887;
      final depth = 1.12 - ((scroll * 0.45 + seed) % 1.38);
      if (depth > maxD || depth < -0.26) {
        continue;
      }
      final sc = game.perspectiveFactor(depth);
      final laneOffset = math.sin(seed * 19.3 + t * 0.55) * 2.55;
      final mx = game.laneXForDepth(1.0 + laneOffset, depth);
      final floatH = (0.12 + 0.55 * ((seed * 7.13) % 1.0)) +
          math.sin(t * 1.3 + i) * 0.08;
      final my = game.yForDepth(depth) - h * 0.20 * floatH * sc;
      if (my > h + 16 || my < -16) {
        continue;
      }
      final pulse = 0.55 + 0.45 * math.sin(t * 2.4 + i * 1.7);
      final hFade = _smoothstep01((1.12 - depth) / 0.26);
      final nFade = depth < -0.10 ? _smoothstep01((depth + 0.26) / 0.16) : 1.0;
      final fade = hFade * nFade * pulse;
      final r = (3.5 * sc).clamp(1.2, 5.5).toDouble();

      canvas.drawCircle(
        Offset(mx, my),
        r * 2.3,
        Paint()..color = glowCol.withValues(alpha: 0.26 * fade),
      );
      canvas.drawCircle(
        Offset(mx, my),
        r * 0.75,
        Paint()
          ..color = const Color(0xFFFFFCE8).withValues(alpha: 0.84 * fade),
      );
    }
  }

  void _renderTitleDepthOfFieldAndPortalVeil(
    Canvas canvas,
    double w,
    double h,
  ) {
    final titleBlend = game.introCameraBlend;
    if (titleBlend > 0.02) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, h * 0.35),
            Offset(0, h),
            [
              const Color(0x00281844),
              _horizonFogColor.withValues(alpha: 0.16 * titleBlend),
              const Color(0xFF1A1032).withValues(alpha: 0.42 * titleBlend),
            ],
            const [0.0, 0.58, 1.0],
          ),
      );
    }

    // Approach pull lines when racing toward the Abyssal Portal (`cutoff < 0.45`)!
    final cutoff = game.activePortalCutoffDepth;
    if (cutoff != null && cutoff < 0.48) {
      final pull = ((0.48 - cutoff) / 0.46).clamp(0.0, 1.0).toDouble();
      final cx = game.trackCenterXForDepth(cutoff);
      final cy = game.yForDepth(cutoff) - h * 0.12 * game.perspectiveFactor(cutoff);
      for (var i = 0; i < 16; i++) {
        final ang = i * (math.pi * 2 / 16) + game.ambientSeconds * 0.7;
        final rOuter = w * (0.95 - 0.30 * ((game.ambientSeconds * 1.8 + i * 0.13) % 1.0));
        final rInner = rOuter - w * 0.16 * pull;
        canvas.drawLine(
          Offset(cx + math.cos(ang) * rOuter, cy + math.sin(ang) * rOuter),
          Offset(cx + math.cos(ang) * rInner, cy + math.sin(ang) * rInner),
          Paint()
            ..color = const Color(0xFFA8FAFF).withValues(alpha: 0.42 * pull)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  /// Stage 3 Sensational `1.35s` Dimensional Breach Spectacle:
  ///  * Prismatic radial flash bloom;
  ///  * 3 expanding shockwave rings (white-gold, electric-cyan, violet);
  ///  * 28 high-velocity hyperspace tunnel rays;
  ///  * 16 tumbling crystal prism shards shattering outward!
  void _renderDimensionalBreachSpectacle(
    Canvas canvas,
    double w,
    double h,
  ) {
    if (!game.isPortalWarping) {
      return;
    }
    final u = game.portalWarpProgress;
    if (u < 0.0 || u >= 1.0) {
      return;
    }

    final center = Offset(w * 0.50, h * 0.52);
    final maxDiag = math.sqrt(w * w + h * h);
    final lightCol = _worldLightColor;

    // 1. Crisp initial dimensional flash peaking at `u = 0.05` and melting fast
    final flashEnv = u < 0.06
        ? (u / 0.06)
        : math.pow(1.0 - ((u - 0.06) / 0.94).clamp(0.0, 1.0), 2.4).toDouble();
    if (flashEnv > 0.01) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = Gradient.radial(
            center,
            maxDiag * 0.70,
            [
              const Color(0xFFFFFFFF).withValues(alpha: 0.56 * flashEnv),
              lightCol.withValues(alpha: 0.38 * flashEnv),
              const Color(0x00000000),
            ],
            const [0.0, 0.48, 1.0],
          ),
      );
    }

    // 2. 3 Expanding Concentric Prismatic Shockwave Rings!
    const ringSpecs = [
      (0.00, 0.62, Color(0xFFFFFFFF), 6.5),
      (0.07, 0.74, Color(0xFF64F8FF), 4.8),
      (0.15, 0.86, Color(0xFFFFCA62), 3.6),
    ];
    for (final rs in ringSpecs) {
      final ru = ((u - rs.$1) / (rs.$2 - rs.$1)).clamp(0.0, 1.0).toDouble();
      if (ru <= 0.0 || ru >= 1.0) {
        continue;
      }
      final ease = 1.0 - (1.0 - ru) * (1.0 - ru);
      final rad = maxDiag * 0.78 * ease;
      final fade = (1.0 - ru) * (1.0 - ru);
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..color = rs.$3.withValues(alpha: 0.82 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (rs.$4 * (1.0 - ru * 0.6)).clamp(1.2, 8.0).toDouble(),
      );
    }

    // 3. 28 High-Speed Radial Hyperspace Tunnel Light Rays!
    if (u < 0.78) {
      final warpEnv = math.sin((u / 0.78) * math.pi);
      for (var i = 0; i < 28; i++) {
        final ang = i * (math.pi * 2 / 28) + 0.11;
        final speedMul = 0.75 + (i % 4) * 0.22;
        final prog = ((u * 2.1 * speedMul + i * 0.17) % 1.0);
        final r0 = w * (0.18 + 0.75 * prog);
        final r1 = r0 + w * (0.14 + 0.18 * prog);
        final col = (i % 3 == 0)
            ? const Color(0xFF78FAFF)
            : (i % 3 == 1 ? const Color(0xFFFFEEAA) : lightCol);
        canvas.drawLine(
          Offset(center.dx + math.cos(ang) * r0, center.dy + math.sin(ang) * r0),
          Offset(center.dx + math.cos(ang) * r1, center.dy + math.sin(ang) * r1),
          Paint()
            ..color = col.withValues(alpha: 0.68 * warpEnv * (1.0 - prog * 0.5))
            ..strokeWidth = (i % 3 == 0) ? 2.8 : 1.9
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // 4. 16 Shattering Faceted Crystal Prism Shards Tumbling Outward!
    if (u < 0.64) {
      final su = (u / 0.64).clamp(0.0, 1.0).toDouble();
      final ease = 1.0 - math.pow(1.0 - su, 2.2).toDouble();
      final fade = (1.0 - su).clamp(0.0, 1.0).toDouble();
      for (var i = 0; i < 16; i++) {
        final ang = i * (math.pi * 2 / 16) + 0.24;
        final dist = w * (0.10 + 0.82 * ease * (0.78 + (i % 3) * 0.16));
        final sx = center.dx + math.cos(ang) * dist;
        final sy = center.dy + math.sin(ang) * dist;
        final spin = u * 9.0 * (i.isEven ? 1.0 : -1.0) + i;
        final sz = w * (0.028 - 0.012 * su);

        canvas.save();
        canvas.translate(sx, sy);
        canvas.rotate(spin);
        final shard = Path()
          ..moveTo(0, -sz * 1.35)
          ..lineTo(sz * 0.72, 0)
          ..lineTo(0, sz * 1.15)
          ..lineTo(-sz * 0.72, 0)
          ..close();
        canvas.drawPath(
          shard,
          Paint()
            ..color = (i.isEven
                    ? const Color(0xDD9AFBFF)
                    : const Color(0xDDFFE89E))
                .withValues(alpha: 0.85 * fade),
        );
        canvas.drawPath(
          shard,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92 * fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
        canvas.restore();
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

  void _renderPlaceholderBackdrop(Canvas canvas, double w, double h) {
    final sky = Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, h),
        const [Color(0xFF3E3068), Color(0xFFD89882), Color(0xFF48386E)],
        const [0.0, 0.38, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);
  }
}
