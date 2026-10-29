import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/systems/power_up_system.dart';

void main() {
  group('PowerUpSystem', () {
    test('pickup power-ups activate and expire cleanly', () {
      final powerUps = PowerUpSystem(
        magnetDuration: 5,
        multiplierDuration: 6,
        solarDashDuration: 3,
      );

      powerUps.activate(PowerUpKind.magnet);
      powerUps.activate(PowerUpKind.multiplier2x);
      expect(powerUps.hasMagnet, isTrue);
      expect(powerUps.scoreMultiplier, 2);

      powerUps.update(5.5);
      expect(powerUps.hasMagnet, isFalse);
      expect(powerUps.scoreMultiplier, 2);

      powerUps.update(1.0);
      expect(powerUps.scoreMultiplier, 1);
    });

    test('Solar Aegis shield absorbs one hit and enters recharge cooldown', () {
      final powerUps = PowerUpSystem(shieldDuration: 8, shieldCooldown: 12);
      expect(powerUps.canActivateShield, isTrue);
      expect(powerUps.activateShield(), isTrue);
      expect(powerUps.hasShield, isTrue);
      expect(powerUps.canActivateShield, isFalse);

      // Absorbs crash!
      expect(powerUps.consumeShieldOnHit(), isTrue);
      expect(powerUps.hasShield, isFalse);
      expect(powerUps.shieldCooldownRemaining, 12);

      // Second hit while recharging is not absorbed.
      expect(powerUps.consumeShieldOnHit(), isFalse);

      powerUps.update(12.5);
      expect(powerUps.canActivateShield, isTrue);
    });
  });
}
