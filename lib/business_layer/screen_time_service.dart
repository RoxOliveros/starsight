import 'dart:async';

import 'package:flutter/widgets.dart';

import 'database_service.dart';

/// Counts how long the active child has been playing today and flips
/// [isLocked] to true once the parent's daily limit is reached.
///
/// Lifecycle:
///  - DashboardScreen calls [startSession] / [stopSession].
///  - ParentsAreaScreen calls [pause] / [resume] so parent time isn't counted.
///  - ScreenTimeGate (wrapped around the whole app) listens to [isLocked] and
///    shows the "Time's up" screen on top of everything.
class ScreenTimeService with WidgetsBindingObserver {
  ScreenTimeService._();
  static final ScreenTimeService instance = ScreenTimeService._();

  /// How often progress is written to Firestore while playing.
  static const int _saveEverySeconds = 15;

  /// True while the lock screen should be showing.
  final ValueNotifier<bool> isLocked = ValueNotifier<bool>(false);

  String? _childId;
  int _limitSeconds = DatabaseService.defaultScreenTimeLimitMinutes * 60;
  int _usedSeconds = 0;
  int _unsavedSeconds = 0;
  String _dateKey = DatabaseService.todayKey();

  Timer? _timer;
  bool _paused = false;
  bool _foreground = true;
  bool _observing = false;
  DateTime? _graceUntil;
  int _sessionToken = 0;
  Object? _owner;

  // ── Session control ───────────────────────────────────────────────────────

  /// [owner] is whoever started the session (pass `this` from the State).
  /// Only that same owner can stop it. This matters when switching children:
  /// the NEW dashboard starts its session before the OLD dashboard is
  /// disposed, and the old one must not shut down the new one's session.
  Future<void> startSession(String childId, Object owner) async {
    final token = ++_sessionToken;
    _owner = owner;

    // Save whichever child was being tracked before, then wait for that
    // write so re-reading the same child below sees the latest usage.
    final previous = _detachCurrent();
    Future.microtask(_evaluate); // clears a lock left over from the last child
    if (previous != null) await _save(previous);
    if (token != _sessionToken) return;

    final data = await DatabaseService().getScreenTime(childId);
    if (token != _sessionToken) return; // a newer session replaced this one

    _childId = childId;
    _limitSeconds = data.limitMinutes * 60;
    _usedSeconds = data.usedSeconds;
    _unsavedSeconds = 0;
    _dateKey = DatabaseService.todayKey();
    _paused = false;
    _foreground = true;
    _graceUntil = null;

    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _evaluate();
  }

  /// Ignored unless [owner] is the one that started the current session.
  Future<void> stopSession(Object owner) async {
    if (!identical(_owner, owner)) return;

    _sessionToken++;
    _owner = null;

    final snapshot = _detachCurrent();
    // Deferred: this is often called from dispose(), when it's unsafe to
    // trigger rebuilds.
    Future.microtask(_evaluate);

    if (snapshot != null) await _save(snapshot);
  }

  /// Stops the timer and forgets the current child, returning what needs to
  /// be saved (or null if nothing was being tracked).
  ({String id, int used, String key})? _detachCurrent() {
    final id = _childId;
    if (id == null) return null;

    final snapshot = (id: id, used: _usedSeconds, key: _dateKey);
    _timer?.cancel();
    _timer = null;
    _childId = null;
    return snapshot;
  }

  Future<void> _save(({String id, int used, String key}) snapshot) {
    return DatabaseService().saveScreenTimeUsage(
      childId: snapshot.id,
      usedSeconds: snapshot.used,
      dateKey: snapshot.key,
    );
  }

  /// Stop counting (e.g. while the parent is in the Parent's Area).
  void pause() {
    _paused = true;
    _persist();
  }

  void resume() {
    _paused = false;
    Future.microtask(_evaluate);
  }

  /// Call after the parent saves a new limit for [childId].
  void updateLimit(String childId, int minutes) {
    if (childId != _childId) return;
    _limitSeconds = minutes * 60;
    _evaluate();
  }

  /// Lets a parent (after entering their PIN) lift the lock temporarily so
  /// they can reach the Parent's Area and raise the limit. Counting continues,
  /// so if the limit isn't raised the lock comes back when this expires.
  void grantParentGrace({Duration duration = const Duration(minutes: 60)}) {
    _graceUntil = DateTime.now().add(duration);
    _evaluate();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _tick() {
    if (_childId == null || _paused || !_foreground) return;

    _rolloverIfNewDay();

    if (!isLocked.value) {
      _usedSeconds++;
      _unsavedSeconds++;
    }

    _evaluate();

    if (_unsavedSeconds >= _saveEverySeconds) _persist();
  }

  /// Daily reset: as soon as the local date changes (12:00 AM), start at zero.
  void _rolloverIfNewDay() {
    final today = DatabaseService.todayKey();
    if (today == _dateKey) return;

    _dateKey = today;
    _usedSeconds = 0;
    _unsavedSeconds = 0;
    _graceUntil = null;
    _persist();
  }

  void _evaluate() {
    if (_childId == null) {
      if (isLocked.value) isLocked.value = false;
      return;
    }
    // Don't lock while the parent is in the Parent's Area changing settings.
    if (_paused) return;

    final overLimit = _usedSeconds >= _limitSeconds;
    final inGrace =
        _graceUntil != null && DateTime.now().isBefore(_graceUntil!);
    final shouldLock = overLimit && !inGrace;

    if (shouldLock != isLocked.value) {
      isLocked.value = shouldLock;
      if (shouldLock) _persist();
    }
  }

  Future<void> _persist() async {
    final id = _childId;
    if (id == null) return;

    final used = _usedSeconds;
    final key = _dateKey;
    _unsavedSeconds = 0;

    await DatabaseService().saveScreenTimeUsage(
      childId: id,
      usedSeconds: used,
      dateKey: key,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        if (_childId != null) {
          _rolloverIfNewDay();
          _evaluate();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // App is in the background -> not "active gameplay", stop counting.
        _foreground = false;
        _persist();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }
}
