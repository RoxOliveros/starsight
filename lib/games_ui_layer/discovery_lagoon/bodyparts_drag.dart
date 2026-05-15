import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';

abstract class ColorTheme {
  static const Color background = Color(0xFFE8F4F8);
  static const Color textDark = Color(0xFF5E463E);
  static const Color primary = Color(0xFF75D5FF);
  static const Color success = Color(0xFF82C84B);
  static const Color accent = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

// --- DATA MODEL FOR BODY PARTS ---
class BodyPart {
  final String word;
  final String imagePath;

  BodyPart({required this.word, required this.imagePath});
}

class BodyPartsDragScreen extends StatefulWidget {
  const BodyPartsDragScreen({super.key});

  @override
  State<BodyPartsDragScreen> createState() => _BodyPartsDragScreenState();
}

class _BodyPartsDragScreenState extends State<BodyPartsDragScreen>
    with SingleTickerProviderStateMixin {
  bool _isMatched = false;
  int _currentIndex = 0;
  late final AnimationController _floatingController;

  // The list of levels to play through!
  final List<BodyPart> _parts = [
    BodyPart(word: 'Paa', imagePath: 'assets/images/objects/feet.png'),
    BodyPart(word: 'Tuhod', imagePath: 'assets/images/objects/knee.png'),
    BodyPart(word: 'Balikat', imagePath: 'assets/images/objects/shoulder.png'),
    BodyPart(word: 'Ulo', imagePath: 'assets/images/objects/head.png'),
  ];

  @override
  void initState() {
    super.initState();

    OrientationService.setLandscape();

    // This makes the word bob up and down continuously
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _showSuccessDialog() {
    bool isLast = _currentIndex == _parts.length - 1;
    final Size screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Awesome!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.success,
            fontSize: screenSize.width * 0.04, // Responsive font
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "You matched the ${_parts[_currentIndex].word}!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: screenSize.width * 0.03, // Responsive font
            color: ColorTheme.textDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isMatched = false;
                if (isLast) {
                  _currentIndex = 0; // Restart if they finished all parts
                } else {
                  _currentIndex++; // Go to the next body part
                }
              });
            },
            child: Text(
              isLast ? "Play Again" : "Next Part",
              style: TextStyle(
                color: ColorTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: screenSize.width * 0.025,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPart = _parts[_currentIndex];
    final Size screenSize = MediaQuery.of(context).size;
    final double imageSize = screenSize.height * 0.40;
    final double wordFontSize = screenSize.width * 0.06;

    return Scaffold(
      backgroundColor: ColorTheme.background,
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
                        color: ColorTheme.textDark,
                        size: 32,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Body Parts',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // --- 1. THE IMAGE TO IDENTIFY ---
                    Container(
                      height: imageSize,
                      width: imageSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: ColorTheme.primary, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Image.asset(
                          currentPart.imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // --- 2. THE DRAG AND TARGET ROW ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // THE FLOATING DRAGGABLE WORD
                        if (!_isMatched)
                          AnimatedBuilder(
                            animation: _floatingController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  0,
                                  -10 * _floatingController.value,
                                ),
                                child: child,
                              );
                            },
                            child: Draggable<String>(
                              data: currentPart.word,
                              feedback: _WordWidget(
                                word: currentPart.word,
                                color: ColorTheme.primary,
                                isDragging: true,
                                fontSize: wordFontSize, // Passes universal math
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.0,
                                child: _WordWidget(
                                  word: currentPart.word,
                                  color: ColorTheme.primary,
                                  fontSize: wordFontSize,
                                ),
                              ),
                              child: _WordWidget(
                                word: currentPart.word,
                                color: ColorTheme.primary,
                                fontSize: wordFontSize,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: screenSize.width * 0.2,
                          ), // Shrinks space universally when matched
                        // THE TARGET BOX
                        DragTarget<String>(
                          onWillAcceptWithDetails: (details) {
                            return details.data ==
                                currentPart.word; // Only accept the exact word
                          },
                          onAcceptWithDetails: (details) {
                            setState(() {
                              _isMatched = true;
                            });
                            Future.delayed(
                              const Duration(milliseconds: 400),
                              () {
                                _showSuccessDialog();
                              },
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            bool isHovering = candidateData.isNotEmpty;

                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    screenSize.width *
                                    0.03, // Responsive padding
                                vertical: screenSize.height * 0.02,
                              ),
                              decoration: BoxDecoration(
                                color: isHovering
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: ColorTheme.textDark.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 4,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Center(
                                child: _isMatched
                                    ? _WordWidget(
                                        word: currentPart.word,
                                        color: ColorTheme.success,
                                        fontSize: wordFontSize,
                                      )
                                    : _WordWidget(
                                        word: currentPart.word,
                                        color: ColorTheme.textDark.withValues(
                                          alpha: 0.15,
                                        ),
                                        fontSize: wordFontSize,
                                      ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordWidget extends StatelessWidget {
  final String word;
  final Color color;
  final bool isDragging;
  final double fontSize;

  const _WordWidget({
    required this.word,
    required this.color,
    required this.fontSize,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: isDragging ? 1.1 : 1.0,
        child: Text(
          word,
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: fontSize, // No longer hardcoded to 60!
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.0,
            shadows: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
