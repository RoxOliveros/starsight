import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_audio_helper.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ── Shape types ────────────────────────────────────────────────────────────
enum ShapeType { circle, square, triangle, rectangle, star, heart }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

// Pairs of shapes that look similar to one another, used to raise difficulty
// at higher levels by making sure at least one confusable pair is on screen.
const List<List<ShapeType>> _kConfusablePairs = [
  [ShapeType.square, ShapeType.rectangle],
  [ShapeType.circle, ShapeType.heart],
];

const Map<ShapeType, Color> _kShapeColors = {
  ShapeType.circle: Color(0xFF4FA8E0),
  ShapeType.square: Color(0xFFE0654F),
  ShapeType.triangle: Color(0xFF5FC489),
  ShapeType.rectangle: Color(0xFFA36FE0),
  ShapeType.star: Color(0xFFF2B33D),
  ShapeType.heart: Color(0xFFE85B9B),
};

const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ShapeFitScreen extends StatefulWidget {
  final int level;

  const ShapeFitScreen({super.key, required this.level});

  @override
  State<ShapeFitScreen> createState() => _ShapeFitScreenState();
}

class _ShapeFitScreenState extends State<ShapeFitScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<ShapeFitScreen>, GameLoadingMixin, PuzzleAudioMixin {
  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/shape_fit_intro.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/shape_fit_instruction.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/shape_fit_complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  List<ShapeType> _roundShapes = [];
  List<ShapeType> _pieceOrder = [];
  List<ShapeType> _slotOrder = [];
  final Set<ShapeType> _placed = {};
  ShapeType? _wrongSlotFlash;
  ShapeType? _wrongPieceFlash;
  bool _showWinDialog = false;

  // Small random tilt applied to pieces at higher levels for extra challenge.
  final Map<ShapeType, double> _pieceTilt = {};

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _roxiePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _shapeDanceCtrl;
  late Animation<double> _shapeDance;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;


  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  @override
  void dispose() {
    _bgPlayer.dispose();
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxiePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _shapeDanceCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Animation init ─────────────────────────────────────────────────────────

  void _initAnimations() {
    _roxieFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _roxieSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _roxieSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut),
    );
    _roxieFade = CurvedAnimation(
      parent: _roxieSlideCtrl,
      curve: const Interval(0, 0.4),
    );

    _shapeDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _shapeDance = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _shapeDanceCtrl, curve: Curves.easeInOut),
    );

    _speechBubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioIntro);

    _speechBubbleCtrl.forward(from: 0);

    _gameEnterCtrl.forward();
    _startRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
    await _playBgAudio(_audioInstructions);
  }

  Future<void> _playBgAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _bgPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _bgPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  // ── Difficulty ─────────────────────────────────────────────────────────────

  int _shapeCountForRound(int round) {
    switch (round) {
      case 1:
        return 2;
      case 2:
        return 3;
      case 3:
        return 4;
      case 4:
        return 5;
      default:
        return 6; // round 5: all shape types
    }
  }

  List<ShapeType> _pickShapesForRound(int round, int count) {
    final rng = Random();
    final all = List<ShapeType>.from(ShapeType.values)..shuffle(rng);

    // Later rounds (and higher levels) get a guaranteed confusable pair.
    final bool harder = round >= 4 || widget.level >= 5;

    if (harder) {
      final pair = _kConfusablePairs[rng.nextInt(_kConfusablePairs.length)];
      final picks = <ShapeType>{...pair};
      for (final s in all) {
        if (picks.length >= count) break;
        picks.add(s);
      }
      return picks.take(count).toList()..shuffle(rng);
    }

    return all.take(count).toList();
  }

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    final rng = Random();
    final count = _shapeCountForRound(_round);
    _roundShapes = _pickShapesForRound(_round, count);

    _pieceOrder = List<ShapeType>.from(_roundShapes)..shuffle(rng);
    _slotOrder = List<ShapeType>.from(_roundShapes)..shuffle(rng);

    _placed.clear();
    _wrongSlotFlash = null;
    _wrongPieceFlash = null;

    _pieceTilt.clear();
    if (_round >= 4 || widget.level >= 5) {
      for (final s in _roundShapes) {
        _pieceTilt[s] = (rng.nextDouble() - 0.5) * 0.35;
      }
    }

    _enterCtrl.forward(from: 0);
  }

  // ── Drop handling ──────────────────────────────────────────────────────────

  Future<void> _onPieceDropped(ShapeType piece, ShapeType slot) async {
    if (_placed.contains(slot)) return;

    if (piece == slot) {
      setState(() => _placed.add(piece));
      unawaited(showRoxieReaction(RoxieState.correct, playSound: false));
      await playVoice(PuzzleAudioAssets.forShape(piece.name));

      if (_placed.length == _roundShapes.length) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _advanceRound();
      }
    } else {
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      unawaited(showRoxieReaction(RoxieState.wrong));
      setState(() {
        _wrongSlotFlash = slot;
        _wrongPieceFlash = piece;
      });
      await Future.delayed(const Duration(milliseconds: 550));
      if (mounted) {
        setState(() {
          _wrongSlotFlash = null;
          _wrongPieceFlash = null;
        });
      }
    }
  }

  Future<void> _advanceRound() async {
    if (_round >= _kTotalRounds) {
      await _completeRound();
      return;
    }

    await _enterCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _round++;
      _startRound();
    });
  }

  Future<void> _completeRound() async {
    await _bgPlayer.stop();
    await _sfxPlayer.stop();

    final completer = Completer<void>();
    final sub = _completePlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    await _completePlayer.play(
      AssetSource(_audioComplete.replaceFirst('assets/', '')),
    );
    await completer.future.timeout(const Duration(seconds: 10));
    await sub.cancel();

    await PuzzleProgressService.instance.markLevelComplete(widget.level);

    if (mounted) setState(() => _showWinDialog = true);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.puzzleGlade(),
        gameBuilder: () => Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  Image.asset(
                    _bgImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.15)),
                ],
              ),
            ),
            _screenPhase == _ScreenPhase.intro
                ? _buildIntroLayer()
                : Stack(
              children: [
                FadeTransition(
                  opacity: _gameFade,
                  child: _buildGameLayer(),
                ),
                buildRoxie(context),
              ],
            ),
            if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIntroLayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
              Align(alignment: Alignment.center, child: PuzzleGameHeader(title: 'Shape Fit')),
              Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildIntroRoxie()),
              Expanded(flex: 6, child: _buildIntroDancingShapes()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroRoxie() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final roxieH = h * 0.95;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _roxieFloatCtrl, curve: Curves.easeInOut),
        );
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _roxieSlide,
              child: FadeTransition(
                opacity: _roxieFade,
                child: AnimatedBuilder(
                  animation: _roxieFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, floatY),
                    child: child,
                  ),
                  child: Image.asset(
                    _characterImage,
                    height: roxieH,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Text('🐰', style: TextStyle(fontSize: roxieH * 0.5)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroDancingShapes() {
    const previewShapes = [ShapeType.circle, ShapeType.star];
    return AnimatedBuilder(
      animation: _shapeDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: List.generate(previewShapes.length, (i) {
              final shape = previewShapes[i];
              final angle = _shapeDance.value * ((i % 2 == 0) ? 1 : -1);
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.30),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(52, 52),
                      painter: _ShapePainter(
                        shape: shape,
                        color: _kShapeColors[shape]!,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameLayer() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
                Align(
                  alignment: Alignment.center,
                  child: PuzzleGameInstruction(
                    instruction: 'Drag each shape into its matching slot',
                  ),
                ),
                Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
              ],
            ),
          ),
          Expanded(child: _buildGameArea()),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: PuzzleProgressDots(
              currentRound: _round,
              totalRounds: _kTotalRounds,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: Center(child: _buildSlotsRow())),
        const SizedBox(height: 16),
        Expanded(child: Center(child: _buildPiecesRow())),
      ],
    );
  }

  // ── Slots ──────────────────────────────────────────────────────────────────

  Widget _buildSlotsRow() {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      alignment: WrapAlignment.center,
      children: _slotOrder
          .map((shape) => KeyedSubtree(
        key: ValueKey('slot_$shape'),
        child: _buildSlot(shape),
      ))
          .toList(),
    );
  }

  Widget _buildSlot(ShapeType shape) {
    final isFilled = _placed.contains(shape);
    final isWrong = _wrongSlotFlash == shape;

    return DragTarget<ShapeType>(
      onWillAcceptWithDetails: (details) => !isFilled,
      onAcceptWithDetails: (details) => _onPieceDropped(details.data, shape),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty && !isFilled;

        Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.30);
        Color bgColor = Colors.white.withValues(alpha: 0.55);

        if (isHovering) {
          borderColor = PuzzleColorTheme.sunnyhue;
          bgColor = Colors.white.withValues(alpha: 0.85);
        }
        if (isWrong) {
          borderColor = const Color(0xFFE05A5A);
          bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.10);
        }
        if (isFilled) {
          borderColor = PuzzleColorTheme.sunnyhue;
          bgColor = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.22);
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor,
              width: isHovering || isFilled ? 3.5 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: AnimatedScale(
              scale: isFilled ? 1.0 : 0.7,
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              child: CustomPaint(
                size: const Size(68, 68),
                painter: isFilled
                    ? _ShapePainter(shape: shape, color: _kShapeColors[shape]!)
                    : _ShapeOutlinePainter(
                  shape: shape,
                  color: PuzzleColorTheme.verydarkdesaturatedblue.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Pieces ─────────────────────────────────────────────────────────────────

  Widget _buildPiecesRow() {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      alignment: WrapAlignment.center,
      children: _pieceOrder
          .map((shape) => KeyedSubtree(
        key: ValueKey('piece_$shape'),
        child: _buildPiece(shape),
      ))
          .toList(),
    );
  }

  Widget _buildPiece(ShapeType shape) {
    final isPlaced = _placed.contains(shape);
    final isWrong = _wrongPieceFlash == shape;
    final tilt = _pieceTilt[shape] ?? 0.0;

    if (isPlaced) {
      // Leaves a soft placeholder where the piece used to sit.
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.12),
            width: 2,
          ),
        ),
      );
    }

    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28);
    Color bgColor = Colors.white.withValues(alpha: 0.85);
    if (isWrong) {
      borderColor = const Color(0xFFE05A5A);
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.10);
    }

    final cardDecoration = BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderColor, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

    Widget shapeVisual = CustomPaint(
      size: const Size(58, 58),
      painter: _ShapePainter(shape: shape, color: _kShapeColors[shape]!),
    );

    if (tilt != 0) {
      shapeVisual = Transform.rotate(angle: tilt, child: shapeVisual);
    }

    return Draggable<ShapeType>(
      data: shape,
      feedback: Material(
        color: Colors.transparent,
        child: shapeVisual,
      ),
      childWhenDragging: Container(
        width: 88,
        height: 88,
        decoration: cardDecoration.copyWith(
          color: bgColor.withValues(alpha: 0.35),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        height: 88,
        decoration: cardDecoration,
        child: Center(child: shapeVisual),
      ),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => (level: widget.level + 1),
        //   ),
        // );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ShapeFitScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shape geometry
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a [Path] for the given [shape] within the bounds of [size],
/// anchored at the origin (0,0).
Path _buildShapePath(ShapeType shape, Size size) {
  final w = size.width;
  final h = size.height;

  switch (shape) {
    case ShapeType.circle:
      return Path()..addOval(Rect.fromLTWH(0, 0, w, h));

    case ShapeType.square:
      final side = min(w, h);
      final dx = (w - side) / 2;
      final dy = (h - side) / 2;
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, dy, side, side),
          Radius.circular(side * 0.14),
        ));

    case ShapeType.rectangle:
      final rectH = h * 0.62;
      final dy = (h - rectH) / 2;
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, dy, w, rectH),
          Radius.circular(rectH * 0.18),
        ));

    case ShapeType.triangle:
      final path = Path();
      path.moveTo(w / 2, 0);
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
      return path;

    case ShapeType.star:
      return _starPath(w, h, points: 5, innerRatio: 0.5);

    case ShapeType.heart:
      return _heartPath(w, h);
  }
}

Path _starPath(double w, double h, {int points = 5, double innerRatio = 0.5}) {
  final path = Path();
  final cx = w / 2;
  final cy = h / 2;
  final outerR = min(w, h) / 2;
  final innerR = outerR * innerRatio;
  final step = pi / points;

  for (int i = 0; i < points * 2; i++) {
    final r = i.isEven ? outerR : innerR;
    final angle = -pi / 2 + i * step;
    final x = cx + r * cos(angle);
    final y = cy + r * sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

Path _heartPath(double w, double h) {
  final path = Path();
  path.moveTo(w / 2, h * 0.92);
  path.cubicTo(
    -w * 0.15, h * 0.55,
    w * 0.05, -h * 0.08,
    w / 2, h * 0.28,
  );
  path.cubicTo(
    w * 0.95, -h * 0.08,
    w * 1.15, h * 0.55,
    w / 2, h * 0.92,
  );
  path.close();
  return path;
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

class _ShapePainter extends CustomPainter {
  final ShapeType shape;
  final Color color;

  const _ShapePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildShapePath(shape, size);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}

class _ShapeOutlinePainter extends CustomPainter {
  final ShapeType shape;
  final Color color;

  const _ShapeOutlinePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildShapePath(shape, size);
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ShapeOutlinePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}