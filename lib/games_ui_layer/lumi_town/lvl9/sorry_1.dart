import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_2.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class Sorry1Screen extends StatefulWidget {
  const Sorry1Screen({super.key});

  @override
  State<Sorry1Screen> createState() => _Sorry1ScreenState();
}

class _Sorry1ScreenState extends State<Sorry1Screen>
    with AiCameraMixin<Sorry1Screen> {
  late final AudioPlayer _audioPlayer;
  final GameTapTracker _tapTracker = GameTapTracker();

  bool _hideLightingCard = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _initAndPlayAudio();
  }

  Future<void> _initAndPlayAudio() async {
    _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_narration_1.wav'),
      );

      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      final emotionsSoFar = stopAiCamera();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Sorry2Screen(
            priorEmotions: emotionsSoFar,
            tapTracker: _tapTracker,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error playing narration audio: $e');
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _tapTracker.recordGenericTap(),
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/objects/lumi/lvl9_scene1.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      'Scene asset could not be loaded.',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  );
                },
              ),
              Positioned(top: 25, left: 25, child: LumiXButton()),

              if (hasCapturedFirstFrame &&
                  !isFaceDetected &&
                  !_hideLightingCard)
                LightingPromptCard(
                  onClose: () {
                    setState(() => _hideLightingCard = true);
                    releaseFaceGate();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
