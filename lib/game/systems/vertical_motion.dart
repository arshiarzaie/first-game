import '../config/game_config.dart';

/// Pure-Dart vertical kinetics for Soul (S12 Subway-tier 4-way controls).
///
/// Supports:
///  * Parabolic jump (`jump()`) with normalized height in `[0, 1]`;
///  * Ground tuck-slide (`slide()`) to duck underneath overhead arches;
///  * Slide-cancel into jump (swiping up while sliding launches immediately);
///  * Mid-air fast-fall slam (`slide()` while airborne drops rapidly and
///    chains straight into a ground slide upon landing).
class VerticalMotion {
  VerticalMotion({
    this.jumpDuration = GameConfig.jumpDurationSeconds,
    this.slideDuration = GameConfig.slideDurationSeconds,
    this.fastFallMultiplier = GameConfig.fastFallMultiplier,
    this.clearThreshold = GameConfig.jumpClearThreshold,
  })  : assert(jumpDuration > 0),
        assert(slideDuration > 0);

  final double jumpDuration;
  final double slideDuration;
  final double fastFallMultiplier;
  final double clearThreshold;

  double _jumpProgress = 0;
  bool _jumping = false;
  bool _fastFalling = false;
  bool _queuedSlide = false;
  double _slideRemaining = 0;

  bool get isJumping => _jumping;
  bool get isFastFalling => _fastFalling;
  bool get isSliding => !_jumping && _slideRemaining > 0;

  /// Normalized parabolic height in `[0, 1]` (0 on ground, 1 at apex).
  double get jumpHeight {
    if (!_jumping) {
      return 0;
    }
    final p = _jumpProgress.clamp(0.0, 1.0);
    return 4 * p * (1 - p);
  }

  /// True while high enough to vault cleanly over low ground obstacles.
  bool get isClearingLow => jumpHeight >= clearThreshold;

  /// True while crouched on the ground underneath overhead arch barriers.
  bool get isDuckingHigh => isSliding;

  /// Triggers a jump (cancelling an active ground slide if needed).
  bool jump() {
    if (_jumping) {
      return false;
    }
    _slideRemaining = 0;
    _queuedSlide = false;
    _fastFalling = false;
    _jumping = true;
    _jumpProgress = 0;
    return true;
  }

  /// Triggers a ground slide, or a fast-fall slam + landing slide if airborne.
  void slide() {
    if (_jumping) {
      _fastFalling = true;
      _queuedSlide = true;
      // Ensure we are on the descending half or accelerate past the apex so
      // the slam feels immediate.
      if (_jumpProgress < 0.5) {
        _jumpProgress = 1.0 - _jumpProgress;
      }
      return;
    }
    _slideRemaining = slideDuration;
  }

  void update(double dt) {
    if (dt <= 0) {
      return;
    }
    if (_jumping) {
      final rate = (_fastFalling ? fastFallMultiplier : 1.0) / jumpDuration;
      _jumpProgress += dt * rate;
      if (_jumpProgress >= 1.0) {
        _jumping = false;
        _jumpProgress = 0;
        _fastFalling = false;
        if (_queuedSlide) {
          _queuedSlide = false;
          _slideRemaining = slideDuration;
        }
      }
      return;
    }
    if (_slideRemaining > 0) {
      _slideRemaining -= dt;
      if (_slideRemaining < 0) {
        _slideRemaining = 0;
      }
    }
  }

  void reset() {
    _jumping = false;
    _jumpProgress = 0;
    _fastFalling = false;
    _queuedSlide = false;
    _slideRemaining = 0;
  }
}
