import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8);
  static const Color deepNavyBlue = Color(0xFF5E463E);
  static const Color orange = Color(0xFFEC8A20);
  static const Color green = Color(0xFF82C84B);
  static const Color lightBlue = Color(0xFF75D5FF);
  static const Color goldenYellow = Color(0xFFFBD481);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class AlphabetMatchScreen extends StatefulWidget {
  const AlphabetMatchScreen({super.key});

  @override
  State<AlphabetMatchScreen> createState() => _AlphabetMatchScreenState();
}

class _AlphabetMatchScreenState extends State<AlphabetMatchScreen>
    with SingleTickerProviderStateMixin {
  // Track which letters have been successfully matched
  final Set<String> _matchedLetters = {};
  final List<String> _allLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

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
          "You matched all the stars!",
          style: TextStyle(fontFamily: AppTextStyles.fredoka, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _matchedLetters.clear());
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
            const Text(
              'Alphabet Match',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: ColorTheme.deepNavyBlue,
              ),
            ),

            Expanded(
              child: Stack(
                children: [
                  // 1. THE STAR GRID (DragTargets)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40.0,
                      vertical: 20.0,
                    ),
                    child: GridView.builder(
                      itemCount: 8,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 1.2,
                          ),
                      itemBuilder: (context, index) {
                        String letter = _allLetters[index];
                        bool isMatched = _matchedLetters.contains(letter);

                        return DragTarget<String>(
                          onWillAcceptWithDetails: (details) =>
                              details.data == letter && !isMatched,
                          onAcceptWithDetails: (details) {
                            setState(() => _matchedLetters.add(letter));
                            if (_matchedLetters.length == 8)
                              _showSuccessDialog();
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // The Star Background
                                Image.asset(
                                  'assets/images/star.png',
                                  color: isMatched
                                      ? null
                                      : Colors.white.withOpacity(0.4),
                                  fit: BoxFit.contain,
                                ),
                                // The Letter (Fredoka Font)
                                Text(
                                  letter,
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.fredoka,
                                    fontSize: 50,
                                    fontWeight: FontWeight.bold,
                                    color: isMatched
                                        ? ColorTheme.goldenYellow
                                        : ColorTheme.deepNavyBlue.withOpacity(
                                            0.2,
                                          ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // 2. THE FLOATING LETTER TO DRAG
                  if (_matchedLetters.length < 8)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedBuilder(
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
                            // Get the next letter that hasn't been matched yet
                            data: _allLetters.firstWhere(
                              (l) => !_matchedLetters.contains(l),
                            ),
                            feedback: _DraggableLetter(
                              letter: _allLetters.firstWhere(
                                (l) => !_matchedLetters.contains(l),
                              ),
                            ),
                            childWhenDragging: const SizedBox.shrink(),
                            child: _DraggableLetter(
                              letter: _allLetters.firstWhere(
                                (l) => !_matchedLetters.contains(l),
                              ),
                            ),
                          ),
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

class _DraggableLetter extends StatelessWidget {
  final String letter;
  const _DraggableLetter({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: AppTextStyles.fredoka,
          fontSize: 80,
          fontWeight: FontWeight.bold,
          color: ColorTheme.lightBlue,
          shadows: [
            Shadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}
