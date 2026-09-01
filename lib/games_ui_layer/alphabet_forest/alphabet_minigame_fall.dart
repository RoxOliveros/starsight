import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_woodpecker_letter_listen.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../../business_layer/orientation_service.dart';
import 'alphabet_game_ui.dart';
import 'forest_game_acorn_basket.dart';
import 'forest_game_berry_bush_harvest.dart';
import 'forest_game_butterfly_flower.dart';
import 'forest_game_letter_match.dart';
import 'forest_game_mushroom_hidenseek.dart';
import 'forest_game_paw_print.dart';
import 'forest_game_stick_letter_builder.dart';
import 'forest_game_yak_zebra_race.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlphabetFallScreen extends StatefulWidget {
  final String letter;

  const AlphabetFallScreen({super.key, required this.letter});

  @override
  State<AlphabetFallScreen> createState() => _AlphabetFallScreenState();
}

class _AlphabetFallScreenState extends State<AlphabetFallScreen>
    with SingleTickerProviderStateMixin, TofiReactionMixin, AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => _player;

  final AudioPlayer _player = AudioPlayer();

  final GameTapTracker _tapTracker = GameTapTracker();

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
    startAiCamera();
    _tapTracker.startSession();
    _loadLevel();
    onFirstFaceDetected = () {
      _startGameLoops();
    };
    if (isFaceDetected) {
      onFirstFaceDetected?.call();
      onFirstFaceDetected = null;
    }
  }

  // --- FLEXIBLE TARGET LETTERS ---
  // Catch both upper and lower case of whatever letter this instance is for.
  void _loadLevel() {
    final String upper = widget.letter.toUpperCase();
    final String lower = widget.letter.toLowerCase();

    _targetLetters = [upper, lower];
    _winCondition = 4;
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
      'O': 'oil',
      'P': 'pan',
      'Q': 'queen',
      'R': 'rain',
      'S': 'sun',
      'T': 'tree',
      'U': 'umbrella',
      'V': 'vase',
      'W': 'window',
      'X': 'xylophone',
      'Y': 'yarn',
      'Z': 'zero',
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
        print("Error playing sound for ${obj.letter}: $e");
      }

      showTofiReaction(TofiState.correct);

      setState(() {
        _correctCount++;
        _activeObjects.remove(obj);

        if (_correctCount >= _winCondition) {
          _spawnTimer.cancel();
          _gameTimer.cancel();
          _saveDataAndShowApplause();
        }
      });
    } else {
      _tapTracker.recordMistake();
      final double tapX = obj.xPos;
      final double tapY = obj.yPos;

      setState(() {
        _activeObjects.remove(obj);
        _wrongEffects.add({'x': tapX, 'y': tapY});
      });

      showTofiReaction(TofiState.wrong);

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

  // --- FLEXIBLE NAVIGATION ---
  // Same "what comes next" pattern used by the hunt/paint games:
  // mark level complete if needed, then move to the next letter or
  // back to the forest map once we run out of the alphabet.
  void _goToNext() {
    final String current = widget.letter.toUpperCase();

    final completedLevel = ForestProgressService.levelNumberForLetter(current);
    if (completedLevel != null) {
      ForestProgressService.instance.markLevelComplete(completedLevel);
    }

    int charCode = current.codeUnitAt(0);
    if (charCode >= 65 && charCode < 90) {
      String nextLetter = String.fromCharCode(charCode + 1);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlphabetIntroScreen(letter: nextLetter),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ForestLevelScreen()),
      );
    }
  }

  Future<void> _saveDataAndShowApplause() async {
    // 1. Stop the camera and get the emotions
    List<String> finalEmotions = stopAiCamera();

    // 2. Save raw data silently (No loading screen!)
    try {
      String parentUid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('category_progress')
          .doc('alphabet_forest')
          .collection('games_played')
          .doc(
            'letter_fall_${widget.letter.toLowerCase()}',
          ) // e.g., 'letter_fall_a'
          .set({
            'activityName': "Alphabet Fall (${widget.letter.toUpperCase()})",
            'emotions': finalEmotions,
            'totalTaps': _tapTracker.totalTaps,
            'mistakes': _tapTracker.mistakeCount,
            'timePlayedSeconds': _tapTracker.formattedDuration,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint("Database Error saving Fall metrics: $e");
    }

    // 3. Now show the normal win dialog
    _showApplause();
  }

  void _showApplause() {
    String currentLetter = widget.letter.toUpperCase();

    const skipGoodJobLetters = {
      'A',
      'B',
      'D',
      'E',
      'G',
      'H',
      'J',
      'K',
      'M',
      'N',
      'P',
      'Q',
      'S',
      'T',
      'V',
      'W',
      'Y',
      'Z',
    };

    if (skipGoodJobLetters.contains(currentLetter)) {
      String nextLetter = String.fromCharCode(currentLetter.codeUnitAt(0) + 1);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlphabetIntroScreen(letter: nextLetter),
        ),
      );
      return;
    }

    // mark level complete for some letters
    const completeLevelsLetters = {'C', 'F', 'I', 'L', 'O', 'R', 'U', 'X', 'Z'};

    if (completeLevelsLetters.contains(currentLetter)) {
      final completedLevel = ForestProgressService.levelNumberForLetter(
        currentLetter,
      );

      if (completedLevel != null) {
        ForestProgressService.instance.markLevelComplete(completedLevel);
      }
    }

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

            if (currentLetter == 'C') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const WoodpeckerLetterListenGame(level: 2),
                ),
              );
            } else if (currentLetter == 'F') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcornBasketGame(level: 4),
                ),
              );
            } else if (currentLetter == 'I') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ButterflyFlowerGardenGame(level: 6),
                ),
              );
            } else if (currentLetter == 'L') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ButterflyLetterMatchGame(level: 8),
                ),
              );
            } else if (currentLetter == 'O') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const MushroomHideAndSeekGame(level: 10),
                ),
              );
            } else if (currentLetter == 'R') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BerryBushHarvestGame(level: 12),
                ),
              );
            } else if (currentLetter == 'U') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowThePawPrintsGame(level: 14),
                ),
              );
            } else if (currentLetter == 'X') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const FallenStickLetterBuilderGame(level: 16),
                ),
              );
            } else if (currentLetter == 'Z') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const YakZebraRaceGame(level: 18),
                ),
              );
            } else {
              _goToNext();
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
            Navigator.pop(context); // Close the prompt
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ForestLevelScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    if (_spawnTimer.isActive) _spawnTimer.cancel();
    if (_gameTimer.isActive) _gameTimer.cancel();
    _audioPlayer.dispose();
    _player.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String letterLabel = widget.letter.toUpperCase();

    return Scaffold(
      body: Stack(
        children: [
          ForestBackground(
            child: Stack(
              children: [
                // ── Back button ──
                const Positioned(top: 25, left: 20, child: ForestBackButton()),

                // ── Title ──
                Positioned(
                  top: 25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ForestInstructionBanner(
                      text: 'Catch the letter $letterLabel!',
                    ),
                  ),
                ),

                // Level Badge
                Positioned(
                  top: 25,
                  right: 20,
                  child: ForestLevelBadge(
                    level:
                        ForestProgressService.levelNumberForLetter(
                          widget.letter.toUpperCase(),
                        ) ??
                        1,
                  ),
                ),

                buildTofi(context),

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
                            left:
                                effect['x']! * (constraints.maxWidth - objSize),
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
              ],
            ),
          ),

          // 2. The Lighting Prompt Card
          if (!isFaceDetected)
            LightingPromptCard(
              onClose: () {
                setState(() {
                  isFaceDetected = true;
                });
                // Manually trigger the start if they tap X
                onFirstFaceDetected?.call();
                onFirstFaceDetected = null;
              },
            ),
        ],
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
