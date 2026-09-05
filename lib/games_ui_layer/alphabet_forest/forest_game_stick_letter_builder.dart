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

/// One stroke of a letter, defined by its endpoints in fractional
/// coordinates (0..1) within the letter build zone. [isLong] just controls
/// which stick asset (short/long) is used to render it.
class StrokeSpec {
  final Offset start;
  final Offset end;

  const StrokeSpec(this.start, this.end);
}

/// A single letter's worth of strokes plus its decorative outline asset.
class LetterRoundSpec {
  final String letter;
  final String outlineAsset;
  final List<StrokeSpec> strokes;

  const LetterRoundSpec({
    required this.letter,
    required this.outlineAsset,
    required this.strokes,
  });
}

/// A physical stick the child drags. [strokeStart]/[strokeEnd] are the
/// fractional coords of the letter stroke this stick completes; [pileX] and
/// [pileAngle] describe where/how it sits before being picked up.
class StickPiece {
  final int index;
  final Offset strokeStart;
  final Offset strokeEnd;
  final double pileAngle;
  bool placed;
  Offset? dragPixelPos; // absolute px position within the build area while dragging

  StickPiece({
    required this.index,
    required this.strokeStart,
    required this.strokeEnd,
    required this.pileAngle,
    this.placed = false,
    this.dragPixelPos,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// GUIDE PAINTER
// ═════════════════════════════════════════════════════════════════════════

/// Draws a faint dashed guide for every stroke of the current letter, using
/// the exact same coordinates sticks snap to — so the guide can never drift
/// out of sync with the actual drop targets.
class _LetterGuidePainter extends CustomPainter {
  final List<StrokeSpec> strokes;
  final double scale;
  final Offset offset;

  _LetterGuidePainter(
      this.strokes,
      this.scale,
      this.offset,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = (size.height * 0.045).clamp(6.0, 16.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      Offset map(Offset p) {
        final cx = size.width / 2;
        final cy = size.height / 2;

        return Offset(
          cx + ((p.dx - 0.5) * scale + offset.dx) * size.width,
          cy + ((p.dy - 0.5) * scale + offset.dy) * size.height,
        );
      }

      final mid = Offset(
        (stroke.start.dx + stroke.end.dx) / 2,
        (stroke.start.dy + stroke.end.dy) / 2,
      );

      const guideShrink = 1;

      final p1 = map(Offset(
        mid.dx + (stroke.start.dx - mid.dx) * guideShrink,
        mid.dy + (stroke.start.dy - mid.dy) * guideShrink,
      ));

      final p2 = map(Offset(
        mid.dx + (stroke.end.dx - mid.dx) * guideShrink,
        mid.dy + (stroke.end.dy - mid.dy) * guideShrink,
      ));

      _drawDashedLine(canvas, p1, p2, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLength = 14.0;
    const gapLength = 10.0;
    final total = (p2 - p1).distance;
    if (total == 0) return;
    final direction = (p2 - p1) / total;
    double covered = 0;
    while (covered < total) {
      final start = p1 + direction * covered;
      final segEnd = min(covered + dashLength, total);
      final end = p1 + direction * segEnd;
      canvas.drawLine(start, end, paint);
      covered += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _LetterGuidePainter oldDelegate) => true;
}

// ═════════════════════════════════════════════════════════════════════════
// GAME
// ═════════════════════════════════════════════════════════════════════════

/// "Fallen Stick Letter Builder" — wind-blown sticks lie scattered in a
/// forest clearing. The child drags each one onto its matching stroke to
/// build V, W, then X, one letter at a time.
class FallenStickLetterBuilderGame extends StatefulWidget {
  final int level;
  const FallenStickLetterBuilderGame({super.key, required this.level});

  @override
  State<FallenStickLetterBuilderGame> createState() => _FallenStickLetterBuilderGameState();
}

class _FallenStickLetterBuilderGameState extends State<FallenStickLetterBuilderGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin<FallenStickLetterBuilderGame>,
        ForestAudioMixin<FallenStickLetterBuilderGame>,
        TofiReactionMixin<FallenStickLetterBuilderGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _stickLongAsset = 'assets/images/objects/forest/stick_long.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/fallen_stick_intro.wav';
  static const String _audioInstruction = '$_audioBase/fallen_stick_instructions.wav';
  static const String _audioWin = '$_audioBase/fallen_stick_win.wav';

  static const int _maxSticks = 4;
  static const double _letterZoneFraction = 0.68;
  static const double _pileXFraction = 0.90;
  static const double _traceScale = 0.72; // smaller letter
  static const Offset _traceOffset = Offset(0.0, 0.2); // optional move up/down

  // ── Letters V, W, X, each defined by their strokes ──────────────────────
  static const List<LetterRoundSpec> _rounds = [
    LetterRoundSpec(
      letter: 'V',
      outlineAsset: 'assets/images/objects/forest/letter_outline_v.png',
      strokes: [
        StrokeSpec(Offset(0.34, 0.06), Offset(0.50, 0.94)),
        StrokeSpec(Offset(0.50, 0.94), Offset(0.66, 0.06)),
      ],
    ),
    LetterRoundSpec(
      letter: 'W',
      outlineAsset: 'assets/images/objects/forest/letter_outline_w.png',
      strokes: [
        StrokeSpec(Offset(0.28, 0.06), Offset(0.38, 0.94)),
        StrokeSpec(Offset(0.38, 0.94), Offset(0.50, 0.48)),
        StrokeSpec(Offset(0.50, 0.48), Offset(0.62, 0.94)),
        StrokeSpec(Offset(0.62, 0.94), Offset(0.72, 0.06)),
      ],
    ),
    LetterRoundSpec(
      letter: 'X',
      outlineAsset: 'assets/images/objects/forest/letter_outline_x.png',
      strokes: [
        StrokeSpec(Offset(0.42, 0.04), Offset(0.58, 0.96)),
        StrokeSpec(Offset(0.58, 0.04), Offset(0.42, 0.96)),
      ],
    ),
  ];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRoundIndex = 0;
  int _solvedRounds = 0;
  int? _draggingIndex;
  late List<StickPiece> _sticks;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late List<AnimationController> _popCtrls; // pop/bounce when a stick snaps in
  late List<Animation<double>> _popAnims;
  late List<AnimationController> _sparkleCtrls; // sparkle flash on correct placement
  late List<Animation<double>> _sparkleAnims;
  late AnimationController _glowCtrl; // whole-letter glow on completion
  late Animation<double> _glow;
  late AnimationController _leafCtrl; // leaf burst on completion
  late AnimationController _birdCtrl; // birds flying across on completion

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRoundData();
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

    _popCtrls = List.generate(
      _maxSticks,
          (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 550)),
    );
    _popAnims = _popCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.elasticOut))
        .toList();

    _sparkleCtrls = List.generate(
      _maxSticks,
          (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)),
    );
    _sparkleAnims = _sparkleCtrls
        .map(
          (c) => TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)),
    )
        .toList();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glow = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 65),
    ]).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut));

    _leafCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _birdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  void _setupRoundData() {
    final spec = _rounds[_currentRoundIndex];
    final rng = Random();
    final n = spec.strokes.length;

    _sticks = List.generate(n, (i) {
      final s = spec.strokes[i];
      return StickPiece(
        index: i,
        strokeStart: s.start,
        strokeEnd: s.end,
        pileAngle: (rng.nextDouble() - 0.5) * 0.6,
      );
    });
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

  Future<void> _announceRound() async {
    if (_currentRoundIndex == 0) {
      await playVoice(_audioInstruction);
      if (!mounted) return;
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await playVoice(ForestAudioAssets.forLetter(_rounds[_currentRoundIndex].letter));
  }

  String get _instructionText => 'Build Letter ${_rounds[_currentRoundIndex].letter}!';

  // ── Geometry helpers (letterH is already h * _letterZoneFraction) ───────
  Offset _targetCenterPx(StickPiece s, double w, double letterH) {
    final cx = w / 2;
    final cy = letterH / 2;

    double mapX(double x) =>
        cx + ((x - 0.5) * _traceScale + _traceOffset.dx) * w;

    double mapY(double y) =>
        cy + ((y - 0.5) * _traceScale + _traceOffset.dy) * letterH;

    return Offset(
      (mapX(s.strokeStart.dx) + mapX(s.strokeEnd.dx)) / 2,
      (mapY(s.strokeStart.dy) + mapY(s.strokeEnd.dy)) / 2,
    );
  }

  double _targetAngle(StickPiece s, double w, double letterH) {
    final dx = (s.strokeEnd.dx - s.strokeStart.dx) * w;
    final dy = (s.strokeEnd.dy - s.strokeStart.dy) * letterH;
    return atan2(dy, dx);
  }

  double _targetLength(StickPiece s, double w, double letterH) {
    final dx = (s.strokeEnd.dx - s.strokeStart.dx) * w;
    final dy = (s.strokeEnd.dy - s.strokeStart.dy) * letterH;
    return sqrt(dx * dx + dy * dy) * _traceScale * 1.20;
  }

  Offset _pileCenterPx(StickPiece s, double w, double h) {
    const baseY = 120.0;

    final offsets = [
      const Offset(0, 0),
      const Offset(-12, 18),
      const Offset(8, -15),
      const Offset(-6, 34),
    ];

    return Offset(
      w * _pileXFraction + offsets[s.index].dx,
      baseY + offsets[s.index].dy,
    );
  }

  // ── Drag handling ────────────────────────────────────────────────────────
  void _onStickDropped(StickPiece stick, double w, double h) {
    if (_draggingIndex != stick.index) return;
    final letterH = h * _letterZoneFraction;
    final target = _targetCenterPx(stick, w, letterH);
    final dropPos = stick.dragPixelPos ?? _pileCenterPx(stick, w, h);
    final length = _targetLength(stick, w, letterH);
    final threshold = max(55.0, length * 0.32);
    final dist = (dropPos - target).distance;

    if (dist <= threshold) {
      HapticFeedback.mediumImpact();
      setState(() {
        stick.placed = true;
        stick.dragPixelPos = null;
        _draggingIndex = null;
      });
      _popCtrls[stick.index].forward(from: 0);
      _sparkleCtrls[stick.index].forward(from: 0);
      _checkRoundComplete();
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        stick.dragPixelPos = null; // AnimatedPositioned eases it back to the pile
        _draggingIndex = null;
      });
    }
  }

  void _checkRoundComplete() {
    if (!_sticks.every((s) => s.placed)) return;
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final letter = _rounds[_currentRoundIndex].letter;
      await playVoice(ForestAudioAssets.forLetter(letter));
      if (!mounted) return;
      await _celebrateLetter();
      if (!mounted) return;
      _solvedRounds++;
      await _advanceRound();
    });
  }

  Future<void> _celebrateLetter() async {
    _glowCtrl.forward(from: 0);
    _leafCtrl.forward(from: 0);
    _birdCtrl.forward(from: 0);
    await showTofiReaction(TofiState.correct);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
  }

  Future<void> _advanceRound() async {
    if (_currentRoundIndex >= _rounds.length - 1) {
      await playVoice(_audioWin);
      if (!mounted) return;
      await ForestProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;
      _showGoodJob();
      return;
    }

    setState(() {
      _currentRoundIndex++;
      _setupRoundData();
    });
    _sceneEnterCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _announceRound();
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
                builder: (_) => AlphabetIntroScreen(letter: 'Y'),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => FallenStickLetterBuilderGame(level: widget.level),
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
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();

    for (final ctrl in _popCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _sparkleCtrls) {
      ctrl.dispose();
    }

    _glowCtrl.dispose();
    _leafCtrl.dispose();
    _birdCtrl.dispose();

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
              Transform.rotate(
                angle: -0.35,
                child: Image.asset(
                  _stickLongAsset,
                  height: screenH * 0.1,
                  errorBuilder: (_, __, ___) => const Text('🪵', style: TextStyle(fontSize: 80)),
                ),
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
                        await playVoice(ForestAudioAssets.forLetter(_rounds[_currentRoundIndex].letter));
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
                            _buildBuildArea(inner.maxWidth, inner.maxHeight),
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

  // ── Build area (letter guide + pile + sticks) ────────────────────────────
  Widget _buildBuildArea(double w, double h) {
    final letterH = h * _letterZoneFraction;
    final letterCenter = Offset(w / 2, letterH / 2);
    final spec = _rounds[_currentRoundIndex];

    final orderedSticks = [..._sticks]..sort((a, b) {
      if (a.index == _draggingIndex) return 1;
      if (b.index == _draggingIndex) return -1;
      return 0;
    });

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: w,
            height: letterH,
            child: Opacity(
              opacity: 0.22,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: w * _traceScale,
                  height: letterH * _traceScale,
                  child: Image.asset(
                    spec.outlineAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: w,
            height: letterH,
            child: CustomPaint(
              painter: _LetterGuidePainter(
                spec.strokes,
                _traceScale,
                _traceOffset,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Positioned(
              left: letterCenter.dx - letterH * 0.4,
              top: letterCenter.dy - letterH * 0.4,
              width: letterH * 0.8,
              height: letterH * 0.8,
              child: IgnorePointer(
                child: Opacity(
                  opacity: _glow.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          ForestColorTheme.mediumseagreen.withValues(alpha: 0.55),
                          ForestColorTheme.mediumseagreen.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (final stick in orderedSticks) _buildStick(stick, w, h),
        ],
      ),
    );
  }

  Widget _buildStick(StickPiece stick, double w, double h) {
    final letterH = h * _letterZoneFraction;
    final targetCenter = _targetCenterPx(stick, w, letterH);
    final pileCenter = _pileCenterPx(stick, w, h);
    final angleBase = _targetAngle(stick, w, letterH);
    final length = _targetLength(stick, w, letterH);
    final thickness = h * 0.08;
    final isDragging = _draggingIndex == stick.index;

    final center = isDragging
        ? (stick.dragPixelPos ?? pileCenter)
        : (stick.placed ? targetCenter : pileCenter);

    final angle = (isDragging || stick.placed) ? angleBase : angleBase + stick.pileAngle;

    // The hit box needs to be big enough to contain the stick at ANY
    // rotation angle, not just length x thickness. A rotated segment's
    // bounding box never exceeds a square of side ~length centered on the
    // same point. Without this, the painted stick pokes outside its thin
    // unrotated hit box at real angles, and grabbing near the tip misses.
    final hitBoxSize = length + thickness;

    return AnimatedPositioned(
      key: ValueKey('stick_${stick.index}'),
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      left: center.dx - hitBoxSize / 2,
      top: center.dy - hitBoxSize / 2,
      width: hitBoxSize,
      height: hitBoxSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: stick.placed
            ? null
            : (_) {
          setState(() {
            _draggingIndex = stick.index;
            stick.dragPixelPos = pileCenter;
          });
        },
        onPanUpdate: (details) {
          if (_draggingIndex != stick.index) return;
          setState(() {
            stick.dragPixelPos = (stick.dragPixelPos ?? pileCenter) + details.delta;
          });
        },
        onPanEnd: (_) => _onStickDropped(stick, w, h),
        child: Center(
          child: Transform.rotate(
            angle: angle,
            child: AnimatedBuilder(
              animation: _popCtrls[stick.index],
              builder: (_, child) {
                final pop = stick.placed ? (1.0 + 0.15 * _popAnims[stick.index].value) : 1.0;
                return Transform.scale(scale: pop, child: child);
              },
              child: SizedBox(
                width: length,
                height: thickness,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _stickAsset(stick, length, thickness),
                    AnimatedBuilder(
                      animation: _sparkleCtrls[stick.index],
                      builder: (_, __) => Opacity(
                        opacity: _sparkleAnims[stick.index].value,
                        child: const Text('✨', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stickAsset(StickPiece stick, double length, double thickness) {
    return Image.asset(
      _stickLongAsset,
      width: length,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: length,
        height: thickness,
        decoration: BoxDecoration(
          color: const Color(0xFF8B5E34),
          borderRadius: BorderRadius.circular(thickness / 2),
          border: Border.all(
            color: const Color(0xFF6B4423),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_rounds.length, (i) {
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