import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8);
  static const Color deepNavyBlue = Color(0xFF5E463E);
  static const Color orange = Color(0xFFEC8A20);
  static const Color green = Color(0xFF82C84B);
  static const Color lightBlue = Color(0xFF75D5FF); // Added for the fill color
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

// --- NEW LEVEL MODEL FOR GUIDED TRACING ---
class TraceLevel {
  final String letterName;
  final String imagePath;
  final List<List<Offset>>
  strokes; // A letter can have multiple strokes (e.g., 'A' has 3)

  TraceLevel({
    required this.letterName,
    required this.imagePath,
    required this.strokes,
  });
}

class AlphabetTraceScreen extends StatefulWidget {
  const AlphabetTraceScreen({super.key});

  @override
  State<AlphabetTraceScreen> createState() => _AlphabetTraceScreenState();
}

class _AlphabetTraceScreenState extends State<AlphabetTraceScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  int _currentLevelIndex = 0;

  // Tracking Progress
  int _currentStrokeIndex = 0; // Which line are they drawing?
  int _currentPointIndex = 0; // How far along that line are they?
  List<List<Offset>> _denseStrokes = []; // The calculated path pixels

  final List<TraceLevel> _levels = [
    TraceLevel(
      letterName: "Big A",
      imagePath: '',
      strokes: [
        // Stroke 1: Left diagonal down
        [const Offset(0.5, 0.2), const Offset(0.2, 0.8)],
        // Stroke 2: Right diagonal down
        [const Offset(0.5, 0.2), const Offset(0.8, 0.8)],
        // Stroke 3: Middle crossbar
        [const Offset(0.35, 0.5), const Offset(0.65, 0.5)],
      ],
    ),
    TraceLevel(
      letterName: "Small a",
      imagePath: '',
      strokes: [
        // Stroke 1: The circle loop
        [
          const Offset(0.70, 0.50), // Start right-middle
          const Offset(0.50, 0.40), // Curve top-left
          const Offset(0.40, 0.45), // Curve left
          const Offset(0.30, 0.60), // Curve bottom-left
          const Offset(0.45, 0.80), // Curve bottom
          const Offset(0.65, 0.75), // Curve right-up
          const Offset(0.70, 0.65), // Connect to stem
        ],
        // Stroke 2: The straight stem down
        [
          const Offset(0.70, 0.35), // Start top of stem
          const Offset(0.70, 0.85), // End bottom of stem
        ],
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // We wait a frame so the canvas has a size, then generate the path
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateDensePaths());
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // This breaks your waypoints into hundreds of tiny dots to track smooth progress
  void _generateDensePaths() {
    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size size = renderBox.size;
    List<List<Offset>> newDenseStrokes = [];

    for (var stroke in _levels[_currentLevelIndex].strokes) {
      List<Offset> densePoints = [];
      for (int i = 0; i < stroke.length - 1; i++) {
        Offset p1 = Offset(
          stroke[i].dx * size.width,
          stroke[i].dy * size.height,
        );
        Offset p2 = Offset(
          stroke[i + 1].dx * size.width,
          stroke[i + 1].dy * size.height,
        );

        // Add a point every 5 pixels
        double distance = sqrt(pow(p2.dx - p1.dx, 2) + pow(p2.dy - p1.dy, 2));
        int steps = (distance / 5.0).ceil();

        for (int j = 0; j <= steps; j++) {
          densePoints.add(
            Offset(
              p1.dx + (p2.dx - p1.dx) * (j / steps),
              p1.dy + (p2.dy - p1.dy) * (j / steps),
            ),
          );
        }
      }
      newDenseStrokes.add(densePoints);
    }

    setState(() {
      _denseStrokes = newDenseStrokes;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length)
      return;

    Offset dragPos = details.localPosition;
    List<Offset> currentStroke = _denseStrokes[_currentStrokeIndex];

    // Check if finger is close to the NEXT required point
    if (_currentPointIndex < currentStroke.length) {
      Offset target = currentStroke[_currentPointIndex];
      double distance = sqrt(
        pow(dragPos.dx - target.dx, 2) + pow(dragPos.dy - target.dy, 2),
      );

      // If they are within 40 pixels of the target dot, fill it in!
      if (distance < 40.0) {
        setState(() {
          // Fast-forward progress if they drag fast
          while (_currentPointIndex < currentStroke.length &&
              sqrt(
                    pow(dragPos.dx - currentStroke[_currentPointIndex].dx, 2) +
                        pow(
                          dragPos.dy - currentStroke[_currentPointIndex].dy,
                          2,
                        ),
                  ) <
                  40.0) {
            _currentPointIndex++;
          }
        });

        // Did they finish this stroke?
        if (_currentPointIndex >= currentStroke.length) {
          _moveToNextStroke();
        }
      }
    }
  }

  void _moveToNextStroke() {
    setState(() {
      _currentStrokeIndex++;
      _currentPointIndex = 0;
    });

    // Did they finish the whole letter?
    if (_currentStrokeIndex >= _denseStrokes.length) {
      _showSuccessDialog();
    }
  }

  void _resetBoard() {
    setState(() {
      _currentStrokeIndex = 0;
      _currentPointIndex = 0;
    });
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
              Navigator.pop(context);
              setState(() {
                _resetBoard();
                if (_currentLevelIndex < _levels.length - 1) {
                  _currentLevelIndex++;
                  _generateDensePaths();
                } else {
                  _currentLevelIndex = 0;
                  _generateDensePaths();
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

  @override
  Widget build(BuildContext context) {
    final currentLevel = _levels[_currentLevelIndex];

    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
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
                      onPressed: _resetBoard,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      key: _canvasKey,
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
                          GestureDetector(
                            onPanUpdate: _onPanUpdate,
                            child: CustomPaint(
                              painter: GuidedTracePainter(
                                denseStrokes: _denseStrokes,
                                currentStrokeIndex: _currentStrokeIndex,
                                currentPointIndex: _currentPointIndex,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20), // Spacing where the button used to be
          ],
        ),
      ),
    );
  }
}

class GuidedTracePainter extends CustomPainter {
  final List<List<Offset>> denseStrokes;
  final int currentStrokeIndex;
  final int currentPointIndex;

  GuidedTracePainter({
    required this.denseStrokes,
    required this.currentStrokeIndex,
    required this.currentPointIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (denseStrokes.isEmpty) return;

    // --- 1. DRAW THE UNIFORM GREY BACKGROUND ---
    // Save a temporary layer and tell it to be 20% transparent
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );

    // Draw the strokes completely SOLID inside this temporary layer
    final bgPaint = Paint()
      ..color = Colors
          .grey // Notice there is no opacity here!
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < denseStrokes.length; i++) {
      var stroke = denseStrokes[i];
      if (stroke.isEmpty) continue;

      Path bgPath = Path();
      bgPath.moveTo(stroke[0].dx, stroke[0].dy);
      for (int j = 1; j < stroke.length; j++) {
        bgPath.lineTo(stroke[j].dx, stroke[j].dy);
      }
      canvas.drawPath(bgPath, bgPaint);
    }

    // Paste the temporary layer onto the screen (this applies the 20% transparency evenly!)
    canvas.restore();

    // --- 2. DRAW THE BLUE FILL & GREEN GUIDE ---
    // These are drawn normally on top so they stay bright and solid
    final fillPaint = Paint()
      ..color = ColorTheme.lightBlue
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 30.0
      ..style = PaintingStyle.stroke;
    final guidePaint = Paint()
      ..color = ColorTheme.green
      ..style = PaintingStyle.fill;

    for (int i = 0; i < denseStrokes.length; i++) {
      var stroke = denseStrokes[i];
      if (stroke.isEmpty) continue;

      if (i < currentStrokeIndex) {
        // Fully drawn previous strokes
        Path fillPath = Path();
        fillPath.moveTo(stroke[0].dx, stroke[0].dy);
        for (int j = 1; j < stroke.length; j++) {
          fillPath.lineTo(stroke[j].dx, stroke[j].dy);
        }
        canvas.drawPath(fillPath, fillPaint);
      } else if (i == currentStrokeIndex) {
        // Currently drawing stroke
        if (currentPointIndex > 0) {
          Path fillPath = Path();
          fillPath.moveTo(stroke[0].dx, stroke[0].dy);
          for (int j = 1; j < currentPointIndex; j++) {
            fillPath.lineTo(stroke[j].dx, stroke[j].dy);
          }
          canvas.drawPath(fillPath, fillPaint);
        }

        // Draw the guiding green circle
        if (currentPointIndex < stroke.length) {
          canvas.drawCircle(stroke[currentPointIndex], 20.0, guidePaint);

          final iconPaint = Paint()
            ..color = Colors.white
            ..strokeWidth = 4.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          Offset center = stroke[currentPointIndex];
          canvas.drawLine(
            Offset(center.dx - 5, center.dy),
            Offset(center.dx, center.dy + 5),
            iconPaint,
          );
          canvas.drawLine(
            Offset(center.dx, center.dy + 5),
            Offset(center.dx + 8, center.dy - 6),
            iconPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuidedTracePainter oldDelegate) => true;
}
