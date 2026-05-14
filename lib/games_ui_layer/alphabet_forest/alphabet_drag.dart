import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          "You dragged it perfectly!",
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
              setState(() {
                _isMatched = false;
              });
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
                children: const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ForestBackButton(),
                  ),
                  Text(
                    'Drag the Letter',
                    style: TextStyle(
                      fontFamily: ForestAppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ForestColorTheme.darkseagreen,
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
                            offset: Offset(0, -15 * _floatingController.value),
                            child: child,
                          );
                        },
                        child: Draggable<String>(
                          data: 'B',
                          feedback: const _LetterWidget(
                            letter: 'B',
                            color: ForestColorTheme.seagreen,
                            isDragging: true,
                          ),
                          childWhenDragging: const Opacity(
                            opacity: 0.0,
                            child: _LetterWidget(
                              letter: 'B',
                              color: ForestColorTheme.seagreen,
                            ),
                          ),
                          child: const _LetterWidget(
                            letter: 'B',
                            color: ForestColorTheme.seagreen,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 150),

                    // --- 2. THE TARGET (THE SHADOW) ---
                    DragTarget<String>(
                      onWillAcceptWithDetails: (details) {
                        return details.data == 'B';
                      },
                      onAcceptWithDetails: (details) {
                        setState(() {
                          _isMatched = true;
                        });
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _showSuccessDialog();
                        });
                      },
                      builder: (context, candidateData, rejectedData) {
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
                              color: ForestColorTheme.darkseagreen.withOpacity(
                                0.2,
                              ),
                              width: 4,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Center(
                            child: _isMatched
                                ? const _LetterWidget(
                                    letter: 'B',
                                    color: ForestColorTheme.seagreen,
                                  )
                                : _LetterWidget(
                                    letter: 'B',
                                    color: ForestColorTheme.darkseagreen
                                        .withOpacity(0.15),
                                  ),
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
        scale: isDragging ? 1.2 : 1.0,
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
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
