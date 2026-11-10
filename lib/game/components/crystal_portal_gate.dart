import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// Stage 3 Colossal Abyssal World-Termination Portal Gateway
/// (`CrystalPortalGate`):
///  * Anchored directly at the broken cliff-edge where the current biome's
///    stone causeway ends into pure cosmic void ("پشتش هیچی نباشد");
///  * Surrounded by counter-rotating celestial astrolabe rings, inward-pulling
///    gravity spears, and crackling dimensional lightning;
///  * Reveals a **live 3D perspective vista of `targetWorld`'s sky AND 3-lane
///    stone highway** waiting inside the portal archway!
class CrystalPortalGate extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  CrystalPortalGate({
    required this.targetWorld,
    double initialDepth = 1.22,
  })  : _depth = initialDepth,
        _prevDepth = initialDepth,
        super(priority: 1000);

  final GameWorld targetWorld;

  double _depth;
  double _prevDepth;
  double _phase = 0;
  bool _triggered = false;

  double get currentDepth => _depth;
  bool get hasTriggered => _triggered;

  Color get _portalAccent {
    switch (targetWorld) {
      case GameWorld.moonveilMarsh:
        return const Color(0xFF56FFF2);
      case GameWorld.emberfallCanyon:
        return const Color(0xFFFFAD48);
      case GameWorld.duskHollow:
        return const Color(0xFFD88CFF);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.bottomCenter;
    _syncPortalSize(game.size);
    _applyProjection();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncPortalSize(size);
    _applyProjection();
  }

  void _syncPortalSize(Vector2 viewport) {
    // Spans the ENTIRE 3-lane stone causeway + flanking parapets edge-to-edge!
    final fullBridgeWidth =
        viewport.x * GameConfig.trackBottomHalfWidthRatio * 2.74;
    size = Vector2(fullBridgeWidth, fullBridgeWidth * 0.80);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * 2.8;
    _prevDepth = _depth;
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    if (!_triggered && _prevDepth >= -0.06 && _depth <= 0.035) {
      _triggered = true;
      game.enterCrystalPortal(targetWorld);
    }

    _applyProjection();

    if (_depth <= -0.34) {
      removeFromParent();
    }
  }

  void _applyProjection() {
    if (_depth > 1.28) {
      scale = Vector2.zero();
      return;
    }
    final sc = game.scaleForDepth(_depth);
    position = Vector2(
      game.trackCenterXForDepth(_depth.clamp(0.0, 1.28).toDouble()),
      game.yForDepth(_depth) + size.y * sc * 0.058,
    );
    scale = Vector2.all(sc);

    final newPriority =
        _depth > 0.018 ? (2000 - (_depth * 50).round() * 20) : 2060;
    if (newPriority != priority) {
      priority = newPriority;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_depth > 1.28) {
      return;
    }

    final w = size.x;
    final h = size.y;
    final hRaw = ((1.28 - _depth) / 0.28).clamp(0.0, 1.0).toDouble();
    final horizonAlpha = hRaw * hRaw * (3.0 - 2.0 * hRaw);
    final passFade =
        _depth < 0.0 ? (1.0 + _depth / 0.32).clamp(0.0, 1.0).toDouble() : 1.0;
    final alpha = (horizonAlpha * passFade).clamp(0.0, 1.0).toDouble();
    if (alpha <= 0.01) {
      return;
    }

    final accent = _portalAccent;
    final portalHeart = Offset(w * 0.50, h * 0.60);

    // 1. Colossal Outer Cosmic Supernova Corona & Spinning Astrolabe Rings!
    final outerGlowR = w * 0.56;
    canvas.drawCircle(
      portalHeart,
      outerGlowR,
      Paint()
        ..shader = Gradient.radial(
          portalHeart,
          outerGlowR,
          [
            accent.withValues(alpha: 0.44 * alpha),
            const Color(0xFF7C4DFF).withValues(alpha: 0.20 * alpha),
            const Color(0x00120828),
          ],
          const [0.0, 0.52, 1.0],
        ),
    );

    _renderAstrolabeRingsAndGravitySpears(
      canvas,
      center: portalHeart,
      w: w,
      accent: accent,
      alpha: alpha,
    );

    // 2. Sculpted Ancient Threshold Stone Dais & Crystal Light Pools at Cliff Lip!
    final daisPath = Path()
      ..moveTo(w * 0.08, h * 0.992)
      ..lineTo(w * 0.14, h * 0.952)
      ..lineTo(w * 0.86, h * 0.952)
      ..lineTo(w * 0.92, h * 0.992)
      ..close();
    canvas.drawPath(
      daisPath,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.50, h * 0.952),
          Offset(w * 0.50, h * 0.995),
          [
            const Color(0xFF4C3C74).withValues(alpha: 0.95 * alpha),
            const Color(0xFF1E1438).withValues(alpha: 0.98 * alpha),
          ],
        ),
    );
    canvas.drawLine(
      Offset(w * 0.14, h * 0.954),
      Offset(w * 0.86, h * 0.954),
      Paint()
        ..color = accent.withValues(alpha: 0.85 * alpha)
        ..strokeWidth = 2.6,
    );

    for (final sideX in [w * 0.22, w * 0.50, w * 0.78]) {
      canvas.save();
      canvas.translate(sideX, h * 0.98);
      canvas.scale(1.0, 0.28);
      final rad = w * (sideX == w * 0.50 ? 0.28 : 0.20);
      canvas.drawCircle(
        Offset.zero,
        rad,
        Paint()
          ..shader = Gradient.radial(
            Offset.zero,
            rad,
            [
              accent.withValues(alpha: 0.56 * alpha),
              accent.withValues(alpha: 0.18 * alpha),
              accent.withValues(alpha: 0.0),
            ],
            const [0.0, 0.54, 1.0],
          ),
      );
      canvas.restore();
    }

    // 3. Live Clipped 3D Next-Biome Vista (Sky + Mountains + 3-Lane Highway!)
    // Coordinates mapped directly to `crystal_portal.png`'s solid crystal ring
    // so 0 pixels leak outside the crystal shoulders!
    final doorway = Path()
      ..moveTo(w * 0.320, h * 0.958)
      ..lineTo(w * 0.320, h * 0.56)
      ..quadraticBezierTo(w * 0.370, h * 0.39, w * 0.505, h * 0.34)
      ..quadraticBezierTo(w * 0.640, h * 0.39, w * 0.690, h * 0.56)
      ..lineTo(w * 0.690, h * 0.958)
      ..close();

    canvas.save();
    canvas.clipPath(doorway);
    _renderNextBiome3DVista(canvas, w, h, alpha);
    canvas.restore();

    // 4. Crackling Dimensional Lightning Rim Around the Threshold!
    canvas.drawPath(
      doorway,
      Paint()
        ..color = accent.withValues(alpha: 0.34 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0,
    );
    canvas.drawPath(
      doorway,
      Paint()
        ..color = const Color(0xFFF2FFFF).withValues(alpha: 0.88 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    _renderThresholdLightningArcs(canvas, w, h, accent, alpha);

    // 5. Pre-Rendered 3D Faceted Translucent Crystal Archway (`crystal_portal.png`)
    final sprite = game.crystalPortalSprite;
    if (sprite != null) {
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH(0.0, h * 0.02, w, h * 0.96),
        Paint()
          ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
          ..filterQuality = FilterQuality.medium,
      );
    } else {
      _renderFallbackCrystalFrame(canvas, w, h, alpha);
    }

    // 6. Blazing Keystone Supernova Star at Top Apex!
    final gleam = 0.78 + 0.22 * math.sin(_phase * 3.2);
    final keyCenter = Offset(w * 0.50, h * 0.19);
    final keyR = w * 0.11 * gleam;
    canvas.drawCircle(
      keyCenter,
      keyR,
      Paint()
        ..shader = Gradient.radial(
          keyCenter,
          keyR,
          [
            const Color(0xFFFFFFFF).withValues(alpha: 0.90 * alpha),
            accent.withValues(alpha: 0.46 * alpha),
            accent.withValues(alpha: 0.0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    for (final ang in [0.0, math.pi * 0.5]) {
      final dx = math.cos(ang + _phase * 0.4) * keyR * 1.35;
      final dy = math.sin(ang + _phase * 0.4) * keyR * 1.35;
      canvas.drawLine(
        Offset(keyCenter.dx - dx, keyCenter.dy - dy),
        Offset(keyCenter.dx + dx, keyCenter.dy + dy),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.80 * alpha)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _renderAstrolabeRingsAndGravitySpears(
    Canvas canvas, {
    required Offset center,
    required double w,
    required Color accent,
    required double alpha,
  }) {
    final rOuter = w * 0.43;
    final rInner = w * 0.35;

    final outerPaint = Paint()
      ..color = const Color(0xFFFFD878).withValues(alpha: 0.56 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final innerPaint = Paint()
      ..color = accent.withValues(alpha: 0.66 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final rectOuter = Rect.fromCircle(center: center, radius: rOuter);
    final rectInner = Rect.fromCircle(center: center, radius: rInner);

    for (var i = 0; i < 6; i++) {
      final a0 = _phase * 0.65 + i * (math.pi / 3);
      canvas.drawArc(rectOuter, a0, math.pi * 0.20, false, outerPaint);

      final b0 = -_phase * 0.95 + i * (math.pi / 3);
      canvas.drawArc(rectInner, b0, math.pi * 0.22, false, innerPaint);
    }

    // Inward-streaming anti-gravity spears pulled from the abyss into the gate!
    for (var i = 0; i < 12; i++) {
      final prog = ((_phase * 0.55 + i * 0.0833) % 1.0);
      final ang = i * (math.pi * 2 / 12) + math.sin(_phase * 0.5 + i) * 0.08;
      final dist0 = w * (0.52 - 0.28 * prog);
      final dist1 = dist0 - w * 0.055;
      final fade = math.sin(prog * math.pi) * alpha;
      canvas.drawLine(
        Offset(center.dx + math.cos(ang) * dist0, center.dy + math.sin(ang) * dist0),
        Offset(center.dx + math.cos(ang) * dist1, center.dy + math.sin(ang) * dist1),
        Paint()
          ..color = (i.isEven ? const Color(0xFFFFF4C2) : accent)
              .withValues(alpha: 0.68 * fade)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _renderThresholdLightningArcs(
    Canvas canvas,
    double w,
    double h,
    Color accent,
    double alpha,
  ) {
    final boltPaint = Paint()
      ..color = const Color(0xFFE8FFFF).withValues(alpha: 0.78 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    final haloPaint = Paint()
      ..color = accent.withValues(alpha: 0.42 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    for (var b = 0; b < 3; b++) {
      final yBase = h * (0.44 + b * 0.17);
      final halfSpan = w * (0.14 + b * 0.035);
      final path = Path();
      const steps = 6;
      for (var s = 0; s <= steps; s++) {
        final u = s / steps;
        final x = w * 0.50 - halfSpan + halfSpan * 2 * u;
        final jag = (s == 0 || s == steps)
            ? 0.0
            : math.sin(_phase * 9.5 + b * 2.7 + s * 3.1) * h * 0.022;
        if (s == 0) {
          path.moveTo(x, yBase);
        } else {
          path.lineTo(x, yBase + jag);
        }
      }
      canvas.drawPath(path, haloPaint);
      canvas.drawPath(path, boltPaint);
    }
  }

  /// Renders a LIVE 3D window into `targetWorld` inside the Portal Archway:
  ///  1. `targetWorld` sky dome + celestial Sun/Moon & stars;
  ///  2. `targetWorld` mountain silhouettes;
  ///  3. `targetWorld` 3-lane glowing stone highway waiting on the other side!
  void _renderNextBiome3DVista(
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
    final Color ridgeCol;
    switch (targetWorld) {
      case GameWorld.moonveilMarsh:
        topSky = const Color(0xFF071B28);
        midSky = const Color(0xFF104658);
        botHorizon = const Color(0xFF28A4B2);
        orbCore = const Color(0xFFD8FFFA);
        orbHalo = const Color(0xFF4AF4E6);
        ridgeCol = const Color(0xFF0D3846);
      case GameWorld.emberfallCanyon:
        topSky = const Color(0xFF2A1024);
        midSky = const Color(0xFF8A342C);
        botHorizon = const Color(0xFFFFA44A);
        orbCore = const Color(0xFFFFF6CE);
        orbHalo = const Color(0xFFFF9838);
        ridgeCol = const Color(0xFF682C1E);
      case GameWorld.duskHollow:
        topSky = const Color(0xFF241644);
        midSky = const Color(0xFF6E3A78);
        botHorizon = const Color(0xFFE890A4);
        orbCore = const Color(0xFFFFF2D2);
        orbHalo = const Color(0xFFFFA672);
        ridgeCol = const Color(0xFF462862);
    }

    final vistaRect = Rect.fromLTWH(w * 0.25, h * 0.28, w * 0.50, h * 0.70);
    final portalHorizY = h * 0.67;

    // 1. Target-world sky dome (`backdrop` texture if warm-cached, plus luminous gradient!)
    final targetBackdrop = game.backdropForWorld(targetWorld);
    if (targetBackdrop != null) {
      canvas.drawImageRect(
        targetBackdrop,
        Rect.fromLTWH(
          0,
          0,
          targetBackdrop.width.toDouble(),
          targetBackdrop.height * 0.58,
        ),
        Rect.fromLTWH(w * 0.24, h * 0.28, w * 0.52, portalHorizY - h * 0.26),
        Paint()
          ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
          ..filterQuality = FilterQuality.low,
      );
    } else {
      canvas.drawRect(
        vistaRect,
        Paint()
          ..shader = Gradient.linear(
            Offset(w * 0.50, h * 0.28),
            Offset(w * 0.50, portalHorizY),
            [
              topSky.withValues(alpha: 0.96 * alpha),
              midSky.withValues(alpha: 0.95 * alpha),
              botHorizon.withValues(alpha: 0.95 * alpha),
            ],
            const [0.0, 0.58, 1.0],
          ),
      );
    }

    // Twinkling stars inside the portal cosmos
    for (var i = 0; i < 12; i++) {
      final sx = w * (0.31 + ((i * 0.37) % 1.0) * 0.38);
      final sy = h * (0.33 + ((i * 0.61) % 1.0) * 0.26);
      final tw = 0.45 + 0.55 * math.sin(_phase * 2.0 + i * 1.9);
      canvas.drawCircle(
        Offset(sx, sy),
        (i % 3 == 0) ? 2.2 : 1.4,
        Paint()
          ..color = const Color(0xFFFFFBE8).withValues(alpha: 0.88 * tw * alpha),
      );
    }

    // Glowing next-biome Moon / Sun rising over the next world's horizon!
    final moonCenter = Offset(w * 0.50, h * 0.50);
    final moonR = w * 0.082;
    canvas.drawCircle(
      moonCenter,
      moonR * 2.4,
      Paint()
        ..shader = Gradient.radial(
          moonCenter,
          moonR * 2.4,
          [
            orbHalo.withValues(alpha: 0.62 * alpha),
            orbHalo.withValues(alpha: 0.20 * alpha),
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
            orbCore.withValues(alpha: 0.96 * alpha),
            orbHalo.withValues(alpha: 0.92 * alpha),
          ],
        ),
    );

    // Distant mountain spires of `targetWorld`
    final mtn = Path()
      ..moveTo(w * 0.25, portalHorizY + 2)
      ..lineTo(w * 0.33, portalHorizY - h * 0.09)
      ..lineTo(w * 0.41, portalHorizY - h * 0.03)
      ..lineTo(w * 0.50, portalHorizY - h * 0.015)
      ..lineTo(w * 0.59, portalHorizY - h * 0.04)
      ..lineTo(w * 0.67, portalHorizY - h * 0.10)
      ..lineTo(w * 0.75, portalHorizY + 2)
      ..close();
    canvas.drawPath(mtn, Paint()..color = ridgeCol.withValues(alpha: 0.90 * alpha));

    // Valley floor & Live 3-Lane Next-World Stone Causeway waiting ahead!
    canvas.drawRect(
      Rect.fromLTWH(w * 0.25, portalHorizY, w * 0.50, h * 0.98 - portalHorizY),
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.50, portalHorizY),
          Offset(w * 0.50, h * 0.98),
          [
            botHorizon.withValues(alpha: 0.85 * alpha),
            ridgeCol.withValues(alpha: 0.96 * alpha),
          ],
        ),
    );

    final roadFill =
        Color(GameConfig.trackFillArgbFor(targetWorld) | 0xFF000000);
    final roadEdge =
        Color(GameConfig.trackEdgeArgbFor(targetWorld) | 0xFF000000);
    final laneGlow =
        Color(GameConfig.trackLaneArgbFor(targetWorld) | 0xFF000000);

    final topHalfW = w * 0.042;
    final botHalfW = w * 0.225;
    final roadPoly = Path()
      ..moveTo(w * 0.50 - topHalfW, portalHorizY)
      ..lineTo(w * 0.50 + topHalfW, portalHorizY)
      ..lineTo(w * 0.50 + botHalfW, h * 0.975)
      ..lineTo(w * 0.50 - botHalfW, h * 0.975)
      ..close();
    canvas.drawPath(
      roadPoly,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.50, portalHorizY),
          Offset(w * 0.50, h * 0.975),
          [
            botHorizon.withValues(alpha: 0.92 * alpha),
            roadFill.withValues(alpha: 0.98 * alpha),
          ],
        ),
    );

    // Glowing 3-lane channels & scrolling stone courses inside the portal vista!
    for (final frac in [-1.0, -0.333, 0.333, 1.0]) {
      final isCurb = frac.abs() > 0.9;
      canvas.drawLine(
        Offset(w * 0.50 + topHalfW * frac, portalHorizY),
        Offset(w * 0.50 + botHalfW * frac, h * 0.975),
        Paint()
          ..color = (isCurb ? roadEdge : laneGlow)
              .withValues(alpha: (isCurb ? 0.90 : 0.82) * alpha)
          ..strokeWidth = isCurb ? 2.4 : 1.8,
      );
    }

    final scrollPhase = (_phase * 0.42) % 1.0;
    for (var row = 0; row < 6; row++) {
      final u = ((row + scrollPhase) / 6.0);
      final p = u * u;
      final ry = portalHorizY + (h * 0.975 - portalHorizY) * p;
      final rhw = topHalfW + (botHalfW - topHalfW) * p;
      canvas.drawLine(
        Offset(w * 0.50 - rhw, ry),
        Offset(w * 0.50 + rhw, ry),
        Paint()
          ..color = const Color(0x5518102C).withValues(alpha: 0.45 * p * alpha)
          ..strokeWidth = 1.3,
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
      ..moveTo(w * 0.14, h * 0.97)
      ..lineTo(w * 0.22, h * 0.42)
      ..lineTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.78, h * 0.42)
      ..lineTo(w * 0.86, h * 0.97)
      ..lineTo(w * 0.72, h * 0.97)
      ..lineTo(w * 0.67, h * 0.52)
      ..lineTo(w * 0.50, h * 0.29)
      ..lineTo(w * 0.33, h * 0.52)
      ..lineTo(w * 0.28, h * 0.97)
      ..close();
    canvas.drawPath(
      outer,
      Paint()..color = const Color(0xCC98D8FF).withValues(alpha: alpha),
    );
  }
}
