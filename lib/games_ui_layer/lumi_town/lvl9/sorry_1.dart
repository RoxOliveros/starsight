import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_2.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/game_loading_mixin.dart';
import '../../../ui_layer/loading_screen.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../games_audio_helper.dart';
import '../lumi_game_ui_layer.dart';

class Sorry1Screen extends StatefulWidget {
  final int level;

  const Sorry1Screen({super.key, required this.level});

  @override
  State<Sorry1Screen> createState() => _Sorry1ScreenState();
}

class _Sorry1ScreenState extends State<Sorry1Screen>
    with AiCameraMixin<Sorry1Screen>, GameLoadingMixin, AppAudioLifecycleMixin<Sorry1Screen> {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final GameTapTracker _tapTracker = GameTapTracker();

  bool _hideLightingCard = false;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

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
    finishLoading(_initAndPlayAudio);
  }

  Future<void> _initAndPlayAudio() async {
    try {
      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level9/sorry_narration_1.wav');
      await waitForAudio(_audioPlayer);
      if (!mounted) return;

      final emotionsSoFar = stopAiCamera();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Sorry2Screen(
            priorEmotions: emotionsSoFar,
            tapTracker: _tapTracker,
            level: widget.level,
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
      body: buildWithLoading(
        loadingScreen: Container(
          color: Colors.white,
          child: LoadingScreen.lumiTown(),
        ),
        gameBuilder: () => Listener(
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
                Positioned(
                  top: 25,
                  right: 25,
                  child: LumiLevelBadge(level: widget.level),
                ),

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
      ),
    );
  }
}
