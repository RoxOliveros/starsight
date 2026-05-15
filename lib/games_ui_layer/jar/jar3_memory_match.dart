import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/jar/jar_buttons.dart';
import '../../ui_layer/jar/jar_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

/// All available object assets (filename without extension).
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

/// How many pairs per round (keep small = easier for toddlers).
const _kPairsPerRound = 3; // 6 cards total

/// How long the wrong pair stays visible before flipping back.
const _kPeekDuration = Duration(milliseconds: 1400);

/// Total rounds before the end dialog.
const _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Card model
// ─────────────────────────────────────────────────────────────────────────────

class _CardModel {
  final int id;          // unique per card
  final int pairId;      // shared by the two matching cards
  final String object;   // asset name

  bool isFaceUp = false;
  bool isMatched = false;

  _CardModel({required this.id, required this.pairId, required this.object});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class JarMemoryMatchScreen extends StatefulWidget {
  const JarMemoryMatchScreen({super.key});

  @override
  State<JarMemoryMatchScreen> createState() => _JarMemoryMatchScreenState();
}

class _JarMemoryMatchScreenState extends State<JarMemoryMatchScreen>
    with TickerProviderStateMixin {

  // ── State ───────────────────────────────────────────────────────────────────

  int _round = 1;
  late List<_CardModel> _cards;

  /// At most 2 cards can be "peeked" (face-up but not yet matched).
  final List<int> _peekedIds = [];

  bool _locked = false;      // blocks taps while evaluating a pair
  bool _roundComplete = false;

  int _matchesFound = 0;

  // ── Animations ──────────────────────────────────────────────────────────────

  /// One AnimationController per card for the flip animation.
  List<AnimationController> _flipCtrls = [];
  List<Animation<double>> _flipAnims = [];

  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  late AnimationController _celebCtrl;
  late Animation<double> _celebAnim;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _celebAnim = CurvedAnimation(parent: _celebCtrl, curve: Curves.elasticOut);

    _buildRound();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _enterCtrl.dispose();
    _celebCtrl.dispose();
    for (final c in _flipCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Round setup ─────────────────────────────────────────────────────────────

  void _buildRound() {
    final rng = Random();

    // Pick N distinct objects
    final pool = List<String>.from(_kAllObjects)..shuffle(rng);
    final chosen = pool.take(_kPairsPerRound).toList();

    // Create pairs
    final rawCards = <_CardModel>[];
    for (int i = 0; i < chosen.length; i++) {
      rawCards.add(_CardModel(id: i * 2,     pairId: i, object: chosen[i]));
      rawCards.add(_CardModel(id: i * 2 + 1, pairId: i, object: chosen[i]));
    }
    rawCards.shuffle(rng);
    _cards = rawCards;

    // Per-card flip controllers (0 = face-down, 1 = face-up)
    for (final c in _flipCtrls) {
      c.dispose();
    }
    _flipCtrls = List.generate(
      _cards.length,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    _flipAnims = _flipCtrls.map((ctrl) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
    }).toList();

    _peekedIds.clear();
    _locked = false;
    _roundComplete = false;
    _matchesFound = 0;
    _celebCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Tap logic ───────────────────────────────────────────────────────────────

  Future<void> _onCardTap(int cardIndex) async {
    if (_locked || _roundComplete) return;

    final card = _cards[cardIndex];
    if (card.isFaceUp || card.isMatched) return;

    // Flip card face-up
    setState(() {
      card.isFaceUp = true;
      _peekedIds.add(cardIndex);
    });
    _flipCtrls[cardIndex].forward();

    if (_peekedIds.length < 2) return; // wait for second tap

    // Two cards are now peeked — evaluate
    _locked = true;
    final idxA = _peekedIds[0];
    final idxB = _peekedIds[1];
    final cardA = _cards[idxA];
    final cardB = _cards[idxB];

    if (cardA.pairId == cardB.pairId) {
      // ✅ Match!
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        cardA.isMatched = true;
        cardB.isMatched = true;
        _peekedIds.clear();
        _matchesFound++;
        _locked = false;
      });

      if (_matchesFound == _kPairsPerRound) {
        // Round complete
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _roundComplete = true);
        _celebCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 1200));

        if (_round >= _kTotalRounds) {
          _showEndDialog();
        } else {
          await _enterCtrl.reverse();
          setState(() {
            _round++;
            _buildRound();
          });
        }
      }
    } else {
      // ❌ No match — let them peek, then flip back
      await Future.delayed(_kPeekDuration);
      setState(() {
        cardA.isFaceUp = false;
        cardB.isFaceUp = false;
        _peekedIds.clear();
      });
      _flipCtrls[idxA].reverse();
      _flipCtrls[idxB].reverse();
      await Future.delayed(const Duration(milliseconds: 400));
      _locked = false;
    }
  }

  // ── End dialog ──────────────────────────────────────────────────────────────

  void _showEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: JarColorTheme.vandecane,
        title: const Text(
          '🧠 Memory Star!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: JarColorTheme.verydarkdesaturatedblue,
          ),
        ),
        content: const Text(
          'You matched all the cards!',
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
                _buildRound();
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
              const SizedBox(height: 16),
              Expanded(child: _buildCardGrid()),
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
            'Memory Match',
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
      _roundComplete
          ? '🎉 You found them all!'
          : 'Find the matching pairs!',
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

  // ── Card grid ───────────────────────────────────────────────────────────────

  Widget _buildCardGrid() {
    // 3 pairs = 6 cards → 2 rows × 3 cols
    return Center(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: List.generate(_cards.length, (i) => _buildCard(i)),
      ),
    );
  }

  Widget _buildCard(int index) {
    final card = _cards[index];
    final anim = _flipAnims[index];

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          // First half of flip shows back, second half shows front
          final showFront = anim.value >= 0.5;
          final angle = showFront
              ? (anim.value - 1.0) * pi // 0 at value=1
              : anim.value * pi;        // 0 at value=0

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            child: showFront
                ? _cardFront(card)
                : _cardBack(),
          );
        },
      ),
    );
  }

  // ── Card faces ──────────────────────────────────────────────────────────────

  Widget _cardBack() {
    return _cardShell(
      color: JarColorTheme.vandecane,
      borderColor: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.35),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle star watermark
          Image.asset(
            'assets/images/star_bnw.png',
            width: 44,
            height: 44,
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.12),
            colorBlendMode: BlendMode.modulate,
          ),
          const Text(
            '?',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: JarColorTheme.sunnyhue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardFront(_CardModel card) {
    return _cardShell(
      color: card.isMatched
          ? JarColorTheme.goldenyellow.withValues(alpha: 0.30)
          : JarColorTheme.vandecane,
      borderColor: card.isMatched
          ? JarColorTheme.sunnyhue
          : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.25),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/objects/${card.object}.png',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
          if (card.isMatched)
            Positioned(
              top: 6,
              right: 6,
              child: ScaleTransition(
                scale: _celebAnim,
                child: const Text('⭐', style: TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardShell({
    required Color color,
    required Color borderColor,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kTotalRounds, (i) {
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