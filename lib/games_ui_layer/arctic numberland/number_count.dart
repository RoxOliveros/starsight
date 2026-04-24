import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yelloworange = Color(0xFFFACC58);
  static const Color green = Color(0xFF82C84B);
  static const Color red = Color(0xFFE05C5C);
  static const Color brown = Color(0xFF5E463E);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class CountingObjectsScreen extends StatefulWidget {
  const CountingObjectsScreen({super.key});

  @override
  State<CountingObjectsScreen> createState() => _CountingObjectsScreenState();
}

class _CountingObjectsScreenState extends State<CountingObjectsScreen> {
  late int _correctCount;
  late List<int> _choices;
  late String _currentObject;
  int? _tappedIndex;
  int _score = 0;
  int _round = 1;
  static const int _totalRounds = 5;

  // Add your own image asset paths here
  final List<Map<String, String>> _objects = [
    {'name': 'Apples', 'asset': 'assets/drafts/apple.png'},
    {'name': 'Balls', 'asset': 'assets/drafts/ball.png'},
    {'name': 'Stars', 'asset': 'assets/images/counting/star.png'},
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _generateRound();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _generateRound() {
    final allNumbers = [1, 2, 3, 4, 5]..shuffle();
    _correctCount = allNumbers.first;

    final wrong = allNumbers.skip(1).take(3).toList();
    _choices = [...wrong, _correctCount]..shuffle();

    final obj = (_objects..shuffle()).first;
    _currentObject = obj['asset']!;

    setState(() => _tappedIndex = null);
  }

  void _onChoiceTap(int index) async {
    if (_tappedIndex != null) return;
    setState(() => _tappedIndex = index);

    if (_choices[index] == _correctCount) _score++;

    await Future.delayed(const Duration(milliseconds: 900));

    if (_round >= _totalRounds) {
      _showEndDialog();
    } else {
      setState(() {
        _round++;
        _generateRound();
      });
    }
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          _score >= 4 ? '🌟 Amazing!' : '🎉 Good Try!',
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ColorTheme.brown,
          ),
        ),
        content: Text(
          'You got $_score out of $_totalRounds!',
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 22,
            color: ColorTheme.brown,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _score = 0;
                _round = 1;
                _generateRound();
              });
            },
            child: const Text(
              'Play Again',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 20,
                color: ColorTheme.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _choiceColor(int index) {
    if (_tappedIndex == null) return ColorTheme.yelloworange;
    if (_choices[index] == _correctCount) return ColorTheme.green;
    if (_tappedIndex == index) return ColorTheme.red;
    return ColorTheme.yelloworange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: ColorTheme.brown,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Counting Objects',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.brown,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: ColorTheme.yelloworange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_round / $_totalRounds',
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'How many are there?',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 22,
                color: ColorTheme.deepNavyBlue,
              ),
            ),

            const SizedBox(height: 8),

            // --- MAIN CONTENT ---
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // OBJECTS DISPLAY BOX
                  Container(
                    width: 340,
                    height: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: ColorTheme.yelloworange, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: ColorTheme.yelloworange.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildObjectGrid(),
                    ),
                  ),

                  // CHOICES
                  SizedBox(
                    width: 300,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: _choices.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _onChoiceTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: _choiceColor(index),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _choiceColor(index) ==
                                    ColorTheme.yelloworange
                                    ? ColorTheme.orange
                                    : _choiceColor(index),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  _choiceColor(index).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/fonts/game_numbers/{_choices[index]}.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Text(
                                  '${_choices[index]}',
                                  style: const TextStyle(
                                    fontFamily: AppTextStyles.fredoka,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectGrid() {
    // Arrange objects in a wrap layout
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: List.generate(_correctCount, (i) {
        return Image.asset(
          _currentObject,
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            '🍎',
            style: TextStyle(fontSize: 48),
          ),
        );
      }),
    );
  }
}