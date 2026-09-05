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
import 'forest_game_catterpillar_letter_match.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';


/// Which celebratory motion an animal uses once it reaches its finish line.
enum _AnimalBounceStyle { hop, wag }

// ═══════════════════════════════════════════════════════════════════════════
// PATH PAINTER
// ═══════════════════════════════════════════════════════════════════════════

/// Draws a soft dashed line through the race path's waypoints, purely
/// decorative -- it visually anchors where the animals are travelling.
class _DashedPathPainter extends CustomPainter {
  final List<Offset> points; // fractional (0..1), scaled against [size]
  final Color color;

  const _DashedPathPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final scaled = points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    final path = Path()..moveTo(scaled.first.dx, scaled.first.dy);
    for (final p in scaled.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    final dashPaint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dashLength = 12.0;
    const gapLength = 10.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), dashPaint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPathPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// GAME
// ═══════════════════════════════════════════════════════════════════════════

class YakZebraRaceGame extends StatefulWidget {
  final int level;
  const YakZebraRaceGame({super.key, required this.level});

  @override
  State<YakZebraRaceGame> createState() => _YakZebraRaceGameState();
}

class _YakZebraRaceGameState extends State<YakZebraRaceGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<YakZebraRaceGame>,
        ForestAudioMixin<YakZebraRaceGame>,
        TofiReactionMixin<YakZebraRaceGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ═════════════════════════════════════════════════════════════════════
  // ASSET PATHS
  // ═════════════════════════════════════════════════════════════════════

  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest_grassland.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _yakAsset = 'assets/images/objects/forest/yak.png';
  static const String _zebraAsset = 'assets/images/objects/forest/zebra.png';
  static const String _stoneAsset = 'assets/images/objects/forest/stone.png';
  static const String _leafAsset = 'assets/images/objects/forest/leaf.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/yak_zebra_race_intro.wav';
  static const String _audioTapY = '$_audioBase/sound_effects/sound_y.wav';
  static const String _audioTapZ = '$_audioBase/sound_effects/sound_z.wav';
  static const String _audioCorrect = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioYIsForYak = '$_audioBase/y_is_for_yak.wav';
  static const String _audioZIsForZebra = '$_audioBase/z_is_for_zebra.wav';
  static const String _audioWin = '$_audioBase/yak_zebra_race_win.wav';
  // Wrong-answer audio ("Try again") is already handled by
  // TofiReactionMixin.showTofiReaction(TofiState.wrong) internally.

  // ═════════════════════════════════════════════════════════════════════
  // GAME STRUCTURE
  // ═════════════════════════════════════════════════════════════════════

  static const int _totalRounds = 5;
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static final List<Offset> _pathPoints = [
    const Offset(0.08, 0.55),
    const Offset(0.26, 0.64),
    const Offset(0.46, 0.50),
    const Offset(0.66, 0.62),
    const Offset(0.84, 0.52),
    const Offset(0.94, 0.55),
  ];

  static const List<Offset> _stoneSlots = [
    Offset(0.22, 0.30),
    Offset(0.42, 0.70),
    Offset(0.62, 0.30),
    Offset(0.82, 0.70),
  ];

  // ═════════════════════════════════════════════════════════════════════
  // STATE
  // ═════════════════════════════════════════════════════════════════════

  bool _introPlaying = true;
  int _currentRoundIndex = 0; // 0..5
  int _solvedRounds = 0;
  double _yakProgress = 0;
  double _zebraProgress = 0;

  late List<String> _choices; // 4 letters this round, target guaranteed present
  int? _correctSlotIndex; // briefly set right after a correct tap
  int? _wrongSlotIndex; // briefly set right after a wrong tap
  bool _resolving = false;
  bool _showBothCelebrating = false; // final "reveal both animals" moment
  late bool _yakWillWin;

  late final String _finalRoundLetter = Random().nextBool() ? 'Y' : 'Z';

  String get _targetLetter {
    switch (_currentRoundIndex) {
      case 0:
        return 'Y';
      case 1:
        return 'Z';
      case 2:
        return 'Y';
      case 3:
        return 'Z';
      case 4:
        return _finalRoundLetter;
      default:
        return 'Y';
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // ANIMATION CONTROLLERS
  // ═════════════════════════════════════════════════════════════════════

  late AnimationController _tofiFloatCtrl; // intro-only idle float
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _bobCtrl; // gentle idle floating for stones
  late AnimationController _pulseCtrl; // correct-stone pulse + glow pop
  late AnimationController _shakeCtrl; // wrong-stone wiggle
  late Animation<double> _shake;
  late AnimationController _celebrateCtrl; // Yak bounce / Zebra wag, repeating
  late AnimationController _ambientLeavesCtrl; // always-on slow background drift

  // ═════════════════════════════════════════════════════════════════════
  // INIT
  // ═════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRound(playInstruction: false);
    finishLoading(_startIntroFlow);
    _yakWillWin = Random().nextBool();
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

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.16), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.16, end: 0.16), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.16, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _ambientLeavesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
    )..repeat();
  }

  // ═════════════════════════════════════════════════════════════════════
  // FLOW
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await playVoice(_targetLetter == 'Y' ? _audioTapY : _audioTapZ);
  }

  /// Builds this round's 4 letter choices: the target letter is always
  /// included, the rest are random distinct A-Z letters, then shuffled.
  List<String> _generateChoices(String target) {
    final rng = Random();
    final letters = <String>{target};
    while (letters.length < 4) {
      letters.add(_alphabet[rng.nextInt(_alphabet.length)]);
    }
    return letters.toList()..shuffle(rng);
  }

  void _setupRound({bool playInstruction = true}) {
    _choices = _generateChoices(_targetLetter);
    _correctSlotIndex = null;
    _wrongSlotIndex = null;
    _resolving = false;

    _pulseCtrl.reset();
    _shakeCtrl.reset();

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) playVoice(_targetLetter == 'Y' ? _audioTapY : _audioTapZ);
      });
    }

    setState(() {});
  }

  // ═════════════════════════════════════════════════════════════════════
  // LETTER INTERACTION
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _onLetterTapped(String letter, int slotIndex) async {
    if (_resolving) return;

    if (letter == _targetLetter) {
      _resolving = true;
      HapticFeedback.mediumImpact();
      setState(() => _correctSlotIndex = slotIndex);
      _pulseCtrl.forward(from: 0);

      await playSfx(_audioCorrect);
      showTofiReaction(TofiState.correct); // fire-and-forget; plays its own audio

      setState(() {
        const winnerStep = 1 / 5; // 0.20
        const loserStep = 0.16;

        if (_yakWillWin) {
          _yakProgress += winnerStep;
          _zebraProgress += loserStep;
        } else {
          _yakProgress += loserStep;
          _zebraProgress += winnerStep;
        }

        _yakProgress = _yakProgress.clamp(0.0, 1.0);
        _zebraProgress = _zebraProgress.clamp(0.0, 1.0);
      });

      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;

      await _advanceRound();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _wrongSlotIndex = slotIndex);
      _shakeCtrl.forward(from: 0);
      showTofiReaction(TofiState.wrong); // fire-and-forget; plays "try again" audio

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _wrongSlotIndex = null);
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // ROUND / PHASE PROGRESSION
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _advanceRound() async {
    _solvedRounds++;

    // Zebra's finish line -- the very end of the track, end of the game.
    final justFinishedGame = _currentRoundIndex == _totalRounds - 1;

    if (justFinishedGame) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      if (_yakWillWin) {
        await playVoice(_audioYIsForYak);
      } else {
        await playVoice(_audioZIsForZebra);
      }
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _showBothCelebrating = true);

      await playVoice(_audioWin);
      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;

      _showGoodJob();
      return;
    }

    _currentRoundIndex++;
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
              MaterialPageRoute(builder: (_) => CaterpillarLetterMatchGame(level: 19)),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => YakZebraRaceGame(level: widget.level)),
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
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _bobCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _celebrateCtrl.dispose();
    _ambientLeavesCtrl.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════
  // BUILD -- ROOT
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

  // ═════════════════════════════════════════════════════════════════════
  // INTRO LAYER
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _bgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: ForestColorTheme.lightgrayishgreen),
          ),
        ),
        const Positioned(top: 25, left: 20, child: ForestBackButton()),
        Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),
        Center(
          child: AnimatedBuilder(
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
              errorBuilder: (_, __, ___) => const Text('🐶', style: TextStyle(fontSize: 90)),
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // MAIN GAME LAYOUT
  // ═════════════════════════════════════════════════════════════════════

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
                errorBuilder: (_, __, ___) => Container(color: ForestColorTheme.lightgrayishgreen),
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
                  onTap: () => playVoice(_targetLetter == 'Y' ? _audioTapY : _audioTapZ),
                  child: ForestInstructionBanner(text: 'Tap the letter $_targetLetter!'),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 90),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: LayoutBuilder(
                    builder: (context, inner) => _buildRaceScene(inner.maxWidth, inner.maxHeight),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 60), // adjust this value
                    child: LayoutBuilder(
                      builder: (context, inner) =>
                          _buildStonesArea(inner.maxWidth, inner.maxHeight),
                    ),
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
  }

  // ═════════════════════════════════════════════════════════════════════
  // RACE SCENE (path + animals)
  // ═════════════════════════════════════════════════════════════════════

  Offset _positionAlongPath(double t) {
    final points = _pathPoints;
    final clampedT = t.clamp(0.0, 1.0);
    final scaled = clampedT * (points.length - 1);
    final i = scaled.floor().clamp(0, points.length - 2);
    final localT = scaled - i;
    final a = points[i];
    final b = points[i + 1];
    return Offset(a.dx + (b.dx - a.dx) * localT, a.dy + (b.dy - a.dy) * localT);
  }

  Widget _buildRaceScene(double w, double h) {
    // Yak owns t in [0, 0.5]; once the Z phase begins he parks at the
    // midpoint permanently. Zebra owns t in [0.5, 1.0] and only appears
    // once the Z phase begins, continuing from exactly where Yak stopped.
    final yakT = _yakProgress;
    final zebraT = _zebraProgress;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedPathPainter(
                points: _pathPoints,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),

          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: _yakProgress,
              end: yakT,
            ),
            duration: const Duration(milliseconds: 700),
            builder: (context, t, _) => _buildAnimal(
              asset: _yakAsset,
              fallbackEmoji: '🐂',
              t: t,
              w: w,
              h: h,
              bouncing: _yakWillWin && _showBothCelebrating,
              bounceStyle: _AnimalBounceStyle.hop,
            ),
          ),

          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: _zebraProgress,
              end: zebraT,
            ),
            duration: const Duration(milliseconds: 700),
            builder: (context, t, _) => _buildAnimal(
              asset: _zebraAsset,
              fallbackEmoji: '🦓',
              t: t,
              w: w,
              h: h,
              bouncing: !_yakWillWin && _showBothCelebrating,
              bounceStyle: _AnimalBounceStyle.wag,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimal({
    required String asset,
    required String fallbackEmoji,
    required double t,
    required double w,
    required double h,
    required bool bouncing,
    required _AnimalBounceStyle bounceStyle,
  }) {
    final pos = _positionAlongPath(t);
    final size = (h * 0.5).clamp(80.0, 150.0);

    Widget image = Image.asset(
      asset,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.7)),
    );

    if (bouncing) {
      image = AnimatedBuilder(
        animation: _celebrateCtrl,
        builder: (_, child) {
          final v = _celebrateCtrl.value;
          if (bounceStyle == _AnimalBounceStyle.hop) {
            final hop = -10 * sin(v * 2 * pi).abs();
            return Transform.translate(offset: Offset(0, hop), child: child);
          } else {
            final wag = 0.16 * sin(v * 2 * pi);
            return Transform.rotate(angle: wag, child: child);
          }
        },
        child: image,
      );
    }

    return Positioned(
      left: pos.dx * w - size / 2,
      top: pos.dy * h - size,
      child: image,
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // LETTER STONES
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildStonesArea(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: List.generate(_choices.length, (i) => _buildStone(i, w, h)),
      ),
    );
  }

  Widget _buildStone(int index, double w, double h) {
    final letter = _choices[index];
    final pos = _stoneSlots[index % _stoneSlots.length];
    final size = (h * 0.42).clamp(60.0, 110.0);
    final correct = _correctSlotIndex == index;
    final wrong = _wrongSlotIndex == index;
    final phase = index * 1.4;

    return Positioned(
      left: pos.dx * w - size / 2,
      top: pos.dy * h - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _onLetterTapped(letter, index),
        child: AnimatedBuilder(
          animation: Listenable.merge([_bobCtrl, _pulseCtrl, _shakeCtrl]),
          builder: (_, child) {
            final bobY = _resolving ? 0.0 : 4 * sin((_bobCtrl.value * 2 * pi) + phase);
            final pulseScale = correct ? 1.0 + 0.25 * Curves.elasticOut.transform(_pulseCtrl.value) : 1.0;
            final shakeAngle = wrong ? _shake.value : 0.0;
            return Transform.translate(
              offset: Offset(0, bobY),
              child: Transform.rotate(
                angle: shakeAngle,
                child: Transform.scale(scale: pulseScale, child: child),
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: correct
                    ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ForestColorTheme.mediumseagreen.withValues(alpha: 0.7),
                      blurRadius: 22,
                      spreadRadius: 6,
                    ),
                  ],
                )
                    : null,
                child: Image.asset(
                  _stoneAsset,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade400,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(2, 0), // move right by 12 px
                child: _outlinedLetter(
                  letter,
                  fontSize: size * 0.42,
                  fillColor: wrong
                      ? Colors.red.shade400
                      : ForestColorTheme.darkseagreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // AMBIENT DECORATION
  // ═════════════════════════════════════════════════════════════════════

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
                    errorBuilder: (_, __, ___) => const Text('🍃', style: TextStyle(fontSize: 14)),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  /// Letter with a white outline behind a solid fill, for legibility
  /// against the forest background and stone artwork.
  Widget _outlinedLetter(String letter, {required double fontSize, required Color fillColor}) {
    return Stack(
      alignment: Alignment.center,
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
  // PROGRESS DOTS
  // ═════════════════════════════════════════════════════════════════════

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