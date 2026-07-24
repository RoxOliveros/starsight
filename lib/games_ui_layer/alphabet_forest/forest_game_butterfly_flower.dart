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

class _FlowerSpot {
  final String letter;
  final Offset pos;
  const _FlowerSpot({required this.letter, required this.pos});
}

class ButterflyFlowerGardenGame extends StatefulWidget {
  final int level;
  const ButterflyFlowerGardenGame({super.key, required this.level});

  @override
  State<ButterflyFlowerGardenGame> createState() => _ButterflyFlowerGardenGameState();
}

class _ButterflyFlowerGardenGameState extends State<ButterflyFlowerGardenGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<ButterflyFlowerGardenGame>,
        ForestAudioMixin<ButterflyFlowerGardenGame>,
        TofiReactionMixin<ButterflyFlowerGardenGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest_garden.png';
  static const String _butterflyImage = 'assets/images/objects/forest/butterfly.png';
  static const String _flowerAsset = 'assets/images/objects/forest/flower_not_bloom.png';
  static const String _flowerBloomAsset = 'assets/images/objects/forest/flower_bloom.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/butterfly_garden_intro.wav';
  static const String _audioInstruction = '$_audioBase/butterfly_garden_instruction.wav';
  static const String _audioWin = '$_audioBase/butterfly_garden_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  static const List<String> _letters = ['G', 'H', 'I'];
  static const int _totalRounds = 5;

  static const List<Offset> _slots = [
    Offset(0.35, 0.45),
    Offset(0.5, 0.49),
    Offset(0.65, 0.45),
  ];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<String> _targets; // one target letter per round
  int _currentRound = 0;
  int _solvedRounds = 0;
  late List<_FlowerSpot> _flowers; // this round's flower/letter layout
  String? _bloomedLetter; // letter of the flower currently blooming (correct tap)
  String? _wrongLetter; // letter of the flower currently shaking (wrong tap)
  bool _resolving = false;

  Offset _butterflyPos = const Offset(0.12, 0.12);
  Offset _butterflyTarget = const Offset(0.12, 0.12);

  late AnimationController _flyCtrl;
  late Animation<Offset> _flyAnimation;
  late AnimationController _butterflyFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _bloomCtrl;
  late Animation<double> _bloom;
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;
  late AnimationController _tofiFloatCtrl;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _targets = _buildTargets();
    _initAnimations();
    _setupRound(playInstruction: false);
    finishLoading(_startIntroFlow);
  }

  List<String> _buildTargets() {
    final rng = Random();
    final targets = <String>[];
    String? last;
    for (int i = 0; i < _totalRounds; i++) {
      String next;
      do {
        next = _letters[rng.nextInt(_letters.length)];
      } while (next == last && _letters.length > 1);
      targets.add(next);
      last = next;
    }
    return targets;
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _butterflyFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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

    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bloom = CurvedAnimation(parent: _bloomCtrl, curve: Curves.elasticOut);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    _flyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flyAnimation = AlwaysStoppedAnimation(_butterflyPos);
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await _announceRound();
  }

  Future<void> _announceRound() async {
    if (_currentRound == 0) {
      await playVoice(_audioInstruction);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }
    await playVoice(ForestAudioAssets.forLetter(_targets[_currentRound]));
  }

  void _setupRound({bool playInstruction = true}) {
    final rng = Random();
    final shuffled = [..._letters]..shuffle(rng);
    _flowers = List.generate(
      shuffled.length,
          (i) => _FlowerSpot(letter: shuffled[i], pos: _slots[i % _slots.length]),
    );
    _bloomedLetter = null;
    _wrongLetter = null;
    _resolving = false;

    _bloomCtrl.reset();
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _announceRound();
      });
    }

    _butterflyPos = const Offset(0.20, 0.1);
    _flyAnimation = AlwaysStoppedAnimation(_butterflyPos);
    _flyCtrl.reset();

    setState(() {});
  }

  // ── Flower interaction ───────────────────────────────────────────────────
  Future<void> _onFlowerTapped(_FlowerSpot flower) async {
    if (_resolving) return;
    final target = _targets[_currentRound];

    if (flower.letter == target) {
      _resolving = true;
      HapticFeedback.mediumImpact();
      _butterflyTarget = Offset(
        flower.pos.dx - 0.05,
        flower.pos.dy - 0.30,
      );

      _flyAnimation = Tween<Offset>(
        begin: _butterflyPos,
        end: _butterflyTarget,
      ).animate(
        CurvedAnimation(
          parent: _flyCtrl,
          curve: Curves.easeInOut,
        ),
      );

      await _flyCtrl.forward(from: 0);

      _butterflyPos = _butterflyTarget;

      setState(() => _bloomedLetter = flower.letter);

      _bloomCtrl.forward(from: 0);
      await showTofiReaction(TofiState.correct);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await _advanceRound();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _wrongLetter = flower.letter);
      _shakeCtrl.forward(from: 0);
      await showTofiReaction(TofiState.wrong);
      if (!mounted) return;
      setState(() => _wrongLetter = null);
    }
  }

  Future<void> _advanceRound() async {
    _solvedRounds++;

    if (_currentRound >= _totalRounds - 1) {
      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      await playVoice(_audioWin);

      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);

      if (!mounted) return;

      _showGoodJob();
      return;
    }

    _currentRound++;

    _setupRound();

    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      playVoice(ForestAudioAssets.forLetter(_targets[_currentRound]));
    }

    setState(() {});
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
          characterImage: 'assets/images/characters/dog.png',
          closeButtonColor: ForestColorTheme.seagreen,

          onNext: () {
            Navigator.of(context).pop();

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlphabetIntroScreen(letter: 'J'),
              ),
            );
          },

          onRestart: () {
            Navigator.of(context).pop();

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    ButterflyFlowerGardenGame(level: widget.level),
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
    _butterflyFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _bloomCtrl.dispose();
    _shakeCtrl.dispose();
    _flyCtrl.dispose();
    _tofiFloatCtrl.dispose();
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
            if (_introPlaying)
              _buildIntroLayer()
            else
              _buildGameContent(),

            if (!_introPlaying)
              buildTofi(context),
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
          child: Image.asset(
            'assets/images/backgrounds/bg_game_forest_garden.png',
            fit: BoxFit.cover,
          ),
        ),

        const Positioned(
          top: 25,
          left: 20,
          child: ForestBackButton(),
        ),

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
                    Tween<double>(
                      begin: -6,
                      end: 6,
                    ).evaluate(
                      CurvedAnimation(
                        parent: _tofiFloatCtrl,
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ),
                  child: child,
                ),
                child: Image.asset(
                  'assets/images/characters/dog.png',
                  height: screenH * .72,
                ),
              ),

              const SizedBox(width: 120),

              Image.asset(
                _butterflyImage,
                height: screenH * .6,
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
        // Never changes
        Positioned.fill(
          child: Image.asset(
            _bgImage,
            fit: BoxFit.cover,
          ),
        ),

        // Everything that changes
        _buildGameUI(),
      ],
    );
  }

  Widget _buildGameUI() {
    final target = _targets[_currentRound];

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return ScaleTransition(
          scale: _sceneEnter,
          child: Stack(
            children: [
              const Positioned(
                top: 25,
                left: 20,
                child: ForestBackButton(),
              ),

              Positioned(
                top: 25,
                right: 20,
                child: ForestLevelBadge(level: widget.level),
              ),

              Positioned(
                top: 25,
                left: 0,
                right: 0,
                child: Center(
                  child: ScaleTransition(
                    scale: _instructionBounce,
                    child: GestureDetector(
                      onTap: () =>
                          playVoice(ForestAudioAssets.forLetter(target)),
                      child: ForestInstructionBanner(
                        text: 'Find the letter $target flower!',
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
                      child: _buildGardenArea(w, h),
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

  // ── Garden ───────────────────────────────────────────────────────────────
  Widget _buildGardenArea(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [

          ..._flowers.map((f) => _buildFlower(f, w, h)),

          AnimatedBuilder(
            animation: _flyCtrl,
            builder: (_, __) {
              final pos = _flyAnimation.value;

              return Positioned(
                left: pos.dx * w - 35,
                top: pos.dy * h - 35,
                child: Image.asset(
                  _butterflyImage,
                  width: 110,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFlower(_FlowerSpot flower, double w, double h) {
    final flowerSize = (h * 0.32);
    final blooming = _bloomedLetter == flower.letter;
    final wrong = _wrongLetter == flower.letter;

    return Positioned(
      left: flower.pos.dx * w - flowerSize / 2,
      top: flower.pos.dy * h - flowerSize / 2 - 30,
      width: flowerSize,
      height: flowerSize,
      child: GestureDetector(
        onTap: () => _onFlowerTapped(flower),
        child: AnimatedBuilder(
          animation: Listenable.merge([_bloomCtrl, _shakeCtrl]),
          builder: (_, child) {
            final scale = blooming ? (1.0 + 0.3 * _bloom.value) : 1.0;
            final angle = wrong ? _shake.value : 0.0;
            return Transform.rotate(
              angle: angle,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                blooming ? _flowerBloomAsset : _flowerAsset,
                width: flowerSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  blooming ? '🌸' : '🌼',
                  style: TextStyle(fontSize: flowerSize * 0.6),
                ),
              ),

              Positioned(
                bottom: flowerSize * 0.12, // move lower
                child: Stack(
                  children: [
                    // White outline
                    Text(
                      flower.letter,
                      style: TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontWeight: FontWeight.w900,
                        fontSize: flowerSize * 0.24,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 5
                          ..color = Colors.white,
                      ),
                    ),

                    // Actual letter
                    Text(
                      flower.letter,
                      style: TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontWeight: FontWeight.w900,
                        fontSize: flowerSize * 0.24,
                        color: wrong
                            ? Colors.red.shade400
                            : ForestColorTheme.darkseagreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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