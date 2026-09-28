import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl10/picking_trash_game.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_1.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';

class Sorry8Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;

  const Sorry8Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
  });

  @override
  State<Sorry8Screen> createState() => _Sorry8ScreenState();
}

class _Sorry8ScreenState extends State<Sorry8Screen>
    with TickerProviderStateMixin, AiCameraMixin<Sorry8Screen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final AnimationController _walkController;
  late final AnimationController _carSlideController;
  late final AnimationController _jumpController;

  bool _isCarWithJack = true;
  bool _showGoodJob = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _walkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _carSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playStorySequence();
    });
  }

  Future<void> _playStorySequence() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_9.wav'),
      );

      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      await _walkController.forward(from: 0);
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() {
        _isCarWithJack = false;
      });
      await _carSlideController.forward(from: 0);
      if (!mounted) return;

      await _jumpController.forward(from: 0);
      if (!mounted) return;

      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_ending.wav'),
      );
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      await _saveDataAndShowGoodJob();
    } catch (e, stackTrace) {
      debugPrint('[Sorry8] ERROR in story sequence: $e');
      debugPrint('[Sorry8] Stack trace: $stackTrace');
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;

    final finalEmotions = [...widget.priorEmotions, ...stopAiCamera()];

    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_sorry',
      activityName: 'Sorry Game',
      emotions: finalEmotions,
      totalTaps: widget.tapTracker.totalTaps,
      mistakes: widget.tapTracker.mistakeCount,
      timePlayedSeconds: widget.tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });
    TownProgressService.instance.markLevelComplete(9).catchError((e) {
      debugPrint("Database Error marking level complete: $e");
    });

    if (mounted) {
      setState(() {
        _showGoodJob = true;
      });
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    _walkController.dispose();
    _carSlideController.dispose();
    _jumpController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final double baseCharacterHeight = sh * 1.18;
    final double characterHeight = baseCharacterHeight * 0.70;
    final double baseBottomOffset = -(baseCharacterHeight * 0.15);

    final double bearLeft = sw * 0.12;
    final double bearHandX = bearLeft + (characterHeight * 0.45);

    final double jackRight = sw * 0.12;
    final double jackStartLeft = sw - jackRight - (characterHeight * 0.85);

    final double jackMeetingLeft = bearLeft + (characterHeight * 0.85);

    final double handY = baseBottomOffset + (characterHeight * 0.12);

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

            AnimatedBuilder(
              animation: Listenable.merge([
                _walkController,
                _carSlideController,
                _jumpController,
              ]),
              builder: (context, child) {
                final double walkT = Curves.easeInOut.transform(
                  _walkController.value,
                );
                final double jackCurrentLeft =
                    jackStartLeft + (jackMeetingLeft - jackStartLeft) * walkT;

                final double jackHandX =
                    jackCurrentLeft + (characterHeight * 0.08);

                final double t = _jumpController.value;
                final double bounce =
                    (math.sin(t * math.pi * 2)).abs() *
                    (characterHeight * 0.08);

                final double slideT = Curves.easeInOutCubic.transform(
                  _carSlideController.value,
                );
                final double carLeft = _isCarWithJack
                    ? jackHandX
                    : jackHandX + (bearHandX - jackHandX) * slideT;

                return Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: bearLeft,
                      bottom: baseBottomOffset + bounce,
                      child: SizedBox(
                        height: characterHeight,
                        child: Image.asset(
                          'assets/images/characters/little_bear_uniform.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Positioned(
                      left: jackCurrentLeft,
                      bottom: baseBottomOffset + bounce,
                      child: SizedBox(
                        height: characterHeight,
                        width: characterHeight * 0.85,
                        child: Image.asset(
                          'assets/images/characters/jack_smiling.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: handY + bounce,
                      left: carLeft,
                      child: Image.asset(
                        'assets/images/objects/lumi/car.png',
                        width: characterHeight * 0.35,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                );
              },
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_showGoodJob)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/tr.woo_smiling.png',

                onNext: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const PickingTrashGame(),
                    ),
                  );
                },
                onRestart: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const Sorry1Screen()),
                  );
                },
                onBack: () {
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const Sorry1Screen()),
                      (route) => route.isFirst,
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
