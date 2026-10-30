import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/obstacle_spawner.dart';

/// True-1/Z 3D track hazard with three cohesive Subway-style archetypes (S13):
///  * [ObstacleKind.lowSpikes] — waist-high crystal barricade (jump over);
///  * [ObstacleKind.highArch] — twin-column overhead rune gate (slide under);
///  * [ObstacleKind.tallMonolith] — towering obelisk wall (switch lanes).
class Obstacle extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  Obstacle({
    required this.lane,
    this.kind = ObstacleKind.lowSpikes,
    double initialDepth = 1.0,
  })  : _depth = initialDepth,
        super(priority: 10);

  final int lane;
  final ObstacleKind kind;
  double _depth;
  bool _resolvedPlayerPlane = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.bottomCenter;
    final base = game.size.x * GameConfig.entityWidthRatio;
    switch (kind) {
      case ObstacleKind.lowSpikes:
        // Matches 768x640 aspect (wide low crystal barricade across lane).
        size = Vector2(base * 1.18, base * 0.98);
      case ObstacleKind.highArch:
        // Tall twin-column portal spanning the lane with generous slide tunnel.
        size = Vector2(base * 1.40, base * 1.58);
      case ObstacleKind.tallMonolith:
        // Matches 640x960 aspect (towering full-lane obelisk).
        size = Vector2(base * 1.10, base * 1.65);
    }
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    // Fair Subway-grade 3D collision evaluation across Soul's plane:
    //  * Forgiving horizontal threshold (`collisionLaneThreshold = 0.36`) so
    //    active lane dodges are rewarded rather than clipped on corners.
    //  * Outer graze zone (`0.36..0.46`) emits a near-miss spark without death!
    if (!_resolvedPlayerPlane && _depth <= 0.032 && _depth >= -0.028) {
      final laneDiff = (game.player.currentLane - lane).abs();
      if (!game.powerUps.isSolarDashing && !_isClearedVertically()) {
        if (laneDiff < GameConfig.collisionLaneThreshold) {
          _resolvedPlayerPlane = true;
          final shatteredByShield = game.onObstacleImpact(
            Vector2(position.x, position.y - size.y * scale.y * 0.45),
          );
          if (shatteredByShield) {
            removeFromParent();
            return;
          }
        } else if (laneDiff < 0.46) {
          _resolvedPlayerPlane = true;
          game.onNearMissSpark(
            Vector2(position.x, position.y - size.y * scale.y * 0.40),
          );
        }
      }
    }

    if (_depth <= -0.18) {
      removeFromParent();
      return;
    }
    _applyProjection();
  }

  bool _isClearedVertically() {
    switch (kind) {
      case ObstacleKind.lowSpikes:
        return game.verticalMotion.isClearingLow;
      case ObstacleKind.highArch:
        return game.verticalMotion.isDuckingHigh;
      case ObstacleKind.tallMonolith:
        return false;
    }
  }

  void _applyProjection() {
    if (_depth > 1.02) {
      scale = Vector2.zero();
      return;
    }
    final sc = game.scaleForDepth(_depth);
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth) + size.y * sc * 0.04,
    );
    scale = Vector2.all(sc);

    if (_depth < -0.035) {
      priority = 25;
    } else if (kind == ObstacleKind.highArch && _depth < 0.085) {
      priority = 23;
    } else {
      priority = (6 + (1.0 - _depth).clamp(0.0, 1.0) * 13).round();
    }
  }

  Image? get _sprite {
    switch (kind) {
      case ObstacleKind.lowSpikes:
        return game.obstacleSprite;
      case ObstacleKind.highArch:
        return game.obstacleArchSprite;
      case ObstacleKind.tallMonolith:
        return game.obstacleMonolithSprite;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_depth > 1.02) {
      return;
    }
    final w = size.x;
    final h = size.y;
    final horizonAlpha = ((1.02 - _depth) / 0.10).clamp(0.0, 1.0);

    final sprite = _sprite;
    if (sprite != null) {
      final double dw;
      final double dh;
      if (kind == ObstacleKind.highArch) {
        dw = w;
        dh = h;
      } else {
        final fit = (w / sprite.width < h / sprite.height)
            ? w / sprite.width
            : h / sprite.height;
        dw = sprite.width * fit;
        dh = sprite.height * fit;
      }

      if (kind == ObstacleKind.highArch) {
        final postShadow = Paint()
          ..color =
              const Color(0x800D051A).withValues(alpha: 0.50 * horizonAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset((w - dw) / 2 + dw * 0.15, h * 0.96),
            width: dw * 0.22,
            height: h * 0.08,
          ),
          postShadow,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset((w + dw) / 2 - dw * 0.15, h * 0.96),
            width: dw * 0.22,
            height: h * 0.08,
          ),
          postShadow,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w / 2, h * 0.95),
            width: dw * 0.80,
            height: h * 0.14,
          ),
          Paint()
            ..color =
                const Color(0x880D051A).withValues(alpha: 0.55 * horizonAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }

      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
            0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH((w - dw) / 2, h - dh, dw, dh),
        Paint()
          ..color = Color.fromARGB((horizonAlpha * 255).round(), 255, 255, 255)
          ..filterQuality = FilterQuality.medium,
      );
      return;
    }

    _renderFallback(canvas, w, h);
  }

  void _renderFallback(Canvas canvas, double w, double h) {
    final fill = Paint()..color = const Color(0xFF1C1030);
    final edge = Paint()
      ..color = const Color(0xFF9E6BFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case ObstacleKind.lowSpikes:
        final spike = Path()
          ..moveTo(0, h)
          ..lineTo(w * 0.5, h * 0.18)
          ..lineTo(w, h)
          ..close();
        canvas.drawPath(spike, fill);
        canvas.drawPath(spike, edge);
      case ObstacleKind.highArch:
        final leftPost = Rect.fromLTWH(w * 0.06, h * 0.18, w * 0.16, h * 0.82);
        final rightPost =
            Rect.fromLTWH(w * 0.78, h * 0.18, w * 0.16, h * 0.82);
        final beam = Rect.fromLTWH(w * 0.04, h * 0.10, w * 0.92, h * 0.28);
        canvas.drawRect(leftPost, fill);
        canvas.drawRect(rightPost, fill);
        canvas.drawRect(beam, Paint()..color = const Color(0xFF3A2068));
        canvas.drawRect(beam, edge);
      case ObstacleKind.tallMonolith:
        final block = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.12, h * 0.06, w * 0.76, h * 0.94),
          Radius.circular(w * 0.06),
        );
        canvas.drawRRect(block, fill);
        canvas.drawRRect(block, edge);
    }
  }
}
