import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/systems/vertical_motion.dart';

void main() {
  group('VerticalMotion', () {
    test('parabolic jump clears low obstacles around apex and lands cleanly',
        () {
      final motion = VerticalMotion(jumpDuration: 0.60);
      expect(motion.isJumping, isFalse);
      expect(motion.jumpHeight, 0);

      expect(motion.jump(), isTrue);
      expect(motion.isJumping, isTrue);

      motion.update(0.30); // apex
      expect(motion.jumpHeight, closeTo(1.0, 1e-6));
      expect(motion.isClearingLow, isTrue);

      motion.update(0.35); // completed arc
      expect(motion.isJumping, isFalse);
      expect(motion.jumpHeight, 0);
      expect(motion.isClearingLow, isFalse);
    });

    test('ground slide ducks overhead arches and cancels cleanly into jump',
        () {
      final motion = VerticalMotion(slideDuration: 0.50);
      motion.slide();
      expect(motion.isSliding, isTrue);
      expect(motion.isDuckingHigh, isTrue);

      // Slide-cancel jump (Subway Surfers responsiveness).
      expect(motion.jump(), isTrue);
      expect(motion.isSliding, isFalse);
      expect(motion.isJumping, isTrue);
    });

    test('mid-air slide triggers fast-fall slam and chains into ground slide',
        () {
      final motion = VerticalMotion(
        jumpDuration: 0.60,
        slideDuration: 0.50,
        fastFallMultiplier: 4.0,
      );
      motion.jump();
      motion.update(0.15);
      expect(motion.isJumping, isTrue);

      motion.slide();
      expect(motion.isFastFalling, isTrue);

      motion.update(0.20); // slams back to ground rapidly
      expect(motion.isJumping, isFalse);
      expect(motion.isSliding, isTrue);
    });

    test('buffers pre-landing jump input during final 30% of descent', () {
      final motion = VerticalMotion(jumpDuration: 0.60);
      expect(motion.jump(), isTrue);

      motion.update(0.45); // 75% through jump arc (descending near ground)
      expect(motion.isJumping, isTrue);
      expect(motion.jump(), isFalse); // buffered, not double-jumped mid-air

      motion.update(0.16); // crosses 100% touchdown -> auto-launches buffered jump!
      expect(motion.isJumping, isTrue);
      motion.update(0.28);
      expect(motion.jumpHeight, greaterThan(0.9));
    });
  });
}
