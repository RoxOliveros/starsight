import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/puzzle_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_audio_path.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import 'game_maze_path.dart';

enum _ScreenPhase { intro, game }

enum ShapeType { circle, square, triangle, rectangle, star, heart }

const List<List<ShapeType>> _kConfusablePairs = [
  [ShapeType.square, ShapeType.rectangle],
  [ShapeType.circle, ShapeType.heart],
];

const String _kShapeAssetDir = 'assets/images/objects/puzzle/';

String _shapeAsset(ShapeType shape) => '$_kShapeAssetDir' 'shape_${shape.name}.png';

class _ShapeImage extends StatelessWidget {
  final ShapeType shape;
  final double size;
  final Color? silhouetteColor;

  const _ShapeImage({
    required this.shape,
    required this.size,
    this.silhouetteColor,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _shapeAsset(shape),
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: silhouetteColor,
      colorBlendMode: silhouetteColor != null ? BlendMode.srcIn : null,
    );
  }
}

const int _kTotalRounds = 5;

class ShapeFitScreen extends StatefulWidget {
  final int level;

  const ShapeFitScreen({super.key, required this.level});

  @override
  State<ShapeFitScreen> createState() => _ShapeFitScreenState();
}

class _ShapeFitScreenState extends State<ShapeFitScreen>
    with
        TickerProviderStateMixin,
        RoxieReactionMixin,
        GameLoadingMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<ShapeFitScreen> {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _roxiePlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _roxiePlayer];

  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/shape_fit_intro.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/shape_fit_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/shape_fit_complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  List<ShapeType> _roundShapes = [];
  List<ShapeType> _pieceOrder = [];
  List<ShapeType> _slotOrder = [];
  final Set<ShapeType> _placed = {};
  bool _showWinDialog = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool inputEnabled = false;

  final Map<ShapeType, double> _pieceTilt = {};

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _roxieFloatCtrl;
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _shapeDanceCtrl;
  late Animation<double> _shapeDance;
  late AnimationController _speechBubbleCtrl;
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
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

  Future<void> _startIntroFlow() async {
    inputEnabled = false;

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _roxieSlideCtrl.forward();
    _speechBubbleCtrl.forward(from: 0);

    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioIntro);
    if (!mounted) return;

    _speechBubbleCtrl.forward(from: 0);
    _gameEnterCtrl.forward();

    _startRound();

    setState(() {
      _screenPhase = _ScreenPhase.game;
      inputEnabled = false;
    });

    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioInstructions);
    if (!mounted) return;

    setState(() {
      inputEnabled = true;
    });
  }

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
        return 6;
    }
  }

  List<ShapeType> _pickShapesForRound(int round, int count) {
    final rng = Random();
    final all = List<ShapeType>.from(ShapeType.values)..shuffle(rng);
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

  void _startRound() {
    final rng = Random();
    final count = _shapeCountForRound(_round);
    _roundShapes = _pickShapesForRound(_round, count);

    _pieceOrder = List<ShapeType>.from(_roundShapes)..shuffle(rng);
    _slotOrder = List<ShapeType>.from(_roundShapes)..shuffle(rng);

    _placed.clear();
    _pieceTilt.clear();
    if (_round >= 4 || widget.level >= 5) {
      for (final s in _roundShapes) {
        _pieceTilt[s] = (rng.nextDouble() - 0.5) * 0.35;
      }
    }

    _enterCtrl.forward(from: 0);
  }

  Future<void> _onPieceDropped(ShapeType piece, ShapeType slot) async {
    if (!inputEnabled || _placed.contains(slot)) return;
    if (_placed.contains(slot)) return;

    if (piece == slot) {
      _tapTracker.recordCorrectTap();
      setState(() {
        _placed.add(piece);
        inputEnabled = false;
      });
      showRoxieReaction(RoxieState.correct);

      await playVoiceRestartingOnFaceLoss(_audioPlayer, PuzzleAudioPath.forShape(piece.name),);
      if (!mounted) return;

      if (_placed.length == _roundShapes.length) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        await _advanceRound();
      } else {
        setState(() => inputEnabled = true);
      }
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showRoxieReaction(RoxieState.wrong);
      await Future.delayed(const Duration(milliseconds: 550));
    }
  }

  Future<void> _advanceRound() async {
    if (_round >= _kTotalRounds) {
      await _saveDataAndShowWinDialog();
      return;
    }

    await _enterCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _round++;
      _startRound();
      inputEnabled = true;
    });
  }

  Future<void> _saveDataAndShowWinDialog() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    PuzzleDatabaseService.saveGameData(
      gameId: 'puzzle_shape_fit',
      activityName: 'Shape Fit',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    PuzzleProgressService.instance.markLevelComplete(widget.level).catchError((e) {
      debugPrint("Database Error marking level complete: $e");
    });

    _audioPlayer.stop();
    _roxiePlayer.stop();

    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioComplete);
    if (!mounted) return;

    setState(() => _showWinDialog = true);
  }

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
                    ],
                  ),

            Positioned(top: 25, left: 25, child: PuzzleXButton()),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroLayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: PuzzleLevelBadge(level: widget.level),
              ),
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
        return Align(
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
                      color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                        alpha: 0.30,
                      ),
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
                    child: _ShapeImage(shape: shape, size: 52),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

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
                Align(
                  alignment: Alignment.centerRight,
                  child: PuzzleLevelBadge(level: widget.level),
                ),
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

  Widget _buildSlotsRow() {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      alignment: WrapAlignment.center,
      children: _slotOrder
          .map(
            (shape) => KeyedSubtree(
              key: ValueKey('slot_$shape'),
              child: _buildSlot(shape),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSlot(ShapeType shape) {
    final isFilled = _placed.contains(shape);

    return DragTarget<ShapeType>(
      onWillAcceptWithDetails: (details) => !isFilled,
      onAcceptWithDetails: (details) => _onPieceDropped(details.data, shape),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty && !isFilled;

        Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(
          alpha: 0.30,
        );
        Color bgColor = Colors.white.withValues(alpha: 0.55);

        if (isHovering) {
          borderColor = PuzzleColorTheme.sunnyhue;
          bgColor = Colors.white.withValues(alpha: 0.85);
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
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                  alpha: 0.10,
                ),
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
              child: _ShapeImage(
                shape: shape,
                size: 68,
                silhouetteColor: isFilled
                    ? null
                    : PuzzleColorTheme.verydarkdesaturatedblue.withValues(alpha: 0.35),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPiecesRow() {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      alignment: WrapAlignment.center,
      children: _pieceOrder
          .map(
            (shape) => KeyedSubtree(
              key: ValueKey('piece_$shape'),
              child: _buildPiece(shape),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPiece(ShapeType shape) {
    final isPlaced = _placed.contains(shape);
    final tilt = _pieceTilt[shape] ?? 0.0;

    if (isPlaced) {
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

    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(
      alpha: 0.28,
    );
    Color bgColor = Colors.white.withValues(alpha: 0.85);

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

    Widget shapeVisual = _ShapeImage(shape: shape, size: 58);

    if (tilt != 0) {
      shapeVisual = Transform.rotate(angle: tilt, child: shapeVisual);
    }

    return Draggable<ShapeType>(
      data: shape,
      maxSimultaneousDrags: inputEnabled ? 1 : 0,
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          _tapTracker.recordMistake();
          _tapTracker.recordMistake();
        }
      },
      feedback: Material(color: Colors.transparent, child: shapeVisual),
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

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MazePathScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        setState(() {
          _round = 1;
          _showWinDialog = false;
          _hasSavedResult = false;
          inputEnabled = true;
          _tapTracker.startSession();
        });
        _startRound();
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}