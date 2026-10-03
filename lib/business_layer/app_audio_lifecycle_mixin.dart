import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'app_audio_lifecycle_service.dart';

/// Add to any screen State. Auto-registers its players and exposes
/// optional hooks for timers/animations.
mixin AppAudioLifecycleMixin<T extends StatefulWidget> on State<T> {
  /// Every AudioPlayer this screen owns.
  List<AudioPlayer> get lifecyclePlayers;

  void onAppBackgrounded() {}
  void onAppForegrounded() {}

  @override
  void initState() {
    super.initState();
    final svc = AppAudioLifecycleService.instance;
    for (final p in lifecyclePlayers) {
      svc.register(p);
    }
    svc.isForeground.addListener(_onForegroundChanged);
  }

  void _onForegroundChanged() {
    if (!mounted) return;
    if (AppAudioLifecycleService.instance.isForeground.value) {
      onAppForegrounded();
    } else {
      onAppBackgrounded();
    }
  }

  @override
  void dispose() {
    final svc = AppAudioLifecycleService.instance;
    svc.isForeground.removeListener(_onForegroundChanged);
    for (final p in lifecyclePlayers) {
      svc.unregister(p);
    }
    super.dispose();
  }
}
