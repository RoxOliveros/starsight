import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum DrWooState { normal, correct, wrong }

mixin DrWooReactionMixin<T extends StatefulWidget> on State<T> {
  DrWooState drWooState = DrWooState.normal;

  // Override this in your screen to provide the AudioPlayer
  AudioPlayer get drWooPlayer;

  Future<void> showDrWooReaction(DrWooState state) async {
    if (!mounted) return;
    setState(() => drWooState = state);

    if (state == DrWooState.correct) {
      await _playDrWooAudio('assets/audio/sound_effects/shine.wav');
    } else if (state == DrWooState.wrong) {
      await _playDrWooAudio('assets/audio/lumi_town/dr.woo_tryagain.wav');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => drWooState = DrWooState.normal);
  }

  Future<void> _playDrWooAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = drWooPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await drWooPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Dr. Woo audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  Widget buildDrWoo(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.50,
        child: switch (drWooState) {
          DrWooState.correct => Image.asset(
            'assets/animations/characters/dr.woo_thumbsup.webp',
            fit: BoxFit.contain,
          ),
          DrWooState.wrong => Image.asset(
            'assets/images/characters/dr.woo_tryagain.png',
            fit: BoxFit.contain,
          ),
          DrWooState.normal => Image.asset(
            'assets/images/characters/dr.woo_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }
}