/// Maps raw pointer gestures to lane-move intents.
///
/// Pure Dart (no widget/Flame dependency) so it stays testable and the
/// gesture policy lives in exactly one place.
class LaneGestureController {
  LaneGestureController({
    required void Function(int direction) onMove,
    this.swipeVelocityThreshold = 250,
  }) : _onMove = onMove;

  final void Function(int direction) _onMove;

  /// Minimum absolute horizontal drag velocity (logical px/s) that counts
  /// as a deliberate swipe; below this the gesture is ignored.
  final double swipeVelocityThreshold;

  /// Horizontal swipe: positive velocity = swipe right = move right (+1),
  /// negative = swipe left = move left (-1).
  void onHorizontalDragEnd(double velocityX) {
    if (velocityX.abs() < swipeVelocityThreshold) {
      return;
    }
    _onMove(velocityX > 0 ? 1 : -1);
  }

  /// Tap: tapping the left half of the screen moves left (-1), the right
  /// half moves right (+1).
  void onTapUp(double localX, double width) {
    if (width <= 0) {
      return;
    }
    _onMove(localX < width / 2 ? -1 : 1);
  }
}
