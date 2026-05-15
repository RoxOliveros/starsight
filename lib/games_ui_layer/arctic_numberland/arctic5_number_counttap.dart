import 'dart:math';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';

class TapCountScreen extends StatefulWidget {
  const TapCountScreen({super.key});

  @override
  State<TapCountScreen> createState() => _TapCountScreenState();
}

class _TapCountScreenState extends State<TapCountScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────

  static const int _totalRounds = 5;
  static const int _poolSize = 5;

  // One theme per number 1–5
  static const _themes = [
    _RoundTheme(
      asset: 'assets/images/objects/ball.png',
      label: 'ball',
      color: Color(0xFFFFC857),
    ),
    _RoundTheme(
      asset: 'assets/images/objects/car.png',
      label: 'car',
      color: Color(0xFFE84393),
    ),
    _RoundTheme(
      asset: 'assets/images/objects/lamp.png',
      label: 'lamp',
      color: Color(0xFF4FC3F7),
    ),
    _RoundTheme(
      asset: 'assets/images/objects/teddybear.png',
      label: 'bear',
      color: Color(0xFF81C784),
    ),
    _RoundTheme(
      asset: 'assets/images/objects/plant.png',
      label: 'plant',
      color: Color(0xFFFF8A65),
    ),
  ];

  // ── State ──────────────────────────────────────────────────────────────────

  int _round = 0; // index into _roundOrder
  late List<int> _roundOrder; // shuffled [1,2,3,4,5]

  int get _targetNumber => _roundOrder[_round];

  _RoundTheme get _theme => _themes[_targetNumber - 1];

  // Which of the 5 objects are selected
  late List<bool> _selected;

  // Submit feedback
  bool _submitFlashWrong = false;
  bool _submitFlashCorrect = false;
  bool _locked = false;

  // Animations
  late AnimationController _numberBounce;
  late Animation<double> _numberBounceAnim;

  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  late AnimationController _celebrationCtrl;

  late AnimationController _wrongShakeCtrl;
  late Animation<double> _wrongShakeAnim;

  // Object scale animations (one per object)
  late List<AnimationController> _objScaleCtrls;
  late List<Animation<double>> _objScaleAnims;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _roundOrder = [1, 2, 3, 4, 5]..shuffle(Random());

    _numberBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _numberBounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _numberBounce, curve: Curves.easeOut));

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _wrongShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wrongShakeAnim = Tween<double>(begin: 0, end: 1).animate(_wrongShakeCtrl);

    _initObjectAnimations();
    _startRound();
  }

  void _initObjectAnimations() {
    _objScaleCtrls = List.generate(
      _poolSize,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      ),
    );
    _objScaleAnims = _objScaleCtrls.map((ctrl) {
      return TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 60),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }).toList();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _numberBounce.dispose();
    _enterCtrl.dispose();
    _celebrationCtrl.dispose();
    _wrongShakeCtrl.dispose();
    for (final c in _objScaleCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Round logic ────────────────────────────────────────────────────────────

  void _startRound() {
    _selected = List.filled(_poolSize, false);
    _submitFlashWrong = false;
    _submitFlashCorrect = false;
    _locked = false;
    _celebrationCtrl.reset();
    _enterCtrl.forward(from: 0);
    _numberBounce.forward(from: 0);
  }

  int get _selectedCount => _selected.where((s) => s).length;

  void _onObjectTap(int index) {
    if (_locked) return;
    setState(() {
      _selected[index] = !_selected[index];
    });
    _objScaleCtrls[index].forward(from: 0);
  }

  Future<void> _onSubmit() async {
    if (_locked) return;
    _locked = true;

    if (_selectedCount == _targetNumber) {
      // ✅ Correct
      setState(() => _submitFlashCorrect = true);
      _celebrationCtrl.forward(from: 0);
      _numberBounce.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1000));

      if (_round + 1 >= _totalRounds) {
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
      setState(() => _submitFlashWrong = true);
      _wrongShakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 2000));
      _wrongShakeCtrl.reset();
      setState(() {
        _submitFlashWrong = false;
        _locked = false;
      });
    }
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: ArcticColorTheme.cotton,
        title: const Text(
          '🌟 You did it!',
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ArcticColorTheme.cadetblue,
          ),
        ),
        content: const Text(
          'You can count so well!',
          style: TextStyle(
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
                _round = 0;
                _roundOrder = [1, 2, 3, 4, 5]..shuffle(Random());
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcticColorTheme.lightgrayishcyan,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ── Header ──────────────────────────────────────────────────────
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
                    'Tap & Count',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ArcticColorTheme.cadetblue,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Prompt ──────────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _wrongShakeAnim,
              builder: (_, child) {
                final shake = sin(_wrongShakeAnim.value * pi * 5) * 6;
                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: child,
                );
              },
              child: Text(
                _submitFlashWrong
                    ? 'So close! Give it another try 🌟'
                    : _submitFlashCorrect
                    ? '🎉 Great job!'
                    : 'Tap $_targetNumber ${_theme.label}${_targetNumber > 1 ? 's' : ''}!',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: 20,
                  color: _submitFlashWrong
                      ? const Color(0xFFFFB347)
                      : ArcticColorTheme.cadetblue,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Main game area ───────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _enterAnim,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 20),

                    // LEFT — Number card
                    _buildNumberCard(),

                    const SizedBox(width: 24),

                    // Arrow
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: ArcticColorTheme.slateblue,
                      size: 32,
                    ),

                    const SizedBox(width: 24),

                    // RIGHT — Object grid + submit
                    Expanded(child: _buildObjectArea()),

                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),

            _buildProgressDots(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ── Number card (left) ─────────────────────────────────────────────────────

  Widget _buildNumberCard() {
    return ScaleTransition(
      scale: _numberBounceAnim,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: _submitFlashWrong
              ? const Color(0xFFFFB347)
              : ArcticColorTheme.cadetblue,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ArcticColorTheme.slateblue, width: 3),
          boxShadow: [
            BoxShadow(
              color: ArcticColorTheme.pictonblue.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            'assets/fonts/game_numbers/$_targetNumber.png',
            width: 70,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              '$_targetNumber',
              style: const TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: ArcticColorTheme.cotton,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Object grid + submit (right) ───────────────────────────────────────────

  Widget _buildObjectArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Counter badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: ArcticColorTheme.cotton,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ArcticColorTheme.pictonblue, width: 2),
          ),
          child: Text(
            '$_selectedCount / $_poolSize tapped',
            style: const TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 16,
              color: ArcticColorTheme.slateblue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Object row (5 objects)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_poolSize, _buildObjectTile),
        ),

        const SizedBox(height: 18),

        // Submit button
        GestureDetector(
          onTap: _onSubmit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
            decoration: BoxDecoration(
              color: _submitFlashWrong
                  ? const Color(0xFFFFB347)
                  : ArcticColorTheme.cadetblue,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ArcticColorTheme.cadetblue.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _submitFlashCorrect
                  ? '✓ Correct!'
                  : _submitFlashWrong
                  ? 'Try again! 💛'
                  : 'Submit',
              style: const TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ArcticColorTheme.cotton,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildObjectTile(int index) {
    final isSelected = _selected[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => _onObjectTap(index),
        child: ScaleTransition(
          scale: _objScaleAnims[index],
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: isSelected ? _theme.color : ArcticColorTheme.cotton,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? _theme.color : ArcticColorTheme.pictonblue,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? _theme.color.withValues(alpha: 0.45)
                      : ArcticColorTheme.pictonblue.withValues(alpha: 0.15),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    _theme.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.star_rounded,
                      color: isSelected ? Colors.white : _theme.color,
                      size: 36,
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _round;
        final current = i == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : current
                ? ArcticColorTheme.pictonblue
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RoundTheme {
  final String asset;
  final String label;
  final Color color;

  const _RoundTheme({
    required this.asset,
    required this.label,
    required this.color,
  });
}
