import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/power_up_system.dart';

/// Collectible on-track Subway-style power-up emblem (S13: horizon-queued with
/// smooth `1 / Z` projection).
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
    final width = game.size.x * GameConfig.entityWidthRatio * 0.90;
    size = Vector2.all(width);
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * 4.5;
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    if (!_collected && _depth <= 0.075 && _depth >= -0.055) {
      final laneDiff = (game.player.currentLane - lane).abs();
      if (laneDiff < 0.56) {
        _collected = true;
        game.onPowerUpCollected(kind, position.clone());
        removeFromParent();
        return;
      }
    }

    if (_depth <= -0.15) {
      removeFromParent();
      return;
    }
    _applyProjection();
  }

  void _applyProjection() {
    if (_depth > 1.02) {
      scale = Vector2.zero();
      return;
    }
    final sc = game.scaleForDepth(_depth);
    final bob = math.sin(_phase) * size.y * 0.06 * sc;
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth) - size.y * 0.34 * sc + bob,
    );
    scale = Vector2.all(sc);
    priority = (6 + (1.0 - _depth).clamp(0.0, 1.0) * 16).round();
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
    if (_depth > 1.02) {
      return;
    }
    final w = size.x;
    final c = Offset(w / 2, w / 2);
    final pulse = 1 + math.sin(_phase * 1.3) * 0.08;
    final accent = _accentColor;
    final horizonAlpha = ((1.02 - _depth) / 0.10).clamp(0.0, 1.0);

    canvas.drawCircle(
      c,
      w * 0.50 * pulse,
      Paint()
        ..color = accent.withValues(alpha: 0.32 * horizonAlpha)
        ..blendMode = BlendMode.plus,
    );

    final r = w * 0.35 * pulse;
    final diamond = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..color = const Color(0xEE1A1030).withValues(alpha: 0.92 * horizonAlpha),
    );
    canvas.drawPath(
      diamond,
      Paint()
        ..color = accent.withValues(alpha: horizonAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: _glyph,
        style: TextStyle(
          color: const Color(0xFFFFF3D1).withValues(alpha: horizonAlpha),
          fontSize: w * 0.29,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }
}
