import 'dart:math' as math;
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_3.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

import '../lumi_game_ui_layer.dart';

class Sorry2Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Sorry2Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Sorry2Screen> createState() => _Sorry2ScreenState();
}

class _Sorry2ScreenState extends State<Sorry2Screen>
    with
        TickerProviderStateMixin,
        AiCameraMixin<Sorry2Screen>,
        AppAudioLifecycleMixin<Sorry2Screen> {
  late final AudioPlayer _audioPlayer;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  late final AnimationController _walkController;
  final Duration _walkDuration = const Duration(milliseconds: 1800);
  final Duration _stepDuration = const Duration(milliseconds: 260);
  final double _bounceHeightFraction = 0.045;

  bool _isBearSadWithTears = false;
  bool _hideLightingCard = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _walkController = AnimationController(vsync: this, duration: _walkDuration);
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSceneSequence();
    });
  }

  Future<void> _startSceneSequence() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_narration_2.wav'),
      );

      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      await _walkController.forward(from: 0);
      if (!mounted) return;

      setState(() {
        _isBearSadWithTears = true;
      });

      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_1.wav'),
      );

      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Sorry3Screen(
            priorEmotions: emotionsSoFar,
            tapTracker: widget.tapTracker,
            level: widget.level,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error playing sequence: $e');
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    _walkController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final baseCharacterHeight = MediaQuery.of(context).size.height * 1.18;
    final bearHeight = baseCharacterHeight * 0.70;

    final double startX = sw;
    final int stepCount =
        (_walkDuration.inMilliseconds / _stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);
    final double bounceHeightPx = bearHeight * _bounceHeightFraction;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_classroom.png',
              fit: BoxFit.cover,
            ),

            Positioned(
              left: sw * 0.10,
              bottom: -(baseCharacterHeight * 0.15),
              child: SizedBox(
                height: baseCharacterHeight * 0.80,
                child: Image.asset(
                  'assets/images/characters/tr.woo_the_owl.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            AnimatedBuilder(
              animation: _walkController,
              builder: (context, child) {
                final double t = _walkController.value;
                final double easedT = Curves.easeOutCubic.transform(t);
                final double dx = startX * (1 - easedT);
                final double bounce = t < 1.0
                    ? (math.sin(t * stepCount * math.pi)).abs() * bounceHeightPx
                    : 0.0;

                return Positioned(
                  right: (sw * 0.10) - dx,
                  bottom: -(baseCharacterHeight * 0.15) + bounce,
                  child: SizedBox(
                    height: bearHeight,
                    child: Image.asset(
                      _isBearSadWithTears
                          ? 'assets/images/characters/littlebear_sad_tears.png'
                          : 'assets/images/characters/bear_sad.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LumiLevelBadge(level: widget.level),
            ),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),
          ],
        ),
      ),
    );
  }
}
