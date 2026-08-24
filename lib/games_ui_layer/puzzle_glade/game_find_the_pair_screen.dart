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

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

class _FindThePairQuestion {
  final List<String> objects;
  final String matchingObject;

  const _FindThePairQuestion({
    required this.objects,
    required this.matchingObject,
  });
}

const List<_FindThePairQuestion> _kQuestions = [
  // Round 1
  _FindThePairQuestion(
    objects: ['apple', 'banana', 'apple', 'orange', 'ball', 'flower'],
    matchingObject: 'apple',
  ),

  // Round 2
  _FindThePairQuestion(
    objects: ['dog', 'car', 'rabbit', 'dog', 'cat', 'bus'],
    matchingObject: 'dog',
  ),

  // Round 3
  _FindThePairQuestion(
    objects: ['flower', 'tree', 'leaf', 'flower', 'car', 'banana'],
    matchingObject: 'flower',
  ),

  // Round 4
  _FindThePairQuestion(
    objects: ['pencil', 'notebook', 'book', 'pencil', 'banana', 'apple'],
    matchingObject: 'pencil',
  ),

  // Round 5
  _FindThePairQuestion(
    objects: ['car', 'bus', 'airplane', 'car', 'dog', 'tree'],
    matchingObject: 'car',
  ),
];

// Dart does not allow `List.length` in a const expression, so this is
// hardcoded to match _kQuestions.length.
const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class FindThePairScreen extends StatefulWidget {
  final int level;

  const FindThePairScreen({super.key, required this.level});

  @override
  State<FindThePairScreen> createState() => _FindThePairScreenState();
}

class _FindThePairScreenState extends State<FindThePairScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<FindThePairScreen>, GameLoadingMixin {
  // IMPORTANT: roxiePlayer must point at its own dedicated AudioPlayer
  // instance, never be aliased to _sfxPlayer — aliasing causes
  // RoxieReactionMixin's audio to interrupt/steal correct/wrong SFX
  // playback (the bug fixed in Shape Fit and Maze Path).
  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
  static const String _objectAssetPath = 'assets/images/objects/puzzle';

  static const String _audioIntro = 'assets/audio/puzzle_glade/intro.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/find_the_pair_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/level17/complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late String _matchingObject;
  late List<String> _choices; // 6 objects: one matching pair + 4 distinct
  int? _firstSelectedIndex;
  int? _secondSelectedIndex;
  bool _wrongFlash = false;
  int? _wrongIndex;
  bool _roundComplete = false;
  bool _showWinDialog = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
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
  late AnimationController _selectCtrl;
  late Animation<double> _selectAnim;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _revealCtrl;
  late Animation<double> _revealAnim;

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
    _bgPlayer.dispose();
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxiePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _previewPulseCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _selectCtrl.dispose();
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    _revealCtrl.dispose();
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

    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _selectAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _selectCtrl, curve: Curves.easeOut),
    );

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

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

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeIn);
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioIntro);

    _speechBubbleCtrl.forward(from: 0);

    _gameEnterCtrl.forward();
    _startRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
    await _playBgAudio(_audioInstructions);
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
    final rng = Random();
    final question = _kQuestions[_round - 1];

    _matchingObject = question.matchingObject;

    // Randomize the position of every card (and therefore the matching
    // pair's positions) every round.
    _choices = List<String>.from(question.objects)..shuffle(rng);

    _firstSelectedIndex = null;
    _secondSelectedIndex = null;
    _wrongFlash = false;
    _wrongIndex = null;
    _roundComplete = false;

    _selectCtrl.reset();
    _bounceCtrl.reset();
    _shakeCtrl.reset();
    _revealCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Tap handling ───────────────────────────────────────────────────────────

  Future<void> _onObjectTapped(int index) async {
    // Block taps while a round is already won or a wrong-answer animation
    // is playing, but otherwise always allow another attempt.
    if (_roundComplete || _wrongFlash) return;

    if (_firstSelectedIndex == null) {
      setState(() => _firstSelectedIndex = index);
      _selectCtrl.forward(from: 0);
      return;
    }

    if (index == _firstSelectedIndex) return;

    // IMPORTANT: compare the actual object values, not the indexes —
    // several cards can share the same object name.
    final isMatch = _choices[_firstSelectedIndex!] == _choices[index];

    setState(() => _secondSelectedIndex = index);

    if (isMatch) {
      setState(() => _roundComplete = true);
      _bounceCtrl.forward(from: 0);
      _revealCtrl.forward(from: 0);
      unawaited(showRoxieReaction(RoxieState.correct));

      await Future.delayed(const Duration(milliseconds: 1100));

      if (_round >= _kTotalRounds) {
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

        await PuzzleProgressService.instance.markLevelComplete(widget.level);

        if (mounted) setState(() => _showWinDialog = true);
      } else {
        await _enterCtrl.reverse();
        setState(() {
          _round++;
          _startRound();
        });
      }
    } else {
      unawaited(showRoxieReaction(RoxieState.wrong));
      setState(() {
        _wrongFlash = true;
        _wrongIndex = index;
      });
      _shakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        setState(() {
          _firstSelectedIndex = null;
          _secondSelectedIndex = null;
          _wrongFlash = false;
          _wrongIndex = null;
        });
      }
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
              Align(alignment: Alignment.center, child: PuzzleGameHeader(title: 'Find the Pair')),
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

  /// Small non-interactive demo grid showing two identical apples among
  /// different objects, teaching the "find the matching pair" mechanic
  /// before play.
  Widget _buildIntroPreview() {
    const previewItems = ['apple', 'banana', 'apple', 'ball'];
    const previewMatch = 'apple';

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: previewItems.map((object) {
          final isMatch = object == previewMatch;

          Widget card = Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isMatch
                    ? PuzzleColorTheme.sunnyhue
                    : PuzzleColorTheme.darkdesaturatedblue
                    .withValues(alpha: 0.30),
                width: isMatch ? 3 : 2.5,
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
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
          );

          if (isMatch) {
            card = ScaleTransition(
              scale: _previewPulse,
              child: card,
            );
          }

          return card;
        }).toList(),
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
                Align(
                  alignment: Alignment.center,
                  child: PuzzleGameInstruction(
                    instruction: 'Find the two objects that are the same!',
                  ),
                ),
                Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
              ],
            ),
          ),
          Expanded(child: _buildGameArea()),
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
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 20,
        children: List.generate(
          _choices.length,
          (i) => KeyedSubtree(
            key: ValueKey('$i-${_choices[i]}'),
            child: _buildObjectCard(i),
          ),
        ),
      ),
    );
  }

  Widget _buildObjectCard(int index) {
    final object = _choices[index];
    final isFirstSelected = index == _firstSelectedIndex && !_roundComplete;
    final isWrongTap = _wrongFlash && index == _wrongIndex;
    final isMatchedPair = _roundComplete &&
        (index == _firstSelectedIndex || index == _secondSelectedIndex);
    final isDimmed = _roundComplete && !isMatchedPair;

    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28);
    Color bgColor = Colors.white.withValues(alpha: 0.85);

    if (isFirstSelected) {
      borderColor = PuzzleColorTheme.sunnyhue;
    }
    if (isWrongTap) {
      borderColor = const Color(0xFFE05A5A);
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.10);
    }
    if (isMatchedPair) {
      borderColor = PuzzleColorTheme.sunnyhue;
      bgColor = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28);
    }

    Widget image = Image.asset(
      '$_objectAssetPath/$object.png',
      width: 72,
      height: 72,
      fit: BoxFit.contain,
      color: isDimmed ? PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.25) : null,
      colorBlendMode: isDimmed ? BlendMode.modulate : null,
    );

    if (isMatchedPair) {
      image = ScaleTransition(scale: _bounceAnim, child: image);
    }

    Widget card = AnimatedBuilder(
      animation: _revealAnim,
      builder: (_, child) => Container(
        width: 105,
        height: 105,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: isMatchedPair
                  ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.35 * _revealAnim.value)
                  : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
              blurRadius: isMatchedPair ? 16 : 10,
              spreadRadius: isMatchedPair ? 1 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
      child: Center(child: image),
    );

    if (isFirstSelected) {
      card = ScaleTransition(scale: _selectAnim, child: card);
    }

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

    return GestureDetector(
      onTap: () => _onObjectTapped(index),
      child: card,
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        // TODO: replace with the next game in the Puzzle Glade sequence.
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FindThePairScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
