import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

// --- NEW LEVEL MODEL FOR GUIDED TRACING ---
class TraceLevel {
  final String letterName;
  final String imagePath;
  final List<List<Offset>> strokes;

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
  int _currentStrokeIndex = 0;
  int _currentPointIndex = 0;
  List<List<Offset>> _denseStrokes = [];

  final List<TraceLevel> _levels = [
    TraceLevel(
      letterName: "Big A",
      imagePath: '',
      strokes: [
        [const Offset(0.5, 0.2), const Offset(0.2, 0.8)],
        [const Offset(0.5, 0.2), const Offset(0.8, 0.8)],
        [const Offset(0.35, 0.5), const Offset(0.65, 0.5)],
      ],
    ),
    TraceLevel(
      letterName: "Small a",
      imagePath: '',
      strokes: [
        [
          const Offset(0.70, 0.50),
          const Offset(0.50, 0.40),
          const Offset(0.40, 0.45),
          const Offset(0.30, 0.60),
          const Offset(0.45, 0.80),
          const Offset(0.65, 0.75),
          const Offset(0.70, 0.65),
        ],
        [const Offset(0.70, 0.35), const Offset(0.70, 0.85)],
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateDensePaths());
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

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

    if (_currentPointIndex < currentStroke.length) {
      Offset target = currentStroke[_currentPointIndex];
      double distance = sqrt(
        pow(dragPos.dx - target.dx, 2) + pow(dragPos.dy - target.dy, 2),
      );

      if (distance < 40.0) {
        setState(() {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: ForestColorTheme.lightgrayishgreen,
        title: const Text(
          "Awesome!",
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            color: ForestColorTheme.darkseagreen,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "You traced it perfectly!",
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            color: ForestColorTheme.seagreen,
            fontSize: 22,
          ),
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
                color: ForestColorTheme.darkseagreen,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForestColorTheme.lightgrayishgreen, // Applied Theme
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // --- REPLACED WITH CUSTOM BUTTON ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ForestBackButton(),
                  ),
                  const Text(
                    'Alphabet Trace',
                    style: TextStyle(
                      fontFamily: ForestAppTextStyles.fredoka, // Applied Theme
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ForestColorTheme.darkseagreen, // Applied Theme
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: ForestColorTheme.seagreen, // Applied Theme
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
                          color: ForestColorTheme.lightgreen, // Applied Theme
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
            const SizedBox(height: 20),
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

    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );

    final bgPaint = Paint()
      ..color = Colors.grey
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

    canvas.restore();

    // --- UPDATED TRACING COLORS TO MATCH FOREST THEME ---
    final fillPaint = Paint()
      ..color = ForestColorTheme
          .mediumseagreen // Replaced Light Blue
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 30.0
      ..style = PaintingStyle.stroke;

    final guidePaint = Paint()
      ..color = ForestColorTheme
          .darkseagreen // Replaced Green
      ..style = PaintingStyle.fill;

    for (int i = 0; i < denseStrokes.length; i++) {
      var stroke = denseStrokes[i];
      if (stroke.isEmpty) continue;

      if (i < currentStrokeIndex) {
        Path fillPath = Path();
        fillPath.moveTo(stroke[0].dx, stroke[0].dy);
        for (int j = 1; j < stroke.length; j++) {
          fillPath.lineTo(stroke[j].dx, stroke[j].dy);
        }
        canvas.drawPath(fillPath, fillPaint);
      } else if (i == currentStrokeIndex) {
        if (currentPointIndex > 0) {
          Path fillPath = Path();
          fillPath.moveTo(stroke[0].dx, stroke[0].dy);
          for (int j = 1; j < currentPointIndex; j++) {
            fillPath.lineTo(stroke[j].dx, stroke[j].dy);
          }
          canvas.drawPath(fillPath, fillPaint);
        }

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
