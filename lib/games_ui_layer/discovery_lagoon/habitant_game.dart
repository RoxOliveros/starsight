import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/seed_game.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';

import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'lagoon_game_ui.dart';

class CharacterAdjustment {
  final double size;
  final double offsetX;
  final double offsetY;

  const CharacterAdjustment({
    this.size = 150.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });
}

class HabitantGame extends StatefulWidget {
  final int level;

  const HabitantGame({super.key, required this.level});

  @override
  State<HabitantGame> createState() => _HabitantGameState();
}

class _HabitantGameState extends State<HabitantGame> with AiCameraMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _audioSubscription;
  final GameTapTracker _tapTracker = GameTapTracker();

  bool _showIntro = true;
  bool _isGameWon = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  Map<String, String> currentPlacements = {
    'arctic': 'dog',
    'town': 'frog',
    'waterfall': 'bear',
    'forest': 'penguin',
  };

  final Map<String, String> correctHabitats = {
    'dog': 'town',
    'frog': 'waterfall',
    'bear': 'forest',
    'penguin': 'arctic',
  };

  final Map<String, String> sadImages = {
    'dog': 'tofi_cold.png',
    'frog': 'frog_sad.png',
    'bear': 'little_bear_wet.png',
    'penguin': 'doma_sweat.png',
  };

  final Map<String, String> happyImages = {
    'dog': 'tofi_smiling.png',
    'frog': 'frog.png',
    'bear': 'little_bear_uniform.png',
    'penguin': 'doma_smiling.png',
  };

  final Map<String, CharacterAdjustment> adjustments = {
    'dog': const CharacterAdjustment(
      size: 200.0,
      offsetX: -15.0,
      offsetY: 60.0,
    ),
    'frog': const CharacterAdjustment(
      size: 175.0,
      offsetX: 10.0,
      offsetY: 60.0,
    ),
    'bear': const CharacterAdjustment(
      size: 200.0,
      offsetX: -15.0,
      offsetY: 50.0,
    ),
    'penguin': const CharacterAdjustment(
      size: 210.0,
      offsetX: 10.0,
      offsetY: 40.0,
    ),
  };

  final CharacterAdjustment introCatAdjustment = const CharacterAdjustment(
    size: 400.0,
    offsetX: 0.0,
    offsetY: 80.0,
  );

  final double introHeightFactor = 1.0;

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

    _playIntro();
  }

  Future<void> _playIntro() async {
    _audioSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && _showIntro) {
        setState(() {
          _showIntro = false;
        });
      }
    });

    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/habitant_game_intro_tutorial.wav'),
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    OrientationService.setLandscape();
    _audioSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(bool isCorrect) async {
    if (isCorrect) {
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
    }
  }

  String _getCharacterImage(String characterId, String currentZone) {
    if (correctHabitats[characterId] == currentZone) {
      return happyImages[characterId]!;
    }
    return sadImages[characterId]!;
  }

  void _checkForWin() {
    bool allCorrect = true;
    currentPlacements.forEach((zoneId, characterId) {
      if (correctHabitats[characterId] != zoneId) {
        allCorrect = false;
      }
    });

    if (allCorrect) {
      _saveDataAndShowGoodJob();
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    try {
      await LagoonDatabaseService.saveGameData(
        gameId: 'lagoon_habitant_game',
        activityName: 'Habitant Game',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      );
    } catch (e) {
      debugPrint("Database Error saving metrics: $e");
    }
    await LagoonProgressService.instance.markLevelComplete(10);

    if (mounted) {
      setState(() {
        _isGameWon = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildDropZone('arctic', 'bg_arctic.png')),
                    Expanded(child: _buildDropZone('town', 'bg_town.png')),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDropZone(
                        'waterfall',
                        'bg_rainbow_closeup2.png',
                      ),
                    ),
                    Expanded(
                      child: _buildDropZone('forest', 'bg_forest_closeup.png'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_showIntro)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Transform.translate(
                  offset: Offset(
                    introCatAdjustment.offsetX,
                    introCatAdjustment.offsetY,
                  ),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: introHeightFactor,
                      child: Image.asset(
                        'assets/images/characters/kiki_the_cat.png',
                        height: introCatAdjustment.size,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (_isGameWon)
            GoodJobOverlay(
              characterImage:
                  'assets/images/characters/cat_holding_fishbone.png',
              characterSizeFactor: 0.9,
              onNext: () {
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeedGame(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  _isGameWon = false;
                  _hasSavedResult = false;
                  _tapTracker.startSession();
                  currentPlacements = {
                    'arctic': 'dog',
                    'town': 'frog',
                    'waterfall': 'bear',
                    'forest': 'penguin',
                  };
                });
              },
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildDropZone(String zoneId, String backgroundFileName) {
    String currentCharacterId = currentPlacements[zoneId]!;
    String currentCharacterFileName = _getCharacterImage(
      currentCharacterId,
      zoneId,
    );

    CharacterAdjustment adjustment =
        adjustments[currentCharacterId] ?? const CharacterAdjustment();

    Widget characterImageWidget = Transform.translate(
      offset: Offset(adjustment.offsetX, adjustment.offsetY),
      child: Image.asset(
        'assets/images/characters/$currentCharacterFileName',
        height: adjustment.size,
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != zoneId,
      onAcceptWithDetails: (details) {
        String sourceZoneId = details.data;
        setState(() {
          String movingCharacter = currentPlacements[sourceZoneId]!;
          String displacedCharacter = currentPlacements[zoneId]!;

          currentPlacements[zoneId] = movingCharacter;
          currentPlacements[sourceZoneId] = displacedCharacter;

          bool isCorrect = correctHabitats[movingCharacter] == zoneId;

          if (isCorrect) {
            _tapTracker.recordCorrectTap();
          } else {
            _tapTracker.recordMistake();
          }

          _playSound(isCorrect);
          _checkForWin();
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/images/backgrounds/$backgroundFileName',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Draggable<String>(
              data: zoneId,
              feedback: Material(
                color: Colors.transparent,
                child: characterImageWidget,
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: characterImageWidget,
              ),
              child: characterImageWidget,
            ),
          ),
        );
      },
    );
  }
}
