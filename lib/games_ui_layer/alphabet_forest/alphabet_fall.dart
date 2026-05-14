import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8);
  static const Color deepNavyBlue = Color(0xFF5E463E);
  static const Color orange = Color(0xFFEC8A20);
  static const Color green = Color(0xFF82C84B);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

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
  int _score = 0;

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
      // Pick a random uppercase letter as the goal
      _targetLetter = String.fromCharCode(_random.nextInt(26) + 65);
    });
  }

  void _startGameLoops() {
    // Spawn a new ball every 1.5 seconds
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _spawnBall();
    });

    // Game logic loop (60fps) to move balls down
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateBallPositions();
    });
  }

  void _spawnBall() {
    if (!mounted) return;

    // 30% chance the ball has the correct target letter
    bool isCorrect = _random.nextDouble() < 0.3;
    String ballLetter = isCorrect
        ? _targetLetter
        : String.fromCharCode(_random.nextInt(26) + 65);

    setState(() {
      _activeBalls.add(
        FallingBall(
          letter: ballLetter,
          xPos: _random.nextDouble(), // Random horizontal start (0.0 to 1.0)
          yPos: -0.1, // Start just above the screen
          speed: 0.003 + (_random.nextDouble() * 0.004), // Random fall speed
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
      // Remove balls that fell off the bottom
      _activeBalls.removeWhere((ball) => ball.yPos > 1.1);
    });
  }

  int _correctCount = 0;
  final List<Map<String, double>> _wrongEffects = [];

  void _onBallTap(FallingBall ball) {
    if (ball.letter == _targetLetter) {
      setState(() {
        _correctCount++; // Still tracking in the background
        _activeBalls.remove(ball);

        // Check if it's time to applaud!
        if (_correctCount >= 5) {
          _showApplause();
          _correctCount = 0; // Reset for the next round of 5
        } else {
          _setNewTarget(); // Just change the letter for now
        }
      });
    } else {
      // ---  WRONG TAP LOGIC ---
      final double tapX = ball.xPos;
      final double tapY = ball.yPos;

      setState(() {
        _activeBalls.remove(ball);
        _wrongEffects.add({'x': tapX, 'y': tapY}); // Show the 'X'
      });

      // Remove the 'X' after half a second (500 milliseconds)
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

  // Applause Dialog
  void _showApplause() {
    // Get the screen size
    final Size screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,

        insetPadding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scale font size based on screen width
              Text("👏", style: TextStyle(fontSize: screenSize.width * 0.1)),
              const SizedBox(height: 16),
              Text(
                "Great Job!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: screenSize.width * 0.05, // Responsive font
                  fontWeight: FontWeight.bold,
                  color: ColorTheme.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You found 5 letters!",
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: screenSize.width * 0.03,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: screenSize.width * 0.3, // Responsive button width
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _setNewTarget();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorTheme.orange,
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
      backgroundColor: ColorTheme.cream,
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
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 24,
                        color: ColorTheme.deepNavyBlue,
                      ),
                    ),
                    Text(
                      _targetLetter,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: ColorTheme.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            //  FALLING BALLS AND EFFECTS
            LayoutBuilder(
              builder: (context, constraints) {
                double ballSize =
                    constraints.maxWidth * 0.12; // Responsive ball size

                return Stack(
                  children: [
                    // A. Draw the active falling balls
                    ..._activeBalls.map(
                      (ball) {
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
                                      fontFamily: AppTextStyles.fredoka,
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
                      },
                    ), // .toList() is not needed when using the spread operator (...)
                    // B. Draw the Red 'X' for wrong taps!
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
                              size: ballSize * 0.8, // Make the X fill the space
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

            // BACK BUTTON
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: ColorTheme.deepNavyBlue,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
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
