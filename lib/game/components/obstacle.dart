import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/obstacle_spawner.dart';

/// 2.5D track hazard with three Subway-style vertical archetypes (S12):
///  * [ObstacleKind.lowSpikes] — vaultable ground crystal cluster;
///  * [ObstacleKind.highArch] — duckable overhead portal arch;
///  * [ObstacleKind.tallMonolith] — full-height impassable rune monolith.
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
        size = Vector2(base * 1.05, base * 1.02);
      case ObstacleKind.highArch:
        size = Vector2(base * 1.42, base * 1.52);
      case ObstacleKind.tallMonolith:
        size = Vector2(base * 1.18, base * 1.74);
    }
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _depth -= (game.currentSpeed / GameConfig.trackLength) * dt;

    // Evaluate true 2.5D (lane, depth, vertical state) collision as the
    // hazard crosses the player plane.
    if (!_resolvedPlayerPlane && _depth <= 0.048 && _depth >= -0.042) {
      final laneDiff = (game.player.currentLane - lane).abs();
      if (laneDiff < 0.49 && !game.powerUps.isSolarDashing) {
        final cleared = _isClearedVertically();
        if (!cleared) {
          _resolvedPlayerPlane = true;
          final shatteredByShield = game.onObstacleImpact(
            Vector2(position.x, position.y - size.y * scale.y * 0.45),
          );
          if (shatteredByShield) {
            removeFromParent();
            return;
          }
        }
      }
    }

    if (_depth <= -0.16) {
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
    final sc = game.scaleForDepth(_depth);
    position = Vector2(
      game.laneXForDepth(lane.toDouble(), _depth),
      game.yForDepth(_depth) + size.y * sc * 0.04,
    );
    scale = Vector2.all(sc);

    // 3D occlusion sorting relative to SoulPlayer (priority 20):
    //  * Overhead arches near the player draw in front of Soul so sliding
    //    visibly passes underneath the glowing crossbar.
    //  * Hazards that have already passed the player plane draw in front.
    //  * Approaching ground spikes stay < 20 so a jumping Soul vaults cleanly
    //    over top of them.
    if (_depth < -0.045) {
      priority = 25;
    } else if (kind == ObstacleKind.highArch && _depth < 0.09) {
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
    final w = size.x;
    final h = size.y;

    final sprite = _sprite;
    if (sprite != null) {
      final fit = (w / sprite.width < h / sprite.height)
          ? w / sprite.width
          : h / sprite.height;
      final dw = sprite.width * fit;
      final dh = sprite.height * fit;

      if (kind == ObstacleKind.highArch) {
        // Two separate contact shadows under the left and right arch posts
        // so the open slide gap in the middle stays clean.
        final postShadow = Paint()
          ..color = const Color(0x800D051A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset((w - dw) / 2 + dw * 0.14, h * 0.96),
            width: dw * 0.24,
            height: h * 0.09,
          ),
          postShadow,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset((w + dw) / 2 - dw * 0.14, h * 0.96),
            width: dw * 0.24,
            height: h * 0.09,
          ),
          postShadow,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w / 2, h * 0.95),
            width: dw * 0.82,
            height: h * 0.16,
          ),
          Paint()
            ..color = const Color(0x880D051A)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }

      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
            0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH((w - dw) / 2, h - dh, dw, dh),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }

    _renderFallback(canvas, w, h);
  }

  void _renderFallback(Canvas canvas, double w, double h) {
    final fill = Paint()..color = const Color(0xFF1C1030);
    final edge = Paint()
      ..color = const Color(0xFF4DD8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case ObstacleKind.lowSpikes:
        final spike = Path()
          ..moveTo(0, h)
          ..lineTo(w * 0.5, h * 0.15)
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
