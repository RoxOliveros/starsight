import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import '../business_layer/audio_settings.dart';

final AudioContext _voiceContext = AudioContext(
  android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
);
final Expando<bool> _configured = Expando<bool>();
Directory? _dir;

Future<String> _assetToFile(String assetPath) async {
  _dir ??= await getTemporaryDirectory();
  final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
  final file = File('${_dir!.path}/${assetPath.replaceAll('/', '_')}');
  if (!await file.exists() || await file.length() != bytes.length) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return file.path;
}

// ── Narration (follows the Games Audio volume) ───────────────────────────────
// USAGE
// await playAssetAudio(_audioPlayer, );
// await waitForAudio(_audioPlayer);

Future<void> playAssetAudio(AudioPlayer player, String assetPath) async {
  if (_configured[player] != true) {
    await player.setAudioContext(_voiceContext);
    _configured[player] = true;
  }
  final path = await _assetToFile(assetPath);
  await player.play(
    DeviceFileSource(path),
    volume: AudioSettings.instance.gamesVolume,
  );
}

Future<void> waitForAudio(AudioPlayer player) async {
  if (player.state != PlayerState.playing &&
      player.state != PlayerState.paused) {
    return;
  }
  try {
    await player.onPlayerStateChanged.firstWhere((s) =>
    s == PlayerState.completed ||
        s == PlayerState.stopped ||
        s == PlayerState.disposed);
  } catch (_) {}
}

// ── Sound effects (follow the Sound Effects on/off + volume) ─────────────────

// USAGE
// GamesSfxPlayer.instance.play(GameSfx.);

abstract class GameSfx {
  static const String _base = 'assets/audio/sound_effects';
  static const String alarmClock = '$_base/sfx_alarmclock.wav';
  static const String breakVase = '$_base/sfx_break_vase.wav';
  static const String bubbleClick = '$_base/sfx_bubble_click.wav';
  static const String bubblePop = '$_base/sfx_bubble_pop.wav';
  static const String build = '$_base/sfx_build.wav';
  static const String brush = '$_base/sfx_brush.wav';
  static const String carPassBy = '$_base/sfx_car_pass_by.wav';
  static const String clack = '$_base/sfx_clack.wav';
  static const String comb = '$_base/sfx_comb.wav';
  static const String eggCrack = '$_base/sfx_egg_crack.wav';
  static const String erase = '$_base/sfx_erase.wav';
  static const String flip = '$_base/sfx_flip.wav';
  static const String glowBlink = '$_base/sfx_glow_blink.wav';
  static const String plip = '$_base/sfx_plip.wav';
  static const String pour = '$_base/sfx_pour.wav';
  static const String shine = '$_base/sfx_shine.wav';
  static const String sizzle = '$_base/sfx_sizzle.wav';
  static const String thump = '$_base/sfx_thump.wav';
  static const String walk = '$_base/sfx_walk.wav';
  static const String wash = '$_base/sfx_wash.wav';
  static const String whisk = '$_base/sfx_whisk.wav';
  static const String wipe = '$_base/sfx_wipe.wav';
  static const String yey = '$_base/sfx_yey.wav';

  static const List<String> all = [
    alarmClock, breakVase, bubbleClick, bubblePop, build, clack, eggCrack,
    erase, flip, plip, pour, shine, sizzle, thump, whisk, yey,
  ];
}

class GamesSfxPlayer with WidgetsBindingObserver {
  GamesSfxPlayer._() {
    WidgetsBinding.instance.addObserver(this);
    AudioSettings.instance.addListener(_onSettingsChanged);
  }
  static final GamesSfxPlayer instance = GamesSfxPlayer._();

  final Map<String, AudioPlayer> _players = {};
  final Map<String, Future<String>> _paths = {};

  Future<String> _pathFor(String asset) {
    return _paths[asset] ??= _assetToFile(asset).catchError((e) {
      _paths.remove(asset);
      throw e;
    });
  }

  Future<void> preload(List<String> assets) async {
    try {
      await Future.wait(assets.map(_pathFor));
    } catch (e) {
      debugPrint('GamesSfxPlayer: preload failed: $e');
    }
  }

  Future<void> play(String asset, {double volume = 1.0, bool loop = false}) async {
    final s = AudioSettings.instance;
    if (!s.sfxOn) return;
    try {
      final path = await _pathFor(asset);
      var p = _players[asset];
      if (p == null) {
        p = AudioPlayer();
        _players[asset] = p;
        await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
        await p.setAudioContext(_voiceContext);
      }
      await p.play(
        DeviceFileSource(path),
        volume: (volume * s.gamesVolume).clamp(0.0, 1.0),
      );
    } catch (e) {
      debugPrint('GamesSfxPlayer: failed to play $asset: $e');
    }
  }

  Future<void> stop(String asset) async {
    try {
      await _players[asset]?.stop();
    } catch (_) {}
  }

  Future<void> stopAll() async {
    for (final p in _players.values) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  void _onSettingsChanged() {
    if (!AudioSettings.instance.sfxOn) stopAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stopAll();
  }
}