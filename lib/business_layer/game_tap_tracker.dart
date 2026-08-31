class GameTapTracker {
  DateTime? _startTime;
  int _totalTaps = 0;
  int _correctTaps = 0;
  int _mistakeCount = 0;

  /// Call this when the game actually begins (after intro finishes)
  void startSession() {
    _startTime = DateTime.now();
    _totalTaps = 0;
    _correctTaps = 0;
    _mistakeCount = 0;
  }

  /// Register a successful action/tap
  void recordCorrectTap() {
    _totalTaps++;
    _correctTaps++;
  }

  /// Register an incorrect action/tap
  void recordMistake() {
    _totalTaps++;
    _mistakeCount++;
  }

  /// Register any screen tap or attempt
  void recordGenericTap() {
    _totalTaps++;
  }

  int get totalTaps => _totalTaps;
  int get correctTaps => _correctTaps;
  int get mistakeCount => _mistakeCount;

  /// Returns formatted time like "1m 15s" or "45s"
  String get formattedDuration {
    if (_startTime == null) return "0s";
    final int seconds = DateTime.now().difference(_startTime!).inSeconds;
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return mins > 0 ? "${mins}m ${secs}s" : "${secs}s";
  }

  /// Reset all metrics
  void reset() {
    _startTime = null;
    _totalTaps = 0;
    _correctTaps = 0;
    _mistakeCount = 0;
  }
}
