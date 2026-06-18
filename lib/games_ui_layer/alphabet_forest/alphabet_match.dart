import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AlphabetMatchScreen extends StatefulWidget {
  const AlphabetMatchScreen({super.key});

  @override
  State<AlphabetMatchScreen> createState() => _AlphabetMatchScreenState();
}

class _AlphabetMatchScreenState extends State<AlphabetMatchScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 1. THE A-G REQUIREMENT
  final List<String> _allLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  int _currentRoundIndex =
      0; // 0 = First Round (4 items), 1 = Second Round (3 items)

  List<MatchNode> _leftNodes = [];
  List<MatchNode> _rightNodes = [];

  List<CompletedLine> _completedLines = [];
  ActiveLine? _activeLine;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _loadRound();
  }

  // --- THE NEW 4 & 3 ROUND LOGIC ---
  void _loadRound() {
    _completedLines.clear();
    _activeLine = null;

    // First round gets 4 items (A-D), Second round gets 3 items (E-G)
    int startIndex = _currentRoundIndex == 0 ? 0 : 4;
    int itemsThisRound = _currentRoundIndex == 0 ? 4 : 3;
    int endIndex = startIndex + itemsThisRound;

    List<String> currentLetters = _allLetters.sublist(startIndex, endIndex);

    // Create the Right side (Lowercase) and shuffle them!
    List<String> shuffledRight = List.from(currentLetters)..shuffle();

    _leftNodes = [];
    _rightNodes = [];

    for (int i = 0; i < currentLetters.length; i++) {
      // Spaces them out perfectly vertically whether there are 3 or 4 items
      double yPos = (i + 1) / (currentLetters.length + 1);

      _leftNodes.add(
        MatchNode(
          letter: currentLetters[i].toUpperCase(),
          imagePath: _getObjectImage(currentLetters[i]),
          relativePos: Offset(0.25, yPos),
        ),
      );

      _rightNodes.add(
        MatchNode(
          letter: shuffledRight[i].toLowerCase(),
          imagePath: _getObjectImage(shuffledRight[i]),
          relativePos: Offset(0.75, yPos),
        ),
      );
    }

    setState(() {});
  }

  String _getObjectImage(String letter) {
    const Map<String, String> objectMap = {
      'A': 'apple',
      'B': 'ball',
      'C': 'car',
      'D': 'duck',
      'E': 'egg',
      'F': 'feet',
      'G': 'glass',
    };
    final name = objectMap[letter.toUpperCase()] ?? 'apple';
    return 'assets/images/objects/forest/$name.png';
  }

  void _onPanStart(DragStartDetails details, Size size) {
    RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    Offset localPos = box.globalToLocal(details.globalPosition);
    Offset relPos = Offset(localPos.dx / size.width, localPos.dy / size.height);

    for (var node in _leftNodes) {
      if (!_isMatched(node.letter) &&
          (node.relativePos - relPos).distance < 0.12) {
        setState(() {
          _activeLine = ActiveLine(
            start: node.relativePos,
            end: relPos,
            letter: node.letter,
          );
        });
        break;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_activeLine == null) return;

    RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    Offset localPos = box.globalToLocal(details.globalPosition);
    Offset relPos = Offset(localPos.dx / size.width, localPos.dy / size.height);

    setState(() {
      _activeLine!.end = relPos;
    });
  }

  void _onPanEnd(DragEndDetails details) async {
    if (_activeLine == null) return;

    for (var node in _rightNodes) {
      if ((node.relativePos - _activeLine!.end).distance < 0.12) {
        if (node.letter.toUpperCase() == _activeLine!.letter.toUpperCase()) {
          String audioFile =
              'audio/alphabet_forest/sound_effects/sound_${node.letter.toLowerCase()}.wav';
          await _audioPlayer.play(AssetSource(audioFile));

          setState(() {
            _completedLines.add(
              CompletedLine(
                start: _activeLine!.start,
                end: node.relativePos,
                color: ForestColorTheme.seagreen,
              ),
            );
          });
          break;
        }
      }
    }

    setState(() {
      _activeLine = null;
    });

    if (_completedLines.length == _leftNodes.length) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;

        // --- NEW ROUND PROGRESSION ---
        if (_currentRoundIndex == 0) {
          // If they just finished Round 1 (A-D), go to Round 2 (E-G)
          _currentRoundIndex++;
          _loadRound();
        } else {
          // THEY BEAT THE ENTIRE A-G GAME!
          _showApplause();
        }
      });
    }
  }

  bool _isMatched(String letter) {
    for (var line in _completedLines) {
      var node = _leftNodes.firstWhere((n) => n.relativePos == line.start);
      if (node.letter.toUpperCase() == letter.toUpperCase()) return true;
    }
    return false;
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
            // Beating the Match game completes level 8, unlocking level 9.
            ForestProgressService.instance.markLevelComplete(8);

            Navigator.pop(context); // Close the prompt
            // Go to a *fresh* level-select screen so it reloads progress
            // on its own (same pattern as Arctic/Puzzle Glade), instead of
            // popping back to a potentially stale existing instance.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ForestLevelScreen(),
              ),
            );
          },
          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _currentRoundIndex = 0;
              _loadRound();
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
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ForestBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final Size playAreaSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              // --- INCREASED BASE SIZING ---
              // Bumped up the multiplier from 0.20 to 0.23, and increased the clamp max!
              final double itemHeight = (constraints.maxHeight * 0.23).clamp(
                75.0,
                140.0,
              );

              return Stack(
                children: [
                  GestureDetector(
                    onPanStart: (d) => _onPanStart(d, playAreaSize),
                    onPanUpdate: (d) => _onPanUpdate(d, playAreaSize),
                    onPanEnd: _onPanEnd,
                    child: Container(
                      width: playAreaSize.width,
                      height: playAreaSize.height,
                      color: Colors.transparent,
                      child: CustomPaint(
                        painter: MatchLinePainter(
                          completedLines: _completedLines,
                          activeLine: _activeLine,
                        ),
                      ),
                    ),
                  ),

                  ..._leftNodes.map(
                    (node) => _buildNodeWidget(
                      node,
                      playAreaSize,
                      itemHeight,
                      isLeft: true,
                    ),
                  ),
                  ..._rightNodes.map(
                    (node) => _buildNodeWidget(
                      node,
                      playAreaSize,
                      itemHeight,
                      isLeft: false,
                    ),
                  ),

                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: constraints.maxHeight * 0.02,
                      ),
                      child: Text(
                        "Match the letters!",
                        style: TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: constraints.maxHeight * 0.07,
                          color: Color.fromARGB(255, 71, 70, 70),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const Positioned(
                    top: 10,
                    left: 10,
                    child: ForestBackButton(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Builds the Letter + Object pair based on your mockup
  Widget _buildNodeWidget(
    MatchNode node,
    Size size,
    double height, {
    required bool isLeft,
  }) {
    bool isDone = _isMatched(node.letter);

    // 1. SIZING VARIABLES
    double letterSize =
        height *
        1.2; // We give the letter extra space so the stroke doesn't crop!
    double imageSize = height * 0.8;
    double gap = 12.0;

    // 2. THE ANCHOR POINTS
    // This is the exact X and Y coordinate where the drawing line connects
    double centerX = node.relativePos.dx * size.width;
    double centerY = node.relativePos.dy * size.height;

    Widget imageWidget = Image.asset(
      node.imagePath,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
    );

    Widget letterWidget = SizedBox(
      width: letterSize,
      height: letterSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior:
            Clip.none, // Ensures the thick stroke can bleed outward freely
        children: [
          Text(
            node.letter,
            style: TextStyle(
              fontFamily: ForestAppTextStyles.fredoka,
              fontSize: height * 0.75,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 10
                ..color = Colors.grey.shade800,
            ),
          ),
          Text(
            node.letter,
            style: TextStyle(
              fontFamily: ForestAppTextStyles.fredoka,
              fontSize: height * 0.75,
              fontWeight: FontWeight.w900,
              color: const Color.fromARGB(255, 151, 192, 5),
            ),
          ),
        ],
      ),
    );

    // 3. THE SMART OFFSET LOGIC
    // This math ensures the center of the LETTER is always perfectly aligned
    // with the line anchor (centerX), pushing the image out to the side!
    double calculatedLeft = isLeft
        ? (centerX -
              (letterSize / 2) -
              gap -
              imageSize) // Left side: Image is pushed to the left
        : (centerX -
              (letterSize /
                  2)); // Right side: Letter sits exactly on the anchor

    return Positioned(
      left: calculatedLeft,
      top: centerY - (letterSize / 2),
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isDone ? 0.4 : 1.0,
          child: SizedBox(
            width: letterSize + gap + imageSize,
            height: letterSize,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isLeft
                  ? [imageWidget, SizedBox(width: gap), letterWidget]
                  : [letterWidget, SizedBox(width: gap), imageWidget],
            ),
          ),
        ),
      ),
    );
  }
}

class MatchNode {
  final String letter;
  final String imagePath;
  final Offset relativePos;

  MatchNode({
    required this.letter,
    required this.imagePath,
    required this.relativePos,
  });
}

class CompletedLine {
  final Offset start;
  final Offset end;
  final Color color;

  CompletedLine({required this.start, required this.end, required this.color});
}

class ActiveLine {
  final Offset start;
  Offset end;
  final String letter;

  ActiveLine({required this.start, required this.end, required this.letter});
}

class MatchLinePainter extends CustomPainter {
  final List<CompletedLine> completedLines;
  final ActiveLine? activeLine;

  MatchLinePainter({required this.completedLines, this.activeLine});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var line in completedLines) {
      paint.color = line.color;
      canvas.drawLine(
        Offset(line.start.dx * size.width, line.start.dy * size.height),
        Offset(line.end.dx * size.width, line.end.dy * size.height),
        paint,
      );
    }

    if (activeLine != null) {
      paint.color = ForestColorTheme.lightgreen;
      canvas.drawLine(
        Offset(
          activeLine!.start.dx * size.width,
          activeLine!.start.dy * size.height,
        ),
        Offset(
          activeLine!.end.dx * size.width,
          activeLine!.end.dy * size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(MatchLinePainter oldDelegate) => true;
}
