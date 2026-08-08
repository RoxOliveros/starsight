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

/// One fish swimming in the pond this round. [startX]/[startY] are the
/// fractional center of its swim lane; it ping-pongs [swimRange] to either
/// side of [startX] and bobs gently in place vertically. [caught]/[wrong]
/// drive its catch and shake feedback.
class _FishData {
  final String letter;
  final double startX;
  final double startY;
  final double speed; // relative swim speed multiplier for this round
  final bool swimsRight; // initial swim direction
  final double swimRange; // fractional horizontal travel from startX
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

/// Per-round difficulty knobs: how many fish, how fast they swim, and how
/// big they are. See the class doc for the full 5-round curve.
class _RoundConfig {
  final int fishCount;
  final int swimDurationMs; // lower = faster ping-pong swim cycle
  final double sizeFactor; // fraction of pond height

  const _RoundConfig({
    required this.fishCount,
    required this.swimDurationMs,
    required this.sizeFactor,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// GAME
// ═════════════════════════════════════════════════════════════════════════

/// "Alphabet Fishing" — Tofi is fishing in a forest pond. Several fish, each
/// carrying a letter, swim back and forth; the child taps the one fish that
/// carries the target letter Tofi called out. Five rounds ramp up fish
/// count and swim speed.
class AlphabetFishingGame extends StatefulWidget {
  final int level;

  /// Letters this level draws its target + distractors from. Defaults to
  /// the full alphabet; pass a narrower pool if you want the game scoped
  /// to specific letters.
  final List<String> letterPool;

  const AlphabetFishingGame({
    super.key,
    required this.level,
    this.letterPool = const [
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
      'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
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
        TofiReactionMixin<AlphabetFishingGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ═════════════════════════════════════════════════════════════════════
  // ASSETS
  // ═════════════════════════════════════════════════════════════════════

  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest_river.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _rodImage = 'assets/images/objects/forest/rod.png';
  static const String _fishImage = 'assets/images/objects/forest/fish.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _sfxBase = ForestAudioAssets.sfxBase;

  static const String _audioIntro = '$_audioBase/alphabet_fishing_intro.wav';
  static const String _audioCatchPrefix = '$_audioBase/alphabet_fishing_catch_prefix.wav';
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
  bool _interactionLocked = false; // true right after a correct catch

  late List<_FishData> _fish;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl; // dog idle float, intro only
  late AnimationController _bobCtrl; // shared vertical-bob + bubble clock
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;

  late List<AnimationController> _swimCtrls; // one horizontal ping-pong per fish
  late List<AnimationController> _shakeCtrls; // one wrong-answer shake per fish
  late List<Animation<double>> _shakeAnims;
  late List<AnimationController> _catchCtrls; // one catch/splash per fish

  // ── Draggable fishing rod ────────────────────────────────────────────────
  Offset _rodPosition = Offset.zero;
  bool _rodInitialized = false;

  double _rodSize = 0;

  /// The actual hook/catch point is near the lower-right corner
  /// of the rod PNG.
  Offset _rodHookPoint = Offset.zero;

  // ═════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
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

    _swimCtrls = List.generate(
      _maxFish,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 2000)),
    );

    _shakeCtrls = List.generate(
      _maxFish,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400)),
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
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 650)),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // INTRO FLOW
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    // Per the audio-timing rule: the full instruction (prefix + letter) is
    // only ever auto-played here, once, at the very start of round 1.
    await _announceInstruction();
  }

  /// Plays "Catch the letter ___!" — a shared lead-in clip followed by the
  /// existing per-letter clip. Also used to replay the instruction when the
  /// child taps the banner, at any point in the game.
  Future<void> _announceInstruction() async {
    await playVoice(_audioCatchPrefix);
    if (!mounted) return;
    await playVoice(ForestAudioAssets.forLetter(_targetLetter));
  }

  // ═════════════════════════════════════════════════════════════════════
  // ROUND SETUP
  // ═════════════════════════════════════════════════════════════════════

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

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    setState(() {});
    // NOTE: deliberately no automatic instruction/voice playback here for
    // rounds after the first — see the audio-timing rule in the intro flow
    // and _handleCorrectAnswer. The banner remains tappable at all times.
  }

  // ═════════════════════════════════════════════════════════════════════
  // FISH GENERATION
  // ═════════════════════════════════════════════════════════════════════

  void _generateFish() {
    final config = _roundConfigs[_currentRound];
    final rng = Random();

    // Exactly one target, unique distractors — never the target letter,
    // never repeated among themselves.
    _targetLetter = widget.letterPool[rng.nextInt(widget.letterPool.length)];
    final distractorPool = widget.letterPool.where((l) => l != _targetLetter).toList()
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
      final baseMs = (_roundConfigs[_currentRound].swimDurationMs / _fish[i].speed).round();
      _swimCtrls[i]
        ..duration = Duration(milliseconds: baseMs)
        ..repeat(reverse: true);
    }
  }

  /// Rejection-samples fractional lane centers within the pond area so fish
  /// don't spawn stacked on each other, staying clear of the target-letter
  /// and instruction-banner zone up top. Falls back to whatever it has
  /// after a bounded number of tries rather than looping forever.
  List<Offset> _generateLanes(int count, Random rng) {
    final lanes = <Offset>[];
    final minDist = max(0.16, 0.32 - 0.02 * count);

    for (int i = 0; i < count; i++) {
      Offset candidate = Offset.zero;
      for (int attempt = 0; attempt < 20; attempt++) {
        candidate = Offset(
          0.18 + rng.nextDouble() * 0.64,
          0.20 + rng.nextDouble() * 0.68,
        );
        final farEnough = lanes.every((l) => (l - candidate).distance >= minDist);
        if (farEnough) break;
      }
      lanes.add(candidate);
    }
    return lanes;
  }

  // ═════════════════════════════════════════════════════════════════════
  // GAMEPLAY
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _handleFishTap(_FishData fish, int index) async {
    if (_interactionLocked || fish.caught) return;

    if (fish.letter == _targetLetter) {
      await _handleCorrectAnswer(fish, index);
    } else {
      await _handleWrongAnswer(fish, index);
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // CORRECT ANSWER
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _handleCorrectAnswer(_FishData fish, int index) async {
    _interactionLocked = true; // block further taps immediately
    HapticFeedback.mediumImpact();

    _swimCtrls[index].stop(); // freeze it before the catch animation
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

  // ═════════════════════════════════════════════════════════════════════
  // WRONG ANSWER
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _handleWrongAnswer(_FishData fish, int index) async {
    HapticFeedback.heavyImpact();
    setState(() => fish.wrong = true);
    _shakeCtrls[index].forward(from: 0);

    await showTofiReaction(TofiState.wrong);
    if (!mounted) return;
    setState(() => fish.wrong = false);
  }

  // ═════════════════════════════════════════════════════════════════════
  // ROUND PROGRESSION
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _advanceRound() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (_currentRound >= _totalRounds - 1) {
      await playVoice(_audioWin);
      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;

      _showGoodJob();
      return;
    }

    _currentRound++;
    _setupRound();
  }

  // ═════════════════════════════════════════════════════════════════════
  // GOOD JOB
  // ═════════════════════════════════════════════════════════════════════

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
              MaterialPageRoute(
                builder: (_) => AlphabetIntroScreen(letter: 'A'),
              ),
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

    // Initial position of the rod.
    // This is the TOP-LEFT corner of the PNG.
    _rodPosition = Offset(
      w * 0.55,
      h * 0.02,
    );

    _rodInitialized = true;

    _updateRodHookPoint();
  }

  void _updateRodHookPoint() {
    // The hook in the supplied rod image is approximately
    // at the lower-right portion of the square PNG.
    _rodHookPoint = _rodPosition + Offset(
      _rodSize * 0.95,
      _rodSize * 0.91,
    );
  }

  void _moveRod(Offset delta, double w, double h) {
    if (_interactionLocked) return;

    final newX = (_rodPosition.dx + delta.dx)
        .clamp(-_rodSize * 0.1, w - _rodSize * 0.85);

    final newY = (_rodPosition.dy + delta.dy)
        .clamp(-_rodSize * 0.5, h - _rodSize * 0.75);

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

      final fishSize =
      (h * config.sizeFactor).clamp(56.0, 130.0).toDouble();

      final direction = fish.swimsRight ? 1.0 : -1.0;

      final swimT =
      Curves.easeInOut.transform(_swimCtrls[i].value);

      final swimOffset =
          (swimT * 2 - 1) *
              fish.swimRange *
              direction;

      final bobY =
          sin(
            (_bobCtrl.value * 2 * pi) +
                fish.startX * 6.28,
          ) *
              0.02;

      final fishX =
          (fish.startX + swimOffset) * w -
              fishSize / 2;

      final fishY =
          (fish.startY + bobY) * h -
              fishSize / 2;

      final fishRect = Rect.fromLTWH(
        fishX,
        fishY,
        fishSize,
        fishSize * 0.7,
      );

      // The hook must actually be over the fish.
// The hook must actually be over the fish.
      if (fishRect.contains(_rodHookPoint)) {
        fish.caughtX = fishX;
        fish.caughtY = fishY;

        _handleRodCatch(fish, i);
        return;
      }
    }
  }

  Future<void> _handleRodCatch(
      _FishData fish,
      int index,
      ) async {
    if (_interactionLocked || fish.caught) return;

    if (fish.letter == _targetLetter) {
      await _handleCorrectAnswer(fish, index);
    } else {
      await _handleWrongAnswer(fish, index);
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
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

  // ═════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
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
                child: Image.asset(
                  _dogImage,
                  height: screenH * 0.72,
                  errorBuilder: (_, __, ___) => const Text('🐶', style: TextStyle(fontSize: 80)),
                ),
              ),
              const SizedBox(width: 120),
              const Text('🎣', style: TextStyle(fontSize: 90)),
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
              const Positioned(top: 25, left: 20, child: ForestBackButton()),
              Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),

              Positioned(
                top: 25,
                left: 0,
                right: 0,
                child: Center(
                  child: ScaleTransition(
                    scale: _instructionBounce,
                    child: GestureDetector(
                      onTap: _announceInstruction,
                      child: ForestInstructionBanner(
                        text: 'Catch the letter $_targetLetter!',
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 190),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, inner) => _buildPond(inner.maxWidth, inner.maxHeight),
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

  // ═════════════════════════════════════════════════════════════════════
  // POND
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildPond(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Water surface, lower/middle of the play area.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: h * 0.82,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ForestColorTheme.seagreen.withValues(alpha: 0.18),
                    ForestColorTheme.darkseagreen.withValues(alpha: 0.32),
                  ],
                ),
              ),
            ),
          ),

          // Decorative, non-interactive lily pads and reeds around the edges.
          Positioned(left: w * 0.03, bottom: h * 0.05, child: const Text('🌿', style: TextStyle(fontSize: 34))),
          Positioned(right: w * 0.04, bottom: h * 0.08, child: const Text('🌾', style: TextStyle(fontSize: 30))),
          Positioned(left: w * 0.1, top: h * 0.12, child: const Text('🍃', style: TextStyle(fontSize: 22))),
          Positioned(right: w * 0.12, top: h * 0.08, child: const Text('🍂', style: TextStyle(fontSize: 22))),
          const Positioned(left: 24, bottom: 18, child: _LilyPad(size: 46)),
          const Positioned(right: 40, bottom: 30, child: _LilyPad(size: 36)),

          // Slow-rising bubbles, purely decorative.
          for (int i = 0; i < 4; i++) _buildBubble(i, w, h),

          // The fish themselves, on top of the decorations.
          for (int i = 0; i < _fish.length; i++) _buildFish(_fish[i], i, w, h),

          _buildDraggableRod(w, h),
        ],
      ),
    );
  }

  Widget _buildDraggableRod(
      double w,
      double h,
      ) {
    _initializeRod(w, h);

    return Positioned(
      left: _rodPosition.dx,
      top: _rodPosition.dy,
      width: _rodSize,
      height: _rodSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onPanUpdate: (details) {
          _moveRod(
            details.delta,
            w,
            h,
          );
        },

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
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // FISH
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildFish(
      _FishData fish,
      int index,
      double w,
      double h,
      ) {
    if (fish.caught) {
      return _buildCatchAnimation(
        fish,
        index,
        w,
        h,
      );
    }

    final config = _roundConfigs[_currentRound];

    final size =
    (h * config.sizeFactor)
        .clamp(56.0, 130.0)
        .toDouble();

    final direction =
    fish.swimsRight ? 1.0 : -1.0;

    final phase =
        fish.startX * 6.28;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _swimCtrls[index],
        _bobCtrl,
        _shakeCtrls[index],
      ]),
      builder: (_, child) {
        final swimT =
        Curves.easeInOut.transform(
          _swimCtrls[index].value,
        );

        final swimOffset =
            (swimT * 2 - 1) *
                fish.swimRange *
                direction;

        final bobY =
            sin(
              (_bobCtrl.value * 2 * pi) +
                  phase,
            ) *
                0.02;

        final angle =
        fish.wrong
            ? _shakeAnims[index].value
            : 0.0;

        final flip =
        direction < 0 ? -1.0 : 1.0;

        final fishX =
            (fish.startX + swimOffset) * w -
                size / 2;

        final fishY =
            (fish.startY + bobY) * h -
                size / 2;

        return Positioned(
          left: fishX,
          top: fishY,
          width: size,
          height: size,
          child: Transform.rotate(
            angle: angle,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(flip, 1.0),
              child: child,
            ),
          ),
        );
      },
        child: _fishVisual(
          fish.letter,
          size,
          wrong: fish.wrong,
          flip: fish.swimsRight ? 1.0 : -1.0,
        )
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
          // ONLY the fish image is flipped.
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

          // Letter stays NORMAL and readable.
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

  Widget _buildCatchAnimation(
      _FishData fish,
      int index,
      double w,
      double h,
      ) {
    final config = _roundConfigs[_currentRound];

    final fishSize =
    (h * config.sizeFactor)
        .clamp(56.0, 130.0)
        .toDouble();

    return AnimatedBuilder(
      animation: _catchCtrls[index],
      builder: (_, __) {
        final t = _catchCtrls[index].value;

        final progress =
        Curves.easeOutBack.transform(
          t.clamp(0.0, 1.0),
        );

        final fishX =
            fish.caughtX ??
                (fish.startX * w - fishSize / 2);

        final fishY =
            fish.caughtY ??
                (fish.startY * h - fishSize / 2);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Fish being pulled upward
            Positioned(
              left: fishX,
              top: fishY -
                  progress * fishSize * 0.35,
              width: fishSize,
              height: fishSize,
              child: Transform.scale(
                scale: 1.0 + progress * 0.15,
                child: _fishVisual(
                  fish.letter,
                  fishSize,
                  wrong: false,
                  flip: fish.swimsRight ? 1.0 : -1.0,
                )
              ),
            ),

            // Splash
            for (int i = 0; i < 5; i++)
              Positioned(
                left:
                fishX + fishSize / 2,
                top:
                fishY + fishSize / 2,
                child: Opacity(
                  opacity: 1.0 - t,
                  child: Transform.translate(
                    offset: Offset(
                      cos(i * 2 * pi / 5) *
                          fishSize *
                          0.7 *
                          t,
                      sin(i * 2 * pi / 5) *
                          fishSize *
                          0.4 *
                          t,
                    ),
                    child: const Text(
                      '💧',
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Letter rendered with a white outline behind a solid fill, so it reads
  /// clearly against the fish/pond artwork underneath.
  Widget _outlinedLetter(String letter, {required double fontSize, required Color fillColor}) {
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

  // ═════════════════════════════════════════════════════════════════════
  // PROGRESS
  // ═════════════════════════════════════════════════════════════════════

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

// ═════════════════════════════════════════════════════════════════════════
// DECORATIVE HELPERS
// ═════════════════════════════════════════════════════════════════════════

/// A simple painted lily pad — purely decorative, non-interactive.
class _LilyPad extends StatelessWidget {
  final double size;
  const _LilyPad({required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(size, size),
        painter: _LilyPadPainter(),
      ),
    );
  }
}

class _LilyPadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = ForestColorTheme.mediumseagreen.withValues(alpha: 0.85),
    );

    // A simple notch wedge to read as a classic lily-pad shape.
    final notch = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + radius, center.dy - radius * 0.15)
      ..lineTo(center.dx + radius, center.dy + radius * 0.15)
      ..close();
    canvas.drawPath(notch, Paint()..color = ForestColorTheme.darkseagreen.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A simple painted fish body (oval + tail triangle) — no art asset needed.
class _FishPainter extends CustomPainter {
  final Color bodyColor;
  const _FishPainter({required this.bodyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = bodyColor;
    final bodyRect = Rect.fromLTWH(size.width * 0.18, 0, size.width * 0.68, size.height);
    canvas.drawOval(bodyRect, paint);

    final tailPath = Path()
      ..moveTo(size.width * 0.18, size.height * 0.1)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(size.width * 0.18, size.height * 0.9)
      ..close();
    canvas.drawPath(tailPath, paint);

    // Simple eye for personality.
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.38),
      size.height * 0.08,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.38),
      size.height * 0.04,
      Paint()..color = Colors.black87,
    );
  }

  @override
  bool shouldRepaint(covariant _FishPainter oldDelegate) => oldDelegate.bodyColor != bodyColor;
}
