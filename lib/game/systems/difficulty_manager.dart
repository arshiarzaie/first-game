import '../config/game_config.dart';

/// Produces the run's forward speed as a function of survival time.
///
/// Invariants (unit-tested):
///  * speed is monotonically non-decreasing in elapsed time;
///  * speed never exceeds [maxSpeed];
///  * speed at t=0 equals [startSpeed].
class DifficultyManager {
  const DifficultyManager({
    this.startSpeed = GameConfig.startSpeed,
    this.maxSpeed = GameConfig.maxSpeed,
    this.rampPerSecond = GameConfig.speedRampPerSecond,
  })  : assert(startSpeed > 0, 'startSpeed must be positive'),
        assert(maxSpeed >= startSpeed, 'maxSpeed must be >= startSpeed'),
        assert(rampPerSecond >= 0, 'ramp must be non-negative');

  final double startSpeed;
  final double maxSpeed;
  final double rampPerSecond;

  /// Speed in world units/second after [elapsedSeconds] of survival.
  double speedAt(double elapsedSeconds) {
    if (elapsedSeconds <= 0) {
      return startSpeed;
    }
    final unclamped = startSpeed + rampPerSecond * elapsedSeconds;
    return unclamped >= maxSpeed ? maxSpeed : unclamped;
  }

  /// Normalized difficulty in [0, 1]: 0 at start, 1 once the cap is reached.
  double levelAt(double elapsedSeconds) {
    final span = maxSpeed - startSpeed;
    if (span <= 0) {
      return 1;
    }
    final level = (speedAt(elapsedSeconds) - startSpeed) / span;
    return level.clamp(0.0, 1.0).toDouble();
  }
}
