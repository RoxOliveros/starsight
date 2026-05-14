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

class AlphabetMemoryMatchScreen extends StatefulWidget {
  const AlphabetMemoryMatchScreen({super.key});

  @override
  State<AlphabetMemoryMatchScreen> createState() =>
      _AlphabetMemoryMatchScreenState();
}

class _AlphabetMemoryMatchScreenState extends State<AlphabetMemoryMatchScreen> {
  // 1. Setup the Board Data
  final List<String> _cards = ['A', 'B', 'C', 'D', 'a', 'b', 'c', 'd'];
  List<bool> _cardFllipped = List.filled(8, false);
  List<bool> _cardMatched = List.filled(8, false);

  int? _firstSelectedIndex;
  bool _waitTimer = false; // Prevents tapping 3 cards at once

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _cards.shuffle(); // Shuffle every time they play!
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onCardTap(int index) {
    if (_waitTimer || _cardFllipped[index] || _cardMatched[index]) return;

    setState(() {
      _cardFllipped[index] = true;
    });

    if (_firstSelectedIndex == null) {
      // First card flipped
      _firstSelectedIndex = index;
    } else {
      // Second card flipped - Check for match!
      _waitTimer = true;
      int first = _firstSelectedIndex!;

      // Logic: A matches a, B matches b, etc.
      if (_cards[first].toLowerCase() == _cards[index].toLowerCase()) {
        // MATCH FOUND!
        setState(() {
          _cardMatched[first] = true;
          _cardMatched[index] = true;
          _firstSelectedIndex = null;
          _waitTimer = false;
        });

        if (_cardMatched.every((m) => m)) _showSuccessDialog();
      } else {
        // NO MATCH - Flip them back after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _cardFllipped[first] = false;
              _cardFllipped[index] = false;
              _firstSelectedIndex = null;
              _waitTimer = false;
            });
          }
        });
      }
    }
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
          "You found all the pairs!",
          style: TextStyle(fontFamily: AppTextStyles.fredoka, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cards.shuffle();
                _cardFllipped = List.filled(8, false);
                _cardMatched = List.filled(8, false);
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40.0,
                  vertical: 20.0,
                ),
                child: GridView.builder(
                  itemCount: 8,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) {
                    bool showFace = _cardFllipped[index] || _cardMatched[index];

                    return GestureDetector(
                      onTap: () => _onCardTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(showFace ? 1.0 : 0.4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // The Star Background
                            Image.asset(
                              'assets/images/star.png',
                              color: showFace
                                  ? ColorTheme.goldenYellow.withOpacity(0.3)
                                  : null,
                              fit: BoxFit.contain,
                            ),
                            // The Letter (Only shows if flipped or matched)
                            if (showFace)
                              Text(
                                _cards[index],
                                style: TextStyle(
                                  fontFamily: AppTextStyles.fredoka,
                                  fontSize: 60,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _cards[index] ==
                                          _cards[index].toUpperCase()
                                      ? ColorTheme.goldenYellow
                                      : ColorTheme.lightBlue,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
