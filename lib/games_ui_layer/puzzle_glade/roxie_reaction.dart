import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum RoxieState { normal, correct, wrong }

mixin RoxieReactionMixin<T extends StatefulWidget> on State<T> {
  RoxieState roxieState = RoxieState.normal;

  // Override this in your screen to provide the AudioPlayer
  AudioPlayer get roxiePlayer;

  Future<void> showRoxieReaction(RoxieState state) async {
    if (!mounted) return;
    setState(() => roxieState = state);

    if (state == RoxieState.correct) {
      await _playRoxieAudio('assets/audio/sound_effects/shine.wav');
    } else if (state == RoxieState.wrong) {
      await _playRoxieAudio('assets/audio/puzzle_glade/try_again.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => roxieState = RoxieState.normal);
  }

  Future<void> _playRoxieAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = roxiePlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await roxiePlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Roxie audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  Widget buildRoxie(BuildContext context) {
    return Positioned(
      left: -40,
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