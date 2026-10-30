import '../config/game_config.dart';

/// Pure-Dart vertical kinetics for Soul (S13 Subway-tier 4-way controls +
/// pre-landing jump input buffer).
///
/// Supports:
///  * Parabolic jump (`jump()`) with normalized height in `[0, 1]`;
///  * Pre-landing jump buffering: swiping Up during the final 30% of descent
///    queues an immediate rebound jump on touchdown instead of dropping input;
///  * Ground tuck-slide (`slide()`) to duck underneath overhead rune gates;
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
  bool _queuedJump = false;
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

  /// Triggers a jump (cancelling an active ground slide if needed), or queues
  /// an instant rebound jump if Soul is near touchdown (`progress >= 0.70`).
  bool jump() {
    if (_jumping) {
      if (_jumpProgress >= 0.70) {
        _queuedJump = true;
        _queuedSlide = false;
      }
      return false;
    }
    _slideRemaining = 0;
    _queuedSlide = false;
    _queuedJump = false;
    _fastFalling = false;
    _jumping = true;
    _jumpProgress = 0;
    return true;
  }

  /// Triggers a ground slide, or a fast-fall slam + landing slide if airborne.
  void slide() {
    _queuedJump = false;
    if (_jumping) {
      _fastFalling = true;
      _queuedSlide = true;
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
        if (_queuedJump) {
          _queuedJump = false;
          _queuedSlide = false;
          _jumping = true;
          _jumpProgress = 0;
        } else if (_queuedSlide) {
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
    _queuedJump = false;
    _slideRemaining = 0;
  }
}
