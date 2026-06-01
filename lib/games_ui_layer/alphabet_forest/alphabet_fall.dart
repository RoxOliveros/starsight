import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_match.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../../business_layer/orientation_service.dart';

class AlphabetFallScreen extends StatefulWidget {
  final String startingLetter;
  final bool isBigGame;

  const AlphabetFallScreen({
    super.key,
    this.startingLetter = 'A',
    this.isBigGame = false,
  });

  @override
  State<AlphabetFallScreen> createState() => _AlphabetFallScreenState();
}

class _AlphabetFallScreenState extends State<AlphabetFallScreen>
    with SingleTickerProviderStateMixin {
  late List<String> _targetLetters;
  int _winCondition = 4;

  final List<FallingObject> _activeObjects = [];
  final Random _random = Random();
  late Timer _spawnTimer;
  late Timer _gameTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();

  int _correctCount = 0;
  final List<Map<String, double>> _wrongEffects = [];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _loadLevel();
    _startGameLoops();
  }

  void _loadLevel() {
    if (widget.isBigGame) {
      // Catch any letter from H through N!
      _targetLetters = [
        'H',
        'h',
        'I',
        'i',
        'J',
        'j',
        'K',
        'k',
        'L',
        'l',
        'M',
        'm',
        'N',
        'n',
      ];
      _winCondition = 14;
    }
  }

  // --- THE IMAGE DICTIONARY ---
  // Tells the game which image to attach to which falling letter!
  String _getImageForLetter(String letter) {
    const Map<String, String> objectMap = {
      'A': 'apple',
      'B': 'ball',
      'C': 'car',
      'D': 'duck',
      'E': 'egg',
      'F': 'feet',
      'G': 'glass',
      'H': 'hat',
      'I': 'igloo',
      'J': 'jar',
      'K': 'key',
      'L': 'lamp',
      'M': 'milk',
      'N': 'nose',
    };
    final name = objectMap[letter.toUpperCase()] ?? 'apple';
    return 'assets/images/objects/forest/$name.png';
  }

  void _startGameLoops() {
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _spawnObject();
    });
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateObjectPositions();
    });
  }

  void _spawnObject() {
    if (!mounted) return;

    bool isTarget = _random.nextDouble() < 0.7;
    String letterToDrop;

    if (isTarget) {
      letterToDrop = _targetLetters[_random.nextInt(_targetLetters.length)];
    } else {
      do {
        bool isUpper = _random.nextBool();
        letterToDrop = isUpper
            ? String.fromCharCode(_random.nextInt(26) + 65)
            : String.fromCharCode(_random.nextInt(26) + 97);
      } while (_targetLetters.contains(letterToDrop));
    }

    // Assign the unique image to the object being dropped!
    String objectImage = _getImageForLetter(letterToDrop);

    setState(() {
      _activeObjects.add(
        FallingObject(
          letter: letterToDrop,
          imagePath: objectImage,
          xPos: _random.nextDouble(),
          yPos: -0.1,
          speed: 0.003 + (_random.nextDouble() * 0.004),
        ),
      );
    });
  }

  void _onObjectTap(FallingObject obj) async {
    if (_targetLetters.contains(obj.letter)) {
      // Try to play the specific letter sound, fallback if playing big game
      try {
        String audioFile =
            'audio/alphabet_forest/sound_effects/sound_${obj.letter.toLowerCase()}.wav';
        await _audioPlayer.play(AssetSource(audioFile));
      } catch (e) {
        // Ignore if sound file is missing
      }

      setState(() {
        _correctCount++;
        _activeObjects.remove(obj);

        if (_correctCount >= _winCondition) {
          _spawnTimer.cancel();
          _gameTimer.cancel();
          _showApplause();
        }
      });
    } else {
      final double tapX = obj.xPos;
      final double tapY = obj.yPos;

      setState(() {
        _activeObjects.remove(obj);
        _wrongEffects.add({'x': tapX, 'y': tapY});
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _wrongEffects.removeWhere(
              (effect) => effect['x'] == tapX && effect['y'] == tapY,
            );
          });
        }
      });
    }
  }

  void _updateObjectPositions() {
    if (!mounted) return;
    setState(() {
      for (var obj in _activeObjects) {
        obj.yPos += obj.speed;
      }
      _activeObjects.removeWhere((obj) => obj.yPos > 1.1);
    });
  }

  void _showApplause() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: 'assets/images/characters/dog.png',
          closeButtonColor: ForestColorTheme.seagreen,

          onNext: () {
            Navigator.pop(context); // Close the Good Job prompt

            if (widget.isBigGame) {
              Navigator.pop(context); // Go back to Level Map to celebrate!
              return;
            }

            // 2. NORMAL ROUTING
            String current = widget.startingLetter.toUpperCase();

            if (current == 'G') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlphabetMatchScreen(),
                ),
              );
            } else if (current == 'N') {
              // Launch the Big Game Fall!
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AlphabetFallScreen(isBigGame: true),
                ),
              );
            } else {
              int charCode = current.codeUnitAt(0);
              if (charCode >= 65 && charCode < 90) {
                String nextLetter = String.fromCharCode(charCode + 1);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetIntroScreen(startingLetter: nextLetter),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            }
          },
          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _correctCount = 0;
              _activeObjects.clear();
              _startGameLoops();
            });
          },
          onBack: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_spawnTimer.isActive) _spawnTimer.cancel();
    if (_gameTimer.isActive) _gameTimer.cancel();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ForestBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      Text(
                        widget.isBigGame
                            ? "Catch H through N!"
                            : "Catch the letters:",
                        style: const TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: 24,
                          color: Color.fromARGB(255, 71, 70, 70),
                        ),
                      ),

                      if (!widget.isBigGame)
                        Text(
                          "${_targetLetters[0]} & ${_targetLetters[1]}",
                          style: const TextStyle(
                            fontFamily: ForestAppTextStyles.fredoka,
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 71, 70, 70),
                          ),
                        ),

                      Text(
                        "$_correctCount / $_winCondition",
                        style: const TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: 24,
                          color: Color.fromARGB(255, 71, 70, 70),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              LayoutBuilder(
                builder: (context, constraints) {
                  double objSize = constraints.maxWidth * 0.12;

                  return Stack(
                    children: [
                      ..._activeObjects.map((obj) {
                        return Positioned(
                          left: obj.xPos * (constraints.maxWidth - objSize),
                          top: obj.yPos * constraints.maxHeight,
                          child: GestureDetector(
                            onTap: () => _onObjectTap(obj),
                            child: SizedBox(
                              width: objSize,
                              height: objSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    obj.imagePath,
                                    fit: BoxFit.contain,
                                  ),
                                  Text(
                                    obj.letter,
                                    style: TextStyle(
                                      fontFamily: ForestAppTextStyles.fredoka,
                                      fontSize: objSize * 0.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Colors.black87,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      ..._wrongEffects.map((effect) {
                        return Positioned(
                          left: effect['x']! * (constraints.maxWidth - objSize),
                          top: effect['y']! * constraints.maxHeight,
                          child: SizedBox(
                            width: objSize,
                            height: objSize,
                            child: Center(
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.redAccent,
                                size: objSize * 0.8,
                                shadows: const [
                                  Shadow(
                                    color: Colors.white,
                                    blurRadius: 12,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
              const Positioned(top: 10, left: 10, child: ForestBackButton()),
            ],
          ),
        ),
      ),
    );
  }
}

class FallingObject {
  final String letter;
  final String imagePath;
  final double xPos;
  double yPos;
  final double speed;

  FallingObject({
    required this.letter,
    required this.imagePath,
    required this.xPos,
    required this.yPos,
    required this.speed,
  });
}
