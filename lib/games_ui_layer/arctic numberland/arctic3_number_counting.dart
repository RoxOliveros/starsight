import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';

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
        backgroundColor: ArcticColorTheme.cotton,
        title: Text(
          _score >= 4 ? '🌟 Amazing!' : '🎉 Good Try!',
          style: const TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ArcticColorTheme.cadetblue,
          ),
        ),
        content: Text(
          'You got $_score out of $_totalRounds!',
          style: const TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: 22,
            color: ArcticColorTheme.slateblue,
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
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 20,
                color: ArcticColorTheme.pictonblue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Unselected → pictonblue | correct → lightblue | wrong tap → cadetblue
  Color _choiceColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.pictonblue;
    if (_choices[index] == _correctCount) return ArcticColorTheme.lightblue;
    if (_tappedIndex == index) return ArcticColorTheme.cadetblue;
    return ArcticColorTheme.pictonblue;
  }

  Color _choiceBorderColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.slateblue;
    if (_choices[index] == _correctCount) return ArcticColorTheme.pictonblue;
    if (_tappedIndex == index) return ArcticColorTheme.slateblue;
    return ArcticColorTheme.slateblue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcticColorTheme.lightgrayishcyan,
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
                    child: ArcticBackButton(),
                  ),
                  const Text(
                    'Counting Objects',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ArcticColorTheme.cadetblue,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: ArcticColorTheme.pictonblue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_round / $_totalRounds',
                        style: const TextStyle(
                          fontFamily: ArcticAppTextStyles.fredoka,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ArcticColorTheme.cotton,
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
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 22,
                color: ArcticColorTheme.slateblue,
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
                      color: ArcticColorTheme.cotton,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: ArcticColorTheme.pictonblue, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: ArcticColorTheme.pictonblue.withValues(alpha: 0.3),
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
                                color: _choiceBorderColor(index),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _choiceColor(index).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Image.asset(
                                'assets/fonts/game_numbers/${_choices[index]}.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    '${_choices[index]}',
                                    style: const TextStyle(
                                      fontFamily: ArcticAppTextStyles.fredoka,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: ArcticColorTheme.cotton,
                                    ),
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