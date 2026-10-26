import 'dart:async';
import 'package:flutter/material.dart';

/// Tracks user inactivity and flips [showHowToPlay] on after
/// [idleHintDuration] of no touches. Reset on any tap via [resetIdleTimer].
mixin IdleHintMixin<T extends StatefulWidget> on State<T> {
  Timer? _idleTimer;
  bool showHowToPlay = false;

  /// Override per-screen if a different threshold is needed.
  Duration get idleHintDuration => const Duration(seconds: 5);

  void startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleHintDuration, () {
      if (mounted) setState(() => showHowToPlay = true);
    });
  }

  /// Call this on any pointer-down across the screen.
  void resetIdleTimer() {
    if (showHowToPlay) {
      setState(() => showHowToPlay = false);
    }
    startIdleTimer();
  }

  void cancelIdleTimer() {
    _idleTimer?.cancel();
  }

  void disposeIdleTimer() {
    _idleTimer?.cancel();
  }
}