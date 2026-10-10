import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../games_audio_helper.dart';

// USAGE
//
// TrWooReactionMixin
//
// final AudioPlayer _trWooPlayer = AudioPlayer();
//
// @override
// AudioPlayer get trWooPlayer => _trWooPlayer;
//
// dispose
// _trWooPlayer.dispose();
//
// right
// unawaited(_trWooPlayer.stop());
// showTrWooReaction(TrWooState.correct);
//
// wrong
// showTrWooReaction(TrWooState.wrong);
//
// build
// if (_screenPhase == introgame) buildTrWoo(context),
// or
// buildtrwoo in gamephase or after introphase

enum TrWooState { normal, correct, wrong }

mixin TrWooReactionMixin<T extends StatefulWidget> on State<T> {
  TrWooState trWooState = TrWooState.normal;

  AudioPlayer get trWooPlayer;

  Future<void> showTrWooReaction(TrWooState state) async {
    if (!mounted) return;
    setState(() => trWooState = state);

    if (state == TrWooState.correct) {
      GamesSfxPlayer.instance.play(GameSfx.shine);
    } else if (state == TrWooState.wrong) {
      await playAssetAudio(trWooPlayer, 'assets/audio/lumi_town/dr.woo_tryagain.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => trWooState = TrWooState.normal);
  }

  Widget buildTrWoo(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.50,
        child: switch (trWooState) {
          TrWooState.correct => Image.asset(
            'assets/animations/characters/dr.woo_thumbsup.webp',
            fit: BoxFit.contain,
          ),
          TrWooState.wrong => Image.asset(
            'assets/images/characters/tr.woo_tryagain.png',
            fit: BoxFit.contain,
          ),
          TrWooState.normal => Image.asset(
            'assets/images/characters/tr.woo_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }
}