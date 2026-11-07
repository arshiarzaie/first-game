import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// S20 100% Modular 9-Layer 3D `SOUL: DUSK RUN` World Engine (`TrackScene`).
///
/// Upgraded for the closer, lower over-the-shoulder chase camera (`0.20.0+20`):
///  1. Atmospheric sky dome + twinkling starfield + upper-right Sunset Sun /
///     giant Aquamarine Full Moon;
///  2. Multi-layer volumetric 3D Sky Cloud banks (`sky_cloud.png`);
///  3. Spire mountain ridges + 4-slot `1/Z` 3D Sky Citadel Castle Islands
///     (`sky_citadel.png`);
///  4. Full-width `16×32` `1/Z` 3D Water / Valley Floor Mesh (`valley_floor.png`);
///  5. Rich 10-slot Asymmetric 3D Cliffside & Chasm Corridors: close terraced
///     left cliffs (`canyon_wall.png`) with luminous turquoise cliff-rivers &
///     purple/orange fantasy flora + open sheer right chasm with multi-altitude
///     floating islands (`floating_island.png`) & viaducts (`viaduct_ruin.png`)
///     (plus lush dual-bank enchanted night forest in Moonveil Marsh!);
///  6. Wide `12×48` 3D Flagstone Causeway (`track_strip.png`) with specular sky
///     sheen, chiseled left stone parapet + glowing cyan crystal rune seams,
///     and sheer right cliff-drop stone coping;
///  7. Curb-mounted 3D Crystal Rune Shrines (`cliff_side.png`) & Lanterns
///     (`corridor_pillar.png`) casting diagonal sunset shadows across the slabs;
///  8. Bioluminescent Firefly Spores, Main-Screen DoF veil & Portal Shimmer!
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
    _renderFullWidth3DValleyFloor(canvas, w, h);
    _renderStreaming3DValleyCorridors(canvas, w, h);
    _renderDriftingValleyMist(canvas, w, h);
    _render3DExtrudedStoneCauseway(canvas, w, h);
    _renderBridgeCurbPropsAndShadows(canvas, w, h);
    _renderFloatingFireflyMotes(canvas, h);
    _renderTitleDepthOfFieldAndPortalVeil(canvas, w, h);
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

    // Twinkling celestial stars in the upper twilight/night sky
    if (_world != GameWorld.emberfallCanyon) {
      final starAlphaBase = _world == GameWorld.moonveilMarsh ? 0.62 : 0.36;
      for (var i = 0; i < 22; i++) {
        final sx = ((i * 0.371 + 0.11) % 1.0) * w + _skyParallaxX * 0.25;
        final sy = ((i * 0.619 + 0.04) % 1.0) * horizonY * 0.68;
        final twinkle =
            0.45 + 0.55 * math.sin(game.ambientSeconds * 2.1 + i * 1.7);
        canvas.drawCircle(
          Offset(sx % w, sy),
          (i % 3 == 0) ? 1.6 : 1.0,
          Paint()
            ..color = const Color(0xFFFFFBE8)
                .withValues(alpha: starAlphaBase * twinkle),
        );
      }
    }

    // Volumetric 3D Celestial Body (Upper-right Sunset Sun `06-22-47` / Giant
    // Aquamarine Moon `06-22-29` / Blazing Solar Corona!)
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
            haloCol.withValues(alpha: 0.46),
            haloCol.withValues(alpha: 0.16),
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
          [coreCol, haloCol.withValues(alpha: 0.92)],
        ),
    );

    if (_world == GameWorld.moonveilMarsh) {
      final craterPaint = Paint()..color = const Color(0x28248A8A);
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
    if (cloud == null) {
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
      (0.16, 0.72, 0.68, 0.011, 0.50, false),
      (0.76, 0.66, 0.72, 0.014, 0.54, true),
      (0.46, 0.84, 0.78, 0.008, 0.42, false),
      (0.18, 0.34, 0.58, 0.019, 0.68, true),
      (0.84, 0.28, 0.62, 0.023, 0.72, false),
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
          ..color = Color.fromARGB((s.$5 * 255).round(), 255, 255, 255)
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
  // 3. Spire Mountain Ridges & 4-Slot 3D Sky Citadel Castle Islands
  // ---------------------------------------------------------------

  void _renderMountainRidgesAndSkyCitadels(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (horizonY <= 0) {
      return;
    }

    final Color ridgeFar;
    final Color ridgeNear;
    switch (_world) {
      case GameWorld.moonveilMarsh:
        ridgeFar = const Color(0x88165060);
        ridgeNear = const Color(0xB4103C4A);
      case GameWorld.duskHollow:
        ridgeFar = const Color(0x886A427E);
        ridgeNear = const Color(0xB44C2E66);
      case GameWorld.emberfallCanyon:
        ridgeFar = const Color(0x88944E36);
        ridgeNear = const Color(0xB4703624);
    }

    // Dramatic fantasy spire peaks (`06-22-47.png` & `06-22-12.png`)!
    final bridgeHorizonX = game.trackCenterXForDepth(1.0);
    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(-10, horizonY + 8);
      final amp = horizonY * (layer == 0 ? 0.22 : 0.14);
      final phaseShift =
          _skyParallaxX * (layer == 0 ? 0.8 : 1.3) / math.max(1.0, w);
      const segs = 34;
      for (var i = 0; i <= segs; i++) {
        final fx = i / segs;
        final x = -10 + (w + 20) * fx;
        final u = fx + phaseShift;
        final rawWave = (math.sin(u * 9.5 + layer * 2.3) * 0.5 + 0.5) * 0.65 +
            math.pow(math.sin(u * 23.0 + layer * 1.4).abs(), 1.6) * 0.35;
        final distToGap = (x - bridgeHorizonX) / (w * 0.20);
        final valleyNotch = 1.0 - 0.74 * math.exp(-distToGap * distToGap);
        path.lineTo(x, horizonY + 2 - amp * rawWave * valleyNotch);
      }
      path
        ..lineTo(w + 10, horizonY + 8)
        ..close();
      canvas.drawPath(path, Paint()..color = layer == 0 ? ridgeFar : ridgeNear);
    }

    // High-altitude 3D Sky Citadels (`sky_citadel.png`) — framed prominently in
    // upper-center-right on Main Screen (`06-22-47`) AND streaming in 1/Z depth!
    final citadel = game.skyCitadel;
    if (citadel == null) {
      return;
    }
    final aspect = citadel.height / citadel.width;
    final src =
        Rect.fromLTWH(0, 0, citadel.width.toDouble(), citadel.height.toDouble());
    final fogCol = _horizonFogColor;
    final titleBlend = game.introCameraBlend;

    const count = 4;
    const span = 1.36;
    const step = span / count;
    final scroll = (game.travelled * 0.28) / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;

    for (var k = 0; k < count; k++) {
      final depth = 1.02 - (phase + k * step);
      if (depth > 1.02 || depth < -0.24) {
        continue;
      }
      final slotId = slotBase - k;
      // Bias Sky Citadels toward the panoramic upper-right chasm (`06-22-12`)!
      final side = (slotId.abs() % 3 == 1) ? -1.0 : 1.0;
      final sc = game.perspectiveFactor(depth);
      final fade = ((1.03 - depth) / 0.16).clamp(0.0, 1.0).toDouble();
      final fogAmt = (depth * 0.44).clamp(0.06, 0.50).toDouble();
      final bob =
          math.sin(game.ambientSeconds * 1.15 + slotId * 2.1) * h * 0.008 * sc;

      final cw = w * (0.76 + 0.12 * titleBlend) * sc;
      final ch = cw * aspect;
      final chaseCx =
          game.trackCenterXForDepth(depth.clamp(0.0, 1.0).toDouble()) +
              side * w * (0.20 + 0.16 * sc);
      // On Main Screen (`titleBlend == 1`), anchor primary citadel right in
      // upper-center-right (`06-22-47.png` castle silhouette)!
      final titleSlotX = (k == 1)
          ? w * 0.62
          : (k == 2 ? w * 0.88 : (side < 0 ? w * 0.16 : w * 0.74));
      final titleSlotY = (k == 1) ? horizonY * 0.42 : horizonY * 0.54;
      final chaseCy = horizonY - h * (0.05 + 0.16 * sc) + bob;

      final cx = chaseCx * (1.0 - titleBlend) +
          (titleSlotX + _skyParallaxX * 0.5) * titleBlend;
      final cy = chaseCy * (1.0 - titleBlend) + (titleSlotY + bob) * titleBlend;

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
  // 4. Full-Width `1/Z` Perspective 3D Water / Valley Floor Mesh
  // ---------------------------------------------------------------

  void _renderFullWidth3DValleyFloor(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final vFloor = game.valleyFloor;
    final fogCol = _horizonFogColor;

    if (vFloor == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, horizonY, w, h - horizonY),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, horizonY),
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
    final tBottom = (h - horizonY) / spanValley;

    final scrollV =
        (game.travelled / GameConfig.trackLength) * GameConfig.valleyTileRepeats;
    final driftU = math.sin(game.ambientSeconds * 0.45) * 0.08;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    var idx = 0;
    for (var r = 0; r <= _valRows; r++) {
      final rf = r / _valRows;
      final t = (rf * rf * 0.45 + rf * 0.55) * tBottom;
      final y = horizonY + spanValley * t;
      final p = (pFar + t * (1.0 - pFar)).clamp(0.118, 2.5).toDouble();
      final z = 1.0 / p;
      final depth = (z - 1.0) / (GameConfig.farDepthRatio - 1.0);
      final distFromHorizon = 1.0 - depth;
      final vCoord =
          (distFromHorizon * GameConfig.valleyTileRepeats - (scrollV % 1.0)) *
              texH;

      final cxRow =
          game.trackCenterXForDepth(depth.clamp(0.0, 1.05).toDouble());
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
      Paint()
        ..shader = ImageShader(
          vFloor,
          TileMode.repeated,
          TileMode.repeated,
          _identityMatrix4,
          filterQuality: FilterQuality.medium,
        ),
    );

    final hazeH = (h - horizonY) * 0.22;
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - 2, w, hazeH + 2),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, horizonY),
          Offset(0, horizonY + hazeH),
          [
            fogCol.withValues(alpha: 0.92),
            fogCol.withValues(alpha: 0.36),
            fogCol.withValues(alpha: 0.0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  // ---------------------------------------------------------------
  // 5. Rich 10-Slot Asymmetric 3D Cliff Terraces, Cyan River & Chasm
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

    const slotCount = 10;
    const span = 1.30;
    const step = span / slotCount;
    final scroll = game.travelled / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;

    for (var k = 0; k < slotCount; k++) {
      final distH = phase + k * step;
      final depth = 1.02 - distH;
      if (depth > 1.01 || depth < -0.24) {
        continue;
      }
      final worldSlot = slotBase - k;
      final sc = game.perspectiveFactor(depth);
      final hw = halfPlayer * sc;
      final cx = game.trackCenterXForDepth(depth.clamp(0.0, 1.0).toDouble());
      final ybDeck = game.yForDepth(depth);
      final yVal = game.valleyYForDepth(depth);
      final fade = ((1.02 - depth) / 0.14).clamp(0.0, 1.0).toDouble();
      final fogAmt = (depth * 0.56).clamp(0.0, 0.54).toDouble();

      // A) Close Left Cliffside Terraces + Glowing Turquoise River Shelf
      // (`06-22-12.png` & `06-23-20.png`)!
      if (canyon != null) {
        final cw = w * 0.86 * sc;
        final ch = cw * (canyon.height / canyon.width);
        final leftX = cx - hw * (worldSlot.isEven ? 1.44 : 1.78);
        // Rise high above the bridge parapet so cliffs, pines & purple flora
        // fill the left flank right beside the causeway!
        final leftBottomY = ybDeck + ch * 0.34;

        // Luminous turquoise cliffside waterfall/stream pool (`06-22-12` left!)
        final cyanCol = isMarsh
            ? const Color(0xFF42FAEA)
            : const Color(0xFF38ECFF);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(leftX + cw * 0.20, ybDeck - ch * 0.08),
            width: cw * 0.78,
            height: cw * 0.16,
          ),
          Paint()
            ..color = cyanCol.withValues(alpha: 0.28 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
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

        // In Moonveil Marsh (`06-22-29.png`), lush ancient forest cliffs frame
        // the right bank closely as well over glowing cyan marsh pools!
        if (isMarsh && worldSlot.isOdd) {
          final rightBankX = cx + hw * 1.56;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(rightBankX - cw * 0.18, yVal),
              width: cw * 0.86,
              height: cw * 0.20,
            ),
            Paint()
              ..color = const Color(0xFF3EF6EA).withValues(alpha: 0.32 * fade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0),
          );
          _drawFoggedElement(
            canvas,
            canyon,
            cx: rightBankX,
            bottomY: ybDeck + ch * 0.36,
            dw: cw * 0.94,
            dh: ch * 0.94,
            flipX: true,
            alpha: fade,
            fogColor: fogCol,
            fogAmount: fogAmt,
          );
        }
      }

      // B) Right Open Sheer Chasm: Multi-Altitude Floating Islands & Viaducts!
      final useViaduct = (worldSlot.abs() % 3 == 1) && viaduct != null;
      if (useViaduct) {
        final vw = w * 0.62 * sc;
        final vh = vw * (viaduct.height / viaduct.width);
        final px = cx + hw * 1.58;
        final py = yVal + vh * 0.06;

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
      } else if (island != null) {
        final bob = math.sin(game.ambientSeconds * 1.5 + worldSlot * 1.7) *
            h *
            0.009 *
            sc;
        final iw = w * 0.56 * sc;
        final ih = iw * (island.height / island.width);
        final highFloat = worldSlot.isEven;
        final px = cx + hw * (highFloat ? 1.82 : 1.46);
        final py =
            (highFloat ? ybDeck - ih * 0.08 : yVal + ih * 0.08) - bob;

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px, yVal + ih * 0.02),
            width: iw * 0.72,
            height: iw * 0.14,
          ),
          Paint()..color = lightCol.withValues(alpha: 0.14 * fade),
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
    if (h <= horizonY) {
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
        Paint()..color = mistCol.withValues(alpha: 0.068),
      );
    }
  }

  // ---------------------------------------------------------------
  // 6. Wide 3D Stone Causeway + Left Parapet + Right Cliff Drop-Off
  // ---------------------------------------------------------------

  void _render3DExtrudedStoneCauseway(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    final blend = game.introCameraBlend;
    // On Main Screen (`blend == 1.0`), causeway stays tucked below view while
    // Soul hovers up in the sky (`06-22-47`), rising smoothly during dive!
    if (h <= horizonY || blend > 0.96) {
      return;
    }

    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final depthBottom = game.depthForScreenY(h);
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    // A) Under-bridge shadow & sheer chiseled cliff rock-face under right edge!
    final shadowPath = Path();
    const sideSteps = 16;
    for (var i = 0; i <= sideSteps; i++) {
      final d = 1.0 - (i / sideSteps) * (1.0 - depthBottom);
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
      final d = 1.0 - (i / sideSteps) * (1.0 - depthBottom);
      final sc = game.perspectiveFactor(d);
      final cx = game.trackCenterXForDepth(d);
      final yv = game.valleyYForDepth(d);
      final hw = halfPlayer * sc * 1.16;
      shadowPath.lineTo(cx + hw, yv);
    }
    shadowPath.close();
    canvas.drawPath(shadowPath, Paint()..color = const Color(0x5A080E18));

    // B) 12x48 Flagstone Slab Deck (`track_strip.png`) + Specular Sky Sheen
    final strip = game.trackStrip;
    if (strip != null) {
      _renderStripMesh(
        canvas,
        strip,
        horizonY: horizonY,
        h: h,
        spanToPlayer: spanToPlayer,
        halfPlayer: halfPlayer,
      );
    } else {
      final cxTop = game.trackCenterXForDepth(1.0);
      final cxBot = game.trackCenterXForDepth(depthBottom);
      final halfTop = halfPlayer * GameConfig.farScale;
      final halfBot = halfPlayer * game.perspectiveFactor(depthBottom);
      final fallback = Path()
        ..moveTo(cxTop - halfTop, horizonY)
        ..lineTo(cxTop + halfTop, horizonY)
        ..lineTo(cxBot + halfBot, h)
        ..lineTo(cxBot - halfBot, h)
        ..close();
      canvas.drawPath(
        fallback,
        Paint()..color = Color(GameConfig.trackFillArgbFor(_world) | 0xFF000000),
      );
    }

    // C) Asymmetric Left Stone Parapet + Glowing Cyan Crystal Seams + Right
    //    Sheer Cliff-Drop Coping (`06-22-12.png`, `06-23-20.png`, `06-22-29.png`)!
    _render3DExtrudedCurbs(canvas, w, h, depthBottom, halfPlayer);

    // D) Atmospheric distance glow + Celestial Horizon Ring at bridge crest!
    final crestX = game.trackCenterXForDepth(1.0);
    final crestY = game.yForDepth(1.0);
    final ringR = w * 0.044;
    final lightCol = _worldLightColor;

    canvas.drawCircle(
      Offset(crestX, crestY - ringR * 0.35),
      ringR * 2.8,
      Paint()
        ..shader = Gradient.radial(
          Offset(crestX, crestY - ringR * 0.35),
          ringR * 2.8,
          [
            lightCol.withValues(alpha: 0.42),
            _horizonFogColor.withValues(alpha: 0.18),
            _horizonFogColor.withValues(alpha: 0.0),
          ],
          const [0.0, 0.50, 1.0],
        ),
    );
    canvas.drawCircle(
      Offset(crestX, crestY - ringR * 0.45),
      ringR * 0.68,
      Paint()
        ..color = lightCol.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
  }

  void _render3DExtrudedCurbs(
    Canvas canvas,
    double w,
    double h,
    double depthBottom,
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
    final dSpan = 1.0 - depthBottom;
    final scrollBlocks =
        (game.travelled / GameConfig.trackLength) * GameConfig.trackTileRepeats * 6.0;

    final pOuter = Paint()..color = curbOuter;
    final pInner = Paint()..color = curbInner;
    final pTop = Paint()..color = curbTop;

    for (final side in const [-1.0, 1.0]) {
      // Left side ALWAYS has the tall sculpted stone parapet (`06-22-12.png`).
      // Right side is an open sheer cliff-drop coping in Dusk/Emberfall and a
      // mossy stone curb in Moonveil Marsh (`06-22-29.png`)!
      final isOpenCliffEdge = (side > 0) && !isMarsh;
      final curbWFactor = isOpenCliffEdge ? 0.024 : 0.052;
      final curbHFactor = isOpenCliffEdge ? 0.008 : 0.032;
      final dropFactor = isOpenCliffEdge ? 0.095 : 0.055;

      final pathOuter = Path();
      final pathInner = Path();
      final pathTop = Path();

      for (var i = 0; i <= segs; i++) {
        final d = 1.0 - (i / segs) * dSpan;
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
        final d = 1.0 - (i / segs) * dSpan;
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

      // Chiseled curb stone joints + moss tufts + vivid cyan crystal light pools!
      const blockCount = 11;
      final phase = scrollBlocks % 1.0;
      for (var b = 0; b < blockCount; b++) {
        final distH = (b + phase) / blockCount * 1.16;
        final d = 1.0 - distH;
        if (d > 0.98 || d < depthBottom) {
          continue;
        }
        final sc = game.perspectiveFactor(d);
        final cx = game.trackCenterXForDepth(d);
        final yb = game.yForDepth(d);
        final hw = halfPlayer * sc;
        final cw = w * curbWFactor * sc;
        final ch = w * curbHFactor * sc;
        final fade = ((1.0 - d) / 0.16).clamp(0.0, 1.0).toDouble();

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
        // Lush moss tufts nestled along stone curb seams
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

        // Glowing cyan/turquoise bioluminescent crystal pools along the curb
        // (`06-23-20.png` & `06-22-12.png`!)
        if ((worldBlock + (side > 0 ? 1 : 0)) % 2 == 0) {
          final rGlow = (6.8 * sc).clamp(2.0, 11.0).toDouble();
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(inX - side * rGlow * 0.45, yb + 1.5 * sc),
              width: rGlow * 1.9,
              height: rGlow * 3.1,
            ),
            Paint()
              ..color = runeGlow.withValues(alpha: 0.58 * fade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
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
      final p = pFar + t * (1.0 - pFar);
      final z = 1.0 / p;
      final depth = (z - 1.0) / (GameConfig.farDepthRatio - 1.0);
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
      Paint()
        ..shader = ImageShader(
          strip,
          TileMode.clamp,
          TileMode.repeated,
          _identityMatrix4,
          filterQuality: FilterQuality.medium,
        ),
    );

    // Wet polished flagstone specular sky sheen + right-side sunset shadow band
    // (`06-22-12.png`!)
    final depthBot = game.depthForScreenY(h);
    final cxTop = game.trackCenterXForDepth(1.0);
    final cxBot = game.trackCenterXForDepth(depthBot);
    final hwTop = halfPlayer * GameConfig.farScale;
    final hwBot = halfPlayer * game.perspectiveFactor(depthBot);

    final sheenPath = Path()
      ..moveTo(cxTop - hwTop * 0.55, horizonY)
      ..lineTo(cxTop + hwTop * 0.25, horizonY)
      ..lineTo(cxBot + hwBot * 0.25, h)
      ..lineTo(cxBot - hwBot * 0.55, h)
      ..close();
    canvas.drawPath(
      sheenPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(cxTop, horizonY),
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
        ..moveTo(cxTop + hwTop * 0.36, horizonY)
        ..lineTo(cxTop + hwTop, horizonY)
        ..lineTo(cxBot + hwBot, h)
        ..lineTo(cxBot + hwBot * 0.42, h)
        ..close();
      canvas.drawPath(
        rightShade,
        Paint()..color = const Color(0x28181030),
      );
    }

    // Subtle distance atmospheric haze over the far 12% of the stone causeway
    final fogCol = _horizonFogColor;
    final cxMid = game.trackCenterXForDepth(0.70);
    final hwMid = halfPlayer * game.perspectiveFactor(0.70) * 1.15;
    final yMid = game.yForDepth(0.70);
    final hazePath = Path()
      ..moveTo(cxTop - hwTop * 1.15, horizonY - 2)
      ..lineTo(cxTop + hwTop * 1.15, horizonY - 2)
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
            fogCol.withValues(alpha: 0.72),
            fogCol.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  // ---------------------------------------------------------------
  // 7. Curb-Mounted 3D Lanterns & Crystal Shrines + Diagonal Shadows
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

    const slotCount = 6;
    const depthSpan = 1.18;
    const step = depthSpan / slotCount;
    final scroll = game.travelled / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    for (var k = 0; k < slotCount; k++) {
      final distH = phase + k * step;
      final depth = 1.0 - distH;
      if (depth > 0.98 || depth < -0.16) {
        continue;
      }
      final sc = game.perspectiveFactor(depth);
      final ybDeck = game.yForDepth(depth);
      final cx = game.trackCenterXForDepth(depth);
      final hw = halfPlayer * sc;
      final fade = (distH / 0.14).clamp(0.0, 1.0).toDouble();
      final fogAmt = (depth * 0.42).clamp(0.0, 0.40).toDouble();
      final worldSlot = slotBase - k;

      for (final side in const [-1.0, 1.0]) {
        // On open right cliff edge (`duskHollow`/`emberfall`), place crystalline
        // rune shrines (`cliff_side.png`) every 3rd slot just like `06-22-12.png`!
        if (!isMarsh && side > 0 && (worldSlot.abs() % 3 != 1)) {
          continue;
        }

        final useLantern = isMarsh
            ? true
            : (side < 0 && (worldSlot.abs() % 2 == 0)) || cliff == null;
        final curbCenterX = cx + side * (hw + w * 0.020 * sc);
        final ybCurb = ybDeck - w * (side < 0 || isMarsh ? 0.024 : 0.006) * sc;

        if (useLantern) {
          final pw = w * (isMarsh ? 0.145 : 0.155) * sc;
          final aspect = pillar != null ? pillar.height / pillar.width : 1.75;
          final ph = pw * aspect;

          // Warm golden/cyan lantern pool on the mossy stone slabs (`06-22-29`)!
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(curbCenterX - side * pw * 0.34, ybDeck + 2 * sc),
              width: pw * 1.25,
              height: pw * 0.34,
            ),
            Paint()
              ..color = auraColor.withValues(alpha: 0.30 * fade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
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
          final cw = w * 0.24 * sc;
          final ch = cw * (cliff.height / cliff.width);

          // Long diagonal sunset shadow cast down-left across the flagstones
          // (`06-22-12.png` right crystal monolith shadow!)
          final shadowPoly = Path()
            ..moveTo(curbCenterX - cw * 0.35, ybDeck)
            ..lineTo(curbCenterX + cw * 0.25, ybDeck)
            ..lineTo(curbCenterX - cw * 1.05, ybDeck + cw * 0.34)
            ..lineTo(curbCenterX - cw * 1.45, ybDeck + cw * 0.24)
            ..close();
          canvas.drawPath(
            shadowPoly,
            Paint()
              ..color = const Color(0x68140C28).withValues(alpha: 0.48 * fade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
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
  // 8. Bioluminescent Firefly Spores, Title DoF Veil & Portal Flash
  // ---------------------------------------------------------------

  void _renderFloatingFireflyMotes(Canvas canvas, double h) {
    const count = GameConfig.ambientParticleCount;
    if (count <= 0) {
      return;
    }
    final glowCol = _worldLightColor;
    final scroll = game.travelled / GameConfig.trackLength;
    final t = game.ambientSeconds;

    for (var i = 0; i < count; i++) {
      final seed = i * 0.6180339887;
      final depth = 1.0 - ((scroll * 0.45 + seed) % 1.12);
      if (depth > 0.98 || depth < -0.10) {
        continue;
      }
      final sc = game.perspectiveFactor(depth);
      final laneOffset = math.sin(seed * 19.3 + t * 0.55) * 2.15;
      final mx = game.laneXForDepth(1.0 + laneOffset, depth);
      final floatH = (0.12 + 0.55 * ((seed * 7.13) % 1.0)) +
          math.sin(t * 1.3 + i) * 0.08;
      final my = game.yForDepth(depth) - h * 0.20 * floatH * sc;
      final pulse = 0.55 + 0.45 * math.sin(t * 2.4 + i * 1.7);
      final fade = ((1.0 - depth) / 0.20).clamp(0.0, 1.0).toDouble() * pulse;
      final r = (3.5 * sc).clamp(1.2, 5.0).toDouble();

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
      // Soft atmospheric depth-of-field mist over the far background so
      // close-up front-facing Soul (`06-22-47.png`) pops in razor-sharp 3D!
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

    final flash = game.portalFlashProgress;
    if (flash > 0.01) {
      final center = Offset(w * 0.5, h * 0.52);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = Gradient.radial(
            center,
            w * 0.85,
            [
              const Color(0xFFFFFFFF).withValues(alpha: 0.44 * flash),
              _worldLightColor.withValues(alpha: 0.28 * flash),
              const Color(0x00000000),
            ],
            const [0.0, 0.55, 1.0],
          ),
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
