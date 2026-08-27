import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_audio_helper.dart';
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
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Sequence pool
// ─────────────────────────────────────────────────────────────────────────────

class _SequenceStep {
  final String id;
  final String label;
  final String asset;
  final String emoji; // fallback if the asset can't be loaded

  const _SequenceStep({
    required this.id,
    required this.label,
    required this.asset,
    required this.emoji,
  });
}

class _SequenceSet {
  final String id;
  final String title;
  final List<_SequenceStep> steps;

  const _SequenceSet({
    required this.id,
    required this.title,
    required this.steps,
  });
}

const List<_SequenceSet> _sequencePool = [
  // ── 3-step sequences ──────────────────────────────────────────────────────
  _SequenceSet(
    id: 'seed_flower',
    title: 'From Seed to Flower',
    steps: [
      _SequenceStep(id: 'seed', label: 'Seed', asset: 'assets/images/objects/puzzle/seed.png', emoji: '🌰'),
      _SequenceStep(id: 'sprout', label: 'Sprout', asset: 'assets/images/objects/puzzle/sprout.png', emoji: '🌱'),
      _SequenceStep(id: 'flower', label: 'Flower', asset: 'assets/images/objects/puzzle/flower.png', emoji: '🌸'),
    ],
  ),
  _SequenceSet(
    id: 'egg_chicken',
    title: 'From Egg to Chicken',
    steps: [
      _SequenceStep(id: 'egg', label: 'Egg', asset: 'assets/images/objects/lumi/egg.png', emoji: '🥚'),
      _SequenceStep(id: 'chick', label: 'Chick', asset: 'assets/images/characters/chicken.png', emoji: '🐣'),
      _SequenceStep(id: 'chicken', label: 'Chicken', asset: 'assets/images/characters/mom_chichken.png', emoji: '🐔'),
    ],
  ),
  _SequenceSet(
    id: 'caterpillar_butterfly',
    title: 'From Caterpillar to Butterfly',
    steps: [
      _SequenceStep(id: 'caterpillar', label: 'Caterpillar', asset: 'assets/images/objects/puzzle/caterpillar.png', emoji: '🐛'),
      _SequenceStep(id: 'cocoon', label: 'Cocoon', asset: 'assets/images/objects/puzzle/cocoon.png', emoji: '🤎'),
      _SequenceStep(id: 'butterfly', label: 'Butterfly', asset: 'assets/images/objects/puzzle/butterfly.png', emoji: '🦋'),
    ],
  ),
  // ── 4-step sequences ──────────────────────────────────────────────────────
  _SequenceSet(
    id: 'sun_day',
    title: 'A Day in the Sky',
    steps: [
      _SequenceStep(id: 'sunrise', label: 'Sunrise', asset: 'assets/images/objects/puzzle/sunrise.png', emoji: '🌅'),
      _SequenceStep(id: 'noon', label: 'Noon', asset: 'assets/images/objects/puzzle/noon.png', emoji: '☀️'),
      _SequenceStep(id: 'sunset', label: 'Sunset', asset: 'assets/images/objects/puzzle/sunset.png', emoji: '🌇'),
      _SequenceStep(id: 'night', label: 'Night', asset: 'assets/images/objects/puzzle/night.png', emoji: '🌙'),
    ],
  ),
  // ── 5-step sequence (hardest round) ──────────────────────────────────────
  _SequenceSet(
    id: 'frog_life',
    title: 'The Life of a Frog',
    steps: [
      _SequenceStep(id: 'frogegg', label: 'Egg', asset: 'assets/images/objects/puzzle/frogegg.png', emoji: '🥚'),
      _SequenceStep(id: 'tadpole', label: 'Tadpole', asset: 'assets/images/objects/puzzle/tadpole.png', emoji: '🐟'),
      _SequenceStep(id: 'froglet', label: 'Froglet', asset: 'assets/images/objects/puzzle/froglet.png', emoji: '🐸'),
      _SequenceStep(id: 'frog', label: 'Frog', asset: 'assets/images/objects/puzzle/frog.png', emoji: '🐸'),
      _SequenceStep(id: 'frog_on_lilypad', label: 'On a Lily Pad', asset: 'assets/images/objects/puzzle/frog_on_lilypad.png', emoji: '🪷'),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Difficulty
// ─────────────────────────────────────────────────────────────────────────────

int _stepCountForRound(int round) {
  switch (round) {
    case 1:
      return 3;
    case 2:
      return 3;
    case 3:
      return 3;
    case 4:
      return 4;
    default:
      return 5;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class WhichComesFirstScreen extends StatefulWidget {
  final int level;

  const WhichComesFirstScreen({super.key, required this.level});

  @override
  State<WhichComesFirstScreen> createState() => _WhichComesFirstScreenState();
}

class _WhichComesFirstScreenState extends State<WhichComesFirstScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<WhichComesFirstScreen>, GameLoadingMixin, PuzzleAudioMixin {
  @override
  AudioPlayer get roxiePlayer => _roxieSfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/which_comes_first_intro.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/which_comes_first_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/which_comes_first_complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round / puzzle state ──────────────────────────────────────────────────
  int _round = 1;
  final Set<String> _usedSequenceIds = {};
  _SequenceSet? _currentSequence;
  List<_SequenceStep?> _slots = [];
  List<_SequenceStep> _tray = [];
  bool _isWrongFlash = false;
  bool _isCompleting = false;
  DateTime? _lastWrongFeedback;
  bool _showWinDialog = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _roxieSfxPlayer = AudioPlayer(); // dedicated player for RoxieReactionMixin

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _demoCtrl;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  // Feedback
  late AnimationController _wiggleCtrl; // gentle "not quite" feedback
  late AnimationController _celebrateCtrl; // success bounce + star burst

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
    _roxieSfxPlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _demoCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _wiggleCtrl.dispose();
    _celebrateCtrl.dispose();
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

    _demoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

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

    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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
    final targetCount = _stepCountForRound(_round);

    var candidates = _sequencePool
        .where((s) => s.steps.length == targetCount && !_usedSequenceIds.contains(s.id))
        .toList();
    if (candidates.isEmpty) {
      // Ran out of unused sets at this length — allow reuse rather than stall.
      candidates = _sequencePool.where((s) => s.steps.length == targetCount).toList();
    }

    final chosen = candidates[rng.nextInt(candidates.length)];
    _usedSequenceIds.add(chosen.id);

    setState(() {
      _currentSequence = chosen;
      _slots = List<_SequenceStep?>.filled(chosen.steps.length, null, growable: false);
      _tray = _shuffledSteps(chosen.steps, rng);
      _isWrongFlash = false;
      _isCompleting = false;
    });

    _enterCtrl.forward(from: 0);
  }

  List<_SequenceStep> _shuffledSteps(List<_SequenceStep> steps, Random rng) {
    if (steps.length <= 1) return List<_SequenceStep>.from(steps);
    var shuffled = List<_SequenceStep>.from(steps);
    do {
      shuffled = List<_SequenceStep>.from(steps)..shuffle(rng);
    } while (_isSameOrder(shuffled, steps));
    return shuffled;
  }

  bool _isSameOrder(List<_SequenceStep> a, List<_SequenceStep> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // ── Drag & drop handling ────────────────────────────────────────────────────

  void _onStepDroppedOnSlot(_SequenceStep step, int slotIndex) {
    if (_isCompleting) return;
    setState(() {
      final existing = _slots[slotIndex];
      if (existing != null && existing.id != step.id) {
        _tray.add(existing);
      }
      _slots[slotIndex] = step;
      _tray.removeWhere((s) => s.id == step.id);
    });

    if (!_slots.contains(null)) {
      _checkOrder();
    }
  }

  void _onSlotTapped(int slotIndex) {
    if (_isCompleting) return;
    final step = _slots[slotIndex];
    if (step == null) return;
    setState(() {
      _slots[slotIndex] = null;
      _tray.add(step);
    });
  }

  void _checkOrder() {
    final target = _currentSequence?.steps;
    if (target == null) return;

    var allCorrect = true;
    final misplaced = <_SequenceStep>[];

    setState(() {
      for (var i = 0; i < target.length; i++) {
        final placed = _slots[i];
        if (placed == null) continue;
        if (placed.id != target[i].id) {
          allCorrect = false;
          misplaced.add(placed);
          _slots[i] = null;
        }
      }
      if (!allCorrect) _tray.addAll(misplaced);
    });

    if (allCorrect) {
      _handleCorrectOrder();
    } else {
      _handleWrongOrder();
    }
  }

  void _handleWrongOrder() {
    final now = DateTime.now();
    if (_lastWrongFeedback != null &&
        now.difference(_lastWrongFeedback!) < const Duration(milliseconds: 500)) {
      return; // debounce rapid attempts
    }
    _lastWrongFeedback = now;

    unawaited(showRoxieReaction(RoxieState.wrong));
    setState(() => _isWrongFlash = true);
    _wiggleCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isWrongFlash = false);
    });
  }

  Future<void> _handleCorrectOrder() async {
    setState(() => _isCompleting = true);
    unawaited(showRoxieReaction(RoxieState.correct));
    await _celebrateCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    await _advanceRound();
  }

  Future<void> _advanceRound() async {
    if (_round >= _kTotalRounds) {
      await _completeRound();
      return;
    }

    await _enterCtrl.reverse();
    if (!mounted) return;
    setState(() => _round++);
    _startRound();
  }

  Future<void> _completeRound() async {
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
              Align(alignment: Alignment.center, child: PuzzleGameHeader(title: 'Which Comes First?')),
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

  // Small preview: seed → sprout → flower with a hand icon "dragging" the
  // middle picture, teasing the ordering mechanic before the round starts.
  Widget _buildIntroPreview() {
    const demoSteps = [
      _SequenceStep(id: 'seed', label: 'Seed', asset: 'assets/images/objects/puzzle/seed.png', emoji: '🌰'),
      _SequenceStep(id: 'sprout', label: 'Sprout', asset: 'assets/images/objects/puzzle/sprout.png', emoji: '🌱'),
      _SequenceStep(id: 'flower', label: 'Flower', asset: 'assets/images/objects/puzzle/flower.png', emoji: '🌸'),
    ];
    return AnimatedBuilder(
      animation: _demoCtrl,
      builder: (_, __) {
        final bob = Tween<double>(begin: 0, end: -10).evaluate(
          CurvedAnimation(parent: _demoCtrl, curve: Curves.easeInOut),
        );
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.30),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < demoSteps.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.5),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(0, i == 1 ? bob : 0),
                    child: _StepImage(step: demoSteps[i], size: 60),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameLayer() {
    final sequence = _currentSequence;
    if (sequence == null) return const SizedBox.shrink();

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
          Expanded(child: Center(child: _buildGameArea())),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth * 0.92;
        final maxH = constraints.maxHeight * 0.92;

        return Container(
          width: maxW,
          height: maxH,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_celebrateCtrl, _wiggleCtrl]),
                    builder: (context, child) {
                      final wiggle = _isWrongFlash
                          ? sin(_wiggleCtrl.value * pi * 6) * 8 * (1 - _wiggleCtrl.value)
                          : 0.0;
                      final bounce = _celebrateCtrl.isAnimating
                          ? 1.0 + (sin(_celebrateCtrl.value * pi) * 0.15)
                          : 1.0;
                      return Transform.translate(
                        offset: Offset(wiggle, 0),
                        child: Transform.scale(
                          scale: bounce,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_celebrateCtrl.isAnimating) _buildStarBurst(),
                              child!,
                            ],
                          ),
                        ),
                      );
                    },
                    child: _buildSlotsRow(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildTrayRow(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _slots.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 26,
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 1),
              ),
            ),
          _buildSlot(i),
        ],
      ],
    );
  }

  Widget _buildSlot(int index) {
    return DragTarget<_SequenceStep>(
      onWillAccept: (data) => !_isCompleting,
      onAccept: (data) => _onStepDroppedOnSlot(data, index),
      builder: (context, candidateData, rejectedData) {
        final step = _slots[index];
        final highlighted = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () => _onSlotTapped(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: step != null
                  ? Colors.white.withValues(alpha: 0.9)
                  : PuzzleColorTheme.lightgrayishyellow.withValues(alpha: highlighted ? 0.9 : 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted
                    ? PuzzleColorTheme.goldenyellow
                    : PuzzleColorTheme.sunnyhue.withValues(alpha: 0.6),
                width: highlighted ? 4 : 3,
              ),
            ),
            alignment: Alignment.center,
            child: step != null
                ? _StepImage(step: step, size: 80)
                : Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: PuzzleAppTextStyles.fredoka,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: PuzzleColorTheme.sunnyhue.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrayRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: _tray.map((step) => _buildDraggableTrayItem(step)).toList(),
    );
  }

  Widget _buildDraggableTrayItem(_SequenceStep step) {
    return Draggable<_SequenceStep>(
      data: step,
      feedback: Material(
        color: Colors.transparent,
        child: _StepImage(step: step, size: 90, elevated: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _StepImage(step: step, size: 80),
      ),
      child: _StepImage(step: step, size: 80, elevated: true),
    );
  }

  Widget _buildStarBurst() {
    const count = 8;
    const colors = [
      PuzzleColorTheme.goldenyellow,
      PuzzleColorTheme.sunnyhue,
      PuzzleColorTheme.darkdesaturatedblue,
    ];
    return AnimatedBuilder(
      animation: _celebrateCtrl,
      builder: (_, __) {
        final progress = _celebrateCtrl.value;
        return Stack(
          alignment: Alignment.center,
          children: List.generate(count, (i) {
            final angle = (2 * pi / count) * i;
            final dist = 100 * progress;
            final opacity = (1 - progress).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(cos(angle) * dist, sin(angle) * dist),
              child: Opacity(
                opacity: opacity,
                child: Icon(
                  Icons.star_rounded,
                  color: colors[i % colors.length],
                  size: 26,
                ),
              ),
            );
          }),
        );
      },
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
            builder: (context) => WhichComesFirstScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step image widget
// ─────────────────────────────────────────────────────────────────────────────

class _StepImage extends StatelessWidget {
  final _SequenceStep step;
  final double size;
  final bool elevated;
  final bool faded;

  const _StepImage({
    required this.step,
    required this.size,
    this.elevated = false,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: elevated
          ? BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      )
          : null,
      child: Opacity(
        opacity: faded ? 0.55 : 1.0,
        child: Image.asset(
          step.asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Text(step.emoji, style: TextStyle(fontSize: size * 0.7)),
          ),
        ),
      ),
    );
  }
}