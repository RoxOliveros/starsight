import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../business_layer/orientation_service.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8);
  static const Color deepNavyBlue = Color(0xFF5E463E);
  static const Color orange = Color(0xFFEC8A20);
  static const Color green = Color(0xFF82C84B);
  static const Color red = Color(0xFFE65C5C);
  static const Color goldenYellow = Color(0xFFFBD481);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class MatchItem {
  final String id;
  final String imagePath;

  MatchItem({required this.id, required this.imagePath});
}

class WeatherMatchScreen extends StatefulWidget {
  const WeatherMatchScreen({super.key});

  @override
  State<WeatherMatchScreen> createState() => _WeatherMatchScreenState();
}

class _WeatherMatchScreenState extends State<WeatherMatchScreen> {
  // 1. Declare lists (initialized in initState)
  late List<MatchItem> _leftItems;
  late List<MatchItem> _rightItems;

  final Map<int, int> _matches = {};
  int? _draggingLeftIndex;
  Offset? _currentDragPos;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    OrientationService.setLandscape();

    // Setup AND shuffle both sides!
    _leftItems = [
      MatchItem(id: 'sunny', imagePath: 'assets/images/objects/sunny.png'),
      MatchItem(id: 'winter', imagePath: 'assets/images/objects/winter.png'),
      MatchItem(id: 'rainy', imagePath: 'assets/images/objects/rainy.png'),
    ]..shuffle();

    _rightItems = [
      MatchItem(
        id: 'sunny',
        imagePath: 'assets/images/objects/sunny_clothes.png',
      ),
      MatchItem(
        id: 'winter',
        imagePath: 'assets/images/objects/winter_clothes.png',
      ),
      MatchItem(
        id: 'rainy',
        imagePath: 'assets/images/objects/rainy_clothes.png',
      ),
    ]..shuffle();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    OrientationService.setLandscape();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _matches.clear();
      _draggingLeftIndex = null;
      _currentDragPos = null;
      _leftItems.shuffle(); // Shuffle left again!
      _rightItems.shuffle(); // Shuffle right again!
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
          "You matched all the clothes to the weather!",
          style: TextStyle(fontFamily: AppTextStyles.fredoka, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: const Text(
              "Play Again",
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

  // --- GRID MATH HELPERS (Adjusted for better spacing) ---
  Offset _getLeftDotPosition(int index, Size size) {
    double ySpace = size.height / (_leftItems.length + 1);
    return Offset(size.width * 0.30, ySpace * (index + 1)); // Pushed left
  }

  Offset _getRightDotPosition(int index, Size size) {
    double ySpace = size.height / (_rightItems.length + 1);
    return Offset(size.width * 0.70, ySpace * (index + 1)); // Pushed right
  }

  // --- DRAG LOGIC ---
  void _onPanStart(DragStartDetails details, Size size) {
    Offset touchPos = details.localPosition;

    for (int i = 0; i < _leftItems.length; i++) {
      if (_matches.containsKey(i)) continue;

      Offset dotPos = _getLeftDotPosition(i, size);
      if ((touchPos - dotPos).distance < 50.0) {
        setState(() {
          _draggingLeftIndex = i;
          _currentDragPos = touchPos;
        });
        break;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggingLeftIndex != null) {
      setState(() {
        _currentDragPos = details.localPosition;
      });
    }
  }

  void _onPanEnd(DragEndDetails details, Size size) {
    if (_draggingLeftIndex == null || _currentDragPos == null) return;

    for (int i = 0; i < _rightItems.length; i++) {
      Offset dotPos = _getRightDotPosition(i, size);

      if ((_currentDragPos! - dotPos).distance < 60.0) {
        if (_leftItems[_draggingLeftIndex!].id == _rightItems[i].id) {
          setState(() {
            _matches[_draggingLeftIndex!] = i;
          });

          if (_matches.length == _leftItems.length) {
            _showSuccessDialog();
          }
          break;
        }
      }
    }

    setState(() {
      _draggingLeftIndex = null;
      _currentDragPos = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // HEADER
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
                    'Weather Match',
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
                      onPressed: _resetGame,
                    ),
                  ),
                ],
              ),
            ),

            // GAME BOARD
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  Size canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  // NEW SIZING LOGIC: Use Height instead of Width!
                  // 28% of the screen height ensures they never overlap vertically.
                  double imageSize = constraints.maxHeight * 0.28;

                  return GestureDetector(
                    onPanStart: (details) => _onPanStart(details, canvasSize),
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: (details) => _onPanEnd(details, canvasSize),
                    child: Stack(
                      children: [
                        // 1. THE DRAWING CANVAS
                        CustomPaint(
                          size: Size.infinite,
                          painter: LinePainter(
                            itemCount: _leftItems.length,
                            matches: _matches,
                            draggingLeftIndex: _draggingLeftIndex,
                            currentDragPos: _currentDragPos,
                            getLeftPos: (i) =>
                                _getLeftDotPosition(i, canvasSize),
                            getRightPos: (i) =>
                                _getRightDotPosition(i, canvasSize),
                          ),
                        ),

                        // 2. THE LEFT IMAGES (Weather)
                        for (int i = 0; i < _leftItems.length; i++)
                          Positioned(
                            left:
                                canvasSize.width * 0.12 -
                                (imageSize / 2), // Pushed left
                            top:
                                _getLeftDotPosition(i, canvasSize).dy -
                                (imageSize / 2),
                            child: SizedBox(
                              width: imageSize,
                              height: imageSize,
                              child: Image.asset(
                                _leftItems[i].imagePath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                        // 3. THE RIGHT IMAGES (Clothes)
                        for (int i = 0; i < _rightItems.length; i++)
                          Positioned(
                            left:
                                canvasSize.width * 0.88 -
                                (imageSize / 2), // Pushed right
                            top:
                                _getRightDotPosition(i, canvasSize).dy -
                                (imageSize / 2),
                            child: SizedBox(
                              width: imageSize,
                              height: imageSize,
                              child: Image.asset(
                                _rightItems[i].imagePath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                      ],
                    ),
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

class LinePainter extends CustomPainter {
  final int itemCount;
  final Map<int, int> matches;
  final int? draggingLeftIndex;
  final Offset? currentDragPos;
  final Offset Function(int) getLeftPos;
  final Offset Function(int) getRightPos;

  LinePainter({
    required this.itemCount,
    required this.matches,
    required this.draggingLeftIndex,
    required this.currentDragPos,
    required this.getLeftPos,
    required this.getRightPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = ColorTheme.goldenYellow
      ..style = PaintingStyle.fill;
    final dotShadowPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = ColorTheme.red
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    matches.forEach((leftIndex, rightIndex) {
      canvas.drawLine(
        getLeftPos(leftIndex),
        getRightPos(rightIndex),
        linePaint,
      );
    });

    if (draggingLeftIndex != null && currentDragPos != null) {
      canvas.drawLine(
        getLeftPos(draggingLeftIndex!),
        currentDragPos!,
        linePaint,
      );
    }

    for (int i = 0; i < itemCount; i++) {
      Offset lPos = getLeftPos(i);
      Offset rPos = getRightPos(i);

      canvas.drawCircle(Offset(lPos.dx + 2, lPos.dy + 2), 14, dotShadowPaint);
      canvas.drawCircle(lPos, 14, dotPaint);

      canvas.drawCircle(Offset(rPos.dx + 2, rPos.dy + 2), 14, dotShadowPaint);
      canvas.drawCircle(rPos, 14, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) => true;
}
