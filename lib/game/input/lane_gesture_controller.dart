import 'dart:math' as math;

/// Maps raw pointer motions & gestures to instant 4-way Subway-tier runner
/// intents (S13: zero-lift-lag pointer swipe detection, chainable L-swipes,
/// strict stationary-tap discrimination so short vertical flicks never
/// misfire as sideways lane taps, and P4 first-input start gating).
///
/// Pure Dart (no widget/Flame dependency) so it is 100% unit-testable.
class LaneGestureController {
  LaneGestureController({
    required void Function(int direction) onMove,
    void Function()? onJump,
    void Function()? onSlide,
    bool Function()? isRunStarted,
    void Function()? onStartRun,
    this.swipeVelocityThreshold = 200,
    this.swipeDistanceThreshold = 22.0,
    this.chainSwipeDistanceThreshold = 34.0,
    this.tapMaxSlop = 10.0,
  })  : _onMove = onMove,
        _onJump = onJump,
        _onSlide = onSlide,
        _isRunStarted = isRunStarted,
        _onStartRun = onStartRun;

  final void Function(int direction) _onMove;
  final void Function()? _onJump;
  final void Function()? _onSlide;
  final bool Function()? _isRunStarted;
  final void Function()? _onStartRun;

  /// Legacy velocity threshold for [onHorizontalDragEnd] / [onVerticalDragEnd].
  final double swipeVelocityThreshold;

  /// Displacement (logical px) that immediately triggers the primary swipe
  /// while the finger is still moving on the screen.
  final double swipeDistanceThreshold;

  /// Displacement required after a swipe to chain a second orthogonal action
  /// (e.g. swipe left -> swipe down roll) in one continuous thumb stroke.
  final double chainSwipeDistanceThreshold;

  /// Maximum pointer excursion (logical px) that still counts as a stationary
  /// left/right tap on finger release. Anything between [tapMaxSlop] and
  /// [swipeDistanceThreshold] is ignored rather than misfiring as a lane tap.
  final double tapMaxSlop;

  int? _activePointer;
  double _originX = 0;
  double _originY = 0;
  double _anchorX = 0;
  double _anchorY = 0;
  double _maxExcursion = 0;
  bool _swipedInStroke = false;
  bool _consumedForStart = false;
  int _lastAxis = 0; // 1 = horizontal, 2 = vertical

  // --------------------------------------------------- Instant pointer API

  void onPointerDown(int pointer, double x, double y) {
    if (_activePointer != null) {
      return;
    }
    _activePointer = pointer;
    _originX = x;
    _originY = y;
    _anchorX = x;
    _anchorY = y;
    _maxExcursion = 0;
    _swipedInStroke = false;
    _consumedForStart = false;
    _lastAxis = 0;
  }

  void onPointerMove(int pointer, double x, double y) {
    if (pointer != _activePointer) {
      return;
    }
    final totalDx = x - _originX;
    final totalDy = y - _originY;
    final excursion = math.sqrt(totalDx * totalDx + totalDy * totalDy);
    if (excursion > _maxExcursion) {
      _maxExcursion = excursion;
    }
    if (_consumedForStart) {
      return;
    }

    final dx = x - _anchorX;
    final dy = y - _anchorY;
    final absX = dx.abs();
    final absY = dy.abs();
    final threshold = _swipedInStroke
        ? chainSwipeDistanceThreshold
        : swipeDistanceThreshold;

    if (math.max(absX, absY) < threshold) {
      return;
    }

    // P4 contract: if the run has not started yet, the first drag starts the
    // run once and does NOT move lanes / jump / slide.
    final isStarted = _isRunStarted;
    if (isStarted != null && !isStarted()) {
      _consumedForStart = true;
      _onStartRun?.call();
      return;
    }

    final axis = absX >= absY ? 1 : 2;
    // Prevent firing duplicate swipes along the same axis during a single
    // long follow-through stroke, while allowing crisp orthogonal L-chains!
    if (_swipedInStroke && axis == _lastAxis) {
      _anchorX = x;
      _anchorY = y;
      return;
    }

    _swipedInStroke = true;
    _lastAxis = axis;
    _anchorX = x;
    _anchorY = y;

    if (axis == 1) {
      _onMove(dx > 0 ? 1 : -1);
    } else {
      if (dy < 0) {
        _onJump?.call();
      } else {
        _onSlide?.call();
      }
    }
  }

  void onPointerUp(int pointer, double x, double y, double width) {
    if (pointer != _activePointer) {
      return;
    }
    _activePointer = null;

    if (_consumedForStart || _swipedInStroke) {
      return;
    }

    final dx = x - _originX;
    final dy = y - _originY;
    final dist = math.max(_maxExcursion, math.sqrt(dx * dx + dy * dy));
    if (dist <= tapMaxSlop) {
      final isStarted = _isRunStarted;
      if (isStarted != null && !isStarted()) {
        _onStartRun?.call();
        return;
      }
      onTapUp(x, width);
    }
  }

  void onPointerCancel(int pointer) {
    if (pointer == _activePointer) {
      _activePointer = null;
    }
  }

  // --------------------------------------------------- Direct / legacy API

  void onHorizontalDragEnd(double velocityX) {
    if (velocityX.abs() < swipeVelocityThreshold) {
      return;
    }
    _onMove(velocityX > 0 ? 1 : -1);
  }

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

  void onTapUp(double localX, double width) {
    if (width <= 0) {
      return;
    }
    _onMove(localX < width / 2 ? -1 : 1);
  }
}
