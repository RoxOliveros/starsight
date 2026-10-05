import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_7.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

import '../lumi_game_ui_layer.dart';

class Sorry6Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Sorry6Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Sorry6Screen> createState() => _Sorry6ScreenState();
}

class _Sorry6ScreenState extends State<Sorry6Screen>
    with AiCameraMixin<Sorry6Screen>, AppAudioLifecycleMixin<Sorry6Screen> {
  late final AudioPlayer _audioPlayer;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  bool _hideLightingCard = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playSceneAudio();
    });
  }

  Future<void> _playSceneAudio() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_7.wav'),
      );

      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Sorry7Screen(
            priorEmotions: emotionsSoFar,
            tapTracker: widget.tapTracker,
            level: widget.level,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error playing audio for sorry_6 screen: $e');
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
    final sw = MediaQuery.of(context).size.width;
    final baseCharacterHeight = MediaQuery.of(context).size.height * 1.18;

    final characterHeight = baseCharacterHeight * 0.70;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_classroom.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => const Center(
                child: Text(
                  'Background could not be loaded.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),

            Positioned(
              left: sw * 0.12,
              bottom: -(baseCharacterHeight * 0.15),
              child: SizedBox(
                height: characterHeight,
                child: Image.asset(
                  'assets/images/characters/littlebear_sad_tears.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Positioned(
              right: sw * 0.12,
              bottom: -(baseCharacterHeight * 0.15),
              child: SizedBox(
                height: characterHeight,
                width: characterHeight * 0.85,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      'assets/images/characters/jack_sad.png',
                      height: characterHeight,
                      fit: BoxFit.contain,
                    ),

                    Positioned(
                      bottom: characterHeight * 0.12,
                      left: characterHeight * 0.08,
                      child: Image.asset(
                        'assets/images/objects/lumi/car.png',
                        width: characterHeight * 0.35,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
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
