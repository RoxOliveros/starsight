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