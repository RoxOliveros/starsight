import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/forest_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_buttons.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'alphabet_game_ui.dart';
import 'forest_audio_helper.dart';
import 'forest_game_letter_treehouse.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

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
        TofiReactionMixin<AlphabetTrainGame>,
        AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── ASSETS ───────────────────────────────────────────────────────────────
  static const String _bgImage =
      'assets/images/backgrounds/bg_game_forest_train_path.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _trainHeadImage =
      'assets/images/objects/forest/train_head.png';
  static const String _trainWagonImage =
      'assets/images/objects/forest/train_wagon.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/alphabet_train_intro.wav';
  static const String _audioInstruction =
      '$_audioBase/alphabet_train_instruction.wav';
  static const String _audioCorrect = '$_audioBase/alphabet_train_correct.wav';
  static const String _audioRoundComplete =
      '$_audioBase/alphabet_train_round_complete.wav';
  static const String _audioWin = '$_audioBase/alphabet_train_win.wav';

  // ── GAME STRUCTURE ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  // ── STATE ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRoundIndex = 0;
  int _solvedRounds = 0;
  bool _roundLocked = false;
  bool _slotFilled = false;
  bool _celebrating = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  late _TrainRound _round;
  String? _shakingChoice;
  bool _missingShaking = false;

  // ── ANIMATIONS ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl;
  late AnimationController _trainBobCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _missingPulseCtrl;
  late AnimationController _carBounceCtrl;
  late Animation<double> _carBounce;
  late AnimationController _choiceShakeCtrl;
  late Animation<double> _choiceShake;
  late AnimationController _trainNudgeCtrl;

  // ── INITIALIZATION ───────────────────────────────────────────────────────
  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

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
    _instructionBounce = TweenSequence(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
      ],
    ).animate(CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut));

    _sceneEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sceneEnter = CurvedAnimation(
      parent: _sceneEnterCtrl,
      curve: Curves.elasticOut,
    );

    _missingPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _carBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _carBounce = CurvedAnimation(
      parent: _carBounceCtrl,
      curve: Curves.elasticOut,
    );

    _choiceShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _choiceShake =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.09), weight: 25),
          TweenSequenceItem(tween: Tween(begin: -0.09, end: 0.09), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 0.09, end: 0.0), weight: 25),
        ]).animate(
          CurvedAnimation(parent: _choiceShakeCtrl, curve: Curves.easeInOut),
        );

    _trainNudgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoiceRestartingOnFaceLoss(audio.voicePlayer, _audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await playVoiceRestartingOnFaceLoss(audio.voicePlayer, _audioInstruction);
  }

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

  _TrainRound _generateRoundForIndex(int roundIndex) {
    switch (roundIndex) {
      case 0:
        return _generateRound(length: 3, choiceCount: 2, fixedMissingIndex: 1);
      case 1:
        return _generateRound(length: 4, choiceCount: 3, fixedMissingIndex: 2);
      case 2:
        return _generateRound(length: 4, choiceCount: 3);
      case 3:
        return _generateRound(length: 5, choiceCount: 4);
      case 4:
      default:
        return _generateRound(length: 5, choiceCount: 4, interiorOnly: true);
    }
  }

  _TrainRound _generateRound({
    required int length,
    required int choiceCount,
    int? fixedMissingIndex,
    bool interiorOnly = false,
  }) {
    final rand = Random();

    final maxStart = 26 - length;
    final startCode = rand.nextInt(maxStart + 1);
    final sequence = List.generate(
      length,
      (i) => String.fromCharCode(65 + startCode + i),
    );

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

  Future<void> _handleCorrectAnswer() async {
    if (_roundLocked) return;

    _tapTracker.recordCorrectTap();
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

  Future<void> _handleWrongAnswer(String letter) async {
    if (_roundLocked) return;

    _tapTracker.recordMistake();
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

  Future<void> _advanceRound() async {
    _solvedRounds++;

    if (_currentRoundIndex >= _totalRounds - 1) {
      await playVoice(_audioWin);
      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;

      await _saveDataAndShowGoodJob();
      return;
    }

    await playVoice(_audioRoundComplete);
    if (!mounted) return;

    _currentRoundIndex++;
    _setupRound();
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    try {
      await ForestDatabaseService.saveGameData(
        gameId: 'forest_alphabet_train',
        activityName: 'Alphabet Train',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      );
    } catch (e) {
      debugPrint("Database Error saving metrics: $e");
    }

    if (!mounted) return;
    _showGoodJob();
  }

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
          onNext: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const LetterTreehouseGame(level: 24),
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

  @override
  void dispose() {
    disposeAiCamera();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.alphabetForest(),
        gameBuilder: () => Stack(
          children: [
            if (_introPlaying) _buildIntroLayer() else _buildGameContent(),
            if (!_introPlaying) buildTofi(context),
            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),
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
        const Positioned(top: 25, left: 25, child: ForestXButton()),
        Positioned(
          top: 25,
          right: 20,
          child: ForestLevelBadge(level: widget.level),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _tofiFloatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                0,
                Tween<double>(begin: -6, end: 6).evaluate(
                  CurvedAnimation(
                    parent: _tofiFloatCtrl,
                    curve: Curves.easeInOut,
                  ),
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
                  errorBuilder: (_, __, ___) =>
                      const Text('🐶', style: TextStyle(fontSize: 80)),
                ),
                const SizedBox(height: 120),
                Image.asset(
                  _trainHeadImage,
                  height: screenH * 0.5,
                  errorBuilder: (_, __, ___) =>
                      const Text('🐶', style: TextStyle(fontSize: 80)),
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
              const Positioned(top: 25, left: 25, child: ForestXButton()),
              Positioned(
                top: 25,
                right: 20,
                child: ForestLevelBadge(level: widget.level),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 90),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, inner) =>
                              _buildTrain(inner.maxWidth, inner.maxHeight),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: LayoutBuilder(
                        builder: (context, inner) => _buildLetterChoices(
                          inner.maxWidth,
                          inner.maxHeight,
                        ),
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
                          ? _buildFilledCar(
                              _round.correctLetter,
                              carSize,
                              justFilled: true,
                            )
                          : _buildMissingCar(carSize))
                    : _buildFilledCar(
                        _round.sequence[i],
                        carSize,
                        justFilled: false,
                      ),
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

  Widget _buildFilledCar(
    String letter,
    double size, {
    required bool justFilled,
  }) {
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
            Image.asset(
              _trainWagonImage,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
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
        onWillAccept: (data) => !_roundLocked,
        onAccept: (letter) {
          if (letter == _round.correctLetter) {
            _handleCorrectAnswer();
          } else {
            _handleWrongAnswer(letter);
          }
        },
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
                color: isHovering
                    ? ForestColorTheme.mediumseagreen
                    : Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: ForestColorTheme.mediumseagreen.withValues(
                    alpha: isHovering ? 0.6 : 0.25,
                  ),
                  blurRadius: isHovering ? 16 : 8,
                  spreadRadius: isHovering ? 2 : 0,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Image.asset(
                  _trainWagonImage,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
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

  Widget _buildLetterChoices(double w, double h) {
    final cardSize = (h * 0.7).clamp(60.0, 90.0);

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 12,
        children: _round.choices
            .map((letter) => _buildLetterChoice(letter, cardSize))
            .toList(),
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

    if (_roundLocked) {
      return Opacity(opacity: 0.5, child: card());
    }

    return Draggable<String>(
      data: letter,
      onDragStarted: () => HapticFeedback.selectionClick(),
      onDraggableCanceled: (_, __) {},
      feedback: Material(color: Colors.transparent, child: card(scale: 1.15)),
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
