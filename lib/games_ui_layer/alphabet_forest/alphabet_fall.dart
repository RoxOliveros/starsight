import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import '../../business_layer/orientation_service.dart';

class AlphabetFallScreen extends StatefulWidget {
  final String startingLetter;

  // Defaults to 'A' if no letter is passed
  const AlphabetFallScreen({super.key, this.startingLetter = 'A'});

  @override
  State<AlphabetFallScreen> createState() => _AlphabetFallScreenState();
}

class _AlphabetFallScreenState extends State<AlphabetFallScreen>
    with SingleTickerProviderStateMixin {
  late String _currentImagePath;
  late List<String> _targetLetters; // Holds both ['A', 'a']

  final List<FallingObject> _activeObjects = [];
  final Random _random = Random();
  late Timer _spawnTimer;
  late Timer _gameTimer;

  int _correctCount = 0;
  final int _winCondition = 5; // How many they need to catch to win
  final List<Map<String, double>> _wrongEffects = [];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Load the specific settings for A, B, or C
    _loadLevel(widget.startingLetter);

    _startGameLoops();
  }

  // --- THE DYNAMIC LEVEL LOADER ---
  void _loadLevel(String letter) {
    switch (letter.toUpperCase()) {
      case 'A':
        _currentImagePath = 'assets/images/objects/apple.png';
        _targetLetters = ['A', 'a'];
        break;
      case 'B':
        _currentImagePath = 'assets/images/objects/ball.png';
        _targetLetters = ['B', 'b'];
        break;
      case 'C':
        _currentImagePath = 'assets/images/objects/car.png';
        _targetLetters = ['C', 'c'];
        break;
      // Add 'D', 'E', etc. here later
      default:
        _currentImagePath = 'assets/images/objects/apple.png';
        _targetLetters = ['A', 'a'];
    }
  }

  // --- HELPER FOR NEXT LETTER ---
  String _getNextLetter(String currentLetter) {
    int charCode = currentLetter.toUpperCase().codeUnitAt(0);
    if (charCode >= 65 && charCode < 90) {
      return String.fromCharCode(charCode + 1);
    }
    return 'DONE';
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

    // 40% chance to spawn a correct letter, 60% chance for a random wrong letter
    bool isTarget = _random.nextDouble() < 0.4;
    String letterToDrop;

    if (isTarget) {
      // Pick either the uppercase or lowercase target randomly
      letterToDrop = _targetLetters[_random.nextInt(_targetLetters.length)];
    } else {
      // Generate a random letter that is NOT the target
      do {
        bool isUpper = _random.nextBool();
        letterToDrop = isUpper
            ? String.fromCharCode(_random.nextInt(26) + 65)
            : String.fromCharCode(_random.nextInt(26) + 97);
      } while (_targetLetters.contains(letterToDrop));
    }

    setState(() {
      _activeObjects.add(
        FallingObject(
          letter: letterToDrop,
          xPos: _random.nextDouble(),
          yPos: -0.1,
          speed: 0.003 + (_random.nextDouble() * 0.004),
        ),
      );
    });
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

  void _onObjectTap(FallingObject obj) {
    // Check if the tapped letter is in our target list (e.g., 'A' or 'a')
    if (_targetLetters.contains(obj.letter)) {
      setState(() {
        _correctCount++;
        _activeObjects.remove(obj);

        // TODO: Play "A" sound here in the future!

        if (_correctCount >= _winCondition) {
          _spawnTimer.cancel();
          _gameTimer.cancel();
          _showApplause();
        }
      });
    } else {
      // Wrong letter tapped
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

  void _showApplause() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: 'assets/images/dog.png',
          closeButtonColor: ForestColorTheme.seagreen,

          // 4. FALL is the last game. Return to the Map!
          onNext: () {
            Navigator.pop(context); // 1st: Close the Good Job prompt
            Navigator.pop(context); // 2nd: Exit the game and return to Map
          },

          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _correctCount = 0;
              _activeObjects.clear();
              _startGameLoops(); // Restart the timers
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
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForestColorTheme.lightgrayishgreen,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. TARGET DISPLAY
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    const Text(
                      "Catch the letters:",
                      style: TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontSize: 24,
                        color: ForestColorTheme.darkseagreen,
                      ),
                    ),
                    Text(
                      "${_targetLetters[0]} & ${_targetLetters[1]}", // Displays "A & a"
                      style: const TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        color: ForestColorTheme.seagreen,
                      ),
                    ),
                    // Score Tracker
                    Text(
                      "$_correctCount / $_winCondition",
                      style: const TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontSize: 24,
                        color: ForestColorTheme.darkseagreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. FALLING OBJECTS AND EFFECTS
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
                                // Uses the dynamic image path!
                                Image.asset(
                                  _currentImagePath,
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
    );
  }
}

class FallingObject {
  final String letter;
  final double xPos;
  double yPos;
  final double speed;

  FallingObject({
    required this.letter,
    required this.xPos,
    required this.yPos,
    required this.speed,
  });
}
