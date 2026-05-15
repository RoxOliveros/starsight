import 'dart:math';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/jar/jar_buttons.dart';
import '../../ui_layer/jar/jar_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAllObjects = [
  'alarmclock',
  'ball',
  'car',
  'apple',
  'comb',
  'duck',
  'frame',
  'handsoap',
  'lamp',
  'plant',
  'rug',
  'stool',
  'teddybear',
  'toothbrush',
  'uniform',
  'wallframe',
];

const int _kChoices     = 3;
const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class JarShadowMatchScreen extends StatefulWidget {
  const JarShadowMatchScreen({super.key});

  @override
  State<JarShadowMatchScreen> createState() => _JarShadowMatchScreenState();
}

class _JarShadowMatchScreenState extends State<JarShadowMatchScreen>
    with TickerProviderStateMixin {

  // ── Round state ─────────────────────────────────────────────────────────────

  int _round = 1;

  late String _answerObject;
  late List<String> _choices;

  bool _wrongFlash    = false;
  bool _roundComplete = false;
  int? _tappedIndex;           // index inside _choices of last tap

  // ── Animations ──────────────────────────────────────────────────────────────

  /// Enter/exit fade for the whole screen between rounds.
  late AnimationController _enterCtrl;
  late Animation<double>   _enterAnim;

  /// Gentle pulse on the silhouette.
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  /// Bounce on the correct choice after a right answer.
  late AnimationController _bounceCtrl;
  late Animation<double>   _bounceAnim;

  /// Reveal: silhouette fades from black → full color on correct answer.
  late AnimationController _revealCtrl;
  late Animation<double>   _revealAnim;  // 0 = black silhouette, 1 = full color

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeIn);

    _startRound();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _bounceCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  // ── Round logic ─────────────────────────────────────────────────────────────

  void _startRound() {
    final rng      = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);

    _answerObject = shuffled[0];
    _choices      = shuffled.take(_kChoices).toList()..shuffle(rng);

    _wrongFlash    = false;
    _roundComplete = false;
    _tappedIndex   = null;

    _bounceCtrl.reset();
    _revealCtrl.reset();
    _pulseCtrl.repeat(reverse: true);   // restart pulse
    _enterCtrl.forward(from: 0);
  }

  Future<void> _onChoiceTapped(int index) async {
    if (_roundComplete || _wrongFlash) return;

    final tapped = _choices[index];

    if (tapped == _answerObject) {
      // ✅ Correct
      _pulseCtrl.stop();
      setState(() {
        _tappedIndex   = index;
        _roundComplete = true;
      });
      _bounceCtrl.forward(from: 0);
      _revealCtrl.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1200));

      if (_round >= _kTotalRounds) {
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
      setState(() {
        _tappedIndex = index;
        _wrongFlash  = true;
      });
      await Future.delayed(const Duration(milliseconds: 650));
      setState(() {
        _wrongFlash  = false;
        _tappedIndex = null;
      });
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
          '🔍 Shadow Expert!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: JarColorTheme.verydarkdesaturatedblue,
          ),
        ),
        content: const Text(
          'You matched every shadow!',
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

  // ── Build ───────────────────────────────────────────────────────────────────

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

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: JarBackButton()),
          const Text(
            'Shadow Match',
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

  // ── Prompt ──────────────────────────────────────────────────────────────────

  Widget _buildPrompt() {
    return Text(
      _roundComplete ? '🎉 You found it!' : 'Which one matches the shadow?',
      style: TextStyle(
        fontFamily: JarAppTextStyles.fredoka,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _roundComplete
            ? JarColorTheme.sunnyhue
            : JarColorTheme.verydarkdesaturatedblue,
      ),
    );
  }

  // ── Game area ───────────────────────────────────────────────────────────────

  Widget _buildGameArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSilhouetteCard(),
        const SizedBox(width: 40),
        _buildChoicesColumn(),
      ],
    );
  }

  // ── Silhouette ──────────────────────────────────────────────────────────────

  Widget _buildSilhouetteCard() {
    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        color: JarColorTheme.vandecane,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.35),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: JarColorTheme.goldenyellow.withValues(alpha: 0.15),
            blurRadius: 0,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Center(child: _buildSilhouetteImage()),
    );
  }

  Widget _buildSilhouetteImage() {
    // After correct: animate from black silhouette → full-color image
    if (_roundComplete) {
      return AnimatedBuilder(
        animation: _revealAnim,
        builder: (_, __) {
          // Interpolate: black (0,0,0) → white (255,255,255) tint
          // BlendMode.modulate: white = show original colors, black = black
          final tintValue = (_revealAnim.value * 255).round().clamp(0, 255);
          final tint = Color.fromARGB(255, tintValue, tintValue, tintValue);
          return Image.asset(
            'assets/images/objects/$_answerObject.png',
            width: 110,
            height: 110,
            color: tint,
            colorBlendMode: BlendMode.modulate,
          );
        },
      );
    }

    // Default: pulsing black silhouette
    return ScaleTransition(
      scale: _pulseAnim,
      child: Image.asset(
        'assets/images/objects/$_answerObject.png',
        width: 110,
        height: 110,
        color: JarColorTheme.verydarkdesaturatedblue.withValues(alpha: 0.85),
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }

  // ── Choices ─────────────────────────────────────────────────────────────────

  Widget _buildChoicesColumn() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_kChoices, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _buildChoiceButton(i),
        );
      }),
    );
  }

  Widget _buildChoiceButton(int index) {
    final object    = _choices[index];
    final isAnswer  = object == _answerObject;
    final isWrong   = _wrongFlash && _tappedIndex == index;
    final isCorrect = _roundComplete && isAnswer;

    Color borderColor = JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.28);
    Color bgColor     = JarColorTheme.vandecane;

    if (isWrong) {
      borderColor = const Color(0xFFE05A5A);
      bgColor     = const Color(0xFFE05A5A).withValues(alpha: 0.10);
    }
    if (isCorrect) {
      borderColor = JarColorTheme.sunnyhue;
      bgColor     = JarColorTheme.goldenyellow.withValues(alpha: 0.28);
    }

    Widget child = Image.asset(
      'assets/images/objects/$object.png',
      width: 60,
      height: 60,
      fit: BoxFit.contain,
      // Dim wrong choices slightly when round is complete
      color: (_roundComplete && !isAnswer)
          ? JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.25)
          : null,
      colorBlendMode: BlendMode.modulate,
    );

    if (isCorrect) {
      child = ScaleTransition(scale: _bounceAnim, child: child);
    }

    return GestureDetector(
      onTap: () => _onChoiceTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kTotalRounds, (i) {
        final done    = i + 1 < _round;
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