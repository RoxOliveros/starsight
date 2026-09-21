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

class BerryBush {
  final String letter;
  final Offset pos;
  bool harvested;

  BerryBush({required this.letter, required this.pos, this.harvested = false});
}

class BerryBushHarvestGame extends StatefulWidget {
  final int level;
  const BerryBushHarvestGame({super.key, required this.level});

  @override
  State<BerryBushHarvestGame> createState() => _BerryBushHarvestGameState();
}

class _BerryBushHarvestGameState extends State<BerryBushHarvestGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<BerryBushHarvestGame>,
        ForestAudioMixin<BerryBushHarvestGame>,
        TofiReactionMixin<BerryBushHarvestGame>,
        AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest.png';
  static const String _bushFullAsset =
      'assets/images/objects/forest/berry_bush_full.png';
  static const String _bushEmptyAsset =
      'assets/images/objects/forest/berry_bush_empty.png';
  static const String _basketAsset = 'assets/images/objects/puzzle/basket.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static String _basketBerryAsset(int count) =>
      'assets/images/objects/forest/berries_state$count.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro =
      'assets/audio/alphabet_forest/berry_bush_intro.wav';
  static const String _audioInstruction =
      '$_audioBase/berry_bush_instruction.wav';
  static const String _audioHarvestChime =
      '$_audioBase/berry_harvest_chime.wav';
  static const String _audioWin = '$_audioBase/berry_bush_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  static const List<String> _letters = ['P', 'p', 'Q', 'q', 'R', 'r'];
  static const List<String> _promptVerbs = ['Harvest', 'Find', 'Tap'];
  static const Color _berryColor = Color(0xFF4A7CFF);

  static const List<Offset> _bushSlots = [
    Offset(0.24, 0.26),
    Offset(0.50, 0.18),
    Offset(0.80, 0.26),
    Offset(0.33, 0.70),
    Offset(0.50, 0.62),
    Offset(0.70, 0.75),
  ];

  static const Offset _basketPos = Offset(0.93, 0.90);

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late final List<BerryBush> _bushes;
  late List<String> _roundOrder;
  int _currentRoundIndex = 0;
  int _harvestedCount = 0;
  bool _roundLocked = false;
  late String _promptVerb;

  int? _shakingWrongIndex;
  int? _harvestingIndex;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  String get _targetLetter => _roundOrder[_currentRoundIndex];

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl;
  late AnimationController _swayCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late List<AnimationController> _harvestShakeCtrls;
  late List<Animation<double>> _harvestShakeAnims;
  late List<AnimationController> _flashCtrls;
  late List<Animation<double>> _flashAnims;
  late AnimationController _wrongShakeCtrl;
  late Animation<double> _wrongShake;
  late AnimationController _berryFallCtrl;

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

    _bushes = List.generate(
      _letters.length,
      (i) => BerryBush(letter: _letters[i], pos: _bushSlots[i]),
    );

    final random = Random();
    final availableLetters = [..._letters]..shuffle(random);
    _roundOrder = availableLetters.take(5).toList();
    _promptVerb = _promptVerbs[Random().nextInt(_promptVerbs.length)];

    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _swayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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

    _harvestShakeCtrls = List.generate(
      _letters.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _harvestShakeAnims = _harvestShakeCtrls
        .map(
          (c) => TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.05), weight: 25),
            TweenSequenceItem(
              tween: Tween(begin: -0.05, end: 0.05),
              weight: 50,
            ),
            TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 25),
          ]).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)),
        )
        .toList();

    _flashCtrls = List.generate(
      _letters.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _flashAnims = _flashCtrls
        .map(
          (c) => TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
          ]).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)),
        )
        .toList();

    _wrongShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wrongShake =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.1), weight: 25),
          TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 25),
        ]).animate(
          CurvedAnimation(parent: _wrongShakeCtrl, curve: Curves.easeInOut),
        );

    _berryFallCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    if (mounted) await _announceRound();
  }

  Future<void> _announceRound() async {
    if (_currentRoundIndex == 0) {
      await playVoiceRestartingOnFaceLoss(audio.voicePlayer, _audioInstruction);
      if (!mounted) return;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await playVoiceRestartingOnFaceLoss(
      audio.voicePlayer,
      ForestAudioAssets.forLetter(_targetLetter.toUpperCase()),
    );
  }

  bool get _targetIsUpper => _targetLetter == _targetLetter.toUpperCase();

  String get _instructionText {
    final caseWord = _targetIsUpper ? 'Big Letter' : 'Small Letter';
    return '$_promptVerb $caseWord $_targetLetter!';
  }

  void _loadTarget({bool playInstruction = true}) {
    _roundLocked = false;
    _shakingWrongIndex = null;
    _promptVerb = _promptVerbs[Random().nextInt(_promptVerbs.length)];

    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _announceRound();
      });
    }

    setState(() {});
  }

  Future<void> _onBushTapped(BerryBush bush, int index) async {
    if (_roundLocked || bush.harvested) return;

    final isMatch = bush.letter == _targetLetter;

    if (isMatch) {
      _tapTracker.recordCorrectTap();
      _roundLocked = true;
      HapticFeedback.mediumImpact();

      setState(() {
        bush.harvested = true;
        _harvestingIndex = index;
      });

      _harvestShakeCtrls[index].forward(from: 0);
      playVoice(_audioHarvestChime);

      _berryFallCtrl.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _harvestingIndex = null;
          _harvestedCount++;
        });
      });

      await playVoiceRestartingOnFaceLoss(
        audio.voicePlayer,
        ForestAudioAssets.forLetter(_targetLetter.toUpperCase()),
      );
      if (!mounted) return;

      await showTofiReaction(TofiState.correct);
      if (!mounted) return;

      await _advanceRound();
    } else {
      _tapTracker.recordMistake();
      HapticFeedback.heavyImpact();
      setState(() => _shakingWrongIndex = index);

      _wrongShakeCtrl.forward(from: 0);
      _flashCtrls[index].forward(from: 0);

      await showTofiReaction(TofiState.wrong);
      if (!mounted) return;

      setState(() => _shakingWrongIndex = null);
    }
  }

  Future<void> _advanceRound() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    if (_currentRoundIndex >= _roundOrder.length - 1) {
      await playVoice(_audioWin);
      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;

      await _saveDataAndShowGoodJob();
      return;
    }

    _currentRoundIndex++;
    _loadTarget();
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    try {
      await ForestDatabaseService.saveGameData(
        gameId: 'forest_berry_bush_harvest',
        activityName: 'Berry Bush Harvest',
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
                builder: (_) => AlphabetIntroScreen(letter: 'S'),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BerryBushHarvestGame(level: widget.level),
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
    _swayCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    for (final ctrl in _harvestShakeCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _flashCtrls) {
      ctrl.dispose();
    }
    _wrongShakeCtrl.dispose();
    _berryFallCtrl.dispose();
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
              const SizedBox(width: 120),
              Image.asset(
                _bushFullAsset,
                height: screenH * 0.55,
                errorBuilder: (_, __, ___) =>
                    const Text('🫐', style: TextStyle(fontSize: 80)),
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
                            _buildForestArea(inner.maxWidth, inner.maxHeight),
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

  Widget _buildForestArea(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < _bushes.length; i++)
            _buildBush(_bushes[i], i, w, h),
          _buildBasket(w, h),
          _buildFallingBerries(w, h),
        ],
      ),
    );
  }

  Widget _buildBush(BerryBush bush, int index, double w, double h) {
    final bushSize = (h * 0.3).clamp(100.0, 165.0);
    final phase = index * 1.3;

    return Positioned(
      left: bush.pos.dx * w - bushSize / 2,
      top: bush.pos.dy * h - bushSize / 2,
      width: bushSize,
      height: bushSize,
      child: GestureDetector(
        onTap: () => _onBushTapped(bush, index),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _swayCtrl,
            _harvestShakeCtrls[index],
            _flashCtrls[index],
            _wrongShakeCtrl,
          ]),
          builder: (_, child) {
            final swayAngle = bush.harvested
                ? 0.0
                : 0.035 * sin((_swayCtrl.value * 2 * pi) + phase);
            final harvestAngle = _harvestingIndex == index
                ? _harvestShakeAnims[index].value
                : 0.0;
            final wrongAngle = _shakingWrongIndex == index
                ? _wrongShake.value
                : 0.0;

            return Transform.rotate(
              angle: swayAngle + harvestAngle + wrongAngle,
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _flashCtrls[index],
                builder: (_, __) => Opacity(
                  opacity: _flashAnims[index].value * 0.45,
                  child: Container(
                    width: bushSize * 1.15,
                    height: bushSize * 1.15,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),

              Image.asset(
                bush.harvested ? _bushEmptyAsset : _bushFullAsset,
                width: bushSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  bush.harvested ? '🌿' : '🫐',
                  style: TextStyle(fontSize: bushSize * 0.6),
                ),
              ),

              Positioned(
                bottom: bushSize * 0.06,
                child: _outlinedLetter(
                  bush.letter,
                  fontSize: bushSize * 0.3,
                  fillColor: ForestColorTheme.darkseagreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasket(double w, double h) {
    const basketW = 140.0;
    const basketH = 108.0;

    return Positioned(
      bottom: 0,
      right: 0,
      width: basketW,
      height: basketH,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            _basketAsset,
            width: basketW,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('🧺', style: TextStyle(fontSize: 64)),
          ),
          if (_harvestedCount > 0)
            Positioned(
              bottom: basketH * 0.1,
              child: Image.asset(
                _basketBerryAsset(_harvestedCount),
                width: basketW * 0.60,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallingBerries(double w, double h) {
    if (_harvestingIndex == null) return const SizedBox.shrink();

    final bush = _bushes[_harvestingIndex!];
    final start = Offset(bush.pos.dx * w, bush.pos.dy * h + 20);
    final end = Offset(_basketPos.dx * w, _basketPos.dy * h - 12);

    return AnimatedBuilder(
      animation: _berryFallCtrl,
      builder: (_, __) {
        return Stack(
          children: List.generate(4, (i) {
            final interval = Interval(
              (i * 0.08).clamp(0.0, 0.6),
              (0.65 + i * 0.08).clamp(0.0, 1.0),
              curve: Curves.easeIn,
            );
            final t = interval.transform(_berryFallCtrl.value);

            final dx = _lerp(start.dx, end.dx + (i - 1.5) * 9, t);
            final dy = _lerp(start.dy, end.dy, t);
            final arcLift = -26 * sin(t * pi);
            final landBounce = t > 0.85 ? sin((t - 0.85) / 0.15 * pi) * 7 : 0.0;

            return Positioned(
              left: dx - 6,
              top: dy + arcLift - landBounce,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _berryColor,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

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
      children: List.generate(_roundOrder.length, (i) {
        final done = i < _harvestedCount;
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
