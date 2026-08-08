import 'dart:math';
import 'package:StarSight/games_ui_layer/arctic_numberland/number_introduction_screen.dart';
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
import 'forest_game_apple_tree.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════

class _LetterPair {
  final String upper;
  final String lower;
  bool matched;
  _LetterPair({required this.upper, required this.lower, this.matched = false});
}

// ═══════════════════════════════════════════════════════════════════════════
// VINE PAINTER
// ═══════════════════════════════════════════════════════════════════════════

/// A single soft green vine connecting a matched pair's two segments.
class _VinePainter extends CustomPainter {
  final Offset start; // pixel coords
  final Offset end;

  const _VinePainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ForestColorTheme.mediumseagreen
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(start.dx, start.dy);
    final dy = end.dy - start.dy;
    path.cubicTo(
      start.dx,
      start.dy + dy * 0.4,
      end.dx,
      start.dy + dy * 0.6,
      end.dx,
      end.dy,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VinePainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}

// ═══════════════════════════════════════════════════════════════════════════
// GAME
// ═══════════════════════════════════════════════════════════════════════════

/// "Caterpillar Letter Match" -- an uppercase caterpillar across the top,
/// a lowercase caterpillar across the bottom; drag each uppercase segment
/// down to its matching lowercase segment.
class CaterpillarLetterMatchGame extends StatefulWidget {
  final int level;
  const CaterpillarLetterMatchGame({super.key, required this.level});

  @override
  State<CaterpillarLetterMatchGame> createState() => _CaterpillarLetterMatchGameState();
}

class _CaterpillarLetterMatchGameState extends State<CaterpillarLetterMatchGame>
    with TickerProviderStateMixin, GameLoadingMixin<CaterpillarLetterMatchGame>, ForestAudioMixin<CaterpillarLetterMatchGame>, TofiReactionMixin<CaterpillarLetterMatchGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _leafAsset = 'assets/images/objects/forest/leaf.png';
  static const String _caterpillarHeadAsset = 'assets/images/objects/forest/catterpillar_head.png';
  static const String _caterpillarBodyAsset = 'assets/images/objects/forest/catterpillar_body.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/caterpillar_intro.wav';
  static const String _audioInstruction = '$_audioBase/caterpillar_instruction.wav';
  static const String _audioCorrect = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioWin = '$_audioBase/caterpillar_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const int _pairsPerRound = 4;

  // Fixed x-slots shared by both caterpillars, so a segment's on-screen
  // column is purely a function of its slot index -- needed for the vine
  // math and for keeping drag targets large and predictable.
  static const List<double> _slotX = [
    0.44,
    0.51,
    0.58,
    0.65,
  ];
  static const double _topY = 0.28;
  static const double _bottomY = 0.76;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<_LetterPair> _pairs; // fixed order = top caterpillar's order
  late List<int> _lowerOrder; // shuffled: bottom slot j shows _pairs[_lowerOrder[j]]
  int _currentRoundIndex = 0;
  int _solvedRounds = 0;

  int? _wrongSlotIndex; // bottom slot currently shaking from a bad drop
  int? _lastRejectedSlot; // tracks which target was hovered-and-rejected this drag
  bool _celebratingRound = false; // brief "wiggle happily" window after a round
  int? _selectedUpper;
  int? _selectedLower;

  late AnimationController _tofiFloatCtrl; // intro-only idle float
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _breatheCtrl; // idle body breathing, both caterpillars
  late AnimationController _blinkCtrl; // periodic eye blink
  late AnimationController _shakeCtrl; // wrong-drop target wiggle
  late Animation<double> _shake;
  late AnimationController _ambientLeavesCtrl; // always-on slow background drift

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRound(playInstruction: false);
    finishLoading(_startIntroFlow);
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

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.14), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.14, end: 0.14), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.14, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _ambientLeavesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
    )..repeat();
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
    if (mounted) await playVoice(_audioInstruction);
  }

  void _setupRound({bool playInstruction = true}) {
    final rng = Random();
    final letters = (List.generate(26, (i) => String.fromCharCode(65 + i))..shuffle(rng))
        .take(_pairsPerRound)
        .toList();

    _pairs = letters.map((u) => _LetterPair(upper: u, lower: u.toLowerCase())).toList();
    _lowerOrder = List.generate(_pairsPerRound, (i) => i)..shuffle(rng);

    _wrongSlotIndex = null;
    _lastRejectedSlot = null;
    _celebratingRound = false;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) playVoice(_audioInstruction);
      });
    }

    setState(() {});
  }

  // ── Match handling ───────────────────────────────────────────────────────
  Future<void> _onMatched(int pairIndex, int bottomSlot) async {
    final pair = _pairs[pairIndex];
    if (pair.matched) return;

    HapticFeedback.mediumImpact();
    setState(() => pair.matched = true);

    await playSfx(_audioCorrect);
    showTofiReaction(TofiState.correct); // fire-and-forget; plays its own audio

    if (_pairs.every((p) => p.matched)) {
      await _advanceRound();
    }
  }

  void _onWrongDrop() {
    HapticFeedback.heavyImpact();
    if (_lastRejectedSlot != null) {
      setState(() => _wrongSlotIndex = _lastRejectedSlot);
      _shakeCtrl.forward(from: 0);
    }
    showTofiReaction(TofiState.wrong); // fire-and-forget; plays "try again" audio

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _wrongSlotIndex = null);
    });
  }

  // ── Round / game progression ─────────────────────────────────────────────
  Future<void> _advanceRound() async {
    _solvedRounds++;

    setState(() => _celebratingRound = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _celebratingRound = false);

    if (_currentRoundIndex >= _totalRounds - 1) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      await playVoice(_audioWin);
      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;

      _showGoodJob();
      return;
    }

    _currentRoundIndex++;
    _setupRound(
      playInstruction: _currentRoundIndex == 0,
    );
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
          closeButtonColor: ForestColorTheme.seagreen,
          onNext: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => AlphabetAppleTreeGame(level: 20)),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => CaterpillarLetterMatchGame(level: widget.level)),
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
    _breatheCtrl.dispose();
    _blinkCtrl.dispose();
    _shakeCtrl.dispose();
    _ambientLeavesCtrl.dispose();
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

  // ── Main game layout ─────────────────────────────────────────────────────
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
                  onTap: () => playVoice(_audioInstruction),
                  child: const ForestInstructionBanner(text: 'Match each BIG letter to its small letter!'),
                ),
              ),
            ),
          ),

          Positioned(
            top: 90,
            left: 0,
            right: 0,
            bottom: 40,
            child: LayoutBuilder(
              builder: (context, inner) {
                final iw = inner.maxWidth;
                final ih = inner.maxHeight;
                return Stack(
                  children: [
                    for (int i = 0; i < _pairs.length; i++)
                      if (_pairs[i].matched) _buildConnectionLine(i, iw, ih),
                    _buildUpperCaterpillar(iw, ih),
                    _buildLowerCaterpillar(iw, ih),
                  ],
                );
              },
            ),
          ),

          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(child: _buildProgressDots()),
          ),
        ],
      ),
    );
  }

  // ── Caterpillars ─────────────────────────────────────────────────────────
  Widget _buildUpperCaterpillar(double w, double h) {
    final headSize = (h * 0.4);

    return Stack(
      children: [
        Positioned(
          left: (_slotX[0] - 0.075) * w - headSize / 2,
          top: _topY * h - headSize / 2 - 16,
          child: _buildCaterpillarHead(headSize),
        ),
        for (int i = 0; i < _pairs.length; i++) _buildUpperSegmentSlot(i, w, h),
      ],
    );
  }

  Widget _buildLowerCaterpillar(double w, double h) {
    final headSize = (h * 0.4);

    return Stack(
      children: [
        Positioned(
          left: (_slotX[0] - 0.075) * w - headSize / 2,
          top: _bottomY * h - headSize / 2 - 16,
          child: _buildCaterpillarHead(headSize),
        ),
        for (int i = 0; i < _pairs.length; i++) _buildLowerSegmentSlot(i, w, h),
      ],
    );
  }

  Widget _buildUpperSegmentSlot(int pairIndex, double w, double h) {
    final pair = _pairs[pairIndex];
    final size = (h * 0.3);
    final segment = _buildSegment(
      letter: pair.upper,
      matched: pair.matched,
      size: size,
      color: ForestColorTheme.seagreen,
      selected: _selectedUpper == pairIndex,
    );

    return Positioned(
      left: _slotX[pairIndex] * w - size / 2,
      top: _topY * h - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: pair.matched
            ? null
            : () async {
          // Lower was selected first
          if (_selectedLower != null) {
            if (_selectedLower == pairIndex) {
              await _onMatched(pairIndex, _lowerOrder.indexOf(pairIndex));
            } else {
              _lastRejectedSlot = _lowerOrder.indexOf(_selectedLower!);
              _onWrongDrop();
            }

            setState(() {
              _selectedUpper = null;
              _selectedLower = null;
            });
          } else {
            setState(() {
              _selectedUpper = pairIndex;
            });
          }
        },
        child: _breathingWrap(segment, pairIndex),
      ),
    );
  }

  Widget _buildLowerSegmentSlot(int slotIndex, double w, double h) {
    final pairIndex = _lowerOrder[slotIndex];
    final pair = _pairs[pairIndex];
    final size = h * 0.3;
    final wrong = _wrongSlotIndex == slotIndex;
    final segment = _buildSegment(
      letter: pair.lower,
      matched: pair.matched,
      size: size,
      color: ForestColorTheme.lightgreen,
      selected: _selectedLower == pairIndex,
    );

    return Positioned(
      left: _slotX[slotIndex] * w - size / 2,
      top: _bottomY * h - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () async {
          if (pair.matched) return;

          // Upper selected first
          if (_selectedUpper != null) {
            if (_selectedUpper == pairIndex) {
              await _onMatched(pairIndex, slotIndex);
            } else {
              _lastRejectedSlot = slotIndex;
              _onWrongDrop();
            }

            setState(() {
              _selectedUpper = null;
              _selectedLower = null;
            });
          } else {
            // No upper selected yet -> select lowercase first
            setState(() {
              _selectedLower = pairIndex;
            });
          }
        },
        child: AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (_, child) {
            final angle = wrong ? _shake.value : 0.0;
            return Transform.rotate(angle: angle, child: child);
          },
          child: _breathingWrap(segment, slotIndex),
        ),
      ),
    );
  }

  Widget _buildSegment({
    required String letter,
    required bool matched,
    required double size,
    required Color color,
    required bool selected,
  }) {
    return AnimatedScale(
      scale: matched ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        decoration: BoxDecoration(
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.yellow.withValues(alpha: 0.9),
              blurRadius: 25,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: Colors.lightGreenAccent.withValues(alpha: 0.7),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ]
              : null,
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [

              Image.asset(
                _caterpillarBodyAsset,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),

              Stack(
                alignment: Alignment.center,
                children: [

                  Text(
                    letter,
                    style: TextStyle(
                      fontFamily: ForestAppTextStyles.fredoka,
                      fontWeight: FontWeight.w900,
                      fontSize: size * .42,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = size * 0.07
                        ..color = Colors.green.shade900,
                    ),
                  ),

                  Text(
                    letter,
                    style: TextStyle(
                      fontFamily: ForestAppTextStyles.fredoka,
                      fontWeight: FontWeight.w900,
                      fontSize: size * .42,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              if (matched) _buildMatchSparkle(size),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchSparkle(double size) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, v, __) => Opacity(
        opacity: (1 - v).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.6 + v * 0.8,
          child: const Text('✨', style: TextStyle(fontSize: 22)),
        ),
      ),
    );
  }

  /// The vine connecting a matched pair -- from its fixed top-slot position
  /// down to wherever that pair ended up in the shuffled bottom row.
  Widget _buildConnectionLine(int pairIndex, double w, double h) {
    final bottomSlot = _lowerOrder.indexOf(pairIndex);
    final start = Offset(_slotX[pairIndex] * w, _topY * h);
    final end = Offset(_slotX[bottomSlot] * w, _bottomY * h);

    return IgnorePointer(
      child: CustomPaint(
        size: Size(w, h),
        painter: _VinePainter(start: start, end: end),
      ),
    );
  }

  /// Idle breathing wrapper shared by every segment (and boosted briefly
  /// into a "wiggle happily" celebration once a round completes).
  Widget _breathingWrap(Widget child, int index) {
    final phase = index * 0.6;
    final amplitude = _celebratingRound ? 0.10 : 0.03;

    return AnimatedBuilder(
      animation: _breatheCtrl,
      builder: (_, c) {
        final s = 1.0 + amplitude * sin((_breatheCtrl.value * 2 * pi) + phase);
        return Transform.scale(scale: s, child: c);
      },
      child: child,
    );
  }

  Widget _buildCaterpillarHead(double size) {
    return AnimatedBuilder(
      animation: _blinkCtrl,
      builder: (_, __) {
        return Image.asset(
          _caterpillarHeadAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      },
    );
  }

  // ── Ambient decoration ───────────────────────────────────────────────────
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

  // ── Progress dots ────────────────────────────────────────────────────────
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