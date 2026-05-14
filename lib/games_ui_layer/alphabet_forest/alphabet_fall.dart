import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

class AlphabetFallScreen extends StatefulWidget {
  const AlphabetFallScreen({super.key});

  @override
  State<AlphabetFallScreen> createState() => _AlphabetFallScreenState();
}

class _AlphabetFallScreenState extends State<AlphabetFallScreen>
    with SingleTickerProviderStateMixin {
  late String _targetLetter;
  final List<FallingBall> _activeBalls = [];
  final Random _random = Random();
  late Timer _spawnTimer;
  late Timer _gameTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _setNewTarget();
    _startGameLoops();
  }

  void _setNewTarget() {
    setState(() {
      _targetLetter = String.fromCharCode(_random.nextInt(26) + 65);
    });
  }

  void _startGameLoops() {
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _spawnBall();
    });
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateBallPositions();
    });
  }

  void _spawnBall() {
    if (!mounted) return;
    bool isCorrect = _random.nextDouble() < 0.3;
    String ballLetter = isCorrect
        ? _targetLetter
        : String.fromCharCode(_random.nextInt(26) + 65);

    setState(() {
      _activeBalls.add(
        FallingBall(
          letter: ballLetter,
          xPos: _random.nextDouble(),
          yPos: -0.1,
          speed: 0.003 + (_random.nextDouble() * 0.004),
        ),
      );
    });
  }

  void _updateBallPositions() {
    if (!mounted) return;
    setState(() {
      for (var ball in _activeBalls) {
        ball.yPos += ball.speed;
      }
      _activeBalls.removeWhere((ball) => ball.yPos > 1.1);
    });
  }

  int _correctCount = 0;
  final List<Map<String, double>> _wrongEffects = [];

  void _onBallTap(FallingBall ball) {
    if (ball.letter == _targetLetter) {
      setState(() {
        _correctCount++;
        _activeBalls.remove(ball);

        if (_correctCount >= 5) {
          _showApplause();
          _correctCount = 0;
        } else {
          _setNewTarget();
        }
      });
    } else {
      final double tapX = ball.xPos;
      final double tapY = ball.yPos;

      setState(() {
        _activeBalls.remove(ball);
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
    final Size screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: ForestColorTheme.lightgrayishgreen,
        insetPadding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("👏", style: TextStyle(fontSize: screenSize.width * 0.1)),
              const SizedBox(height: 16),
              Text(
                "Great Job!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ForestAppTextStyles.fredoka,
                  fontSize: screenSize.width * 0.05,
                  fontWeight: FontWeight.bold,
                  color: ForestColorTheme.darkseagreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You found 5 letters!",
                style: TextStyle(
                  fontFamily: ForestAppTextStyles.fredoka,
                  fontSize: screenSize.width * 0.03,
                  color: ForestColorTheme.seagreen,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: screenSize.width * 0.3,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _setNewTarget();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ForestColorTheme.darkseagreen,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    "Keep Playing!",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _spawnTimer.cancel();
    _gameTimer.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    const Text(
                      "Find the Letter:",
                      style: TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontSize: 24,
                        color: ForestColorTheme.darkseagreen,
                      ),
                    ),
                    Text(
                      _targetLetter,
                      style: const TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: ForestColorTheme.seagreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. FALLING BALLS AND EFFECTS
            LayoutBuilder(
              builder: (context, constraints) {
                double ballSize = constraints.maxWidth * 0.12;

                return Stack(
                  children: [
                    ..._activeBalls.map((ball) {
                      return Positioned(
                        left: ball.xPos * (constraints.maxWidth - ballSize),
                        top: ball.yPos * constraints.maxHeight,
                        child: GestureDetector(
                          onTap: () => _onBallTap(ball),
                          child: SizedBox(
                            width: ballSize,
                            height: ballSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/objects/ball.png',
                                  fit: BoxFit.contain,
                                ),
                                Text(
                                  ball.letter,
                                  style: TextStyle(
                                    fontFamily: ForestAppTextStyles.fredoka,
                                    fontSize: ballSize * 0.4,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 4,
                                        color: Colors.black45,
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
                        left: effect['x']! * (constraints.maxWidth - ballSize),
                        top: effect['y']! * constraints.maxHeight,
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

            const Positioned(top: 10, left: 10, child: ForestBackButton()),
          ],
        ),
      ),
    );
  }
}

class FallingBall {
  final String letter;
  final double xPos;
  double yPos;
  final double speed;

  FallingBall({
    required this.letter,
    required this.xPos,
    required this.yPos,
    required this.speed,
  });
}
