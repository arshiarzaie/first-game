import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/obstacle_spawner.dart';

/// S17 Pure `SOUL: DUSK RUN` Pre-Rendered 3D Fantasy Obstacles & Clouds
/// (ZERO rectangular train-boxes — 100% organic magical sprites!):
///
///  * [ObstacleKind.lowSpikes] — 3D Dark Obsidian & Glowing Amethyst Crystal
///    Spikes (`obstacle_spikes.png`) -> JUMP OVER;
///  * [ObstacleKind.highArch] — 3D Carved Ancient Mossy Rune Vine Archway
///    (`obstacle_arch.png`) -> SLIDE UNDER;
///  * [ObstacleKind.tallMonolith] — 3D Volumetric Dark Twilight Storm Cloud
///    (`obstacle_monolith.png`) with billowing shadow aura & inner violet
///    lightning pulse -> DODGE AROUND (or soar high above on a sky-arc!);
///  * [ObstacleKind.trainWithRamp] — 3D Radiant Golden Dawn Bounce-Cloud
///    (`golden_cloud.png`) -> TOUCH IT TO SOAR HIGH INTO A GOLDEN SKY-ARC!
class Obstacle extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  Obstacle({
    required this.lane,
    this.kind = ObstacleKind.lowSpikes,
    this.isMoving = false,
    double initialDepth = 1.0,
  })  : _depth = initialDepth,
        super(priority: 1000);

  final int lane;
  final ObstacleKind kind;
  final bool isMoving;

  double _depth;
  double _phase = 0;
  bool _resolved = false;

  bool get isStormCloud => kind == ObstacleKind.tallMonolith;
  bool get isGoldenBounceCloud => kind == ObstacleKind.trainWithRamp;
  double get frontDepth => _depth;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.bottomCenter;
    _phase = lane * 1.7 + _depth * 3.1;
    final base = game.size.x * GameConfig.entityWidthRatio;
    switch (kind) {
      case ObstacleKind.lowSpikes:
        size = Vector2(base * 1.12, base * 0.94);
      case ObstacleKind.highArch:
        size = Vector2(base * 1.44, base * 1.32);
      case ObstacleKind.tallMonolith:
        size = Vector2(base * 1.74, base * 1.34);
      case ObstacleKind.trainWithRamp:
        size = Vector2(base * 1.46, base * 1.08);
    }
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * (isMoving ? 5.2 : 3.2);

    final approachSpeed = game.currentSpeed +
        (isStormCloud && isMoving && game.isRunStarted
            ? GameConfig.movingTrainExtraSpeed
            : 0);
    _depth -= (approachSpeed / GameConfig.trackLength) * dt;

    if (!_resolved && _depth <= 0.048 && _depth >= -0.042) {
      _evaluateInteraction();
    }

    if (_depth <= -0.22) {
      removeFromParent();
      return;
    }
    _applyProjection();
  }

  void _evaluateInteraction() {
    final laneDiff = (game.player.currentLane - lane).abs();

    // 1. Radiant Golden Dawn Bounce-Cloud -> beneficial sky-bounce launch!
    if (isGoldenBounceCloud) {
      if (!game.powerUps.isSolarDashing &&
          laneDiff < 0.46 &&
          game.effectivePlayerElevation < 0.55) {
        _resolved = true;
        game.triggerCloudBounce(
          Vector2(position.x, position.y - size.y * scale.y * 0.35),
        );
      }
      return;
    }

    // 2. Solar Comet Flight ignores all ground/cloud hazards
    if (game.powerUps.isSolarDashing) {
      return;
    }

    // 3. Hazards: Dark Storm Cloud, Crystal Spikes, Ancient Rune Vine Arch
    final elev = game.effectivePlayerElevation;
    if (!_isClearedVertically(elev)) {
      final contactPoint =
          Vector2(position.x, position.y - size.y * scale.y * 0.48);
      if (laneDiff < GameConfig.collisionLaneThreshold) {
        _resolved = true;
        if (game.onObstacleImpact(contactPoint)) {
          removeFromParent();
        }
      } else if (laneDiff < GameConfig.stumbleLaneThreshold) {
        _resolved = true;
        game.onObstacleSideStumble(lane, contactPoint);
      } else if (laneDiff < 0.50) {
        _resolved = true;
        game.onNearMissSpark(contactPoint);
      }
    }
  }

  bool _isClearedVertically(double elev) {
    switch (kind) {
      case ObstacleKind.lowSpikes:
        return elev >= GameConfig.jumpClearThreshold;
      case ObstacleKind.highArch:
        return game.verticalMotion.isDuckingHigh ||
            elev >= GameConfig.stormCloudClearElevation;
      case ObstacleKind.tallMonolith:
        return elev >= GameConfig.stormCloudClearElevation;
      case ObstacleKind.trainWithRamp:
        return true;
    }
  }

  void _applyProjection() {
    if (_depth > 1.03) {
      scale = Vector2.zero();
      return;
    }
    final sc = game.scaleForDepth(_depth);
    final windSway = (isStormCloud && isMoving)
        ? math.sin(_phase * 0.85) * 0.045
        : 0.0;
    final hoverBob = (isStormCloud || isGoldenBounceCloud)
        ? math.sin(_phase) * size.y * 0.035 * sc
        : 0.0;
    final breathe = isStormCloud
        ? 1.0 + math.sin(_phase * 1.15) * 0.035
        : (isGoldenBounceCloud ? 1.0 + math.sin(_phase * 1.4) * 0.04 : 1.0);

    position = Vector2(
      game.laneXForDepth(lane.toDouble() + windSway, _depth),
      game.yForDepth(_depth) + size.y * sc * 0.02 + hoverBob,
    );
    scale = Vector2(sc * breathe, sc * (2.0 - breathe));

    final basePriority = ((2.0 - _depth) * 1000).round();
    if (isStormCloud &&
        game.effectivePlayerElevation >= GameConfig.stormCloudClearElevation &&
        _depth <= 0.08 &&
        _depth >= -0.08) {
      // Keep storm cloud beneath Soul while Soul soars over it on a sky-arc!
      priority = 1910;
    } else if (isGoldenBounceCloud) {
      priority = basePriority - 25;
    } else if (kind == ObstacleKind.highArch) {
      priority = basePriority + 90;
    } else {
      priority = basePriority;
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
      case ObstacleKind.trainWithRamp:
        return game.goldenCloudSprite;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_depth > 1.03) {
      return;
    }
    final w = size.x;
    final h = size.y;
    final horizonAlpha = ((1.03 - _depth) / 0.12).clamp(0.0, 1.0).toDouble();

    // 1. Grounded shadow / warm golden aura on the ancient stone bridge!
    if (isStormCloud) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.97),
          width: w * 0.76,
          height: h * 0.16,
        ),
        Paint()
          ..color =
              const Color(0x99120A24).withValues(alpha: 0.56 * horizonAlpha),
      );
      // Subtle ominous violet thunder-glow beneath storm cloud!
      final flash = math.pow(math.sin(_phase * 1.7).abs(), 6).toDouble();
      if (flash > 0.15) {
        canvas.drawCircle(
          Offset(w / 2, h * 0.52),
          w * 0.36,
          Paint()
            ..color = const Color(0x88B478FF)
                .withValues(alpha: 0.38 * flash * horizonAlpha),
        );
      }
    } else if (isGoldenBounceCloud) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.94),
          width: w * 0.80,
          height: h * 0.18,
        ),
        Paint()
          ..color =
              const Color(0x88FFC658).withValues(alpha: 0.44 * horizonAlpha),
      );
    } else if (kind == ObstacleKind.lowSpikes) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.96),
          width: w * 0.80,
          height: h * 0.14,
        ),
        Paint()
          ..color =
              const Color(0x77160E24).withValues(alpha: 0.48 * horizonAlpha),
      );
    }

    final sprite = _sprite;
    if (sprite != null) {
      final double dw;
      final double dh;
      if (kind == ObstacleKind.highArch) {
        dw = w;
        dh = h;
      } else {
        final fit = math.min(w / sprite.width, h / sprite.height);
        dw = sprite.width * fit;
        dh = sprite.height * fit;
      }
      final yOffset = isStormCloud ? -h * 0.10 : 0.0;
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
            0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH((w - dw) / 2, h - dh + yOffset, dw, dh),
        Paint()
          ..color = Color.fromARGB((horizonAlpha * 255).round(), 255, 255, 255)
          ..filterQuality = FilterQuality.medium,
      );
      return;
    }

    _renderFallback(canvas, w, h, horizonAlpha);
  }

  void _renderFallback(Canvas canvas, double w, double h, double alpha) {
    if (isStormCloud) {
      final p = Paint()
        ..color = const Color(0xFF2E2248).withValues(alpha: alpha);
      canvas.drawOval(Rect.fromLTWH(w * 0.10, h * 0.25, w * 0.80, h * 0.52), p);
    } else if (isGoldenBounceCloud) {
      final p = Paint()
        ..color = const Color(0xFFFFD87A).withValues(alpha: alpha);
      canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.36, w * 0.76, h * 0.46), p);
    } else if (kind == ObstacleKind.lowSpikes) {
      final spike = Path()
        ..moveTo(w * 0.18, h)
        ..lineTo(w * 0.50, h * 0.18)
        ..lineTo(w * 0.82, h)
        ..close();
      canvas.drawPath(
        spike,
        Paint()..color = const Color(0xFF563C7E).withValues(alpha: alpha),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.06, h * 0.14, w * 0.88, h * 0.24),
        Paint()..color = const Color(0xFF685A7C).withValues(alpha: alpha),
      );
    }
  }
}
