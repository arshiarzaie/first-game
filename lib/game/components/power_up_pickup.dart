import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/power_up_system.dart';

/// Collectible on-track Subway-Surfers power-up badge (S15: Magnet, 2x Surge,
/// Jetpack Sky-Dash, and Super Sneakers).
class PowerUpPickup extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  PowerUpPickup({
    required this.lane,
    required this.kind,
    double initialDepth = 1.0,
    this.elevation = 0.0,
  })  : _depth = initialDepth,
        super(priority: 1000);

  final int lane;
  final PowerUpKind kind;
  final double elevation;
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
      final elevDiff = (elevation - game.effectivePlayerElevation).abs();
      if (laneDiff < 0.56 && elevDiff < 0.72) {
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
    final bob = math.sin(_phase) * size.y * 0.05 * sc;
    final lift = elevation * game.size.y * GameConfig.jumpHeightRatio * sc;
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth) - size.y * 0.36 * sc - lift + bob,
    );
    scale = Vector2.all(sc);
    priority = ((2.0 - _depth) * 1000).round();
  }

  Color get _accentColor {
    switch (kind) {
      case PowerUpKind.magnet:
        return const Color(0xFF2898D8);
      case PowerUpKind.multiplier2x:
        return const Color(0xFFF5A623);
      case PowerUpKind.solarDash:
        return const Color(0xFFE8563A);
      case PowerUpKind.superSneakers:
        return const Color(0xFF34B864);
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
      case PowerUpKind.superSneakers:
        return '▲';
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
    final pulse = 1 + math.sin(_phase * 1.3) * 0.06;
    final accent = _accentColor;
    final horizonAlpha = ((1.02 - _depth) / 0.10).clamp(0.0, 1.0).toDouble();

    canvas.drawCircle(
      c,
      w * 0.44 * pulse,
      Paint()..color = accent.withValues(alpha: 0.25 * horizonAlpha),
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
        ..color = const Color(0xF01C2C44).withValues(alpha: 0.94 * horizonAlpha),
    );
    canvas.drawPath(
      diamond,
      Paint()
        ..color = accent.withValues(alpha: horizonAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: _glyph,
        style: TextStyle(
          color: const Color(0xFFFFF8E8).withValues(alpha: horizonAlpha),
          fontSize: w * 0.29,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }
}
