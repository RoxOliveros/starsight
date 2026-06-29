import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum DomaState { normal, correct, wrong }

mixin DomaReactionMixin<T extends StatefulWidget> on State<T> {
  DomaState domaState = DomaState.normal;

  // Override this in your screen to provide the AudioPlayer
  AudioPlayer get domaPlayer;

  Future<void> showDomaReaction(DomaState state) async {
    if (!mounted) return;
    setState(() => domaState = state);

    if (state == DomaState.correct) {
      await _playDomaAudio('assets/audio/sound_effects/shine.wav');
    } else if (state == DomaState.wrong) {
      await _playDomaAudio('assets/audio/arctic_numberland/doma_tryagain.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => domaState = DomaState.normal);
  }

  Future<void> _playDomaAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = domaPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await domaPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Dr. Woo audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
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