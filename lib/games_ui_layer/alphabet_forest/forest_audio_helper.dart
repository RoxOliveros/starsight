import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';

class ForestAudioHelper {

  final AudioPlayer voicePlayer = AudioPlayer();
  final AudioPlayer sfxPlayer = AudioPlayer();

  /// Plays a voice line and waits for it to finish (or times out).
  Future<void> playVoice(
      String asset, {
        Duration timeout = const Duration(seconds: 20),
      }) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = voicePlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
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
  Future<void> playSfx(String asset, {Duration fallback = const Duration(milliseconds: 900)}) async {
    try {
      final source = AssetSource(_strip(asset));
      await sfxPlayer.play(source);
      final duration = await sfxPlayer.getDuration();
      await Future.delayed(duration ?? fallback);
    } catch (e) {
      debugPrint('ForestAudioHelper: sfx error ($asset): $e');
    }
  }

  String _strip(String asset) => asset.replaceFirst('assets/', '');

  /// Call from the widget's [State.dispose].
  void dispose() {
    voicePlayer.dispose();
    sfxPlayer.dispose();
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

  /// Look up a letter call-out by name, e.g. `ForestAudioAssets.forLetter('B')`.
  static String forLetter(String letter) {
    switch (letter.toUpperCase()) {
      case 'A':
        return letterA;
      case 'B':
        return letterB;
      case 'C':
        return letterC;
      default:
        throw ArgumentError('Unknown letter: $letter');
    }
  }
}

mixin ForestAudioMixin<T extends StatefulWidget> on State<T> {
  final ForestAudioHelper audio = ForestAudioHelper();

  Future<void> playVoice(String asset) => audio.playVoice(asset);
  Future<void> playSfx(String asset) => audio.playSfx(asset);

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }
}