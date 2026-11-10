import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/power_up_system.dart';

/// Stage 4 Sculpted 3D Fantasy Relic Power-Up (`PowerUpPickup`):
///  * Replaces the flat 2D diamond prototype with a **levitating 8-facet 3D
///    octahedral crystal relic**, counter-rotating celestial astrolabe ring,
///    orbiting stardust motes, grounded road rune-shadow, and bespoke vector
///    emblems (`Lodestone`, `Twin-Sun 2x`, `Solar Sunburst`, `Zephyr Wings`);
///  * Zero `MaskFilter.blur` & cached `TextPainter` for locked 60/120fps;
///  * Smoothstep horizon emergence + swept depth-crossing pickup check.
class PowerUpPickup extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  PowerUpPickup({
    required this.lane,
    required this.kind,
    double initialDepth = 1.0,
    this.elevation = 0.0,
    this.fadeInSeconds = 0.0,
  })  : _depth = initialDepth,
        _prevDepth = initialDepth,
        super(priority: 1000);

  final int lane;
  final PowerUpKind kind;
  final double elevation;
  final double fadeInSeconds;

  double _depth;
  double _prevDepth;
  double _phase = 0;
  double _aliveSeconds = 0;
  bool _collected = false;
  TextPainter? _badgePainter;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.entityWidthRatio * 0.96;
    size = Vector2.all(width);
    if (kind == PowerUpKind.multiplier2x) {
      _badgePainter = TextPainter(
        text: TextSpan(
          text: '2×',
          style: TextStyle(
            color: const Color(0xFFFFFDF4),
            fontSize: width * 0.25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _aliveSeconds += dt;
    _phase += dt * 4.2;
    _prevDepth = _depth;
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    if (!_collected && _prevDepth >= -0.055 && _depth <= 0.075) {
      final laneDiff = (game.player.currentLane - lane).abs();
      final elevDiff = (elevation - game.effectivePlayerElevation).abs();
      if (laneDiff < 0.56 && elevDiff < 0.72) {
        _collected = true;
        game.onPowerUpCollected(kind, position.clone());
        removeFromParent();
        return;
      }
    }

    _applyProjection();

    if (_depth < -0.06) {
      final topScreenY = position.y - size.y * scale.y * 0.68;
      if (topScreenY > game.size.y + 24 || _depth <= -0.45) {
        removeFromParent();
      }
    }
  }

  void _applyProjection() {
    if (_depth > 1.28) {
      scale = Vector2.zero();
      return;
    }
    final sc = game.scaleForDepth(_depth);
    final bob = math.sin(_phase) * size.y * 0.055 * sc;
    final lift = elevation * game.size.y * GameConfig.jumpHeightRatio * sc;
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth) - size.y * 0.42 * sc - lift + bob,
    );
    scale = Vector2.all(sc);

    final newPriority = 2000 - (_depth * 50).round() * 20;
    if (newPriority != priority) {
      priority = newPriority;
    }
  }

  /// Palette tuple: `(highlight, primaryAccent, midFacet, deepShadow)`
  (Color, Color, Color, Color) get _gemPalette {
    switch (kind) {
      case PowerUpKind.magnet:
        return (
          const Color(0xFFF3D9FF),
          const Color(0xFFC47AFF),
          const Color(0xFF7B38D8),
          const Color(0xFF391472),
        );
      case PowerUpKind.multiplier2x:
        return (
          const Color(0xFFFFF6C8),
          const Color(0xFFFFCC48),
          const Color(0xFFD88418),
          const Color(0xFF6E3608),
        );
      case PowerUpKind.solarDash:
        return (
          const Color(0xFFFFF2C2),
          const Color(0xFFFF8838),
          const Color(0xFFD93E26),
          const Color(0xFF68141C),
        );
      case PowerUpKind.superSneakers:
        return (
          const Color(0xFFD8FFF8),
          const Color(0xFF4CF5DC),
          const Color(0xFF14A8A0),
          const Color(0xFF0A4A54),
        );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_depth > 1.28) {
      return;
    }
    final hRaw = ((1.28 - _depth) / 0.30).clamp(0.0, 1.0).toDouble();
    final horizonAlpha = hRaw * hRaw * (3.0 - 2.0 * hRaw);
    final spawnAlpha = fadeInSeconds > 0.0
        ? (_aliveSeconds / fadeInSeconds).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final nearAlpha = _depth < -0.30
        ? ((_depth + 0.44) / 0.14).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final alpha =
        (horizonAlpha * spawnAlpha * nearAlpha).clamp(0.0, 1.0).toDouble();
    if (alpha <= 0.01) {
      return;
    }

    final w = size.x;
    final c = Offset(w * 0.5, w * 0.5);
    final pulse = 1.0 + math.sin(_phase * 1.35) * 0.055;
    final (hiCol, accent, midCol, deepCol) = _gemPalette;

    // 1. Grounded Arcane Rune Light-Pool on the stone causeway below!
    final bobLocal = math.sin(_phase) * w * 0.055;
    final dropPx =
        w * 0.42 + elevation * game.size.y * GameConfig.jumpHeightRatio - bobLocal;
    final groundCenter = Offset(c.dx, c.dy + dropPx);
    canvas.save();
    canvas.translate(groundCenter.dx, groundCenter.dy);
    canvas.scale(1.0, 0.28);
    final poolR = w * 0.44;
    canvas.drawCircle(
      Offset.zero,
      poolR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.46 * alpha),
            const Color(0xFF120824).withValues(alpha: 0.30 * alpha),
            accent.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: poolR)),
    );
    canvas.drawCircle(
      Offset.zero,
      poolR * 0.62,
      Paint()
        ..color = hiCol.withValues(alpha: 0.52 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.restore();

    // 2. Soft Volumetric Relic Halo + Counter-Rotating Astrolabe Ring!
    final haloR = w * 0.50 * pulse;
    canvas.drawCircle(
      c,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            hiCol.withValues(alpha: 0.52 * alpha),
            accent.withValues(alpha: 0.26 * alpha),
            accent.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: haloR)),
    );

    final ringRect = Rect.fromCircle(center: c, radius: w * 0.41 * pulse);
    final arcPaint = Paint()
      ..color = hiCol.withValues(alpha: 0.78 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.026).clamp(1.3, 3.0).toDouble()
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a0 = _phase * 0.85 + i * (math.pi * 0.5);
      canvas.drawArc(ringRect, a0, math.pi * 0.24, false, arcPaint);
    }

    // 3. Sculpted 8-Facet 3D Octahedral Relic Crystal!
    final rx = w * 0.30 * pulse;
    final ry = w * 0.38 * pulse;
    final swayX = math.sin(_phase * 0.9) * rx * 0.10;
    final top = Offset(c.dx, c.dy - ry);
    final bot = Offset(c.dx, c.dy + ry);
    final left = Offset(c.dx - rx, c.dy);
    final right = Offset(c.dx + rx, c.dy);
    final waistL = Offset(c.dx - rx * 0.36 + swayX, c.dy - ry * 0.06);
    final waistR = Offset(c.dx + rx * 0.36 + swayX, c.dy - ry * 0.06);

    void fillTri(Offset a, Offset b, Offset d, Color col) {
      final p = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(d.dx, d.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = col.withValues(alpha: 0.95 * alpha));
    }

    // Upper 3 crown facets (bright key-lit left, incandescent center, mid right)
    fillTri(top, left, waistL, hiCol);
    fillTri(top, waistL, waistR, accent);
    fillTri(top, waistR, right, midCol);

    // Lower 3 pavilion facets (warm bounce left, rich core center, deep shadow right)
    fillTri(bot, waistL, left, accent);
    fillTri(bot, waistR, waistL, midCol);
    fillTri(bot, right, waistR, deepCol);

    // Inner glowing cabochon jewel heart table
    final heartR = w * 0.19 * pulse;
    canvas.drawCircle(
      c,
      heartR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            midCol.withValues(alpha: 0.92 * alpha),
            deepCol.withValues(alpha: 0.96 * alpha),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: heartR)),
    );
    canvas.drawCircle(
      c,
      heartR,
      Paint()
        ..color = hiCol.withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.024).clamp(1.2, 2.6).toDouble(),
    );

    // Crisp outer diamond bevel highlight
    final outline = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bot.dx, bot.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.88 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.028).clamp(1.3, 3.0).toDouble(),
    );

    // 4. Bespoke Iconic 3D Relic Emblem Inside the Heart Table!
    _renderRelicEmblem(canvas, c, w * pulse, hiCol, accent, alpha);

    // 5. Orbiting starlight motes
    for (var i = 0; i < 3; i++) {
      final ang = -_phase * 1.4 + i * (math.pi * 2 / 3);
      final mx = c.dx + math.cos(ang) * w * 0.42;
      final my = c.dy + math.sin(ang) * w * 0.28;
      canvas.drawCircle(
        Offset(mx, my),
        (w * 0.032).clamp(1.4, 3.6).toDouble(),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.90 * alpha),
      );
    }
  }

  void _renderRelicEmblem(
    Canvas canvas,
    Offset c,
    double s,
    Color hiCol,
    Color accent,
    double alpha,
  ) {
    final whitePaint = Paint()
      ..color = const Color(0xFFFFFEF8).withValues(alpha: 0.96 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.042).clamp(1.6, 4.2).toDouble()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case PowerUpKind.magnet:
        // Astral U-Lodestone Horseshoe + glowing twin pole tips!
        final r = s * 0.095;
        final uPath = Path()
          ..moveTo(c.dx - r, c.dy - r * 0.85)
          ..lineTo(c.dx - r, c.dy + r * 0.15)
          ..arcToPoint(
            Offset(c.dx + r, c.dy + r * 0.15),
            radius: Radius.circular(r),
            clockwise: false,
          )
          ..lineTo(c.dx + r, c.dy - r * 0.85);
        canvas.drawPath(uPath, whitePaint);
        final tipPaint = Paint()
          ..color = const Color(0xFF7AF8FF).withValues(alpha: alpha);
        canvas.drawCircle(Offset(c.dx - r, c.dy - r * 0.88), r * 0.34, tipPaint);
        canvas.drawCircle(Offset(c.dx + r, c.dy - r * 0.88), r * 0.34, tipPaint);

      case PowerUpKind.multiplier2x:
        final tp = _badgePainter;
        if (tp != null) {
          if (alpha < 0.99) {
            canvas.saveLayer(
              Rect.fromCenter(
                center: c,
                width: tp.width + 6,
                height: tp.height + 6,
              ),
              Paint()
                ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255),
            );
            tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
            canvas.restore();
          } else {
            tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
          }
        }

      case PowerUpKind.solarDash:
        // 8-Rayed Blazing Solar Starburst!
        final rIn = s * 0.065;
        final rOut = s * 0.145;
        final rayPaint = Paint()
          ..color = hiCol.withValues(alpha: 0.95 * alpha)
          ..strokeWidth = (s * 0.026).clamp(1.2, 2.8).toDouble()
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = i * (math.pi / 4) + _phase * 0.5;
          final len = i.isEven ? rOut : rOut * 0.78;
          canvas.drawLine(
            Offset(c.dx + math.cos(a) * rIn * 0.6, c.dy + math.sin(a) * rIn * 0.6),
            Offset(c.dx + math.cos(a) * len, c.dy + math.sin(a) * len),
            rayPaint,
          );
        }
        canvas.drawCircle(
          c,
          rIn,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.98 * alpha),
        );

      case PowerUpKind.superSneakers:
        // Twin Swept Sky-Wings + Ascending Chevron!
        final r = s * 0.125;
        final chev1 = Path()
          ..moveTo(c.dx - r, c.dy + r * 0.25)
          ..lineTo(c.dx, c.dy - r * 0.65)
          ..lineTo(c.dx + r, c.dy + r * 0.25);
        final chev2 = Path()
          ..moveTo(c.dx - r * 0.68, c.dy + r * 0.82)
          ..lineTo(c.dx, c.dy + r * 0.14)
          ..lineTo(c.dx + r * 0.68, c.dy + r * 0.82);
        canvas.drawPath(chev1, whitePaint);
        canvas.drawPath(
          chev2,
          Paint()
            ..color = accent.withValues(alpha: 0.95 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (s * 0.032).clamp(1.3, 3.2).toDouble()
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
    }
  }
}
