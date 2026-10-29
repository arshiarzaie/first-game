import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// Lightweight additive Canvas particle/ring burst for orb pickups,
/// jump takeoffs, and Solar Aegis obstacle shatters (S12).
class VfxBurst extends PositionComponent {
  VfxBurst._({
    required Vector2 origin,
    required this.duration,
    required this.maxRadius,
    required this.sparkCount,
    required this.coreColor,
    required this.ringColor,
    this.flattenY = 1.0,
  }) : super(position: origin, anchor: Anchor.center, priority: 60);

  factory VfxBurst.orbCollect(Vector2 center) => VfxBurst._(
        origin: center,
        duration: 0.26,
        maxRadius: 46,
        sparkCount: 6,
        coreColor: const Color(0xFFFFE082),
        ringColor: const Color(0xFFFFB300),
      );

  factory VfxBurst.shieldShatter(Vector2 center) => VfxBurst._(
        origin: center,
        duration: 0.42,
        maxRadius: 118,
        sparkCount: 12,
        coreColor: const Color(0xFFFFE57F),
        ringColor: const Color(0xFF4DD8FF),
      );

  factory VfxBurst.jumpRipple(Vector2 footCenter) => VfxBurst._(
        origin: footCenter,
        duration: 0.25,
        maxRadius: 56,
        sparkCount: 0,
        coreColor: const Color(0xAAFFD54F),
        ringColor: const Color(0xAA4DD8FF),
        flattenY: 0.34,
      );

  final double duration;
  final double maxRadius;
  final int sparkCount;
  final Color coreColor;
  final Color ringColor;
  final double flattenY;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final ease = 1 - (1 - t) * (1 - t);
    final fade = (1 - t).clamp(0.0, 1.0);
    final radius = maxRadius * (0.22 + 0.78 * ease);

    canvas.save();
    canvas.scale(1.0, flattenY);

    final ringPaint = Paint()
      ..color = ringColor.withValues(alpha: fade * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (4.5 * fade).clamp(1.0, 5.0)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset.zero, radius, ringPaint);

    final glowPaint = Paint()
      ..color = coreColor.withValues(alpha: fade * 0.45)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset.zero, radius * 0.55, glowPaint);

    if (sparkCount > 0) {
      final sparkPaint = Paint()
        ..color = coreColor.withValues(alpha: fade * 0.95)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;
      for (var i = 0; i < sparkCount; i++) {
        final angle = (i / sparkCount) * math.pi * 2 + 0.3;
        final r0 = radius * 0.45;
        final r1 = radius * 1.15;
        canvas.drawLine(
          Offset(math.cos(angle) * r0, math.sin(angle) * r0),
          Offset(math.cos(angle) * r1, math.sin(angle) * r1),
          sparkPaint,
        );
      }
    }
    canvas.restore();
  }
}
