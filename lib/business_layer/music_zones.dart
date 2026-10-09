import 'package:flutter/widgets.dart';
import 'audio_helper.dart';

// USAGE
// add in levelscreen mixin
// MusicZoneMixin

class MusicZones extends NavigatorObserver {
  MusicZones._();
  static final MusicZones instance = MusicZones._();

  AudioHelper? helper; // set by the dashboard
  final Set<Route<dynamic>> _zones = {};
  Route<dynamic>? _top;
  bool _syncQueued = false;

  bool get active => _top == null || _zones.contains(_top);

  void register(Route<dynamic>? route) {
    if (route == null) return;
    _zones.add(route);
    _scheduleSync();
  }

  void unregister(Route<dynamic>? route) {
    if (route != null) _zones.remove(route);
  }

  void _scheduleSync() {
    if (_syncQueued) return;
    _syncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      final h = helper;
      if (h == null) return;
      active ? h.resumeBackgroundMusic() : h.pauseBackgroundMusic();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _top = route;
      _scheduleSync();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute is PageRoute) {
      _top = previousRoute;
      _scheduleSync();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute) {
      _top = newRoute;
      _scheduleSync();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route == _top && previousRoute is PageRoute) {
      _top = previousRoute;
      _scheduleSync();
    }
  }
}

mixin MusicZoneMixin<T extends StatefulWidget> on State<T> {
  Route<dynamic>? _zoneRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (r != _zoneRoute) {
      MusicZones.instance.unregister(_zoneRoute);
      _zoneRoute = r;
      MusicZones.instance.register(r);
    }
  }

  @override
  void dispose() {
    MusicZones.instance.unregister(_zoneRoute);
    super.dispose();
  }
}