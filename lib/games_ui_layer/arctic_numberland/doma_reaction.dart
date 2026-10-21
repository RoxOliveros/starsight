import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../games_audio_helper.dart';

// USAGE
//
// DomaReactionMixin
//
// final AudioPlayer _domaPlayer = AudioPlayer();
//
// @override
// AudioPlayer get domaPlayer => _domaPlayer;
//
// dispose
// _domaPlayer.dispose();
//
// right
// unawaited(_domaPlayer.stop());
// showDomaReaction(DomaState.correct);
//
// wrong
// showDomaReaction(DomaState.wrong);
//
// build
// if (_screenPhase == introgame) buildDoma(context),
// or
// buildDoma in gamephase or after introphase

enum DomaState { normal, correct, wrong }

mixin DomaReactionMixin<T extends StatefulWidget> on State<T> {
  DomaState domaState = DomaState.normal;

  AudioPlayer get domaPlayer;

  Future<void> showDomaReaction(DomaState state) async {
    if (!mounted) return;
    setState(() => domaState = state);

    if (state == DomaState.correct) {
      unawaited(domaPlayer.stop());
      GamesSfxPlayer.instance.play(GameSfx.shine);
    } else if (state == DomaState.wrong) {
      await playAssetAudio(domaPlayer, 'assets/audio/arctic_numberland/doma_tryagain.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => domaState = DomaState.normal);
  }

  Widget buildDoma(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.50,
        child: switch (domaState) {
          DomaState.correct => Image.asset(
            'assets/animations/characters/doma_flying.webp',
            fit: BoxFit.contain,
          ),
          DomaState.wrong => Image.asset(
            'assets/images/characters/doma_tryagain.png',
            fit: BoxFit.contain,
          ),
          DomaState.normal => Image.asset(
            'assets/images/characters/doma_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }
}