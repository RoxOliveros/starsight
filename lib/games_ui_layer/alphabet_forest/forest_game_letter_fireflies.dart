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
import 'forest_game_fishing.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

class Firefly {
  final String letter;
  final bool isTarget;
  final Offset anchor;
  final double ampX;
  final double ampY;
  final double phase;
  bool popped;

  Firefly({
    required this.letter,
    required this.isTarget,
    required this.anchor,
    required this.ampX,
    required this.ampY,
    required this.phase,
    this.popped = false,
  });
}

class _RoundConfig {
  final int fireflyCount;
  final int moveDurationMs;
  final double sizeFactor;

  const _RoundConfig({
    required this.fireflyCount,
    required this.moveDurationMs,
    required this.sizeFactor,
  });
}

class LetterFirefliesGame extends StatefulWidget {
  final int level;
  final List<String> letterPool;

  const LetterFirefliesGame({
    super.key,
    required this.level,
    this.letterPool = const [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
      'M',
      'N',
      'O',
      'P',
      'Q',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ],
  });

  @override
  State<LetterFirefliesGame> createState() => _LetterFirefliesGameState();
}

class _LetterFirefliesGameState extends State<LetterFirefliesGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<LetterFirefliesGame>,
        ForestAudioMixin<LetterFirefliesGame>,
        TofiReactionMixin<LetterFirefliesGame>,
        AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _fireflyImage =
      'assets/images/objects/forest/firefly.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/letter_fireflies_intro.wav';
  static const String _audioFindPrefix =
      '$_audioBase/letter_fireflies_find_prefix.wav';
  static const String _audioWin = '$_audioBase/letter_fireflies_win.wav';

  // ── Round structure ──────────────────────────────────────────────────────
  static const List<_RoundConfig> _roundConfigs = [
    _RoundConfig(fireflyCount: 3, moveDurationMs: 2600, sizeFactor: 0.26),
    _RoundConfig(fireflyCount: 4, moveDurationMs: 2200, sizeFactor: 0.26),
    _RoundConfig(fireflyCount: 5, moveDurationMs: 1900, sizeFactor: 0.26),
    _RoundConfig(fireflyCount: 5, moveDurationMs: 1500, sizeFactor: 0.26),
    _RoundConfig(fireflyCount: 6, moveDurationMs: 1200, sizeFactor: 0.26),
  ];
  static int get _totalRounds => _roundConfigs.length;

  // ═════════════════════════════════════════════════════════════════════
  // STATE
  // ═════════════════════════════════════════════════════════════════════

  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  String _targetLetter = 'A';

  late List<Firefly> _fireflies;
  int? _wrongFireflyIndex;
  bool _interactionLocked = false;
  bool _roundCelebrating = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _targetPulseCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;

  static const int _maxFireflies = 6;
  late List<AnimationController> _shakeCtrls;
  late List<Animation<double>> _shakeAnims;
  late List<AnimationController> _burstCtrls;
  late AnimationController _roundCompleteCtrl;

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
    _setupRound(playInstruction: false);
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _roundConfigs[0].moveDurationMs),
    )..repeat();

    _targetPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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

    _shakeCtrls = List.generate(
      _maxFireflies,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _shakeAnims = _shakeCtrls
        .map(
          (c) => TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.1), weight: 25),
            TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 50),
            TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 25),
          ]).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();

    _burstCtrls = List.generate(
      _maxFireflies,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    _roundCompleteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
    if (mounted) await _announceTarget();
  }

  Future<void> _announceTarget() async {
    await playVoiceRestartingOnFaceLoss(audio.voicePlayer, _audioFindPrefix);
    if (!mounted) return;
    await playVoiceRestartingOnFaceLoss(
      audio.voicePlayer,
      ForestAudioAssets.forLetter(_targetLetter),
    );
  }

  void _setupRound({bool playInstruction = true}) {
    final config = _roundConfigs[_currentRound];
    final rng = Random();

    _targetLetter = widget.letterPool[rng.nextInt(widget.letterPool.length)];
    final distractorPool =
        widget.letterPool.where((l) => l != _targetLetter).toList()
          ..shuffle(rng);
    final distractorCount = min(config.fireflyCount - 1, distractorPool.length);
    final distractors = distractorPool.take(distractorCount).toList();

    final letters = [_targetLetter, ...distractors]..shuffle(rng);
    final anchors = _generateAnchors(letters.length, rng);

    _fireflies = List.generate(letters.length, (i) {
      return Firefly(
        letter: letters[i],
        isTarget: letters[i] == _targetLetter,
        anchor: anchors[i],
        ampX: 0.02 + rng.nextDouble() * 0.03,
        ampY: 0.03 + rng.nextDouble() * 0.04,
        phase: rng.nextDouble() * 2 * pi,
      );
    });

    _wrongFireflyIndex = null;
    _interactionLocked = false;
    _roundCelebrating = false;

    for (final ctrl in _shakeCtrls) {
      ctrl.reset();
    }
    for (final ctrl in _burstCtrls) {
      ctrl.reset();
    }
    _roundCompleteCtrl.reset();

    _floatCtrl
      ..duration = Duration(milliseconds: config.moveDurationMs)
      ..repeat();

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _announceTarget();
      });
    }

    setState(() {});
  }

  List<Offset> _generateAnchors(int count, Random rng) {
    final anchors = <Offset>[];

    const double minX = 0.30;
    const double maxX = 0.88;
    const double minY = 0.12;
    const double maxY = 0.82;

    final minDist = max(0.16, 0.30 - 0.02 * count);

    for (int i = 0; i < count; i++) {
      Offset candidate = Offset.zero;

      for (int attempt = 0; attempt < 50; attempt++) {
        candidate = Offset(
          minX + rng.nextDouble() * (maxX - minX),
          minY + rng.nextDouble() * (maxY - minY),
        );

        final farEnough = anchors.every(
          (a) => (a - candidate).distance >= minDist,
        );

        if (farEnough) {
          break;
        }
      }

      anchors.add(candidate);
    }

    return anchors;
  }

  Future<void> _handleFireflyTap(Firefly firefly, int index) async {
    if (_interactionLocked || firefly.popped || _roundCelebrating) return;

    if (firefly.isTarget) {
      await _handleCorrectAnswer(firefly, index);
    } else {
      await _handleWrongAnswer(firefly, index);
    }
  }

  Future<void> _handleCorrectAnswer(Firefly firefly, int index) async {
    _tapTracker.recordCorrectTap();
    _interactionLocked = true;
    HapticFeedback.mediumImpact();

    setState(() => firefly.popped = true);
    _burstCtrls[index].forward(from: 0);

    await showTofiReaction(TofiState.correct);
    if (!mounted) return;

    _solvedRounds++;
    await _celebrateRoundComplete();
    if (!mounted) return;

    await _advanceRound();
  }

  Future<void> _handleWrongAnswer(Firefly firefly, int index) async {
    _tapTracker.recordMistake();
    HapticFeedback.heavyImpact();
    setState(() => _wrongFireflyIndex = index);
    _shakeCtrls[index].forward(from: 0);

    await showTofiReaction(TofiState.wrong);
    if (!mounted) return;
    setState(() => _wrongFireflyIndex = null);
  }

  Future<void> _celebrateRoundComplete() async {
    setState(() => _roundCelebrating = true);
    await _roundCompleteCtrl.forward(from: 0);
  }

  Future<void> _advanceRound() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (_currentRound >= _totalRounds - 1) {
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
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'forest_letter_fireflies',
      activityName: 'Letter Fireflies',
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
              MaterialPageRoute(builder: (_) => AlphabetFishingGame(level: 22)),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LetterFirefliesGame(
                  level: widget.level,
                  letterPool: widget.letterPool,
                ),
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
    _floatCtrl.dispose();
    _targetPulseCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    for (final ctrl in _shakeCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _burstCtrls) {
      ctrl.dispose();
    }
    _roundCompleteCtrl.dispose();
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
          child: Stack(
            children: [
              Image.asset(
                _bgImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Container(color: Colors.indigo.withValues(alpha: 0.18)),
            ],
          ),
        ),

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
              const SizedBox(width: 120),
              const Text('✨', style: TextStyle(fontSize: 90)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    return Stack(
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
              Container(color: Colors.indigo.withValues(alpha: 0.18)),
            ],
          ),
        ),
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
                padding: const EdgeInsets.only(top: 95),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, inner) =>
                            _buildFireflyField(inner.maxWidth, inner.maxHeight),
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

  Widget _buildFireflyField(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          for (int i = 0; i < _fireflies.length; i++)
            _buildFirefly(_fireflies[i], i, w, h),
        ],
      ),
    );
  }

  Widget _buildFirefly(Firefly firefly, int index, double w, double h) {
    if (firefly.popped) {
      return _buildBurst(firefly, index, w, h);
    }

    final config = _roundConfigs[_currentRound];
    final size = h * config.sizeFactor;
    final isWrong = _wrongFireflyIndex == index;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _floatCtrl,
        _shakeCtrls[index],
        _roundCompleteCtrl,
      ]),
      builder: (_, child) {
        final t = _floatCtrl.value * 2 * pi;

        final floatX = sin(t + firefly.phase) * firefly.ampX * w;
        final floatY = cos(t * 1.3 + firefly.phase) * firefly.ampY * h;
        final celebrateBounce = _roundCelebrating
            ? sin(_roundCompleteCtrl.value * pi * 4) * 4
            : 0.0;
        final angle = isWrong ? _shakeAnims[index].value : 0.0;
        final glowBoost = _roundCelebrating
            ? 0.5 + (0.5 * _roundCompleteCtrl.value)
            : 1.0;

        final rawLeft = firefly.anchor.dx * w - size / 2 + floatX;
        final rawTop =
            firefly.anchor.dy * h - size / 2 + floatY + celebrateBounce;

        final safeLeft = rawLeft.clamp(0.0, w - size).toDouble();
        final safeTop = rawTop.clamp(0.0, h - size).toDouble();

        return Positioned(
          left: safeLeft,
          top: safeTop,
          width: size,
          height: size,
          child: Transform.rotate(
            angle: angle,
            child: Opacity(opacity: glowBoost, child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _handleFireflyTap(firefly, index),
        child: _fireflyVisual(firefly.letter, size, wrong: isWrong),
      ),
    );
  }

  Widget _fireflyVisual(String letter, double size, {required bool wrong}) {
    final letterColor = wrong
        ? Colors.red.shade400
        : ForestColorTheme.darkseagreen;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              _fireflyImage,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          Positioned(
            right: size * 0.16,
            bottom: size * 0.08,
            child: _outlinedLetter(
              letter,
              fontSize: size * 0.28,
              fillColor: letterColor,
            ),
          ),
          if (wrong)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.65),
                      blurRadius: size * 0.25,
                      spreadRadius: size * 0.04,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBurst(Firefly firefly, int index, double w, double h) {
    final config = _roundConfigs[_currentRound];
    final size = (h * config.sizeFactor).clamp(48.0, 110.0);

    return AnimatedBuilder(
      animation: _burstCtrls[index],
      builder: (_, __) {
        final t = _burstCtrls[index].value;
        final growT = (t / 0.3).clamp(0.0, 1.0);
        final burstT = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
        final coreScale = 1.0 + Curves.easeOut.transform(growT) * 0.4;
        final sparkleSpread = size * 0.9 * burstT;
        final opacity = 1.0 - burstT;

        return Positioned(
          left: firefly.anchor.dx * w - size / 2,
          top: firefly.anchor.dy * h - size / 2,
          width: size,
          height: size,
          child: Opacity(
            opacity: opacity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < 6; i++)
                  Transform.translate(
                    offset: Offset(
                      cos(i * pi / 3) * sparkleSpread,
                      sin(i * pi / 3) * sparkleSpread,
                    ),
                    child: Text('✨', style: TextStyle(fontSize: size * 0.28)),
                  ),
                Transform.scale(
                  scale: coreScale,
                  child: _fireflyVisual(
                    firefly.letter,
                    size * 0.8,
                    wrong: false,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
