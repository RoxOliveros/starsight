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
import 'game_odd_one_out_screen.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Question model
// ─────────────────────────────────────────────────────────────────────────────

class _GoesTogetherQuestion {
  final String targetObject;
  final String correctObject;
  final List<String> choices;

  const _GoesTogetherQuestion({
    required this.targetObject,
    required this.correctObject,
    required this.choices,
  });

  /// Unique-ish key used to avoid repeating the exact same question
  /// within a single playthrough.
  String get key => '$targetObject-$correctObject-${choices.join(",")}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const int _kTotalRounds = 5;

// Round 1 — very obvious pairs, clearly unrelated distractors.
const List<_GoesTogetherQuestion> _kRound1Pool = [
  _GoesTogetherQuestion(
    targetObject: 'toothbrush',
    correctObject: 'toothpaste',
    choices: ['toothpaste', 'ball', 'spoon'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'shoes',
    correctObject: 'socks',
    choices: ['socks', 'banana', 'star_alarm'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'lock',
    correctObject: 'key',
    choices: ['key', 'apple', 'kite'],
  ),
];

// Round 2 — common, still very clear object pairs.
const List<_GoesTogetherQuestion> _kRound2Pool = [
  _GoesTogetherQuestion(
    targetObject: 'pencil',
    correctObject: 'paper',
    choices: ['paper', 'fish', 'hat'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'cup',
    correctObject: 'water',
    choices: ['water', 'chair', 'kite'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'fork',
    correctObject: 'plate',
    choices: ['plate', 'ball', 'socks'],
  ),
];

// Round 3 — slightly more thoughtful associations.
const List<_GoesTogetherQuestion> _kRound3Pool = [
  _GoesTogetherQuestion(
    targetObject: 'bed',
    correctObject: 'pillow',
    choices: ['pillow', 'kite', 'spoon'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'rain_cloud',
    correctObject: 'umbrella',
    choices: ['umbrella', 'guitar', 'ball'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'soap',
    correctObject: 'towel',
    choices: ['towel', 'star_alarm', 'apple'],
  ),
];

// Round 4 — distractors are somewhat related or visually similar.
const List<_GoesTogetherQuestion> _kRound4Pool = [
  _GoesTogetherQuestion(
    targetObject: 'pencil',
    correctObject: 'paper',
    choices: ['paper', 'jar', 'spoon'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'fork',
    correctObject: 'plate',
    choices: ['plate', 'pan', 'kite'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'toothbrush',
    correctObject: 'toothpaste',
    choices: ['toothpaste', 'soap', 'towel'],
  ),
];

// Round 5 — more thoughtful, still unambiguous.
const List<_GoesTogetherQuestion> _kRound5Pool = [
  _GoesTogetherQuestion(
    targetObject: 'plant',
    correctObject: 'watering_can',
    choices: ['watering_can', 'drum', 'socks'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'letter',
    correctObject: 'envelope',
    choices: ['envelope', 'ball', 'apple'],
  ),
  _GoesTogetherQuestion(
    targetObject: 'door',
    correctObject: 'door_key',
    choices: ['door_key', 'spoon', 'kite'],
  ),
];

const List<List<_GoesTogetherQuestion>> _kRoundQuestionPools = [
  _kRound1Pool,
  _kRound2Pool,
  _kRound3Pool,
  _kRound4Pool,
  _kRound5Pool,
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class WhatGoesTogetherScreen extends StatefulWidget {
  final int level;

  const WhatGoesTogetherScreen({super.key, required this.level});

  @override
  State<WhatGoesTogetherScreen> createState() => _WhatGoesTogetherScreenState();
}

class _WhatGoesTogetherScreenState extends State<WhatGoesTogetherScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<WhatGoesTogetherScreen>, GameLoadingMixin {
  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
  static const String _objectAssetPath = 'assets/images/objects/puzzle';

  static const String _audioIntro = 'assets/audio/puzzle_glade/what_goes_together_intro.wav';
  static const String _audioInstruction = 'assets/audio/puzzle_glade/what_goes_together_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/what_goes_together_complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late _GoesTogetherQuestion _question;
  late List<String> _shuffledChoices;
  late int _correctIndex;
  final Set<String> _usedQuestionKeys = {};

  int? _selectedIndex;
  int? _wrongIndex;
  bool _buttonsDisabled = true;
  bool _roundComplete = false;
  bool _showWinDialog = false;
  bool _instructionPlayed = false;

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
  late AnimationController _targetEnterCtrl;
  late Animation<double> _targetFade;
  late Animation<double> _targetScale;
  late AnimationController _choicesEnterCtrl;
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
    _targetEnterCtrl.dispose();
    _choicesEnterCtrl.dispose();
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

    _targetEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _targetFade = CurvedAnimation(parent: _targetEnterCtrl, curve: Curves.easeOut);
    _targetScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _targetEnterCtrl, curve: Curves.easeOut),
    );

    _choicesEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
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

  Animation<double> _choiceEntranceFor(int index) {
    final start = index * 0.15;
    final end = (start + 0.6).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _choicesEnterCtrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
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

    setState(() {
      _screenPhase = _ScreenPhase.game;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;

    await _playInstructionAudio();
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

  /// Plays once, the first time gameplay is reached — blocks answering
  /// until it finishes. Does not repeat on later rounds since it's a
  /// one-time "how to play" narration, not per-round narration.
  Future<void> _playInstructionAudio() async {
    if (!mounted || _instructionPlayed) return;
    _instructionPlayed = true;

    if (mounted) {
      setState(() {
        _buttonsDisabled = true;
      });
    }

    await _playBgAudio(_audioInstruction);

    if (!mounted) return;

    if (!_roundComplete) {
      setState(() {
        _buttonsDisabled = false;
      });
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

    _shuffledChoices = List<String>.from(_question.choices)..shuffle(rng);
    _correctIndex = _shuffledChoices.indexOf(_question.correctObject);

    _selectedIndex = null;
    _wrongIndex = null;
    _buttonsDisabled = !_instructionPlayed;
    _roundComplete = false;

    _bounceCtrl.reset();
    _shakeCtrl.reset();
    _targetEnterCtrl.forward(from: 0);
    _choicesEnterCtrl.forward(from: 0);
  }

  // ── Answer handling ────────────────────────────────────────────────────────

  Future<void> _onChoiceTapped(int index) async {
    if (_buttonsDisabled || _roundComplete) return;

    final isCorrect = index == _correctIndex;

    if (isCorrect) {
      setState(() {
        _selectedIndex = index;
        _buttonsDisabled = true;
        _roundComplete = true;
      });

      _bounceCtrl.forward(from: 0);

      unawaited(showRoxieReaction(RoxieState.correct));

      await Future.delayed(const Duration(milliseconds: 1000));

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
        await _targetEnterCtrl.reverse();

        if (!mounted) return;

        setState(() {
          _round++;
        });

        _startRound();
      }
    } else {
      setState(() {
        _wrongIndex = index;
        _buttonsDisabled = true;
      });

      unawaited(showRoxieReaction(RoxieState.wrong));

      _shakeCtrl.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 650));

      if (!mounted) return;

      setState(() {
        _wrongIndex = null;
        _buttonsDisabled = false;
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
                  child: _buildGameArea(),
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
              Align(alignment: Alignment.center, child: PuzzleGameHeader(title: 'What Goes Together?')),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _previewPulse,
            child: _buildPreviewObjectCard('toothbrush', highlighted: true),
          ),
          const SizedBox(height: 12),
          Icon(
            Icons.favorite,
            color: PuzzleColorTheme.sunnyhue,
            size: 28,
          ),
          const SizedBox(height: 12),
          _buildPreviewObjectCard('toothpaste', highlighted: true),
        ],
      ),
    );
  }

  Widget _buildPreviewObjectCard(String object, {bool highlighted = false}) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? PuzzleColorTheme.sunnyhue
              : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.30),
          width: highlighted ? 3 : 2.5,
        ),
      ),
      child: Center(
        child: Image.asset(
          '$_objectAssetPath/$object.png',
          width: 60,
          height: 60,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameArea() {
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
        Expanded(child: _buildTarget()),
        Padding(
          padding: const EdgeInsets.only(top: 15, bottom: 15),
          child: _buildChoiceRow(),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: PuzzleProgressDots(
            currentRound: _round,
            totalRounds: _kTotalRounds,
          ),
        ),
      ],
    );
  }

  Widget _buildTarget() {
    Widget image = Image.asset(
      '$_objectAssetPath/${_question.targetObject}.png',
      fit: BoxFit.contain,
    );

    if (_roundComplete) {
      image = ScaleTransition(scale: _bounceAnim, child: image);
    }

    return Center(
      child: FadeTransition(
        opacity: _targetFade,
        child: ScaleTransition(
          scale: _targetScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 180,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: image,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _shuffledChoices.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
          KeyedSubtree(
            key: ValueKey('${_round}_${i}_${_shuffledChoices[i]}'),
            child: _buildChoiceCard(i),
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceCard(int index) {
    final object = _shuffledChoices[index];
    final isCorrectSelected = _roundComplete && index == _selectedIndex;
    final isWrongTap = _wrongIndex == index;
    final isDimmed = _roundComplete && index != _selectedIndex;

    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28);
    Color bgColor = Colors.white.withValues(alpha: 0.85);

    if (isCorrectSelected) {
      borderColor = PuzzleColorTheme.sunnyhue;
      bgColor = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28);
    }
    if (isWrongTap) {
      borderColor = const Color(0xFFE05A5A);
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.10);
    }

    Widget image = Image.asset(
      '$_objectAssetPath/$object.png',
      width: 76,
      fit: BoxFit.contain,
      color: isDimmed ? PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.25) : null,
      colorBlendMode: isDimmed ? BlendMode.modulate : null,
    );

    if (isCorrectSelected) {
      image = ScaleTransition(scale: _bounceAnim, child: image);
    }

    Widget card = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: isCorrectSelected
                ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.35)
                : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
            blurRadius: isCorrectSelected ? 16 : 10,
            spreadRadius: isCorrectSelected ? 1 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: image),
    );

    if (isWrongTap) {
      card = AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        ),
        child: card,
      );
    }

    final entrance = _choiceEntranceFor(index);
    card = FadeTransition(
      opacity: entrance,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(entrance),
        child: card,
      ),
    );

    return GestureDetector(
      onTap: () => _onChoiceTapped(index),
      child: card,
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OddOneOutScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WhatGoesTogetherScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}