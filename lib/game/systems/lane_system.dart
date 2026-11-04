import '../config/game_config.dart';

/// Tracks the player's current lane, remembers [previousLane] for Subway-style
/// side-clip stumble recovery, and enforces the lane bounds.
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
        _lane = initialLane,
        _previousLane = initialLane;

  final int _laneCount;
  final int _initialLane;
  int _lane;
  int _previousLane;

  /// Current lane index. Guaranteed to be in [0, laneCount - 1].
  int get lane => _lane;

  /// Most recent lane prior to the latest lane move (used to bounce back on a
  /// side-clip stumble instead of unfairly killing the player).
  int get previousLane => _previousLane;

  int get laneCount => _laneCount;

  /// Attempts to move one lane left. Returns true if the move happened.
  bool moveLeft() => _move(-1);

  /// Attempts to move one lane right. Returns true if the move happened.
  bool moveRight() => _move(1);

  /// Bounces Soul cleanly back into [previousLane] (or a safe neighbor away
  /// from [blockedLane]) after clipping the side of a 3D obstacle.
  void bounceFromBlockedLane(int blockedLane) {
    if (_previousLane != blockedLane &&
        _previousLane >= 0 &&
        _previousLane < _laneCount) {
      _lane = _previousLane;
      return;
    }
    if (blockedLane > 0) {
      _lane = blockedLane - 1;
    } else if (blockedLane + 1 < _laneCount) {
      _lane = blockedLane + 1;
    }
  }

  bool _move(int delta) {
    final next = _lane + delta;
    if (next < 0 || next >= _laneCount) {
      return false;
    }
    _previousLane = _lane;
    _lane = next;
    return true;
  }

  void reset() {
    _lane = _initialLane;
    _previousLane = _initialLane;
  }
}
