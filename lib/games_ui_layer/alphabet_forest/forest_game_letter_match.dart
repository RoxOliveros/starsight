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

class FlowerTarget {
  final String letter; // uppercase, e.g. 'J'
  final Offset pos; // fractional position within the garden area
  bool matched;

  FlowerTarget({
    required this.letter,
    required this.pos,
    this.matched = false,
  });
}

class ButterflyOption {
  final String letter; // lowercase, e.g. 'j'
  final Offset pos; // fractional resting position within the garden area
  bool matched;

  ButterflyOption({
    required this.letter,
    required this.pos,
    this.matched = false,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// GAME
// ═════════════════════════════════════════════════════════════════════════

/// "Butterfly Letter Match" — three flowers each show an uppercase letter;
/// three butterflies each carry a lowercase letter. The child drags each
/// butterfly onto the flower it matches. Reinforces uppercase ↔ lowercase
/// recognition for J/K/L. Not a letter-introduction game.
class ButterflyLetterMatchGame extends StatefulWidget {
  final int level;
  const ButterflyLetterMatchGame({super.key, required this.level});

  @override
  State<ButterflyLetterMatchGame> createState() => _ButterflyLetterMatchGameState();
}

class _ButterflyLetterMatchGameState extends State<ButterflyLetterMatchGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<ButterflyLetterMatchGame>,
        ForestAudioMixin<ButterflyLetterMatchGame>,
        TofiReactionMixin<ButterflyLetterMatchGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest_garden.png';
  static const String _butterflyImage = 'assets/images/objects/forest/butterfly.png';
  static const String _flowerAsset = 'assets/images/objects/forest/flower_not_bloom.png';
  static const String _flowerBloomAsset = 'assets/images/objects/forest/flower_bloom.png';
  static const String _dogImage = 'assets/images/characters/dog.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/butterfly_letter_match_intro.wav';
  static const String _audioInstruction = '$_audioBase/butterfly_letter_match_instruction.wav';
  static const String _audioWin = '$_audioBase/butterfly_letter_match_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  static const List<String> _letters = ['J', 'K', 'L'];
  static const int _totalRounds = 3;

  static const List<Offset> _flowerSlots = [
    Offset(0.30, 0.64),
    Offset(0.5, 0.64),
    Offset(0.70, 0.64),
  ];

  // Pool of bottom slots the butterflies are shuffled across each round.
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
  int _matchedCount = 0; // matches landed so far *this* round

  late final List<FlowerTarget> _flowers; // 3 flowers, fixed for the game
  late List<ButterflyOption> _butterflies; // this round's 3 butterflies

  String? _wrongButterfly; // lowercase letter of the butterfly currently shaking

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl; // dog idle float, intro only
  late AnimationController _butterflyFloatCtrl; // shared idle float for resting butterflies
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late List<AnimationController> _bloomCtrls; // one bloom-pop per flower
  late List<Animation<double>> _bloomAnims;
  late AnimationController _shakeCtrl; // wrong-answer butterfly shake
  late Animation<double> _shake;

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
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

  /// Plays the round instruction (round 1 only) then reads out each of the
  /// three target letters in turn.
  Future<void> _announceRound() async {
    if (_currentRound == 0) {
      await playVoice(_audioInstruction);
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

  // ── Drag-and-drop matching ──────────────────────────────────────────────
  Future<void> _onButterflyDropped(ButterflyOption butterfly, FlowerTarget flower) async {
    if (_roundCompleted) return;
    if (butterfly.matched || flower.matched) return;

    final isMatch = butterfly.letter.toUpperCase() == flower.letter.toUpperCase();

    if (isMatch) {
      HapticFeedback.mediumImpact();
      setState(() {
        butterfly.matched = true;
        flower.matched = true;
        _matchedCount++;
      });

      _bloomCtrls[_flowers.indexOf(flower)].forward(from: 0);

      await playVoice(ForestAudioAssets.forLetter(flower.letter));

      await showTofiReaction(TofiState.correct);
      if (!mounted) return;

      if (_matchedCount >= _letters.length) {
        _roundCompleted = true;
        await _advanceRound();
      }
    } else {
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

      await ForestProgressService.instance.markLevelComplete(widget.level);

      if (!mounted) return;

      _showGoodJob();
      return;
    }

    _currentRound++;
    _setupRound();

    _isFinishingRound = false;
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

        const Positioned(top: 25, left: 25, child: ForestXButton()),
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
              Image.asset(
                _butterflyImage,
                height: screenH * 0.4,
                errorBuilder: (_, __, ___) => const Text('🦋', style: TextStyle(fontSize: 80)),
              ),
              Image.asset(
                _flowerBloomAsset,
                height: screenH * 0.4,
                errorBuilder: (_, __, ___) => const Text('🦋', style: TextStyle(fontSize: 80)),
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
              const Positioned(top: 25, left: 25, child: ForestXButton()),
              Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),

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

  // ── Garden ───────────────────────────────────────────────────────────────
  Widget _buildGardenArea(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          for (int i = 0; i < _flowers.length; i++) _buildFlower(_flowers[i], i, w, h),
          for (final butterfly in _butterflies) _buildButterfly(butterfly, w, h),
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
              final scale = (flower.matched ? (1.0 + 0.25 * _bloomAnims[index].value) : 1.0) *
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
    final phase = butterfly.pos.dx * 6.28; // stagger idle float per butterfly

    // Once matched, the butterfly stays pinned on its flower and is no
    // longer draggable.
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
        child: _butterflyVisual(
          butterfly.letter,
          pinnedSize,
          wrong: false,
        ),
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
          errorBuilder: (_, __, ___) => Text('🦋', style: TextStyle(fontSize: size * 0.6)),
        ),
        Positioned(
          bottom: size * 0.14,
          child: _outlinedLetter(
            letter,
            fontSize: size * 0.26,
            fillColor: wrong ? Colors.red.shade400 : ForestColorTheme.darkseagreen,
          ),
        ),
      ],
    );
  }

  /// Letter rendered with a white outline behind a solid fill, so it reads
  /// clearly against any flower/butterfly artwork underneath.
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