import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';

class ArcticAudioHelper {

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
      debugPrint('ArcticAudioHelper: voice error ($asset): $e');
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
      debugPrint('ArcticAudioHelper: sfx error ($asset): $e');
    }
  }

  String _strip(String asset) => asset.replaceFirst('assets/', '');

  /// Call from the widget's [State.dispose].
  void dispose() {
    voicePlayer.dispose();
    sfxPlayer.dispose();
  }
}

/// Shared asset paths used across multiple Arctic Numberland games,
/// so every game references the same constants instead of re-typing paths.
class ArcticAudioAssets {
  ArcticAudioAssets._();

  static const String base = 'assets/audio/arctic_numberland';
  static const String sfxBase = 'assets/audio/sound_effects';

  // Generic SFX
  static const String bubblePop = '$sfxBase/bubble_pop.wav';

  // Shape name call-outs (shared by any game involving shape matching/ID)
  static const String circle = '$base/circle.wav';
  static const String square = '$base/square.wav';
  static const String triangle = '$base/triangle.wav';
  static const String star = '$base/star.wav';

  /// Look up a shape call-out by name, e.g. `ArcticAudioAssets.forShape('star')`.
  static String forShape(String shapeName) {
    switch (shapeName) {
      case 'circle':
        return circle;
      case 'square':
        return square;
      case 'triangle':
        return triangle;
      case 'star':
        return star;
      default:
        throw ArgumentError('Unknown shape: $shapeName');
    }
  }
}

mixin ArcticAudioMixin<T extends StatefulWidget> on State<T> {
  final ArcticAudioHelper audio = ArcticAudioHelper();

  Future<void> playVoice(String asset) => audio.playVoice(asset);
  Future<void> playSfx(String asset) => audio.playSfx(asset);

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }
}