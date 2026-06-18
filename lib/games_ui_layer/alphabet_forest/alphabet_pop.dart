import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_fall.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_match.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AlphabetPopScreen extends StatefulWidget {
  final String targetLetter;

  const AlphabetPopScreen({super.key, required this.targetLetter});

  @override
  State<AlphabetPopScreen> createState() => _AlphabetPopScreenState();
}

class _AlphabetPopScreenState extends State<AlphabetPopScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _random = Random();

  late Timer _gameTimer;
  List<BouncingBall> _activeBalls = [];

  int _correctCount = 0;
  final int _winCondition = 3;
  List<Map<String, double>> _wrongEffects = [];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _generateBalls();
    _startGameLoop();
  }

  void _generateBalls() {
    _activeBalls.clear();

    List<String> distractors = _getDistractorLetters(widget.targetLetter);
    for (int i = 0; i < 7; i++) {
      String randomDistractor =
          distractors[_random.nextInt(distractors.length)];
      _activeBalls.add(_createBall(randomDistractor));
    }

    for (int i = 0; i < _winCondition; i++) {
      _activeBalls.add(_createBall(widget.targetLetter.toUpperCase()));
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
    return BouncingBall(
      id: UniqueKey().toString(),
      key: GlobalKey(),
      letter: letter,
      xPos: 0.05 + (_random.nextDouble() * 0.90),
      yPos:
          _random.nextDouble() *
          0.5, // Start them all in the top half of the screen
      dx: 0.0,
      dy: 0.0,
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

    RenderBox? box = ball.key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    Offset position = box.localToGlobal(Offset.zero);

    if (ball.letter == widget.targetLetter.toUpperCase()) {
      // --- CORRECT MATCH ---
      String audioFile =
          'audio/alphabet_forest/sound_effects/sound_${widget.targetLetter.toLowerCase()}.wav';
      await _audioPlayer.play(AssetSource(audioFile));

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
      // --- WRONG MATCH ---
      setState(() {
        _wrongEffects.add({'x': position.dx, 'y': position.dy});
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _wrongEffects.removeWhere(
              (effect) =>
                  effect['x'] == position.dx && effect['y'] == position.dy,
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
          characterImage: 'assets/images/characters/dog.png',
          closeButtonColor: ForestColorTheme.seagreen,

          onNext: () {
            Navigator.pop(context); // Close the prompt

            String current = widget.targetLetter.toUpperCase();

            final completedLevel = ForestProgressService.levelNumberForLetter(
              current,
            );
            if (completedLevel != null) {
              ForestProgressService.instance.markLevelComplete(completedLevel);
            }

            if (current == 'G') {
              // If they just finished G, send them to Level 8 (Match Game!)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlphabetMatchScreen(),
                ),
              );
            } else if (current == 'N') {
              // If they just finished N, send them to Level 16 (Fall Game!)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlphabetFallScreen(),
                ),
              );
            } else {
              // Otherwise, just go to the next normal Intro screen!
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
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: screenSize.height * 0.02),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Pop the correct balls!",
                        style: TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: screenSize.height * 0.06,
                          color: Color.fromARGB(255, 71, 70, 70),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.targetLetter.toUpperCase(),
                        style: TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: screenSize.height * 0.12,
                          fontWeight: FontWeight.w900,
                          color: ForestColorTheme.seagreen,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
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
                      children: _activeBalls.map((ball) {
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
                                        : 'assets/images/objects/forest/ball_normal.png',
                                    fit: BoxFit.contain,
                                  ),

                                  if (!ball.isPopped)
                                    Text(
                                      ball.letter,
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
                      }).toList(),
                    );
                  },
                ),
              ),

              ..._wrongEffects.map((effect) {
                return Positioned(
                  left: effect['x']! - 20,
                  top: effect['y']! - 20,
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
                );
              }),

              const Positioned(top: 10, left: 10, child: ForestBackButton()),
            ],
          ),
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
