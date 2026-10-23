import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../games_audio_helper.dart';

// USAGE
//
// RoxieReactionMixin
//
// final AudioPlayer _roxiePlayer = AudioPlayer();
//
// @override
// AudioPlayer get roxiePlayer => _roxiePlayer;
//
// dispose
// _roxiePlayer.dispose();
//
// right
// unawaited(_roxiePlayer.stop());
// showRoxieReaction(RoxieState.correct);
//
// wrong
// showRoxieReaction(RoxieState.wrong);
//
// build
// if (_screenPhase == _ScreenPhase.game) buildRoxie(context),

enum RoxieState { normal, correct, wrong }

mixin RoxieReactionMixin<T extends StatefulWidget> on State<T> {
  RoxieState roxieState = RoxieState.normal;

  AudioPlayer get roxiePlayer;

  Future<void> showRoxieReaction(RoxieState state) async {
    if (!mounted) return;
    setState(() => roxieState = state);

    if (state == RoxieState.correct) {
      unawaited(roxiePlayer.stop());
      GamesSfxPlayer.instance.play(GameSfx.shine);
    } else if (state == RoxieState.wrong) {
      await playAssetAudio(roxiePlayer, 'assets/audio/puzzle_glade/try_again.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => roxieState = RoxieState.normal);
  }

  Widget buildRoxie(BuildContext context) {
    return Positioned(
      left: -20,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.50,
        child: switch (roxieState) {
          RoxieState.correct => Image.asset(
            'assets/animations/characters/roxie_clapping.webp',
            fit: BoxFit.contain,
          ),
          RoxieState.wrong => Image.asset(
            'assets/images/characters/roxie_try_again.png',
            fit: BoxFit.contain,
          ),
          RoxieState.normal => Image.asset(
            'assets/images/characters/roxie_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }
}