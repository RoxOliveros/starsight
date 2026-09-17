import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum TrWooState { normal, correct, wrong }

mixin TrWooReactionMixin<T extends StatefulWidget> on State<T> {
  TrWooState trWooState = TrWooState.normal;

  AudioPlayer get trWooPlayer;

  Future<void> showTrWooReaction(TrWooState state) async {
    if (!mounted) return;
    setState(() => trWooState = state);

    if (state == TrWooState.correct) {
      await _playTrWooAudio('assets/audio/sound_effects/shine.wav');
    } else if (state == TrWooState.wrong) {
      await _playTrWooAudio('assets/audio/lumi_town/dr.woo_tryagain.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => trWooState = TrWooState.normal);
  }

  Future<void> _playTrWooAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = trWooPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await trWooPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Dr. Woo audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
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