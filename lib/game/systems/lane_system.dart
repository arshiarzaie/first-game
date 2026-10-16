import '../config/game_config.dart';

/// Tracks the player's current lane and enforces the lane bounds.
///
/// Pure Dart (no Flutter/Flame) so the invariants are unit-testable:
/// the lane index NEVER leaves the range [0, laneCount - 1].
class LaneSystem {
  LaneSystem({
    int laneCount = GameConfig.laneCount,
    int initialLane = GameConfig.initialLane,
  })  : assert(laneCount >= 1, 'laneCount must be >= 1'),
        assert(initialLane >= 0 && initialLane < laneCount),
        _laneCount = laneCount,
        _initialLane = initialLane,
        _lane = initialLane;

  final int _laneCount;
  final int _initialLane;
  int _lane;

  /// Current lane index. Guaranteed to be in [0, laneCount - 1].
  int get lane => _lane;

  int get laneCount => _laneCount;

  /// Attempts to move one lane left. Returns true if the move happened.
  bool moveLeft() => _move(-1);

  /// Attempts to move one lane right. Returns true if the move happened.
  bool moveRight() => _move(1);

  bool _move(int delta) {
    final next = _lane + delta;
    if (next < 0 || next >= _laneCount) {
      return false; // clamped at the boundary
    }
    _lane = next;
    return true;
  }

  void reset() {
    _lane = _initialLane;
  }
}
