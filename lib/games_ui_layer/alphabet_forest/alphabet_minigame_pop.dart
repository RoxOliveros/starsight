import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_woodpecker_letter_listen.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'alphabet_game_ui.dart';
import 'forest_game_acorn_basket.dart';

class AlphabetPopScreen extends StatefulWidget {
  final String letter;

  const AlphabetPopScreen({super.key, required this.letter});

  @override
  State<AlphabetPopScreen> createState() => _AlphabetPopScreenState();
}

class _AlphabetPopScreenState extends State<AlphabetPopScreen>
  with TofiReactionMixin {

  @override
  AudioPlayer get tofiPlayer => _audioPlayer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _random = Random();

  late Timer _gameTimer;
  final List<BouncingBall> _activeBalls = [];

  int _correctCount = 0;
  final int _winCondition = 3;
  final List<Map<String, double>> _wrongEffects = [];

  final List<double> _lanes = [
    0.22,
    0.32,
    0.42,
    0.52,
    0.62,
    0.72,
    0.82,
    0.92,
  ];

  late List<double> _availableLanes;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _generateBalls();
    _startGameLoop();
  }

  void _generateBalls() {
    _activeBalls.clear();

    _availableLanes = List.from(_lanes);
    _availableLanes.shuffle();

    List<String> distractors = _getDistractorLetters(widget.letter);
    for (int i = 0; i < 5; i++) {
      String randomDistractor =
          distractors[_random.nextInt(distractors.length)];
      _activeBalls.add(_createBall(randomDistractor));
    }

    for (int i = 0; i < _winCondition; i++) {
      _activeBalls.add(_createBall(widget.letter.toUpperCase()));
    }
  }

  List<String> _getDistractorLetters(String target) {
    List<String> pool = [];
    for (int i = 65; i <= 90; i++) {
      String l = String.fromCharCode(i);
      if (l != target.toUpperCase()) pool.add(l);
    }
    return pool;
  }

  BouncingBall _createBall(String letter) {
    // use one lane per ball
    double x;

    if (_availableLanes.isNotEmpty) {
      x = _availableLanes.removeLast();
    } else {
      // fallback if you ever have more balls than lanes
      x = 0.30 + _random.nextDouble() * 0.64;
    }

    double y = 0.05 + _random.nextDouble() * 0.45;

    return BouncingBall(
      id: UniqueKey().toString(),
      key: GlobalKey(),
      letter: letter,
      xPos: x,
      yPos: y,
      dx: 0,
      dy: 0,
      isPopped: false,
    );
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;

      setState(() {
        for (var ball in _activeBalls) {
          if (ball.isPopped) continue;

          ball.dy += 0.00015;

          // MOVE THE BALL
          ball.yPos += ball.dy;
          ball.xPos += ball.dx;

          //  THE HIGH BOUNCE
          if (ball.yPos >= 1.0) {
            ball.yPos = 1.0;
            ball.dy = -(0.014 + _random.nextDouble() * 0.005);
          }

          // 4. THE CEILING CHECK
          if (ball.yPos <= 0.0) {
            ball.yPos = 0.0;
            ball.dy = ball.dy.abs();
          }
        }
      });
    });
  }

  void _onBallTap(BouncingBall ball) async {
    if (ball.isPopped) return;

    if (ball.letter == widget.letter.toUpperCase()) {
      // --- CORRECT MATCH ---
      String audioFile =
          'audio/alphabet_forest/sound_effects/sound_${widget.letter.toLowerCase()}.wav';
      await _audioPlayer.play(AssetSource(audioFile));

      showTofiReaction(TofiState.correct);

      setState(() {
        ball.isPopped = true;
        _correctCount++;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _activeBalls.removeWhere((item) => item.id == ball.id);
            if (_correctCount >= _winCondition) {
              _gameTimer.cancel();
              _showApplause();
            }
          });
        }
      });
    } else {
      showTofiReaction(TofiState.wrong);

      // --- WRONG MATCH ---
      final double tapX = ball.xPos;
      final double tapY = ball.yPos;

      setState(() {
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
    final String currentLetter = widget.letter.toUpperCase();

    const skipGoodJobLetters = {
      'A', 'B',
      'D', 'E',
      'G', 'H',
      'J', 'K',
      'M', 'N',
      'P', 'Q',
      'S', 'T',
      'V', 'W',
      'Y', 'Z',
    };

    if (skipGoodJobLetters.contains(currentLetter)) {
      String nextLetter =
      String.fromCharCode(currentLetter.codeUnitAt(0) + 1);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AlphabetIntroScreen(letter: nextLetter),
        ),
      );
      return;
    }

    // mark level complete for some letters
    const completeLevelsLetters = {
      'C',
      'F',
      'I',
      'L',
      'O',
      'R',
      'U',
      'X',
      'Z',
    };

    if (completeLevelsLetters.contains(currentLetter)) {
      final completedLevel =
      ForestProgressService.levelNumberForLetter(currentLetter);

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
            Navigator.pop(context);

            if (currentLetter == 'C'){
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const WoodpeckerLetterListenGame(level: 2),
                ),
              );
            } else if (currentLetter == 'F'){
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcornBasketGame(level: 4),
                ),
              );
            } else if (currentLetter == 'I') {
              // TODO: @Tin add navigation for a-i games
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => const (),
              //   ),
              // );
            } else {
              int charCode = currentLetter.codeUnitAt(0);
              if (charCode >= 65 && charCode < 90) {
                String nextLetter = String.fromCharCode(charCode + 1);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetIntroScreen(letter: nextLetter),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForestLevelScreen(),
                  ),
                );
              }
            }
          },

          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _correctCount = 0;
              _generateBalls();
              _startGameLoop();
            });
          },

          onBack: () {
            Navigator.pop(context);
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
    _gameTimer.cancel();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double ballSize = (screenSize.height * 0.22).clamp(80.0, 150.0);
    final double letterFontSize = ballSize * 0.55;

    return Scaffold(
      body: ForestBackground(
        child: Stack(
          children: [
            buildTofi(context),

            Positioned(top: 25, left: 20, child: ForestBackButton()),

            Positioned(
              top: 25,
              left: 0,
              right: 0,
              child: Center(
                child: ForestInstructionBanner(
                  text:
                      'Pop all the ${widget.letter.toUpperCase()} balls!',
                ),
              ),
            ),

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

            Positioned(
              top: screenSize.height * 0.30,
              bottom: 20,
              left: 20,
              right: 20,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // 1. Draw the balls
                      ..._activeBalls.map((ball) {
                        return Positioned(
                          left: ball.xPos * (constraints.maxWidth - ballSize),
                          top: ball.yPos * (constraints.maxHeight - ballSize),
                          child: GestureDetector(
                            key: ball.key,
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onBallTap(ball),
                            child: SizedBox(
                              width: ballSize,
                              height: ballSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    ball.isPopped
                                        ? 'assets/images/objects/forest/ball_popped.png'
                                        : 'assets/images/objects/forest/ball.png',
                                    fit: BoxFit.contain,
                                  ),
                                  if (!ball.isPopped)
                                    Text(
                                      ball.letter,
                                      textScaler: const TextScaler.linear(1.0),
                                      style: TextStyle(
                                        fontFamily: ForestAppTextStyles.fredoka,
                                        fontSize: letterFontSize,
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

                      // 2. Draw the Red X's using the EXACT same math as the balls
                      ..._wrongEffects.map((effect) {
                        return Positioned(
                          left:
                              effect['x']! * (constraints.maxWidth - ballSize),
                          top:
                              effect['y']! * (constraints.maxHeight - ballSize),
                          child: SizedBox(
                            width: ballSize,
                            height: ballSize,
                            child: Center(
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.redAccent,
                                size: ballSize * 0.8,
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
            ),
          ],
        ),
      ),
    );
  }
}

class BouncingBall {
  final String id;
  final GlobalKey key;
  final String letter;
  double xPos;
  double yPos;
  double dx;
  double dy;
  bool isPopped;

  BouncingBall({
    required this.id,
    required this.key,
    required this.letter,
    required this.xPos,
    required this.yPos,
    required this.dx,
    required this.dy,
    required this.isPopped,
  });
}
