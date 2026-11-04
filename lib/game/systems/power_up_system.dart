import '../config/game_config.dart';

/// Complete Subway-Surfers-grade on-track power-up quartet (S15):
///  * [magnet] — Coin Magnet across all 3 lanes & train roofs;
///  * [multiplier2x] — 2x Score Multiplier;
///  * [solarDash] — Jetpack sky-flight high above all trains with bonus coins;
///  * [superSneakers] — Super Sneakers letting every jump vault straight onto
///    full-height 3D train roofs!
enum PowerUpKind {
  magnet,
  multiplier2x,
  solarDash,
  superSneakers,
}

/// Pure-Dart manager for active power-ups and Soul's crash-absorbing
/// Solar Hoverboard (`activateShield` / double-tap board).
class PowerUpSystem {
  PowerUpSystem({
    this.magnetDuration = GameConfig.magnetDuration,
    this.multiplierDuration = GameConfig.multiplierDuration,
    this.solarDashDuration = GameConfig.solarDashDuration,
    this.superSneakersDuration = GameConfig.superSneakersDuration,
    this.shieldDuration = GameConfig.solarShieldDuration,
    this.shieldCooldown = GameConfig.solarShieldCooldown,
  });

  final double magnetDuration;
  final double multiplierDuration;
  final double solarDashDuration;
  final double superSneakersDuration;
  final double shieldDuration;
  final double shieldCooldown;

  double _magnetRemaining = 0;
  double _multiplierRemaining = 0;
  double _dashRemaining = 0;
  double _sneakersRemaining = 0;
  double _shieldRemaining = 0;
  double _shieldCooldownRemaining = 0;

  double get magnetRemaining => _magnetRemaining;
  double get multiplierRemaining => _multiplierRemaining;
  double get dashRemaining => _dashRemaining;
  double get sneakersRemaining => _sneakersRemaining;
  double get shieldRemaining => _shieldRemaining;
  double get shieldCooldownRemaining => _shieldCooldownRemaining;

  bool get hasMagnet => _magnetRemaining > 0;
  bool get hasMultiplier => _multiplierRemaining > 0;
  bool get isSolarDashing => _dashRemaining > 0;
  bool get hasSuperSneakers => _sneakersRemaining > 0;
  bool get hasShield => _shieldRemaining > 0;

  int get scoreMultiplier => hasMultiplier ? 2 : 1;

  bool get canActivateShield =>
      _shieldRemaining <= 0 && _shieldCooldownRemaining <= 0;

  void activate(PowerUpKind kind) {
    switch (kind) {
      case PowerUpKind.magnet:
        _magnetRemaining = magnetDuration;
      case PowerUpKind.multiplier2x:
        _multiplierRemaining = multiplierDuration;
      case PowerUpKind.solarDash:
        _dashRemaining = solarDashDuration;
      case PowerUpKind.superSneakers:
        _sneakersRemaining = superSneakersDuration;
    }
  }

  /// Summons the Solar Hoverboard when off cooldown.
  bool activateShield() {
    if (!canActivateShield) {
      return false;
    }
    _shieldRemaining = shieldDuration;
    return true;
  }

  /// Absorbs one lethal obstacle hit if Solar Hoverboard is active, putting it
  /// onto recharge cooldown.
  bool consumeShieldOnHit() {
    if (_shieldRemaining <= 0) {
      return false;
    }
    _shieldRemaining = 0;
    _shieldCooldownRemaining = shieldCooldown;
    return true;
  }

  void update(double dt) {
    if (dt <= 0) {
      return;
    }
    if (_magnetRemaining > 0) {
      _magnetRemaining =
          (_magnetRemaining - dt).clamp(0.0, magnetDuration).toDouble();
    }
    if (_multiplierRemaining > 0) {
      _multiplierRemaining =
          (_multiplierRemaining - dt).clamp(0.0, multiplierDuration).toDouble();
    }
    if (_dashRemaining > 0) {
      _dashRemaining =
          (_dashRemaining - dt).clamp(0.0, solarDashDuration).toDouble();
    }
    if (_sneakersRemaining > 0) {
      _sneakersRemaining = (_sneakersRemaining - dt)
          .clamp(0.0, superSneakersDuration)
          .toDouble();
    }
    if (_shieldRemaining > 0) {
      _shieldRemaining -= dt;
      if (_shieldRemaining <= 0) {
        _shieldRemaining = 0;
        _shieldCooldownRemaining = shieldCooldown;
      }
    } else if (_shieldCooldownRemaining > 0) {
      _shieldCooldownRemaining =
          (_shieldCooldownRemaining - dt).clamp(0.0, shieldCooldown).toDouble();
    }
  }

  void reset() {
    _magnetRemaining = 0;
    _multiplierRemaining = 0;
    _dashRemaining = 0;
    _sneakersRemaining = 0;
    _shieldRemaining = 0;
    _shieldCooldownRemaining = 0;
  }
}
