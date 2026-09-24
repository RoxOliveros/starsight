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
import 'forest_game_letter_fireflies.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

class AlphabetAppleTreeGame extends StatefulWidget {
  final int level;
  const AlphabetAppleTreeGame({super.key, required this.level});

  @override
  State<AlphabetAppleTreeGame> createState() => _AlphabetAppleTreeGameState();
}

class _AlphabetAppleTreeGameState extends State<AlphabetAppleTreeGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<AlphabetAppleTreeGame>,
        ForestAudioMixin<AlphabetAppleTreeGame>,
        TofiReactionMixin<AlphabetAppleTreeGame>,
        AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _treeAsset = 'assets/images/objects/lagoon/tree.png';
  static const String _appleAsset = 'assets/images/objects/forest/apple.png';
  static const String _leafAsset = 'assets/images/objects/forest/leaf.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/apple_tree_intro.wav';
  static const String _audioInstruction =
      '$_audioBase/apple_tree_instruction.wav';
  static const String _audioRoundComplete = '$_audioBase/apple_found_chime.wav';
  static const String _audioWin = '$_audioBase/apple_tree_win.wav';

  static const List<Offset> _baseAppleSlots = [
    Offset(0.47, 0.20),
    Offset(0.53, 0.20),
    Offset(0.40, 0.38),
    Offset(0.57, 0.38),
  ];

  static const int _totalRounds = 5;
  static const int _applesPerRound = 4;

  bool _introPlaying = true;
  int _currentRoundIndex = 0;
  int _solvedRounds = 0;

  late List<String> _appleLetters;
  late List<Offset> _applePositions;
  late String _targetLetter;
  String? _previousTarget;

  bool _foundThisRound = false;
  bool _resolving = false;
  int? _fallingIndex;
  int? _wrongIndex;
  final Set<int> _pressedIndices = {};

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  late AnimationController _tofiFloatCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _breatheCtrl;
  late AnimationController _bobCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;
  late AnimationController _fallCtrl;
  late AnimationController _ambientLeavesCtrl;

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
    _setupRound();
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

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.14), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.14, end: 0.14), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.14, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _fallCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _ambientLeavesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
    )..repeat();
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
    if (!mounted) return;
    await playVoiceRestartingOnFaceLoss(
      audio.voicePlayer,
      ForestAudioAssets.forLetter(_targetLetter),
    );
  }

  void _setupRound() {
    final rng = Random();

    String target;
    do {
      target = String.fromCharCode(65 + rng.nextInt(26));
    } while (target == _previousTarget);
    _previousTarget = target;

    final distractorPool = List.generate(26, (i) => String.fromCharCode(65 + i))
      ..remove(target);
    distractorPool.shuffle(rng);
    final letters = [target, ...distractorPool.take(_applesPerRound - 1)]
      ..shuffle(rng);

    _appleLetters = letters;
    _applePositions = _buildApplePositions(rng);
    _targetLetter = target;

    _foundThisRound = false;
    _resolving = false;
    _fallingIndex = null;
    _wrongIndex = null;
    _pressedIndices.clear();

    _fallCtrl.reset();
    _shakeCtrl.reset();
    _instructionCtrl.forward(from: 0);

    setState(() {});
  }

  List<Offset> _buildApplePositions(Random rng) {
    return _baseAppleSlots.map((base) {
      final dx = (rng.nextDouble() - 0.5) * 0.06;
      final dy = (rng.nextDouble() - 0.5) * 0.06;
      return Offset(
        (base.dx + dx).clamp(0.08, 0.92),
        (base.dy + dy).clamp(0.16, 0.62),
      );
    }).toList();
  }

  Future<void> _onAppleTapped(int index) async {
    if (_resolving || _foundThisRound) return;
    final letter = _appleLetters[index];

    if (letter == _targetLetter) {
      _tapTracker.recordCorrectTap();
      _resolving = true;
      _foundThisRound = true;
      HapticFeedback.mediumImpact();
      setState(() => _fallingIndex = index);
      _fallCtrl.forward(from: 0);

      showTofiReaction(TofiState.correct);

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      await playVoiceRestartingOnFaceLoss(
        audio.voicePlayer,
        _audioRoundComplete,
      );
      if (!mounted) return;

      await _advanceRound();
    } else {
      _tapTracker.recordMistake();
      HapticFeedback.heavyImpact();
      setState(() => _wrongIndex = index);
      _shakeCtrl.forward(from: 0);

      showTofiReaction(TofiState.wrong);

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _wrongIndex = null);
    }
  }

  Future<void> _advanceRound() async {
    _solvedRounds++;

    if (_currentRoundIndex >= _totalRounds - 1) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await playVoice(_audioWin);
      if (!mounted) return;

      ForestProgressService.instance.markLevelComplete(widget.level).catchError(
        (e) {
          debugPrint("Database Error marking level complete: $e");
        },
      );
      if (!mounted) return;

      await _saveDataAndShowGoodJob();
      return;
    }

    _currentRoundIndex++;
    _setupRound();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await playVoiceRestartingOnFaceLoss(
      audio.voicePlayer,
      ForestAudioAssets.forLetter(_targetLetter),
    );
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'forest_apple_tree',
      activityName: 'Alphabet Apple Tree',
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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const LetterFirefliesGame(level: 21),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlphabetAppleTreeGame(level: widget.level),
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
    _breatheCtrl.dispose();
    _bobCtrl.dispose();
    _shakeCtrl.dispose();
    _fallCtrl.dispose();
    _ambientLeavesCtrl.dispose();
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
        Positioned.fill(
          child: Image.asset(
            _bgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: ForestColorTheme.lightgrayishgreen),
          ),
        ),
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
            child: Image.asset(
              _dogImage,
              height: screenH * 0.72,
              errorBuilder: (_, __, ___) =>
                  const Text('🐶', style: TextStyle(fontSize: 90)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _bgImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: ForestColorTheme.lightgrayishgreen),
              ),
            ),
            Positioned.fill(child: _buildAmbientLeaves(w, h)),
            _buildGameUI(w, h),
          ],
        );
      },
    );
  }

  Widget _buildGameUI(double w, double h) {
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

          Positioned(
            top: 90,
            left: 0,
            right: 0,
            bottom: 40,
            child: LayoutBuilder(
              builder: (context, inner) =>
                  _buildTreeArea(inner.maxWidth, inner.maxHeight),
            ),
          ),

          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(child: _buildProgressDots()),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeArea(double w, double h) {
    final treeHeight = h * 1;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _breatheCtrl,
            builder: (_, child) {
              final s = 1.0 + 0.015 * sin(_breatheCtrl.value * 2 * pi);
              return Transform.scale(scale: s, child: child);
            },
            child: Image.asset(
              _treeAsset,
              height: treeHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Text('🌳', style: TextStyle(fontSize: treeHeight * 0.45)),
            ),
          ),
          for (int i = 0; i < _appleLetters.length; i++) _buildApple(i, w, h),
        ],
      ),
    );
  }

  Widget _buildApple(int index, double w, double h) {
    final size = (h * 0.17);

    if (_fallingIndex == index) {
      final pos = _applePositions[index];
      return Positioned(
        left: pos.dx * w - size / 2,
        top: pos.dy * h - size / 2,
        child: _buildFallingApple(index, h, size),
      );
    }

    final pos = _applePositions[index];
    final wrong = _wrongIndex == index;
    final pressed = _pressedIndices.contains(index);
    final phase = index * 1.3;

    return Positioned(
      left: pos.dx * w - size / 2,
      top: pos.dy * h - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressedIndices.add(index)),
        onTapCancel: () => setState(() => _pressedIndices.remove(index)),
        onTapUp: (_) => setState(() => _pressedIndices.remove(index)),
        onTap: () => _onAppleTapped(index),
        child: AnimatedBuilder(
          animation: Listenable.merge([_bobCtrl, _shakeCtrl]),
          builder: (_, child) {
            final bobY = 5 * sin((_bobCtrl.value * 2 * pi) + phase);
            final shakeAngle = wrong ? _shake.value : 0.0;
            final scale = pressed ? 1.12 : 1.0;
            return Transform.translate(
              offset: Offset(0, bobY),
              child: Transform.rotate(
                angle: shakeAngle,
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: _buildAppleVisual(_appleLetters[index], size, wrong: wrong),
        ),
      ),
    );
  }

  Widget _buildAppleVisual(
    String letter,
    double size, {
    bool wrong = false,
    bool correct = false,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          _appleAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: correct
                  ? ForestColorTheme.mediumseagreen
                  : (wrong ? Colors.red.shade300 : Colors.red.shade400),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.42,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallingApple(int index, double h, double size) {
    return AnimatedBuilder(
      animation: _fallCtrl,
      builder: (_, child) {
        final t = _fallCtrl.value;
        final popPhase = (t / 0.35).clamp(0.0, 1.0);
        final fallPhase = ((t - 0.35) / 0.65).clamp(0.0, 1.0);

        final popScale = 1.0 + 0.35 * Curves.easeOut.transform(popPhase);
        final dy = fallPhase * h * 0.35;
        final opacity = (1 - fallPhase).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: popScale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  child!,
                  if (popPhase < 1.0) _buildSparkle(size, popPhase),
                ],
              ),
            ),
          ),
        );
      },
      child: _buildAppleVisual(_appleLetters[index], size, correct: true),
    );
  }

  Widget _buildSparkle(double size, double popPhase) {
    return Opacity(
      opacity: (1 - popPhase).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.6 + popPhase * 0.8,
        child: Text('✨', style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }

  Widget _buildAmbientLeaves(double w, double h) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ambientLeavesCtrl,
        builder: (_, __) {
          return Stack(
            children: List.generate(4, (i) {
              final speedOffset = i * 0.25;
              final t = (_ambientLeavesCtrl.value + speedOffset) % 1.0;
              final x = t;
              final y = 0.05 + 0.15 * i + 0.05 * sin(t * 2 * pi);
              return Positioned(
                left: x * w,
                top: y * h,
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    _leafAsset,
                    width: 18,
                    errorBuilder: (_, __, ___) =>
                        const Text('🍃', style: TextStyle(fontSize: 14)),
                  ),
                ),
              );
            }),
          );
        },
      ),
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
