import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlphabetMemoryMatchScreen extends StatefulWidget {
  const AlphabetMemoryMatchScreen({super.key});

  @override
  State<AlphabetMemoryMatchScreen> createState() =>
      _AlphabetMemoryMatchScreenState();
}

class _AlphabetMemoryMatchScreenState extends State<AlphabetMemoryMatchScreen> {
  final List<String> _cards = ['A', 'B', 'C', 'D', 'a', 'b', 'c', 'd'];
  List<bool> _cardFllipped = List.filled(8, false);
  List<bool> _cardMatched = List.filled(8, false);

  int? _firstSelectedIndex;
  bool _waitTimer = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _cards.shuffle();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  void _onCardTap(int index) {
    if (_waitTimer || _cardFllipped[index] || _cardMatched[index]) return;

    setState(() {
      _cardFllipped[index] = true;
    });

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = index;
    } else {
      _waitTimer = true;
      int first = _firstSelectedIndex!;

      if (_cards[first].toLowerCase() == _cards[index].toLowerCase()) {
        setState(() {
          _cardMatched[first] = true;
          _cardMatched[index] = true;
          _firstSelectedIndex = null;
          _waitTimer = false;
        });

        if (_cardMatched.every((m) => m)) _showSuccessDialog();
      } else {
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
          "You found all the pairs!",
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
                _cards.shuffle();
                _cardFllipped = List.filled(8, false);
                _cardMatched = List.filled(8, false);
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
                    'Memory Match',
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double horizontalPadding = 80.0;
                  double verticalPadding = 20.0;
                  double spacing = 16.0;

                  double cellWidth =
                      (constraints.maxWidth -
                          horizontalPadding -
                          (spacing * 3)) /
                      4;
                  double cellHeight =
                      (constraints.maxHeight - verticalPadding - spacing) / 2;
                  double calculatedAspectRatio = cellWidth / cellHeight;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding / 2,
                      vertical: verticalPadding / 2,
                    ),
                    child: GridView.builder(
                      physics:
                          const NeverScrollableScrollPhysics(), // Disables scrolling entirely!
                      itemCount: 8,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio:
                            calculatedAspectRatio, // Applies the perfect fit calculation
                      ),
                      itemBuilder: (context, index) {
                        bool showFace =
                            _cardFllipped[index] || _cardMatched[index];

                        return GestureDetector(
                          onTap: () => _onCardTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                showFace ? 1.0 : 0.4,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: showFace
                                    ? ForestColorTheme.lightgreen
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/star.png',
                                  color: showFace
                                      ? ForestColorTheme.mediumseagreen
                                            .withOpacity(0.2)
                                      : null,
                                  fit: BoxFit.contain,
                                ),
                                if (showFace)
                                  Text(
                                    _cards[index],
                                    style: TextStyle(
                                      fontFamily: ForestAppTextStyles.fredoka,
                                      fontSize:
                                          cellHeight *
                                          0.5, // Font scales with the card height
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _cards[index] ==
                                              _cards[index].toUpperCase()
                                          ? ForestColorTheme.mediumseagreen
                                          : ForestColorTheme.seagreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
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
