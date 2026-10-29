import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// World environment (P2 slice, S4 multi-world): the selected world's
/// pre-rendered backdrop is drawn cover-fit with its painted horizon
/// anchored to the game's horizon line, breathing gently and swaying
/// opposite the player's lane for camera parallax. The code-drawn
/// perspective track, lane dividers, flowing depth stripes and tinted
/// edges take their colors from the world palette — gameplay projection
/// is untouched and identical in every world. Ambient luminous motes
/// drift over the valley to match the baked-in particles.
///
/// When the backdrop image is unavailable the component renders the
/// Phase 1 canvas placeholder sky/ridges instead (never a black scene).
class TrackScene extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  TrackScene() : super(priority: -100);

  // S11 perspective mesh grid: 12 horizontal columns (divisible by 6 so
  // column boundaries land directly on the 1/3 & 2/3 rails and 1/2 center,
  // eliminating affine trapezoid sawtooth warp) x 48 foreshortened rows.
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
        speed: 0.5 + random.nextDouble() * 0.8,
        radius: 1.1 + random.nextDouble() * 1.4,
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
    _renderSpeedLines(canvas, w, h);
    _renderCausewayFlanks(canvas, w, h);
    _renderTrack(canvas, w, h);
    _renderCorridorPillars(canvas, w, h);
  }

  /// Kinetic radial wind/light streaks along the outer corridor flanks as
  /// forward speed climbs or during Sunburst Sky-Dash (S12).
  void _renderSpeedLines(Canvas canvas, double w, double h) {
    if (!game.isRunStarted) {
      return;
    }
    final intensity = game.powerUps.isSolarDashing
        ? 1.0
        : ((game.difficulty.levelAt(game.elapsedSeconds) - 0.12) / 0.88)
            .clamp(0.0, 0.75);
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
    final phaseBase = game.travelled / GameConfig.trackLength * 1.9;
    for (var i = 0; i < streakCount; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final t = (phaseBase + i * 0.137) % 1.0;
      final r0 = 0.26 + t * 0.56;
      final r1 = (r0 + 0.14).clamp(0.0, 1.05);
      final spreadY = 0.08 + (i % 4) * 0.16;
      final p0 = Offset(
        cx + side * w * 0.54 * r0,
        horizonY + (h - horizonY) * spreadY * r0,
      );
      final p1 = Offset(
        cx + side * w * 0.54 * r1,
        horizonY + (h - horizonY) * spreadY * r1,
      );
      final fade = math.sin(t * math.pi) * intensity * 0.42;
      paint.color = color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.drawLine(p0, p1, paint);
    }
  }

  /// 3D stone viaduct side-walls dropping outward from both edges of the
  /// track, with perspective masonry ribs scrolling in 1:1 lockstep with
  /// the track bricks so the causeway reads as a solid elevated structure
  /// moving through the valley (S12).
  void _renderCausewayFlanks(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final aMax = (h - horizonY) / spanToPlayer;
    final cx = w / 2;
    final halfTop = game.halfWidthForDepth(1);
    final halfPlayer = game.halfWidthForDepth(0);
    final halfBottom = halfTop + (halfPlayer - halfTop) * aMax;

    final wallTop = w * 0.018;
    final wallBottom = w * 0.14;
    final baseFill = Color(GameConfig.trackFillArgbFor(game.selectedWorld));

    for (final side in const [-1.0, 1.0]) {
      final wall = Path()
        ..moveTo(cx + side * halfTop, horizonY)
        ..lineTo(cx + side * (halfTop + wallTop), horizonY + 8)
        ..lineTo(cx + side * (halfBottom + wallBottom), h)
        ..lineTo(cx + side * halfBottom, h)
        ..close();
      canvas.drawPath(
        wall,
        Paint()
          ..shader = Gradient.linear(
            Offset(cx, horizonY),
            Offset(cx, h),
            [
              baseFill.withValues(alpha: 0.0),
              baseFill.withValues(alpha: 0.78),
            ],
          ),
      );
    }

    // Scrolling stone buttress ribs along both viaduct walls (same u^2
    // foreshortening as the track strip -> zero relative slip).
    final ribPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final edgeColor = Color(GameConfig.trackEdgeArgbFor(game.selectedWorld));
    const ribStep = 0.12;
    final phase = (game.travelled / GameConfig.trackLength) % ribStep;
    for (var k = 0; k < 10; k++) {
      final u = phase + k * ribStep;
      if (u <= 0.06) {
        continue;
      }
      final a = math.pow(u, GameConfig.perspectiveExponent).toDouble();
      final y = horizonY + spanToPlayer * a;
      if (y > h + 40) {
        continue;
      }
      final half = halfTop + (halfPlayer - halfTop) * a;
      final wallW = wallTop + (wallBottom - wallTop) * (a / math.max(1.0, aMax));
      final fade = ((u - 0.06) / 0.22).clamp(0.0, 1.0) * 0.36;
      ribPaint.color = edgeColor.withValues(alpha: fade);
      canvas.drawLine(
        Offset(cx - half, y),
        Offset(cx - half - wallW, y + wallW * 0.55),
        ribPaint,
      );
      canvas.drawLine(
        Offset(cx + half, y),
        Offset(cx + half + wallW, y + wallW * 0.55),
        ribPaint,
      );
    }
  }

  /// Streams 5 symmetric pairs of world-authored stone lantern pillars
  /// down both outer flanks of the viaduct at exact 2.5D world speed so
  /// environment and track advance together like Subway Surfers (S12).
  void _renderCorridorPillars(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    if (h <= horizonY) {
      return;
    }
    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final cx = w / 2;
    final halfTop = game.halfWidthForDepth(1);
    final halfPlayer = game.halfWidthForDepth(0);
    final pillar = game.corridorPillar;

    const pairCount = 5;
    const cycleSpan = 1.22;
    const step = cycleSpan / pairCount;
    final phase = (game.travelled / GameConfig.trackLength) % step;

    for (var k = 0; k < pairCount; k++) {
      final u = phase + k * step;
      if (u < 0.035) {
        continue;
      }
      final a = math.pow(u, GameConfig.perspectiveExponent).toDouble();
      final yBase = horizonY + spanToPlayer * a;
      final half = halfTop + (halfPlayer - halfTop) * a;
      final sc = GameConfig.farScale +
          (1 - GameConfig.farScale) *
              math.pow(u, GameConfig.scaleExponent).toDouble();
      final alpha = ((u - 0.035) / 0.16).clamp(0.0, 1.0);

      final pillarH = w * 0.34 * sc;
      final aspect =
          pillar != null ? pillar.width / pillar.height : 0.44;
      final pillarW = pillarH * aspect;
      final flankOffset = half + pillarW * 0.44;

      for (final side in const [-1.0, 1.0]) {
        final footX = cx + side * flankOffset;
        final footY = yBase + pillarH * 0.05;
        if (footX + pillarW < -20 || footX - pillarW > w + 20) {
          continue;
        }

        // Contact shadow on the viaduct parapet ledge.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(footX, footY - pillarH * 0.03),
            width: pillarW * 0.92,
            height: pillarW * 0.28,
          ),
          Paint()
            ..color = const Color(0xFF0A0416).withValues(alpha: 0.55 * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        if (pillar != null) {
          canvas.save();
          canvas.translate(footX, footY);
          // Mirror right-flank pillar so both lantern faces angle inward.
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
          // Lightweight canvas fallback when asset bundle is absent in tests.
          final rect = Rect.fromLTWH(
            footX - pillarW * 0.32,
            footY - pillarH * 0.92,
            pillarW * 0.64,
            pillarH * 0.92,
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color =
                  const Color(0xFF281A42).withValues(alpha: 0.85 * alpha),
          );
        }

        // Warm breathing lantern aura at the pillar crown.
        final lanternPulse =
            0.88 + 0.12 * math.sin(game.elapsedSeconds * 3.8 + k);
        canvas.drawCircle(
          Offset(footX, footY - pillarH * 0.72),
          pillarW * 0.58 * lanternPulse,
          Paint()
            ..color =
                const Color(0xFFFFC857).withValues(alpha: 0.26 * alpha)
            ..blendMode = BlendMode.plus,
        );
      }
    }
  }

  /// Cover-fits the selected world's matte painting so the whole screen
  /// stays painted, anchors its painted horizon near the game horizon,
  /// adds breathing drift and lane-opposed camera sway.
  void _renderWorldBackdrop(
      Canvas canvas, double w, double h, Image backdrop) {
    final horizonY = game.horizonY;
    final imgW = backdrop.width.toDouble();
    final imgH = backdrop.height.toDouble();

    // 8% overscan so drift/sway can never expose an unpainted edge.
    final scale = math.max(w / imgW, h / imgH) * 1.08;

    final laneCenter = (GameConfig.laneCount - 1) / 2;
    final sway = (game.laneSystem.lane - laneCenter) *
        -GameConfig.cameraSwayPerLane;
    final dx = (w - imgW * scale) / 2 + sway;

    final drift = math.sin(game.elapsedSeconds * 0.35) *
        GameConfig.backdropDriftAmplitude;
    // Clamp keeps the (covering) image from ever leaving a visible gap.
    final horizonFraction =
        GameConfig.backdropHorizonFractionFor(game.selectedWorld);
    var dy = horizonY - imgH * horizonFraction * scale + drift;
    dy = dy.clamp(h - imgH * scale, 0.0);

    canvas.drawImageRect(
      backdrop,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(dx, dy, imgW * scale, imgH * scale),
      Paint()..filterQuality = FilterQuality.medium,
    );
    _renderMotes(canvas, w, h);
  }

  /// Ambient golden motes drifting towards the viewer over the valley.
  void _renderMotes(Canvas canvas, double w, double h) {
    final t = game.elapsedSeconds;
    final paint = Paint()
      ..color = const Color(0x33FFD166)
      ..blendMode = BlendMode.plus;
    for (final mote in _motes) {
      final cycle = (t * 0.021 * mote.speed + mote.phase) % 1.0;
      final fade = math.sin(cycle * math.pi); // fade in/out over the fall
      final yF = 0.22 + 0.74 * cycle; // sky band down to below the path
      final wobble = math.sin(t * 0.6 * mote.speed + mote.phase * 6.28) * 8;
      paint.color = Color.fromARGB(
        (0x33 * fade).round(),
        0xFF,
        0xD1,
        0x66,
      );
      canvas.drawCircle(
        Offset(mote.x * w + wobble, yF * h),
        mote.radius * (0.6 + cycle),
        paint,
      );
    }
  }

  /// The perspective track: trapezoid, lane dividers, flowing depth
  /// stripes and cyan edges. Translucent fill lets the backdrop's valley
  /// floor show through so world and path read as one place.
  void _renderTrack(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    final spanToPlayer = math.max(1.0, game.playerPlaneY - horizonY);
    final aMax = (h - horizonY) / spanToPlayer;
    final cx = w / 2;
    final halfTop = game.halfWidthForDepth(1);
    final halfPlayer = game.halfWidthForDepth(0);
    // Extrapolate the exact linear-in-approach cone past playerPlaneY
    // (0.86h) to the screen bottom (1.00h) so track and entity projection
    // stay 1:1 aligned at every depth while filling the lower frame (S11).
    final halfBottom = halfTop + (halfPlayer - halfTop) * aMax;

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
            // near the horizon the painted world floor shows through so
            // the track visually melts into the selected world's ground;
            // it densifies towards the player for readability (S8).
            Color(GameConfig.trackFillArgbFor(game.selectedWorld))
                .withValues(alpha: 0.25),
            Color(GameConfig.trackFillArgbFor(game.selectedWorld))
                .withValues(alpha: 0.85),
          ],
        ),
    );

    // S11: world-authored orthographic track strip warped with true 2.5D
    // perspective foreshortening across a 12x48 mesh all the way to the
    // screen bottom, with a soft top mist fade into the horizon glow.
    final strip = game.trackStrip;
    if (strip != null && h > horizonY) {
      final trackBounds = Rect.fromLTWH(0, horizonY, w, h - horizonY);
      canvas.saveLayer(trackBounds, Paint());
      _renderStripMesh(
        canvas,
        strip,
        horizonY: horizonY,
        spanToPlayer: spanToPlayer,
        aMax: aMax,
        cx: cx,
        halfTop: halfTop,
        halfPlayer: halfPlayer,
      );
      final curb = Paint()
        ..color = Color(GameConfig.trackEdgeArgbFor(game.selectedWorld))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
          Offset(cx - halfTop, horizonY), Offset(cx - halfBottom, h), curb);
      canvas.drawLine(
          Offset(cx + halfTop, horizonY), Offset(cx + halfBottom, h), curb);
      final fadeEnd = horizonY + (h - horizonY) * 0.06;
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
    }

    // Code-drawn rails only when the authored strip is unavailable: the
    // strip bakes its own rails and drawing both misaligns (S10).
    if (strip == null) {
      final edge = Paint()
        ..color = Color(GameConfig.trackEdgeArgbFor(game.selectedWorld))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
          Offset(cx - halfTop, horizonY), Offset(cx - halfBottom, h), edge);
      canvas.drawLine(
          Offset(cx + halfTop, horizonY), Offset(cx + halfBottom, h), edge);
    }

    // S11: baked rails sit at the lane boundaries (thirds of the strip
    // width), so code lane dividers are fallback-only too.
    if (strip == null) {
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
    }

    // Flowing depth stripes are the fallback motion cue — the authored
    // strip already paints its own flow, so they are skipped with it.
    if (strip == null) {
      final stripe = Paint()
        ..color = Color(GameConfig.trackStripeArgbFor(game.selectedWorld))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      const stripeCount = 9;
      final spacing = GameConfig.trackLength / stripeCount;
      for (var i = 0; i < stripeCount; i++) {
        final phase =
            (game.travelled + i * spacing) % GameConfig.trackLength;
        final depth = 1 - phase / GameConfig.trackLength;
        final y = game.yForDepth(depth);
        if (y <= horizonY + 2 || y >= h - 2) {
          continue;
        }
        final half = game.halfWidthForDepth(depth) * 0.96;
        canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), stripe);
      }
    }
  }

  /// Warps the orthographic strip into the 2.5D track cone as a 12x48
  /// subdivided triangle mesh (S11). Sampling world distance `u` uniformly
  /// and projecting `a = u^perspectiveExponent` locks brick scroll 1:1 to
  /// obstacle/orb motion and compresses stone courses naturally toward the
  /// horizon, while the 12 horizontal subdivisions eliminate affine
  /// trapezoid sawtooth distortion on the baked rails.
  void _renderStripMesh(
    Canvas canvas,
    Image strip, {
    required double horizonY,
    required double spanToPlayer,
    required double aMax,
    required double cx,
    required double halfTop,
    required double halfPlayer,
  }) {
    final stripW = strip.width.toDouble();
    final stripH = strip.height.toDouble();
    final scroll = (game.travelled / GameConfig.trackLength) % 1.0;
    final uMax =
        math.pow(math.max(0.0, aMax), 1 / GameConfig.perspectiveExponent)
            .toDouble();

    var p = 0;
    for (var r = 0; r <= _meshRows; r++) {
      final u = (r / _meshRows) * uMax;
      final a = math.pow(u, GameConfig.perspectiveExponent).toDouble();
      final y = horizonY + spanToPlayer * a;
      final half = halfTop + (halfPlayer - halfTop) * a;
      final v = (u - scroll) * stripH;
      final left = cx - half;
      final width = half * 2;
      for (var c = 0; c <= _meshCols; c++) {
        final fx = c / _meshCols;
        _meshPos[p] = left + width * fx;
        _meshPos[p + 1] = y;
        _meshTex[p] = stripW * fx;
        _meshTex[p + 1] = v;
        p += 2;
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

  /// Phase 1 placeholder environment (canvas only): night sky gradient,
  /// stars, sunset glow, parallax ridges, ground. Used when the backdrop
  /// asset is not available.
  void _renderPlaceholderBackdrop(Canvas canvas, double w, double h) {
    final horizonY = game.horizonY;
    final cx = w / 2;

    // --- sky gradient ---
    final sky = Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, h),
        const [Color(0xFF0E0920), Color(0xFF1C1236), Color(0xFF33205A)],
        // dart:ui requires explicit colorStops when passing 3+ colors;
        // omitting them throws ArgumentError during paint -> black scene.
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & Size(w, h), sky);

    // --- stars ---
    final starPaint = Paint()..color = const Color(0xAAFFF6E0);
    for (final star in _stars) {
      canvas.drawCircle(Offset(star.dx * w, star.dy * h), 1.2, starPaint);
    }

    // --- sunset glow above the horizon ---
    final glow = Paint()
      ..shader = Gradient.radial(
        Offset(cx, horizonY),
        w * 0.65,
        const [Color(0x55F78DA7), Color(0x00F78DA7)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glow);

    // --- parallax ridge silhouettes (slow = far, faster = nearer) ---
    _drawRidge(canvas, w, horizonY, game.travelled * 0.02, w * 0.34,
        h * 0.05, const Color(0xFF1B1133));
    _drawRidge(canvas, w, horizonY, game.travelled * 0.05, w * 0.26,
        h * 0.028, const Color(0xFF231741));

    // --- ground ---
    canvas.drawRect(Rect.fromLTWH(0, horizonY, w, h - horizonY),
        Paint()..color = const Color(0xFF191028));
  }

  /// Draws one ridge layer: a flat band on the base line plus triangular
  /// peaks scrolling by [offset] so distant terrain drifts sideways.
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

    // base band (keeps the silhouette solid beneath the peaks)
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

/// One ambient luminous mote: fixed horizontal anchor plus a falling
/// cycle (phase/speed/radius) modulated by run time.
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
