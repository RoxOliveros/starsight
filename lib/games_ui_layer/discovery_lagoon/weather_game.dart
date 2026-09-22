import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/clothes_game.dart';

import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import 'lagoon_game_ui.dart';

enum KikiState { normal, correct, wrong }

class WeatherGame extends StatefulWidget {
  final int level;

  const WeatherGame({super.key, required this.level});

  @override
  _WeatherGameState createState() => _WeatherGameState();
}

class _WeatherGameState extends State<WeatherGame> with AiCameraMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GameTapTracker _tapTracker = GameTapTracker();

  KikiState _kikiState = KikiState.normal;
  int currentLevelIndex = 0;
  bool _isGameComplete = false;
  bool _isPromptPlaying = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  final List<Map<String, String>> levelSequence = [
    {'bg': 'assets/images/backgrounds/bg_park_sunny.png', 'target': 'sunny'},
    {'bg': 'assets/images/backgrounds/bg_lake_rainy.png', 'target': 'rainy'},
    {'bg': 'assets/images/backgrounds/bg_beach_sunny.png', 'target': 'sunny'},
    {
      'bg': 'assets/images/backgrounds/bg_school_cloudy.png',
      'target': 'cloudy',
    },
    {'bg': 'assets/images/backgrounds/bg_fields_windy.png', 'target': 'windy'},
    {'bg': 'assets/images/backgrounds/bg_town_rainy.png', 'target': 'rainy'},
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

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted && _isPromptPlaying) {
        setState(() {
          _isPromptPlaying = false;
        });
      }
    });

    _playIntroPrompt();
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _playIntroPrompt() async {
    setState(() {
      _isPromptPlaying = true;
    });

    await _playAudio('assets/audio/discovery_lagoon/weather_game_intro.wav');
  }

  Future<void> _playAudio(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource(assetPath.replaceFirst('assets/', '')),
      );
    } catch (e) {
      debugPrint('Audio error ($assetPath): $e');
    }
  }

  Future<void> handleAnswer(String selectedWeather) async {
    if (_kikiState != KikiState.normal || _isGameComplete || _isPromptPlaying) {
      return;
    }

    String currentTarget = levelSequence[currentLevelIndex]['target']!;

    if (selectedWeather == currentTarget) {
      _tapTracker.recordCorrectTap();
      setState(() {
        _kikiState = KikiState.correct;
      });
      _playAudio('assets/audio/sound_effects/shine.wav');

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _kikiState = KikiState.normal;
          if (currentLevelIndex < levelSequence.length - 1) {
            currentLevelIndex++;
          } else {
            _saveDataAndShowGoodJob();
          }
        });
      }
    } else {
      _tapTracker.recordMistake();
      setState(() {
        _kikiState = KikiState.wrong;
      });
      _playAudio('assets/audio/discovery_lagoon/kiki_tryagain.wav');

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _kikiState = KikiState.normal;
        });
      }
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    try {
      await LagoonDatabaseService.saveGameData(
        gameId: 'lagoon_weather_game',
        activityName: 'Weather Game',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      );
    } catch (e) {
      debugPrint("Database Error saving metrics: $e");
    }
    await LagoonProgressService.instance.markLevelComplete(8);

    if (mounted) {
      setState(() {
        _isGameComplete = true;
      });
    }
  }

  String _getKikiImageAsset() {
    switch (_kikiState) {
      case KikiState.correct:
        return 'assets/images/characters/kiki_smiling.png';
      case KikiState.wrong:
        return 'assets/images/characters/kiki_smiling.png';
      case KikiState.normal:
        return 'assets/images/characters/kiki_the_cat.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double buttonSize = screenSize.width * 0.12;

    double kikiWidth = screenSize.width * 0.35;
    double kikiBottom = -screenSize.height * 0.15;

    if (_kikiState == KikiState.correct) {
      kikiWidth = screenSize.width * 0.35;
      kikiBottom = -screenSize.height * 0.15;
    } else if (_kikiState == KikiState.wrong) {
      kikiBottom = -screenSize.height * 0.15;
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              levelSequence[currentLevelIndex]['bg']!,
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          Positioned(
            bottom: screenSize.height * 0.08,
            left: screenSize.width * 0.05,
            child: Row(
              children: [
                _buildWeatherButton(
                  'rainy',
                  'assets/images/objects/lagoon/raincloud.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'sunny',
                  'assets/images/objects/lagoon/suncloud.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'windy',
                  'assets/images/objects/lagoon/windy.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'cloudy',
                  'assets/images/objects/lagoon/cloudy.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
              ],
            ),
          ),

          Positioned(
            bottom: kikiBottom,
            right: screenSize.width * 0.02,
            child: Image.asset(_getKikiImageAsset(), width: kikiWidth),
          ),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (_isGameComplete)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage:
                    'assets/images/characters/cat_holding_fishbone.png',
                characterSizeFactor: 0.9,
                onNext: () {
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClothesGame(level: widget.level + 1),
                      ),
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    currentLevelIndex = 0;
                    _isGameComplete = false;
                    _kikiState = KikiState.normal;
                    _hasSavedResult = false;
                    _tapTracker.startSession();
                    _playIntroPrompt();
                  });
                },
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherButton(
    String weatherType,
    String imagePath,
    Color borderColor,
    double size, {
    bool isHighlighted = false,
  }) {
    return GestureDetector(
      onTap: () => handleAnswer(weatherType),
      child: Opacity(
        opacity: _isPromptPlaying ? 0.5 : 1.0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.15),
            border: Border.all(
              color: isHighlighted ? Colors.orange : borderColor,
              width: size * 0.04,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.15),
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
