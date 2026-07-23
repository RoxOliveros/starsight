import 'dart:math';
import 'dart:ui' as ui;
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_woodpecker_letter_listen.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'alphabet_game_ui.dart';
import 'forest_game_acorn_basket.dart';

class PaintPoint {
  final Offset position;
  final Color color;
  final double radius;

  PaintPoint({
    required this.position,
    required this.color,
    required this.radius,
  });
}

class AlphabetPaintScreen extends StatefulWidget {
  final String letter;

  const AlphabetPaintScreen({super.key, required this.letter});

  @override
  State<AlphabetPaintScreen> createState() => _AlphabetPaintScreenState();
}

class _AlphabetPaintScreenState extends State<AlphabetPaintScreen>
    with TickerProviderStateMixin, TofiReactionMixin {

  final AudioPlayer _player = AudioPlayer();

  @override
  AudioPlayer get tofiPlayer => _player;

  // --- Paint State ---
  final List<PaintPoint> _paintPoints = [];
  Color _selectedColor = const Color(0xFFE74C3C); // default red
  bool _celebrationShown = false;

  // Canvas key for coverage check
  final GlobalKey _canvasKey = GlobalKey();

  // --- Watercolor palette ---
  final List<Color> _palette = [
    const ui.Color.fromARGB(255, 13, 255, 0),
    const ui.Color.fromARGB(255, 255, 0, 183),
    const ui.Color.fromARGB(255, 0, 206, 209),
    const ui.Color.fromARGB(255, 231, 76, 60),
    const ui.Color.fromARGB(255, 230, 126, 34), // orange
    const ui.Color.fromARGB(255, 241, 196, 15), // yellow
    const ui.Color.fromARGB(255, 46, 204, 113), // green
    const ui.Color.fromARGB(255, 52, 152, 219), // blue
    const ui.Color.fromARGB(255, 155, 89, 182), // purple
    const ui.Color.fromARGB(255, 255, 105, 180), // pink
    const ui.Color.fromARGB(255, 26, 188, 156), // teal
    const ui.Color.fromARGB(255, 139, 69, 19), // brown
    const ui.Color.fromARGB(255, 44, 62, 80), // dark blue
    const ui.Color.fromARGB(255, 255, 99, 71), // tomato
  ];

  late AnimationController _celebCtrl;

  // --- Brush size ---
  double _brushSize = 28.0;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _celebCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Coverage check: sample grid points and see how many are painted ──
  void _checkCoverage(Size canvasSize) {
    if (_celebrationShown) return;

    const int gridSize = 30;
    final double cellW = canvasSize.width / gridSize;
    final double cellH = canvasSize.height / gridSize;

    int covered = 0;
    int total = 0;

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final Offset pt = Offset(
          col * cellW + cellW / 2,
          row * cellH + cellH / 2,
        );
        total++;
        for (final p in _paintPoints) {
          if ((p.position - pt).distance < (p.radius * 1.5)) {
            covered++;
            break;
          }
        }
      }
    }

    if (total == 0) return;

    final double coverage = covered / total;

    if (coverage >= 0.50 && !_celebrationShown) {
      _celebrationShown = true;
      Future.delayed(
        const Duration(milliseconds: 400),
            () async {
          await showTofiReaction(TofiState.correct);
          if (mounted) {
            _showCelebrationDialog();
          }
        },
      );
    }
  }

  void _showCelebrationDialog() {
    if (!mounted) return;
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
            } else {
              int charCode = currentLetter.codeUnitAt(0);
              if (charCode >= 65 && charCode < 90) {
                String nextLetter = String.fromCharCode(charCode + 1);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AlphabetIntroScreen(letter: nextLetter),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForestLevelScreen(),
                  ),
                );
              }
            }
          },
          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _paintPoints.clear();
              _celebrationShown = false;
            });
          },
          onBack: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const ForestLevelScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Offset local = box.globalToLocal(details.globalPosition);
    final Size canvasSize = box.size;

    // Clamp to canvas bounds so painting outside the box doesn't register
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > canvasSize.width ||
        local.dy > canvasSize.height) {
      return;
    }

    final Random rng = Random();

    // Add a cluster of soft points for watercolor feel
    for (int i = 0; i < 6; i++) {
      final double jitterX = (rng.nextDouble() - 0.5) * _brushSize * 0.6;
      final double jitterY = (rng.nextDouble() - 0.5) * _brushSize * 0.6;
      final double sizeJitter = _brushSize * (0.6 + rng.nextDouble() * 0.7);

      setState(() {
        _paintPoints.add(
          PaintPoint(
            position: Offset(local.dx + jitterX, local.dy + jitterY),
            color: _selectedColor.withValues(alpha: 0.18 + rng.nextDouble() * 0.15),
            radius: sizeJitter,
          ),
        );
      });
    }

    _checkCoverage(canvasSize);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: ForestBackground(
        child: Stack(
          children: [
            buildTofi(context),

            // ── Back button ──
            const Positioned(top: 25, left: 20, child: ForestBackButton()),

            // ── Title ──
            Positioned(
              top: 25,
              left: 0,
              right: 0,
              child: Center(child: ForestInstructionBanner(text: 'Paint the letter!')),
            ),

            // Level Badge
            Positioned(
              top: 25,
              right: 20,
              child: ForestLevelBadge(
                level: ForestProgressService.levelNumberForLetter(
                  widget.letter.toUpperCase(),
                ) ??
                    1,
              ),
            ),

            // ── Main area: canvas + palette ──
            Positioned(
              top: screenSize.height * 0.22,
              bottom: 12,
              left: 200,
              right: 12,
              child: Column(
                children: [
                  // ── Paint Canvas ──
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onPanUpdate: (d) => _onPanUpdate(d, constraints),
                          onPanStart: (d) {
                            _onPanUpdate(
                              DragUpdateDetails(
                                globalPosition: d.globalPosition,
                                delta: Offset.zero,
                              ),
                              constraints,
                            );
                          },
                          child: Container(
                            key: _canvasKey,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF6E3),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: ForestColorTheme.darkseagreen,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CustomPaint(
                                painter: _ProgressiveLetterPainter(
                                  points: _paintPoints,
                                  letter: widget.letter,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Color Palette — horizontal, scrolls if it overflows ──
                  SizedBox(
                    height: screenSize.height * 0.14,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 8),

                          // Brush size buttons
                          _BrushSizeButton(
                            size: 18,
                            isSelected: _brushSize == 18,
                            color: _selectedColor,
                            onTap: () => setState(() => _brushSize = 18),
                          ),
                          const SizedBox(width: 4),
                          _BrushSizeButton(
                            size: 28,
                            isSelected: _brushSize == 28,
                            color: _selectedColor,
                            onTap: () => setState(() => _brushSize = 28),
                          ),
                          const SizedBox(width: 4),
                          _BrushSizeButton(
                            size: 40,
                            isSelected: _brushSize == 40,
                            color: _selectedColor,
                            onTap: () => setState(() => _brushSize = 40),
                          ),

                          const SizedBox(width: 12),
                          const VerticalDivider(color: Colors.white54, thickness: 1, width: 20),
                          const SizedBox(width: 8),

                          // Color swatches — all palette colors, scrolls if needed
                          ..._palette.map((color) {
                            final bool isSelected = _selectedColor == color;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedColor = color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: isSelected ? 42 : 34,
                                  height: isSelected ? 42 : 34,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white54,
                                      width: isSelected ? 3 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                        : [],
                                  ),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(width: 12),
                          const VerticalDivider(color: Colors.white54, thickness: 1, width: 20),
                          const SizedBox(width: 8),

                          // Clear button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _paintPoints.clear();
                                _celebrationShown = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white54,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  fontFamily: ForestAppTextStyles.fredoka,
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrushSizeButton extends StatelessWidget {
  final double size;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _BrushSizeButton({
    required this.size,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double dotSize = size * 0.55;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _ProgressiveLetterPainter extends CustomPainter {
  final List<PaintPoint> points;
  final String letter;

  _ProgressiveLetterPainter({required this.points, required this.letter});

  // Build a TextPainter for the letter
  TextPainter _makeTP(
    String text,
    double fontSize,
    Color color, {
    Paint? foreground,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: foreground == null ? color : null,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double fontSize = size.height * 0.82;

    // We still need to measure the letter to center it perfectly
    final TextPainter measureTP = _makeTP(
      letter.toUpperCase(),
      fontSize,
      Colors.black,
    );
    final Offset letterOffset = Offset(
      (size.width - measureTP.width) / 2,
      (size.height - measureTP.height) / 2,
    );

    // --- 1. WE REMOVED THE HINT AND OUTLINE PAINTERS HERE ---
    // By removing hintTP.paint() and outlineTP.paint(), the canvas stays completely blank!

    // --- 2. THE SURPRISE REVEAL LOGIC ---
    if (points.isNotEmpty) {
      canvas.saveLayer(Offset.zero & size, Paint());

      // Draw all the watercolor blobs the user is scrubbing onto the screen
      for (final p in points) {
        final Paint strokePaint = Paint()
          ..color = p.color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p.position, p.radius, strokePaint);
      }

      // 3. The Invisible Stencil
      // This mask takes the user's messy paint blobs and cuts them out
      // perfectly into the shape of the hidden letter!
      final TextPainter maskTP = _makeTP(
        letter.toUpperCase(),
        fontSize,
        Colors.black,
      );

      final Paint dstInPaint = Paint()..blendMode = BlendMode.dstIn;
      canvas.saveLayer(Offset.zero & size, dstInPaint);
      maskTP.paint(canvas, letterOffset);
      canvas.restore(); // apply dstIn

      canvas.restore(); // merge clipped strokes onto main canvas
    }
  }

  @override
  bool shouldRepaint(_ProgressiveLetterPainter old) =>
      old.points.length != points.length || old.letter != letter;
}
