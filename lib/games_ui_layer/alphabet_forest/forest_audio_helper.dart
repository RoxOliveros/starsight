import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';

class ForestAudioHelper {
  final AudioPlayer voicePlayer = AudioPlayer();
  final AudioPlayer sfxPlayer = AudioPlayer();

  // Separate player for background music so it can loop independently
  // underneath voice lines / sound effects without being stopped by them.
  final AudioPlayer bgPlayer = AudioPlayer();
  String? _currentBgTrack;

  ForestAudioHelper() {
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
      await Future.wait([
        voicePlayer.setAudioContext(mixContext),
        sfxPlayer.setAudioContext(mixContext),
        bgPlayer.setAudioContext(mixContext),
      ]);
    } catch (e) {
      debugPrint('ForestAudioHelper: failed to set mixing audio context: $e');
    }
  }

  Future<void> playVoice(
      String asset, {
        Duration timeout = const Duration(seconds: 20),
      }) async {
    StreamSubscription? sub;

    try {
      await voicePlayer.stop(); // <-- Add this

      final completer = Completer<void>();

      sub = voicePlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await voicePlayer.play(AssetSource(_strip(asset)));

      await completer.future.timeout(timeout);
    } catch (e) {
      debugPrint('ForestAudioHelper: voice error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  /// Stops any currently playing voice line.
  Future<void> stopVoice() => voicePlayer.stop();

  /// Plays a short sound effect. Does not await completion.
  Future<void> playSfx(
      String asset, {
        Duration fallback = const Duration(milliseconds: 900),
      }) async {
    try {
      final source = AssetSource(_strip(asset));
      await sfxPlayer.play(source);
      final duration = await sfxPlayer.getDuration();
      await Future.delayed(duration ?? fallback);
    } catch (e) {
      debugPrint('ForestAudioHelper: sfx error ($asset): $e');
    }
  }

  // ── BACKGROUND MUSIC ─────────────────────────────────────────────────

  //bg music volume
  Future<void> playBackgroundMusic({String? track, double volume = 0.15}) async {
    final resolved = track != null
        ? BgMusicAssets.resolve(track)
        : BgMusicAssets.random();

    if (_currentBgTrack == resolved && bgPlayer.state == PlayerState.playing) {
      return; // Already playing this track — don't restart it.
    }

    try {
      await bgPlayer.stop();
      await bgPlayer.setReleaseMode(ReleaseMode.loop);
      await bgPlayer.setVolume(volume);
      await bgPlayer.play(AssetSource(_strip(resolved)));
      _currentBgTrack = resolved;
    } catch (e) {
      debugPrint('ForestAudioHelper: bg music error ($resolved): $e');
    }
  }

  /// Stops the background music.
  Future<void> stopBackgroundMusic() async {
    await bgPlayer.stop();
    _currentBgTrack = null;
  }

  /// Adjusts background music volume without restarting the track.
  Future<void> setBackgroundMusicVolume(double volume) =>
      bgPlayer.setVolume(volume);

  String _strip(String asset) => asset.replaceFirst('assets/', '');

  /// Call from the widget's [State.dispose].
  void dispose() {
    voicePlayer.dispose();
    sfxPlayer.dispose();
    bgPlayer.dispose();
  }
}

/// Shared asset paths used across multiple Alphabet Forest games,
/// so every game references the same constants instead of re-typing paths.
class ForestAudioAssets {
  ForestAudioAssets._();

  static const String base = 'assets/audio/alphabet_forest';
  static const String sfxBase = 'assets/audio/sound_effects';

  // Letter call-outs (shared by any game involving letter matching/ID)
  static const String letterA = '$base/sound_effects/sound_a.wav';
  static const String letterB = '$base/sound_effects/sound_b.wav';
  static const String letterC = '$base/sound_effects/sound_c.wav';
  static const String letterD = '$base/sound_effects/sound_d.wav';
  static const String letterE = '$base/sound_effects/sound_e.wav';
  static const String letterF = '$base/sound_effects/sound_f.wav';
  static const String letterG = '$base/sound_effects/sound_g.wav';
  static const String letterH = '$base/sound_effects/sound_h.wav';
  static const String letterI = '$base/sound_effects/sound_i.wav';
  static const String letterJ = '$base/sound_effects/sound_j.wav';
  static const String letterK = '$base/sound_effects/sound_k.wav';
  static const String letterL = '$base/sound_effects/sound_l.wav';
  static const String letterM = '$base/sound_effects/sound_m.wav';
  static const String letterN = '$base/sound_effects/sound_n.wav';
  static const String letterO = '$base/sound_effects/sound_o.wav';
  static const String letterP = '$base/sound_effects/sound_p.wav';
  static const String letterQ = '$base/sound_effects/sound_q.wav';
  static const String letterR = '$base/sound_effects/sound_r.wav';
  static const String letterS = '$base/sound_effects/sound_s.wav';
  static const String letterT = '$base/sound_effects/sound_t.wav';
  static const String letterU = '$base/sound_effects/sound_u.wav';
  static const String letterV = '$base/sound_effects/sound_v.wav';
  static const String letterW = '$base/sound_effects/sound_w.wav';
  static const String letterX = '$base/sound_effects/sound_x.wav';
  static const String letterY = '$base/sound_effects/sound_y.wav';
  static const String letterZ = '$base/sound_effects/sound_z.wav';

  /// Look up a letter call-out by name, e.g.
  /// `ForestAudioAssets.forLetter('B')`.
  static String forLetter(String letter) {
    switch (letter.toUpperCase()) {
      case 'A':
        return letterA;
      case 'B':
        return letterB;
      case 'C':
        return letterC;
      case 'D':
        return letterD;
      case 'E':
        return letterE;
      case 'F':
        return letterF;
      case 'G':
        return letterG;
      case 'H':
        return letterH;
      case 'I':
        return letterI;
      case 'J':
        return letterJ;
      case 'K':
        return letterK;
      case 'L':
        return letterL;
      case 'M':
        return letterM;
      case 'N':
        return letterN;
      case 'O':
        return letterO;
      case 'P':
        return letterP;
      case 'Q':
        return letterQ;
      case 'R':
        return letterR;
      case 'S':
        return letterS;
      case 'T':
        return letterT;
      case 'U':
        return letterU;
      case 'V':
        return letterV;
      case 'W':
        return letterW;
      case 'X':
        return letterX;
      case 'Y':
        return letterY;
      case 'Z':
        return letterZ;
      default:
        throw ArgumentError('Unknown letter: $letter');
    }
  }
}

// USAGE
// init
// // Default: random track from bg_musics
// playBackgroundMusic();
//
// // Specific track by name (still assumes bg_musics folder)
// playBackgroundMusic(track: 'happy2');
//
// // A file in a completely different folder — just give the path
// // (with or without the leading "assets/", both work)
// playBackgroundMusic(track: 'assets/audio/level_themes/boss_fight.wav');
// playBackgroundMusic(track: 'audio/level_themes/boss_fight.wav');
//
// dispose
// stopBackgroundMusic();

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
    if (track.startsWith('assets/')) return track;
    if (track.contains('/')) return 'assets/$track';

    var name = track;
    if (!name.endsWith('.wav')) name = '$name.wav';
    if (!name.startsWith('bg_music_')) name = 'bg_music_$name';

    final candidate = '$base/$name';

    if (!tracks.contains(candidate)) {
      debugPrint(
        'BgMusicAssets: "$track" did not match a known track — '
            'playing it anyway at $candidate. Check the file name/path.',
      );
    }

    return candidate;
  }
}

mixin ForestAudioMixin<T extends StatefulWidget> on State<T> {
  final ForestAudioHelper audio = ForestAudioHelper();
  AppLifecycleListener? _audioLifecycleListener;

  Future<void> playVoice(String asset) => audio.playVoice(asset);
  Future<void> playSfx(String asset) => audio.playSfx(asset);

  // bg music volume
  Future<void> playBackgroundMusic({String? track, double volume = 0.10}) =>
      audio.playBackgroundMusic(track: track, volume: volume);

  Future<void> stopBackgroundMusic() => audio.stopBackgroundMusic();

  Future<void> setBackgroundMusicVolume(double volume) =>
      audio.setBackgroundMusicVolume(volume);

  @override
  void initState() {
    super.initState();
    _audioLifecycleListener = AppLifecycleListener(
      onPause: () => audio.bgPlayer.pause(),
      onResume: () => audio.bgPlayer.resume(),
    );
  }

  @override
  void dispose() {
    _audioLifecycleListener?.dispose();
    audio.dispose();
    super.dispose();
  }
}