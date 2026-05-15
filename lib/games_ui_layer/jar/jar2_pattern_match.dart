import 'dart:math';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/jar/jar_buttons.dart';
import '../../ui_layer/jar/jar_theme.dart';

class JarPatternMatchScreen extends StatefulWidget {
  const JarPatternMatchScreen({super.key});

  @override
  State<JarPatternMatchScreen> createState() => _JarPatternMatchScreenState();
}

class _JarPatternMatchScreenState extends State<JarPatternMatchScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────

  static const int _totalRounds = 5;

  /// All available star colors (jarColor used as the tint).
  static const _allColors = [
    _StarColor(label: 'Red',    color: Color(0xFFE05A5A)),
    _StarColor(label: 'Blue',   color: Color(0xFF4C7FBE)),
    _StarColor(label: 'Green',  color: Color(0xFF5AAE6A)),
    _StarColor(label: 'Yellow', color: Color(0xFFF9AB19)),
    _StarColor(label: 'Purple', color: Color(0xFF9B6DC5)),
    _StarColor(label: 'Orange', color: Color(0xFFF07030)),
  ];

  /// Pattern templates: list of indices into a 2-color pair [A, B].
  /// The last element is the hidden "?" slot.
  static const _patternTemplates = [
    // AB patterns
    [0, 1, 0, 1, 0],   // A B A B A ?  → answer: B
    [0, 1, 0, 1, 1],   // A B A B B ?  → answer: A  (ABB end)
    // AAB patterns
    [0, 0, 1, 0, 0],   // A A B A A ?  → answer: B
    [0, 0, 1, 0, 1],   // A A B A B ?  → answer: wrong end, use next
    // ABB patterns
    [0, 1, 1, 0, 1],   // A B B A B ?  → answer: B
    [0, 1, 1, 0, 0],   // A B B A A ?  → answer: B  (ABB)
    // Simple AB
    [1, 0, 1, 0, 1],   // B A B A B ?  → answer: A
  ];

  // ── Round state ────────────────────────────────────────────────────────────

  int _round = 1;

  late List<_StarColor> _sequenceColors; // the visible stars (before "?")
  late _StarColor _answerColor;          // correct answer
  late List<_StarColor> _choices;        // tappable options (2–3)

  bool _wrongFlash = false;
  bool _rightFlash = false;
  bool _roundComplete = false;

  // ── Animations ─────────────────────────────────────────────────────────────

  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  late AnimationController _celebCtrl;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startRound();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _enterCtrl.dispose();
    _bounceCtrl.dispose();
    _celebCtrl.dispose();
    super.dispose();
  }

  // ── Round logic ────────────────────────────────────────────────────────────

  void _startRound() {
    final rng = Random();

    // Pick two distinct colors for A and B
    final shuffledColors = List<_StarColor>.from(_allColors)..shuffle(rng);
    final colorA = shuffledColors[0];
    final colorB = shuffledColors[1];
    final colorDecoy = shuffledColors[2]; // wrong-answer decoy

    // Pick a random pattern template
    final template =
    _patternTemplates[rng.nextInt(_patternTemplates.length)];

    // Build sequence (all but last element) and answer (last element)
    final pair = [colorA, colorB];
    _sequenceColors =
        template.sublist(0, template.length - 1).map((i) => pair[i]).toList();
    _answerColor = pair[template.last];

    // Build 2–3 choices that always include the correct answer
    final wrongChoice = (_answerColor == colorA) ? colorB : colorA;
    final includeDecoy = rng.nextBool(); // sometimes add a third option
    _choices = [_answerColor, wrongChoice, if (includeDecoy) colorDecoy]
      ..shuffle(rng);

    _wrongFlash = false;
    _rightFlash = false;
    _roundComplete = false;
    _celebCtrl.reset();
    _bounceCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  Future<void> _onChoiceTapped(_StarColor tapped) async {
    if (_roundComplete || _wrongFlash || _rightFlash) return;

    if (tapped == _answerColor) {
      // ✅ Correct
      setState(() {
        _rightFlash = true;
        _roundComplete = true;
      });
      _bounceCtrl.forward(from: 0);
      _celebCtrl.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1100));

      if (_round >= _totalRounds) {
        _showEndDialog();
      } else {
        await _enterCtrl.reverse();
        setState(() {
          _round++;
          _startRound();
        });
      }
    } else {
      // ❌ Wrong
      setState(() => _wrongFlash = true);
      await Future.delayed(const Duration(milliseconds: 700));
      setState(() => _wrongFlash = false);
    }
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: JarColorTheme.vandecane,
        title: const Text(
          '🌟 Pattern Pro!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: JarColorTheme.verydarkdesaturatedblue,
          ),
        ),
        content: const Text(
          'You found every missing star!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 20,
            color: JarColorTheme.darkdesaturatedblue,
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
                fontFamily: JarAppTextStyles.fredoka,
                fontSize: 20,
                color: JarColorTheme.sunnyhue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarColorTheme.lightgrayishyellow,
      body: SafeArea(
        child: FadeTransition(
          opacity: _enterAnim,
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHeader(),
              const SizedBox(height: 4),
              _buildPrompt(),
              const SizedBox(height: 12),
              Expanded(child: _buildGameArea()),
              _buildProgressDots(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: JarBackButton()),
          const Text(
            'Star Patterns',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: JarColorTheme.verydarkdesaturatedblue,
            ),
          ),
        ],
      ),
    );
  }

  // ── Prompt ─────────────────────────────────────────────────────────────────

  Widget _buildPrompt() {
    return Text(
      _roundComplete
          ? '🎉 That\'s right! Great job!'
          : 'What star comes next?',
      style: TextStyle(
        fontFamily: JarAppTextStyles.fredoka,
        fontSize: 22,
        color: _roundComplete
            ? JarColorTheme.sunnyhue
            : JarColorTheme.verydarkdesaturatedblue,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── Game area ──────────────────────────────────────────────────────────────

  Widget _buildGameArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSequenceRow(),
        const SizedBox(height: 24),
        _buildChoicesRow(),
      ],
    );
  }

  // ── Sequence row ───────────────────────────────────────────────────────────

  Widget _buildSequenceRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: JarColorTheme.vandecane,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
          JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.45),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: JarColorTheme.goldenyellow.withValues(alpha: 0.18),
            blurRadius: 0,
            spreadRadius: 3,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Known stars
          ..._sequenceColors.map(
                (c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _starWidget(c.color, 52),
            ),
          ),

          // Separator dash
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '→',
              style: TextStyle(
                fontSize: 28,
                color: JarColorTheme.darkdesaturatedblue
                    .withValues(alpha: 0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // "?" slot
          _buildQuestionSlot(),
        ],
      ),
    );
  }

  Widget _buildQuestionSlot() {
    // Once correct, show the answer star with bounce
    if (_roundComplete) {
      return ScaleTransition(
        scale: _bounceAnim,
        child: _starWidget(_answerColor.color, 58),
      );
    }

    // Else show animated pulsing "?" box
    return _PulseWidget(
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: JarColorTheme.goldenyellow.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: JarColorTheme.sunnyhue,
            width: 2.5,
          ),
        ),
        child: const Center(
          child: Text(
            '?',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: JarColorTheme.sunnyhue,
            ),
          ),
        ),
      ),
    );
  }

  // ── Choices row ────────────────────────────────────────────────────────────

  Widget _buildChoicesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _choices.map((choice) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildChoiceButton(choice),
        );
      }).toList(),
    );
  }

  Widget _buildChoiceButton(_StarColor choice) {
    final isAnswer = choice == _answerColor;
    final showWrong = _wrongFlash && !isAnswer;
    final showRight = _rightFlash && isAnswer;

    Color borderColor = JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.30);
    if (showWrong) borderColor = const Color(0xFFE05A5A);
    if (showRight) borderColor = JarColorTheme.sunnyhue;

    return GestureDetector(
      onTap: () => _onChoiceTapped(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: showRight
              ? JarColorTheme.goldenyellow.withValues(alpha: 0.35)
              : showWrong
              ? const Color(0xFFE05A5A).withValues(alpha: 0.12)
              : JarColorTheme.vandecane,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: choice.color.withValues(alpha: 0.20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _starWidget(
            showWrong
                ? JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.30)
                : choice.color,
            54,
          ),
        ),
      ),
    );
  }

  // ── Shared star widget ─────────────────────────────────────────────────────

  Widget _starWidget(Color tint, double size) {
    return Image.asset(
      'assets/images/star_bnw.png',
      width: size,
      height: size,
      color: tint,
      colorBlendMode: BlendMode.modulate,
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? JarColorTheme.darkdesaturatedblue
                : current
                ? JarColorTheme.sunnyhue
                : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PulseWidget — gently scales a child up/down on repeat
// ─────────────────────────────────────────────────────────────────────────────

class _PulseWidget extends StatefulWidget {
  final Widget child;
  const _PulseWidget({required this.child});

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _anim, child: widget.child);
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _StarColor {
  final String label;
  final Color color;

  const _StarColor({required this.label, required this.color});
}