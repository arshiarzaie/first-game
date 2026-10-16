import '../config/game_config.dart';

/// Accumulates distance and orb score for one run.
class ScoreManager {
  ScoreManager({
    this.scorePerWorldUnit = GameConfig.scorePerWorldUnit,
    this.orbValue = GameConfig.orbScore,
  });

  final double scorePerWorldUnit;
  final int orbValue;

  double _distancePoints = 0;
  int _orbsCollected = 0;

  int get orbsCollected => _orbsCollected;

  /// Total score: floored distance points plus orb bonuses.
  int get totalScore => _distancePoints.floor() + _orbsCollected * orbValue;

  void addDistance(double worldUnits) {
    if (worldUnits > 0) {
      _distancePoints += worldUnits * scorePerWorldUnit;
    }
  }

  void addOrb() {
    _orbsCollected += 1;
  }

  void reset() {
    _distancePoints = 0;
    _orbsCollected = 0;
  }
}
