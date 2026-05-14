import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';

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
  int _round = 1;
  static const int _totalRounds = 5;

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
    _wrongFlashNumber = null;
    _wrongFlashDots = null;
  }

  Future<void> _onDropped(int droppedValue, int targetValue) async {
    if (_matchedNumbers.contains(droppedValue)) return;

    if (droppedValue == targetValue) {
      // ✅ Correct match
      setState(() => _matchedNumbers.add(droppedValue));

      if (_matchedNumbers.length == _roundNumbers.length) {
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
      // ❌ Wrong match — flash both cards
      setState(() {
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
        backgroundColor: ArcticColorTheme.cotton,
        title: Text(
          '🌟 Amazing!',
          style: const TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ArcticColorTheme.cadetblue,
          ),
        ),
        content: Text(
          'You did well!',
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
                _round = 1;
                _startRound();
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

  // ── Color helpers ─────────────────────────────────────────────────────────

  // Number card (draggable): default → pictonblue | matched → lightblue | wrong → cadetblue
  Color _numberCardColor(int value) {
    if (_matchedNumbers.contains(value)) return ArcticColorTheme.lightblue;
    if (_wrongFlashNumber == value) return ArcticColorTheme.cadetblue;
    return ArcticColorTheme.pictonblue;
  }

  Color _numberCardBorderColor(int value) {
    if (_matchedNumbers.contains(value)) return ArcticColorTheme.pictonblue;
    if (_wrongFlashNumber == value) return ArcticColorTheme.slateblue;
    return ArcticColorTheme.slateblue;
  }

  // Dot card (target): default fill → cotton | matched → green | wrong → red
  Color _dotCardFillColor(int value) {
    if (_matchedNumbers.contains(value)) return Colors.green;
    if (_wrongFlashDots == value) return Colors.red;
    return ArcticColorTheme.cotton;
  }

  Color _dotCardBorderColor(int value) {
    if (_matchedNumbers.contains(value)) return ArcticColorTheme.pictonblue;
    if (_wrongFlashDots == value) return ArcticColorTheme.slateblue;
    return ArcticColorTheme.pictonblue;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                    'Number Matching',
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
                        horizontal: 16,
                        vertical: 6,
                      ),
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

            const SizedBox(height: 3),

            // --- PROMPT ---
            const Text(
              'Drag the number to its matching dots!',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 20,
                color: ArcticColorTheme.slateblue,
              ),
            ),

            const SizedBox(height: 5),

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
                    color: ArcticColorTheme.slateblue,
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
    final borderColor = _numberCardBorderColor(value);

    final cardChild = Padding(
      padding: const EdgeInsets.all(10),
      child: Image.asset(
        'assets/fonts/game_numbers/$value.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            '$value',
            style: const TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: ArcticColorTheme.cotton,
            ),
          ),
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 85,
      height: 72,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isMatched
          ? cardChild
          : Draggable<int>(
        data: value,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 100,
            height: 90,
            decoration: BoxDecoration(
              color: ArcticColorTheme.pictonblue,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/fonts/game_numbers/$value.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    '$value',
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
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: Container(
            width: 85,
            height: 72,
            decoration: BoxDecoration(
              color: ArcticColorTheme.pictonblue,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: ArcticColorTheme.slateblue,
                width: 3,
              ),
            ),
            child: cardChild,
          ),
        ),
        child: cardChild,
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
            ? ArcticColorTheme.lightblue
            : isHovering
            ? ArcticColorTheme.pictonblue.withValues(alpha: 0.2)
            : _dotCardFillColor(value);
        final borderColor = isHovering
            ? ArcticColorTheme.pictonblue
            : _dotCardBorderColor(value);

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
                color: borderColor.withValues(alpha: 0.3),
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
                    color: isMatched
                        ? ArcticColorTheme.cotton
                        : ArcticColorTheme.slateblue,
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