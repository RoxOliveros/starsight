import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'game_which_belongs_here.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Question model
// ─────────────────────────────────────────────────────────────────────────────

class _SameOrDifferentQuestion {
  final String leftObject;
  final String rightObject;
  final Color? leftTint;
  final Color? rightTint;
  final double leftScale;
  final double rightScale;
  final bool isSame;

  const _SameOrDifferentQuestion({
    required this.leftObject,
    required this.rightObject,
    this.leftTint,
    this.rightTint,
    this.leftScale = 1.0,
    this.rightScale = 1.0,
    required this.isSame,
  });

  /// Unique-ish key used to avoid repeating the exact same question
  /// within a single playthrough.
  String get key =>
      '$leftObject-$rightObject-$leftTint-$rightTint-$leftScale-$rightScale-$isSame';
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const int _kTotalRounds = 5;

// Round 1 — very obvious: identical object, identical everything.
const List<_SameOrDifferentQuestion> _kRound1Pool = [
  _SameOrDifferentQuestion(leftObject: 'apple', rightObject: 'apple', isSame: true),
  _SameOrDifferentQuestion(leftObject: 'ball', rightObject: 'ball', isSame: true),
  _SameOrDifferentQuestion(leftObject: 'flower', rightObject: 'flower', isSame: true),
  _SameOrDifferentQuestion(leftObject: 'car', rightObject: 'car', isSame: true),
  _SameOrDifferentQuestion(leftObject: 'dog', rightObject: 'dog', isSame: true),
];

// Round 2 — clearly different objects.
const List<_SameOrDifferentQuestion> _kRound2Pool = [
  _SameOrDifferentQuestion(leftObject: 'apple', rightObject: 'banana', isSame: false),
  _SameOrDifferentQuestion(leftObject: 'dog', rightObject: 'bus', isSame: false),
  _SameOrDifferentQuestion(leftObject: 'car', rightObject: 'tree', isSame: false),
  _SameOrDifferentQuestion(leftObject: 'pen', rightObject: 'cat', isSame: false),
  _SameOrDifferentQuestion(leftObject: 'flower', rightObject: 'book', isSame: false),
];

// Round 3 — same object, different color tint.
const List<_SameOrDifferentQuestion> _kRound3Pool = [
  _SameOrDifferentQuestion(
    leftObject: 'ball',
    rightObject: 'ball',
    leftTint: Colors.blueAccent,
    rightTint: Colors.redAccent,
    isSame: false,
  ),
  _SameOrDifferentQuestion(
    leftObject: 'flower',
    rightObject: 'flower',
    leftTint: Colors.purpleAccent,
    rightTint: Colors.orangeAccent,
    isSame: false,
  ),
  _SameOrDifferentQuestion(
    leftObject: 'apple',
    rightObject: 'apple',
    leftTint: Colors.green,
    rightTint: Colors.redAccent,
    isSame: false,
  ),
  _SameOrDifferentQuestion(
    leftObject: 'car',
    rightObject: 'car',
    leftTint: Colors.yellow,
    rightTint: Colors.blueAccent,
    isSame: false,
  ),
];

// Round 4 — same shape, different size.
const List<_SameOrDifferentQuestion> _kRound4Pool = [
  _SameOrDifferentQuestion(
    leftObject: 'flower',
    rightObject: 'flower',
    leftScale: 1.0,
    rightScale: 0.55,
    isSame: false,
  ),
  _SameOrDifferentQuestion(
    leftObject: 'ball',
    rightObject: 'ball',
    leftScale: 1.0,
    rightScale: 0.5,
    isSame: false,
  ),
  _SameOrDifferentQuestion(
    leftObject: 'tree',
    rightObject: 'tree',
    leftScale: 0.6,
    rightScale: 1.0,
    isSame: false,
  ),
  _SameOrDifferentQuestion(
    leftObject: 'car',
    rightObject: 'car',
    leftScale: 1.0,
    rightScale: 0.6,
    isSame: false,
  ),
];

// Round 5 — visually similar but different objects; look closely.
const List<_SameOrDifferentQuestion> _kRound5Pool = [
  _SameOrDifferentQuestion(leftObject: 'ball', rightObject: 'apple', isSame: false),
  _SameOrDifferentQuestion(leftObject: 'book', rightObject: 'notebook', isSame: false),
  _SameOrDifferentQuestion(leftObject: 'leaf', rightObject: 'tree', isSame: false),
  _SameOrDifferentQuestion(leftObject: 'cat', rightObject: 'dog', isSame: false),
];

const List<List<_SameOrDifferentQuestion>> _kRoundQuestionPools = [
  _kRound1Pool,
  _kRound2Pool,
  _kRound3Pool,
  _kRound4Pool,
  _kRound5Pool,
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SameOrDifferentScreen extends StatefulWidget {
  final int level;

  const SameOrDifferentScreen({super.key, required this.level});

  @override
  State<SameOrDifferentScreen> createState() => _SameOrDifferentScreenState();
}

class _SameOrDifferentScreenState extends State<SameOrDifferentScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<SameOrDifferentScreen>, GameLoadingMixin {
  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
  static const String _objectAssetPath = 'assets/images/objects/puzzle';
  static const String _symbolAssetPath = 'assets/images/buttons';

  static const String _audioIntro = 'assets/audio/puzzle_glade/same_or_different_intro.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/same_or_different_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/same_or_different_complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late _SameOrDifferentQuestion _question;
  final Set<String> _usedQuestionKeys = {};

  bool? _selectedAnswer; // true = SAME tapped, false = DIFFERENT tapped
  bool _buttonsDisabled = false;
  bool _roundComplete = false;
  bool _wrongFlash = false;
  bool _showWinDialog = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _roxiePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _previewPulseCtrl;
  late Animation<double> _previewPulse;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  @override
  void dispose() {
    _bgPlayer.stop();
    _completePlayer.stop();
    _roxiePlayer.stop();

    _bgPlayer.dispose();
    _completePlayer.dispose();
    _roxiePlayer.dispose();

    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _previewPulseCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();

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
        .animate(CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut));
    _roxieFade = CurvedAnimation(parent: _roxieSlideCtrl, curve: const Interval(0, 0.4));

    _previewPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _previewPulse = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _previewPulseCtrl, curve: Curves.easeInOut),
    );

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
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    _roxieSlideCtrl.forward();
    _speechBubbleCtrl.forward(from: 0);

    await _playBgAudio(_audioIntro);

    if (!mounted) return;

    _speechBubbleCtrl.forward(from: 0);
    _gameEnterCtrl.forward();

    _startRound();

    if (!mounted) return;

    setState(() => _screenPhase = _ScreenPhase.game);

    await _playBgAudio(_audioInstructions);

    if (!mounted) return;
  }

  Future<void> _playBgAudio(String asset) async {
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

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    if (!mounted) return;

    final rng = Random();
    final pool = _kRoundQuestionPools[_round - 1];

    final available = pool.where((q) => !_usedQuestionKeys.contains(q.key)).toList();
    final candidates = available.isNotEmpty ? available : pool;

    _question = candidates[rng.nextInt(candidates.length)];
    _usedQuestionKeys.add(_question.key);

    _selectedAnswer = null;
    _buttonsDisabled = false;
    _roundComplete = false;
    _wrongFlash = false;

    _bounceCtrl.reset();
    _shakeCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Answer handling ────────────────────────────────────────────────────────

  Future<void> _onAnswerSelected(bool answeredSame) async {
    if (_buttonsDisabled || _roundComplete) return;

    final isCorrect = answeredSame == _question.isSame;

    if (isCorrect) {
      setState(() {
        _selectedAnswer = answeredSame;
        _buttonsDisabled = true;
        _roundComplete = true;
      });

      _bounceCtrl.forward(from: 0);

      unawaited(showRoxieReaction(RoxieState.correct));

      await Future.delayed(const Duration(milliseconds: 1100));

      if (!mounted) return;

      if (_round >= _kTotalRounds) {
        await _bgPlayer.stop();

        if (!mounted) return;

        final completer = Completer<void>();
        final sub = _completePlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });

        try {
          await _completePlayer.play(
            AssetSource(_audioComplete.replaceFirst('assets/', '')),
          );
          await completer.future.timeout(const Duration(seconds: 10));
        } finally {
          await sub.cancel();
        }

        if (!mounted) return;

        await PuzzleProgressService.instance.markLevelComplete(widget.level);

        if (!mounted) return;

        setState(() => _showWinDialog = true);
      } else {
        await _enterCtrl.reverse();

        if (!mounted) return;

        setState(() {
          _round++;
          _startRound();
        });
      }
    } else {
      // Wrong answer: flash, react, and let the child try again.
      setState(() {
        _selectedAnswer = answeredSame;
        _buttonsDisabled = true;
        _wrongFlash = true;
      });

      unawaited(showRoxieReaction(RoxieState.wrong));

      _shakeCtrl.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 650));

      if (!mounted) return;

      setState(() {
        _selectedAnswer = null;
        _buttonsDisabled = false;
        _wrongFlash = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.puzzleGlade(),
        gameBuilder: () => Stack(
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
            _screenPhase == _ScreenPhase.intro
                ? _buildIntroLayer()
                : Stack(
                    children: [
                      FadeTransition(
                        opacity: _gameFade,
                        child: _buildGameLayer(),
                      ),
                      buildRoxie(context),
                    ],
                  ),
            if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIntroLayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
              Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildIntroRoxie()),
              Expanded(flex: 6, child: _buildIntroPreview()),
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
        final roxieH = h * 0.95;
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroPreview() {
    // A single obvious "same" example to set expectations before round 1.
    return Center(
      child: ScaleTransition(
        scale: _previewPulse,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPreviewCard('apple'),
            const SizedBox(width: 18),
            _buildCompareIndicator(),
            const SizedBox(width: 18),
            _buildPreviewCard('apple'),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(String object) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PuzzleColorTheme.sunnyhue,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          '$_objectAssetPath/$object.png',
          width: 58,
          height: 58,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameLayer() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
                Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
              ],
            ),
          ),
          Expanded(child: _buildGameArea()),
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: _buildAnswerButtons(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: PuzzleProgressDots(
              currentRound: _round,
              totalRounds: _kTotalRounds,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildObjectCard(
            object: _question.leftObject,
            tint: _question.leftTint,
            scale: _question.leftScale,
          ),
          const SizedBox(width: 26),
          _buildCompareIndicator(),
          const SizedBox(width: 26),
          _buildObjectCard(
            object: _question.rightObject,
            tint: _question.rightTint,
            scale: _question.rightScale,
          ),
        ],
      ),
    );
  }

  Widget _buildCompareIndicator() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.30),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'VS',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: PuzzleColorTheme.darkdesaturatedblue,
        ),
      ),
    );
  }

  Widget _buildObjectCard({
    required String object,
    Color? tint,
    double scale = 1.0,
  }) {
    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28);
    Color bgColor = Colors.white.withValues(alpha: 0.85);

    if (_roundComplete) {
      borderColor = PuzzleColorTheme.sunnyhue;
      bgColor = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28);
    } else if (_wrongFlash) {
      borderColor = const Color(0xFFE05A5A);
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.10);
    }

    Widget image = Image.asset(
      '$_objectAssetPath/$object.png',
      width: 88 * scale,
      height: 88 * scale,
      fit: BoxFit.contain,
      color: tint,
      colorBlendMode: tint != null ? BlendMode.modulate : null,
    );

    if (_roundComplete) {
      image = ScaleTransition(scale: _bounceAnim, child: image);
    }

    Widget card = Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _roundComplete
                ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.35)
                : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
            blurRadius: _roundComplete ? 16 : 10,
            spreadRadius: _roundComplete ? 1 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: image),
    );

    if (_wrongFlash) {
      card = AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildAnswerButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAnswerButton(
          imagePath: '$_symbolAssetPath/equals.png',
          answeredSame: true,
          color: PuzzleColorTheme.sunnyhue,
        ),
        const SizedBox(width: 24),
        _buildAnswerButton(
          imagePath: '$_symbolAssetPath/not_equals.png',
          answeredSame: false,
          color: PuzzleColorTheme.darkdesaturatedblue,
        ),
      ],
    );
  }

  Widget _buildAnswerButton({
    required String imagePath,
    required bool answeredSame,
    required Color color,
  }) {
    final bool isThisSelectedWrong =
        _wrongFlash && _selectedAnswer == answeredSame;

    return GestureDetector(
      onTap: () => _onAnswerSelected(answeredSame),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _buttonsDisabled && !isThisSelectedWrong ? 0.5 : 1.0,
        child: Container(
          width: 190,
          height: 68,
          alignment: Alignment.center,
          child: Image.asset(
            imagePath,
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WhichBelongsHereScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SameOrDifferentScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
