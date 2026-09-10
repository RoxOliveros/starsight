import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../business_layer/arctic_progress_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../audio_helper.dart';
import '../goodjob_prompt.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';

// ─────────────────────────────────────────────────────────────────────────
// Challenge types
// ─────────────────────────────────────────────────────────────────────────

enum ArcticFinalChallenge {
  recognition,
  counting,
  sequence,
  addition,
  subtraction,
}

const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────
// Dynamic question model
// ─────────────────────────────────────────────────────────────────────────

class ArcticFinalQuestion {
  final ArcticFinalChallenge type;
  final int correctAnswer;
  final List<int> choices;

  // Sequence-specific.
  final List<int>? sequence;
  final int? missingIndex;

  // Addition/subtraction-specific.
  final int? firstNumber;
  final int? secondNumber;

  // Counting-specific.
  final int? objectCount;
  final String? objectAsset; // e.g. 'snowflake', 'fish', 'star'

  const ArcticFinalQuestion({
    required this.type,
    required this.correctAnswer,
    required this.choices,
    this.sequence,
    this.missingIndex,
    this.firstNumber,
    this.secondNumber,
    this.objectCount,
    this.objectAsset,
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────

enum _ScreenPhase { intro, game }

class ArcticFestivalFinaleGame extends StatefulWidget {
  final int level;

  const ArcticFestivalFinaleGame({super.key, required this.level});

  @override
  State<ArcticFestivalFinaleGame> createState() =>
      _ArcticFestivalFinaleGameState();
}

class _ArcticFestivalFinaleGameState extends State<ArcticFestivalFinaleGame>
    with TickerProviderStateMixin, DomaReactionMixin, GameLoadingMixin {
  @override
  AudioPlayer get domaPlayer => _domaPlayer;

  // ── Asset config ───────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic_night.png';
  static const String _starBnwImage = 'assets/images/objects/arctic/star_bnw.png';
  static const String _starImage = 'assets/images/objects/arctic/star.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/arctic_festival_intro.wav';
  static const String _audioMainInstruction = 'assets/audio/arctic_numberland/arctic_festival_instruction.wav';
  static const String _audioRecognition = 'assets/audio/arctic_numberland/arctic_festival_recognition_instruction.wav';
  static const String _audioCounting = 'assets/audio/arctic_numberland/arctic_festival_counting_instruction.wav';
  static const String _audioSequence = 'assets/audio/arctic_numberland/arctic_festival_sequence_instruction.wav';
  static const String _audioAddition = 'assets/audio/arctic_numberland/arctic_festival_addition_instruction.wav';
  static const String _audioSubtraction = 'assets/audio/arctic_numberland/arctic_festival_subtraction_instruction.wav';
  static const String _audioNextChallenge = 'assets/audio/arctic_numberland/arctic_festival_next_challenge.wav';
  static const String _audioWin = 'assets/audio/arctic_numberland/arctic_festival_win.wav';
  static String _numberAudioAsset(int n) => 'assets/audio/arctic_numberland/$n.wav';

  static const List<String> _countingObjectPool = [
    'assets/images/objects/arctic/snowflake.png',
    'assets/images/objects/arctic/snowball.png',
    'assets/images/objects/arctic/fish.png',
    'assets/images/objects/arctic/star.png',
  ];

  // ── Phase / round state ───────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  int _round = 1;
  late List<ArcticFinalChallenge> _challengeOrder;
  late ArcticFinalQuestion _currentQuestion;

  int _litLights = 0;
  int? _selectedIndex;
  int? _wrongIndex;
  bool _isBusy = false;
  bool _showWinDialog = false;
  bool _showFlyingStars = false;

  final Random _rng = Random();

  // ── Audio ──────────────────────────────────────────────────────────────
  final AudioHelper _audioHelper = AudioHelper();
  final AudioPlayer _narrationPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _domaPlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _domaSlideCtrl;
  late Animation<Offset> _domaSlide;
  late Animation<double> _domaFade;

  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  late AnimationController _lightGlowCtrl;

  late AnimationController _flyingStarsCtrl;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _newGame();
    finishLoading(_startIntroFlow);
  }

  @override
  void dispose() {
    _audioHelper.stopBackgroundMusic();
    _audioHelper.dispose();

    _narrationPlayer.stop();
    _sfxPlayer.stop();
    _domaPlayer.stop();
    _narrationPlayer.dispose();
    _sfxPlayer.dispose();
    _domaPlayer.dispose();

    _domaFloatCtrl.dispose();
    _domaSlideCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    _lightGlowCtrl.dispose();
    _flyingStarsCtrl.dispose();

    OrientationService.setLandscape();
    super.dispose();
  }

  void _initAnimations() {
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _domaSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _domaSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(CurvedAnimation(parent: _domaSlideCtrl, curve: Curves.elasticOut));
    _domaFade = CurvedAnimation(parent: _domaSlideCtrl, curve: const Interval(0, 0.4));

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
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
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

    _lightGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _flyingStarsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  // ── New game / replay setup ──────────────────────────────────────────
  // Called on initState AND every restart — regenerates challenge order
  // and, transitively (via _loadRound), every question.

  void _newGame() {
    _round = 1;
    _litLights = 0;
    _selectedIndex = null;
    _wrongIndex = null;
    _isBusy = false;
    _showWinDialog = false;

    _challengeOrder = [
      ArcticFinalChallenge.recognition,
      ArcticFinalChallenge.counting,
      ArcticFinalChallenge.sequence,
      ArcticFinalChallenge.addition,
      ArcticFinalChallenge.subtraction,
    ]..shuffle(_rng);
  }

  // ── Intro flow ────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Background music starts here and is never stopped/restarted until
    // dispose — everything else (narration, Doma reactions, SFX) plays
    // over it via separate AudioPlayer instances.
    unawaited(_audioHelper.playBackgroundMusic());

    _domaSlideCtrl.forward();

    await _playNarration(_audioIntro);
    if (!mounted) return;

    await _playNarration(_audioMainInstruction);
    if (!mounted) return;

    _gameEnterCtrl.forward();
    _loadRound();

    setState(() => _screenPhase = _ScreenPhase.game);

    await _playChallengeInstruction(_challengeOrder[_round - 1]);
    await _maybePlayRecognitionNumber();
  }

  Future<void> _playNarration(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _narrationPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _narrationPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Narration error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> _playChallengeInstruction(ArcticFinalChallenge type) async {
    if (!mounted) return;
    setState(() => _isBusy = true);

    final asset = switch (type) {
      ArcticFinalChallenge.recognition => _audioRecognition,
      ArcticFinalChallenge.counting => _audioCounting,
      ArcticFinalChallenge.sequence => _audioSequence,
      ArcticFinalChallenge.addition => _audioAddition,
      ArcticFinalChallenge.subtraction => _audioSubtraction,
    };

    await _playNarration(asset);
    if (!mounted) return;

    setState(() => _isBusy = false);
  }

  Future<void> _maybePlayRecognitionNumber() async {
    if (!mounted) return;
    if (_challengeOrder[_round - 1] == ArcticFinalChallenge.recognition) {
      await _playNarration(_numberAudioAsset(_currentQuestion.correctAnswer));
    }
  }

  // ── Round setup ───────────────────────────────────────────────────────

  void _loadRound() {
    final type = _challengeOrder[_round - 1];
    setState(() {
      _currentQuestion = _generateQuestion(type);
      _selectedIndex = null;
      _wrongIndex = null;
    });
    _bounceCtrl.reset();
    _shakeCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Question generation (kept separate from UI) ─────────────────────

  ArcticFinalQuestion _generateQuestion(ArcticFinalChallenge type) {
    switch (type) {
      case ArcticFinalChallenge.recognition:
        return _generateRecognitionQuestion();
      case ArcticFinalChallenge.counting:
        return _generateCountingQuestion();
      case ArcticFinalChallenge.sequence:
        return _generateSequenceQuestion();
      case ArcticFinalChallenge.addition:
        return _generateAdditionQuestion();
      case ArcticFinalChallenge.subtraction:
        return _generateSubtractionQuestion();
    }
  }

  List<int> _generateAnswerChoices({
    required int correctAnswer,
    required int min,
    required int max,
  }) {
    final choices = <int>{correctAnswer};
    int attempts = 0;

    while (choices.length < 3 && attempts < 30) {
      attempts++;
      final offset = _rng.nextInt(5) - 2; // -2..+2, close distractors
      final candidate = (correctAnswer + offset).clamp(min, max);
      choices.add(candidate);
    }

    // Extremely small ranges (e.g. correct=0, min=0, max=1) could still
    // leave us short — pad with anything in range as a last resort.
    while (choices.length < 3) {
      choices.add(_rng.nextInt(max - min + 1) + min);
    }

    final list = choices.toList()..shuffle(_rng);
    return list;
  }

  ArcticFinalQuestion _generateRecognitionQuestion() {
    final target = _rng.nextInt(11); // 0–10
    return ArcticFinalQuestion(
      type: ArcticFinalChallenge.recognition,
      correctAnswer: target,
      choices: _generateAnswerChoices(correctAnswer: target, min: 0, max: 10),
    );
  }

  ArcticFinalQuestion _generateCountingQuestion() {
    final count = _rng.nextInt(10) + 1; // 1–10
    final asset = _countingObjectPool[_rng.nextInt(_countingObjectPool.length)];
    return ArcticFinalQuestion(
      type: ArcticFinalChallenge.counting,
      correctAnswer: count,
      choices: _generateAnswerChoices(correctAnswer: count, min: 1, max: 10),
      objectCount: count,
      objectAsset: asset,
    );
  }

  ArcticFinalQuestion _generateSequenceQuestion() {
    final length = _rng.nextBool() ? 4 : 5;
    final maxStart = 10 - (length - 1);
    final start = _rng.nextInt(maxStart + 1); // keeps sequence within 0–10
    final sequence = List<int>.generate(length, (i) => start + i);
    final missingIndex = _rng.nextInt(length);
    final correct = sequence[missingIndex];

    return ArcticFinalQuestion(
      type: ArcticFinalChallenge.sequence,
      correctAnswer: correct,
      choices: _generateAnswerChoices(correctAnswer: correct, min: 0, max: 10),
      sequence: sequence,
      missingIndex: missingIndex,
    );
  }

  ArcticFinalQuestion _generateAdditionQuestion() {
    final a = _rng.nextInt(9) + 1; // 1–9
    final maxB = 10 - a;
    final b = _rng.nextInt(maxB) + 1; // 1..maxB, guarantees sum <= 10
    final sum = a + b;

    return ArcticFinalQuestion(
      type: ArcticFinalChallenge.addition,
      correctAnswer: sum,
      choices: _generateAnswerChoices(correctAnswer: sum, min: 0, max: 10),
      firstNumber: a,
      secondNumber: b,
    );
  }

  ArcticFinalQuestion _generateSubtractionQuestion() {
    final starting = _rng.nextInt(10) + 1; // 1–10
    final removed = _rng.nextInt(starting + 1); // 0..starting
    final result = starting - removed;

    return ArcticFinalQuestion(
      type: ArcticFinalChallenge.subtraction,
      correctAnswer: result,
      choices: _generateAnswerChoices(correctAnswer: result, min: 0, max: 10),
      firstNumber: starting,
      secondNumber: removed,
    );
  }

  // ── Answer handling ──────────────────────────────────────────────────

  Future<void> _onAnswerTapped(int index) async {
    if (_isBusy) return;

    final selectedValue = _currentQuestion.choices[index];
    final isCorrect = selectedValue == _currentQuestion.correctAnswer;

    if (isCorrect) {
      await _handleCorrect(index);
    } else {
      await _handleWrong(index);
    }
  }

  Future<void> _handleCorrect(int index) async {
    setState(() {
      _isBusy = true;
      _selectedIndex = index;
      _litLights = _round; // light #N for round N
    });

    _bounceCtrl.forward(from: 0);
    unawaited(showDomaReaction(DomaState.correct));

    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    if (_round >= _kTotalRounds) {
      await _finishGame();
      return;
    }

    final playCheer = _rng.nextBool();
    if (playCheer) {
      await _playNarration(_audioNextChallenge);
      if (!mounted) return;
    }

    await _enterCtrl.reverse();
    if (!mounted) return;

    setState(() => _round++);
    _loadRound();

    await _playChallengeInstruction(_challengeOrder[_round - 1]);
    await _maybePlayRecognitionNumber();
  }

  Future<void> _handleWrong(int index) async {
    setState(() {
      _isBusy = true;
      _wrongIndex = index;
    });

    unawaited(showDomaReaction(DomaState.wrong));
    _shakeCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    setState(() {
      _wrongIndex = null;
      _isBusy = false;
      // Question is intentionally NOT regenerated — same problem stays
      // until the child answers correctly.
    });
  }

  Future<void> _finishGame() async {
    setState(() {
      _showWinDialog = false;
      _showFlyingStars = true;
    });
    _flyingStarsCtrl.forward(from: 0);

    await _narrationPlayer.stop();
    if (!mounted) return;

    await _playNarration(_audioWin);
    if (!mounted) return;

    await ArcticProgressService.instance.markLevelComplete(widget.level);

    if (!mounted) return;
    setState(() {
      _showFlyingStars = false;
      _showWinDialog = true;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.arctic(),
        gameBuilder: () => Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  Image.asset(_bgImage, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  Container(color: Colors.black.withValues(alpha: 0.15)),
                ],
              ),
            ),
            _screenPhase == _ScreenPhase.intro
                ? _buildIntroLayer()
                : Stack(
              children: [
                FadeTransition(opacity: _gameFade, child: _buildGameLayer()),
                buildDoma(context),
              ],
            ),
            if (_showFlyingStars) Positioned.fill(child: IgnorePointer(child: _buildFlyingStars())),
            if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildIntroLayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(alignment: Alignment.centerLeft, child: ArcticXButton()),
              Align(alignment: Alignment.centerRight, child: ArcticLevelBadge(level: widget.level)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildIntroDoma()),
              Expanded(
                flex: 6,
                child: Center(child: _buildFestivalLights(size: 70)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroDoma() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final domaH = h * 0.95;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _domaFloatCtrl, curve: Curves.easeInOut),
        );
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _domaSlide,
              child: FadeTransition(
                opacity: _domaFade,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) => Transform.translate(offset: Offset(0, floatY), child: child),
                  child: Image.asset(_characterImage, height: domaH, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildGameLayer() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(alignment: Alignment.centerLeft, child: ArcticXButton()),
                Align(alignment: Alignment.centerRight, child: ArcticLevelBadge(level: widget.level)),
              ],
            ),
          ),
          Expanded(child: _buildChallengeVisual()),
          _buildAnswerRow(),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 15),
            child: _buildFestivalLights(size: 34),
          ),
        ],
      ),
    );
  }

  Widget _buildFlyingStars() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const starCount = 5;

        return AnimatedBuilder(
          animation: _flyingStarsCtrl,
          builder: (context, _) {
            return Stack(
              children: List.generate(starCount, (i) {
                final start = i * 0.12;
                final progress = CurvedAnimation(
                  parent: _flyingStarsCtrl,
                  curve: Interval(start, (start + 0.6).clamp(0.0, 1.0), curve: Curves.easeOut),
                ).value;

                final startX = w * (0.15 + 0.7 * (i / (starCount - 1)));
                final endX = startX + (i.isEven ? -40.0 : 40.0);
                final dx = startX + (endX - startX) * progress;
                final dy = (h + 60) + ((h * 0.15) - (h + 60)) * progress;

                final opacity = progress < 0.1
                    ? progress / 0.1
                    : (progress > 0.85 ? (1 - progress) / 0.15 : 1.0);
                final scale = 0.6 + 0.6 * progress;
                final rotation = progress * (i.isEven ? 1 : -1) * 2.5;

                return Positioned(
                  left: dx - 24,
                  top: dy - 24,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(
                        scale: scale,
                        child: Image.asset(_starImage, width: 48, height: 48),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildChallengeVisual() {
    switch (_currentQuestion.type) {
      case ArcticFinalChallenge.recognition:
        return Center(child: _buildListenPrompt());
      case ArcticFinalChallenge.counting:
        return Center(child: _buildObjectCluster());
      case ArcticFinalChallenge.sequence:
        return Center(child: _buildSequenceRow());
      case ArcticFinalChallenge.addition:
        return Center(child: _buildAdditionVisual());
      case ArcticFinalChallenge.subtraction:
        return Center(child: _buildSubtractionVisual());
    }
  }

  Widget _buildListenPrompt() {
    return GestureDetector(
      onTap: _isBusy
          ? null
          : () => _playNarration(_numberAudioAsset(_currentQuestion.correctAnswer)),
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ArcticColorTheme.slateblue, width: 4),
        ),
        child: Center(
          child: Icon(
            Icons.volume_up_rounded,
            size: 64,
            color: ArcticColorTheme.slateblue,
          ),
        ),
      ),
    );
  }

  Widget _buildObjectCluster() {
    final count = _currentQuestion.objectCount ?? 0;
    final asset = _currentQuestion.objectAsset ??
        _countingObjectPool.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ArcticColorTheme.slateblue.withValues(alpha: 10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArcticColorTheme.cotton.withValues(alpha: 0.5), width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: List.generate(
          count,
              (i) => Image.asset(asset, width: 46, height: 46, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildSequenceRow() {
    final sequence = _currentQuestion.sequence ?? const [];
    final missingIndex = _currentQuestion.missingIndex ?? -1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(sequence.length * 2 - 1, (i) {
        if (i.isOdd) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, size: 20, color: Colors.white),
          );
        }
        final dotIndex = i ~/ 2;
        final isMissing = dotIndex == missingIndex;
        return _buildSequenceCell(isMissing ? null : sequence[dotIndex]);
      }),
    );
  }

  Widget _buildSequenceCell(int? value) {
    return Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: value == null
            ? ArcticColorTheme.slateblue.withValues(alpha: 0.25)
            : ArcticColorTheme.slateblue.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value == null
              ? ArcticColorTheme.cotton
              : ArcticColorTheme.slateblue.withValues(alpha: 0.3),
          width: value == null ? 3 : 2,
        ),
      ),
      child: Center(
        child: Text(
          value?.toString() ?? '?',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: ArcticColorTheme.cotton,
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionVisual() {
    final a = _currentQuestion.firstNumber ?? 0;
    final b = _currentQuestion.secondNumber ?? 0;
    final asset = _countingObjectPool.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ArcticColorTheme.cadetblue.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ArcticColorTheme.slateblue.withValues(alpha: 0.3), width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(a, (_) => Image.asset(asset, width: 36, height: 36)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.add, size: 26, color: Colors.white),
              ),
              ...List.generate(b, (_) => Image.asset(asset, width: 36, height: 36)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ArcticColorTheme.slateblue.withValues(alpha: 0.3), width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Text(
            '$a + $b = ?',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ArcticColorTheme.slateblue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtractionVisual() {
    final starting = _currentQuestion.firstNumber ?? 0;
    final removed = _currentQuestion.secondNumber ?? 0;
    final asset = _countingObjectPool.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ArcticColorTheme.cadetblue.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ArcticColorTheme.slateblue.withValues(alpha: 0.3), width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: List.generate(starting, (i) {
              final isRemoved = i >= starting - removed;
              return Opacity(
                opacity: isRemoved ? 0.25 : 1.0,
                child: Image.asset(asset, width: 36, height: 36),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ArcticColorTheme.slateblue.withValues(alpha: 0.3), width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Text(
            '$starting - $removed = ?',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ArcticColorTheme.slateblue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerRow() {
    final choices = _currentQuestion.choices;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(choices.length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildAnswerButton(index),
          );
        }),
      ),
    );
  }

  Widget _buildAnswerButton(int index) {
    final value = _currentQuestion.choices[index];
    final isSelected = index == _selectedIndex;
    final isWrong = index == _wrongIndex;

    Color bgColor = Colors.white.withValues(alpha: 0.9);
    Color borderColor = ArcticColorTheme.slateblue.withValues(alpha: 0.3);

    if (isSelected) {
      bgColor = ArcticColorTheme.cotton.withValues(alpha: 0.85);
      borderColor = ArcticColorTheme.slateblue;
    }
    if (isWrong) {
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.12);
      borderColor = const Color(0xFFE05A5A);
    }

    Widget button = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: ArcticColorTheme.slateblue,
          ),
        ),
      ),
    );

    if (isSelected) {
      button = ScaleTransition(scale: _bounceAnim, child: button);
    }
    if (isWrong) {
      button = AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
        child: button,
      );
    }

    return GestureDetector(
      onTap: () => _onAnswerTapped(index),
      child: button,
    );
  }

  // ── Festival lights ──────────────────────────────────────────────────

  Widget _buildFestivalLights({required double size}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_kTotalRounds, (i) {
        final isLit = i < _litLights;
        Widget star = Image.asset(
          isLit ? _starImage : _starBnwImage,
          width: size,
          height: size,
        );

        if (isLit) {
          star = AnimatedBuilder(
            animation: _lightGlowCtrl,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ArcticColorTheme.slateblue
                        .withValues(alpha: 0.3 + 0.3 * _lightGlowCtrl.value),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
            child: star,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: star,
        );
      }),
    );
  }

  // ── Win overlay ───────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      onNext: () {
        Navigator.pop(context);
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ArcticFestivalFinaleGame(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}