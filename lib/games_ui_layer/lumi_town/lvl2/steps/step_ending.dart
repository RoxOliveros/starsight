import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl3/clean_bedroom_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../../../goodjob_prompt.dart';
import '../../lumi_game_ui_layer.dart';
import '../audio_helper.dart';
import '../bathroom_game_screen.dart';
import 'package:StarSight/business_layer/town_database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class StepEndingScreen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const StepEndingScreen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker, required this.level,
  });

  @override
  State<StepEndingScreen> createState() => _StepEndingScreenState();
}

class _StepEndingScreenState extends State<StepEndingScreen>
    with AiCameraMixin<StepEndingScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _showOverlay = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _playEndingThenShow();
  }

  Future<void> _playEndingThenShow() async {
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level2/vo_ending.wav',
    );
    await waitForAudio(_player);
    if (!mounted) return;

    await _saveDataAndMarkComplete();
    if (!mounted) return;

    setState(() => _showOverlay = true);
  }

  @override
  void dispose() {
    disposeAiCamera();
    _player.dispose();
    super.dispose();
  }

  Future<void> _saveDataAndMarkComplete() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;

    final List<String> finalEmotions = [
      ...widget.priorEmotions,
      ...stopAiCamera(),
    ];
    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_bathroom',
      activityName: 'Bathroom Routine',
      emotions: finalEmotions,
      totalTaps: widget.tapTracker.totalTaps,
      mistakes: widget.tapTracker.mistakeCount,
      timePlayedSeconds: widget.tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    TownProgressService.instance.markLevelComplete(widget.level).catchError((e) {
      debugPrint("Database Error marking level complete: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Image.asset(
              'assets/images/backgrounds/bg_lumi_bathroom.png',
              fit: BoxFit.cover,
            ),

            // Little Bear still visible beneath overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bearH = MediaQuery.of(context).size.height * 0.80;
                    return Image.asset(
                      'assets/images/characters/little_bear.png',
                      height: bearH,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(top: 25, right: 25, child: LumiLevelBadge(level: widget.level)),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            // Good Job overlay appears after ending audio
            if (_showOverlay)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/tr.woo_the_owl.png',
                onNext: _onNext,
                onRestart: _onRestart,
                onBack: _onBack,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onNext() async {
     Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CleanBedroomGameScreen(level: widget.level + 1)),
      );
  }

  void _onRestart() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => Lvl2BathroomGameScreen(level: widget.level)),
    );
  }

  Future<void> _onBack() async {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
        (route) => route.isFirst,
      );
  }
}
