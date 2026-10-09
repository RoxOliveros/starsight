import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'audio_settings.dart';

// USAGE
// The observer is registered/removed by AudioHelper itself — don't add it in the screen.
//
// late final AudioHelper _audioHelper = AudioHelper(
//   shouldResumeOnForeground: () => _screenPhase == LagoonScreenPhase.game,
// );
//
// init
// _audioHelper.playBackgroundMusic();
//
// dispose
// _audioHelper.stopBackgroundMusic();
// _audioHelper.dispose();

class AudioHelper with WidgetsBindingObserver {
  final AudioPlayer bgPlayer = AudioPlayer();

  String? _currentBgTrack;

  final bool Function()? shouldResumeOnForeground;
  double _baseVolume = 0.10;
  String? _pendingTrack;
  late final Future<void> _ctxReady;

  double get _effectiveVolume =>
      (_baseVolume * AudioSettings.instance.musicVolume).clamp(0.0, 1.0);

  AudioHelper({this.shouldResumeOnForeground}) {
    _ctxReady = _applyMixingAudioContext();
    WidgetsBinding.instance.addObserver(this);
    AudioSettings.instance.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!AudioSettings.instance.musicOn) {
      pauseBackgroundMusic();
      return;
    }
    bgPlayer.setVolume(_effectiveVolume);
    final canPlay = shouldResumeOnForeground?.call() ?? true;
    if (!canPlay) return;

    if (bgPlayer.state == PlayerState.paused) {
      resumeBackgroundMusic();
    } else if (bgPlayer.state != PlayerState.playing && _pendingTrack != null) {
      playBackgroundMusic(track: _pendingTrack, volume: _baseVolume);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        if (shouldResumeOnForeground?.call() ?? true) {
          resumeBackgroundMusic();
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _applyMixingAudioContext() async {
    final mixContext = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    );

    try {
      await bgPlayer.setAudioContext(mixContext);
    } catch (e) {
      debugPrint('AudioHelper: failed to configure background audio: $e');
    }
  }

  Future<void> playBackgroundMusic({
    String? track,
    double volume = 0.10,
  }) async {
    final resolved = track != null
        ? BgMusicAssets.resolve(track)
        : BgMusicAssets.random();

    _baseVolume = volume;
    _pendingTrack = resolved;
    if (!AudioSettings.instance.musicOn) return;

    if (_currentBgTrack == resolved && bgPlayer.state == PlayerState.playing) {
      return;
    }

    await _ctxReady;

    try {
      await bgPlayer.stop();
      await bgPlayer.setReleaseMode(ReleaseMode.loop);
      await bgPlayer.setVolume(_effectiveVolume);
      await bgPlayer.play(AssetSource(_strip(resolved)));

      _currentBgTrack = resolved;

      debugPrint('AudioHelper: playing background music $resolved');
    } catch (e) {
      debugPrint('AudioHelper: background music error ($resolved): $e');
    }
  }

  Future<void> stopBackgroundMusic() async {
    _pendingTrack = null;
    try {
      await bgPlayer.stop();
      _currentBgTrack = null;
    } catch (e) {
      debugPrint('AudioHelper: failed to stop background music: $e');
    }
  }

  Future<void> pauseBackgroundMusic() async {
    try {
      if (bgPlayer.state == PlayerState.playing) {
        await bgPlayer.pause();
      }
    } catch (e) {
      debugPrint('AudioHelper: failed to pause background music: $e');
    }
  }

  Future<void> resumeBackgroundMusic() async {
    if (!AudioSettings.instance.musicOn) return;
    try {
      if (bgPlayer.state == PlayerState.paused) {
        await bgPlayer.resume();
      }
    } catch (e) {
      debugPrint('AudioHelper: failed to resume background music: $e');
    }
  }

  Future<void> setBackgroundMusicVolume(double volume) async {
    _baseVolume = volume.clamp(0.0, 1.0);
    await bgPlayer.setVolume(_effectiveVolume);
  }

  String _strip(String asset) {
    return asset.replaceFirst('assets/', '');
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioSettings.instance.removeListener(_onSettingsChanged);
    bgPlayer.dispose();
  }
}

class BgMusicAssets {
  BgMusicAssets._();

  static const String base = 'assets/audio/bg_musics';
  static const String adventurous = '$base/bg_music_adventurous.wav';
  static const String cheerful = '$base/bg_music_cheerful.wav';
  static const String cute = '$base/bg_music_cute.wav';
  static const String funny = '$base/bg_music_funny.wav';
  static const String happy = '$base/bg_music_happy.wav';
  static const String happy2 = '$base/bg_music_happy2.wav';
  static const String happy3 = '$base/bg_music_happy3.wav';
  static const String happy4 = '$base/bg_music_happy4.wav';

  static const List<String> tracks = [
    adventurous,
    cheerful,
    cute,
    funny,
    happy,
    happy2,
    happy3,
    happy4,
  ];

  static String random() => tracks[Random().nextInt(tracks.length)];

  static String resolve(String track) {
    if (track.startsWith('assets/')) {
      return track;
    }

    if (track.contains('/')) {
      return 'assets/$track';
    }

    var name = track;

    if (!name.endsWith('.wav')) {
      name = '$name.wav';
    }

    if (!name.startsWith('bg_music_')) {
      name = 'bg_music_$name';
    }

    return '$base/$name';
  }
}

// USAGE
// SfxHelper.instance.play(Sfx.bubblePop);

abstract class Sfx {
  static const String keyTap = 'audio/sound_effects/bubble_click.wav';
  static const String bubblePop = 'audio/sound_effects/bubble_pop.wav';
}

class SfxHelper {
  SfxHelper._();
  static final SfxHelper instance = SfxHelper._();

  static const int _poolSize = 4;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  Future<void>? _initFuture;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    final ctx = AudioContext(
      android: const AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    );

    for (var i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setAudioContext(ctx);
      _pool.add(p);
    }
  }

  Future<void> preload(List<String> assets) =>
      AudioCache.instance.loadAll(assets);

  void play(String asset, {double volume = 1.0}) {
    final s = AudioSettings.instance;
    if (!s.sfxOn) return;
    init().then((_) {
      final p = _pool[_next];
      _next = (_next + 1) % _pool.length;
      return p.stop().then((_) => p.play(
        AssetSource(asset),
        volume: (volume * s.sfxVolume).clamp(0.0, 1.0),
      ));
    }).catchError((_) {});
  }
}