import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color yelloworange = Color(0xFFFACC58);
  static const Color green = Color(0xFF82C84B);
  static const Color red = Color(0xFFE05C5C);
  static const Color brown = Color(0xFF5E463E);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class NumberMatchingScreen extends StatefulWidget {
  const NumberMatchingScreen({super.key});

  @override
  State<NumberMatchingScreen> createState() => _NumberMatchingScreenState();
}

class _NumberMatchingScreenState extends State<NumberMatchingScreen> {
  // Numbers used in this round (3 pairs)
  late List<int> _roundNumbers;

  // Stable shuffled orders — locked per round so setState doesn't re-shuffle
  late List<int> _numberCardOrder;
  late List<int> _dotCardOrder;

  // Tracks which values have been correctly matched
  final Set<int> _matchedNumbers = {};

  // Wrong-flash state
  int? _wrongFlashNumber;
  int? _wrongFlashDots;

  // Score tracking
  int _score = 0;
  int _round = 1;
  static const int _totalRounds = 5;
  bool _wrongThisRound = false;
  final List<bool?> _scoreHistory = List.filled(5, null);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startRound();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // ── Round logic ───────────────────────────────────────────────────────────

  void _startRound() {
    final all = [1, 2, 3, 4, 5]..shuffle();
    _roundNumbers = all.take(3).toList();
    _numberCardOrder = List<int>.from(_roundNumbers)..shuffle();
    _dotCardOrder = List<int>.from(_roundNumbers)..shuffle();
    _matchedNumbers.clear();
    _wrongThisRound = false;
    _wrongFlashNumber = null;
    _wrongFlashDots = null;
  }

  Future<void> _onDropped(int droppedValue, int targetValue) async {
    if (_matchedNumbers.contains(droppedValue)) return;

    if (droppedValue == targetValue) {
      // ✅ Correct match
      setState(() => _matchedNumbers.add(droppedValue));

      if (_matchedNumbers.length == _roundNumbers.length) {
        final correct = !_wrongThisRound;
        setState(() {
          _scoreHistory[_round - 1] = correct;
          if (correct) _score++;
        });

        await Future.delayed(const Duration(milliseconds: 700));

        if (_round >= _totalRounds) {
          _showEndDialog();
        } else {
          setState(() {
            _round++;
            _startRound();
          });
        }
      }
    } else {
      // ❌ Wrong match — flash both cards red
      setState(() {
        _wrongThisRound = true;
        _wrongFlashNumber = droppedValue;
        _wrongFlashDots = targetValue;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _wrongFlashNumber = null;
        _wrongFlashDots = null;
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
                _scoreHistory.fillRange(0, _totalRounds, null);
                _startRound();
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

  // ── Color helpers ─────────────────────────────────────────────────────────

  Color _numberCardColor(int value) {
    if (_matchedNumbers.contains(value)) return ColorTheme.green;
    if (_wrongFlashNumber == value) return ColorTheme.red;
    return ColorTheme.yelloworange;
  }

  Color _dotCardFillColor(int value) {
    if (_matchedNumbers.contains(value)) return ColorTheme.green;
    if (_wrongFlashDots == value) return ColorTheme.red;
    return Colors.white;
  }

  Color _dotCardBorderColor(int value) {
    if (_matchedNumbers.contains(value)) return ColorTheme.green;
    if (_wrongFlashDots == value) return ColorTheme.red;
    return ColorTheme.yelloworange;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                    'Number Matching',
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
                        horizontal: 16,
                        vertical: 6,
                      ),
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

            const SizedBox(height: 3),

            // --- PROMPT ---
            const Text(
              'Drag the number to its matching dots!',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 20,
                color: ColorTheme.deepNavyBlue,
              ),
            ),

            const SizedBox(height: 5),

            // --- SCORE DOTS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalRounds, (i) {
                Color color;
                if (_scoreHistory[i] == true) {
                  color = ColorTheme.green;
                } else if (_scoreHistory[i] == false) {
                  color = ColorTheme.red;
                } else {
                  color = Colors.grey.shade300;
                }
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                  ),
                );
              }),
            ),

            const SizedBox(height: 6),

            // --- MAIN GAME AREA ---
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT — Draggable number cards
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _numberCardOrder
                        .map(_buildDraggableNumberCard)
                        .toList(),
                  ),

                  // Center arrow hint
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: ColorTheme.deepNavyBlue,
                    size: 32,
                  ),

                  // RIGHT — DragTarget dot cards
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _dotCardOrder
                        .map(_buildDotTarget)
                        .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Draggable Number Card ─────────────────────────────────────────────────

  Widget _buildDraggableNumberCard(int value) {
    final isMatched = _matchedNumbers.contains(value);
    final bgColor = _numberCardColor(value);

    final numberText = Text(
      '$value',
      style: const TextStyle(
        fontFamily: AppTextStyles.fredoka,
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 85,
      height: 72,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: bgColor == ColorTheme.yelloworange
              ? ColorTheme.orange
              : bgColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isMatched
          ? Center(child: numberText)
          : Draggable<int>(
        data: value,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 100,
            height: 90,
            decoration: BoxDecoration(
              color: ColorTheme.orange,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(child: numberText),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: Container(
            width: 100,
            height: 90,
            decoration: BoxDecoration(
              color: ColorTheme.yelloworange,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ColorTheme.orange, width: 3),
            ),
            child: Center(child: numberText),
          ),
        ),
        child: Center(child: numberText),
      ),
    );
  }

  // ── Dot Target Card ───────────────────────────────────────────────────────

  Widget _buildDotTarget(int value) {
    final isMatched = _matchedNumbers.contains(value);

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
      !isMatched && !_matchedNumbers.contains(details.data),
      onAcceptWithDetails: (details) => _onDropped(details.data, value),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final bgColor = isMatched
            ? ColorTheme.green
            : isHovering
            ? ColorTheme.yellow.withOpacity(0.5)
            : _dotCardFillColor(value);
        final borderColor =
        isHovering ? ColorTheme.orange : _dotCardBorderColor(value);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 110,
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: isHovering ? 3.5 : 3,
            ),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 5,
              runSpacing: 5,
              children: List.generate(
                value,
                    (_) => Container(
                      width: 14,
                      height: 14,
                  decoration: BoxDecoration(
                    color: isMatched ? Colors.white : ColorTheme.deepNavyBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}