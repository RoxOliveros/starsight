import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioHelper {
  final AudioPlayer bgPlayer = AudioPlayer();

  String? _currentBgTrack;

  AudioHelper() {
    _applyMixingAudioContext();
  }

  Future<void> _applyMixingAudioContext() async {
    final mixContext = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
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

    // Don't restart the exact same song if it's already playing.
    if (_currentBgTrack == resolved &&
        bgPlayer.state == PlayerState.playing) {
      return;
    }

    try {
      await bgPlayer.stop();

      await bgPlayer.setReleaseMode(
        ReleaseMode.loop,
      );

      await bgPlayer.setVolume(volume);

      await bgPlayer.play(
        AssetSource(_strip(resolved)),
      );

      _currentBgTrack = resolved;

      debugPrint(
        'AudioHelper: playing background music $resolved',
      );
    } catch (e) {
      debugPrint(
        'AudioHelper: background music error ($resolved): $e',
      );
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await bgPlayer.stop();
      _currentBgTrack = null;
    } catch (e) {
      debugPrint(
        'AudioHelper: failed to stop background music: $e',
      );
    }
  }

  Future<void> pauseBackgroundMusic() async {
    try {
      if (bgPlayer.state == PlayerState.playing) {
        await bgPlayer.pause();
      }
    } catch (e) {
      debugPrint(
        'AudioHelper: failed to pause background music: $e',
      );
    }
  }

  Future<void> resumeBackgroundMusic() async {
    try {
      if (bgPlayer.state == PlayerState.paused) {
        await bgPlayer.resume();
      }
    } catch (e) {
      debugPrint(
        'AudioHelper: failed to resume background music: $e',
      );
    }
  }

  Future<void> setBackgroundMusicVolume(
      double volume,
      ) async {
    await bgPlayer.setVolume(
      volume.clamp(0.0, 1.0),
    );
  }

  String _strip(String asset) {
    return asset.replaceFirst('assets/', '');
  }

  void dispose() {
    bgPlayer.dispose();
  }
}


/// Shared background-music assets.
///
/// These can be used by ANY StarSight world/game.
class BgMusicAssets {
  BgMusicAssets._();

  static const String base =
      'assets/audio/bg_musics';

  static const String adventurous =
      '$base/bg_music_adventurous.wav';

  static const String cheerful =
      '$base/bg_music_cheerful.wav';

  static const String cute =
      '$base/bg_music_cute.wav';

  static const String funny =
      '$base/bg_music_funny.wav';

  static const String happy =
      '$base/bg_music_happy.wav';

  static const String happy2 =
      '$base/bg_music_happy2.wav';

  static const String happy3 =
      '$base/bg_music_happy3.wav';

  static const String happy4 =
      '$base/bg_music_happy4.wav';

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

  static String random() {
    return tracks[
    Random().nextInt(tracks.length)
    ];
  }

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