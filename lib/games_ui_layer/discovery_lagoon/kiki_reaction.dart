import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../games_audio_helper.dart';

// USAGE
//
// KikiReactionMixin
//
// final AudioPlayer _kikiPlayer = AudioPlayer();
//
// @override
// AudioPlayer get kikiPlayer => _kikiPlayer;
//
// dispose
// _kikiPlayer.dispose();
//
// right
// unawaited(_kikiPlayer.stop());
// showKikiReaction(KikiState.correct);
//
// wrong
// showKikiReaction(KikiState.wrong);
//
// build
// if (_screenPhase == introgame) buildKiki(context),
// or
// buildKiki in gamephase or after introphase

enum KikiState { normal, correct, wrong }

mixin KikiReactionMixin<T extends StatefulWidget> on State<T> {
  KikiState kikiState = KikiState.normal;

  AudioPlayer get kikiPlayer;

  Future<void> showKikiReaction(KikiState state) async {
    if (!mounted) return;
    setState(() => kikiState = state);

    if (state == KikiState.correct) {
      unawaited(kikiPlayer.stop());
      GamesSfxPlayer.instance.play(GameSfx.shine);
    } else if (state == KikiState.wrong) {
      await playAssetAudio(
        kikiPlayer,
        'assets/audio/discovery_lagoon/kiki_tryagain.wav',
      );
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => kikiState = KikiState.normal);
  }

  Widget buildKiki(
      BuildContext context, {
        double heightFactor = 0.50,
      }) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * heightFactor,
        child: switch (kikiState) {
          KikiState.correct => Image.asset(
            'assets/animations/characters/kiki_cheering.webp',
            fit: BoxFit.contain,
          ),
          KikiState.wrong => Image.asset(
            'assets/images/characters/kiki_tryagain.png',
            fit: BoxFit.contain,
          ),
          KikiState.normal => Image.asset(
            'assets/images/characters/kiki_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }
}