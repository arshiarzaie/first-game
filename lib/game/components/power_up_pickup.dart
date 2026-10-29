import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/power_up_system.dart';

/// Collectible on-track Subway-style power-up emblem (S12):
///  * [PowerUpKind.magnet] — cyan-gold solar attractor ring;
///  * [PowerUpKind.multiplier2x] — blazing 2x sun crest;
///  * [PowerUpKind.solarDash] — winged golden sky-comet.
class PowerUpPickup extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  PowerUpPickup({
    required this.lane,
    required this.kind,
    double initialDepth = 1.0,
  })  : _depth = initialDepth,
        super(priority: 12);

  final int lane;
  final PowerUpKind kind;
  double _depth;
  double _phase = 0;
  bool _collected = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.entityWidthRatio * 0.95;
    size = Vector2.all(width);
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * 4.5;
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    if (!_collected && _depth <= 0.08 && _depth >= -0.06) {
      final laneDiff = (game.player.currentLane - lane).abs();
      if (laneDiff < 0.62) {
        _collected = true;
        game.onPowerUpCollected(kind, position.clone());
        removeFromParent();
        return;
      }
    }

    if (_depth <= -0.14) {
      removeFromParent();
      return;
    }
    _applyProjection();
  }

  void _applyProjection() {
    final bob = math.sin(_phase) * size.y * 0.06;
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth) - size.y * 0.22 + bob,
    );
    scale = Vector2.all(game.scaleForDepth(_depth));
    priority = (6 + (1.0 - _depth) * 18).round();
  }

  Color get _accentColor {
    switch (kind) {
      case PowerUpKind.magnet:
        return const Color(0xFF4DD8FF);
      case PowerUpKind.multiplier2x:
        return const Color(0xFFFFB300);
      case PowerUpKind.solarDash:
        return const Color(0xFFFF6D00);
    }
  }

  String get _glyph {
    switch (kind) {
      case PowerUpKind.magnet:
        return 'U';
      case PowerUpKind.multiplier2x:
        return '2x';
      case PowerUpKind.solarDash:
        return '★';
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final c = Offset(w / 2, w / 2);
    final pulse = 1 + math.sin(_phase * 1.3) * 0.08;
    final accent = _accentColor;

    // Outer additive beacon halo.
    canvas.drawCircle(
      c,
      w * 0.52 * pulse,
      Paint()
        ..color = accent.withValues(alpha: 0.34)
        ..blendMode = BlendMode.plus,
    );

    // Dark twilight diamond medallion with bright rim.
    final r = w * 0.36 * pulse;
    final diamond = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = const Color(0xEE1A1030));
    canvas.drawPath(
      diamond,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055,
    );
    canvas.drawCircle(
      c,
      r * 0.72,
      Paint()
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.22)
        ..blendMode = BlendMode.plus,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: _glyph,
        style: TextStyle(
          color: const Color(0xFFFFF3D1),
          fontSize: w * 0.30,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }
}
