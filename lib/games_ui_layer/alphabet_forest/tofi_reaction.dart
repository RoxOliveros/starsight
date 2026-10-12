import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../games_audio_helper.dart';

// USAGE
//
// TofiReactionMixin
//
// final AudioPlayer _tofiPlayer = AudioPlayer();
//
// @override
// AudioPlayer get tofiPlayer => _tofiPlayer;
//
// dispose
// _tofiPlayer.dispose();
//
// right
// showTofiReaction(TofiState.correct);
//
// wrong
// showTofiReaction(TofiState.wrong);
//
// build
// if (_screenPhase == introgame) buildTofi(context),
// or
// buildTofi in gamephase or after introphase

enum TofiState { normal, correct, wrong }

mixin TofiReactionMixin<T extends StatefulWidget> on State<T> {
  TofiState tofiState = TofiState.normal;

  AudioPlayer get tofiPlayer;

  Future<void> showTofiReaction(TofiState state) async {
    if (!mounted) return;
    setState(() => tofiState = state);

    if (state == TofiState.correct) {
      unawaited(tofiPlayer.stop());
      GamesSfxPlayer.instance.play(GameSfx.shine);
    } else if (state == TofiState.wrong) {
      await playAssetAudio(
        tofiPlayer,
        'assets/audio/alphabet_forest/tofi_tryagain.wav',
      );
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => tofiState = TofiState.normal);
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