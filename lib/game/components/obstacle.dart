import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../soul_dusk_run_game.dart';
import '../systems/obstacle_spawner.dart';

/// Stage 4 Commercial-Grade 3D Fantasy Obstacles & Sky Clouds:
///  * Grounded 3D contact ambient-occlusion & colored stone bounce-light pools
///    so every crystal cluster, rune arch, thunderhead, and golden dawn cloud
///    sits physically inside the biome lighting;
///  * Live animated visual telegraphing (rising crystal motes on `lowSpikes`,
///    twin pillar shadows + swaying rune-curtain glow on `highArch`, internal
///    fork-lightning on `tallMonolith` storm clouds, ascending golden updraft
///    rings on `trainWithRamp` bounce clouds);
///  * Faceted radial shatter burst during `dissolveOut()`;
///  * Zero `MaskFilter.blur`, zero pop-in, zero pop-out, swept collisions!
class Obstacle extends PositionComponent
    with HasGameReference<SoulDuskRunGame> {
  Obstacle({
    required this.lane,
    this.kind = ObstacleKind.lowSpikes,
    this.isMoving = false,
    double initialDepth = 1.0,
    this.fadeInSeconds = 0.0,
  })  : _depth = initialDepth,
        _prevDepth = initialDepth,
        super(priority: 1000);

  final int lane;
  final ObstacleKind kind;
  final bool isMoving;
  final double fadeInSeconds;

  double _depth;
  double _prevDepth;
  double _phase = 0;
  double _aliveSeconds = 0;
  double _dissolveProgress = -1.0;
  bool _resolved = false;

  bool get isStormCloud => kind == ObstacleKind.tallMonolith;
  bool get isGoldenBounceCloud => kind == ObstacleKind.trainWithRamp;
  bool get isDissolving => _dissolveProgress >= 0.0;
  double get frontDepth => _depth;

  void dissolveOut() {
    if (_dissolveProgress < 0.0) {
      _resolved = true;
      _dissolveProgress = 0.0;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.bottomCenter;
    _phase = lane * 1.7 + _depth * 3.1;
    final base = game.size.x * GameConfig.entityWidthRatio;
    switch (kind) {
      case ObstacleKind.lowSpikes:
        size = Vector2(base * 1.16, base * 0.96);
      case ObstacleKind.highArch:
        size = Vector2(base * 1.48, base * 1.35);
      case ObstacleKind.tallMonolith:
        size = Vector2(base * 1.76, base * 1.36);
      case ObstacleKind.trainWithRamp:
        size = Vector2(base * 1.50, base * 1.10);
    }
    _applyProjection();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _aliveSeconds += dt;
    _phase += dt * (isMoving ? 5.2 : 3.2);

    if (_dissolveProgress >= 0.0) {
      _dissolveProgress += dt / 0.24;
      if (_dissolveProgress >= 1.0) {
        removeFromParent();
        return;
      }
    }

    _prevDepth = _depth;
    final approachSpeed = game.currentSpeed +
        (isStormCloud && isMoving && game.isRunStarted
            ? GameConfig.movingTrainExtraSpeed
            : 0);
    _depth -= (approachSpeed / GameConfig.trackLength) * dt;

    if (!_resolved && _prevDepth >= -0.042 && _depth <= 0.048) {
      _evaluateInteraction();
    }

    _applyProjection();

    if (_depth < -0.08) {
      final topScreenY = position.y - size.y * scale.y * 1.15;
      if (topScreenY > game.size.y + 32 || _depth <= -0.52) {
        removeFromParent();
      }
    }
  }

  void _evaluateInteraction() {
    final laneDiff = (game.player.currentLane - lane).abs();

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

    if (game.powerUps.isSolarDashing) {
      return;
    }

    final elev = game.effectivePlayerElevation;
    if (!_isClearedVertically(elev)) {
      final contactPoint =
          Vector2(position.x, position.y - size.y * scale.y * 0.48);
      if (laneDiff < GameConfig.collisionLaneThreshold) {
        _resolved = true;
        if (game.onObstacleImpact(contactPoint)) {
          dissolveOut();
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
    if (_depth > 1.24) {
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
    final dissolveBoost = _dissolveProgress > 0.0
        ? 1.0 + _dissolveProgress * 0.22
        : 1.0;

    final crestSink = _depth > 1.0
        ? ((_depth - 1.0) / 0.24).clamp(0.0, 1.0) * size.y * sc * 0.35
        : 0.0;

    position = Vector2(
      game.laneXForDepth(lane.toDouble() + windSway, _depth),
      game.yForDepth(_depth) + size.y * sc * 0.025 + hoverBob + crestSink,
    );
    scale = Vector2(
      sc * breathe * dissolveBoost,
      sc * (2.0 - breathe) * dissolveBoost,
    );

    final bucketPriority = 2000 - (_depth * 50).round() * 20;
    final int newPriority;
    if (isStormCloud &&
        game.effectivePlayerElevation >= GameConfig.stormCloudClearElevation &&
        _depth <= 0.08 &&
        _depth >= -0.08) {
      newPriority = 1910;
    } else if (isGoldenBounceCloud) {
      newPriority = bucketPriority - 25;
    } else if (kind == ObstacleKind.highArch) {
      newPriority = bucketPriority + 90;
    } else {
      newPriority = bucketPriority;
    }
    if (newPriority != priority) {
      priority = newPriority;
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

  Color get _biomeTint {
    switch (game.currentWorld) {
      case GameWorld.duskHollow:
        return const Color(0xFFD698FF);
      case GameWorld.moonveilMarsh:
        return const Color(0xFF5CF6EA);
      case GameWorld.emberfallCanyon:
        return const Color(0xFFFFB454);
    }
  }

  static void _drawGroundOval(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color inner,
    required Color mid,
    required double alpha,
  }) {
    if (width <= 1.0 || height <= 1.0 || alpha <= 0.005) {
      return;
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, height / width);
    final r = width * 0.5;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = Gradient.radial(
          Offset.zero,
          r,
          [
            inner.withValues(alpha: (inner.a * alpha).clamp(0.0, 1.0).toDouble()),
            mid.withValues(alpha: (mid.a * alpha).clamp(0.0, 1.0).toDouble()),
            mid.withValues(alpha: 0.0),
          ],
          const [0.0, 0.56, 1.0],
        ),
    );
    canvas.restore();
  }

  double _computeAlpha() {
    final hRaw = ((1.24 - _depth) / 0.34).clamp(0.0, 1.0).toDouble();
    final horizonAlpha = hRaw * hRaw * (3.0 - 2.0 * hRaw);
    final spawnAlpha = fadeInSeconds > 0.0
        ? (_aliveSeconds / fadeInSeconds).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final nearAlpha = _depth < -0.34
        ? ((_depth + 0.50) / 0.16).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final dissolveAlpha = _dissolveProgress >= 0.0
        ? (1.0 - _dissolveProgress).clamp(0.0, 1.0).toDouble()
        : 1.0;
    return (horizonAlpha * spawnAlpha * nearAlpha * dissolveAlpha)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_depth > 1.24) {
      return;
    }
    final alpha = _computeAlpha();
    final w = size.x;
    final h = size.y;
    if (alpha <= 0.01 && _dissolveProgress < 0.0) {
      return;
    }

    // 1. Grounded 3D Contact Shadow & Colored Stone Bounce-Light Pool!
    if (isStormCloud) {
      _drawGroundOval(
        canvas,
        center: Offset(w * 0.5, h * 0.96),
        width: w * 0.88,
        height: h * 0.20,
        inner: const Color(0xBB0D0620),
        mid: const Color(0x55221244),
        alpha: alpha,
      );
    } else if (isGoldenBounceCloud) {
      _drawGroundOval(
        canvas,
        center: Offset(w * 0.5, h * 0.94),
        width: w * 0.94,
        height: h * 0.24,
        inner: const Color(0xAAFFD86B),
        mid: const Color(0x44FF9838),
        alpha: alpha,
      );
      // Ascending concentric golden updraft rings signaling "SKY BOUNCE!"
      for (var rIdx = 0; rIdx < 2; rIdx++) {
        final u = ((_phase * 0.38 + rIdx * 0.5) % 1.0);
        final ry = h * (0.90 - 0.34 * u);
        final rw = w * (0.68 - 0.16 * u);
        final ringAlpha = math.sin(u * math.pi) * 0.62 * alpha;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(w * 0.5, ry), width: rw, height: rw * 0.24),
          Paint()
            ..color = const Color(0xFFFFF2B2).withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    } else if (kind == ObstacleKind.lowSpikes) {
      _drawGroundOval(
        canvas,
        center: Offset(w * 0.5, h * 0.95),
        width: w * 0.92,
        height: h * 0.20,
        inner: const Color(0xAA16092B),
        mid: const Color(0x58B256FF),
        alpha: alpha,
      );
    } else {
      // `highArch`: twin grounded pillar plinth shadows + warm rune light under lintel!
      for (final px in [w * 0.17, w * 0.83]) {
        _drawGroundOval(
          canvas,
          center: Offset(px, h * 0.96),
          width: w * 0.32,
          height: h * 0.13,
          inner: const Color(0xB0100820),
          mid: const Color(0x40100820),
          alpha: alpha,
        );
      }
      _drawGroundOval(
        canvas,
        center: Offset(w * 0.5, h * 0.96),
        width: w * 0.56,
        height: h * 0.14,
        inner: const Color(0x44C878FF),
        mid: const Color(0x00C878FF),
        alpha: alpha,
      );
    }

    // 2. Crisp Halo-Free 3D Sprite + Subtle Biome Atmospheric Tint!
    final sprite = _sprite;
    if (sprite != null && alpha > 0.01) {
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
      final dst = Rect.fromLTWH((w - dw) / 2, h - dh + yOffset, dw, dh);

      final paint = Paint()
        ..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255)
        ..filterQuality = FilterQuality.medium;
      // Gentle atmospheric light harmony in Moonveil Marsh & Emberfall Canyon
      if (game.currentWorld != GameWorld.duskHollow && !isGoldenBounceCloud) {
        paint.colorFilter = ColorFilter.mode(
          _biomeTint.withValues(alpha: 0.12),
          BlendMode.srcATop,
        );
      }

      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        dst,
        paint,
      );
    } else if (alpha > 0.01) {
      _renderFallback(canvas, w, h, alpha);
    }

    // 3. Live Foreground Magical Details (Zero Blur!)
    if (alpha > 0.05) {
      if (isStormCloud) {
        final flash = math.pow(math.sin(_phase * 1.85).abs(), 5).toDouble();
        if (flash > 0.18) {
          final cx = w * (0.46 + 0.08 * math.sin(_phase * 3.1));
          final bolt = Path()
            ..moveTo(cx, h * 0.34)
            ..lineTo(cx - w * 0.06, h * 0.48)
            ..lineTo(cx + w * 0.04, h * 0.54)
            ..lineTo(cx - w * 0.05, h * 0.72);
          canvas.drawPath(
            bolt,
            Paint()
              ..color = const Color(0xFFD89EFF).withValues(alpha: 0.65 * flash * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.6
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawPath(
            bolt,
            Paint()
              ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92 * flash * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..strokeCap = StrokeCap.round,
          );
        }
      } else if (kind == ObstacleKind.lowSpikes) {
        // Rising amethyst-cyan crystal motes above spike tips!
        for (var i = 0; i < 4; i++) {
          final u = ((_phase * 0.45 + i * 0.25) % 1.0);
          final sx = w * (0.26 + i * 0.16) + math.sin(_phase + i) * w * 0.03;
          final sy = h * (0.58 - 0.38 * u);
          final ma = math.sin(u * math.pi) * 0.85 * alpha;
          canvas.drawCircle(
            Offset(sx, sy),
            (w * 0.018).clamp(1.2, 3.2).toDouble(),
            Paint()
              ..color = (i.isEven
                      ? const Color(0xFFF0C4FF)
                      : const Color(0xFF84F8FF))
                  .withValues(alpha: ma),
          );
        }
      } else if (kind == ObstacleKind.highArch) {
        // Subtle glowing rune-curtain shimmer beneath the lintel ("SLIDE UNDER!")
        final pulse = 0.65 + 0.35 * math.sin(_phase * 2.2);
        _drawGroundOval(
          canvas,
          center: Offset(w * 0.5, h * 0.38),
          width: w * 0.54,
          height: h * 0.18,
          inner: const Color(0x66E49EFF),
          mid: const Color(0x00B864FF),
          alpha: alpha * pulse,
        );
      }
    }

    // 4. Radial Crystal/Cloud Shatter Burst during `dissolveOut()`!
    if (_dissolveProgress >= 0.0 && _dissolveProgress < 1.0) {
      final u = _dissolveProgress;
      final fade = (1.0 - u).clamp(0.0, 1.0).toDouble();
      final shardCol = isGoldenBounceCloud
          ? const Color(0xFFFFE694)
          : (isStormCloud ? const Color(0xFFC49CFF) : const Color(0xFFDF98FF));
      for (var i = 0; i < 8; i++) {
        final ang = i * (math.pi / 4) + 0.3;
        final dist = w * (0.12 + 0.55 * u);
        final sx = w * 0.5 + math.cos(ang) * dist;
        final sy = h * 0.55 + math.sin(ang) * dist * 0.75;
        final r = w * 0.055 * fade;
        final shard = Path()
          ..moveTo(sx, sy - r)
          ..lineTo(sx + r * 0.7, sy)
          ..lineTo(sx, sy + r)
          ..lineTo(sx - r * 0.7, sy)
          ..close();
        canvas.drawPath(
          shard,
          Paint()..color = shardCol.withValues(alpha: 0.88 * fade),
        );
      }
    }
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
