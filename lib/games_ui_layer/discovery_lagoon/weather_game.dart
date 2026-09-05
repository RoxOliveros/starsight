import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/clothes_game.dart';

import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import 'lagoon_game_ui.dart'; // Make sure this path is correct for ClothesGame!

enum KikiState { normal, correct, wrong }

class WeatherGame extends StatefulWidget {
  final int level;

  const WeatherGame({super.key, required this.level});

  @override
  _WeatherGameState createState() => _WeatherGameState();
}

class _WeatherGameState extends State<WeatherGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  KikiState _kikiState = KikiState.normal;
  int currentLevelIndex = 0;
  bool _isGameComplete = false; // Tracks if the final level is finished

  // Tracks if the intro voice prompt is currently playing
  bool _isPromptPlaying = false;

  final List<Map<String, String>> levelSequence = [
    {'bg': 'assets/images/backgrounds/bg_park_sunny.png', 'target': 'sunny'},
    {'bg': 'assets/images/backgrounds/bg_lake_rainy.png', 'target': 'rainy'},
    {'bg': 'assets/images/backgrounds/bg_beach_sunny.png', 'target': 'sunny'},
    {'bg': 'assets/images/backgrounds/bg_school_cloudy.png', 'target': 'cloudy',},
    {'bg': 'assets/images/backgrounds/bg_fields_windy.png', 'target': 'windy'},
    {'bg': 'assets/images/backgrounds/bg_town_rainy.png', 'target': 'rainy'},
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Listen for when the audio finishes playing to re-enable buttons
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted && _isPromptPlaying) {
        setState(() {
          _isPromptPlaying = false;
        });
      }
    });

    // Play the intro prompt when the screen loads
    _playIntroPrompt();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _playIntroPrompt() async {
    setState(() {
      _isPromptPlaying = true; // Disable buttons
    });

    // Adjust this path if your audio file is stored in a different folder
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
    // Prevent multiple clicks while Kiki is reacting, game is over, OR intro is playing
    if (_kikiState != KikiState.normal || _isGameComplete || _isPromptPlaying) {
      return;
    }

    String currentTarget = levelSequence[currentLevelIndex]['target']!;

    if (selectedWeather == currentTarget) {
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
            // Uncomment the line below if you want the intro to play on every new level
            // _playIntroPrompt();
          } else {
            // Trigger the overlay on the last level
            _isGameComplete = true;
          }
        });
      }
    } else {
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

    // Default Kiki size and position
    double kikiWidth = screenSize.width * 0.35;
    double kikiBottom = -screenSize.height * 0.15;

    // Adjust size/position based on current reaction state
    if (_kikiState == KikiState.correct) {
      kikiWidth = screenSize.width * 0.35;
      kikiBottom = -screenSize.height * 0.15;
    } else if (_kikiState == KikiState.wrong) {
      kikiBottom = -screenSize.height * 0.15;
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic Background Image
          Positioned.fill(
            child: Image.asset(
              levelSequence[currentLevelIndex]['bg']!,
              fit: BoxFit.cover,
            ),
          ),

          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

          // 2. Weather Selection Buttons
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
                  'assets/images/objects/lagoon/sun.png',
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

          // 3. Kiki the Cat (Dynamic Size & Position)
          Positioned(
            bottom: kikiBottom,
            right: screenSize.width * 0.02,
            child: Image.asset(_getKikiImageAsset(), width: kikiWidth),
          ),

          // 4. Good Job Overlay (Shows when game is complete)
          if (_isGameComplete)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/cat_holding_fishbone.png',
                
                characterSizeFactor: 0.9,
                onNext: () async {
                  // Mark Level 8 as complete and unlock Level 9
                  await LagoonProgressService.instance.markLevelComplete(8);

                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClothesGame(level: widget.level + 1),
                      ),
                    );
                  }
                },
                onRestart: () {
                  // Resets the game state back to the first background
                  setState(() {
                    currentLevelIndex = 0;
                    _isGameComplete = false;
                    _kikiState = KikiState.normal;
                    _playIntroPrompt(); // Re-play intro when restarting
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
        // Dims the button visually while the intro prompt is playing
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
