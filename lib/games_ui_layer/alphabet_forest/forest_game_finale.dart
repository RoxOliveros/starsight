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
import '../star_round_indicator.dart';
import 'alphabet_game_ui.dart';
import 'forest_audio_helper.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

enum AlphabetFinaleChallenge {
  recognition,
  caseMatching,
  missingLetter,
  soundSound,
  alphabetOrder,
}

class _FinaleQuestion {
  final AlphabetFinaleChallenge type;
  final String correctAnswer;
  final List<String> choices;
  final String? promptLetter;
  final List<String>? sequence;
  final int? missingIndex;

  const _FinaleQuestion({
    required this.type,
    required this.correctAnswer,
    required this.choices,
    this.promptLetter,
    this.sequence,
    this.missingIndex,
  });
}

class AlphabetForestFinaleGame extends StatefulWidget {
  final int level;
  const AlphabetForestFinaleGame({super.key, required this.level});

  @override
  State<AlphabetForestFinaleGame> createState() =>
      _AlphabetForestFinaleGameState();
}

class _AlphabetForestFinaleGameState extends State<AlphabetForestFinaleGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<AlphabetForestFinaleGame>,
        ForestAudioMixin<AlphabetForestFinaleGame>,
        TofiReactionMixin<AlphabetForestFinaleGame>,
        AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _speakerImage = 'assets/images/icons/speaker.png';
  static const String _starImage = 'assets/images/objects/lagoon/star.png';
  static const String _audioBase = ForestAudioAssets.base;

  static const String _audioIntro = '$_audioBase/forest_finale_intro.wav';
  static const String _audioMainInstruction =
      '$_audioBase/forest_finale_instruction.wav';
  static const String _audioRecognitionInstruction =
      '$_audioBase/forest_finale_recognition_instruction.wav';
  static const String _audioCaseInstruction =
      '$_audioBase/forest_finale_case_instruction.wav';
  static const String _audioMissingInstruction =
      '$_audioBase/forest_finale_missing_instruction.wav';
  static const String _audioSoundInstruction =
      '$_audioBase/forest_finale_sound_instruction.wav';
  static const String _audioOrderInstruction =
      '$_audioBase/forest_finale_order_instruction.wav';
  static const String _audioWin = '$_audioBase/forest_finale_win.wav';

  static const String _audioCorrect = '$_audioBase/alphabet_train_correct.wav';
  static const String _audioRoundComplete =
      '$_audioBase/alphabet_train_round_complete.wav';

  static String _letterAudioAsset(String letter) =>
      'assets/audio/alphabet_forest/sound_effects/sound_${letter.toLowerCase()}.wav';

  static const int _totalRounds = 5;

  // ── STATE ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRoundIndex = 0;
  int _litStars = 0;
  bool _roundLocked = false;
  bool _celebrating = false;
  String? _shakingChoice;
  bool _showFlyingStars = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  final Random _rand = Random();
  final Set<String> _usedTargets = {};
  late List<AlphabetFinaleChallenge> _challengeOrder;
  late _FinaleQuestion _question;

  // ── ANIMATIONS ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _correctBounceCtrl;
  late Animation<double> _correctBounce;
  late AnimationController _choiceShakeCtrl;
  late Animation<double> _choiceShake;
  late AnimationController _starGlowCtrl;
  late AnimationController _flyingStarsCtrl;

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
    _newGame();
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _instructionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _sceneEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sceneEnter = CurvedAnimation(
      parent: _sceneEnterCtrl,
      curve: Curves.elasticOut,
    );

    _correctBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _correctBounce = CurvedAnimation(
      parent: _correctBounceCtrl,
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

    _starGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _flyingStarsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  void _newGame() {
    _currentRoundIndex = 0;
    _litStars = 0;
    _roundLocked = false;
    _celebrating = false;
    _shakingChoice = null;
    _usedTargets.clear();

    _challengeOrder = [
      AlphabetFinaleChallenge.recognition,
      AlphabetFinaleChallenge.caseMatching,
      AlphabetFinaleChallenge.missingLetter,
      AlphabetFinaleChallenge.soundSound,
      AlphabetFinaleChallenge.alphabetOrder,
    ]..shuffle(_rand);

    _question = _generateQuestion(_challengeOrder[0]);
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

    await playVoiceRestartingOnFaceLoss(
      audio.voicePlayer,
      _audioMainInstruction,
    );
    if (!mounted) return;

    await _playChallengeInstruction(_challengeOrder[_currentRoundIndex]);
    await _playSoundLetter();
  }

  Future<void> _playChallengeInstruction(AlphabetFinaleChallenge type) async {
    if (!mounted) return;
    final asset = switch (type) {
      AlphabetFinaleChallenge.recognition => _audioRecognitionInstruction,
      AlphabetFinaleChallenge.caseMatching => _audioCaseInstruction,
      AlphabetFinaleChallenge.missingLetter => _audioMissingInstruction,
      AlphabetFinaleChallenge.soundSound => _audioSoundInstruction,
      AlphabetFinaleChallenge.alphabetOrder => _audioOrderInstruction,
    };
    await playVoiceRestartingOnFaceLoss(audio.voicePlayer, asset);
  }

  Future<void> _playSoundLetter() async {
    if (!mounted) return;

    final currentType = _challengeOrder[_currentRoundIndex];

    if (currentType == AlphabetFinaleChallenge.soundSound) {
      await playVoiceRestartingOnFaceLoss(
        audio.voicePlayer,
        _letterAudioAsset(_question.correctAnswer),
      );
    }
  }

  static final List<String> _az = List.generate(
    26,
    (i) => String.fromCharCode(65 + i),
  );

  String _randomLetterExcluding(Set<String> exclude) {
    String letter;
    do {
      letter = String.fromCharCode(65 + _rand.nextInt(26));
    } while (exclude.contains(letter));
    return letter;
  }

  String _pickUnusedLetter() {
    final available = _az.where((l) => !_usedTargets.contains(l)).toList();
    final pool = available.isEmpty ? _az : available;
    final letter = pool[_rand.nextInt(pool.length)];
    _usedTargets.add(letter);
    return letter;
  }

  _FinaleQuestion _generateQuestion(AlphabetFinaleChallenge type) {
    switch (type) {
      case AlphabetFinaleChallenge.recognition:
        return _generateRecognition();
      case AlphabetFinaleChallenge.caseMatching:
        return _generateCaseMatching();
      case AlphabetFinaleChallenge.missingLetter:
        return _generateMissingLetter();
      case AlphabetFinaleChallenge.soundSound:
        return _generateSoundSound();
      case AlphabetFinaleChallenge.alphabetOrder:
        return _generateAlphabetOrder();
    }
  }

  _FinaleQuestion _generateRecognition() {
    final target = _pickUnusedLetter();
    final distractors = <String>{};
    while (distractors.length < 2) {
      distractors.add(_randomLetterExcluding({target, ...distractors}));
    }
    final choices = [target, ...distractors]..shuffle(_rand);
    return _FinaleQuestion(
      type: AlphabetFinaleChallenge.recognition,
      correctAnswer: target,
      choices: choices,
      promptLetter: target,
    );
  }

  _FinaleQuestion _generateCaseMatching() {
    final letter = _pickUnusedLetter();
    final showUpper = _rand.nextBool();
    final promptDisplay = showUpper ? letter : letter.toLowerCase();
    final correct = showUpper ? letter.toLowerCase() : letter;

    final distractors = <String>{};
    while (distractors.length < 2) {
      final other = _randomLetterExcluding({letter});
      final candidate = showUpper ? other.toLowerCase() : other;
      if (candidate == correct || distractors.contains(candidate)) continue;
      distractors.add(candidate);
    }
    final choices = [correct, ...distractors]..shuffle(_rand);

    return _FinaleQuestion(
      type: AlphabetFinaleChallenge.caseMatching,
      correctAnswer: correct,
      choices: choices,
      promptLetter: promptDisplay,
    );
  }

  _FinaleQuestion _generateMissingLetter() {
    final length = 3 + _rand.nextInt(2);
    final maxStart = 26 - length;
    final startCode = _rand.nextInt(maxStart + 1);
    final sequence = List.generate(
      length,
      (i) => String.fromCharCode(65 + startCode + i),
    );
    final missingIndex = _rand.nextInt(length);
    final correct = sequence[missingIndex];
    _usedTargets.add(correct);

    final usedLetters = sequence.toSet();
    final distractors = <String>{};
    while (distractors.length < 2) {
      final l = String.fromCharCode(65 + _rand.nextInt(26));
      if (usedLetters.contains(l) || distractors.contains(l)) continue;
      distractors.add(l);
    }
    final choices = [correct, ...distractors]..shuffle(_rand);

    return _FinaleQuestion(
      type: AlphabetFinaleChallenge.missingLetter,
      correctAnswer: correct,
      choices: choices,
      sequence: sequence,
      missingIndex: missingIndex,
    );
  }

  _FinaleQuestion _generateSoundSound() {
    final target = _pickUnusedLetter();
    final distractors = <String>{};
    while (distractors.length < 2) {
      distractors.add(_randomLetterExcluding({target, ...distractors}));
    }
    final choices = [target, ...distractors]..shuffle(_rand);
    return _FinaleQuestion(
      type: AlphabetFinaleChallenge.soundSound,
      correctAnswer: target,
      choices: choices,
      promptLetter: target,
    );
  }

  _FinaleQuestion _generateAlphabetOrder() {
    final codes = <int>{};
    while (codes.length < 3) {
      codes.add(_rand.nextInt(26));
    }
    final sorted = codes.toList()..sort();
    final correct = String.fromCharCode(65 + sorted.first);
    _usedTargets.add(correct);

    final displayCodes = codes.toList()..shuffle(_rand);
    final displayLetters = displayCodes
        .map((c) => String.fromCharCode(65 + c))
        .toList();

    return _FinaleQuestion(
      type: AlphabetFinaleChallenge.alphabetOrder,
      correctAnswer: correct,
      choices: displayLetters,
    );
  }

  Future<void> _handleTap(String letter) async {
    if (_roundLocked) return;
    if (letter == _question.correctAnswer) {
      await _handleCorrect();
    } else {
      await _handleWrong(letter);
    }
  }

  Future<void> _handleCorrect() async {
    if (_roundLocked) return;
    _roundLocked = true;
    _tapTracker.recordCorrectTap();

    HapticFeedback.mediumImpact();
    setState(() => _celebrating = true);
    _correctBounceCtrl.forward(from: 0);
    playVoice(_audioCorrect);
    showTofiReaction(TofiState.correct);
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;

    setState(() => _litStars = _currentRoundIndex + 1);

    if (_currentRoundIndex >= _totalRounds - 1) {
      setState(() => _showFlyingStars = true);
      _flyingStarsCtrl.forward(from: 0);

      await playVoice(_audioWin);
      if (!mounted) return;

      ForestProgressService.instance.markLevelComplete(widget.level).catchError(
        (e) {
          debugPrint("Database Error marking level complete: $e");
        },
      );
      if (!mounted) return;

      setState(() => _showFlyingStars = false);
      await _saveDataAndShowGoodJob();
      return;
    }

    await playVoice(_audioRoundComplete);
    if (!mounted) return;

    _currentRoundIndex++;
    _setupRound();

    await _playChallengeInstruction(_challengeOrder[_currentRoundIndex]);
    await _playSoundLetter();
  }

  Future<void> _handleWrong(String letter) async {
    if (_roundLocked) return;
    _tapTracker.recordMistake();

    HapticFeedback.heavyImpact();
    setState(() => _shakingChoice = letter);
    _choiceShakeCtrl.forward(from: 0);

    await showTofiReaction(TofiState.wrong);
    if (!mounted) return;

    setState(() => _shakingChoice = null);
  }

  void _setupRound() {
    _roundLocked = false;
    _celebrating = false;
    _shakingChoice = null;

    _question = _generateQuestion(_challengeOrder[_currentRoundIndex]);

    _correctBounceCtrl.reset();
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    setState(() {});
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'forest_finale',
      activityName: 'Alphabet Forest Finale',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

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
            Navigator.of(context).pop();
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlphabetForestFinaleGame(level: widget.level),
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
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _correctBounceCtrl.dispose();
    _choiceShakeCtrl.dispose();
    _starGlowCtrl.dispose();
    _flyingStarsCtrl.dispose();
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
            Positioned(top: 25, left: 25, child: ForestXButton()),
            Positioned(
              top: 25,
              right: 20,
              child: ForestLevelBadge(level: widget.level),
            ),
            if (_showFlyingStars)
              Positioned.fill(child: IgnorePointer(child: _buildFlyingStars())),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _dogImage,
                  height: screenH * 0.70,
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
        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 50, bottom: 50),
                child: Center(
                  child: ScaleTransition(
                    scale: _sceneEnter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChallengeVisual(),

                        if (_question.type !=
                            AlphabetFinaleChallenge.alphabetOrder) ...[
                          const SizedBox(height: 24),

                          _buildAnswerRow(_question.choices),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: StarRoundIndicator(
                  totalRounds: _totalRounds,
                  litCount: _litStars,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChallengeVisual() {
    switch (_question.type) {
      case AlphabetFinaleChallenge.recognition:
        return _buildRecognitionTarget();
      case AlphabetFinaleChallenge.caseMatching:
        return _buildCaseTarget();
      case AlphabetFinaleChallenge.missingLetter:
        return _buildSequenceRow();
      case AlphabetFinaleChallenge.soundSound:
        return _buildListenPrompt();
      case AlphabetFinaleChallenge.alphabetOrder:
        return _buildAnswerRow(_question.choices);
    }
  }

  Widget _buildRecognitionTarget() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ForestColorTheme.seagreen, width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _question.promptLetter ?? '',
        style: TextStyle(
          fontFamily: ForestAppTextStyles.fredoka,
          fontWeight: FontWeight.w900,
          fontSize: 72,
          color: ForestColorTheme.darkseagreen,
        ),
      ),
    );
  }

  Widget _buildListenPrompt() {
    return GestureDetector(
      onTap: _roundLocked
          ? null
          : () => playVoiceRestartingOnFaceLoss(
              audio.voicePlayer,
              _letterAudioAsset(_question.correctAnswer),
            ),
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ForestColorTheme.seagreen, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: Image.asset(_speakerImage)),
      ),
    );
  }

  Widget _buildCaseTarget() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ForestColorTheme.seagreen, width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _question.promptLetter ?? '',
        style: TextStyle(
          fontFamily: ForestAppTextStyles.fredoka,
          fontWeight: FontWeight.w900,
          fontSize: 64,
          color: ForestColorTheme.darkseagreen,
        ),
      ),
    );
  }

  Widget _buildSequenceRow() {
    final sequence = _question.sequence ?? const [];
    final missingIndex = _question.missingIndex ?? -1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(sequence.length, (i) {
        final isMissing = i == missingIndex;
        return Container(
          width: 64,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isMissing
                ? ForestColorTheme.mediumseagreen.withValues(alpha: 0.25)
                : ForestColorTheme.darkseagreen.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMissing ? ForestColorTheme.mediumseagreen : Colors.white,
              width: isMissing ? 3 : 2,
            ),
          ),
          child: Center(
            child: Text(
              isMissing ? '?' : sequence[i],
              style: TextStyle(
                fontFamily: ForestAppTextStyles.fredoka,
                fontWeight: FontWeight.w900,
                fontSize: 30,
                color: Colors.white,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAnswerRow(List<String> choices) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: choices.map(_buildChoiceCard).toList(),
    );
  }

  Widget _buildChoiceCard(String letter) {
    final isShaking = _shakingChoice == letter;

    Widget card = AnimatedBuilder(
      animation: _choiceShakeCtrl,
      builder: (_, child) {
        final angle = isShaking ? _choiceShake.value : 0.0;
        return Transform.rotate(angle: angle, child: child);
      },
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ForestColorTheme.seagreen, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontWeight: FontWeight.w900,
            fontSize: 38,
            color: ForestColorTheme.darkseagreen,
          ),
        ),
      ),
    );

    if (letter == _question.correctAnswer && _celebrating) {
      card = ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.25).animate(_correctBounce),
        child: card,
      );
    }

    return GestureDetector(
      onTap: _roundLocked ? null : () => _handleTap(letter),
      child: Opacity(
        opacity: _roundLocked && letter != _question.correctAnswer ? 0.5 : 1.0,
        child: card,
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
                  curve: Interval(
                    start,
                    (start + 0.6).clamp(0.0, 1.0),
                    curve: Curves.easeOut,
                  ),
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
}
