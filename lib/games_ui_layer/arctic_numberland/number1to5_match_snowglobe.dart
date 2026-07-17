import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';

class Number1to5MatchSnowglobesScreen extends StatefulWidget {
  final int level;

  const Number1to5MatchSnowglobesScreen({super.key, required this.level});

  @override
  State<Number1to5MatchSnowglobesScreen> createState() =>
      _Number1to5MatchSnowglobesScreenState();
}

class _Number1to5MatchSnowglobesScreenState
    extends State<Number1to5MatchSnowglobesScreen>
    with TickerProviderStateMixin, DomaReactionMixin {
  @override
  AudioPlayer get domaPlayer => _player;

  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const int _globeCount = 3;

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _snowglobeAsset = 'assets/images/objects/arctic/empty_snowglobe.png';

  // Objects that can appear inside snowglobes
  static const List<String> _insideObjects = [
    'assets/images/objects/arctic/candy_cane.png',
    'assets/images/objects/arctic/winter_hat.png',
    'assets/images/objects/arctic/snowball.png',
    'assets/images/objects/arctic/snowy_tree.png',
    'assets/images/objects/arctic/ice_skates.png',
  ];

  static const String _audioIntro =
      'assets/audio/arctic_numberland/level20/intro.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;

  late int _targetNumber; // the number shown to the player
  late List<int> _globeCounts; // how many objects in each globe
  late List<String> _globeObjects; // which object type each globe uses
  int? _tappedIndex;
  bool _showWinDialog = false;
  late List<int> _roundPool;

  // Shake state for wrong answer
  int? _shakingIndex;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;

  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;

  late AnimationController _globesEnterCtrl;
  late Animation<double> _globesEnter;

  late AnimationController _targetEnterCtrl;
  late Animation<double> _targetEnter;

  late AnimationController _correctPulseCtrl;
  late Animation<double> _correctPulse;

  // Per-globe shake controllers
  late List<AnimationController> _shakeCtrl;
  late List<Animation<double>> _shakeAnim;

  // Intro dance
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _roundPool = List.generate(5, (i) => i + 1)..shuffle();
    _initAnimations();
    _startIntroFlow();
  }

  void _initAnimations() {
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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

    _globesEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _globesEnter = CurvedAnimation(
      parent: _globesEnterCtrl,
      curve: Curves.elasticOut,
    );

    _targetEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _targetEnter = CurvedAnimation(
      parent: _targetEnterCtrl,
      curve: Curves.easeOutBack,
    );

    _correctPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _correctPulse =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _correctPulseCtrl, curve: Curves.easeOut),
        );

    _shakeCtrl = List.generate(
      _globeCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _shakeAnim = _shakeCtrl.map((c) {
      return TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 20),
        TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 10.0, end: -5.0), weight: 20),
        TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 20),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _numberDance = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );
  }

  // ── Flow ───────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _playAudio(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _setupRound();
  }

  void _setupRound() {
    final rng = Random();

    if (_roundPool.isEmpty) {
      _roundPool = List.generate(5, (i) => i + 1)..shuffle();
    }

    _targetNumber = _roundPool.removeLast();

    // Build globe counts: one must equal _targetNumber, others must differ
    final allNums = List.generate(5, (i) => i + 1);
    final distractors = [...allNums]..remove(_targetNumber);
    distractors.shuffle(rng);
    final otherCounts = distractors.take(_globeCount - 1).toList();

    _globeCounts = [...otherCounts, _targetNumber]..shuffle(rng);

    // Each globe gets a random object type (can repeat across globes)
    _globeObjects = List.generate(
      _globeCount,
      (_) => _insideObjects[rng.nextInt(_insideObjects.length)],
    );

    _tappedIndex = null;
    _shakingIndex = null;

    for (final c in _shakeCtrl) {
      c.reset();
    }

    _globesEnterCtrl.forward(from: 0);
    _targetEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
  }

  // ── Globe Tap ──────────────────────────────────────────────────────────────
  Future<void> _onGlobeTap(int index) async {
    if (_tappedIndex != null) return;

    final isCorrect = _globeCounts[index] == _targetNumber;

    if (isCorrect) {
      setState(() => _tappedIndex = index);
      _correctPulseCtrl.forward(from: 0);
      await _playAudio('assets/audio/arctic_numberland/$_targetNumber.wav');
      showDomaReaction(DomaState.correct);

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      if (_currentRound + 1 >= _totalRounds) {
        await ArcticProgressService.instance.markLevelComplete(widget.level);
        setState(() => _showWinDialog = true);
      } else {
        setState(() => _currentRound++);
        _setupRound();
      }
    } else {
      // Shake the wrong globe
      setState(() => _shakingIndex = index);
      await _playAudio('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);

      _shakeCtrl[index].forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _shakingIndex = null);
    }
  }

  // ── Audio ──────────────────────────────────────────────────────────────────
  Future<void> _playAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _globesEnterCtrl.dispose();
    _targetEnterCtrl.dispose();
    _correctPulseCtrl.dispose();
    _numberDanceCtrl.dispose();
    for (final c in _shakeCtrl) {
      c.dispose();
    }
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
          _introPlaying ? _buildIntroLayer() : _buildGameContent(),
          if (!_introPlaying) buildDoma(context),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Intro ──────────────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    return Stack(
      children: [
        Positioned(top: 25, left: 20, child: ArcticBackButton()),
        Positioned(top: 25, right: 20, child: ArcticLevelBadge(level: widget.level)),
        Positioned.fill(
          top: 48,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: Image.asset(
                    _characterImage,
                    height: MediaQuery.of(context).size.height * 0.62,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🐧', style: TextStyle(fontSize: 60)),
                  ),
                ),
              ),
              // Snowglobes 0–5 dancing
              Expanded(
                flex: 7,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _numberDanceCtrl,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(5, (i) {
                          final num = i + 1;
                          final angle =
                              _numberDance.value * ((i % 2 == 0) ? 1 : -1);
                          final globeH =
                              MediaQuery.of(context).size.height * 0.15 +
                                  (i * 3.0);
                          return Transform.rotate(
                            angle: angle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Image.asset(
                                        _snowglobeAsset,
                                        height: globeH,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Text(
                                              '🔮',
                                              style: TextStyle(fontSize: 32),
                                            ),
                                      ),
                                      // Mini object count inside
                                      Positioned(
                                        bottom: globeH * 0.22,
                                        child: Text(
                                          '$num',
                                          style: TextStyle(
                                            fontFamily:
                                                ArcticAppTextStyles.fredoka,
                                            fontSize: globeH * 0.24,
                                            fontWeight: FontWeight.bold,
                                            color: ArcticColorTheme.cadetblue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ArcticColorTheme.cadetblue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$num',
                                      style: TextStyle(
                                        fontFamily: ArcticAppTextStyles.fredoka,
                                        fontSize: globeH * 0.22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Game ───────────────────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        return Column(
          children: [
            // ── HEADER ──────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ArcticBackButton(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ArcticLevelBadge(level: widget.level),
                  ),
                  Center(child: _buildInstructionBanner(h)),
                ],
              ),
            ),

            // ── SCENE ───────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.height * 0.40,
                  ),
                  Expanded(
                    flex: 7,
                    child: Row(                                // ADD — target panel + globes grouped together on the right
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 1, child: _buildTargetPanel(h)),
                        Expanded(flex: 4, child: _buildGlobesArea(h)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── PROGRESS ────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _buildRoundIndicator(),
            ),
          ],
        );
      },
    );
  }

  // ── Instruction Banner ─────────────────────────────────────────────────────
  Widget _buildInstructionBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: ArcticColorTheme.pictonblue.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: ArcticColorTheme.pictonblue.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Find the snowglobe with the matching number/s',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Target Panel ───────────────────────────────────────────────────────────
  Widget _buildTargetPanel(double h) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Target number card
        ScaleTransition(
          scale: _targetEnter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF97D9FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: ArcticColorTheme.cadetblue.withValues(alpha: 0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/fonts/game_numbers/$_targetNumber.png',
                  height: (h * 0.25),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    '$_targetNumber',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: (h * 0.13).clamp(36.0, 60.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Globes Area ────────────────────────────────────────────────────────────
  Widget _buildGlobesArea(double h) {
    return ScaleTransition(
      scale: _globesEnter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_globeCount, (i) => _buildSingleGlobe(i, h)),
      ),
    );
  }

  Widget _buildSingleGlobe(int index, double h) {
    final isTapped = _tappedIndex == index;
    final isShaking = _shakingIndex == index;
    final globeSize = (h * 0.47);
    final objectSize = (globeSize * 0.16).clamp(16.0, 30.0);

    return AnimatedBuilder(
      animation: _shakeCtrl[index],
      builder: (_, child) => Transform.translate(
        offset: Offset(isShaking ? _shakeAnim[index].value : 0, 0),
        child: child,
      ),
      child: GestureDetector(
        onTap: () => _onGlobeTap(index),
        child: ScaleTransition(
          scale: isTapped ? _correctPulse : const AlwaysStoppedAnimation(1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Snowglobe base image
                Image.asset(
                  _snowglobeAsset,
                  width: globeSize,
                  height: globeSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(
                    width: globeSize,
                    height: globeSize,
                  ),
                ),

                // Objects arranged inside the globe dome area
                Positioned(
                  top: globeSize * 0.18,
                  left: globeSize * 0.15,
                  right: globeSize * 0.15,
                  bottom: globeSize * 0.30,
                  child: _buildObjectsInsideGlobe(
                    _globeCounts[index],
                    _globeObjects[index],
                    objectSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Objects arranged in a neat grid/row inside the globe
  Widget _buildObjectsInsideGlobe(int count, String objectAsset, double size) {
    Widget buildItem() {
      return Padding(
        padding: const EdgeInsets.all(1.5),
        child: Image.asset(
          objectAsset,
          width: size + 8,
          height: size + 8,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Text('❄️', style: TextStyle(fontSize: size * 0.7)),
        ),
      );
    }

    // Determine how many go on top row vs bottom row
    int topCount;
    int bottomCount;
    switch (count) {
      case 4:
        topCount = 2;
        bottomCount = 2;
        break;
      case 5:
        topCount = 3;
        bottomCount = 2;
        break;
      default:
      // 1, 2, 3 (and any other count) — single centered row
        return Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 3,
          runSpacing: 3,
          children: List.generate(count, (_) => buildItem()),
        );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(topCount, (_) => buildItem()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(bottomCount, (_) => buildItem()),
        ),
      ],
    );
  }

  // ── Progress ───────────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _currentRound;
        final current = !_showWinDialog && i == _currentRound;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : current
                ? ArcticColorTheme.slateblue
                : ArcticColorTheme.slateblue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }

  // ── Win Overlay ────────────────────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        //TODO: @Tin navigation after number intro is done
        // onNext: () {
        //   Navigator.pushReplacement(
        //     context,
        //     MaterialPageRoute(
        //       builder: (_) => (level: widget.level + 1),
        //     ),
        //   );
        // },
      },
      onRestart: () {
        Navigator.pop(context, Number1to5MatchSnowglobesScreen(level: widget.level));
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
