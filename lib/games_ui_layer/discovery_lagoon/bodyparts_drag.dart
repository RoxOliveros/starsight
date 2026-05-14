import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- GENERIC THEME (Replace later when you design the new map!) ---
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // This makes the word bob up and down continuously
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _showSuccessDialog() {
    bool isLast = _currentIndex == _parts.length - 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Awesome!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.success,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "You matched the ${_parts[_currentIndex].word}!",
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 22,
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
              style: const TextStyle(
                color: ColorTheme.accent,
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
    final currentPart = _parts[_currentIndex];

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
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: ColorTheme.primary, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.0,
                                child: _WordWidget(
                                  word: currentPart.word,
                                  color: ColorTheme.primary,
                                ),
                              ),
                              child: _WordWidget(
                                word: currentPart.word,
                                color: ColorTheme.primary,
                              ),
                            ),
                          )
                        else
                          const SizedBox(
                            width: 150,
                          ), // Empty space when matched

                        DragTarget<String>(
                          onWillAcceptWithDetails: (details) {
                            return details.data ==
                                currentPart.word; // Only accept the exact word!
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isHovering
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: ColorTheme.textDark.withOpacity(0.2),
                                  width: 4,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Center(
                                child: _isMatched
                                    ? _WordWidget(
                                        word: currentPart.word,
                                        color: ColorTheme.success,
                                      )
                                    : _WordWidget(
                                        word: currentPart.word,
                                        color: ColorTheme.textDark.withOpacity(
                                          0.15,
                                        ),
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

// A reusable widget designed specifically for full words
class _WordWidget extends StatelessWidget {
  final String word;
  final Color color;
  final bool isDragging;

  const _WordWidget({
    required this.word,
    required this.color,
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
            fontSize: 60, // Shrunk so long words fit perfectly
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.0,
            shadows: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
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
