import '../config/game_config.dart';

/// On-track power-ups inspired by Subway Surfers' classic trio, themed for
/// Soul's twilight solar world.
enum PowerUpKind {
  /// Pulls orbs from all 3 lanes smoothly into Soul.
  magnet,

  /// Doubles distance and orb score points while active.
  multiplier2x,

  /// Lifts Soul high above obstacles in a blazing golden comet dash.
  solarDash,
}

/// Pure-Dart manager for active power-ups and Soul's crash-absorbing
/// Solar Aegis shield (Subway Surfers' Hoverboard counterpart).
class PowerUpSystem {
  PowerUpSystem({
    this.magnetDuration = GameConfig.magnetDuration,
    this.multiplierDuration = GameConfig.multiplierDuration,
    this.solarDashDuration = GameConfig.solarDashDuration,
    this.shieldDuration = GameConfig.solarShieldDuration,
    this.shieldCooldown = GameConfig.solarShieldCooldown,
  });

  final double magnetDuration;
  final double multiplierDuration;
  final double solarDashDuration;
  final double shieldDuration;
  final double shieldCooldown;

  double _magnetRemaining = 0;
  double _multiplierRemaining = 0;
  double _dashRemaining = 0;
  double _shieldRemaining = 0;
  double _shieldCooldownRemaining = 0;

  double get magnetRemaining => _magnetRemaining;
  double get multiplierRemaining => _multiplierRemaining;
  double get dashRemaining => _dashRemaining;
  double get shieldRemaining => _shieldRemaining;
  double get shieldCooldownRemaining => _shieldCooldownRemaining;

  bool get hasMagnet => _magnetRemaining > 0;
  bool get hasMultiplier => _multiplierRemaining > 0;
  bool get isSolarDashing => _dashRemaining > 0;
  bool get hasShield => _shieldRemaining > 0;

  int get scoreMultiplier => hasMultiplier ? 2 : 1;

  bool get canActivateShield =>
      _shieldRemaining <= 0 && _shieldCooldownRemaining <= 0;

  /// Activates an on-track power-up pickup.
  void activate(PowerUpKind kind) {
    switch (kind) {
      case PowerUpKind.magnet:
        _magnetRemaining = magnetDuration;
      case PowerUpKind.multiplier2x:
        _multiplierRemaining = multiplierDuration;
      case PowerUpKind.solarDash:
        _dashRemaining = solarDashDuration;
    }
  }

  /// Activates the Solar Aegis crash shield when off cooldown.
  bool activateShield() {
    if (!canActivateShield) {
      return false;
    }
    _shieldRemaining = shieldDuration;
    return true;
  }

  /// Absorbs one lethal obstacle hit if Solar Aegis is active, putting the
  /// shield onto recharge cooldown. Returns true if the hit was absorbed.
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
      _magnetRemaining = (_magnetRemaining - dt).clamp(0.0, magnetDuration);
    }
    if (_multiplierRemaining > 0) {
      _multiplierRemaining =
          (_multiplierRemaining - dt).clamp(0.0, multiplierDuration);
    }
    if (_dashRemaining > 0) {
      _dashRemaining = (_dashRemaining - dt).clamp(0.0, solarDashDuration);
    }
    if (_shieldRemaining > 0) {
      _shieldRemaining -= dt;
      if (_shieldRemaining <= 0) {
        _shieldRemaining = 0;
        _shieldCooldownRemaining = shieldCooldown;
      }
    } else if (_shieldCooldownRemaining > 0) {
      _shieldCooldownRemaining =
          (_shieldCooldownRemaining - dt).clamp(0.0, shieldCooldown);
    }
  }

  void reset() {
    _magnetRemaining = 0;
    _multiplierRemaining = 0;
    _dashRemaining = 0;
    _shieldRemaining = 0;
    _shieldCooldownRemaining = 0;
  }
}
