import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';

class PuzzleAudioHelper {

  final AudioPlayer voicePlayer = AudioPlayer();
  final AudioPlayer sfxPlayer = AudioPlayer();

  /// Plays a voice line (e.g. a shape name call-out) and waits for it to
  /// finish, or times out.
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
      debugPrint('PuzzleAudioHelper: voice error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  /// Stops any currently playing voice line.
  Future<void> stopVoice() => voicePlayer.stop();

  /// Plays a short sound effect. Does not await full completion.
  Future<void> playSfx(String asset, {Duration fallback = const Duration(milliseconds: 900)}) async {
    try {
      final source = AssetSource(_strip(asset));
      await sfxPlayer.play(source);
      final duration = await sfxPlayer.getDuration();
      await Future.delayed(duration ?? fallback);
    } catch (e) {
      debugPrint('PuzzleAudioHelper: sfx error ($asset): $e');
    }
  }

  String _strip(String asset) => asset.replaceFirst('assets/', '');

  /// Call from the widget's [State.dispose].
  void dispose() {
    voicePlayer.dispose();
    sfxPlayer.dispose();
  }
}

/// Shared asset paths used across Puzzle Glade games, so every game
/// references the same constants instead of re-typing paths.
class PuzzleAudioAssets {
  PuzzleAudioAssets._();

  static const String base = 'assets/audio/puzzle_glade';
  static const String sfxBase = 'assets/audio/sound_effects';

  // Generic SFX
  static const String shine = '$sfxBase/shine.wav';
  static const String bubblePop = '$sfxBase/bubble_pop.wav';

  // Shape name call-outs (shared by any game involving shape matching/ID)
  static const String circle = '$base/circle.wav';
  static const String square = '$base/square.wav';
  static const String triangle = '$base/triangle.wav';
  static const String rectangle = '$base/rectangle.wav';
  static const String star = '$base/star.wav';
  static const String heart = '$base/heart.wav';

  /// Look up a shape call-out by name, e.g. `PuzzleAudioAssets.forShape('star')`.
  static String forShape(String shapeName) {
    switch (shapeName) {
      case 'circle':
        return circle;
      case 'square':
        return square;
      case 'triangle':
        return triangle;
      case 'rectangle':
        return rectangle;
      case 'star':
        return star;
      case 'heart':
        return heart;
      default:
        throw ArgumentError('Unknown shape: $shapeName');
    }
  }
}

mixin PuzzleAudioMixin<T extends StatefulWidget> on State<T> {
  final PuzzleAudioHelper puzzleAudio = PuzzleAudioHelper();

  Future<void> playVoice(String asset) => puzzleAudio.playVoice(asset);
  Future<void> playSfx(String asset) => puzzleAudio.playSfx(asset);

  @override
  void dispose() {
    puzzleAudio.dispose();
    super.dispose();
  }
}
