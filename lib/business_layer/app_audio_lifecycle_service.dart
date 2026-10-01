import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class AppAudioLifecycleService with WidgetsBindingObserver {
  AppAudioLifecycleService._();
  static final AppAudioLifecycleService instance = AppAudioLifecycleService._();

  final Set<AudioPlayer> _players = {};
  final Set<AudioPlayer> _pausedByLifecycle = {};

  /// Screens listen to this to pause/resume timers etc.
  final ValueNotifier<bool> isForeground = ValueNotifier<bool>(true);

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void register(AudioPlayer player) => _players.add(player);

  void unregister(AudioPlayer player) {
    _players.remove(player);
    _pausedByLifecycle.remove(player);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _pauseAll();
        break;
      case AppLifecycleState.resumed:
        _resumeAll();
        break;
      case AppLifecycleState.inactive: // dialogs, permission prompts, shade
      case AppLifecycleState.detached:
        break;
    }
  }

  void _pauseAll() {
    if (!isForeground.value) return; // paused + hidden both fire
    isForeground.value = false;

    for (final p in _players.toList()) {
      if (p.state == PlayerState.playing) {
        _pausedByLifecycle.add(p);
        p.pause().catchError((_) {});
      }
    }
  }

  void _resumeAll() {
    if (isForeground.value) return;
    isForeground.value = true;

    for (final p in _pausedByLifecycle.toList()) {
      p.resume().catchError((_) {});
    }
    _pausedByLifecycle.clear();
  }
}
