import '../config/game_config.dart';

/// Accumulates distance and orb score for one run, with optional active
/// score multiplier support (S12 Solar Surge 2x).
class ScoreManager {
  ScoreManager({
    this.scorePerWorldUnit = GameConfig.scorePerWorldUnit,
    this.orbValue = GameConfig.orbScore,
  });

  final double scorePerWorldUnit;
  final int orbValue;

  double _distancePoints = 0;
  int _orbsCollected = 0;
  int _bonusOrbPoints = 0;

  int get orbsCollected => _orbsCollected;

  /// Total score: floored distance points plus orb bonuses.
  int get totalScore =>
      _distancePoints.floor() + _orbsCollected * orbValue + _bonusOrbPoints;

  void addDistance(double worldUnits, {int multiplier = 1}) {
    if (worldUnits > 0) {
      final m = multiplier < 1 ? 1 : multiplier;
      _distancePoints += worldUnits * scorePerWorldUnit * m;
    }
  }

  void addOrb({int multiplier = 1}) {
    final m = multiplier < 1 ? 1 : multiplier;
    _orbsCollected += 1;
    if (m > 1) {
      _bonusOrbPoints += (m - 1) * orbValue;
    }
  }

  void reset() {
    _distancePoints = 0;
    _orbsCollected = 0;
    _bonusOrbPoints = 0;
  }
}
