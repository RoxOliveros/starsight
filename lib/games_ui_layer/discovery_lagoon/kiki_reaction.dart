import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum KikiState { normal, correct, wrong }

mixin KikiReactionMixin<T extends StatefulWidget> on State<T> {
  KikiState kikiState = KikiState.normal;

  // Override this in your screen to provide the AudioPlayer
  AudioPlayer get kikiPlayer;

  Future<void> showKikiReaction(KikiState state) async {
    if (!mounted) return;
    setState(() => kikiState = state);

    if (state == KikiState.correct) {
      await _playKikiAudio('assets/audio/sound_effects/shine.wav');
    } else if (state == KikiState.wrong) {
      await _playKikiAudio('assets/audio/discovery_lagoon/kiki_tryagain.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => kikiState = KikiState.normal);
  }

  Future<void> _playKikiAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = kikiPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await kikiPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Dr. Woo audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  Widget buildKiki(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.50,
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