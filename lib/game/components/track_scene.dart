import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// S18 100% Modular 9-Layer 3D `SOUL: DUSK RUN` World Engine (`TrackScene`).
///
/// Every square inch of the viewport is constructed out of independent,
/// depth-projected 3D surfaces and modular 3D world elements (ZERO static
/// painted scenery):
///  1. Pure atmospheric sky dome + twinkling starfield + radial Celestial
///     Moon / Sunset Sun element;
///  2. Multi-layer volumetric 3D Sky Cloud banks (`sky_cloud.png`) drifting
///     across the sky at independent parallax speeds;
///  3. Parallax 3D Pine-Mountain horizon silhouettes + streaming `1/Z`
///     High-Altitude 3D Sky Citadel Castle Islands (`sky_citadel.png`);
///  4. Full-width `16×32` `1/Z` perspective-projected 3D Water / Valley Floor
///     Mesh (`valley_floor.png`) flowing beneath the elevated bridge;
///  5. Multi-corridor `1/Z` 3D Valley Scenery: towering Outer Canyon Cliffs &
///     Ancient Forest Banks (`canyon_wall.png`), Mid-Valley Floating/Marsh
///     Islands (`floating_island.png`), and Transverse Ancient Stone Viaduct
///     Arch Ruins (`viaduct_ruin.png`) with water reflections & distance fog;
///  6. True 3D Extruded Stone Causeway: chiseled outer cliff wall, `12×48`
///     `1/Z` Flagstone Slab Deck (`track_strip.png`), 3D raised block-jointed
///     stone curbs, glowing cyan/gold rune seams, and distant horizon halo;
///  7. Curb-mounted 3D Lantern Pillars (`corridor_pillar.png`) & 3D Crystal
///     Rune Shrines (`cliff_side.png`) casting diagonal shadows & light pools;
///  8. Depth-projected bioluminescent Firefly Spores & Solar Flight streaks!
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

  Color get _horizonFogColor {
    switch (game.selectedWorld) {
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
        game.roadCurveFactor * size.x * 0.055;
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
      final horizonFrac =
          GameConfig.backdropHorizonFractionFor(game.selectedWorld);
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

    // Subtle twinkling celestial stars in the upper zenith
    if (game.selectedWorld != GameWorld.emberfallCanyon) {
      final starAlphaBase =
          game.selectedWorld == GameWorld.moonveilMarsh ? 0.58 : 0.34;
      for (var i = 0; i < 18; i++) {
        final sx = ((i * 0.371 + 0.11) % 1.0) * w + _skyParallaxX * 0.25;
        final sy = ((i * 0.619 + 0.04) % 1.0) * horizonY * 0.68;
        final twinkle =
            0.45 + 0.55 * math.sin(game.elapsedSeconds * 2.1 + i * 1.7);
        canvas.drawCircle(
          Offset(sx % w, sy),
          (i % 3 == 0) ? 1.5 : 1.0,
          Paint()
            ..color = const Color(0xFFFFFBE8)
                .withValues(alpha: starAlphaBase * twinkle),
        );
      }
    }

    // Volumetric 3D Celestial Body (Giant Cyan Moon / Sunset Sun / Solar Corona)
    final double cx;
    final double cy;
    final double radius;
    final Color coreCol;
    final Color haloCol;
    switch (game.selectedWorld) {
      case GameWorld.moonveilMarsh:
        cx = w * 0.56 + _skyParallaxX * 0.55;
        cy = horizonY * 0.33;
        radius = w * 0.135;
        coreCol = const Color(0xFFD6FFF9);
        haloCol = const Color(0xFF56F0E4);
      case GameWorld.duskHollow:
        cx = w * 0.54 + _skyParallaxX * 0.55;
        cy = horizonY * 0.64;
        radius = w * 0.056;
        coreCol = const Color(0xFFFFF4D2);
        haloCol = const Color(0xFFFFA874);
      case GameWorld.emberfallCanyon:
        cx = w * 0.52 + _skyParallaxX * 0.55;
        cy = horizonY * 0.58;
        radius = w * 0.076;
        coreCol = const Color(0xFFFFF6CE);
        haloCol = const Color(0xFFFF9E44);
    }

    final bloomR = radius * 3.1;
    canvas.drawCircle(
      Offset(cx, cy),
      bloomR,
      Paint()
        ..shader = Gradient.radial(
          Offset(cx, cy),
          bloomR,
          [
            haloCol.withValues(alpha: 0.42),
            haloCol.withValues(alpha: 0.14),
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

    // Subtle lunar maria craters on Moonveil Marsh's giant full moon!
    if (game.selectedWorld == GameWorld.moonveilMarsh) {
      final craterPaint = Paint()..color = const Color(0x28268E8E);
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
    switch (game.selectedWorld) {
      case GameWorld.moonveilMarsh:
        tintCol = const Color(0xFF287E92);
        tintAmt = 0.56;
      case GameWorld.duskHollow:
        tintCol = const Color(0xFFC87898);
        tintAmt = 0.48;
      case GameWorld.emberfallCanyon:
        tintCol = const Color(0xFFE49454);
        tintAmt = 0.50;
    }

    const specs = [
      // (baseX, yFracOfHorizon, widthFrac, driftSpeed, alpha, flip)
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
                  game.elapsedSeconds * w * s.$4 +
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
  // 3. Distant 3D Mountain Ridges & Streaming 3D Sky Citadel Islands
  // ---------------------------------------------------------------

  void _renderMountainRidgesAndSkyCitadels(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (horizonY <= 0) {
      return;
    }

    // Distant parallax mountain silhouette ridge framing the valley gap
    final Color ridgeFar;
    final Color ridgeNear;
    switch (game.selectedWorld) {
      case GameWorld.moonveilMarsh:
        ridgeFar = const Color(0x881A5868);
        ridgeNear = const Color(0xAA144452);
      case GameWorld.duskHollow:
        ridgeFar = const Color(0x886A447E);
        ridgeNear = const Color(0xAA4E3268);
      case GameWorld.emberfallCanyon:
        ridgeFar = const Color(0x88945038);
        ridgeNear = const Color(0xAA723A28);
    }

    final bridgeHorizonX = game.trackCenterXForDepth(1.0);
    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(-10, horizonY + 8);
      final amp = horizonY * (layer == 0 ? 0.14 : 0.095);
      final phaseShift =
          _skyParallaxX * (layer == 0 ? 0.8 : 1.3) / math.max(1.0, w);
      const segs = 28;
      for (var i = 0; i <= segs; i++) {
        final fx = i / segs;
        final x = -10 + (w + 20) * fx;
        final u = fx + phaseShift;
        final wave = (math.sin(u * 8.5 + layer * 2.2) * 0.5 + 0.5) * 0.72 +
            (math.sin(u * 21.0 + layer) * 0.5 + 0.5) * 0.28;
        final distToGap = ((x - bridgeHorizonX) / (w * 0.22));
        final valleyNotch = 1.0 - 0.72 * math.exp(-distToGap * distToGap);
        path.lineTo(x, horizonY + 2 - amp * wave * valleyNotch);
      }
      path
        ..lineTo(w + 10, horizonY + 8)
        ..close();
      canvas.drawPath(path, Paint()..color = layer == 0 ? ridgeFar : ridgeNear);
    }

    // High-altitude 3D Sky Citadels (`sky_citadel.png`) streaming in 1/Z depth!
    final citadel = game.skyCitadel;
    if (citadel == null) {
      return;
    }
    final aspect = citadel.height / citadel.width;
    final src =
        Rect.fromLTWH(0, 0, citadel.width.toDouble(), citadel.height.toDouble());
    final fogCol = _horizonFogColor;

    const count = 3;
    const span = 1.32;
    const step = span / count;
    final scroll = (game.travelled * 0.26) / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;

    for (var k = 0; k < count; k++) {
      final depth = 1.04 - (phase + k * step);
      if (depth > 1.02 || depth < -0.22) {
        continue;
      }
      final slotId = slotBase - k;
      final side = slotId.isEven ? -1.0 : 1.0;
      final sc = game.perspectiveFactor(depth);
      final fade = ((1.03 - depth) / 0.18).clamp(0.0, 1.0).toDouble();
      final fogAmt = (depth * 0.46).clamp(0.08, 0.52).toDouble();
      final bob =
          math.sin(game.elapsedSeconds * 1.1 + slotId * 2.1) * h * 0.008 * sc;

      final cw = w * 0.62 * sc;
      final ch = cw * aspect;
      final cx = game.trackCenterXForDepth(depth.clamp(0.0, 1.0).toDouble()) +
          side * w * (0.24 + 0.16 * sc);
      final cy = horizonY - h * (0.04 + 0.14 * sc) + bob;

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
              Color(GameConfig.trackFillArgbFor(game.selectedWorld) | 0xFF000000),
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
    final driftU = math.sin(game.elapsedSeconds * 0.45) * 0.08;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    var idx = 0;
    for (var r = 0; r <= _valRows; r++) {
      // Quadratic row concentration near horizon for ultra-smooth 1/Z water!
      final rf = r / _valRows;
      final t = (rf * rf * 0.45 + rf * 0.55) * tBottom;
      final y = horizonY + spanValley * t;
      final p = (pFar + t * (1.0 - pFar)).clamp(0.125, 2.4).toDouble();
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

    // Smooth atmospheric horizon haze melting distant water into the sky!
    final hazeH = (h - horizonY) * 0.20;
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
  // 5. Multi-Corridor `1/Z` 3D Cliffs, Islands & Viaduct Ruins
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

    const slotCount = 7;
    const span = 1.26;
    const step = span / slotCount;
    final scroll = game.travelled / GameConfig.trackLength;
    final slotBase = (scroll / step).floor();
    final phase = scroll % step;

    // Back-to-front painter's order (k = 0 is farthest near horizon -> k = slotCount-1 is closest!)
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
      final yVal = game.valleyYForDepth(depth);
      final fade = ((1.02 - depth) / 0.14).clamp(0.0, 1.0).toDouble();
      final fogAmt = (depth * 0.62).clamp(0.0, 0.58).toDouble();

      // A) Outer Towering 3D Canyon Cliffs & Ancient Forest Banks (alternating sides so water shines between!)
      if (canyon != null) {
        final cliffSide = worldSlot.isEven ? -1.0 : 1.0;
        final cw = w * 0.72 * sc;
        final ch = cw * (canyon.height / canyon.width);
        final px = cx + cliffSide * hw * 2.52;
        final py = yVal + ch * 0.05;

        // Soft bioluminescent reflection on the 3D water beneath the cliff!
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px - cliffSide * cw * 0.12, yVal + ch * 0.02),
            width: cw * 0.85,
            height: cw * 0.18,
          ),
          Paint()..color = lightCol.withValues(alpha: 0.12 * fade),
        );

        _drawFoggedElement(
          canvas,
          canyon,
          cx: px,
          bottomY: py,
          dw: cw,
          dh: ch,
          flipX: cliffSide > 0,
          alpha: fade,
          fogColor: fogCol,
          fogAmount: fogAmt,
        );
      }

      // B) Mid-Valley 3D Viaduct Arch Ruins & Floating/Marsh Islands on the opposite flank!
      final midSide = worldSlot.isEven ? 1.0 : -1.0;
      final useViaduct = (worldSlot.abs() % 3 == 1) && viaduct != null;
      if (useViaduct) {
        final vw = w * 0.56 * sc;
        final vh = vw * (viaduct.height / viaduct.width);
        final px = cx + midSide * hw * 1.56;
        final py = yVal + vh * 0.04;

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px, yVal + vh * 0.02),
            width: vw * 0.88,
            height: vw * 0.16,
          ),
          Paint()..color = const Color(0x55101824).withValues(alpha: 0.30 * fade),
        );

        _drawFoggedElement(
          canvas,
          viaduct,
          cx: px,
          bottomY: py,
          dw: vw,
          dh: vh,
          flipX: midSide > 0,
          alpha: fade,
          fogColor: fogCol,
          fogAmount: fogAmt * 0.88,
        );
      } else if (island != null) {
        final bob = math.sin(game.elapsedSeconds * 1.5 + worldSlot * 1.7) *
            h *
            0.008 *
            sc;
        final iw = w * 0.48 * sc;
        final ih = iw * (island.height / island.width);
        final px = cx + midSide * hw * 1.66;
        final py = yVal + ih * 0.04 - bob;

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px, yVal + ih * 0.02),
            width: iw * 0.76,
            height: iw * 0.15,
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
          flipX: midSide > 0,
          alpha: fade,
          fogColor: fogCol,
          fogAmount: fogAmt * 0.85,
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

  /// Gentle low-lying water/chasm mist wisps rising across the valley.
  void _renderDriftingValleyMist(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final mistCol = _worldLightColor;
    final t = game.elapsedSeconds * 0.25;
    for (var i = 0; i < 3; i++) {
      final yFrac = horizonY + (h - horizonY) * (0.18 + i * 0.26);
      final driftX = math.sin(t + i * 2.1) * w * 0.14;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5 + driftX, yFrac),
          width: w * 1.30,
          height: h * 0.11,
        ),
        Paint()..color = mistCol.withValues(alpha: 0.065),
      );
    }
  }

  // ---------------------------------------------------------------
  // 6. True 3D Extruded Stone Causeway + Block-Jointed Curbs + Halo
  // ---------------------------------------------------------------

  void _render3DExtrudedStoneCauseway(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final depthBottom = game.depthForScreenY(h);
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;

    // A) Under-bridge shadow cast onto the 3D water/valley floor below
    final shadowPath = Path();
    const sideSteps = 16;
    for (var i = 0; i <= sideSteps; i++) {
      final d = 1.0 - (i / sideSteps) * (1.0 - depthBottom);
      final sc = game.perspectiveFactor(d);
      final cx = game.trackCenterXForDepth(d);
      final yv = game.valleyYForDepth(d);
      final hw = halfPlayer * sc * 1.18;
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
      final hw = halfPlayer * sc * 1.18;
      shadowPath.lineTo(cx + hw, yv);
    }
    shadowPath.close();
    canvas.drawPath(shadowPath, Paint()..color = const Color(0x52080E18));

    // B) 12x48 Flagstone Slab Deck (`track_strip.png`)
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
        Paint()
          ..color = Color(
              GameConfig.trackFillArgbFor(game.selectedWorld) | 0xFF000000),
      );
    }

    // C) True 3D Extruded Stone Curb Parapets + Glowing Cyan/Gold Rune Seams!
    _render3DExtrudedCurbs(canvas, w, h, depthBottom, halfPlayer);

    // D) Atmospheric distance mist + Glowing Celestial Horizon Ring at bridge crest!
    final crestX = game.trackCenterXForDepth(1.0);
    final crestY = game.yForDepth(1.0);
    final ringR = w * 0.048;
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
    // Glowing golden/cyan portal ring on the distant bridge horizon (Screenshot 1!)
    canvas.drawCircle(
      Offset(crestX, crestY - ringR * 0.45),
      ringR * 0.72,
      Paint()
        ..color = lightCol.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.drawCircle(
      Offset(crestX, crestY - ringR * 0.45),
      ringR * 0.72,
      Paint()
        ..color = const Color(0xFFFFFCE8).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  void _render3DExtrudedCurbs(
    Canvas canvas,
    double w,
    double h,
    double depthBottom,
    double halfPlayer,
  ) {
    final Color curbTop;
    final Color curbInner;
    final Color curbOuter;
    final Color jointCol;
    final Color runeGlow;
    switch (game.selectedWorld) {
      case GameWorld.duskHollow:
        curbTop = const Color(0xFF9484B4);
        curbInner = const Color(0xFF4C3E6A);
        curbOuter = const Color(0xFF2C2244);
        jointCol = const Color(0xAA34284E);
        runeGlow = const Color(0xFF66F4FF);
      case GameWorld.moonveilMarsh:
        curbTop = const Color(0xFF568A96);
        curbInner = const Color(0xFF264C56);
        curbOuter = const Color(0xFF142C36);
        jointCol = const Color(0xAA18343E);
        runeGlow = const Color(0xFF68FFF2);
      case GameWorld.emberfallCanyon:
        curbTop = const Color(0xFFD8A06A);
        curbInner = const Color(0xFF7E4C2E);
        curbOuter = const Color(0xFF4C2A1A);
        jointCol = const Color(0xAA5A321E);
        runeGlow = const Color(0xFFFFCE5C);
    }

    const segs = 28;
    final dSpan = 1.0 - depthBottom;
    final scrollBlocks =
        (game.travelled / GameConfig.trackLength) * GameConfig.trackTileRepeats * 6.0;

    final pOuter = Paint()..color = curbOuter;
    final pInner = Paint()..color = curbInner;
    final pTop = Paint()..color = curbTop;

    for (final side in const [-1.0, 1.0]) {
      final pathOuter = Path();
      final pathInner = Path();
      final pathTop = Path();

      // Forward along outer/inner edges from horizon (i=0) to bottom (i=segs)
      for (var i = 0; i <= segs; i++) {
        final d = 1.0 - (i / segs) * dSpan;
        final sc = game.perspectiveFactor(d);
        final cx = game.trackCenterXForDepth(d);
        final yb = game.yForDepth(d);
        final hw = halfPlayer * sc;
        final cw = w * 0.046 * sc;
        final ch = w * 0.024 * sc;

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

      // Return along complementary edge from bottom (i=segs) to horizon (i=0)
      for (var i = segs; i >= 0; i--) {
        final d = 1.0 - (i / segs) * dSpan;
        final sc = game.perspectiveFactor(d);
        final cx = game.trackCenterXForDepth(d);
        final yb = game.yForDepth(d);
        final hw = halfPlayer * sc;
        final cw = w * 0.046 * sc;
        final ch = w * 0.024 * sc;
        final drop = h * 0.052 * sc;

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

      // Chiseled curb stone joints + glowing cyan/gold rune-seam spots!
      const blockCount = 10;
      final phase = scrollBlocks % 1.0;
      for (var b = 0; b < blockCount; b++) {
        final distH = (b + phase) / blockCount * 1.14;
        final d = 1.0 - distH;
        if (d > 0.98 || d < depthBottom) {
          continue;
        }
        final sc = game.perspectiveFactor(d);
        final cx = game.trackCenterXForDepth(d);
        final yb = game.yForDepth(d);
        final hw = halfPlayer * sc;
        final cw = w * 0.046 * sc;
        final ch = w * 0.024 * sc;
        final fade = ((1.0 - d) / 0.16).clamp(0.0, 1.0).toDouble();

        final inX = cx + side * hw;
        final outX = cx + side * (hw + cw);
        canvas.drawLine(
          Offset(inX, yb - ch),
          Offset(outX, yb - ch),
          Paint()
            ..color = jointCol.withValues(alpha: 0.68 * fade)
            ..strokeWidth = (1.8 * sc).clamp(0.8, 2.8).toDouble(),
        );

        // Every alternate block joint seeps glowing cyan/gold magic light onto the curb seam!
        final worldBlock = (scrollBlocks.floor() - b).abs();
        if ((worldBlock + (side > 0 ? 1 : 0)) % 2 == 0) {
          final rGlow = (5.5 * sc).clamp(1.6, 8.5).toDouble();
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(inX - side * rGlow * 0.35, yb),
              width: rGlow * 1.4,
              height: rGlow * 2.6,
            ),
            Paint()
              ..color = runeGlow.withValues(alpha: 0.52 * fade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(inX - side * rGlow * 0.15, yb),
              width: rGlow * 0.55,
              height: rGlow * 1.5,
            ),
            Paint()..color = const Color(0xFFEFFFFF).withValues(alpha: 0.80 * fade),
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

    // Subtle distance atmospheric haze over the far 12% of the stone causeway
    final fogCol = _horizonFogColor;
    final cxTop = game.trackCenterXForDepth(1.0);
    final cxMid = game.trackCenterXForDepth(0.68);
    final hwTop = halfPlayer * GameConfig.farScale * 1.15;
    final hwMid = halfPlayer * game.perspectiveFactor(0.68) * 1.15;
    final yMid = game.yForDepth(0.68);
    final hazePath = Path()
      ..moveTo(cxTop - hwTop, horizonY - 2)
      ..lineTo(cxTop + hwTop, horizonY - 2)
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
            fogCol.withValues(alpha: 0.76),
            fogCol.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  // ---------------------------------------------------------------
  // 7. Curb-Mounted 3D Lanterns & Crystal Shrines + Deck Shadows
  // ---------------------------------------------------------------

  void _renderBridgeCurbPropsAndShadows(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final pillar = game.corridorPillar;
    final cliff = game.cliffSide;
    final auraColor = Color(GameConfig.lanternAuraArgbFor(game.selectedWorld));
    final fogCol = _horizonFogColor;

    const slotCount = 5;
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
      final ybCurb = ybDeck - w * 0.022 * sc;
      final cx = game.trackCenterXForDepth(depth);
      final hw = halfPlayer * sc;
      final fade = (distH / 0.14).clamp(0.0, 1.0).toDouble();
      final fogAmt = (depth * 0.44).clamp(0.0, 0.42).toDouble();
      final worldSlot = slotBase - k;

      for (final side in const [-1.0, 1.0]) {
        final isLantern =
            ((worldSlot.abs() + (side > 0 ? 1 : 0)) % 2 == 0) || cliff == null;
        final curbCenterX = cx + side * (hw + w * 0.023 * sc);

        if (isLantern) {
          final pw = w * 0.155 * sc;
          final aspect = pillar != null ? pillar.height / pillar.width : 1.75;
          final ph = pw * aspect;

          // Diagonal shadow + warm lantern light pool cast inward onto flagstones!
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(curbCenterX - side * pw * 0.42, ybDeck + 2 * sc),
              width: pw * 0.95,
              height: pw * 0.22,
            ),
            Paint()..color = const Color(0x55120C22).withValues(alpha: 0.34 * fade),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(curbCenterX - side * pw * 0.28, ybDeck),
              width: pw * 1.15,
              height: pw * 0.30,
            ),
            Paint()..color = auraColor.withValues(alpha: 0.24 * fade),
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
          final cw = w * 0.215 * sc;
          final ch = cw * (cliff.height / cliff.width);

          // Diagonal crystal-shrine shadow cast across the stone slabs (Screenshot 2!)
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(curbCenterX - side * cw * 0.38, ybDeck + 2 * sc),
              width: cw * 0.92,
              height: cw * 0.20,
            ),
            Paint()..color = const Color(0x66120C24).withValues(alpha: 0.42 * fade),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(curbCenterX - side * cw * 0.18, ybDeck),
              width: cw * 0.76,
              height: cw * 0.22,
            ),
            Paint()..color = auraColor.withValues(alpha: 0.18 * fade),
          );

          _drawFoggedElement(
            canvas,
            cliff,
            cx: curbCenterX,
            bottomY: ybCurb + ch * 0.05,
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
  // 8. Bioluminescent Firefly Spores & Solar Comet Streaks
  // ---------------------------------------------------------------

  void _renderFloatingFireflyMotes(Canvas canvas, double h) {
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
      final laneOffset = math.sin(seed * 19.3 + t * 0.55) * 2.15;
      final mx = game.laneXForDepth(1.0 + laneOffset, depth);
      final floatH = (0.12 + 0.55 * ((seed * 7.13) % 1.0)) +
          math.sin(t * 1.3 + i) * 0.08;
      final my = game.yForDepth(depth) - h * 0.20 * floatH * sc;
      final pulse = 0.55 + 0.45 * math.sin(t * 2.4 + i * 1.7);
      final fade = ((1.0 - depth) / 0.20).clamp(0.0, 1.0).toDouble() * pulse;
      final r = (3.4 * sc).clamp(1.2, 4.8).toDouble();

      canvas.drawCircle(
        Offset(mx, my),
        r * 2.3,
        Paint()..color = glowCol.withValues(alpha: 0.24 * fade),
      );
      canvas.drawCircle(
        Offset(mx, my),
        r * 0.75,
        Paint()
          ..color = const Color(0xFFFFFCE8).withValues(alpha: 0.80 * fade),
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
