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

/// One of the six mushrooms shown this round. [letter] keeps its exact
/// case (e.g. 'M' vs 'm') since case is the whole point of the game.
/// [pos] is re-shuffled every round; [revealed] flips to true the moment
/// this is the correctly-tapped mushroom, popping its hidden animal out.
class MushroomSpot {
  final String letter; // exact case, e.g. 'M' or 'm'
  Offset pos;
  String animalAsset;
  bool revealed;

  MushroomSpot({
    required this.letter,
    required this.pos,
    required this.animalAsset,
    this.revealed = false,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// GAME
// ═════════════════════════════════════════════════════════════════════════

/// "Find the Correct Mushroom" — six mushrooms are scattered across the
/// forest floor, one for each of M/m/N/n/O/o. Every round the child is
/// asked for a specific letter *and case* ("Tap uppercase M!"); tapping the
/// matching mushroom pops it open to reveal a hidden animal as a reward.
/// Wrong taps just shake and flash red so the child can try again — the
/// round only advances once the correct mushroom is found. Reinforces
/// uppercase ↔ lowercase recognition for M/N/O.
class MushroomHideAndSeekGame extends StatefulWidget {
  final int level;
  const MushroomHideAndSeekGame({super.key, required this.level});

  @override
  State<MushroomHideAndSeekGame> createState() => _MushroomHideAndSeekGameState();
}

class _MushroomHideAndSeekGameState extends State<MushroomHideAndSeekGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<MushroomHideAndSeekGame>,
        ForestAudioMixin<MushroomHideAndSeekGame>,
        TofiReactionMixin<MushroomHideAndSeekGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest.png';
  static const String _mushroomAsset = 'assets/images/objects/forest/mushroom.png';
  static const String _dogImage = 'assets/images/characters/dog.png';

  // Animals hiding behind the mushrooms. Only one asset exists today, but
  // keeping this as a list means dropping in more art later is a one-line
  // change — round setup already picks randomly from whatever's here.
  static const List<String> _animalAssets = [
    'assets/images/objects/forest/ladybug.png',
  ];

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/mushroom_hide_n_seek_intro.wav';
  static const String _audioInstruction = '$_audioBase/mushroom_hide_n_seek_intructions.wav';
  static const String _audioWin = '$_audioBase/mushroom_hide_n_seek_win.wav';
  static const String _audioBig = '$_audioBase/big.wav';
  static const String _audioSmall = '$_audioBase/small.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  // Exactly one uppercase and one lowercase mushroom per letter.
  static const List<String> _letters = ['M', 'm', 'N', 'n', 'O', 'o'];
  static const int _totalRounds = 5;
  static const List<String> _promptVerbs = ['Tap', 'Find'];

  // Fixed slot positions the six mushrooms are shuffled across every round —
  // a loose two-row, staggered arrangement rather than a rigid grid.
  static const List<Offset> _mushroomSlots = [
    Offset(0.24, 0.30),
    Offset(0.50, 0.20),
    Offset(0.73, 0.30),
    Offset(0.32, 0.74),
    Offset(0.58, 0.82),
    Offset(0.82, 0.70),
  ];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  bool _roundLocked = false; // true right after a correct tap, until advance

  late final List<MushroomSpot> _mushrooms; // 6 mushrooms, one per letter
  late String _targetLetter; // exact-case target for this round
  late String _promptVerb;
  int? _shakingIndex; // index of the mushroom currently shaking on a wrong tap

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl; // dog idle float, intro only
  late AnimationController _mushroomBounceCtrl; // shared idle bounce for mushrooms
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late List<AnimationController> _bloomCtrls; // one elastic pop-open per mushroom
  late List<Animation<double>> _bloomAnims;
  late List<AnimationController> _flashCtrls; // one red-flash pulse per mushroom
  late List<Animation<double>> _flashAnims;
  late AnimationController _shakeCtrl; // shared wrong-answer shake
  late Animation<double> _shake;
  late List<AnimationController> _bugWalkCtrls;
  late List<Animation<double>> _bugWalkAnims;
  late List<String> _roundLetters;

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _mushrooms = List.generate(
      _letters.length,
          (i) => MushroomSpot(
        letter: _letters[i],
        pos: _mushroomSlots[i],
        animalAsset: _animalAssets[0],
      ),
    );
    _initAnimations();
    _roundLetters = [..._letters]..shuffle(Random());
    _setupRound(playInstruction: false);
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _mushroomBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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

    _bloomCtrls = List.generate(
      _letters.length,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 550),
      ),
    );
    _bloomAnims = _bloomCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.elasticOut))
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

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _bugWalkCtrls = List.generate(
      _letters.length,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      ),
    );

    _bugWalkAnims = _bugWalkCtrls
        .map((c) => CurvedAnimation(
      parent: c,
      curve: Curves.easeInOut,
    ))
        .toList();
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await _announceRound();
  }

  /// Plays the round instruction (round 1 only), then reads out this
  /// round's target letter.
  Future<void> _announceRound() async {
    if (_currentRound == 0) {
      await playVoice(_audioInstruction);
      if (!mounted) return;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await playVoice(_targetIsUpper ? _audioBig : _audioSmall);
    await playVoice(ForestAudioAssets.forLetter(_targetLetter.toUpperCase()));
  }

  bool get _targetIsUpper => _targetLetter == _targetLetter.toUpperCase();

  String get _instructionText {
    final caseWord = _targetIsUpper ? 'Big' : 'Small';
    return '$_promptVerb $caseWord Letter $_targetLetter!';
  }

  void _setupRound({bool playInstruction = true}) {
    _roundLocked = false;
    _shakingIndex = null;

    final rng = Random();

    // Only reset temporary effects (shake/flash).
    for (final ctrl in _flashCtrls) {
      ctrl.reset();
    }
    _shakeCtrl.reset();

    // Keep mushroom positions and revealed state.
    // (No more reshuffling.)

    _targetLetter = _roundLetters[_currentRound];
    _promptVerb = _promptVerbs[rng.nextInt(_promptVerbs.length)];

    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _announceRound();
      });
    }

    setState(() {});
  }

  // ── Tap handling ─────────────────────────────────────────────────────────
  Future<void> _onMushroomTapped(MushroomSpot mushroom, int index) async {
    if (_roundLocked || mushroom.revealed) return;

    final isMatch = mushroom.letter == _targetLetter;

    if (isMatch) {
      _roundLocked = true;
      HapticFeedback.mediumImpact();
      setState(() => mushroom.revealed = true);

      _bloomCtrls[index].forward(from: 0);
      await _bugWalkCtrls[index].forward(from: 0);
      await playVoice(ForestAudioAssets.forLetter(_targetLetter.toUpperCase()));
      if (!mounted) return;

      await showTofiReaction(TofiState.correct);
      if (!mounted) return;

      await _advanceRound();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _shakingIndex = index);

      _shakeCtrl.forward(from: 0);
      _flashCtrls[index].forward(from: 0);

      await showTofiReaction(TofiState.wrong);
      if (!mounted) return;

      setState(() => _shakingIndex = null);
    }
  }

  Future<void> _advanceRound() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    _solvedRounds++;

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
                builder: (_) => AlphabetIntroScreen(letter: 'P'),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MushroomHideAndSeekGame(level: widget.level),
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
    _tofiFloatCtrl.dispose();
    _mushroomBounceCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();

    for (final ctrl in _bloomCtrls) {
      ctrl.dispose();
    }

    for (final ctrl in _flashCtrls) {
      ctrl.dispose();
    }

    for (final ctrl in _bugWalkCtrls) {
      ctrl.dispose();
    }

    _shakeCtrl.dispose();

    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
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

  // ── Intro layer ──────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(_bgImage, fit: BoxFit.cover),
        ),

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
              const SizedBox(width: 60),
              Image.asset(
                _mushroomAsset,
                height: screenH * 0.4,
                errorBuilder: (_, __, ___) => const Text('🍄', style: TextStyle(fontSize: 80)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Main game layout ─────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(_bgImage, fit: BoxFit.cover),
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
                      onTap: () async {
                        await playVoice(_targetIsUpper ? _audioBig : _audioSmall);
                        await playVoice(ForestAudioAssets.forLetter(_targetLetter.toUpperCase()));
                      },
                      child: ForestInstructionBanner(
                        text: _instructionText,
                      ),
                    ),
                  ),
                ),
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

  // ── Forest area ──────────────────────────────────────────────────────────
  Widget _buildForestArea(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < _mushrooms.length; i++) _buildMushroom(_mushrooms[i], i, w, h),
        ],
      ),
    );
  }

  Widget _buildMushroom(MushroomSpot mushroom, int index, double w, double h) {
    final mushroomSize = (h * 0.26).clamp(90.0, 150.0);
    final phase = index * 1.4; // stagger idle bounce per mushroom

    return Positioned(
      left: mushroom.pos.dx * w - mushroomSize / 2,
      top: mushroom.pos.dy * h - mushroomSize / 2,
      width: mushroomSize,
      height: mushroomSize,
      child: GestureDetector(
        onTap: () => _onMushroomTapped(mushroom, index),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _mushroomBounceCtrl,
            _bloomCtrls[index],
            _flashCtrls[index],
            _shakeCtrl,
          ]),
          builder: (_, child) {
            final bounceY = mushroom.revealed
                ? 0.0
                : 4 * sin((_mushroomBounceCtrl.value * 2 * pi) + phase);
            final popScale = mushroom.revealed ? (1.0 + 0.22 * _bloomAnims[index].value) : 1.0;
            final shakeAngle = (_shakingIndex == index) ? _shake.value : 0.0;

            return Transform.translate(
              offset: Offset(0, bounceY),
              child: Transform.rotate(
                angle: shakeAngle,
                child: Transform.scale(scale: popScale, child: child),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Soft red pulse behind the mushroom on a wrong tap.
              AnimatedBuilder(
                animation: _flashCtrls[index],
                builder: (_, __) => Opacity(
                  opacity: _flashAnims[index].value * 0.45,
                  child: Container(
                    width: mushroomSize * 1.15,
                    height: mushroomSize * 1.15,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),

              Image.asset(
                mushroom.revealed ? _mushroomAsset : _mushroomAsset,
                width: mushroomSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  '🍄',
                  style: TextStyle(fontSize: mushroomSize * 0.6),
                ),
              ),

              Positioned(
                top: mushroomSize * 0.47,
                child: _outlinedLetter(
                  mushroom.letter,
                  fontSize: mushroomSize * 0.34,
                  fillColor: ForestColorTheme.darkseagreen,
                ),
              ),

              // Hidden animal — pops up out of the cap once revealed.
              if (mushroom.revealed)
                AnimatedBuilder(
                  animation: _bloomCtrls[index],
                  builder: (_, __) {
                    return AnimatedBuilder(
                      animation: Listenable.merge([
                        _bloomCtrls[index],
                        _bugWalkCtrls[index],
                      ]),
                      builder: (_, __) {
                        final pop = _bloomAnims[index].value.clamp(0.0, 1.0);
                        final walk = _bugWalkAnims[index].value;

                        double x = 0;
                        double y = 0;

                        // Stage 1: crawl upward
                        if (walk < .3) {
                          final p = walk / .3;
                          y = -mushroomSize * .45 * p;
                        }

                        // Stage 2: move down to the ground
                        else if (walk < .5) {
                          final p = (walk - .3) / .2;
                          y = -mushroomSize * .45 +
                              (mushroomSize * .52 * p);
                        }

                        // Stage 3: walk right
                        else {
                          final p = (walk - .5) / .5;

                          x = mushroomSize * 1 * p;

                          y = mushroomSize * .07 *
                              sin(p * 10 * pi); // little walking bob
                        }

                        return Transform.translate(
                          offset: Offset(x, y),
                          child: Opacity(
                            opacity: pop,
                            child: Image.asset(
                              'assets/images/objects/forest/ladybug.png',
                              width: mushroomSize * .55,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Letter rendered with a white outline behind a solid fill, so it reads
  /// clearly against the mushroom cap underneath.
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

  // ── Progress dots ────────────────────────────────────────────────────────
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