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
import 'forest_game_train.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

class _FishData {
  final String letter;
  final double startX;
  final double startY;
  final double speed;
  final bool swimsRight;
  final double swimRange;
  bool caught;
  bool wrong;
  double? caughtX;
  double? caughtY;

  _FishData({
    required this.letter,
    required this.startX,
    required this.startY,
    required this.speed,
    required this.swimsRight,
    required this.swimRange,
    this.caught = false,
    this.wrong = false,
  });
}

class _RoundConfig {
  final int fishCount;
  final int swimDurationMs;
  final double sizeFactor;

  const _RoundConfig({
    required this.fishCount,
    required this.swimDurationMs,
    required this.sizeFactor,
  });
}

class AlphabetFishingGame extends StatefulWidget {
  final int level;
  final List<String> letterPool;

  const AlphabetFishingGame({
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
  State<AlphabetFishingGame> createState() => _AlphabetFishingGameState();
}

class _AlphabetFishingGameState extends State<AlphabetFishingGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<AlphabetFishingGame>,
        ForestAudioMixin<AlphabetFishingGame>,
        TofiReactionMixin<AlphabetFishingGame>,
        AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ═════════════════════════════════════════════════════════════════════
  // ASSETS
  // ═════════════════════════════════════════════════════════════════════

  static const String _bgImage =
      'assets/images/backgrounds/bg_game_forest_river.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _rodImage = 'assets/images/objects/forest/rod.png';
  static const String _fishImage = 'assets/images/objects/forest/fish.png';
  static const String _rodFishImage =
      'assets/images/objects/forest/rod_fish.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _sfxBase = ForestAudioAssets.sfxBase;

  static const String _audioIntro = '$_audioBase/alphabet_fishing_intro.wav';
  static const String _audioCatch = '$_audioBase/alphabet_fishing_catch.wav';
  static const String _audioWin = '$_audioBase/alphabet_fishing_win.wav';

  static const String _sfxCatch = '$_sfxBase/fish_catch_splash.wav';
  static const String _sfxRoundComplete = '$_sfxBase/fish_round_complete.wav';

  // ═════════════════════════════════════════════════════════════════════
  // GAME STRUCTURE
  // ═════════════════════════════════════════════════════════════════════

  static const List<_RoundConfig> _roundConfigs = [
    _RoundConfig(fishCount: 3, swimDurationMs: 2800, sizeFactor: 0.30),
    _RoundConfig(fishCount: 4, swimDurationMs: 2300, sizeFactor: 0.27),
    _RoundConfig(fishCount: 5, swimDurationMs: 1900, sizeFactor: 0.25),
    _RoundConfig(fishCount: 5, swimDurationMs: 1500, sizeFactor: 0.24),
    _RoundConfig(fishCount: 6, swimDurationMs: 1200, sizeFactor: 0.22),
  ];
  static int get _totalRounds => _roundConfigs.length;
  static const int _maxFish = 6;

  // ═════════════════════════════════════════════════════════════════════
  // STATE
  // ═════════════════════════════════════════════════════════════════════

  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  String _targetLetter = 'A';
  bool _interactionLocked = false;

  late List<_FishData> _fish;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl;
  late AnimationController _bobCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;

  late List<AnimationController> _swimCtrls;
  late List<AnimationController> _shakeCtrls;
  late List<Animation<double>> _shakeAnims;
  late List<AnimationController> _catchCtrls;

  // ── Draggable fishing rod ────────────────────────────────────────────────
  Offset _rodPosition = Offset.zero;
  bool _rodInitialized = false;

  double _rodSize = 0;

  double _pondW = 0;
  double _pondH = 0;
  static const double _pondTopOffset = 190;

  Offset _rodHookPoint = Offset.zero;

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
    _setupRound(isFirstRound: true);
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

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

    _swimCtrls = List.generate(
      _maxFish,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
    );

    _shakeCtrls = List.generate(
      _maxFish,
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

    _catchCtrls = List.generate(
      _maxFish,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 650),
      ),
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
    await _announceInstruction();
  }

  Future<void> _announceInstruction() async {
    await playVoiceRestartingOnFaceLoss(audio.voicePlayer, _audioCatch);
    if (!mounted) return;
    await playVoiceRestartingOnFaceLoss(
      audio.voicePlayer,
      ForestAudioAssets.forLetter(_targetLetter),
    );
  }

  void _setupRound({bool isFirstRound = false}) {
    _interactionLocked = false;

    for (final ctrl in _shakeCtrls) {
      ctrl.reset();
    }
    for (final ctrl in _catchCtrls) {
      ctrl.reset();
    }

    _generateFish();

    _rodInitialized = false;

    if (isFirstRound) {
      _sceneEnterCtrl.forward(from: 0);
    }

    setState(() {});

    if (!isFirstRound) {
      _announceInstruction();
    }
  }

  void _generateFish() {
    final config = _roundConfigs[_currentRound];
    final rng = Random();

    _targetLetter = widget.letterPool[rng.nextInt(widget.letterPool.length)];
    final distractorPool =
        widget.letterPool.where((l) => l != _targetLetter).toList()
          ..shuffle(rng);
    final distractorCount = min(config.fishCount - 1, distractorPool.length);
    final distractors = distractorPool.take(distractorCount).toList();

    final letters = [_targetLetter, ...distractors]..shuffle(rng);
    final lanes = _generateLanes(letters.length, rng);

    _fish = List.generate(letters.length, (i) {
      final lane = lanes[i];
      return _FishData(
        letter: letters[i],
        startX: lane.dx,
        startY: lane.dy,
        speed: 0.85 + rng.nextDouble() * 0.3,
        swimsRight: rng.nextBool(),
        swimRange: 0.06 + rng.nextDouble() * 0.04,
      );
    });

    for (int i = 0; i < _fish.length; i++) {
      final baseMs =
          (_roundConfigs[_currentRound].swimDurationMs / _fish[i].speed)
              .round();
      _swimCtrls[i]
        ..duration = Duration(milliseconds: baseMs)
        ..repeat(reverse: true);
    }
  }

  List<Offset> _generateLanes(int count, Random rng) {
    final lanes = <Offset>[];
    final minDist = max(0.16, 0.32 - 0.02 * count);

    for (int i = 0; i < count; i++) {
      Offset candidate = Offset.zero;
      for (int attempt = 0; attempt < 20; attempt++) {
        candidate = Offset(
          0.30 + rng.nextDouble() * 0.52,
          0.20 + rng.nextDouble() * 0.68,
        );
        final farEnough = lanes.every(
          (l) => (l - candidate).distance >= minDist,
        );
        if (farEnough) break;
      }
      lanes.add(candidate);
    }
    return lanes;
  }

  Future<void> _handleCorrectAnswer(_FishData fish, int index) async {
    _tapTracker.recordCorrectTap();
    _interactionLocked = true;
    HapticFeedback.mediumImpact();

    _swimCtrls[index].stop();
    setState(() => fish.caught = true);

    playSfx(_sfxCatch);
    await _catchCtrls[index].forward(from: 0);
    if (!mounted) return;

    await showTofiReaction(TofiState.correct);
    if (!mounted) return;

    playSfx(_sfxRoundComplete);
    _solvedRounds++;

    await _advanceRound();
  }

  Future<void> _handleWrongAnswer(_FishData fish, int index) async {
    _tapTracker.recordMistake();
    HapticFeedback.heavyImpact();
    setState(() => fish.wrong = true);
    _shakeCtrls[index].forward(from: 0);

    await showTofiReaction(TofiState.wrong);
    if (!mounted) return;
    setState(() => fish.wrong = false);
  }

  Future<void> _advanceRound() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (_currentRound >= _totalRounds - 1) {
      await playVoice(_audioWin);
      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);
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

    try {
      await ForestDatabaseService.saveGameData(
        gameId: 'forest_alphabet_fishing',
        activityName: 'Alphabet Fishing',
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
              MaterialPageRoute(builder: (_) => AlphabetTrainGame(level: 23)),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlphabetFishingGame(
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

  void _initializeRod(double w, double h) {
    if (_rodInitialized) return;
    _rodSize = min(h * 0.58, 260.0);
    _rodPosition = Offset(w - _rodSize * 1.3, -_rodSize * 1);
    _rodInitialized = true;
    _updateRodHookPoint();
  }

  void _updateRodHookPoint() {
    _rodHookPoint = _rodPosition + Offset(_rodSize * 0.05, _rodSize * 0.91);
  }

  void _moveRod(Offset delta, double w, double h) {
    if (_interactionLocked) return;

    final newX = (_rodPosition.dx + delta.dx).clamp(
      -_rodSize * 0.85,
      w - _rodSize * 0.15,
    );

    final newY = (_rodPosition.dy + delta.dy).clamp(
      -_rodSize * 0.85,
      h - _rodSize * 0.15,
    );

    setState(() {
      _rodPosition = Offset(newX, newY);
      _updateRodHookPoint();
    });

    _checkRodCollision(w, h);
  }

  void _checkRodCollision(double w, double h) {
    if (_interactionLocked) return;

    for (int i = 0; i < _fish.length; i++) {
      final fish = _fish[i];
      if (fish.caught) continue;

      final config = _roundConfigs[_currentRound];
      final fishSize = (h * config.sizeFactor).clamp(56.0, 130.0).toDouble();
      final direction = fish.swimsRight ? 1.0 : -1.0;
      final swimT = Curves.easeInOut.transform(_swimCtrls[i].value);
      final swimOffset = (swimT * 2 - 1) * fish.swimRange * direction;
      final bobY = sin((_bobCtrl.value * 2 * pi) + fish.startX * 6.28) * 0.02;
      final fishX = (fish.startX + swimOffset) * w - fishSize / 2;
      final fishY = (fish.startY + bobY) * h - fishSize / 2;
      final fishRect = Rect.fromLTWH(fishX, fishY, fishSize, fishSize * 0.7);

      if (fishRect.contains(_rodHookPoint)) {
        fish.caughtX = fishX;
        fish.caughtY = fishY;
        _handleRodCatch(fish, i);
        return;
      }
    }
  }

  Future<void> _handleRodCatch(_FishData fish, int index) async {
    if (_interactionLocked || fish.caught) return;

    if (fish.letter == _targetLetter) {
      await _handleCorrectAnswer(fish, index);
    } else {
      await _handleWrongAnswer(fish, index);
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    _tofiFloatCtrl.dispose();
    _bobCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    for (final ctrl in _swimCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _shakeCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _catchCtrls) {
      ctrl.dispose();
    }
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
                  height: screenH * 0.60,
                  errorBuilder: (_, __, ___) =>
                      const Text('🐶', style: TextStyle(fontSize: 80)),
                ),
              ),
              const SizedBox(width: 120),
              Image.asset(_rodFishImage, height: screenH * 0.60),
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
        const progressDotsHeight = 26.0;
        _pondW = constraints.maxWidth;
        _pondH = (constraints.maxHeight - _pondTopOffset - progressDotsHeight)
            .clamp(0.0, double.infinity);

        return ScaleTransition(
          scale: _sceneEnter,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(top: 25, left: 25, child: ForestXButton()),
              Positioned(
                top: 25,
                right: 20,
                child: ForestLevelBadge(level: widget.level),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 190),
                child: Column(
                  children: [
                    Expanded(child: _buildPond(_pondW, _pondH)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _buildProgressDots(),
                    ),
                  ],
                ),
              ),
              _buildDraggableRod(_pondW, _pondH),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPond(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < 4; i++) _buildBubble(i, w, h),
          for (int i = 0; i < _fish.length; i++) _buildFish(_fish[i], i, w, h),
        ],
      ),
    );
  }

  Widget _buildDraggableRod(double w, double h) {
    _initializeRod(w, h);

    return Positioned(
      left: _rodPosition.dx,
      top: _rodPosition.dy + _pondTopOffset,
      width: _rodSize,
      height: _rodSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => _moveRod(details.delta, w, h),
        child: Image.asset(
          _rodImage,
          width: _rodSize,
          height: _rodSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildBubble(int index, double w, double h) {
    final baseX = 0.15 + (index * 0.22);
    return AnimatedBuilder(
      animation: _bobCtrl,
      builder: (_, __) {
        final t = (_bobCtrl.value + index * 0.25) % 1.0;
        final y = h * (0.75 - t * 0.5);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        return Positioned(
          left: baseX * w,
          top: y,
          child: Opacity(
            opacity: opacity * 0.6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFish(_FishData fish, int index, double w, double h) {
    if (fish.caught) {
      return _buildCatchAnimation(fish, index, w, h);
    }

    final config = _roundConfigs[_currentRound];
    final size = (h * config.sizeFactor).clamp(56.0, 130.0).toDouble();
    final direction = fish.swimsRight ? 1.0 : -1.0;
    final phase = fish.startX * 6.28;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _swimCtrls[index],
        _bobCtrl,
        _shakeCtrls[index],
      ]),
      builder: (_, child) {
        final swimT = Curves.easeInOut.transform(_swimCtrls[index].value);
        final swimOffset = (swimT * 2 - 1) * fish.swimRange * direction;
        final bobY = sin((_bobCtrl.value * 2 * pi) + phase) * 0.02;
        final angle = fish.wrong ? _shakeAnims[index].value : 0.0;
        final fishX = (fish.startX + swimOffset) * w - size / 2;
        final fishY = (fish.startY + bobY) * h - size / 2;

        return Positioned(
          left: fishX,
          top: fishY,
          width: size,
          height: size,
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: _fishVisual(
        fish.letter,
        size,
        wrong: fish.wrong,
        flip: fish.swimsRight ? 1.0 : -1.0,
      ),
    );
  }

  Widget _fishVisual(
    String letter,
    double size, {
    required bool wrong,
    required double flip,
  }) {
    return SizedBox(
      width: size,
      height: size * 0.7,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(flip, 1.0),
            child: Image.asset(
              _fishImage,
              width: size,
              height: size * 0.7,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.phishing,
                  size: 60,
                  color: Colors.orange,
                );
              },
            ),
          ),
          _outlinedLetter(
            letter,
            fontSize: size * 0.32,
            fillColor: wrong
                ? Colors.red.shade600
                : ForestColorTheme.darkseagreen,
          ),
        ],
      ),
    );
  }

  Widget _buildCatchAnimation(_FishData fish, int index, double w, double h) {
    final config = _roundConfigs[_currentRound];
    final fishSize = (h * config.sizeFactor).clamp(56.0, 130.0).toDouble();

    return AnimatedBuilder(
      animation: _catchCtrls[index],
      builder: (_, __) {
        final t = _catchCtrls[index].value;
        final progress = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
        final fishX = fish.caughtX ?? (fish.startX * w - fishSize / 2);
        final fishY = fish.caughtY ?? (fish.startY * h - fishSize / 2);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: fishX,
              top: fishY - progress * fishSize * 0.35,
              width: fishSize,
              height: fishSize,
              child: Transform.scale(
                scale: 1.0 + progress * 0.15,
                child: _fishVisual(
                  fish.letter,
                  fishSize,
                  wrong: false,
                  flip: fish.swimsRight ? 1.0 : -1.0,
                ),
              ),
            ),
            for (int i = 0; i < 5; i++)
              Positioned(
                left: fishX + fishSize / 2,
                top: fishY + fishSize / 2,
                child: Opacity(
                  opacity: 1.0 - t,
                  child: Transform.translate(
                    offset: Offset(
                      cos(i * 2 * pi / 5) * fishSize * 0.7 * t,
                      sin(i * 2 * pi / 5) * fishSize * 0.4 * t,
                    ),
                    child: const Text('💧', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
          ],
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
