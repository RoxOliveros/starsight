import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum TofiState { normal, correct, wrong }

mixin TofiReactionMixin<T extends StatefulWidget> on State<T> {
  TofiState tofiState = TofiState.normal;

  // Override this in your screen to provide the AudioPlayer
  AudioPlayer get tofiPlayer;

  Future<void> showTofiReaction(TofiState state) async {
    if (!mounted) return;
    setState(() => tofiState = state);

    if (state == TofiState.correct) {
      await _playTofiAudio('assets/audio/sound_effects/shine.wav');
    } else if (state == TofiState.wrong) {
      await _playTofiAudio('assets/audio/alphabet_forest/tofi_tryagain.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => tofiState = TofiState.normal);
  }

  Future<void> _playTofiAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = tofiPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await tofiPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Dr. Woo audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  Widget buildTofi(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.50,
        child: switch (tofiState) {
          TofiState.correct => Image.asset(
            'assets/animations/characters/tofi_dancing.webp',
            fit: BoxFit.contain,
          ),
          TofiState.wrong => Image.asset(
            'assets/images/characters/tofi_tryagain.png',
            fit: BoxFit.contain,
          ),
          TofiState.normal => Image.asset(
            'assets/images/characters/tofi_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }
}