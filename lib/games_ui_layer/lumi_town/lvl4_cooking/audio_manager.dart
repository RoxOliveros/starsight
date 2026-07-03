import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();

  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  bool _voiceEnabled = true;

  // ── Background music ──────────────────────────────
  Future<void> playBgMusic() async {
    if (!_musicEnabled) return;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    //TODO await _musicPlayer.play(AssetSource('audio/bg_music.wav'), volume: 0.4);
  }

  Future<void> stopBgMusic() async {
    await _musicPlayer.stop();
  }

  // ── Voice dialogs ─────────────────────────────────
  Future<void> playVoice(String audioFile) async {
    if (!_voiceEnabled) return;
    await _voicePlayer.stop();
    await _voicePlayer.play(AssetSource('audio/lumi_town/level4_cooking/$audioFile'));
  }

  // ── Sound effects ─────────────────────────────────
  Future<void> playSfx(String sfxFile) async {
    if (!_sfxEnabled) return;
    await _sfxPlayer.play(AssetSource('audio/lumi_town/level4_cooking/$sfxFile'));
  }

  //TODO @ron add sound effects
  // Preset SFX helpers
  // Future<void> playPour() => playSfx('sfx_pour.wav');
  // Future<void> playWhisk() => playSfx('sfx_whisk.wav');
  // Future<void> playSizzle() => playSfx('sfx_sizzle.wav');
  // Future<void> playFlip() => playSfx('sfx_flip.wav');
  // Future<void> playDone() => playSfx('sfx_done.wav');
  // Future<void> playTap() => playSfx('sfx_tap.wav');
  // Future<void> playWrong() => playSfx('sfx_wrong.wav');
  // Future<void> playDrizzle() => playSfx('sfx_drizzle.wav');
  // Future<void> playCelebration() => playSfx('sfx_celebration.wav');
  // Future<void> playCrack() => playSfx('sfx_crack.wav');

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

  void dispose() {

  }
}
