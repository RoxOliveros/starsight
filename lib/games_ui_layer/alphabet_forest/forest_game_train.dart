import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_buttons.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'alphabet_game_ui.dart';
import 'alphabet_intro.dart';
import 'forest_audio_helper.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

// ═════════════════════════════════════════════════════════════════════════
// MODELS
// ═════════════════════════════════════════════════════════════════════════

/// One round's alphabet sequence: a contiguous run of letters with exactly
/// one gap, plus the shuffled answer cards (one correct, the rest unique
/// distractors that never collide with any letter already on-screen).
class _TrainRound {
  final List<String> sequence;
  final int missingIndex;
  final String correctLetter;
  final List<String> choices;

  const _TrainRound({
    required this.sequence,
    required this.missingIndex,
    required this.correctLetter,
    required this.choices,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// GAME
// ═════════════════════════════════════════════════════════════════════════

class AlphabetTrainGame extends StatefulWidget {
  final int level;
  const AlphabetTrainGame({super.key, required this.level});

  @override
  State<AlphabetTrainGame> createState() => _AlphabetTrainGameState();
}

class _AlphabetTrainGameState extends State<AlphabetTrainGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<AlphabetTrainGame>,
        ForestAudioMixin<AlphabetTrainGame>,
        TofiReactionMixin<AlphabetTrainGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ── ASSETS ───────────────────────────────────────────────────────────────
  // The train itself is built entirely from Flutter widgets (containers,
  // text, circles) so no new train artwork is required — only the existing
  // forest background and Tofi are reused.
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest_train_path.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _trainHeadImage = 'assets/images/objects/forest/train_head.png';
  static const String _trainWagonImage = 'assets/images/objects/forest/train_wagon.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/alphabet_train_intro.wav';
  static const String _audioInstruction = '$_audioBase/alphabet_train_instruction.wav';
  static const String _audioCorrect = '$_audioBase/alphabet_train_correct.wav';
  static const String _audioRoundComplete = '$_audioBase/alphabet_train_round_complete.wav';
  static const String _audioWin = '$_audioBase/alphabet_train_win.wav';

  // ── GAME STRUCTURE ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  // ── STATE ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRoundIndex = 0;
  int _solvedRounds = 0;
  bool _roundLocked = false; // guards against multiple/rapid completions
  bool _slotFilled = false; // the missing car has just received its letter
  bool _celebrating = false;

  late _TrainRound _round;
  String? _shakingChoice; // letter card currently shaking on a wrong drop
  bool _missingShaking = false; // missing car shake on a wrong drop

  // ── ANIMATIONS ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl; // dog idle float, intro only
  late AnimationController _trainBobCtrl; // idle train + card float
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _missingPulseCtrl; // glow/pulse on the empty car
  late AnimationController _carBounceCtrl; // correct-drop car bounce + sparkle
  late Animation<double> _carBounce;
  late AnimationController _choiceShakeCtrl; // shared wrong-answer shake
  late Animation<double> _choiceShake;
  late AnimationController _trainNudgeCtrl; // small forward nudge after a round

  // ── INITIALIZATION ───────────────────────────────────────────────────────
  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();

    _initAnimations();
    _round = _generateRoundForIndex(0);
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _trainBobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _instructionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _instructionBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut));

    _sceneEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sceneEnter = CurvedAnimation(parent: _sceneEnterCtrl, curve: Curves.elasticOut);

    _missingPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _carBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _carBounce = CurvedAnimation(parent: _carBounceCtrl, curve: Curves.elasticOut);

    _choiceShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _choiceShake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.09), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.09, end: 0.09), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.09, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _choiceShakeCtrl, curve: Curves.easeInOut));

    _trainNudgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  // ── INTRO FLOW ───────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Instruction audio plays automatically ONLY on round 1 — rounds 2-5
    // rely on the tappable instruction banner instead.
    await playVoice(_audioInstruction);
  }

  // ── ROUND SETUP ──────────────────────────────────────────────────────────
  void _setupRound() {
    _roundLocked = false;
    _slotFilled = false;
    _celebrating = false;
    _shakingChoice = null;
    _missingShaking = false;

    _round = _generateRoundForIndex(_currentRoundIndex);

    _carBounceCtrl.reset();
    _trainNudgeCtrl.reset();
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    setState(() {});
  }

  // ── SEQUENCE GENERATION ──────────────────────────────────────────────────
  _TrainRound _generateRoundForIndex(int roundIndex) {
    switch (roundIndex) {
      case 0: // 3-letter sequence, 2 choices — very easy, fixed middle gap
        return _generateRound(length: 3, choiceCount: 2, fixedMissingIndex: 1);
      case 1: // 4-letter sequence, 3 choices
        return _generateRound(length: 4, choiceCount: 3, fixedMissingIndex: 2);
      case 2: // 4-letter sequence, 3 choices — gap position randomized
        return _generateRound(length: 4, choiceCount: 3);
      case 3: // 5-letter sequence, 4 choices
        return _generateRound(length: 5, choiceCount: 4);
      case 4: // 5-letter sequence, 4 choices — interior-only gap for a bit more challenge
      default:
        return _generateRound(length: 5, choiceCount: 4, interiorOnly: true);
    }
  }

  /// Builds a contiguous alphabet run of [length] letters with exactly one
  /// gap, plus [choiceCount] total answer cards (the correct letter and
  /// unique, non-sequence distractors), shuffled. Guarantees exactly one
  /// valid answer — distractors can never equal the correct letter or any
  /// other letter already visible in the sequence.
  _TrainRound _generateRound({
    required int length,
    required int choiceCount,
    int? fixedMissingIndex,
    bool interiorOnly = false,
  }) {
    final rand = Random();

    final maxStart = 26 - length; // 'A' = 0 ... 'Z' = 25
    final startCode = rand.nextInt(maxStart + 1);
    final sequence = List.generate(length, (i) => String.fromCharCode(65 + startCode + i));

    int missingIndex;
    if (fixedMissingIndex != null) {
      missingIndex = fixedMissingIndex.clamp(0, length - 1);
    } else if (interiorOnly && length > 2) {
      missingIndex = 1 + rand.nextInt(length - 2);
    } else {
      missingIndex = rand.nextInt(length);
    }

    final correctLetter = sequence[missingIndex];

    final usedLetters = sequence.toSet();
    final distractors = <String>{};
    while (distractors.length < choiceCount - 1) {
      final letter = String.fromCharCode(65 + rand.nextInt(26));
      if (letter == correctLetter) continue;
      if (usedLetters.contains(letter)) continue;
      if (distractors.contains(letter)) continue;
      distractors.add(letter);
    }

    final choices = [correctLetter, ...distractors]..shuffle(rand);

    return _TrainRound(
      sequence: sequence,
      missingIndex: missingIndex,
      correctLetter: correctLetter,
      choices: choices,
    );
  }

  // ── DRAG AND DROP / CORRECT ANSWER ───────────────────────────────────────
  Future<void> _handleCorrectAnswer() async {
    if (_roundLocked) return; // multiple rapid drops can't double-complete

    _roundLocked = true;
    HapticFeedback.mediumImpact();

    setState(() => _slotFilled = true);
    _carBounceCtrl.forward(from: 0);
    playVoice(_audioCorrect);

    showTofiReaction(TofiState.correct);
    if (!mounted) return;

    setState(() => _celebrating = true);
    _trainNudgeCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    await _advanceRound();
  }

  // ── WRONG ANSWER ─────────────────────────────────────────────────────────
  Future<void> _handleWrongAnswer(String letter) async {
    if (_roundLocked) return;

    HapticFeedback.heavyImpact();

    setState(() {
      _shakingChoice = letter;
      _missingShaking = true;
    });

    _choiceShakeCtrl.forward(from: 0);

    await showTofiReaction(TofiState.wrong);
    if (!mounted) return;

    setState(() {
      _shakingChoice = null;
      _missingShaking = false;
    });
  }

  // ── ROUND PROGRESSION ────────────────────────────────────────────────────
  Future<void> _advanceRound() async {
    _solvedRounds++;

    if (_currentRoundIndex >= _totalRounds - 1) {
      await playVoice(_audioWin);
      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;

      _showGoodJob();
      return;
    }

    await playVoice(_audioRoundComplete);
    if (!mounted) return;

    _currentRoundIndex++;
    _setupRound();
  }

  // ── GOOD JOB ─────────────────────────────────────────────────────────────
  void _showGoodJob() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: _dogImage,
          closeButtonColor: ForestColorTheme.seagreen,
          onNext: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              //TODO: @Tin fix nav
              MaterialPageRoute(
                builder: (_) => const AlphabetIntroScreen(letter: 'A'),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlphabetTrainGame(level: widget.level),
              ),
            );
          },
          onBack: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // ── DISPOSE ──────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _tofiFloatCtrl.dispose();
    _trainBobCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _missingPulseCtrl.dispose();
    _carBounceCtrl.dispose();
    _choiceShakeCtrl.dispose();
    _trainNudgeCtrl.dispose();
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.alphabetForest(),
        gameBuilder: () => Stack(
          children: [
            if (_introPlaying) _buildIntroLayer() else _buildGameContent(),
            if (!_introPlaying) buildTofi(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        const Positioned(top: 25, left: 20, child: ForestBackButton()),
        Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),
        Center(
          child: AnimatedBuilder(
            animation: _tofiFloatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                0,
                Tween<double>(begin: -6, end: 6).evaluate(
                  CurvedAnimation(parent: _tofiFloatCtrl, curve: Curves.easeInOut),
                ),
              ),
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _dogImage,
                  height: screenH * 0.5,
                  errorBuilder: (_, __, ___) => const Text('🐶', style: TextStyle(fontSize: 80)),
                ),
                const SizedBox(height: 120),
                Image.asset(
                  _trainHeadImage,
                  height: screenH * 0.5,
                  errorBuilder: (_, __, ___) => const Text('🐶', style: TextStyle(fontSize: 80)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        _buildGameUI(),
      ],
    );
  }

  Widget _buildGameUI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScaleTransition(
          scale: _sceneEnter,
          child: Stack(
            children: [
              const Positioned(top: 25, left: 20, child: ForestBackButton()),
              Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),
              _buildInstruction(),

              Padding(
                padding: const EdgeInsets.only(top: 90),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, inner) => _buildTrain(inner.maxWidth, inner.maxHeight),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: LayoutBuilder(
                        builder: (context, inner) => _buildLetterChoices(inner.maxWidth, inner.maxHeight),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _buildProgressDots(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── INSTRUCTION ──────────────────────────────────────────────────────────
  Widget _buildInstruction() {
    return Positioned(
      top: 25,
      left: 0,
      right: 0,
      child: Center(
        child: ScaleTransition(
          scale: _instructionBounce,
          child: GestureDetector(
            onTap: () => playVoice(_audioInstruction),
            child: const ForestInstructionBanner(
              text: 'Put the missing letter on the train!',
            ),
          ),
        ),
      ),
    );
  }

  // ── TRAIN ────────────────────────────────────────────────────────────────
  Widget _buildTrain(double w, double h) {
    final carSize = (h * 0.62).clamp(70.0, 110.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_trainBobCtrl, _trainNudgeCtrl]),
      builder: (_, child) {
        final bobY = 4 * sin(_trainBobCtrl.value * 2 * pi);
        final nudgeX = w * 1.3 * Curves.easeIn.transform(_trainNudgeCtrl.value);
        return Transform.translate(offset: Offset(nudgeX, bobY), child: child);
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < _round.sequence.length; i++)
                i == _round.missingIndex
                    ? (_slotFilled
                    ? _buildFilledCar(_round.correctLetter, carSize, justFilled: true)
                    : _buildMissingCar(carSize))
                    : _buildFilledCar(_round.sequence[i], carSize, justFilled: false),
              _buildEngine(carSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngine(double size) {
    return Container(
      width: size * 1.15,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Image.asset(
        _trainHeadImage,
        width: size * 1.15,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 16,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF6B4226),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildFilledCar(String letter, double size, {required bool justFilled}) {
    return AnimatedBuilder(
      animation: _carBounceCtrl,
      builder: (_, child) {
        final scale = justFilled ? (1.0 + 0.25 * _carBounce.value) : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Image.asset(_trainWagonImage, width: size, height: size, fit: BoxFit.contain),
            Text(
              letter,
              style: TextStyle(
                fontFamily: ForestAppTextStyles.fredoka,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.46,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.05
                  ..color = Colors.white,
              ),
            ),
            Text(
              letter,
              style: TextStyle(
                fontFamily: ForestAppTextStyles.fredoka,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.46,
                color: ForestColorTheme.darkseagreen,
              ),
            ),
            if (justFilled) _buildSparkles(size),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingCar(double size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_missingPulseCtrl, _choiceShakeCtrl]),
      builder: (_, child) {
        final pulse = 1.0 + 0.05 * _missingPulseCtrl.value;
        final shakeX = _missingShaking ? _choiceShake.value * 40 : 0.0;
        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: Transform.scale(scale: pulse, child: child),
        );
      },
      child: DragTarget<String>(
        onWillAccept: (data) => !_roundLocked && data == _round.correctLetter,
        onAccept: (_) => _handleCorrectAnswer(),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return Container(
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isHovering
                  ? ForestColorTheme.darkseagreen.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHovering ? ForestColorTheme.mediumseagreen : Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: ForestColorTheme.mediumseagreen.withValues(alpha: isHovering ? 0.6 : 0.25),
                  blurRadius: isHovering ? 16 : 8,
                  spreadRadius: isHovering ? 2 : 0,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Image.asset(_trainWagonImage, width: size, height: size, fit: BoxFit.contain,
                  color: isHovering ? ForestColorTheme.mediumseagreen : null,
                  colorBlendMode: isHovering ? BlendMode.modulate : null,
                ),
                Text(
                  '?',
                  style: TextStyle(
                    fontFamily: ForestAppTextStyles.fredoka,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.46,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = size * 0.05
                      ..color = Colors.white,
                  ),
                ),
                Text(
                  '?',
                  style: TextStyle(
                    fontFamily: ForestAppTextStyles.fredoka,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.46,
                    color: ForestColorTheme.darkseagreen,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSparkles(double size) {
    return AnimatedBuilder(
      animation: _carBounceCtrl,
      builder: (_, __) {
        final t = _carBounce.value.clamp(0.0, 1.0);
        return Positioned(
          top: -size * 0.22,
          child: Opacity(
            opacity: sin(t * pi),
            child: Text('✨', style: TextStyle(fontSize: size * 0.4)),
          ),
        );
      },
    );
  }

  // ── LETTER CHOICES ───────────────────────────────────────────────────────
  Widget _buildLetterChoices(double w, double h) {
    final cardSize = (h * 0.7).clamp(60.0, 90.0);

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 12,
        children: _round.choices.map((letter) => _buildLetterChoice(letter, cardSize)).toList(),
      ),
    );
  }

  Widget _buildLetterChoice(String letter, double size) {
    final isShaking = _shakingChoice == letter;

    Widget card({double scale = 1.0}) {
      return AnimatedBuilder(
        animation: _choiceShakeCtrl,
        builder: (_, child) {
          final angle = isShaking ? _choiceShake.value : 0.0;
          return Transform.rotate(angle: angle, child: child);
        },
        child: Container(
          width: size * scale,
          height: size * scale,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ForestColorTheme.seagreen, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: scale > 1.0 ? 14 : 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: ForestAppTextStyles.fredoka,
              fontWeight: FontWeight.w900,
              fontSize: size * scale * 0.46,
              color: ForestColorTheme.darkseagreen,
            ),
          ),
        ),
      );
    }

    // Interaction is briefly disabled right after a correct answer so a
    // second rapid drop can't trigger another round completion.
    if (_roundLocked) {
      return Opacity(opacity: 0.5, child: card());
    }

    return Draggable<String>(
      data: letter,
      onDragStarted: () => HapticFeedback.selectionClick(),
      onDraggableCanceled: (_, __) => _handleWrongAnswer(letter),
      feedback: Material(
        color: Colors.transparent,
        child: card(scale: 1.15),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card()),
      child: _buildIdleBob(card(), letter),
    );
  }

  Widget _buildIdleBob(Widget child, String letter) {
    final phase = letter.codeUnitAt(0) * 0.3;
    return AnimatedBuilder(
      animation: _trainBobCtrl,
      builder: (_, c) {
        final bobY = 2 * sin((_trainBobCtrl.value * 2 * pi) + phase);
        return Transform.translate(offset: Offset(0, bobY), child: c);
      },
      child: child,
    );
  }

  // ── PROGRESS ─────────────────────────────────────────────────────────────
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedRounds;
        final current = i == _currentRoundIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ForestColorTheme.mediumseagreen
                : current
                ? ForestColorTheme.seagreen
                : ForestColorTheme.seagreen.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
