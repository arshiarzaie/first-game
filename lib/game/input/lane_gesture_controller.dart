/// Maps raw pointer gestures to 4-way runner intents (Subway-tier S12:
/// horizontal lane switches, swipe-up jump, swipe-down slide/fast-fall).
///
/// Pure Dart (no widget/Flame dependency) so it stays testable and the
/// gesture policy lives in exactly one place.
class LaneGestureController {
  LaneGestureController({
    required void Function(int direction) onMove,
    void Function()? onJump,
    void Function()? onSlide,
    this.swipeVelocityThreshold = 220,
  })  : _onMove = onMove,
        _onJump = onJump,
        _onSlide = onSlide;

  final void Function(int direction) _onMove;
  final void Function()? _onJump;
  final void Function()? _onSlide;

  /// Minimum absolute drag velocity (logical px/s) that counts as a
  /// deliberate swipe; below this the gesture is ignored.
  final double swipeVelocityThreshold;

  /// Horizontal swipe: positive velocity = swipe right = move right (+1),
  /// negative = swipe left = move left (-1).
  void onHorizontalDragEnd(double velocityX) {
    if (velocityX.abs() < swipeVelocityThreshold) {
      return;
    }
    _onMove(velocityX > 0 ? 1 : -1);
  }

  /// Vertical swipe: negative velocity = swipe up = jump,
  /// positive velocity = swipe down = slide / fast-fall slam.
  void onVerticalDragEnd(double velocityY) {
    if (velocityY.abs() < swipeVelocityThreshold) {
      return;
    }
    if (velocityY < 0) {
      _onJump?.call();
    } else {
      _onSlide?.call();
    }
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
