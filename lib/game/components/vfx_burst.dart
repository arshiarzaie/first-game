import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// Eye-friendly crisp Canvas particle/ring burst for orb pickups,
/// jump takeoffs, and Solar Aegis obstacle shatters (S14: priority 2400 above
/// 1000-step 3D corridor depth sort, soft non-flashing alpha).
class VfxBurst extends PositionComponent {
  VfxBurst._({
    required Vector2 origin,
    required this.duration,
    required this.maxRadius,
    required this.sparkCount,
    required this.coreColor,
    required this.ringColor,
    this.flattenY = 1.0,
  }) : super(position: origin, anchor: Anchor.center, priority: 2400);

  factory VfxBurst.orbCollect(Vector2 center) => VfxBurst._(
        origin: center,
        duration: 0.22,
        maxRadius: 34,
        sparkCount: 5,
        coreColor: const Color(0xFFFFE599),
        ringColor: const Color(0xFFF5B041),
      );

  factory VfxBurst.shieldShatter(Vector2 center) => VfxBurst._(
        origin: center,
        duration: 0.34,
        maxRadius: 82,
        sparkCount: 8,
        coreColor: const Color(0xFFFFE8B3),
        ringColor: const Color(0xFF64D8EE),
      );

  factory VfxBurst.jumpRipple(Vector2 footCenter) => VfxBurst._(
        origin: footCenter,
        duration: 0.22,
        maxRadius: 44,
        sparkCount: 0,
        coreColor: const Color(0x88FFE599),
        ringColor: const Color(0x8892E4DA),
        flattenY: 0.32,
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
    final t = (_elapsed / duration).clamp(0.0, 1.0).toDouble();
    final ease = 1 - (1 - t) * (1 - t);
    final fade = (1 - t).clamp(0.0, 1.0).toDouble();
    final radius = maxRadius * (0.24 + 0.76 * ease);

    canvas.save();
    canvas.scale(1.0, flattenY);

    final ringPaint = Paint()
      ..color = ringColor.withValues(alpha: fade * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.2 * fade).clamp(1.0, 4.0).toDouble();
    canvas.drawCircle(Offset.zero, radius, ringPaint);

    final glowPaint = Paint()
      ..color = coreColor.withValues(alpha: fade * 0.28);
    canvas.drawCircle(Offset.zero, radius * 0.48, glowPaint);

    if (sparkCount > 0) {
      final sparkPaint = Paint()
        ..color = coreColor.withValues(alpha: fade * 0.80)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < sparkCount; i++) {
        final angle = (i / sparkCount) * math.pi * 2 + 0.3;
        final r0 = radius * 0.48;
        final r1 = radius * 1.08;
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
