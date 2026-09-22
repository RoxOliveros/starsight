import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/bodyparts_assembly.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'lagoon_game_ui.dart';

class SeedGame extends StatefulWidget {
  final int level;

  const SeedGame({super.key, required this.level});

  @override
  _SeedGameState createState() => _SeedGameState();
}

class _SeedGameState extends State<SeedGame> with AiCameraMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GameTapTracker _tapTracker = GameTapTracker();

  bool showIntro = true;
  bool showGoodJob = false;
  bool _disposed = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  final double kikiVerticalOffset = 40.0;

  int currentLevelIndex = 0;
  bool isCorrect = false;
  late List<String> currentSequence;

  final List<List<String>> allCorrectSequences = [
    [
      'assets/images/objects/lagoon/f1.png',
      'assets/images/objects/lagoon/f2.png',
      'assets/images/objects/lagoon/f3.png',
      'assets/images/objects/lagoon/f4.png',
    ],
    [
      'assets/images/objects/lagoon/s1.png',
      'assets/images/objects/lagoon/s2.png',
      'assets/images/objects/lagoon/s3.png',
      'assets/images/objects/lagoon/s4.png',
    ],
    [
      'assets/images/objects/lagoon/m1.png',
      'assets/images/objects/lagoon/m2.png',
      'assets/images/objects/lagoon/m3.png',
      'assets/images/objects/lagoon/m4.png',
    ],
  ];

  final List<List<String>> allInitialSequences = [
    [
      'assets/images/objects/lagoon/f2.png',
      'assets/images/objects/lagoon/f4.png',
      'assets/images/objects/lagoon/f1.png',
      'assets/images/objects/lagoon/f3.png',
    ],
    [
      'assets/images/objects/lagoon/s3.png',
      'assets/images/objects/lagoon/s1.png',
      'assets/images/objects/lagoon/s4.png',
      'assets/images/objects/lagoon/s2.png',
    ],
    [
      'assets/images/objects/lagoon/m2.png',
      'assets/images/objects/lagoon/m4.png',
      'assets/images/objects/lagoon/m1.png',
      'assets/images/objects/lagoon/m3.png',
    ],
  ];

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

    currentSequence = List.from(allInitialSequences[currentLevelIndex]);
    _playIntro();
  }

  Future<void> _waitForAudioComplete() async {
    try {
      await _audioPlayer.onPlayerComplete.first;
    } catch (_) {}
  }

  void _playIntro() async {
    if (_disposed) return;
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/seed_game_intro.wav'),
    );

    _waitForAudioComplete().then((_) {
      if (!mounted || _disposed) return;
      setState(() {
        showIntro = false;
      });
    });
  }

  @override
  void dispose() {
    _disposed = true;
    disposeAiCamera();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _onItemDropped(int oldIndex, int newIndex) {
    if (isCorrect || showGoodJob) return;

    setState(() {
      final temp = currentSequence[oldIndex];
      currentSequence[oldIndex] = currentSequence[newIndex];
      currentSequence[newIndex] = temp;

      _checkWinCondition();
    });
  }

  void _checkWinCondition() {
    bool win = true;
    for (int i = 0; i < allCorrectSequences[currentLevelIndex].length; i++) {
      if (currentSequence[i] != allCorrectSequences[currentLevelIndex][i]) {
        win = false;
        break;
      }
    }

    setState(() {
      isCorrect = win;
    });

    if (isCorrect) {
      _tapTracker.recordCorrectTap();
      _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));

      if (currentLevelIndex < allCorrectSequences.length - 1) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;

          setState(() {
            currentLevelIndex++;
            currentSequence = List.from(allInitialSequences[currentLevelIndex]);
            isCorrect = false;
          });
        });
      } else {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          _saveDataAndShowGoodJob();
        });
      }
    } else {
      _tapTracker.recordMistake();
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    try {
      await LagoonDatabaseService.saveGameData(
        gameId: 'lagoon_seed_game',
        activityName: 'Seed Game',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      );
    } catch (e) {
      debugPrint("Database Error saving metrics: $e");
    }
    await LagoonProgressService.instance.markLevelComplete(11);

    if (mounted) {
      setState(() {
        showGoodJob = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_rainbow_closeup2.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          if (showIntro)
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, kikiVerticalOffset),
                child: FractionallySizedBox(
                  heightFactor: 0.9,
                  child: Image.asset(
                    'assets/images/characters/kiki_gardener.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          else
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double maxByHeight = constraints.maxHeight * 0.45;
                  double maxByWidth = constraints.maxWidth / 5.5;

                  double universalCardSize = maxByHeight < maxByWidth
                      ? maxByHeight
                      : maxByWidth;

                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        height: universalCardSize,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(7, (index) {
                            if (index % 2 == 1) {
                              return _buildArrow(universalCardSize);
                            }
                            int cardIndex = index ~/ 2;
                            return _buildDraggableSlot(
                              cardIndex,
                              universalCardSize,
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (showGoodJob)
            GoodJobOverlay(
              characterImage:
                  'assets/images/characters/cat_holding_fishbone.png',
              characterSizeFactor: 0.9,
              onNext: () async {
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BodyPartsAssemblyScreen(level: 12),
                    ),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  currentLevelIndex = 0;
                  currentSequence = List.from(allInitialSequences[0]);
                  isCorrect = false;
                  showGoodJob = false;
                  _hasSavedResult = false;
                  _tapTracker.startSession();
                });
              },
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildArrow(double height) {
    return Visibility(
      visible: isCorrect,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: height * 0.3,
          color: const Color(0xFF3E2723),
        ),
      ),
    );
  }

  Widget _buildDraggableSlot(int index, double cardSize) {
    return DragTarget<int>(
      onAcceptWithDetails: (details) => _onItemDropped(details.data, index),
      builder: (context, candidateData, rejectedData) {
        return Draggable<int>(
          data: index,
          maxSimultaneousDrags: isCorrect || showGoodJob ? 0 : 1,
          feedback: Material(
            color: Colors.transparent,
            child: _buildCardUI(currentSequence[index], true, cardSize),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _buildCardUI(currentSequence[index], false, cardSize),
          ),
          child: _buildCardUI(currentSequence[index], false, cardSize),
        );
      },
    );
  }

  Widget _buildCardUI(String imagePath, bool isDragging, double cardSize) {
    return SizedBox(
      width: cardSize,
      height: cardSize,
      child: Container(
        margin: const EdgeInsets.all(6.0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect ? const Color(0xFF81C784) : Colors.grey.shade500,
            width: 5,
          ),
          color: Colors.white,
          boxShadow: isDragging
              ? [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
