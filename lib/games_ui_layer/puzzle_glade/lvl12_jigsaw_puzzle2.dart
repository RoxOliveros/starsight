import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_level.dart';
import '../../ui_layer/puzzle_glade/Puzzle_theme.dart';
import '../goodjob_prompt.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAllObjects = [
  'compass',
  'jar',
  'lamp',
  'magnifying_glass',
  'map',
  'pen',
  'notebook',
  'puzzle_piece',
  'star',
  'telescope',
  'water_bottle',
];

const int _kTotalRounds = 5;
const int _kGridSize = 3;

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

class Lvl12JigsawPuzzle2Screen extends StatefulWidget {
  const Lvl12JigsawPuzzle2Screen({super.key});

  @override
  State<Lvl12JigsawPuzzle2Screen> createState() => _Lvl12JigsawPuzzle2ScreenState();
}

class _Lvl12JigsawPuzzle2ScreenState extends State<Lvl12JigsawPuzzle2Screen>
    with TickerProviderStateMixin {
  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/level5/intro.wav';
  static const String _audioWelcome = 'assets/audio/puzzle_glade/level5/welcome.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/level5/instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/level5/complete.wav';

  static const String _audioSuccess = 'assets/audio/shine.wav';
  static const String _audioWrong = 'assets/audio/bubble_pop.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late String _currentObject;
  late List<_Piece> _trayPieces;
  int _heldPieceId = -1;
  late List<int> _slotContents; // length 4; -1 = empty
  final List<bool> _slotHighlight = List.filled(9, false);
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
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
    _roxieSlideCtrl.forward();

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioIntro);

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));

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
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);
    _currentObject = shuffled[0];

    _correctMapping = [0, 1, 2, 3, 4, 5, 6, 7, 8]..shuffle(rng);

    _trayPieces = List.generate(9, (i) => _Piece(id: _correctMapping[i]))
      ..shuffle(rng);

    _slotContents = List.filled(9, -1);
    _heldPieceId = -1;
    _roundComplete = false;

    for (int i = 0; i < 9; i++) {
      _slotHighlight[i] = false;
    }

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

      if (_slotContents.every((s) => s != -1)) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _roundComplete = true);
        _completePulseCtrl.repeat(reverse: true);

        _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));

        await Future.delayed(const Duration(milliseconds: 1400));

        if (_round >= _kTotalRounds) {
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
      body: Stack(
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
          SafeArea(
            child: _screenPhase == _ScreenPhase.intro
                ? _buildIntroContent()
                : FadeTransition(
              opacity: _gameFade,
              child: _buildGameContent(),
            ),
          ),
          if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIntroContent() {
    return Stack(
      children: [
        Positioned(top: 8, left: 12, child: PuzzleBackButton()),
        Positioned.fill(
          top: 48,
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
        final roxieH = h * 1.05;
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
      {'col': 0, 'row': 0}, {'col': 1, 'row': 0}, {'col': 2, 'row': 0},
      {'col': 0, 'row': 1}, {'col': 1, 'row': 1}, {'col': 2, 'row': 1},
      {'col': 0, 'row': 2}, {'col': 1, 'row': 2}, {'col': 2, 'row': 2},
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
                      color: JarColorTheme.darkdesaturatedblue.withValues(
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
                      maxWidth: 68 * 3,
                      maxHeight: 68 * 3,
                      alignment: Alignment(
                        col == 0 ? -1.0 : col == 1 ? 0.0 : 1.0,
                        row == 0 ? -1.0 : row == 1 ? 0.0 : 1.0,
                      ),
                      child: Image.asset(
                        'assets/images/objects/puzzle/$previewObject.png',
                        width: 68 * 3,
                        height: 68 * 3,
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

  Widget _buildGameContent() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildGameHeader(),
          const SizedBox(height: 12),
          Expanded(child: _buildGameArea()),
          _buildProgressDots(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildGameHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Jigsaw Puzzle',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 22,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.35),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
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
          // 3×3 drop slots
          Padding(
            padding: const EdgeInsets.all(10),
            child:
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _kGridSize,
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
        ? JarColorTheme.sunnyhue.withValues(alpha: 0.70)
        : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.20);

    Color bgColor = isHighlightWrong
        ? const Color(0xFFE05A5A).withValues(alpha: 0.10)
        : isHolding && !filled
        ? JarColorTheme.goldenyellow.withValues(alpha: 0.15)
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
                  ? JarColorTheme.goldenyellow.withValues(alpha: 0.25)
                  : bgColor,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: isDragOver ? JarColorTheme.sunnyhue : borderColor,
                width: isDragOver ? 3.0 : 2.0,
              ),
            ),
            child: filled
                ? _buildPlacedPieceTile(slotIndex)
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _buildPlacedPieceTile(int slotIndex) {
    final isLastPlaced =
        _slotContents.where((s) => s != -1).length == 1 ||
            (_slotContents[slotIndex] != -1 &&
                _slotContents.lastIndexWhere((s) => s != -1) == slotIndex);

    Widget tile = LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final col = slotIndex % 3;
        final row = slotIndex ~/ 3;
        return ClipRRect(
          borderRadius: BorderRadius.zero,
          child: OverflowBox(
            maxWidth: size * 3,
            maxHeight: size * 3,
            alignment: Alignment(
              col == 0 ? -1.0 : col == 1 ? 0.0 : 1.0,
              row == 0 ? -1.0 : row == 1 ? 0.0 : 1.0,
            ),
            child: Image.asset(
              'assets/images/objects/puzzle/$_currentObject.png',
              width: size * 3,
              height: size * 3,
              fit: BoxFit.contain,
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
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pieces',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          if (_trayPieces.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '⭐',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 15,
                  color: JarColorTheme.sunnyhue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              children: List.generate(9, (id) {
                final piece = _trayPieces.cast<_Piece?>().firstWhere(
                      (p) => p!.id == id,
                  orElse: () => null,
                );
                // Already placed — ghost slot
                if (piece == null) {
                  return Container(
                    decoration: BoxDecoration(
                      color: JarColorTheme.darkdesaturatedblue.withValues(
                        alpha: 0.05,
                      ),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: JarColorTheme.darkdesaturatedblue.withValues(
                          alpha: 0.10,
                        ),
                        width: 2,
                      ),
                    ),
                  );
                }
                return _buildTrayPiece(piece);
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildPieceContent(int pieceId, {double size = 48}) {
    final slotIndex = _correctMapping.indexOf(pieceId); // ← fix
    final col = slotIndex % 3;
    final row = slotIndex ~/ 3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: OverflowBox(
        maxWidth: size * 3,
        maxHeight: size * 3,
        alignment: Alignment(
          col == 0 ? -1.0 : col == 1 ? 0.0 : 1.0,
          row == 0 ? -1.0 : row == 1 ? 0.0 : 1.0,
        ),
        child: Image.asset(
          'assets/images/objects/puzzle/$_currentObject.png',
          width: size * 3,
          height: size * 3,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Text('🧩', style: TextStyle(fontSize: size * 0.4)),
        ),
      ),
    );
  }

  Widget _buildTrayPiece(_Piece piece) {
    final isHeld = _heldPieceId == piece.id;

    final pieceWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isHeld
            ? JarColorTheme.goldenyellow.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHeld
              ? JarColorTheme.sunnyhue
              : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
          width: isHeld ? 3 : 2.5,
        ),
        boxShadow: isHeld
            ? [
          BoxShadow(
            color: JarColorTheme.sunnyhue.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ]
            : [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(
              alpha: 0.09,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildPieceContent(piece.id),
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
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: JarColorTheme.goldenyellow.withValues(alpha: 0.28),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: JarColorTheme.sunnyhue, width: 3),
              boxShadow: [
                BoxShadow(
                  color: JarColorTheme.sunnyhue.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildPieceContent(piece.id, size: 68),
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

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kTotalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? JarColorTheme.darkdesaturatedblue
                : current
                ? JarColorTheme.sunnyhue
                : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: JarColorTheme.darkdesaturatedblue,
      onNext: () {
        //TODO
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(builder: (_) => const ()),
        // );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Lvl12JigsawPuzzle2Screen()),
        );
      },
      onBack: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PuzzleLevelScreen()),
        );
      },
    );
  }
}