import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8);
  static const Color deepNavyBlue = Color(0xFF5E463E);
  static const Color orange = Color(0xFFEC8A20);
  static const Color green = Color(0xFF82C84B);
  static const Color lightBlue = Color(0xFF75D5FF);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class AlphabetDragScreen extends StatefulWidget {
  const AlphabetDragScreen({super.key});

  @override
  State<AlphabetDragScreen> createState() => _AlphabetDragScreenState();
}

class _AlphabetDragScreenState extends State<AlphabetDragScreen>
    with SingleTickerProviderStateMixin {
  bool _isMatched = false;
  late final AnimationController _floatingController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // This makes the letter bob up and down continuously!
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
          "You dragged it perfectly!",
          style: TextStyle(fontFamily: AppTextStyles.fredoka, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isMatched = false; // Reset for the next round
              });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
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
                    'Drag the Letter',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.deepNavyBlue,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // --- 1. THE FLOATING DRAGGABLE LETTER ---
                    if (!_isMatched)
                      AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.translate(
                            // Moves the letter up and down by 15 pixels
                            offset: Offset(0, -15 * _floatingController.value),
                            child: child,
                          );
                        },
                        child: Draggable<String>(
                          data: 'B', // The secret data we are passing
                          feedback: const _LetterWidget(
                            letter: 'B',
                            color: ColorTheme.lightBlue,
                            isDragging: true,
                          ),
                          childWhenDragging: const Opacity(
                            opacity: 0.0,
                            child: _LetterWidget(
                              letter: 'B',
                              color: ColorTheme.lightBlue,
                            ),
                          ),
                          child: const _LetterWidget(
                            letter: 'B',
                            color: ColorTheme.lightBlue,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 150), // Empty space when matched
                    // --- 2. THE TARGET (THE SHADOW) ---
                    DragTarget<String>(
                      onWillAcceptWithDetails: (details) {
                        return details.data == 'B'; // Only accept a 'B'!
                      },
                      onAcceptWithDetails: (details) {
                        setState(() {
                          _isMatched = true;
                        });
                        // Add a tiny delay so they see it snap into place before the dialog pops up
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _showSuccessDialog();
                        });
                      },
                      builder: (context, candidateData, rejectedData) {
                        // If they hover over it, make it glow slightly
                        bool isHovering = candidateData.isNotEmpty;

                        return Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: isHovering
                                ? Colors.white.withOpacity(0.5)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: ColorTheme.deepNavyBlue.withOpacity(0.2),
                              width: 4,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Center(
                            child: _isMatched
                                ? const _LetterWidget(
                                    letter: 'B',
                                    color: ColorTheme.lightBlue,
                                  ) // Show solid letter when won
                                : _LetterWidget(
                                    letter: 'B',
                                    color: ColorTheme.deepNavyBlue.withOpacity(
                                      0.15,
                                    ),
                                  ), // Show faint shadow initially
                          ),
                        );
                      },
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

// A reusable widget to draw the letter so our code stays clean!
class _LetterWidget extends StatelessWidget {
  final String letter;
  final Color color;
  final bool isDragging;

  const _LetterWidget({
    required this.letter,
    required this.color,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        // Make it slightly bigger while they are dragging it
        scale: isDragging ? 1.2 : 1.0,
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 150,
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
