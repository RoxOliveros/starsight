import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math'; // Needed for calculating distance

// --- REUSING YOUR EXACT THEMES ---
abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8);
  static const Color deepNavyBlue = Color(0xFF5E463E);
  static const Color orange = Color(0xFFEC8A20);
  static const Color green = Color(0xFF82C84B); // Added for the Success button
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

// --- NEW: LEVEL DATA MODEL ---
class TraceLevel {
  final String letterName;
  final String imagePath;
  final List<Offset>
  checkpoints; // Invisible targets (0.0 to 1.0 percentage of the screen)

  TraceLevel({
    required this.letterName,
    required this.imagePath,
    required this.checkpoints,
  });
}

// --- THE TRACING SCREEN ---
class AlphabetTraceScreen extends StatefulWidget {
  const AlphabetTraceScreen({super.key});

  @override
  State<AlphabetTraceScreen> createState() => _AlphabetTraceScreenState();
}

class _AlphabetTraceScreenState extends State<AlphabetTraceScreen> {
  List<Offset?> _points = [];
  final GlobalKey _canvasKey = GlobalKey(); // Used to measure the canvas size
  int _currentLevelIndex = 0; // Starts at 0 (Level 1)

  // --- OUR GAME LEVELS ---
  final List<TraceLevel> _levels = [
    TraceLevel(
      letterName: "Big A",
      imagePath: 'assets/fonts/game_letters/Trace_A.png',
      checkpoints: [
        const Offset(0.5, 0.35), // Top point
        const Offset(0.42, 0.90), // Bottom Left
        const Offset(0.58, 0.90), // Bottom Right
        const Offset(0.5, 0.78), // Middle crossbar
      ],
    ),
    TraceLevel(
      letterName: "Small a",
      imagePath: 'assets/fonts/game_letters/Trace_small_a.png',
      checkpoints: [
        const Offset(0.5, 0.55), // Top curve
        const Offset(0.45, 0.7), // Left curve
        const Offset(0.5, 0.9), // Bottom curve
        const Offset(0.55, 0.55), // Right straight line top
        const Offset(0.55, 0.90), // Right straight line bottom
      ],
    ),
    // You can easily add B, C, D here later!
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _clearBoard() {
    setState(() {
      _points.clear();
    });
  }

  // --- THE MAGIC: EVALUATING THE TRACE ---
  void _checkTrace() {
    // 1. Get the exact width and height of the white drawing box
    final RenderBox renderBox =
        _canvasKey.currentContext!.findRenderObject() as RenderBox;
    final Size canvasSize = renderBox.size;

    final currentLevel = _levels[_currentLevelIndex];
    int hitCount = 0;

    // 2. Loop through our invisible checkpoints
    for (Offset targetPercentage in currentLevel.checkpoints) {
      // Convert the percentage (0.5) to actual screen pixels (e.g., 300px)
      Offset pixelTarget = Offset(
        targetPercentage.dx * canvasSize.width,
        targetPercentage.dy * canvasSize.height,
      );

      bool hit = false;

      // 3. Check every point the child drew. Did they get close to this target?
      for (Offset? drawnPoint in _points) {
        if (drawnPoint != null) {
          // Calculate distance using basic math (Pythagorean theorem)
          double distance = sqrt(
            pow(drawnPoint.dx - pixelTarget.dx, 2) +
                pow(drawnPoint.dy - pixelTarget.dy, 2),
          );

          // If they drew within 50 pixels of the target, it counts as a hit!
          if (distance < 50.0) {
            hit = true;
            break; // Move to the next target
          }
        }
      }

      if (hit) hitCount++;
    }

    // 4. Did they hit ALL the checkpoints?
    if (hitCount == currentLevel.checkpoints.length) {
      _showSuccessDialog();
    } else {
      _showTryAgainDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          "Awesome!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.green,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "You traced it perfectly!",
          style: TextStyle(fontFamily: AppTextStyles.fredoka, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _clearBoard();
                // Move to next level, or loop back to 0 if they beat the game!
                if (_currentLevelIndex < _levels.length - 1) {
                  _currentLevelIndex++;
                } else {
                  _currentLevelIndex = 0; // Game beat! Back to start.
                }
              });
            },
            child: const Text(
              "Next Letter",
              style: TextStyle(
                color: ColorTheme.orange,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTryAgainDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Almost!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.orange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Try to trace exactly over the lines. You can do it!",
          style: TextStyle(fontFamily: AppTextStyles.fredoka, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearBoard(); // Wipe the board for them to try again
            },
            child: const Text(
              "Try Again",
              style: TextStyle(
                color: ColorTheme.deepNavyBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = _levels[_currentLevelIndex];

    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: ColorTheme.deepNavyBlue,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Alphabet Trace',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.deepNavyBlue,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: ColorTheme.orange,
                        size: 32,
                      ),
                      onPressed: _clearBoard,
                    ),
                  ),
                ],
              ),
            ),

            // --- THE TRACING CANVAS ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40.0,
                  vertical: 8.0,
                ),
                child: Container(
                  key: _canvasKey, // Attach the measuring tape here!
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: ColorTheme.deepNavyBlue.withOpacity(0.2),
                      width: 4,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // LAYER 1: The background letter
                      Center(
                        child: Image.asset(
                          currentLevel.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Text(
                            currentLevel.letterName[currentLevel
                                    .letterName
                                    .length -
                                1], // Pulls the last letter from the name
                            style: TextStyle(
                              fontFamily: AppTextStyles.fredoka,
                              fontSize: 250,
                              fontWeight: FontWeight.bold,
                              color: ColorTheme.deepNavyBlue.withOpacity(0.15),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),

                      // LAYER 2: The Drawing Glass
                      GestureDetector(
                        onPanStart: (details) =>
                            setState(() => _points.add(details.localPosition)),
                        onPanUpdate: (details) =>
                            setState(() => _points.add(details.localPosition)),
                        onPanEnd: (details) =>
                            setState(() => _points.add(null)),
                        child: CustomPaint(
                          painter: TracePainter(
                            points: _points,
                            checkpoints: currentLevel
                                .checkpoints, // <-- Pass the checkpoints down!
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- NEW: THE CHECK BUTTON ---
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton(
                onPressed: _points.isEmpty
                    ? null
                    : _checkTrace, // Disable if they haven't drawn anything
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorTheme.green,
                  disabledBackgroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  "CHECK TRACE",
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- THE INVISIBLE ARTIST ---
// --- THE INVISIBLE (NOW VISIBLE!) ARTIST ---
class TracePainter extends CustomPainter {
  final List<Offset?> points;
  final List<Offset> checkpoints; // <-- Added this

  TracePainter({
    required this.points,
    required this.checkpoints,
  }); // <-- Updated constructor

  @override
  void paint(Canvas canvas, Size size) {
    // 1. --- DEBUG MODE: DRAW THE CHECKPOINTS FIRST ---
    final debugPaint = Paint()
      ..color = Colors.green
          .withValues(alpha: 0.3) // Semi-transparent green
      ..style = PaintingStyle.fill;

    for (Offset cp in checkpoints) {
      // Convert the percentage (e.g., 0.5) to exact screen pixels
      Offset pixelTarget = Offset(cp.dx * size.width, cp.dy * size.height);

      // Draw a circle with a radius of 50.
      // This perfectly matches your "distance < 50.0" math!
      canvas.drawCircle(pixelTarget, 15.0, debugPaint);
    }

    // 2. --- DRAW THE INK ON TOP ---
    final inkPaint = Paint()
      ..color = ColorTheme.orange
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 24.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, inkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TracePainter oldDelegate) => true;
}
