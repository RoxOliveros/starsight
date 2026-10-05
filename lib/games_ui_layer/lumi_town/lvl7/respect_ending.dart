import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl7/lumi_classroom_screen.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl8/prayer_1.dart';
import 'package:StarSight/ui_layer/lumi_town/town_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';

import '../lumi_game_ui_layer.dart';

class RespectEnding extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const RespectEnding({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<RespectEnding> createState() => _RespectEndingState();
}

class _RespectEndingState extends State<RespectEnding>
    with AiCameraMixin<RespectEnding>, AppAudioLifecycleMixin<RespectEnding> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  bool _showGoodJobOverlay = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  static const Map<String, String> charactersSmiling = {
    'bunny': 'assets/images/characters/roxie_try_again.png',
    'cat': 'assets/images/characters/kiki_smiling.png',
    'fox': 'assets/images/characters/jack_smiling.png',
    'penguin': 'assets/images/characters/doma_smiling.png',
    'owl': 'assets/images/characters/tr.woo_smiling.png',
    'dog': 'assets/images/characters/tofi_smiling.png',
    'bear': 'assets/images/characters/little_bear_uniform.png',
  };

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _startEndingSequence();
  }

  void _startEndingSequence() {
    _audioPlayer.play(
      AssetSource('audio/lumi_town/level7/respect_success.wav'),
    );

    Future.delayed(const Duration(seconds: 20), () async {
      if (!mounted) return;
      await _saveDataAndMarkComplete();
      if (!mounted) return;
      setState(() {
        _showGoodJobOverlay = true;
      });
    });
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveDataAndMarkComplete() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;

    final finalEmotions = [...widget.priorEmotions, ...stopAiCamera()];

    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_respect',
      activityName: 'Classroom Respect',
      emotions: finalEmotions,
      totalTaps: widget.tapTracker.totalTaps,
      mistakes: widget.tapTracker.mistakeCount,
      timePlayedSeconds: widget.tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    TownProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
    });
  }

  Widget _positionedCharacter(
    String imagePath, {
    required double left,
    required double bottom,
    required double width,
    required int delayMs,
  }) {
    return Positioned(
      left: left,
      bottom: bottom,
      width: width,
      child: Image.asset(imagePath, fit: BoxFit.contain)
          .animate(
            onPlay: (c) => c.repeat(reverse: true),
            delay: Duration(milliseconds: delayMs),
          )
          .moveY(
            begin: 0,
            end: -14,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    'assets/images/backgrounds/bg_lumi_classroom.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                alignment: Alignment.bottomCenter,
                children: [
                  _positionedCharacter(
                    charactersSmiling['dog']!,
                    left: -sw * -0.05,
                    bottom: -sh * 0.02,
                    width: sw * 0.35,
                    delayMs: 0,
                  ),
                  _positionedCharacter(
                    charactersSmiling['cat']!,
                    left: sw * 0.62,
                    bottom: -sh * 0.02,
                    width: sw * 0.35,
                    delayMs: 150,
                  ),

                  _positionedCharacter(
                    charactersSmiling['bunny']!,
                    left: -sw * 0.01,
                    bottom: -sh * 0.22,
                    width: sw * 0.30,
                    delayMs: 300,
                  ),
                  _positionedCharacter(
                    charactersSmiling['penguin']!,
                    left: sw * 0.15,
                    bottom: -sh * 0.20,
                    width: sw * 0.30,
                    delayMs: 450,
                  ),
                  _positionedCharacter(
                    charactersSmiling['bear']!,
                    left: sw * 0.60,
                    bottom: -sh * 0.28,
                    width: sw * 0.25,
                    delayMs: 750,
                  ),
                  _positionedCharacter(
                    charactersSmiling['fox']!,
                    left: sw * 0.74,
                    bottom: -sh * 0.20,
                    width: sw * 0.30,
                    delayMs: 900,
                  ),

                  _positionedCharacter(
                    charactersSmiling['owl']!,
                    left: sw * 0.33,
                    bottom: -sh * 0.18,
                    width: sw * 0.35,
                    delayMs: 600,
                  ),
                ],
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

            if (_showGoodJobOverlay)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/tr.woo_smiling.png',

                onNext: () async {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => Prayer1(level: widget.level + 1),
                    ),
                  );
                },
                onRestart: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => LumiClassroomScreen(level: widget.level),
                    ),
                  );
                },
                onBack: () async {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
                    (route) => route.isFirst,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
