import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// S13 True-1/Z 3D Twilight Sky-Bridge Environment.
///
/// Renders:
///  1. Portrait-framed high-DPI sky & horizon sanctuary (1:1 crisp, no 3x
///     vertical zoom blur) + deep atmospheric chasm mist & drifting fireflies;
///  2. Continuous 3D raised stone viaduct parapet curbs & vertical masonry
///     drop-walls scrolling in exact `1 / Z` lockstep with the road;
///  3. Perspective-correct `12 x 64` subdivided `1 / Z` flagstone mesh tiled
///     `3.0x` along [GameConfig.trackLength] so pavers stay razor-sharp all
///     the way beneath Soul's feet to screen bottom;
///  4. Six symmetric pairs of high-DPI front-perspective Sanctuary Lantern
///     Pylons seated squarely on both stone parapets, casting warm pools of
///     light onto the stonework as they stream past.
class TrackScene extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  TrackScene() : super(priority: -100);

  static const int _meshCols = 12;
  static const int _meshRows = 64;
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

  late final List<Offset> _stars = _makeStars();
  late final List<_Mote> _motes = _makeMotes();

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

  static List<Offset> _makeStars() {
    final random = math.Random(7);
    return List<Offset>.generate(
      28,
      (_) => Offset(random.nextDouble(), random.nextDouble() * 0.24),
      growable: false,
    );
  }

  static List<_Mote> _makeMotes() {
    final random = math.Random(23);
    return List<_Mote>.generate(
      GameConfig.ambientParticleCount,
      (_) => _Mote(
        x: random.nextDouble(),
        phase: random.nextDouble(),
        speed: 0.45 + random.nextDouble() * 0.75,
        radius: 1.2 + random.nextDouble() * 1.6,
      ),
      growable: false,
    );
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
    _renderChasmAtmosphere(canvas, w, h);
    _renderSpeedLines(canvas, w, h);
    _renderCausewayFlanks(canvas, w, h);
    _renderTrack(canvas, w, h);
    _renderCorridorPillars(canvas, w, h);
  }

  /// Portrait-crisp sky + horizon backdrop rendering (S13: fits width cleanly
  /// at ~1:1 native DPI so all floating islands, trees, and canyon cliffs
  /// frame the horizon without 3x vertical upscale blur).
  void _renderWorldBackdrop(
      Canvas canvas, double w, double h, Image backdrop) {
    final horizonY = game.horizonY;
    final imgW = backdrop.width.toDouble();
    final imgH = backdrop.height.toDouble();
    final baseFill =
        Color(GameConfig.trackFillArgbFor(game.selectedWorld) | 0xFF000000);

    // Solid deep chasm base below the sky dome so zero unpainted pixels ever appear.
    canvas.drawRect(Offset.zero & Size(w, h), Paint()..color = baseFill);

    final horizonFrac =
        GameConfig.backdropHorizonFractionFor(game.selectedWorld);
    // Fit portrait width + enough vertical span to reach horizonY cleanly.
    final minScaleForSky =
        (horizonY + GameConfig.backdropDriftAmplitude + 8) /
            math.max(1.0, imgH * horizonFrac);
    final scale = math.max(w / imgW, minScaleForSky) * 1.08;

    final laneCenter = (GameConfig.laneCount - 1) / 2;
    final sway =
        (game.laneSystem.lane - laneCenter) * -GameConfig.cameraSwayPerLane;
    final dx = (w - imgW * scale) / 2 + sway;
    final drift = math.sin(game.elapsedSeconds * 0.35) *
        GameConfig.backdropDriftAmplitude;
    final dy = (horizonY - imgH * horizonFrac * scale + drift).clamp(
      math.min(0.0, h - imgH * scale),
      0.0,
    );

    canvas.drawImageRect(
      backdrop,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(dx, dy, imgW * scale, imgH * scale),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// Deep misty chasm & scrolling valley fog banks flanking the sky-bridge
  /// below [SoulDuskRunGame.horizonY].
  void _renderChasmAtmosphere(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final world = game.selectedWorld;
    final Color mistTop;
    final Color mistMid;
    final Color chasmDeep;
    switch (world) {
      case GameWorld.duskHollow:
        mistTop = const Color(0x005C3496);
        mistMid = const Color(0xB8321A5C);
        chasmDeep = const Color(0xF2120826);
      case GameWorld.moonveilMarsh:
        mistTop = const Color(0x001D6B75);
        mistMid = const Color(0xB80E3B46);
        chasmDeep = const Color(0xF206161E);
      case GameWorld.emberfallCanyon:
        mistTop = const Color(0x008A3E2B);
        mistMid = const Color(0xB84A2018);
        chasmDeep = const Color(0xF21C0B08);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - h * 0.02, w, h - horizonY + h * 0.02),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, horizonY - h * 0.02),
          Offset(0, h),
          [mistTop, mistMid, chasmDeep],
          const [0.0, 0.28, 1.0],
        ),
    );

    // Soft drifting chasm mist billows on left & right flanks (scrolling forward
    // subtly with world travel so the whole valley feels alive).
    final edgeTint = Color(GameConfig.trackEdgeArgbFor(world));
    final flow = (game.travelled / GameConfig.trackLength * 0.55) % 1.0;
    for (var i = 0; i < 4; i++) {
      final t = (flow + i * 0.25) % 1.0;
      final yMist = horizonY + (h - horizonY) * (0.12 + 0.78 * t * t);
      final rMist = w * (0.16 + 0.18 * t);
      final alpha = math.sin(t * math.pi) * 0.14;
      final mistPaint = Paint()
        ..shader = Gradient.radial(
          Offset(w * 0.10, yMist),
          rMist,
          [
            edgeTint.withValues(alpha: alpha),
            edgeTint.withValues(alpha: 0.0),
          ],
        );
      canvas.drawCircle(Offset(w * 0.10, yMist), rMist, mistPaint);

      final mistPaintR = Paint()
        ..shader = Gradient.radial(
          Offset(w * 0.90, yMist + 18),
          rMist,
          [
            edgeTint.withValues(alpha: alpha),
            edgeTint.withValues(alpha: 0.0),
          ],
        );
      canvas.drawCircle(Offset(w * 0.90, yMist + 18), rMist, mistPaintR);
    }

    _renderMotes(canvas, w, h);
  }

  void _renderSpeedLines(Canvas canvas, double w, double h) {
    if (!game.isRunStarted) {
      return;
    }
    final intensity = game.powerUps.isSolarDashing
        ? 1.0
        : ((game.difficulty.levelAt(game.elapsedSeconds) - 0.14) / 0.86)
            .clamp(0.0, 0.72);
    if (intensity <= 0.02) {
      return;
    }
    final horizonY = game.horizonY;
    final cx = w / 2;
    final color = game.powerUps.isSolarDashing
        ? const Color(0xFFFFD54F)
        : Color(GameConfig.trackEdgeArgbFor(game.selectedWorld));
    final paint = Paint()
      ..strokeWidth = game.powerUps.isSolarDashing ? 2.4 : 1.5
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;

    const streakCount = 8;
    final phaseBase = game.travelled / GameConfig.trackLength * 1.8;
    for (var i = 0; i < streakCount; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final t = (phaseBase + i * 0.137) % 1.0;
      final r0 = 0.28 + t * 0.54;
      final r1 = (r0 + 0.13).clamp(0.0, 1.05);
      final spreadY = 0.10 + (i % 4) * 0.16;
      final p0 = Offset(
        cx + side * w * 0.52 * r0,
        horizonY + (h - horizonY) * spreadY * r0,
      );
      final p1 = Offset(
        cx + side * w * 0.52 * r1,
        horizonY + (h - horizonY) * spreadY * r1,
      );
      final fade = math.sin(t * math.pi) * intensity * 0.38;
      paint.color = color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.drawLine(p0, p1, paint);
    }
  }

  /// True `1 / Z` 3D raised stone viaduct parapet ledge + vertical cliff
  /// drop-wall flanking both sides of the causeway.
  void _renderCausewayFlanks(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final tBottom = (h - horizonY) / spanToPlayer;
    const pFar = GameConfig.farScale;
    final pBottom = pFar + tBottom * (1.0 - pFar);

    final cx = w / 2;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;
    final halfTop = halfPlayer * pFar;
    final halfBottom = halfPlayer * pBottom;

    // Parapet top ledge width & outer vertical stone drop-cliff width scale
    // linearly with `p = 1/Z` (exact 3D pinhole geometry!).
    final parapetPlayer = w * 0.036;
    final cliffPlayer = w * 0.026;
    final pTopW = parapetPlayer * pFar;
    final pBotW = parapetPlayer * pBottom;
    final cTopW = cliffPlayer * pFar;
    final cBotW = cliffPlayer * pBottom;

    final baseFill =
        Color(GameConfig.trackFillArgbFor(game.selectedWorld) | 0xFF000000);
    final edgeColor =
        Color(GameConfig.trackEdgeArgbFor(game.selectedWorld) | 0xFF000000);
    final parapetTop = Color.lerp(baseFill, edgeColor, 0.34)!;
    final cliffShade = Color.lerp(baseFill, const Color(0xFF070310), 0.55)!;

    for (final side in const [-1.0, 1.0]) {
      // 1. Outer vertical viaduct drop-cliff face
      final cliffPath = Path()
        ..moveTo(cx + side * (halfTop + pTopW), horizonY)
        ..lineTo(cx + side * (halfTop + pTopW + cTopW), horizonY + 4)
        ..lineTo(cx + side * (halfBottom + pBotW + cBotW), h)
        ..lineTo(cx + side * (halfBottom + pBotW), h)
        ..close();
      canvas.drawPath(
        cliffPath,
        Paint()
          ..shader = Gradient.linear(
            Offset(cx, horizonY),
            Offset(cx, h),
            [cliffShade.withValues(alpha: 0.15), cliffShade],
          ),
      );

      // 2. Raised stone parapet top ledge (lantern pylons stand right on this!)
      final ledgePath = Path()
        ..moveTo(cx + side * halfTop, horizonY)
        ..lineTo(cx + side * (halfTop + pTopW), horizonY)
        ..lineTo(cx + side * (halfBottom + pBotW), h)
        ..lineTo(cx + side * halfBottom, h)
        ..close();
      canvas.drawPath(
        ledgePath,
        Paint()
          ..shader = Gradient.linear(
            Offset(cx, horizonY),
            Offset(cx, h),
            [
              parapetTop.withValues(alpha: 0.18),
              parapetTop.withValues(alpha: 0.96),
            ],
          ),
      );

      // Crisp outer bevel highlight along parapet rim
      canvas.drawLine(
        Offset(cx + side * (halfTop + pTopW), horizonY),
        Offset(cx + side * (halfBottom + pBotW), h),
        Paint()
          ..color = edgeColor.withValues(alpha: 0.45)
          ..strokeWidth = 1.4,
      );
    }

    // Scrolling 1/Z stone masonry joints across the parapet & drop-cliff
    // (100% locked to ground scroll!).
    final jointPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const jointCount = 16;
    const worldSpan = 1.12;
    const step = worldSpan / jointCount;
    final scrollPhase = (game.travelled / GameConfig.trackLength) % step;

    for (var k = 0; k < jointCount; k++) {
      final distFromHorizon = scrollPhase + k * step; // 0 = horizon, 1 = player
      final depth = 1.0 - distFromHorizon;
      final p = game.perspectiveFactor(depth);
      final y = game.yForDepth(depth);
      if (y <= horizonY + 2 || y > h + 20) {
        continue;
      }
      final half = halfPlayer * p;
      final pw = parapetPlayer * p;
      final cw = cliffPlayer * p;
      final fade = (distFromHorizon / 0.25).clamp(0.0, 1.0) * 0.48;
      jointPaint.color = const Color(0xFF0E061E).withValues(alpha: fade);

      for (final side in const [-1.0, 1.0]) {
        final x0 = cx + side * half;
        final x1 = cx + side * (half + pw);
        final x2 = cx + side * (half + pw + cw);
        canvas.drawLine(Offset(x0, y), Offset(x1, y), jointPaint);
        canvas.drawLine(Offset(x1, y), Offset(x2, y + cw * 0.9), jointPaint);
      }
    }
  }

  /// Streams 6 symmetric pairs of high-DPI front-perspective Sanctuary Lantern
  /// Pylons seated squarely on both viaduct parapets in exact `1 / Z` lockstep.
  void _renderCorridorPillars(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final cx = w / 2;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;
    final parapetMidPlayer = w * 0.018;
    final pillar = game.corridorPillar;
    final auraColor = Color(GameConfig.lanternAuraArgbFor(game.selectedWorld));

    const pairCount = 6;
    const worldSpan = 1.14; // covers depth 1.0 down to depth -0.14
    const step = worldSpan / pairCount;
    final scrollPhase = (game.travelled / GameConfig.trackLength) % step;

    // Draw back-to-front (smaller distFromHorizon = closer to horizon first!).
    for (var k = 0; k < pairCount; k++) {
      final distFromHorizon = scrollPhase + k * step;
      if (distFromHorizon <= 0.02) {
        continue;
      }
      final depth = 1.0 - distFromHorizon;
      final p = game.perspectiveFactor(depth);
      final yBase = game.yForDepth(depth);
      if (yBase > h + w * 0.35) {
        continue;
      }
      final alpha = (distFromHorizon / 0.14).clamp(0.0, 1.0);
      final half = halfPlayer * p;
      final parapetMid = parapetMidPlayer * p;

      final pillarW = w * 0.185 * p;
      final aspect = pillar != null ? pillar.height / pillar.width : 1.75;
      final pillarH = pillarW * aspect;

      for (final side in const [-1.0, 1.0]) {
        final footX = cx + side * (half + parapetMid);
        final footY = yBase + pillarH * 0.05;
        if (footX + pillarW < -30 || footX - pillarW > w + 30) {
          continue;
        }

        // Warm lantern light pool cast onto the stone curb & parapet!
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(footX - side * pillarW * 0.18, yBase),
            width: pillarW * 1.55,
            height: pillarW * 0.52,
          ),
          Paint()
            ..color = auraColor.withValues(alpha: 0.16 * alpha)
            ..blendMode = BlendMode.plus
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );

        // Ground contact shadow on parapet ledge.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(footX, yBase),
            width: pillarW * 0.68,
            height: pillarW * 0.20,
          ),
          Paint()
            ..color = const Color(0xFF090314).withValues(alpha: 0.62 * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

        if (pillar != null) {
          canvas.save();
          canvas.translate(footX, footY);
          if (side > 0) {
            canvas.scale(-1, 1);
          }
          canvas.drawImageRect(
            pillar,
            Rect.fromLTWH(
                0, 0, pillar.width.toDouble(), pillar.height.toDouble()),
            Rect.fromLTWH(-pillarW / 2, -pillarH, pillarW, pillarH),
            Paint()
              ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
              ..filterQuality = FilterQuality.medium,
          );
          canvas.restore();
        } else {
          canvas.drawRect(
            Rect.fromLTWH(
              footX - pillarW * 0.28,
              footY - pillarH * 0.90,
              pillarW * 0.56,
              pillarH * 0.90,
            ),
            Paint()
              ..color =
                  const Color(0xFF281A42).withValues(alpha: 0.85 * alpha),
          );
        }

        // Gentle breathing lantern flame halo.
        final pulse =
            0.90 + 0.10 * math.sin(game.elapsedSeconds * 3.6 + k * 1.3);
        canvas.drawCircle(
          Offset(footX, footY - pillarH * 0.71),
          pillarW * 0.44 * pulse,
          Paint()
            ..color = auraColor.withValues(alpha: 0.22 * alpha)
            ..blendMode = BlendMode.plus,
        );
      }
    }
  }

  void _renderMotes(Canvas canvas, double w, double h) {
    final t = game.elapsedSeconds;
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final mote in _motes) {
      final cycle = (t * 0.022 * mote.speed + mote.phase) % 1.0;
      final fade = math.sin(cycle * math.pi);
      final yF = 0.24 + 0.72 * cycle;
      final wobble = math.sin(t * 0.65 * mote.speed + mote.phase * 6.28) * 9;
      paint.color = Color.fromARGB(
        (0x40 * fade).round(),
        0xFF,
        0xD8,
        0x75,
      );
      canvas.drawCircle(
        Offset(mote.x * w + wobble, yF * h),
        mote.radius * (0.65 + cycle * 0.8),
        paint,
      );
    }
  }

  /// True `1 / Z` perspective track trapezoid & high-DPI flagstone mesh.
  void _renderTrack(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final tBottom = (h - horizonY) / spanToPlayer;
    const pFar = GameConfig.farScale;
    final pBottom = pFar + tBottom * (1.0 - pFar);

    final cx = w / 2;
    final halfPlayer = w * GameConfig.trackBottomHalfWidthRatio;
    final halfTop = halfPlayer * pFar;
    final halfBottom = halfPlayer * pBottom;

    final track = Path()
      ..moveTo(cx - halfTop, horizonY)
      ..lineTo(cx + halfTop, horizonY)
      ..lineTo(cx + halfBottom, h)
      ..lineTo(cx - halfBottom, h)
      ..close();
    canvas.drawPath(
      track,
      Paint()
        ..shader = Gradient.linear(
          Offset(cx, horizonY),
          Offset(cx, h),
          [
            Color(GameConfig.trackFillArgbFor(game.selectedWorld))
                .withValues(alpha: 0.35),
            Color(GameConfig.trackFillArgbFor(game.selectedWorld))
                .withValues(alpha: 0.94),
          ],
        ),
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
        cx: cx,
        halfPlayer: halfPlayer,
      );

      // Soft horizon atmospheric haze over the farthest 5% of the bridge so
      // the causeway melts organically into the distant Citadel / Moon mist.
      final fadeEnd = horizonY + (h - horizonY) * 0.05;
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

    // Fallback rails & stripes when running headless tests without assets.
    final edge = Paint()
      ..color = Color(GameConfig.trackEdgeArgbFor(game.selectedWorld))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(cx - halfTop, horizonY), Offset(cx - halfBottom, h), edge);
    canvas.drawLine(
        Offset(cx + halfTop, horizonY), Offset(cx + halfBottom, h), edge);

    final lanePaint = Paint()
      ..color = Color(GameConfig.trackLaneArgbFor(game.selectedWorld))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 1; i < GameConfig.laneCount; i++) {
      final f = i / GameConfig.laneCount;
      canvas.drawLine(
        Offset(cx - halfTop + 2 * halfTop * f, horizonY),
        Offset(cx - halfBottom + 2 * halfBottom * f, h),
        lanePaint,
      );
    }

    final stripe = Paint()
      ..color = Color(GameConfig.trackStripeArgbFor(game.selectedWorld))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const stripeCount = 12;
    final spacing = GameConfig.trackLength / stripeCount;
    for (var i = 0; i < stripeCount; i++) {
      final phase = (game.travelled + i * spacing) % GameConfig.trackLength;
      final depth = 1 - phase / GameConfig.trackLength;
      final y = game.yForDepth(depth);
      if (y <= horizonY + 2 || y >= h - 2) {
        continue;
      }
      final half = game.halfWidthForDepth(depth) * 0.96;
      canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), stripe);
    }
  }

  /// True `1 / Z` perspective-correct mesh rasterizer (`12 x 64` grid).
  ///
  /// Screen `y` steps uniformly from `horizonY` to `h`, so `p = 1 / Z` steps
  /// linearly, `z = 1 / p` recovers exact 3D world distance, and `v` tiles
  /// `track_strip.png` (`1024x2048`) [GameConfig.trackTileRepeats] times per
  /// [GameConfig.trackLength] — zero foreground stretch, zero obstacle slip!
  void _renderStripMesh(
    Canvas canvas,
    Image strip, {
    required double horizonY,
    required double h,
    required double spanToPlayer,
    required double cx,
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
      // Gently bias row density near the horizon where `dz/dy` changes fastest.
      final s = rowFrac * rowFrac * 0.35 + rowFrac * 0.65;
      final t = s * tBottom;
      final y = horizonY + spanToPlayer * t;
      final p = pFar + t * (1.0 - pFar);
      final z = 1.0 / p;
      final distFromHorizon =
          (GameConfig.farDepthRatio - z) / (GameConfig.farDepthRatio - 1.0);
      final vUnwrapped =
          (distFromHorizon * GameConfig.trackTileRepeats - (scroll % 1.0)) *
              stripH;
      final half = halfPlayer * p;
      final left = cx - half;
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
    final cx = w / 2;

    final sky = Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, h),
        const [Color(0xFF0E0920), Color(0xFF1C1236), Color(0xFF33205A)],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & Size(w, h), sky);

    final starPaint = Paint()..color = const Color(0xAAFFF6E0);
    for (final star in _stars) {
      canvas.drawCircle(Offset(star.dx * w, star.dy * h), 1.2, starPaint);
    }

    final glow = Paint()
      ..shader = Gradient.radial(
        Offset(cx, horizonY),
        w * 0.65,
        const [Color(0x55F78DA7), Color(0x00F78DA7)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glow);

    _drawRidge(canvas, w, horizonY, game.travelled * 0.02, w * 0.34, h * 0.05,
        const Color(0xFF1B1133));
    _drawRidge(canvas, w, horizonY, game.travelled * 0.05, w * 0.26, h * 0.028,
        const Color(0xFF231741));

    canvas.drawRect(Rect.fromLTWH(0, horizonY, w, h - horizonY),
        Paint()..color = const Color(0xFF191028));
  }

  void _drawRidge(
    Canvas canvas,
    double width,
    double baseY,
    double offset,
    double step,
    double peakHeight,
    Color color,
  ) {
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(0, baseY, width, peakHeight * 0.4), paint);

    final path = Path()..moveTo(-step, baseY);
    var x = -step - (offset % step);
    var peak = true;
    while (x < width + step) {
      if (peak) {
        path
          ..lineTo(x + step / 2, baseY - peakHeight)
          ..lineTo(x + step, baseY);
      } else {
        path.lineTo(x + step, baseY);
      }
      x += step;
      peak = !peak;
    }
    path
      ..lineTo(width + step, baseY)
      ..close();
    canvas.drawPath(path, paint);
  }
}

class _Mote {
  const _Mote({
    required this.x,
    required this.phase,
    required this.speed,
    required this.radius,
  });

  final double x;
  final double phase;
  final double speed;
  final double radius;
}
