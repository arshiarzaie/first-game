import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// Greybox environment: night sky, stars, sunset glow, parallax ridge
/// silhouettes, and the perspective track with depth stripes flowing towards
/// the player. Everything is drawn with the Canvas — no image assets.
///
/// Colors come from Soul's palette family (deep violet night, pink sunset
/// glow, restrained cyan accents) so the golden player stays the warm focal
/// point even in placeholder form.
class TrackScene extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  TrackScene() : super(priority: -100);

  late final List<Offset> _stars = _makeStars();

  static List<Offset> _makeStars() {
    final random = math.Random(7);
    return List<Offset>.generate(
      28,
      (_) => Offset(random.nextDouble(), random.nextDouble() * 0.24),
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
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size = gameSize.clone();
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

    final horizonY = game.horizonY;
    final cx = w / 2;

    // --- sky gradient ---
    final sky = Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, h),
        const [Color(0xFF0E0920), Color(0xFF1C1236), Color(0xFF33205A)],
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

    // --- track trapezoid ---
    final halfTop = game.halfWidthForDepth(1);
    final halfBottom = game.halfWidthForDepth(0);
    final track = Path()
      ..moveTo(cx - halfTop, horizonY)
      ..lineTo(cx + halfTop, horizonY)
      ..lineTo(cx + halfBottom, h)
      ..lineTo(cx - halfBottom, h)
      ..close();
    canvas.drawPath(track, Paint()..color = const Color(0xFF2A1B4A));

    // --- cyan track edges ---
    final edge = Paint()
      ..color = const Color(0x884DD8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(cx - halfTop, horizonY), Offset(cx - halfBottom, h), edge);
    canvas.drawLine(
        Offset(cx + halfTop, horizonY), Offset(cx + halfBottom, h), edge);

    // --- lane dividers ---
    final lanePaint = Paint()
      ..color = const Color(0x554DD8FF)
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

    // --- depth stripes flowing towards the player (speed illusion) ---
    final stripe = Paint()
      ..color = const Color(0x446E64A8)
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
