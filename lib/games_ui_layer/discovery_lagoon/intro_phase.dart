import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

enum LagoonScreenPhase { intro, game }

mixin LagoonIntroMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  // ── Required overrides from the host screen ─────────────────────────────
  AudioPlayer get introAudioPlayer;

  // ── Animation controllers (character slide + idle float) ────────────────
  late AnimationController introFloatCtrl;
  late AnimationController introSlideCtrl;
  late Animation<Offset> introSlide;
  late Animation<double> introFade;

  bool _introInitialized = false;

  /// Call this inside initState(), before startLagoonIntro().
  void initLagoonIntro() {
    introFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    introSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    introSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: introSlideCtrl, curve: Curves.elasticOut),
    );

    introFade = CurvedAnimation(
      parent: introSlideCtrl,
      curve: const Interval(0, 0.4),
    );

    _introInitialized = true;
  }

  /// Call this inside dispose().
  void disposeLagoonIntro() {
    if (!_introInitialized) return;
    introFloatCtrl.dispose();
    introSlideCtrl.dispose();
  }

  Future<void> startLagoonIntro({
    required String introAudioAsset,
    required VoidCallback onGameStart,
    Duration preDelay = const Duration(milliseconds: 300),
    Duration postDelay = const Duration(milliseconds: 400),
  }) async {
    await Future.delayed(preDelay);
    if (!mounted) return;

    introSlideCtrl.forward();

    await _playIntroAudio(introAudioAsset);
    if (!mounted) return;

    await Future.delayed(postDelay);
    if (!mounted) return;

    onGameStart();
  }

  Future<void> _playIntroAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = introAudioPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await introAudioPlayer.play(
        AssetSource(asset.replaceFirst('assets/', '')),
      );
      await completer.future.timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Lagoon intro audio error ($asset): $e');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      await sub?.cancel();
    }
  }

  Widget buildLagoonIntroCharacter({double heightFactor = 0.95}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final charH = h * heightFactor;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: introFloatCtrl, curve: Curves.easeInOut),
        );

        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: introSlide,
              child: FadeTransition(
                opacity: introFade,
                child: AnimatedBuilder(
                  animation: introFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, floatY),
                    child: child,
                  ),
                  child: Image.asset(
                    'assets/images/characters/cat_holding_fishbone.png',
                    height: charH,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Text('🐱', style: TextStyle(fontSize: charH * 0.5)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}