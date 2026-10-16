import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// Dusk Hollow environment (World 1, P2 visual slice): the pre-rendered
/// violet-twilight valley backdrop is drawn cover-fit with its painted
/// horizon anchored to the game's horizon line, breathing gently and
/// swaying opposite the player's lane for camera parallax. The code-drawn
/// perspective track, lane dividers, flowing depth stripes and restrained
/// cyan edges stay — gameplay projection is untouched. Ambient luminous
/// motes drift over the valley to match the baked-in particles.
///
/// When the backdrop image is unavailable the component renders the
/// Phase 1 canvas placeholder sky/ridges instead (never a black scene).
class TrackScene extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  TrackScene() : super(priority: -100);

  late final List<Offset> _stars = _makeStars();
  late final List<_Mote> _motes = _makeMotes();

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

    final backdrop = game.duskHollowBackdrop;
    if (backdrop != null) {
      _renderDuskHollow(canvas, w, h, backdrop);
    } else {
      _renderPlaceholderBackdrop(canvas, w, h);
    }
    _renderTrack(canvas, w, h);
  }

  /// Cover-fits the matte painting so the whole screen stays painted,
  /// anchors its painted horizon near the game horizon, adds breathing
  /// drift and lane-opposed camera sway.
  void _renderDuskHollow(Canvas canvas, double w, double h, Image backdrop) {
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
    var dy = horizonY - imgH * GameConfig.backdropHorizonFraction * scale + drift;
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
    final cx = w / 2;
    final halfTop = game.halfWidthForDepth(1);
    final halfBottom = game.halfWidthForDepth(0);

    final track = Path()
      ..moveTo(cx - halfTop, horizonY)
      ..lineTo(cx + halfTop, horizonY)
      ..lineTo(cx + halfBottom, h)
      ..lineTo(cx - halfBottom, h)
      ..close();
    canvas.drawPath(track, Paint()..color = const Color(0xB3241738));

    final edge = Paint()
      ..color = const Color(0x884DD8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(cx - halfTop, horizonY), Offset(cx - halfBottom, h), edge);
    canvas.drawLine(
        Offset(cx + halfTop, horizonY), Offset(cx + halfBottom, h), edge);

    final lanePaint = Paint()
      ..color = const Color(0x444DD8FF)
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
      ..color = const Color(0x44806FB8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const stripeCount = 9;
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
