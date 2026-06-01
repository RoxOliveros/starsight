import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_level.dart';
import '../../ui_layer/puzzle_glade/Puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl17_spot_the_difference.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, memorize, recall, result }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAllObjects = [
  'compass', 'jar', 'lamp', 'magnifying_glass', 'map',
  'pen', 'notebook', 'puzzle_piece', 'star', 'telescope', 'water_bottle',
];

const int _kTotalRounds = 5;
const int _kMemorizeSeconds = 10;
const int _kGridSize = 3; // 2 objects per round

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Lvl20CopyPattern2Screen extends StatefulWidget {
  const Lvl20CopyPattern2Screen({super.key});

  @override
  State<Lvl20CopyPattern2Screen> createState() => _Lvl20CopyPattern2ScreenState();
}

class _Lvl20CopyPattern2ScreenState extends State<Lvl20CopyPattern2Screen>
    with TickerProviderStateMixin {

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage =
      'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/level16/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level16/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level16/instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/level16/complete.wav';
  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioBubblePop = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  _ScreenPhase _phase = _ScreenPhase.intro;
  int _round = 1;
  int _memorizeCountdown = _kMemorizeSeconds;
  Timer? _memorizeTimer;

  /// The 2 objects to memorize this round (in order)
  List<String> _patternObjects = [];

  /// The answer slots the child fills (null = empty)
  List<String?> _answerSlots = [null, null, null];

  /// Available choices shown at bottom (shuffled pool)
  List<String> _choices = [];

  bool _showWinDialog = false;
  bool _roundCorrect = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _roxieFloatCtrl;
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;
  late AnimationController _phaseCtrl;
  late Animation<double> _phaseAnim;
  late AnimationController _countdownCtrl;
  late AnimationController _correctPulseCtrl;

  // Per-slot shake for wrong answer
  late List<AnimationController> _slotShakeCtrl;
  late List<Animation<double>> _slotShakeAnim;

  // Per-slot bounce for correct
  late List<AnimationController> _slotBounceCtrl;
  late List<Animation<double>> _slotBounceAnim;

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
    _memorizeTimer?.cancel();
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _gameEnterCtrl.dispose();
    _phaseCtrl.dispose();
    _countdownCtrl.dispose();
    _correctPulseCtrl.dispose();
    for (final c in _slotShakeCtrl) {
      c.dispose();
    }
    for (final c in _slotBounceCtrl) {
      c.dispose();
    }
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Animation init ─────────────────────────────────────────────────────────

  void _initAnimations() {
    _roxieFloatCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _roxieSlideCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    );
    _roxieSlide = Tween<Offset>(
      begin: const Offset(0, 1.6), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut));
    _roxieFade = CurvedAnimation(
      parent: _roxieSlideCtrl, curve: const Interval(0, 0.4),
    );

    _gameEnterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _phaseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _phaseAnim = CurvedAnimation(parent: _phaseCtrl, curve: Curves.easeOut);

    _countdownCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );

    _correctPulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );

    _slotShakeCtrl = List.generate(
      _kGridSize,
          (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400)),
    );
    _slotShakeAnim = _slotShakeCtrl.map((c) =>
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: c, curve: Curves.elasticOut),
        ),
    ).toList();

    _slotBounceCtrl = List.generate(
      _kGridSize,
          (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 450)),
    );
    _slotBounceAnim = _slotBounceCtrl.map((c) =>
        Tween<double>(begin: 1.0, end: 1.18).animate(
          CurvedAnimation(parent: c, curve: Curves.elasticOut),
        ),
    ).toList();
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();
    await _playAudio(_audioIntro);
    await _playAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));
    _gameEnterCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _phase = _ScreenPhase.memorize);
    await Future.delayed(const Duration(milliseconds: 100));
    _startRound();
    await _playAudio(_audioInstructions);
  }

  Future<void> _playAudio(String asset) async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      final completer = Completer<void>();
      final sub = player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 20));
      await sub.cancel();
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await player.stop();
      await player.dispose();
    }
  }

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);
    _patternObjects = shuffled.take(_kGridSize).toList();

    // Build choices: correct answers + 1 distractors, shuffled
    final distractors = shuffled.skip(_kGridSize).take(2).toList();
    _choices = [..._patternObjects, ...distractors]..shuffle(rng);

    _answerSlots = List.filled(_kGridSize, null);
    _roundCorrect = false;

    for (final c in _slotShakeCtrl) {
      c.reset();
    }
    for (final c in _slotBounceCtrl) {
      c.reset();
    }
    _correctPulseCtrl.stop();
    _correctPulseCtrl.reset();

    _memorizeCountdown = _kMemorizeSeconds;
    _phaseCtrl.forward(from: 0);

    if (mounted) setState(() => _phase = _ScreenPhase.memorize);
    _startMemorizeTimer();
  }

  void _startMemorizeTimer() {
    _memorizeTimer?.cancel();
    _memorizeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _memorizeCountdown--);
      if (_memorizeCountdown <= 0) {
        t.cancel();
        _transitionToRecall();
      }
    });
  }

  void _transitionToRecall() async {
    await _phaseCtrl.reverse();
    if (mounted) setState(() => _phase = _ScreenPhase.recall);
    _phaseCtrl.forward(from: 0);
  }

  // ── Answer logic ──────────────────────────────────────────────────────────

  void _onChoiceTapped(String object) async {
    if (_phase != _ScreenPhase.recall) return;

    // Find first empty slot
    final emptyIndex = _answerSlots.indexWhere((s) => s == null);
    if (emptyIndex == -1) return;

    _sfxPlayer.play(AssetSource(_audioBubblePop.replaceFirst('assets/', '')));

    setState(() {
      _answerSlots[emptyIndex] = object;
    });
    _slotBounceCtrl[emptyIndex].forward(from: 0);

    // Check if all filled
    if (_answerSlots.every((s) => s != null)) {
      await Future.delayed(const Duration(milliseconds: 300));
      _checkAnswer();
    }
  }

  void _onAnswerSlotTapped(int index) {
    if (_phase != _ScreenPhase.recall) return;
    if (_answerSlots[index] == null) return;

    // Remove item from slot (put back)
    _sfxPlayer.play(AssetSource(_audioBubblePop.replaceFirst('assets/', '')));
    setState(() => _answerSlots[index] = null);
  }

  void _checkAnswer() async {
    bool correct = true;
    for (int i = 0; i < _kGridSize; i++) {
      if (_answerSlots[i] != _patternObjects[i]) {
        correct = false;
        break;
      }
    }

    if (correct) {
      setState(() { _roundCorrect = true; _phase = _ScreenPhase.result; });
      _correctPulseCtrl.repeat(reverse: true);
      _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
      await Future.delayed(const Duration(milliseconds: 1600));

      if (_round >= _kTotalRounds) {
        await _sfxPlayer.stop();
        final completer = Completer<void>();
        final sub = _completePlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        await _completePlayer.play(AssetSource(_audioComplete.replaceFirst('assets/', '')));
        await completer.future.timeout(const Duration(seconds: 15));
        await sub.cancel();
        if (mounted) setState(() => _showWinDialog = true);
      } else {
        await _phaseCtrl.reverse();
        if (mounted) setState(() { _round++; _startRound(); });
      }
    } else {
      // Wrong — shake wrong slots and clear
      for (int i = 0; i < _kGridSize; i++) {
        if (_answerSlots[i] != _patternObjects[i]) {
          _slotShakeCtrl[i].forward(from: 0);
        }
      }
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _answerSlots = List.filled(_kGridSize, null));
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
                Image.asset(_bgImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Container(color: Colors.black.withValues(alpha: 0.15)),
              ],
            ),
          ),
          SafeArea(
            child: _phase == _ScreenPhase.intro
                ? _buildIntroContent()
                : FadeTransition(
              opacity: _gameFade,
              child: _buildGameContent(),
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
              Expanded(flex: 6, child: _buildIntroPreview()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroRoxie() {
    return LayoutBuilder(builder: (context, constraints) {
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
                  offset: Offset(0, floatY), child: child,
                ),
                child: Image.asset(_characterImage,
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
    });
  }

  Widget _buildIntroPreview() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pattern side
          _buildPreviewGrid(revealed: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.arrow_forward_rounded,
                size: 36, color: Colors.white.withValues(alpha: 0.8)),
          ),
          // Recall side
          _buildPreviewGrid(revealed: false),
        ],
      ),
    );
  }

  Widget _buildPreviewGrid({required bool revealed}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            revealed ? 'Memorize!' : 'Recall!',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: JarColorTheme.darkdesaturatedblue,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(_kGridSize, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: revealed ? 0.9 : 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: revealed
                  ? Image.asset(
                'assets/images/objects/puzzle/star.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.star, color: Colors.amber),
              )
                  : Icon(Icons.question_mark_rounded,
                  color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.4),
                  size: 28),
            );
          }),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameContent() {
    return FadeTransition(
      opacity: _phaseAnim,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildGameHeader(),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                _buildRoxieSide(),
                Expanded(child: _buildMainArea()),
              ],
            ),
          ),
          _buildProgressDots(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGameHeader() {
    final phaseLabel = _phase == _ScreenPhase.memorize
        ? 'Remember!'
        : _phase == _ScreenPhase.result
        ? _roundCorrect ? 'Tama!' : 'Subukan ulit!'
        : 'Ano ang pattern?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 48,
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
              ),
              child: Text(
                'Copy the Pattern',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 20,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _phase == _ScreenPhase.memorize
                      ? JarColorTheme.sunnyhue.withValues(alpha: 0.9)
                      : _roundCorrect
                      ? Colors.green.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  phaseLabel,
                  style: TextStyle(
                    fontFamily: JarAppTextStyles.fredoka,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _phase == _ScreenPhase.memorize
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoxieSide() {
    return SizedBox(
      width: 90,
      child: LayoutBuilder(builder: (context, constraints) {
        final floatY = Tween<double>(begin: -6, end: 6).evaluate(
          CurvedAnimation(parent: _roxieFloatCtrl, curve: Curves.easeInOut),
        );
        return AnimatedBuilder(
          animation: _roxieFloatCtrl,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, floatY), child: child,
          ),
          child: Image.asset(
            _characterImage,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
            const Text('🐰', style: TextStyle(fontSize: 48)),
          ),
        );
      }),
    );
  }

  Widget _buildMainArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_phase == _ScreenPhase.memorize) _buildMemorizeView(),
        if (_phase == _ScreenPhase.recall || _phase == _ScreenPhase.result)
          _buildRecallView(),
      ],
    );
  }

  // ── Memorize view ──────────────────────────────────────────────────────────

  Widget _buildMemorizeView() {
    if (_patternObjects.length < _kGridSize) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Countdown bar
        _buildCountdownBar(),
        const SizedBox(height: 20),
        // Pattern display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_kGridSize, (i) {
            return AnimatedBuilder(
              animation: _roxieFloatCtrl,
              builder: (_, child) {
                final nudge = sin(_roxieFloatCtrl.value * pi * 2 + i) * 3.0;
                return Transform.translate(
                  offset: Offset(0, nudge), child: child,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: JarColorTheme.sunnyhue.withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/images/objects/puzzle/${_patternObjects[i]}.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Text('?', style: TextStyle(fontSize: 40)),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(
          'Tandaan ang pagkakasunod!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownBar() {
    return Column(
      children: [
        Text(
          '$_memorizeCountdown',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 260,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _memorizeCountdown / _kMemorizeSeconds,
            child: Container(
              decoration: BoxDecoration(
                color: JarColorTheme.sunnyhue,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Recall view ────────────────────────────────────────────────────────────

  Widget _buildRecallView() {
    if (_patternObjects.length < _kGridSize || _answerSlots.length < _kGridSize) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Answer slots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_kGridSize, (i) => _buildAnswerSlot(i)),
        ),
        const SizedBox(height: 20),
        // Divider hint
        Text(
          _phase == _ScreenPhase.result
              ? (_roundCorrect ? '🌟 Tama! Magaling!' : '')
              : 'Piliin sa tamang pagkakasunod',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 14),
        // Choice buttons
        if (_phase == _ScreenPhase.recall) _buildChoices(),
      ],
    );
  }

  Widget _buildAnswerSlot(int index) {
    final item = _answerSlots[index];
    final isCorrect = _phase == _ScreenPhase.result &&
        _answerSlots[index] == _patternObjects[index];
    final isWrong = _phase == _ScreenPhase.result &&
        _answerSlots[index] != null &&
        _answerSlots[index] != _patternObjects[index];

    return AnimatedBuilder(
      animation: Listenable.merge([_slotShakeAnim[index], _slotBounceAnim[index]]),
      builder: (_, child) {
        final shake = sin(_slotShakeAnim[index].value * pi * 6) * 6;
        final scale = _slotBounceAnim[index].value;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GestureDetector(
        onTap: () => _onAnswerSlotTapped(index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: isCorrect
                ? Colors.green.withValues(alpha: 0.25)
                : isWrong
                ? Colors.red.withValues(alpha: 0.25)
                : item != null
                ? Colors.white.withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCorrect
                  ? Colors.green
                  : isWrong
                  ? Colors.red
                  : item != null
                  ? JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.4)
                  : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.2),
              width: isCorrect || isWrong ? 3 : 2,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: item != null
              ? Image.asset(
            'assets/images/objects/puzzle/$item.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(),
          )
              : Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: JarAppTextStyles.fredoka,
                fontSize: 28,
                color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoices() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _choices.map((obj) {
        final isUsed = _answerSlots.contains(obj);
        return GestureDetector(
          onTap: isUsed ? null : () => _onChoiceTapped(obj),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isUsed ? 0.3 : 1.0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isUsed ? 0.4 : 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/images/objects/puzzle/$obj.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

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
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(builder: (_) => const ()),
        // ); TODO
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Lvl20CopyPattern2Screen()),
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