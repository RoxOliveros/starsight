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
import 'alphabet_intro.dart';
import 'forest_audio_helper.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

class FlowerTarget {
  final String letter;
  final Offset pos;
  bool matched;

  FlowerTarget({required this.letter, required this.pos, this.matched = false});
}

class ButterflyOption {
  final String letter;
  final Offset pos;
  bool matched;

  ButterflyOption({
    required this.letter,
    required this.pos,
    this.matched = false,
  });
}

class ButterflyLetterMatchGame extends StatefulWidget {
  final int level;
  const ButterflyLetterMatchGame({super.key, required this.level});

  @override
  State<ButterflyLetterMatchGame> createState() =>
      _ButterflyLetterMatchGameState();
}

class _ButterflyLetterMatchGameState extends State<ButterflyLetterMatchGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<ButterflyLetterMatchGame>,
        ForestAudioMixin<ButterflyLetterMatchGame>,
        TofiReactionMixin<ButterflyLetterMatchGame>,
        AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage =
      'assets/images/backgrounds/bg_game_forest_garden.png';
  static const String _butterflyImage =
      'assets/images/objects/forest/butterfly.png';
  static const String _flowerAsset =
      'assets/images/objects/forest/flower_not_bloom.png';
  static const String _flowerBloomAsset =
      'assets/images/objects/forest/flower_bloom.png';
  static const String _dogImage = 'assets/images/characters/dog.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro =
      '$_audioBase/butterfly_letter_match_intro.wav';
  static const String _audioInstruction =
      '$_audioBase/butterfly_letter_match_instruction.wav';
  static const String _audioWin = '$_audioBase/butterfly_letter_match_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  static const List<String> _letters = ['J', 'K', 'L'];
  static const int _totalRounds = 3;

  static const List<Offset> _flowerSlots = [
    Offset(0.30, 0.64),
    Offset(0.5, 0.64),
    Offset(0.70, 0.64),
  ];

  static const List<Offset> _butterflySlots = [
    Offset(0.25, 0.15),
    Offset(0.5, 0.15),
    Offset(0.75, 0.15),
  ];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  bool _isFinishingRound = false;
  bool _roundCompleted = false;
  int _currentRound = 0;
  int _solvedRounds = 0;
  int _matchedCount = 0;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  late final List<FlowerTarget> _flowers;
  late List<ButterflyOption> _butterflies;
  String? _wrongButterfly;

  late AnimationController _tofiFloatCtrl;
  late AnimationController _butterflyFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late List<AnimationController> _bloomCtrls;
  late List<Animation<double>> _bloomAnims;
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;

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

    _flowers = List.generate(
      _letters.length,
      (i) => FlowerTarget(letter: _letters[i], pos: _flowerSlots[i]),
    );
    _initAnimations();
    _setupRound(playInstruction: false);
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _butterflyFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

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

    _bloomCtrls = List.generate(
      _letters.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _bloomAnims = _bloomCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.elasticOut))
        .toList();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoiceRestartingOnFaceLoss(audio.voicePlayer, _audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await _announceRound();
  }

  Future<void> _announceRound() async {
    if (_currentRound == 0) {
      await playVoiceRestartingOnFaceLoss(audio.voicePlayer, _audioInstruction);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }
  }

  void _setupRound({bool playInstruction = true}) {
    _isFinishingRound = false;
    _roundCompleted = false;
    _matchedCount = 0;

    for (final flower in _flowers) {
      flower.matched = false;
    }
    for (final ctrl in _bloomCtrls) {
      ctrl.reset();
    }

    final rng = Random();
    final shuffledSlots = [..._butterflySlots]..shuffle(rng);

    _butterflies = List.generate(
      _letters.length,
      (i) => ButterflyOption(
        letter: _letters[i].toLowerCase(),
        pos: shuffledSlots[i],
      ),
    );

    _wrongButterfly = null;
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _announceRound();
      });
    }

    setState(() {});
  }

  Future<void> _onButterflyDropped(
    ButterflyOption butterfly,
    FlowerTarget flower,
  ) async {
    if (_roundCompleted) return;
    if (butterfly.matched || flower.matched) return;

    final isMatch =
        butterfly.letter.toUpperCase() == flower.letter.toUpperCase();

    if (isMatch) {
      _tapTracker.recordCorrectTap();
      HapticFeedback.mediumImpact();
      setState(() {
        butterfly.matched = true;
        flower.matched = true;
        _matchedCount++;
      });

      _bloomCtrls[_flowers.indexOf(flower)].forward(from: 0);
      await playVoiceRestartingOnFaceLoss(
        audio.voicePlayer,
        ForestAudioAssets.forLetter(flower.letter),
      );

      await showTofiReaction(TofiState.correct);
      if (!mounted) return;

      if (_matchedCount >= _letters.length) {
        _roundCompleted = true;
        await _advanceRound();
      }
    } else {
      _tapTracker.recordMistake();
      HapticFeedback.heavyImpact();
      setState(() => _wrongButterfly = butterfly.letter);
      _shakeCtrl.forward(from: 0);
      await showTofiReaction(TofiState.wrong);
      if (!mounted) return;
      setState(() => _wrongButterfly = null);
    }
  }

  Future<void> _advanceRound() async {
    if (_isFinishingRound) return;
    _isFinishingRound = true;

    _solvedRounds++;

    if (_solvedRounds >= _totalRounds) {
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

    _currentRound++;
    _setupRound();

    _isFinishingRound = false;
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'forest_butterfly_match',
      activityName: 'Butterfly Letter Match',
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
                builder: (_) => AlphabetIntroScreen(letter: 'M'),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ButterflyLetterMatchGame(level: widget.level),
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
    _butterflyFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    for (final ctrl in _bloomCtrls) {
      ctrl.dispose();
    }
    _shakeCtrl.dispose();
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
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
                      const Text('🐶', style: TextStyle(fontSize: 80)),
                ),
              ),
              Image.asset(
                _butterflyImage,
                height: screenH * 0.4,
                errorBuilder: (_, __, ___) =>
                    const Text('🦋', style: TextStyle(fontSize: 80)),
              ),
              Image.asset(
                _flowerBloomAsset,
                height: screenH * 0.4,
                errorBuilder: (_, __, ___) =>
                    const Text('🌸', style: TextStyle(fontSize: 80)),
              ),
            ],
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
                      child: LayoutBuilder(
                        builder: (context, inner) =>
                            _buildGardenArea(inner.maxWidth, inner.maxHeight),
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

  Widget _buildGardenArea(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          for (int i = 0; i < _flowers.length; i++)
            _buildFlower(_flowers[i], i, w, h),
          for (final butterfly in _butterflies)
            _buildButterfly(butterfly, w, h),
        ],
      ),
    );
  }

  Widget _buildFlower(FlowerTarget flower, int index, double w, double h) {
    final flowerSize = (h * 0.32).clamp(100.0, 180.0);

    return Positioned(
      left: flower.pos.dx * w - flowerSize / 2,
      top: flower.pos.dy * h - flowerSize / 2,
      width: flowerSize,
      height: flowerSize,
      child: DragTarget<ButterflyOption>(
        onWillAccept: (_) => !flower.matched,
        onAccept: (butterfly) => _onButterflyDropped(butterfly, flower),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return AnimatedBuilder(
            animation: _bloomCtrls[index],
            builder: (_, child) {
              final scale =
                  (flower.matched
                      ? (1.0 + 0.25 * _bloomAnims[index].value)
                      : 1.0) *
                  (isHovering ? 1.06 : 1.0);
              return Transform.scale(scale: scale, child: child);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  flower.matched ? _flowerBloomAsset : _flowerAsset,
                  width: flowerSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    flower.matched ? '🌸' : '🌼',
                    style: TextStyle(fontSize: flowerSize * 0.6),
                  ),
                ),
                Positioned(
                  top: flowerSize * 0.56,
                  child: _outlinedLetter(
                    flower.letter,
                    fontSize: flowerSize * 0.32,
                    fillColor: ForestColorTheme.darkseagreen,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildButterfly(ButterflyOption butterfly, double w, double h) {
    final size = (h * 0.35);
    final wrong = _wrongButterfly == butterfly.letter;
    final phase = butterfly.pos.dx * 6.28;

    if (butterfly.matched) {
      final flower = _flowers.firstWhere(
        (f) => f.letter.toLowerCase() == butterfly.letter,
      );
      final pinnedSize = size * 1.1;
      return Positioned(
        left: flower.pos.dx * w - pinnedSize / 2 - h * 0.05,
        bottom: flower.pos.dy * h - pinnedSize / 2 + h * 0.01,
        width: pinnedSize,
        height: pinnedSize,
        child: _butterflyVisual(butterfly.letter, pinnedSize, wrong: false),
      );
    }

    return Positioned(
      left: butterfly.pos.dx * w - size / 2,
      top: butterfly.pos.dy * h - size / 2,
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_butterflyFloatCtrl, _shakeCtrl]),
        builder: (_, child) {
          final floatY = 6 * sin((_butterflyFloatCtrl.value * 2 * pi) + phase);
          final angle = wrong ? _shake.value : 0.0;
          return Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.rotate(angle: angle, child: child),
          );
        },
        child: Draggable<ButterflyOption>(
          data: butterfly,
          feedback: Material(
            color: Colors.transparent,
            child: _butterflyVisual(butterfly.letter, size, wrong: false),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _butterflyVisual(butterfly.letter, size, wrong: false),
          ),
          child: _butterflyVisual(butterfly.letter, size, wrong: wrong),
        ),
      ),
    );
  }

  Widget _butterflyVisual(String letter, double size, {required bool wrong}) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Image.asset(
          _butterflyImage,
          width: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Text('🦋', style: TextStyle(fontSize: size * 0.6)),
        ),
        Positioned(
          bottom: size * 0.14,
          child: _outlinedLetter(
            letter,
            fontSize: size * 0.26,
            fillColor: wrong
                ? Colors.red.shade400
                : ForestColorTheme.darkseagreen,
          ),
        ),
      ],
    );
  }

  Widget _outlinedLetter(
    String letter, {
    required double fontSize,
    required Color fillColor,
  }) {
    return Stack(
      children: [
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.09
              ..color = Colors.white,
          ),
        ),
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            color: fillColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedRounds;
        final current = i == _currentRound;

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
