import 'dart:math';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/jar/jar_buttons.dart';
import '../../ui_layer/jar/jar_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kPuzzleObjects = [
  'alarmclock',
  'ball',
  'car',
  'apple',
  'duck',
  'teddybear',
  'lamp',
  'plant',
];

const int _kTotalRounds = 5;
const int _kGridSize    = 2;

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

class JarJigsawPuzzleScreen extends StatefulWidget {
  const JarJigsawPuzzleScreen({super.key});

  @override
  State<JarJigsawPuzzleScreen> createState() => _JarJigsawPuzzleScreenState();
}

class _JarJigsawPuzzleScreenState extends State<JarJigsawPuzzleScreen>
    with TickerProviderStateMixin {

  // ── Round state ─────────────────────────────────────────────────────────────

  int    _round         = 1;
  late String _currentObject;

  /// The 4 pieces in the tray (shuffled order).
  late List<_Piece> _trayPieces;

  /// Which piece is currently held by the user (-1 = none).
  int  _heldPieceId   = -1;

  /// Which slots have been filled (slot index → piece id, or -1 = empty).
  late List<int> _slotContents; // length 4

  bool _roundComplete = false;

  // ── Animations ──────────────────────────────────────────────────────────────

  late AnimationController _enterCtrl;
  late Animation<double>   _enterAnim;

  late AnimationController _bounceCtrl;
  late Animation<double>   _bounceAnim;

  late AnimationController _completePulseCtrl;
  late Animation<double>   _completePulseAnim;

  // Drop highlight animation per slot
  final List<bool> _slotHighlight = List.filled(4, false);

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );

    _completePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _completePulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _completePulseCtrl, curve: Curves.easeInOut),
    );

    _startRound();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _enterCtrl.dispose();
    _bounceCtrl.dispose();
    _completePulseCtrl.dispose();
    super.dispose();
  }

  // ── Round logic ─────────────────────────────────────────────────────────────

  void _startRound() {
    final rng      = Random();
    final shuffled = List<String>.from(_kPuzzleObjects)..shuffle(rng);
    _currentObject = shuffled[0];

    // Pieces 0–3 in shuffled order for the tray
    _trayPieces = List.generate(4, (i) => _Piece(id: i))
      ..shuffle(rng);

    _slotContents   = List.filled(4, -1);
    _heldPieceId    = -1;
    _roundComplete  = false;

    for (int i = 0; i < 4; i++) {
      _slotHighlight[i] = false;
    }

    _bounceCtrl.reset();
    _completePulseCtrl.stop();
    _completePulseCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  void _pickUpPiece(int pieceId) {
    if (_roundComplete) return;
    setState(() => _heldPieceId = pieceId);
  }

  Future<void> _dropOnSlot(int slotIndex) async {
    if (_heldPieceId == -1 || _roundComplete) return;

    // Only allow drop if the slot is empty AND piece matches slot
    if (_slotContents[slotIndex] != -1) {
      setState(() => _heldPieceId = -1);
      return;
    }

    if (_heldPieceId == slotIndex) {
      // ✅ Correct placement
      setState(() {
        _slotContents[slotIndex] = _heldPieceId;
        _trayPieces.removeWhere((p) => p.id == _heldPieceId);
        _heldPieceId = -1;
        _slotHighlight[slotIndex] = false;
      });

      _bounceCtrl.forward(from: 0);

      // Check if all 4 slots filled
      if (_slotContents.every((s) => s != -1)) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _roundComplete = true);
        _completePulseCtrl.repeat(reverse: true);
        await Future.delayed(const Duration(milliseconds: 1400));

        if (_round >= _kTotalRounds) {
          _showEndDialog();
        } else {
          await _enterCtrl.reverse();
          setState(() {
            _round++;
            _startRound();
          });
        }
      }
    } else {
      // ❌ Wrong slot — flash red briefly
      setState(() {
        _slotHighlight[slotIndex] = true;
        _heldPieceId = -1;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _slotHighlight[slotIndex] = false);
    }
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: JarColorTheme.vandecane,
        title: const Text(
          '🧩 Puzzle Master!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: JarColorTheme.verydarkdesaturatedblue,
          ),
        ),
        content: const Text(
          'You completed all the puzzles!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 20,
            color: JarColorTheme.darkdesaturatedblue,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _round = 1;
                _startRound();
              });
            },
            child: const Text(
              'Play Again',
              style: TextStyle(
                fontFamily: JarAppTextStyles.fredoka,
                fontSize: 20,
                color: JarColorTheme.sunnyhue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarColorTheme.lightgrayishyellow,
      body: SafeArea(
        child: FadeTransition(
          opacity: _enterAnim,
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHeader(),
              const SizedBox(height: 4),
              _buildPrompt(),
              const SizedBox(height: 10),
              Expanded(child: _buildGameArea()),
              _buildProgressDots(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: JarBackButton()),
          const Text(
            'Jigsaw Puzzle',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: JarColorTheme.verydarkdesaturatedblue,
            ),
          ),
        ],
      ),
    );
  }

  // ── Prompt ──────────────────────────────────────────────────────────────────

  Widget _buildPrompt() {
    return Text(
      _roundComplete
          ? '🎉 Puzzle complete!'
          : _heldPieceId != -1
          ? 'Now drop it in the right spot!'
          : 'Tap a piece, then tap where it goes!',
      style: TextStyle(
        fontFamily: JarAppTextStyles.fredoka,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _roundComplete
            ? JarColorTheme.sunnyhue
            : JarColorTheme.verydarkdesaturatedblue,
      ),
    );
  }

  // ── Game area ───────────────────────────────────────────────────────────────

  Widget _buildGameArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPuzzleBoard(),
        const SizedBox(width: 48),
        _buildTray(),
      ],
    );
  }

  // ── Puzzle board (2×2 drop slots) ───────────────────────────────────────────

  Widget _buildPuzzleBoard() {
    // A faint ghost of the full image as background hint
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: JarColorTheme.vandecane,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.25),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ghost / hint image (very faint)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/objects/$_currentObject.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // 2×2 grid of drop slots
          Padding(
            padding: const EdgeInsets.all(10),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _kGridSize,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (_, slotIndex) => _buildDropSlot(slotIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropSlot(int slotIndex) {
    final filled      = _slotContents[slotIndex] != -1;
    final isHighlightWrong = _slotHighlight[slotIndex];
    final isHolding   = _heldPieceId != -1;

    // Label positions: 0=TL, 1=TR, 2=BL, 3=BR
    final labels = ['↖', '↗', '↙', '↘'];

    Color borderColor = isHighlightWrong
        ? const Color(0xFFE05A5A)
        : isHolding && !filled
        ? JarColorTheme.sunnyhue.withValues(alpha: 0.70)
        : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.20);

    Color bgColor = isHighlightWrong
        ? const Color(0xFFE05A5A).withValues(alpha: 0.12)
        : isHolding && !filled
        ? JarColorTheme.goldenyellow.withValues(alpha: 0.15)
        : Colors.transparent;

    return GestureDetector(
      onTap: () => _dropOnSlot(slotIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: filled ? 2.0 : 2.0,
            style: filled ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: filled
            ? _buildPlacedPieceTile(slotIndex)
            : Center(
          child: Text(
            labels[slotIndex],
            style: TextStyle(
              fontSize: 20,
              color: JarColorTheme.darkdesaturatedblue
                  .withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows the placed piece using ClipRect to show only the correct quadrant.
  Widget _buildPlacedPieceTile(int slotIndex) {
    // slotIndex: 0=TL,1=TR,2=BL,3=BR
    final bool isLastPlaced =
        _slotContents.where((s) => s != -1).length == 1 ||
            (_slotContents[slotIndex] != -1 &&
                _slotContents.lastIndexWhere((s) => s != -1) == slotIndex);

    Widget tile = LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        // Alignment: offset so only the correct quadrant shows
        final col = slotIndex % 2;
        final row = slotIndex ~/ 2;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: OverflowBox(
            maxWidth: size * 2,
            maxHeight: size * 2,
            alignment: Alignment(
              col == 0 ? -1.0 : 1.0,
              row == 0 ? -1.0 : 1.0,
            ),
            child: Image.asset(
              'assets/images/objects/$_currentObject.png',
              width: size * 2,
              height: size * 2,
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

  // ── Tray (source pieces) ────────────────────────────────────────────────────

  Widget _buildTray() {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: JarColorTheme.vandecane,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.18),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _trayPieces
                .map((piece) => _buildTrayPiece(piece))
                .toList(),
          ),
          if (_trayPieces.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '✅ All placed!',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 15,
                  color: JarColorTheme.sunnyhue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrayPiece(_Piece piece) {
    final isHeld    = _heldPieceId == piece.id;
    final col       = piece.id % 2;
    final row       = piece.id ~/ 2;

    return GestureDetector(
      onTap: () {
        if (isHeld) {
          setState(() => _heldPieceId = -1); // deselect
        } else {
          _pickUpPiece(piece.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: isHeld
              ? JarColorTheme.goldenyellow.withValues(alpha: 0.30)
              : JarColorTheme.lightgrayishyellow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHeld
                ? JarColorTheme.sunnyhue
                : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.22),
            width: isHeld ? 3 : 2,
          ),
          boxShadow: isHeld
              ? [
            BoxShadow(
              color: JarColorTheme.sunnyhue.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: OverflowBox(
            maxWidth: 68 * 2,
            maxHeight: 68 * 2,
            alignment: Alignment(
              col == 0 ? -1.0 : 1.0,
              row == 0 ? -1.0 : 1.0,
            ),
            child: Image.asset(
              'assets/images/objects/$_currentObject.png',
              width: 68 * 2,
              height: 68 * 2,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kTotalRounds, (i) {
        final done    = i + 1 < _round;
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
}