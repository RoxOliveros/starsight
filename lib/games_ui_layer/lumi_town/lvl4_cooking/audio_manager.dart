import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();

  AudioPlayer get sfxPlayer => _sfxPlayer;
  AudioPlayer get musicPlayer => _musicPlayer;
  AudioPlayer get voicePlayer => _voicePlayer;

  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  bool _voiceEnabled = true;

  // ── Voice dialogs ─────────────────────────────────
  Future<void> playVoice(String audioFile) async {
    if (!_voiceEnabled) return;
    await _voicePlayer.stop();
    await _voicePlayer.play(
      AssetSource('audio/lumi_town/level4_cooking/$audioFile'),
    );
  }

  Future<void> playVoiceAndWait(String audioFile) async {
    if (!_voiceEnabled) {
      debugPrint('Voice disabled, skipping $audioFile');
      return;
    }
    final path = 'audio/lumi_town/level4_cooking/$audioFile';
    final completer = Completer<void>();
    final sub = _voicePlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(AssetSource(path));
      debugPrint('Voice started: $path');
      await completer.future.timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Voice error ($path): $e');
    } finally {
      await sub.cancel();
    }
  }

  // ── Sound effects ─────────────────────────────────
  Future<void> playSfx(String sfxFile) async {
    if (!_sfxEnabled) return;
    await _sfxPlayer.play(AssetSource('audio/sound_effects/$sfxFile'));
  }

  // Preset SFX helpers
  Future<void> playPour() => playSfx('pour.wav');
  Future<void> playWhisk() => playSfx('whisk.wav');
  Future<void> playSizzle() => playSfx('sizzle.wav');
  Future<void> playFlip() => playSfx('flip.wav');
  Future<void> playTap() => playSfx('bubble_pop.wav');
  Future<void> playCrack() => playSfx('egg_crack.wav');

  void toggleSfx() => _sfxEnabled = !_sfxEnabled;
  void toggleMusic() => _musicEnabled = !_musicEnabled;
  void toggleVoice() => _voiceEnabled = !_voiceEnabled;

  bool get sfxEnabled => _sfxEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get voiceEnabled => _voiceEnabled;

  Future<void> stopAll() async {
    await _sfxPlayer.stop();
    await _musicPlayer.stop();
    await _voicePlayer.stop();
  }

  void dispose() {}
}
