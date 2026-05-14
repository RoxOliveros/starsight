import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlphabetLineMatchScreen extends StatefulWidget {
  const AlphabetLineMatchScreen({super.key});

  @override
  State<AlphabetLineMatchScreen> createState() =>
      _AlphabetLineMatchScreenState();
}

class _AlphabetLineMatchScreenState extends State<AlphabetLineMatchScreen> {
  final List<String> _leftLetters = ['A', 'B', 'C', 'D'];
  List<String> _rightLetters = [];

  final Map<int, int> _matches = {};
  int? _draggingLeftIndex;
  Offset? _currentDragPos;

  final Color _yellowColor = const Color(0xFFFBD481);
  final Color _blueColor = const Color(0xFF75D5FF);
  final Color _redColor = const Color(0xFFE65C5C);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _rightLetters = List.from(['a', 'b', 'c', 'd'])..shuffle();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _matches.clear();
      _draggingLeftIndex = null;
      _currentDragPos = null;
      _rightLetters.shuffle();
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: ForestColorTheme.lightgrayishgreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Awesome!",
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            color: ForestColorTheme.darkseagreen,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "You connected all the letters!",
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontSize: 18,
            color: ForestColorTheme.seagreen,
          ),
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
                color: ForestColorTheme.darkseagreen,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _getLeftDotPosition(int index, Size size) {
    double ySpace = size.height / (_leftLetters.length + 1);
    return Offset(size.width * 0.35, ySpace * (index + 1));
  }

  Offset _getRightDotPosition(int index, Size size) {
    double ySpace = size.height / (_rightLetters.length + 1);
    return Offset(size.width * 0.65, ySpace * (index + 1));
  }

  void _onPanStart(DragStartDetails details, Size size) {
    Offset touchPos = details.localPosition;
    for (int i = 0; i < _leftLetters.length; i++) {
      if (_matches.containsKey(i)) continue;
      Offset dotPos = _getLeftDotPosition(i, size);
      if ((touchPos - dotPos).distance < 40.0) {
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
    for (int i = 0; i < _rightLetters.length; i++) {
      Offset dotPos = _getRightDotPosition(i, size);
      if ((_currentDragPos! - dotPos).distance < 50.0) {
        if (_leftLetters[_draggingLeftIndex!].toLowerCase() ==
            _rightLetters[i].toLowerCase()) {
          setState(() {
            _matches[_draggingLeftIndex!] = i;
          });
          if (_matches.length == _leftLetters.length) {
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
      backgroundColor: ForestColorTheme.lightgrayishgreen,
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
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ForestBackButton(),
                  ),
                  const Text(
                    'Match the Letters',
                    style: TextStyle(
                      fontFamily: ForestAppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ForestColorTheme.darkseagreen,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: ForestColorTheme.seagreen,
                        size: 32,
                      ),
                      onPressed: _resetGame,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  Size canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  return GestureDetector(
                    onPanStart: (details) => _onPanStart(details, canvasSize),
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: (details) => _onPanEnd(details, canvasSize),
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter: LinePainter(
                            leftLetters: _leftLetters,
                            rightLetters: _rightLetters,
                            matches: _matches,
                            draggingLeftIndex: _draggingLeftIndex,
                            currentDragPos: _currentDragPos,
                            getLeftPos: (i) =>
                                _getLeftDotPosition(i, canvasSize),
                            getRightPos: (i) =>
                                _getRightDotPosition(i, canvasSize),
                            dotColor: _yellowColor,
                            lineColor: _redColor,
                          ),
                        ),

                        for (int i = 0; i < _leftLetters.length; i++)
                          Positioned(
                            left: canvasSize.width * 0.15,
                            top: _getLeftDotPosition(i, canvasSize).dy - 40,
                            child: _LetterBlock(
                              letter: _leftLetters[i],
                              color: _yellowColor,
                            ),
                          ),

                        for (int i = 0; i < _rightLetters.length; i++)
                          Positioned(
                            left: canvasSize.width * 0.70,
                            top: _getRightDotPosition(i, canvasSize).dy - 40,
                            child: _LetterBlock(
                              letter: _rightLetters[i],
                              color: _blueColor,
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

class _LetterBlock extends StatelessWidget {
  final String letter;
  final Color color;

  const _LetterBlock({required this.letter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      letter,
      style: TextStyle(
        fontFamily: ForestAppTextStyles.fredoka,
        fontSize: 70,
        fontWeight: FontWeight.w900,
        color: color,
        shadows: const [
          Shadow(color: Colors.black26, offset: Offset(2, 4), blurRadius: 4),
        ],
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final List<String> leftLetters;
  final List<String> rightLetters;
  final Map<int, int> matches;
  final int? draggingLeftIndex;
  final Offset? currentDragPos;
  final Offset Function(int) getLeftPos;
  final Offset Function(int) getRightPos;
  final Color dotColor;
  final Color lineColor;

  LinePainter({
    required this.leftLetters,
    required this.rightLetters,
    required this.matches,
    required this.draggingLeftIndex,
    required this.currentDragPos,
    required this.getLeftPos,
    required this.getRightPos,
    required this.dotColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    final dotShadowPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 6.0
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

    for (int i = 0; i < leftLetters.length; i++) {
      Offset pos = getLeftPos(i);
      canvas.drawCircle(Offset(pos.dx + 2, pos.dy + 2), 12, dotShadowPaint);
      canvas.drawCircle(pos, 12, dotPaint);
    }

    for (int i = 0; i < rightLetters.length; i++) {
      Offset pos = getRightPos(i);
      canvas.drawCircle(Offset(pos.dx + 2, pos.dy + 2), 12, dotShadowPaint);
      canvas.drawCircle(pos, 12, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) => true;
}
