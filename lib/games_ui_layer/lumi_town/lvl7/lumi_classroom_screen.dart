import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../games_audio_helper.dart';
import '../lumi_game_ui_layer.dart';
import 'respect_1.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class LumiClassroomScreen extends StatefulWidget {
  final int level;

  const LumiClassroomScreen({super.key, required this.level});

  @override
  State<LumiClassroomScreen> createState() => _LumiClassroomScreenState();
}

class _LumiClassroomScreenState extends State<LumiClassroomScreen>
    with
        TrWooReactionMixin,
        AiCameraMixin<LumiClassroomScreen>,
        AppAudioLifecycleMixin<LumiClassroomScreen> {

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playIntroAudio();
    });
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  AudioPlayer get trWooPlayer => _audioPlayer;

  Future<void> showDrWooReactionQuietly(TrWooState state) async {
    if (!mounted) return;
    setState(() => trWooState = state);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => trWooState = TrWooState.normal);
  }

  Future<void> _playIntroAudio() async {
    try {
      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level7/respect_intro.wav');
      await waitForAudio(_audioPlayer);
      if (!mounted) return;

      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level7/respect_tutorial.wav');
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          showDrWooReactionQuietly(TrWooState.correct);
        }
      });

      await waitForAudio(_audioPlayer);
      if (!mounted) return;

      final emotionsSoFar = stopAiCamera();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Respect1Screen(
            priorEmotions: emotionsSoFar,
            tapTracker: _tapTracker,
            level: widget.level,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error playing audio sequence: $e');
    }
  }

  @override
  Widget buildTrWoo(BuildContext context) {
    final owlHeight = MediaQuery.of(context).size.height * 1.18;

    return Positioned(
      left: 0,
      right: 0,
      bottom: -(owlHeight * 0.15),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: owlHeight,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_classroom.png',
              fit: BoxFit.cover,
            ),
            buildTrWoo(context),
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
