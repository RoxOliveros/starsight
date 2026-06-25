import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class LagoonAudio {
  LagoonAudio._internal();

  static final LagoonAudio instance = LagoonAudio._internal();

  final AudioPlayer _player = AudioPlayer();

  static const Map<String, String> _sounds = {
    'correct': 'assets/audio/sound_effects/bubble_pop.wav',
    'success': 'assets/audio/sound_effects/shine.wav',

    'head': 'assets/audio/discovery_lagoon/ulo.wav',
    'shoulder': 'assets/audio/discovery_lagoon/balikat.wav',
    'knee': 'assets/audio/discovery_lagoon/tuhod.wav',
    'feet': 'assets/audio/discovery_lagoon/paa.wav',

    'q_penguin': 'assets/audio/discovery_lagoon/saan_nakatira_penguin.wav',
    'q_aso': 'assets/audio/discovery_lagoon/saan_nakatira_aso.wav',
    'q_bear': 'assets/audio/discovery_lagoon/saan_nakatira_bear.wav',
    'a_bear': 'assets/audio/discovery_lagoon/a_bear.wav',
    'a_aso': 'assets/audio/discovery_lagoon/a_aso.wav',
    'a_penguin': 'assets/audio/discovery_lagoon/a_penguin.wav',

    'spring': 'assets/audio/discovery_lagoon/spring.wav',
    'summer': 'assets/audio/discovery_lagoon/summer.wav',
    'winter': 'assets/audio/discovery_lagoon/winter.wav',
    'autumn': 'assets/audio/discovery_lagoon/autumn.wav',

    'weather_q_sunny':  'assets/audio/discovery_lagoon/weather_q_sunny.wav',
    'weather_win_sunny':'assets/audio/discovery_lagoon/weather_win_sunny.wav',
    'weather_q_rainy':  'assets/audio/discovery_lagoon/weather_q_rainy.wav',
    'weather_win_rainy':'assets/audio/discovery_lagoon/weather_win_rainy.wav',
    'weather_q_cloudy': 'assets/audio/discovery_lagoon/weather_q_cloudy.wav',
    'weather_win_cloudy':'assets/audio/discovery_lagoon/weather_win_cloudy.wav',
    'weather_q_windy':  'assets/audio/discovery_lagoon/weather_q_windy.wav',
    'weather_win_windy':'assets/audio/discovery_lagoon/weather_win_windy.wav',
  };

  Future<void> play(String key) async {
    final path = _sounds[key];
    if (path == null) {
      debugPrint('LagoonAudio: no sound registered for key "$key"');
      return;
    }
    try {
      await _player.stop(); // ← add this
      await _player.play(AssetSource(path.replaceFirst('assets/', '')));
    } catch (e) {
      debugPrint('LagoonAudio: error playing "$key" ($path): $e');
    }
  }

  Future<void> playThenCallback(String key, VoidCallback onFinished) async {
    final path = _sounds[key];
    if (path == null) {
      debugPrint('LagoonAudio: no sound registered for key "$key"');
      onFinished();
      return;
    }
    try {
      await _player.stop();
      await _player.play(AssetSource(path.replaceFirst('assets/', '')));
      await _player.onPlayerComplete.first; // wait for audio to finish
      onFinished();
    } catch (e) {
      debugPrint('LagoonAudio: error playing "$key" ($path): $e');
      onFinished(); // still show dialog even if audio fails
    }
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
