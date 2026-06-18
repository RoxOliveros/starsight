import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_level.dart';
import '../../ui_layer/puzzle_glade/Puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl20_copy_the_pattern2.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

enum _IntroPhase { playingIntro, playingWelcome, done }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAllObjects = [
  'compass',
  'jar',
  'lamp',
  'magnifying_glass',
  'map',
  'pen',
  'notebook',
  'puzzle_piece',
  'star',
  'telescope',
  'water_bottle',
];

const _kPairsPerRound = 4;
const _kPeekDuration = Duration(milliseconds: 1400);
const _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Card model
// ─────────────────────────────────────────────────────────────────────────────

class _CardModel {
  final int id;
  final int pairId;
  final String object;
  bool isFaceUp = false;
  bool isMatched = false;

  _CardModel({required this.id, required this.pairId, required this.object});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Lvl19JarMemoryMatch3Screen extends StatefulWidget {
  const Lvl19JarMemoryMatch3Screen({super.key});

  @override
  State<Lvl19JarMemoryMatch3Screen> createState() =>
      _Lvl19JarMemoryMatch3ScreenState();
}

class _Lvl19JarMemoryMatch3ScreenState extends State<Lvl19JarMemoryMatch3Screen>
    with TickerProviderStateMixin, RoxieReactionMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
  static const String _starImage = 'assets/images/objects/puzzle/star_bnw.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/level3/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level3/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level3/instruction.wav';
  static const String _audioCorrect =
      'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/level3/complete.wav';

  // ── Phase state ────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Game state ─────────────────────────────────────────────────────────────
  int _round = 1;
  late List<_CardModel> _cards;
  final List<int> _peekedIds = [];
  bool _locked = false;
  bool _roundComplete = false;
  int _matchesFound = 0;
  bool _showWinDialog = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer(); // intro, welcome, instructions
  final AudioPlayer _sfxPlayer = AudioPlayer(); // correct, success, complete
  final AudioPlayer _completePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _cardDanceCtrl;
  late Animation<double> _cardDance;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _celebCtrl;
  late Animation<double> _celebAnim;

  // Per-card flip
  List<AnimationController> _flipCtrls = [];
  List<Animation<double>> _flipAnims = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
  }

  @override
  void dispose() {
    _bgPlayer.dispose();
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _cardDanceCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _celebCtrl.dispose();
    for (final c in _flipCtrls) {
      c.dispose();
    }
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Animation init ─────────────────────────────────────────────────────────
  void _initAnimations() {
    _roxieFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _roxieSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _roxieSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut),
        );
    _roxieFade = CurvedAnimation(
      parent: _roxieSlideCtrl,
      curve: const Interval(0, 0.4),
    );

    _cardDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _cardDance = Tween<double>(
      begin: -0.07,
      end: 0.07,
    ).animate(CurvedAnimation(parent: _cardDanceCtrl, curve: Curves.easeInOut));

    _speechBubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

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
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();

    _setIntroPhase(_IntroPhase.playingIntro);
    _speechBubbleCtrl.forward(from: 0);
    await _playAudio(_audioIntro);

    _setIntroPhase(_IntroPhase.playingWelcome);
    _speechBubbleCtrl.forward(from: 0);
    await _playAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));

    _setIntroPhase(_IntroPhase.done);
    _gameEnterCtrl.forward();
    _buildRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
    await _playAudio(_audioInstructions);
  }

  Future<void> _playAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();

      sub = _bgPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      await _bgPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));

      await completer.future.timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  void _setIntroPhase(_IntroPhase p) {
    if (!mounted) return;
  }

  // ── Round setup ────────────────────────────────────────────────────────────
  void _buildRound() {
    final rng = Random();
    final pool = List<String>.from(_kAllObjects)..shuffle(rng);
    final chosen = pool.take(_kPairsPerRound).toList();

    final rawCards = <_CardModel>[];
    for (int i = 0; i < chosen.length; i++) {
      rawCards.add(_CardModel(id: i * 2, pairId: i, object: chosen[i]));
      rawCards.add(_CardModel(id: i * 2 + 1, pairId: i, object: chosen[i]));
    }
    rawCards.shuffle(rng);
    _cards = rawCards;

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
    _flipAnims = _flipCtrls
        .map(
          (ctrl) => Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut)),
        )
        .toList();

    _peekedIds.clear();
    _locked = false;
    _roundComplete = false;
    _matchesFound = 0;
    _celebCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Card tap logic ─────────────────────────────────────────────────────────
  Future<void> _onCardTap(int cardIndex) async {
    if (_locked || _roundComplete) return;

    final card = _cards[cardIndex];
    if (card.isFaceUp || card.isMatched) return;

    setState(() {
      card.isFaceUp = true;
      _peekedIds.add(cardIndex);
    });
    _flipCtrls[cardIndex].forward();

    if (_peekedIds.length < 2) return;

    _locked = true;
    final idxA = _peekedIds[0];
    final idxB = _peekedIds[1];
    final cardA = _cards[idxA];
    final cardB = _cards[idxB];

    if (cardA.pairId == cardB.pairId) {
      showRoxieReaction(RoxieState.correct);

      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        cardA.isMatched = true;
        cardB.isMatched = true;
        _peekedIds.clear();
        _matchesFound++;
        _locked = false;
      });

      if (_matchesFound == _kPairsPerRound) {
        _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _roundComplete = true);
        _celebCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 1200));

        if (_round >= _kTotalRounds) {
          await Future.delayed(const Duration(milliseconds: 300));
          await _bgPlayer.stop();
          await _sfxPlayer.stop();

          final completer = Completer<void>();
          final sub = _completePlayer.onPlayerComplete.listen((_) {
            if (!completer.isCompleted) completer.complete();
          });
          await _completePlayer.play(
            AssetSource(_audioComplete.replaceFirst('assets/', '')),
          );
          await completer.future.timeout(const Duration(seconds: 10));
          await sub.cancel();

          await PuzzleProgressService.instance.markLevelComplete(19);

          if (mounted) setState(() => _showWinDialog = true);
        } else {
          await _enterCtrl.reverse();
          setState(() {
            _round++;
            _buildRound();
          });
        }
      }
    } else {
      showRoxieReaction(RoxieState.wrong);

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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                Image.asset(
                  _bgImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Container(color: Colors.black.withValues(alpha: 0.15)),
              ],
            ),
          ),
          SafeArea(
            child: _screenPhase == _ScreenPhase.intro
                ? _buildIntroContent()
                : Stack(
                    children: [
                      FadeTransition(
                        opacity: _gameFade,
                        child: _buildGameContent(),
                      ),
                      buildRoxie(context),
                    ],
                  ),
          ),
          if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildIntroContent() {
    return Stack(
      children: [
        Positioned(top: 8, left: 12, child: PuzzleBackButton()),

        Positioned.fill(
          top: 48,
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildIntroRoxie()),
              Expanded(flex: 6, child: _buildIntroDancingCards()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroRoxie() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final roxieH = h * 1.05;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _roxieFloatCtrl, curve: Curves.easeInOut),
        );

        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _roxieSlide,
              child: FadeTransition(
                opacity: _roxieFade,
                child: AnimatedBuilder(
                  animation: _roxieFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, floatY),
                    child: child,
                  ),
                  child: Image.asset(
                    _characterImage,
                    height: roxieH,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Text('🐰', style: TextStyle(fontSize: roxieH * 0.5)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroDancingCards() {
    // Show a preview of face-down cards dancing to hint at the memory game
    return AnimatedBuilder(
      animation: _cardDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: List.generate(8, (i) {
              final angle = _cardDance.value * ((i % 2 == 0) ? 1 : -1);
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: JarColorTheme.vandecane,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: JarColorTheme.darkdesaturatedblue.withValues(
                        alpha: 0.35,
                      ),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontFamily: JarAppTextStyles.fredoka,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: JarColorTheme.sunnyhue,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGameContent() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildGameHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildCardGrid()),
          _buildProgressDots(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildGameHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Memory Match',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 22,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardGrid() {
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
          final showFront = anim.value >= 0.5;
          final angle = showFront ? (anim.value - 1.0) * pi : anim.value * pi;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showFront ? _cardFront(card) : _cardBack(),
          );
        },
      ),
    );
  }

  Widget _cardBack() {
    return _cardShell(
      color: JarColorTheme.vandecane,
      borderColor: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.35),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            _starImage,
            width: 36,
            height: 36,
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.12),
            colorBlendMode: BlendMode.modulate,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          Text(
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
            'assets/images/objects/puzzle/${card.object}.png',
            width: 50,
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('🖼️', style: TextStyle(fontSize: 36)),
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
      width: 82,
      height: 82,
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

  // ── Win overlay ────────────────────────────────────────────────────────────
  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: JarColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Lvl20CopyPattern2Screen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Lvl19JarMemoryMatch3Screen()),
        );
      },
      onBack: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PuzzleLevelScreen()),
        );
      },
    );
  }
}
