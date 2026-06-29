import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum DobyState { normal, correct, wrong }

mixin DobyReactionMixin<T extends StatefulWidget> on State<T> {
  DobyState dobyState = DobyState.normal;

  // Override this in your screen to provide the AudioPlayer
  AudioPlayer get dobyPlayer;

  Future<void> showDobyReaction(DobyState state) async {
    if (!mounted) return;
    setState(() => dobyState = state);

    if (state == DobyState.correct) {
      await _playDobyAudio('assets/audio/sound_effects/shine.wav');
    } else if (state == DobyState.wrong) {
      await _playDobyAudio('assets/audio/alphabet_forest/doby_tryagain.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => dobyState = DobyState.normal);
  }

  Future<void> _playDobyAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = dobyPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await dobyPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Dr. Woo audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  Widget buildDoby(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.50,
        child: switch (dobyState) {
          DobyState.correct => Image.asset(
            'assets/animations/characters/doby_dancing.webp',
            fit: BoxFit.contain,
          ),
          DobyState.wrong => Image.asset(
            'assets/images/characters/doby_tryagain.png',
            fit: BoxFit.contain,
          ),
          DobyState.normal => Image.asset(
            'assets/images/characters/doby_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }
}