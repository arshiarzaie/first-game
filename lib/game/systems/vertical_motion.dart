import '../config/game_config.dart';

/// Pure-Dart vertical kinetics for Soul (S17: 4-way controls, pre-landing jump
/// buffer, fast-fall slam, AND Golden Dawn Cloud sky-bounce arcs!).
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
  double _activeHeightScale = 1.0;
  double _activeDurationScale = 1.0;
  bool _jumping = false;
  bool _fastFalling = false;
  bool _queuedSlide = false;
  bool _queuedJump = false;
  double _slideRemaining = 0;

  bool get isJumping => _jumping;
  bool get isFastFalling => _fastFalling;
  bool get isSliding => !_jumping && _slideRemaining > 0;

  /// Normalized parabolic height (`0` on ground, `1.0` at normal jump apex,
  /// `> 1.0` when launched by a Golden Dawn Bounce-Cloud!).
  double get jumpHeight {
    if (!_jumping) {
      return 0;
    }
    final p = _jumpProgress.clamp(0.0, 1.0);
    return 4 * p * (1 - p) * _activeHeightScale;
  }

  bool get isClearingLow => jumpHeight >= clearThreshold;
  bool get isDuckingHigh => isSliding;

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
    _activeHeightScale = 1.0;
    _activeDurationScale = 1.0;
    _jumping = true;
    _jumpProgress = 0;
    return true;
  }

  /// Launches Soul into a graceful, high Golden Dawn Cloud sky-arc (can be
  /// triggered from the ground or mid-air!).
  void bounce({
    double heightScale = GameConfig.goldenCloudBounceMultiplier,
    double durationScale = GameConfig.goldenCloudDurationScale,
  }) {
    _slideRemaining = 0;
    _queuedSlide = false;
    _queuedJump = false;
    _fastFalling = false;
    _activeHeightScale = heightScale;
    _activeDurationScale = durationScale;
    _jumping = true;
    _jumpProgress = 0;
  }

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
      final duration = jumpDuration * _activeDurationScale;
      final rate = (_fastFalling ? fastFallMultiplier : 1.0) / duration;
      _jumpProgress += dt * rate;
      if (_jumpProgress >= 1.0) {
        _jumping = false;
        _jumpProgress = 0;
        _fastFalling = false;
        _activeHeightScale = 1.0;
        _activeDurationScale = 1.0;
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
    _activeHeightScale = 1.0;
    _activeDurationScale = 1.0;
    _fastFalling = false;
    _queuedSlide = false;
    _queuedJump = false;
    _slideRemaining = 0;
  }
}
