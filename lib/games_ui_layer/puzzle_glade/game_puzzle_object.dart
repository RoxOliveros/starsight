import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
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
import 'game_basket_sort.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAllObjects = [
  'compass',
  'jar',
  'map',
  'notebook',
  'puzzle_piece',
];

const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _Piece {
  final int id;

  _Piece({required this.id});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PuzzleObjectScreen extends StatefulWidget {
  final int level;

  const PuzzleObjectScreen({super.key, required this.level});

  @override
  State<PuzzleObjectScreen> createState() => _PuzzleObjectScreenState();
}

class _PuzzleObjectScreenState extends State<PuzzleObjectScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<PuzzleObjectScreen>, GameLoadingMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/level5/intro.wav';
  static const String _audioWelcome = 'assets/audio/puzzle_glade/level5/welcome.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/level5/instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/level5/complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late String _currentObject;
  late List<_Piece> _trayPieces;
  int _heldPieceId = -1;
  late List<int> _slotContents;
  List<bool> _slotHighlight = List.filled(4, false);
  bool _roundComplete = false;
  bool _showWinDialog = false;
  late List<int> _correctMapping;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _pieceDanceCtrl;
  late Animation<double> _pieceDance;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _completePulseCtrl;
  late Animation<double> _completePulseAnim;

  int _gridSizeForRound(int round) => round >= 4 ? 3 : 2;
  int _pieceCountForRound(int round) {
    final g = _gridSizeForRound(round);
    return g * g;
  }

  double _boardSlotSize(int round) {
    const boardSize = 220.0;      // matches _buildPuzzleBoard's width/height
    const boardPadding = 10.0;    // matches Padding(all(10)) around the GridView
    final gridSize = _gridSizeForRound(round);
    return (boardSize - boardPadding * 2) / gridSize;
  }

  final Set<String> _usedObjects = {};

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
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _pieceDanceCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _bounceCtrl.dispose();
    _completePulseCtrl.dispose();
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

    _pieceDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pieceDance = Tween<double>(begin: -0.07, end: 0.07).animate(
      CurvedAnimation(parent: _pieceDanceCtrl, curve: Curves.easeInOut),
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

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    _completePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _completePulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _completePulseCtrl, curve: Curves.easeInOut),
    );
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _roxieSlideCtrl.forward();

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioIntro);
    if (!mounted) return;

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioWelcome);
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

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

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    final rng = Random();

    var available = _kAllObjects.where((o) => !_usedObjects.contains(o)).toList();
    if (available.isEmpty) {
      _usedObjects.clear();
      available = List<String>.from(_kAllObjects);
    }
    available.shuffle(rng);
    _currentObject = available[0];
    _usedObjects.add(_currentObject);

    final pieceCount = _pieceCountForRound(_round);

    _correctMapping = List.generate(pieceCount, (i) => i)..shuffle(rng);

    _trayPieces = List.generate(pieceCount, (i) => _Piece(id: _correctMapping[i]))
      ..shuffle(rng);

    _slotContents = List.filled(pieceCount, -1);
    _slotHighlight = List.filled(pieceCount, false);
    _heldPieceId = -1;
    _roundComplete = false;

    _bounceCtrl.reset();
    _completePulseCtrl.stop();
    _completePulseCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Piece interaction ──────────────────────────────────────────────────────

  void _pickUpPiece(int pieceId) {
    if (_roundComplete) return;
    setState(() => _heldPieceId = pieceId);
  }

  Future<void> _dropOnSlot(int slotIndex, {int? pieceId}) async {
    final incoming = pieceId ?? _heldPieceId;
    if (incoming == -1 || _roundComplete) return;

    if (_slotContents[slotIndex] != -1) {
      setState(() => _heldPieceId = -1);
      return;
    }

    if (incoming == _correctMapping[slotIndex]) {
      setState(() {
        _slotContents[slotIndex] = incoming;
        _trayPieces.removeWhere((p) => p.id == incoming);
        _heldPieceId = -1;
        _slotHighlight[slotIndex] = false;
      });

      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      _bounceCtrl.forward(from: 0);

      unawaited(showRoxieReaction(RoxieState.correct));

      if (_slotContents.every((s) => s != -1)) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;                        // <-- add
        setState(() => _roundComplete = true);

        unawaited(showRoxieReaction(RoxieState.correct));

        _completePulseCtrl.repeat(reverse: true);

        _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));

        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;                        // <-- add

        if (_round >= _kTotalRounds) {
          await _bgPlayer.stop();
          await _sfxPlayer.stop();
          if (!mounted) return;                       // <-- add

          final completer = Completer<void>();
          final sub = _completePlayer.onPlayerComplete.listen((_) {
            if (!completer.isCompleted) completer.complete();
          });
          await _completePlayer.play(
            AssetSource(_audioComplete.replaceFirst('assets/', '')),
          );
          await completer.future.timeout(const Duration(seconds: 10));
          await sub.cancel();
          if (!mounted) return;                        // <-- add

          await PuzzleProgressService.instance.markLevelComplete(5);

          if (mounted) setState(() => _showWinDialog = true);
        } else {
          await _enterCtrl.reverse();
          if (mounted) {
            setState(() {
              _round++;
              _startRound();
            });
          }
        }
      }
    } else {
      // ❌ Wrong slot
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      unawaited(showRoxieReaction(RoxieState.wrong));
      setState(() {
        _slotHighlight[slotIndex] = true;
        _heldPieceId = -1;
      });
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) setState(() => _slotHighlight[slotIndex] = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: buildWithLoading(
          loadingScreen: LoadingScreen.puzzleGlade(), gameBuilder: () =>
            Stack(
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
          child:Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
              Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildIntroRoxie()),
              Expanded(flex: 6, child: _buildIntroDancingPieces()),
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

  /// Intro preview: 4 jigsaw-style tiles dancing, mirroring the shadow-dance
  /// pattern from ShadowMatch but themed for the jigsaw puzzle.
  Widget _buildIntroDancingPieces() {
    const previewObject = 'puzzle_piece';
    // Quadrant labels matching the 2×2 board layout
    final quadrants = [
      {'col': 0, 'row': 0},
      {'col': 1, 'row': 0},
      {'col': 0, 'row': 1},
      {'col': 1, 'row': 1},
    ];

    return AnimatedBuilder(
      animation: _pieceDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: List.generate(quadrants.length, (i) {
              final angle = _pieceDance.value * ((i % 2 == 0) ? 1 : -1);
              final col = quadrants[i]['col']!;
              final row = quadrants[i]['row']!;
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 68,
                  height: 68,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: OverflowBox(
                      maxWidth: 68 * 2,
                      maxHeight: 68 * 2,
                      alignment: Alignment(
                        col == 0 ? -1.0 : 1.0,
                        row == 0 ? -1.0 : 1.0,
                      ),
                      child: Image.asset(
                        'assets/images/objects/puzzle/$previewObject.png',
                        width: 68 * 2,
                        height: 68 * 2,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Text('🧩', style: TextStyle(fontSize: 28)),
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
            child:
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [_buildPuzzleBoard(), const SizedBox(width: 32), _buildTray()],
    );
  }

  // ── Puzzle board ───────────────────────────────────────────────────────────

  Widget _buildPuzzleBoard() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.35),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ghost hint image
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/objects/puzzle/$_currentObject.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          // drop slots
          Padding(
            padding: const EdgeInsets.all(10),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _slotContents.length, // was: 4
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridSizeForRound(_round), // was: _kGridSize (const)
                mainAxisSpacing: 0,
                crossAxisSpacing: 0,
              ),
              itemBuilder: (_, slotIndex) => _buildDropSlot(slotIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropSlot(int slotIndex) {
    final filled = _slotContents[slotIndex] != -1;
    final isHighlightWrong = _slotHighlight[slotIndex];
    final isHolding = _heldPieceId != -1;

    Color borderColor = isHighlightWrong
        ? const Color(0xFFE05A5A)
        : isHolding && !filled
        ? PuzzleColorTheme.sunnyhue.withValues(alpha: 0.70)
        : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.20);

    Color bgColor = isHighlightWrong
        ? const Color(0xFFE05A5A).withValues(alpha: 0.10)
        : isHolding && !filled
        ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.15)
        : Colors.transparent;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => !filled,
      onAcceptWithDetails: (details) =>
          _dropOnSlot(slotIndex, pieceId: details.data),
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty && !filled;
        return GestureDetector(
          onTap: () => _dropOnSlot(slotIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isDragOver
                  ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.25)
                  : bgColor,
              border: Border.all(
                color: isDragOver ? PuzzleColorTheme.sunnyhue : borderColor,
                width: isDragOver ? 3.0 : 2.0,
              ),
            ),
            child: filled
                ? ClipRect(child: _buildPlacedPieceTile(slotIndex))   // wrap with ClipRect
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _buildPlacedPieceTile(int slotIndex) {
    final gridSize = _gridSizeForRound(_round);
    final isLastPlaced =
        _slotContents.where((s) => s != -1).length == 1 ||
        (_slotContents[slotIndex] != -1 &&
            _slotContents.lastIndexWhere((s) => s != -1) == slotIndex);

    Widget tile = LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final col = slotIndex % gridSize;
        final row = slotIndex ~/ gridSize;
        return ClipRRect(
          child: OverflowBox(
            maxWidth: size * gridSize,
            maxHeight: size * gridSize,
            alignment: Alignment(
              col == 0 ? -1.0 : (gridSize == 3 && col == 1 ? 0.0 : 1.0),
              row == 0 ? -1.0 : (gridSize == 3 && row == 1 ? 0.0 : 1.0),
            ),
            child: Image.asset(
              'assets/images/objects/puzzle/$_currentObject.png',
              width: size * gridSize,
              height: size * gridSize,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );

    if (isLastPlaced && !_roundComplete) {
      tile = ScaleTransition(scale: _bounceAnim, child: tile);
    }
    if (_roundComplete) {
      tile = ScaleTransition(scale: _completePulseAnim, child: tile);
    }

    return tile;
  }

  // ── Tray ───────────────────────────────────────────────────────────────────
  Widget _buildTray() {
    const trayPadding = 5.0;
    const spacing = 8.0;

    final slotSize = _boardSlotSize(_round);
    final gridSize = _gridSizeForRound(_round);
    final pieceCount = _pieceCountForRound(_round);

    final trayWidth =
        gridSize * slotSize + (gridSize) * spacing + trayPadding * 2;

    return Container(
      width: trayWidth,
      padding: const EdgeInsets.symmetric(horizontal: trayPadding, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            _buildTrayGrid(pieceCount, gridSize, slotSize, spacing),
        ],
      ),
    );
  }

  Widget _buildTrayGrid(
      int pieceCount,
      int gridSize,
      double slotSize,
      double spacing,
      ) {
    final tiles = List.generate(pieceCount, (id) {
      final piece = _trayPieces.cast<_Piece?>().firstWhere(
            (p) => p!.id == id,
        orElse: () => null,
      );
      if (piece == null) {
        return Container(
          width: slotSize,
          height: slotSize,
          decoration: BoxDecoration(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.05),
            border: Border.all(
              color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
              width: 2,
            ),
          ),
        );
      }
      return _buildTrayPiece(piece, slotSize);
    });

    // Chunk the flat tile list into rows of exactly `gridSize` items.
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += gridSize) {
      final rowTiles = tiles.sublist(
        i,
        (i + gridSize > tiles.length) ? tiles.length : i + gridSize,
      );
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + gridSize < tiles.length ? spacing : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int j = 0; j < rowTiles.length; j++) ...[
                if (j > 0) SizedBox(width: spacing),
                rowTiles[j],
              ],
            ],
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildPieceContent(int pieceId, {double size = 64}) {
    final gridSize = _gridSizeForRound(_round);
    final slotIndex = _correctMapping.indexOf(pieceId);
    final col = slotIndex % gridSize;
    final row = slotIndex ~/ gridSize;
    return ClipRRect(
      child: OverflowBox(
        maxWidth: size * gridSize,
        maxHeight: size * gridSize,
        alignment: Alignment(
          col == 0 ? -1.0 : (gridSize == 3 && col == 1 ? 0.0 : 1.0),
          row == 0 ? -1.0 : (gridSize == 3 && row == 1 ? 0.0 : 1.0),
        ),
        child: Image.asset(
          'assets/images/objects/puzzle/$_currentObject.png',
          width: size * gridSize,
          height: size * gridSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Text('🧩', style: TextStyle(fontSize: size * 0.4)),
        ),
      ),
    );
  }

  Widget _buildTrayPiece(_Piece piece, double size) { // CHANGED — added size param
    final isHeld = _heldPieceId == piece.id;

    final pieceWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,   // was: cellSize from LayoutBuilder
      height: size,  // was: cellSize from LayoutBuilder
      decoration: BoxDecoration(
        color: isHeld
            ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: isHeld
              ? PuzzleColorTheme.sunnyhue
              : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
          width: isHeld ? 3 : 2.5,
        ),
        boxShadow: isHeld
            ? [
          BoxShadow(
            color: PuzzleColorTheme.sunnyhue.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ]
            : [
          BoxShadow(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildPieceContent(piece.id, size: size),
    );

    return Draggable<int>(
      data: piece.id,
      onDragStarted: () => setState(() => _heldPieceId = piece.id),
      onDraggableCanceled: (_, __) => setState(() => _heldPieceId = -1),
      onDragCompleted: () => setState(() => _heldPieceId = -1),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: Container(
            width: size + 4,
            height: size + 4,
            decoration: BoxDecoration(
              color: PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PuzzleColorTheme.sunnyhue, width: 3),
              boxShadow: [
                BoxShadow(
                  color: PuzzleColorTheme.sunnyhue.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildPieceContent(piece.id, size: size + 4),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: pieceWidget),
      child: GestureDetector(
        onTap: () {
          if (isHeld) {
            setState(() => _heldPieceId = -1);
          } else {
            _pickUpPiece(piece.id);
          }
        },
        child: pieceWidget,
      ),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BasketSortScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PuzzleObjectScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
