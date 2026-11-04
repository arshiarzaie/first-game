import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/systems/power_up_system.dart';

void main() {
  group('PowerUpSystem (S15 Subway-Surfers suite)', () {
    test('pickup power-ups including Super Sneakers activate and expire cleanly',
        () {
      final powerUps = PowerUpSystem(
        magnetDuration: 5,
        multiplierDuration: 6,
        solarDashDuration: 3,
        superSneakersDuration: 4,
      );

      powerUps.activate(PowerUpKind.magnet);
      powerUps.activate(PowerUpKind.multiplier2x);
      powerUps.activate(PowerUpKind.superSneakers);
      expect(powerUps.hasMagnet, isTrue);
      expect(powerUps.hasSuperSneakers, isTrue);
      expect(powerUps.scoreMultiplier, 2);

      powerUps.update(4.5);
      expect(powerUps.hasSuperSneakers, isFalse);
      expect(powerUps.hasMagnet, isTrue);

      powerUps.update(1.0);
      expect(powerUps.hasMagnet, isFalse);
      expect(powerUps.scoreMultiplier, 2);

      powerUps.update(1.0);
      expect(powerUps.scoreMultiplier, 1);
    });

    test('Solar Hoverboard shield absorbs one hit and enters recharge cooldown',
        () {
      final powerUps = PowerUpSystem(shieldDuration: 8, shieldCooldown: 12);
      expect(powerUps.canActivateShield, isTrue);
      expect(powerUps.activateShield(), isTrue);
      expect(powerUps.hasShield, isTrue);
      expect(powerUps.canActivateShield, isFalse);

      expect(powerUps.consumeShieldOnHit(), isTrue);
      expect(powerUps.hasShield, isFalse);
      expect(powerUps.shieldCooldownRemaining, 12);

      expect(powerUps.consumeShieldOnHit(), isFalse);

      powerUps.update(12.5);
      expect(powerUps.canActivateShield, isTrue);
    });
  });
}
