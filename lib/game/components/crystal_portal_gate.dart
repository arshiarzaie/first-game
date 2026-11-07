import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// S20 3D Faceted Crystal Portal Gateway (`06-22-22.png` -> `06-22-29.png`):
///
/// Spans across the 3-lane stone causeway and renders a **live window into the
/// next biome** (e.g. Moonveil Marsh's giant cyan full moon & starry night sky)
/// clipped inside the translucent crystal archway! When Soul runs through the
/// portal plane (`depth <= 0.03`), the world seamlessly transforms on the fly!
class CrystalPortalGate extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  CrystalPortalGate({
    required this.targetWorld,
    double initialDepth = 1.06,
  })  : _depth = initialDepth,
        super(priority: 1000);

  final GameWorld targetWorld;

  double _depth;
  double _phase = 0;
  bool _triggered = false;

  double get currentDepth => _depth;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.bottomCenter;
    final fullBridgeWidth =
        game.size.x * GameConfig.trackBottomHalfWidthRatio * 2.16;
    size = Vector2(fullBridgeWidth, fullBridgeWidth * 0.75);
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * 2.6;
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    if (!_triggered && _depth <= 0.03) {
      _triggered = true;
      game.enterCrystalPortal(targetWorld);
    }

    if (_depth <= -0.22) {
      removeFromParent();
      return;
    }
    _applyProjection();
  }

  void _applyProjection() {
    if (_depth > 1.08) {
      scale = Vector2.zero();
      return;
    }
    final sc = game.scaleForDepth(_depth);
    position = Vector2(
      game.trackCenterXForDepth(_depth.clamp(-0.22, 1.05).toDouble()),
      game.yForDepth(_depth) + size.y * sc * 0.015,
    );
    scale = Vector2.all(sc);

    // Stay behind Soul (`priority < 2000`) while Soul approaches (`06-22-22`),
    // then sweep overhead (`2050`) right as Soul passes under the keystone!
    priority = _depth > 0.015 ? ((2.0 - _depth) * 1000).round() : 2050;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_depth > 1.08) {
      return;
    }

    final w = size.x;
    final h = size.y;
    final horizonAlpha = ((1.08 - _depth) / 0.14).clamp(0.0, 1.0).toDouble();
    final passFade =
        _depth < 0.0 ? (1.0 + _depth / 0.22).clamp(0.0, 1.0).toDouble() : 1.0;
    final alpha = (horizonAlpha * passFade).clamp(0.0, 1.0).toDouble();
    if (alpha <= 0.01) {
      return;
    }

    // 1. Icy-cyan & lavender crystal light pools on the flagstones under left & right bases!
    for (final sideX in [w * 0.23, w * 0.77]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sideX, h * 0.98),
          width: w * 0.34,
          height: h * 0.10,
        ),
        Paint()
          ..color = const Color(0xFF66F4FF).withValues(alpha: 0.36 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
      );
    }

    // 2. Live Clipped Preview of `targetWorld` Inside the Pointed Crystal Archway!
    final doorway = Path()
      ..moveTo(w * 0.295, h * 0.982)
      ..lineTo(w * 0.335, h * 0.56)
      ..quadraticBezierTo(w * 0.41, h * 0.36, w * 0.50, h * 0.33)
      ..quadraticBezierTo(w * 0.59, h * 0.36, w * 0.665, h * 0.56)
      ..lineTo(w * 0.705, h * 0.982)
      ..close();

    canvas.save();
    canvas.clipPath(doorway);
    _renderNextBiomeWindow(canvas, w, h, alpha);
    canvas.restore();

    // Shimmering inner rim around the portal threshold
    canvas.drawPath(
      doorway,
      Paint()
        ..color = const Color(0xFFAAF8FF).withValues(alpha: 0.52 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    // 3. Pre-Rendered 3D Faceted Translucent Crystal Archway (`crystal_portal.png`)
    final sprite = game.crystalPortalSprite;
    if (sprite != null) {
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
          ..filterQuality = FilterQuality.medium,
      );
    } else {
      _renderFallbackCrystalFrame(canvas, w, h, alpha);
    }

    // 4. Pulsing diamond keystone gleam at top peak (`06-22-22.png`)!
    final gleam = 0.72 + 0.28 * math.sin(_phase * 2.2);
    final keyCenter = Offset(w * 0.50, h * 0.21);
    final keyR = w * 0.085 * gleam;
    canvas.drawCircle(
      keyCenter,
      keyR,
      Paint()
        ..shader = Gradient.radial(
          keyCenter,
          keyR,
          [
            const Color(0xFFFFFFFF).withValues(alpha: 0.76 * alpha),
            const Color(0xFF7AF6FF).withValues(alpha: 0.34 * alpha),
            const Color(0x007AF6FF),
          ],
          const [0.0, 0.48, 1.0],
        ),
    );
  }

  void _renderNextBiomeWindow(
    Canvas canvas,
    double w,
    double h,
    double alpha,
  ) {
    final Color topSky;
    final Color midSky;
    final Color botHorizon;
    final Color orbCore;
    final Color orbHalo;
    switch (targetWorld) {
      case GameWorld.moonveilMarsh:
        topSky = const Color(0xFF071B28);
        midSky = const Color(0xFF104658);
        botHorizon = const Color(0xFF228C9A);
        orbCore = const Color(0xFFD8FFFA);
        orbHalo = const Color(0xFF4AF4E6);
      case GameWorld.emberfallCanyon:
        topSky = const Color(0xFF2A1024);
        midSky = const Color(0xFF7A2E2E);
        botHorizon = const Color(0xFFE68A3E);
        orbCore = const Color(0xFFFFF6CE);
        orbHalo = const Color(0xFFFF9838);
      case GameWorld.duskHollow:
        topSky = const Color(0xFF241644);
        midSky = const Color(0xFF68366E);
        botHorizon = const Color(0xFFD87E98);
        orbCore = const Color(0xFFFFF2D2);
        orbHalo = const Color(0xFFFFA672);
    }

    final rect = Rect.fromLTWH(w * 0.26, h * 0.30, w * 0.48, h * 0.70);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.50, h * 0.32),
          Offset(w * 0.50, h * 0.98),
          [
            topSky.withValues(alpha: 0.94 * alpha),
            midSky.withValues(alpha: 0.92 * alpha),
            botHorizon.withValues(alpha: 0.90 * alpha),
          ],
          const [0.0, 0.58, 1.0],
        ),
    );

    // Twinkling stars inside the portal cosmos (`06-22-22.png`)!
    for (var i = 0; i < 10; i++) {
      final sx = w * (0.34 + ((i * 0.37) % 1.0) * 0.32);
      final sy = h * (0.38 + ((i * 0.61) % 1.0) * 0.42);
      final tw = 0.45 + 0.55 * math.sin(_phase * 1.8 + i * 1.9);
      canvas.drawCircle(
        Offset(sx, sy),
        (i % 3 == 0) ? 2.2 : 1.4,
        Paint()
          ..color = const Color(0xFFFFFBE8).withValues(alpha: 0.85 * tw * alpha),
      );
    }

    // Glowing next-biome Moon / Sun rising inside the portal base (`06-22-22.png`)!
    final moonCenter = Offset(w * 0.51, h * 0.92);
    final moonR = w * 0.095;
    canvas.drawCircle(
      moonCenter,
      moonR * 2.2,
      Paint()
        ..shader = Gradient.radial(
          moonCenter,
          moonR * 2.2,
          [
            orbHalo.withValues(alpha: 0.56 * alpha),
            orbHalo.withValues(alpha: 0.16 * alpha),
            orbHalo.withValues(alpha: 0.0),
          ],
          const [0.0, 0.52, 1.0],
        ),
    );
    canvas.drawCircle(
      moonCenter,
      moonR,
      Paint()
        ..shader = Gradient.radial(
          Offset(moonCenter.dx - moonR * 0.2, moonCenter.dy - moonR * 0.2),
          moonR * 1.2,
          [
            orbCore.withValues(alpha: 0.95 * alpha),
            orbHalo.withValues(alpha: 0.92 * alpha),
          ],
        ),
    );

    // Swirling vertical portal veil streaks
    for (var s = 0; s < 3; s++) {
      final vx = w * (0.40 + s * 0.10) + math.sin(_phase + s * 2.0) * w * 0.02;
      canvas.drawLine(
        Offset(vx, h * 0.44),
        Offset(vx, h * 0.95),
        Paint()
          ..color = const Color(0xFFA8F8FF).withValues(alpha: 0.20 * alpha)
          ..strokeWidth = w * 0.025
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
      );
    }
  }

  void _renderFallbackCrystalFrame(
    Canvas canvas,
    double w,
    double h,
    double alpha,
  ) {
    final outer = Path()
      ..moveTo(w * 0.16, h * 0.98)
      ..lineTo(w * 0.24, h * 0.44)
      ..lineTo(w * 0.50, h * 0.08)
      ..lineTo(w * 0.76, h * 0.44)
      ..lineTo(w * 0.84, h * 0.98)
      ..lineTo(w * 0.70, h * 0.98)
      ..lineTo(w * 0.65, h * 0.52)
      ..lineTo(w * 0.50, h * 0.34)
      ..lineTo(w * 0.35, h * 0.52)
      ..lineTo(w * 0.30, h * 0.98)
      ..close();
    canvas.drawPath(
      outer,
      Paint()..color = const Color(0xCC98D8FF).withValues(alpha: alpha),
    );
  }
}
