import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- COLOR & FONT THEMES (Reusing your StarSight themes) ---
abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8); // Light blue grid background
  static const Color deepNavyBlue = Color(0xFF5E463E); // Brown text outline
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

// --- DATA MODEL FOR A CARD ---
class MemoryCard {
  final int id;
  final String imageAsset; // e.g., 'assets/images/Big_A.jpg'
  final String matchKey; // e.g., 'A' (Used to check if Big_A matches Small_a)
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.imageAsset,
    required this.matchKey,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

// --- THE GAME SCREEN ---
class AlphabetMatchScreen extends StatefulWidget {
  const AlphabetMatchScreen({super.key});

  @override
  State<AlphabetMatchScreen> createState() => _AlphabetMatchScreenState();
}

class _AlphabetMatchScreenState extends State<AlphabetMatchScreen> {
  // The list of cards currently on the board
  List<MemoryCard> _cards = [];

  // Keeps track of the cards the child just tapped
  List<int> _flippedCardIndices = [];

  // Prevents the child from tapping rapidly while cards are flipping back
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeGame();
  }

  @override
  void dispose() {
    // Unlock the orientation when they leave the game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _initializeGame() {
    List<MemoryCard> initialCards = [
      MemoryCard(
        id: 1,
        imageAsset: 'assets/fonts/game_letters/Big_A.png',
        matchKey: 'A',
      ),
      MemoryCard(
        id: 2,
        imageAsset: 'assets/fonts/game_letters/Small_a.png',
        matchKey: 'A',
      ),
      MemoryCard(
        id: 3,
        imageAsset: 'assets/fonts/game_letters/Big_B.png',
        matchKey: 'B',
      ),
      MemoryCard(
        id: 4,
        imageAsset: 'assets/fonts/game_letters/Small_b.png',
        matchKey: 'B',
      ),
      MemoryCard(
        id: 5,
        imageAsset: 'assets/fonts/game_letters/Big_C.png',
        matchKey: 'C',
      ),
      MemoryCard(
        id: 6,
        imageAsset: 'assets/fonts/game_letters/Small_c.png',
        matchKey: 'C',
      ),
      MemoryCard(
        id: 7,
        imageAsset: 'assets/fonts/game_letters/Big_D.png',
        matchKey: 'D',
      ),
      MemoryCard(
        id: 8,
        imageAsset: 'assets/fonts/game_letters/Small_d.png',
        matchKey: 'D',
      ),
    ];

    initialCards.shuffle();

    setState(() {
      _cards = initialCards;
      _flippedCardIndices = [];
      _isProcessing = false;
    });
  }

  void _onCardTap(int index) async {
    // Ignore tap if processing, already flipped, or already matched
    if (_isProcessing || _cards[index].isFlipped || _cards[index].isMatched) {
      return;
    }

    setState(() {
      _cards[index].isFlipped = true;
      _flippedCardIndices.add(index);
    });

    // If they flipped 2 cards, check for a match
    if (_flippedCardIndices.length == 2) {
      _isProcessing = true; // Lock the board
      await _checkForMatch();
    }
  }

  Future<void> _checkForMatch() async {
    int index1 = _flippedCardIndices[0];
    int index2 = _flippedCardIndices[1];

    if (_cards[index1].matchKey == _cards[index2].matchKey) {
      // MATCH FOUND!
      setState(() {
        _cards[index1].isMatched = true;
        _cards[index2].isMatched = true;
      });
      _checkWinCondition();
    } else {
      // NOT A MATCH! Wait 2 seconds so the child can memorize them, then flip back
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _cards[index1].isFlipped = false;
          _cards[index2].isFlipped = false;
        });
      }
    }

    // Unlock the board for the next turn
    setState(() {
      _flippedCardIndices.clear();
      _isProcessing = false;
    });
  }

  void _checkWinCondition() {
    // If every single card is matched, they win!
    bool hasWon = _cards.every((card) => card.isMatched);
    if (hasWon) {
      // Show a victory dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            "You did it! 🌟",
            style: TextStyle(fontFamily: AppTextStyles.fredoka),
          ),
          content: const Text("You matched all the letters!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _initializeGame(); // Restart game
              },
              child: const Text("Play Again"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- HEADER ---
            Stack(
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: ColorTheme.deepNavyBlue,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Title
                const Center(
                  child: Text(
                    'Alphabet Match',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.deepNavyBlue,
                    ),
                  ),
                ),
              ],
            ),

            // --- THE GAME GRID ---
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double itemWidth = (constraints.maxWidth - (16 * 3)) / 4;
                      double itemHeight = (constraints.maxHeight - 16) / 2;
                      double dynamicRatio = itemWidth / itemHeight;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: dynamicRatio,
                        ),
                        itemCount: _cards.length,
                        itemBuilder: (context, index) {
                          final card = _cards[index];

                          return GestureDetector(
                            onTap: () => _onCardTap(index),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: card.isFlipped || card.isMatched
                                    ? Image.asset(
                                        card.imageAsset,
                                        key: ValueKey('front_$index'),
                                        fit: BoxFit.contain,
                                      )
                                    : Image.asset(
                                        'assets/images/star.png',
                                        key: ValueKey('back_$index'),
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
