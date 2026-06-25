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

    'animal_habitat_intro': 'assets/audio/discovery_lagoon/animal_habitat_intro.wav',
    'q_penguin': 'assets/audio/discovery_lagoon/saan_nakatira_penguin.wav',
    'q_aso': 'assets/audio/discovery_lagoon/saan_nakatira_aso.wav',
    'q_bear': 'assets/audio/discovery_lagoon/saan_nakatira_bear.wav',
    'a_bear': 'assets/audio/discovery_lagoon/a_bear.wav',
    'a_aso': 'assets/audio/discovery_lagoon/a_aso.wav',
    'a_penguin': 'assets/audio/discovery_lagoon/a_penguin.wav',
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
