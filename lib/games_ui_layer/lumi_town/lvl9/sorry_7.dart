import 'dart:async';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_8.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Sorry7Screen extends StatefulWidget {
  const Sorry7Screen({super.key});

  @override
  State<Sorry7Screen> createState() => _Sorry7ScreenState();
}

class _Sorry7ScreenState extends State<Sorry7Screen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- Game Phase State ---
  // 1 = First puzzle ("KINUHA KO ANG LARUAN MO")
  // 2 = Second puzzle ("HINDI KO NA UULITIN")
  int _currentPhase = 1;

  // --- Interaction State ---
  // Set to TRUE immediately since there is no intro audio!
  bool _canDrag = true;

  // --- Phase 1 Placement State (Row 1 - Top) ---
  bool _kinuhaKoPlaced = false;
  bool _angPlaced = false;
  bool _laruanMoPlaced = false;

  // --- Phase 2 Placement State (Row 2 - Bottom) ---
  bool _hindiPlaced = false;
  bool _koNaPlaced = false;
  bool _uulitinPlaced = false;

  @override
  void initState() {
    super.initState();
    _setupLandscapeOrientation();
    // No intro audio called here — user can start dragging immediately!
  }

  void _setupLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Checks if the active puzzle row is complete and triggers the right sequence
  void _checkCompletion() {
    if (_currentPhase == 1) {
      if (_kinuhaKoPlaced && _angPlaced && _laruanMoPlaced) {
        debugPrint('Phase 1 Complete: KINUHA KO ANG LARUAN MO!');
        _playPhase1CompleteSequence();
      }
    } else if (_currentPhase == 2) {
      if (_hindiPlaced && _koNaPlaced && _uulitinPlaced) {
        debugPrint('Phase 2 Complete: HINDI KO NA UULITIN!');
        _playFinalVictorySequence();
      }
    }
  }

  /// When Row 1 completes: play shine.wav, glide up, and reveal Row 2!
  Future<void> _playPhase1CompleteSequence() async {
    try {
      setState(() => _canDrag = false); // Temporarily lock while animating
      await _audioPlayer.stop();

      // Play shine sound effect
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // Glide Row 1 up, fade in Row 2, and unlock dragging!
      setState(() {
        _currentPhase = 2;
        _canDrag = true;
      });
    } catch (e) {
      debugPrint('Error in Phase 1 transition: $e');
      if (mounted) {
        setState(() {
          _currentPhase = 2;
          _canDrag = true;
        });
      }
    }
  }

  /// When Row 2 completes: play shine.wav then sorry_8.wav
  Future<void> _playFinalVictorySequence() async {
    try {
      setState(() => _canDrag = false);
      await _audioPlayer.stop();

      // 1. Play celebration shine audio
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // 2. Play sorry_8.wav
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_8.wav'),
      );
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // Navigate to the Celebration Finale (Scene 8)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Sorry8Screen()),
      );
    } catch (e) {
      debugPrint('Error in final victory sequence: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    // Base Piece Size (Row 1)
    final double pieceWidth = sw * 0.16;
    final double pieceHeight = pieceWidth;

    // --- ROW 2 WIDTH EXPANSION ---
    // Makes Row 2 pieces slightly wider to close their internal gaps!
    // TWEAK THIS: Increase to 0.25 if there is still a gap, decrease to 0.15 if they overlap too much!
    final double row2WidthExpansion = pieceWidth * 0.08;
    final double row2PieceWidth = pieceWidth + row2WidthExpansion;

    // --- VERTICAL POSITIONING & OVERLAP MATH ---
    final double puzzleTopPosition = _currentPhase == 1 ? sh * 0.18 : sh * 0.05;

    // Vertical Depth: Kept at 0.50 as you confirmed it was correct!
    final double verticalOverlap = pieceHeight * 0.52;
    final double row2TopOffset = pieceHeight - verticalOverlap;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image
          Image.asset(
            'assets/images/backgrounds/bg_lumi_puzzle.jpg',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFBE4C3),
                    Color(0xFFFBE4C3),
                    Color(0xFFECA352),
                    Color(0xFFECA352),
                  ],
                  stops: [0.0, 0.60, 0.60, 1.0],
                ),
              ),
            ),
          ),

          // 2. Top Area: 2-Row Puzzle Grid
          AnimatedPositioned(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutBack,
            top: puzzleTopPosition,
            left: 0,
            right: 0,
            child: Builder(
              builder: (context) {
                final double horizontalOverlap = pieceWidth * 0.42;
                final double step = pieceWidth - horizontalOverlap;
                final double totalWidth = pieceWidth + step * 2;
                final double totalHeight = pieceHeight + row2TopOffset;

                return Center(
                  child: SizedBox(
                    width: totalWidth,
                    height: totalHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // ====================================================
                        // ROW 1 (TOP): "KINUHA KO ANG LARUAN MO"
                        // Listed FIRST so that Row 2's top knobs paint ON TOP of Row 1!
                        // ====================================================
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SizedBox(
                            width: totalWidth,
                            height: pieceHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: 0 - (pieceWidth * 0.03),
                                  top: 0,
                                  child: _buildDragTarget(
                                    id: 'KINUHA_KO',
                                    isPlaced: _kinuhaKoPlaced,
                                    placeholderAsset:
                                        'assets/images/objects/lumi/kinuhako_placeholder.png',
                                    placedAsset:
                                        'assets/images/objects/lumi/kinuhako_rp.png',
                                    width: pieceWidth,
                                    height: pieceHeight,
                                    onAccept: () => setState(() {
                                      _kinuhaKoPlaced = true;
                                      _checkCompletion();
                                    }),
                                  ),
                                ),
                                Positioned(
                                  left: (step * 2) + (pieceWidth * 0.03),
                                  top: 0,
                                  child: _buildDragTarget(
                                    id: 'LARUAN_MO',
                                    isPlaced: _laruanMoPlaced,
                                    placeholderAsset:
                                        'assets/images/objects/lumi/laruanmo_placeholder.png',
                                    placedAsset:
                                        'assets/images/objects/lumi/laruanmo_rp.png',
                                    width: pieceWidth,
                                    height: pieceHeight,
                                    onAccept: () => setState(() {
                                      _laruanMoPlaced = true;
                                      _checkCompletion();
                                    }),
                                  ),
                                ),
                                Positioned(
                                  left: step,
                                  top: 0,
                                  child: _buildDragTarget(
                                    id: 'ANG',
                                    isPlaced: _angPlaced,
                                    placeholderAsset:
                                        'assets/images/objects/lumi/ang_placeholder.png',
                                    placedAsset:
                                        'assets/images/objects/lumi/ang_rp.png',
                                    width: pieceWidth,
                                    height: pieceHeight,
                                    onAccept: () => setState(() {
                                      _angPlaced = true;
                                      _checkCompletion();
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ====================================================
                        // ROW 2 (BOTTOM): "HINDI KO NA UULITIN"
                        // ====================================================
                        Positioned(
                          top: row2TopOffset,
                          left: 0,
                          right: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 450),
                            opacity: _currentPhase == 2 ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: _currentPhase == 1,
                              child: SizedBox(
                                width: totalWidth,
                                height: pieceHeight,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Row 2 Left: "HINDI" (Grows inward to the right)
                                    Positioned(
                                      left: 0 - (pieceWidth * 0.025),
                                      top: -1,
                                      child: _buildDragTarget(
                                        id: 'HINDI',
                                        isPlaced: _hindiPlaced,
                                        placeholderAsset:
                                            'assets/images/objects/lumi/hindi_placeholder.png',
                                        placedAsset:
                                            'assets/images/objects/lumi/hindi_rp.png',
                                        width: row2PieceWidth,
                                        height: pieceHeight,
                                        onAccept: () => setState(() {
                                          _hindiPlaced = true;
                                          _checkCompletion();
                                        }),
                                      ),
                                    ),

                                    // Row 2 Right: "UULITIN" (Grows inward to the left)
                                    Positioned(
                                      left:
                                          ((step * 2) + (pieceWidth * 0.015)) -
                                          row2WidthExpansion,
                                      top: 0,
                                      child: _buildDragTarget(
                                        id: 'UULITIN',
                                        isPlaced: _uulitinPlaced,
                                        placeholderAsset:
                                            'assets/images/objects/lumi/uulitin_placeholder.png',
                                        placedAsset:
                                            'assets/images/objects/lumi/uulitin_rp.png',
                                        width: row2PieceWidth,
                                        height: pieceHeight,
                                        onAccept: () => setState(() {
                                          _uulitinPlaced = true;
                                          _checkCompletion();
                                        }),
                                      ),
                                    ),

                                    // Row 2 Middle: "KO NA" (Grows evenly from the center)
                                    Positioned(
                                      left: step - (row2WidthExpansion / 2),
                                      top: 0,
                                      child: _buildDragTarget(
                                        id: 'KO_NA',
                                        isPlaced: _koNaPlaced,
                                        placeholderAsset:
                                            'assets/images/objects/lumi/kona_placeholder.png',
                                        placedAsset:
                                            'assets/images/objects/lumi/kona_rp.png',
                                        width: row2PieceWidth,
                                        height: pieceHeight,
                                        onAccept: () => setState(() {
                                          _koNaPlaced = true;
                                          _checkCompletion();
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Bottom Area: Draggable Puzzle Pieces
          Positioned(
            bottom: sh * 0.05,
            left: 0,
            right: 0,
            child: Center(
              child: _currentPhase == 1
                  // --- PHASE 1 BOTTOM ROW ---
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDraggablePiece(
                          id: 'LARUAN_MO',
                          isPlaced: _laruanMoPlaced,
                          assetPath:
                              'assets/images/objects/lumi/laruanmo_rp.png',
                          width: pieceWidth,
                          height: pieceHeight,
                        ),
                        SizedBox(width: pieceWidth * 0.15),
                        _buildDraggablePiece(
                          id: 'KINUHA_KO',
                          isPlaced: _kinuhaKoPlaced,
                          assetPath:
                              'assets/images/objects/lumi/kinuhako_rp.png',
                          width: pieceWidth,
                          height: pieceHeight,
                        ),
                        SizedBox(width: pieceWidth * 0.15),
                        _buildDraggablePiece(
                          id: 'ANG',
                          isPlaced: _angPlaced,
                          assetPath: 'assets/images/objects/lumi/ang_rp.png',
                          width: pieceWidth,
                          height: pieceHeight,
                        ),
                        SizedBox(width: pieceWidth * 0.15),
                        _buildDraggablePiece(
                          id: 'PANGIT_KA',
                          isPlaced: false,
                          assetPath:
                              'assets/images/objects/lumi/pangitka_wp.png',
                          width: pieceWidth,
                          height: pieceHeight,
                        ),
                      ],
                    )
                  // --- PHASE 2 BOTTOM ROW ---
                  : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDraggablePiece(
                              id: 'KO_NA',
                              isPlaced: _koNaPlaced,
                              assetPath:
                                  'assets/images/objects/lumi/kona_rp.png',
                              width: row2PieceWidth,
                              height: pieceHeight,
                            ),
                            SizedBox(
                              width: pieceWidth * 0.10,
                            ), // Slightly smaller gap so wider pieces fit on screen!
                            _buildDraggablePiece(
                              id: 'IBABALIK',
                              isPlaced: false,
                              assetPath:
                                  'assets/images/objects/lumi/ibabalik_wp.png',
                              width: row2PieceWidth,
                              height: pieceHeight,
                            ),
                            SizedBox(width: pieceWidth * 0.10),
                            _buildDraggablePiece(
                              id: 'UULITIN',
                              isPlaced: _uulitinPlaced,
                              assetPath:
                                  'assets/images/objects/lumi/uulitin_rp.png',
                              width: row2PieceWidth,
                              height: pieceHeight,
                            ),
                            SizedBox(width: pieceWidth * 0.10),
                            _buildDraggablePiece(
                              id: 'HINDI',
                              isPlaced: _hindiPlaced,
                              assetPath:
                                  'assets/images/objects/lumi/hindi_rp.png',
                              width: row2PieceWidth,
                              height: pieceHeight,
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 450))
                        .slideY(begin: 0.3, end: 0.0),
            ),
          ),

          // 4. Close Button (Top Left)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Image.asset(
                    'assets/images/buttons/x_blue.png',
                    width: 50,
                    height: 50,
                    errorBuilder: (ctx, err, st) => Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF266589),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DRAG & DROP HELPER WIDGETS
  // ============================================================================

  Widget _buildDragTarget({
    required String id,
    required bool isPlaced,
    required String placeholderAsset,
    required String placedAsset,
    required double width,
    required double height,
    required VoidCallback onAccept,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data == id && !isPlaced,
      onAcceptWithDetails: (details) {
        onAccept();
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Image.asset(
            isPlaced ? placedAsset : placeholderAsset,
            fit: BoxFit.fill,
            errorBuilder: (ctx, err, st) => Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isPlaced
                    ? Colors.orange
                    : Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  isPlaced ? id : '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggablePiece({
    required String id,
    required bool isPlaced,
    required String assetPath,
    required double width,
    required double height,
  }) {
    if (isPlaced) {
      return SizedBox(width: width, height: height);
    }

    final Widget pieceImage = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.fill,
      errorBuilder: (ctx, err, st) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: (id == 'PANGIT_KA' || id == 'IBABALIK')
              ? Colors.redAccent
              : Colors.blueAccent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            id.replaceAll('_', ' '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );

    if (!_canDrag) {
      return Opacity(opacity: 0.65, child: pieceImage);
    }

    return Draggable<String>(
      data: id,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.10, child: pieceImage),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: pieceImage),
      child: pieceImage
          .animate(target: _canDrag ? 1 : 0)
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
          ),
    );
  }
}
