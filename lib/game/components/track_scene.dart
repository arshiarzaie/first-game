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
    _renderTrack(canvas, w, h);
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
