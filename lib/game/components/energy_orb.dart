import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';

/// Collectible golden sun-energy orb (Stage 2: zero pop-in smoothstep horizon
/// emergence, timed `fadeInSeconds` for intro vista spawns, swept pickup check,
/// bucketed depth priority, and true off-screen bottom exit).
class EnergyOrb extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  EnergyOrb({
    required this.lane,
    double initialDepth = 1.0,
    this.elevation = 0.0,
    this.fadeInSeconds = 0.0,
  })  : _depth = initialDepth,
        _prevDepth = initialDepth,
        _currentLane = lane.toDouble(),
        _currentElevation = elevation,
        super(priority: 1000);

  final int lane;
  final double elevation;
  final double fadeInSeconds;

  double _depth;
  double _prevDepth;
  double _currentLane;
  double _currentElevation;
  double _pulsePhase = 0;
  double _aliveSeconds = 0;
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
    _aliveSeconds += dt;
    _pulsePhase += dt * 4.5;
    _prevDepth = _depth;
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    final magnetized =
        game.powerUps.hasMagnet || game.powerUps.isSolarDashing;
    if (magnetized && _depth <= 0.56 && _depth >= -0.08) {
      final pull = (dt * 10.0).clamp(0.0, 1.0).toDouble();
      _currentLane += (game.player.currentLane - _currentLane) * pull;
      _currentElevation +=
          (game.effectivePlayerElevation - _currentElevation) * pull;
    }

    // Swept pickup check across [-0.055..0.068]
    if (!_collected && _prevDepth >= -0.055 && _depth <= 0.068) {
      final laneDiff = (_currentLane - game.player.currentLane).abs();
      final elevDiff =
          (_currentElevation - game.effectivePlayerElevation).abs();
      if ((laneDiff < 0.52 && elevDiff < 0.60) ||
          (magnetized && _depth <= 0.048)) {
        _collected = true;
        game.onOrbCollected(position: position.clone());
        removeFromParent();
        return;
      }
    }

    _applyProjection();

    if (_depth < -0.06) {
      final topScreenY = position.y - size.y * scale.y * 0.65;
      if (topScreenY > game.size.y + 24 || _depth <= -0.45) {
        removeFromParent();
      }
    }
  }

  void _applyProjection() {
    if (_depth > 1.24) {
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

    final newPriority = 2000 - (_depth * 50).round() * 20;
    if (newPriority != priority) {
      priority = newPriority;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_depth > 1.24) {
      return;
    }
    final hRaw = ((1.24 - _depth) / 0.28).clamp(0.0, 1.0).toDouble();
    final horizonAlpha = hRaw * hRaw * (3.0 - 2.0 * hRaw);
    final spawnAlpha = fadeInSeconds > 0.0
        ? (_aliveSeconds / fadeInSeconds).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final nearAlpha = _depth < -0.30
        ? ((_depth + 0.44) / 0.14).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final alpha = (horizonAlpha * spawnAlpha * nearAlpha).clamp(0.0, 1.0).toDouble();
    if (alpha <= 0.01) {
      return;
    }

    final w = size.x;
    final center = Offset(w / 2, w / 2);
    final pulse = 1 + math.sin(_pulsePhase) * 0.06;

    // Grounded warm sun-pool on the stone flagstones below!
    final dropPx = _currentElevation * game.size.y * GameConfig.jumpHeightRatio;
    final poolCenter = Offset(w * 0.5, w * 0.92 + dropPx);
    final poolAlpha =
        (_currentElevation > 0.08 ? 0.28 : 0.42) * alpha;
    canvas.save();
    canvas.translate(poolCenter.dx, poolCenter.dy);
    canvas.scale(1.0, 0.28);
    final pr = w * 0.40;
    canvas.drawCircle(
      Offset.zero,
      pr,
      Paint()
        ..shader = Gradient.radial(
          Offset.zero,
          pr,
          [
            const Color(0xFFFFD86E).withValues(alpha: poolAlpha),
            const Color(0xFF180C2C).withValues(alpha: poolAlpha * 0.45),
            const Color(0x00FFD86E),
          ],
          const [0.0, 0.58, 1.0],
        ),
    );
    canvas.restore();

    final sprite = game.orbSprite;
    if (sprite != null) {
      final haloR = w * 0.52 * pulse;
      canvas.drawCircle(
        center,
        haloR,
        Paint()
          ..shader = Gradient.radial(
            center,
            haloR,
            [
              const Color(0xFFFFE48A).withValues(alpha: 0.34 * alpha),
              const Color(0xFFFFA838).withValues(alpha: 0.14 * alpha),
              const Color(0x00FFA838),
            ],
            const [0.0, 0.52, 1.0],
          ),
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
          ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
          ..filterQuality = FilterQuality.medium,
      );

      // Orbiting golden starlight mote
      final gx = center.dx + math.cos(_pulsePhase * 0.85) * w * 0.31;
      final gy = center.dy + math.sin(_pulsePhase * 0.85) * w * 0.14;
      canvas.drawCircle(
        Offset(gx, gy),
        (w * 0.032).clamp(1.2, 3.0).toDouble(),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.90 * alpha),
      );
      return;
    }

    canvas.drawCircle(
      center,
      w * 0.44 * pulse,
      Paint()..color = const Color(0x40FFD166).withValues(alpha: 0.25 * alpha),
    );
    canvas.drawCircle(
      center,
      w * 0.28 * pulse,
      Paint()..color = const Color(0xFFFFE599).withValues(alpha: alpha),
    );
  }
}
