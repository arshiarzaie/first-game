import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// Collectible golden sun-energy orb (S13: horizon-smooth fade-in, true `1 / Z`
/// perspective scaling, parabolic jump-reward arcs, and Sun Magnet pull).
class EnergyOrb extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  EnergyOrb({
    required this.lane,
    double initialDepth = 1.0,
    this.elevation = 0.0,
  })  : _depth = initialDepth,
        _currentLane = lane.toDouble(),
        _currentElevation = elevation,
        super(priority: 9);

  final int lane;
  final double elevation;

  double _depth;
  double _currentLane;
  double _currentElevation;
  double _pulsePhase = 0;
  bool _collected = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    final width = game.size.x * GameConfig.entityWidthRatio * 0.72;
    size = Vector2.all(width);
    _pulsePhase = (_depth * 9.0) % (math.pi * 2);
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 4.5;
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    final magnetized =
        game.powerUps.hasMagnet || game.powerUps.isSolarDashing;
    if (magnetized && _depth <= 0.56 && _depth >= -0.06) {
      final pull = (dt * 10.0).clamp(0.0, 1.0);
      _currentLane += (game.player.currentLane - _currentLane) * pull;
      _currentElevation +=
          (game.effectivePlayerElevation - _currentElevation) * pull;
    }

    if (!_collected && _depth <= 0.065 && _depth >= -0.050) {
      final laneDiff = (_currentLane - game.player.currentLane).abs();
      final elevDiff =
          (_currentElevation - game.effectivePlayerElevation).abs();
      if ((laneDiff < 0.52 && elevDiff < 0.60) ||
          (magnetized && _depth <= 0.045)) {
        _collected = true;
        game.onOrbCollected(position: position.clone());
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
    final groundY = game.yForDepth(_depth);
    final lift =
        _currentElevation * game.size.y * GameConfig.jumpHeightRatio * sc;
    position = Vector2(
      game.laneXForDepth(_currentLane, _depth),
      groundY - size.y * 0.44 * sc - lift,
    );
    scale = Vector2.all(sc);
    priority = (6 + (1.0 - _depth).clamp(0.0, 1.0) * 14).round();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_depth > 1.02) {
      return;
    }
    final w = size.x;
    final center = Offset(w / 2, w / 2);
    final pulse = 1 + math.sin(_pulsePhase) * 0.06;
    final horizonAlpha = ((1.02 - _depth) / 0.10).clamp(0.0, 1.0);

    if (_currentElevation > 0.08) {
      final dropPx = _currentElevation * game.size.y * GameConfig.jumpHeightRatio;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, w * 0.85 + dropPx),
          width: w * 0.44,
          height: w * 0.13,
        ),
        Paint()
          ..color =
              const Color(0x55120824).withValues(alpha: 0.34 * horizonAlpha),
      );
    }

    final sprite = game.orbSprite;
    if (sprite != null) {
      canvas.drawCircle(
        center,
        w * 0.46 * pulse,
        Paint()
          ..color =
              const Color(0x42FFD166).withValues(alpha: 0.26 * horizonAlpha)
          ..blendMode = BlendMode.plus,
      );
      final fit = (w / sprite.width < w / sprite.height)
          ? w / sprite.width
          : w / sprite.height;
      final dw = sprite.width * fit * pulse;
      final dh = sprite.height * fit * pulse;
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
            0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromCenter(center: center, width: dw, height: dh),
        Paint()
          ..color = Color.fromARGB((horizonAlpha * 255).round(), 255, 255, 255)
          ..filterQuality = FilterQuality.medium,
      );
      return;
    }

    canvas.drawCircle(
      center,
      w * 0.44 * pulse,
      Paint()..color = const Color(0x40FFD166),
    );
    canvas.drawCircle(
      center,
      w * 0.28 * pulse,
      Paint()..color = const Color(0xFFFFE599),
    );
  }
}
