import 'dart:async';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_6.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Sorry5Screen extends StatefulWidget {
  const Sorry5Screen({super.key});

  @override
  State<Sorry5Screen> createState() => _Sorry5ScreenState();
}

class _Sorry5ScreenState extends State<Sorry5Screen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- Interaction State ---
  // Pieces remain locked until sorry_5.wav finishes playing!
  bool _canDrag = false;

  // --- Puzzle Placement State ---
  bool _imPlaced = false;
  bool _sorryPlaced = false;
  bool _littleBearPlaced = false;

  @override
  void initState() {
    super.initState();
    _setupLandscapeOrientation();

    // Start audio and unlock puzzle pieces when it completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startIntroAudio();
    });
  }

  void _setupLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Plays sorry_5.wav and unlocks dragging once the narration finishes
  Future<void> _startIntroAudio() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_5.wav'),
      );

      // Wait for the audio to completely finish playing
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // Unlock the puzzle pieces so the user can now drag them!
      setState(() {
        _canDrag = true;
      });
    } catch (e) {
      debugPrint('Error playing sorry_5.wav: $e');
      // Fallback: If audio fails to load, unlock immediately so the child isn't stuck
      if (mounted) setState(() => _canDrag = true);
    }
  }

  /// Checks if all 3 pieces are in place and triggers the victory sequence
  void _checkCompletion() {
    if (_imPlaced && _sorryPlaced && _littleBearPlaced) {
      debugPrint('Puzzle Complete!');
      _playVictorySequence();
    }
  }

  Future<void> _playVictorySequence() async {
    try {
      // 1. Stop any background narration that might still be playing
      await _audioPlayer.stop();

      // 2. Play the shine sound effect and wait for it to finish!
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // 3. Play sorry_6.wav right after the shine sound finishes
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_6.wav'),
      );
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // 4. Navigate smoothly to the classroom scene!
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Sorry6Screen()),
      );
    } catch (e) {
      debugPrint('Error in victory sequence: $e');
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

    // Piece size scaling (Roughly 18% of screen width so all 3 fit nicely)
    final double pieceWidth = sw * 0.18;
    final double pieceHeight =
        pieceWidth; // Square aspect ratio for puzzle boxes

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image
          Image.asset(
            'assets/images/backgrounds/bg_lumi_puzzle.jpg',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => Container(
              // Fallback split color matching the mockup image_e757db.png
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFBE4C3), // Upper tan area
                    Color(0xFFFBE4C3),
                    Color(0xFFECA352), // Lower orange table area
                    Color(0xFFECA352),
                  ],
                  stops: [0.0, 0.60, 0.60, 1.0],
                ),
              ),
            ),
          ),

          // 2. Top Area: Target Placeholders (Where pieces are dropped)
          //
          // NOTE: Instead of manually offsetting each piece by a different
          // guessed amount (which is fragile and hard to keep in sync),
          // all 3 pieces share ONE `overlapAmount`. Each piece is placed at
          // `index * (pieceWidth - overlapAmount)`, guaranteeing identical
          // spacing/connection between every pair, regardless of how many
          // pieces there are. Tune `overlapAmount` below to match how much
          // of the tab/notch on your PNGs should visually interlock.
          Positioned(
            top: sh * 0.15,
            left: 0,
            right: 0,
            child: Builder(
              builder: (context) {
                // How much each piece overlaps the next (in px).
                // Increase this if there's still a visible gap between
                // pieces; decrease it if they overlap too much.
                final double overlapAmount = pieceWidth * 0.26;
                final double step = pieceWidth - overlapAmount;
                final double totalWidth = pieceWidth + step * 2;

                return Center(
                  child: SizedBox(
                    width: totalWidth,
                    height: pieceHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Slot 1: "I'M"
                        Positioned(
                          left: 0,
                          top: 0,
                          child: _buildDragTarget(
                            id: 'IM',
                            isPlaced: _imPlaced,
                            placeholderAsset:
                                'assets/images/objects/lumi/im_placeholder.png',
                            placedAsset: 'assets/images/objects/lumi/im_rp.png',
                            width: pieceWidth,
                            height: pieceHeight,
                            onAccept: () => setState(() {
                              _imPlaced = true;
                              _checkCompletion();
                            }),
                          ),
                        ),

                        // Slot 2: "SORRY"
                        Positioned(
                          left: step,
                          top: 0,
                          child: _buildDragTarget(
                            id: 'SORRY',
                            isPlaced: _sorryPlaced,
                            placeholderAsset:
                                'assets/images/objects/lumi/sorry_placeholder.png',
                            placedAsset:
                                'assets/images/objects/lumi/sorry_rp.png',
                            width: pieceWidth,
                            height: pieceHeight,
                            onAccept: () => setState(() {
                              _sorryPlaced = true;
                              _checkCompletion();
                            }),
                          ),
                        ),

                        // Slot 3: "LITTLE BEAR"
                        Positioned(
                          // CHANGED: We subtract an extra offset (pieceWidth * 0.08)
                          // to pull this end piece further left so its socket slides over Slot 2's tab!
                          left: (step * 2) - (pieceWidth * 0.05),
                          top: 0,
                          child: _buildDragTarget(
                            id: 'LITTLE_BEAR',
                            isPlaced: _littleBearPlaced,
                            placeholderAsset:
                                'assets/images/objects/lumi/littlebear_placeholder.png',
                            placedAsset:
                                'assets/images/objects/lumi/littlebear_rp.png',
                            width: pieceWidth,
                            height: pieceHeight,
                            onAccept: () => setState(() {
                              _littleBearPlaced = true;
                              _checkCompletion();
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 3. Bottom Area: Draggable Puzzle Pieces (Source)
          //
          // Previously this used `spaceEvenly` across the *entire* width
          // between left/right insets, which spreads pieces apart based on
          // total available screen width — on a wide screen that pushes
          // the 3rd piece way out toward the edge instead of keeping the
          // trio clustered together in the middle like the mockup.
          //
          // Fix: center a fixed-size cluster with a small, explicit gap
          // between pieces, so spacing stays tight and consistent
          // regardless of screen width.
          Positioned(
            bottom: sh * 0.08,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Piece 1: "I'M"
                  _buildDraggablePiece(
                    id: 'IM',
                    isPlaced: _imPlaced,
                    assetPath: 'assets/images/objects/lumi/im_rp.png',
                    width: pieceWidth,
                    height: pieceHeight,
                  ),

                  SizedBox(width: pieceWidth * 0.35),

                  // Piece 2: "SORRY"
                  _buildDraggablePiece(
                    id: 'SORRY',
                    isPlaced: _sorryPlaced,
                    assetPath: 'assets/images/objects/lumi/sorry_rp.png',
                    width: pieceWidth,
                    height: pieceHeight,
                  ),

                  SizedBox(width: pieceWidth * 0.35),

                  // Piece 3: "LITTLE BEAR"
                  _buildDraggablePiece(
                    id: 'LITTLE_BEAR',
                    isPlaced: _littleBearPlaced,
                    assetPath: 'assets/images/objects/lumi/littlebear_rp.png',
                    width: pieceWidth,
                    height: pieceHeight,
                  ),
                ],
              ),
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

  /// Builds a drop target slot for a specific puzzle piece
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
      // Only accept the piece if its ID matches this target slot!
      onWillAcceptWithDetails: (details) => details.data == id && !isPlaced,
      onAcceptWithDetails: (details) {
        // Play a snap sound if you have one!
        // _audioPlayer.play(AssetSource('audio/lumi_town/level9/snap.wav'));
        onAccept();
      },
      builder: (context, candidateData, rejectedData) {
        // If the piece is hovering over the correct target, give it a slight brightness boost
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
            fit: BoxFit.contain,
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

  /// Builds a draggable puzzle piece sitting in the bottom row
  Widget _buildDraggablePiece({
    required String id,
    required bool isPlaced,
    required String assetPath,
    required double width,
    required double height,
  }) {
    // If the piece is already placed in the top slot, hide it from the bottom row!
    if (isPlaced) {
      return SizedBox(width: width, height: height);
    }

    final Widget pieceImage = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, st) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            id,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

    // If dragging is disabled while audio plays, wrap in an IgnorePointer
    if (!_canDrag) {
      return Opacity(
        opacity: 0.65, // Slightly dimmed to show it is not interactable yet
        child: pieceImage,
      );
    }

    return Draggable<String>(
      data: id,
      // What the user sees under their finger while dragging:
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.10, // Make it pop slightly larger while dragging
          child: pieceImage,
        ),
      ),
      // What remains in the bottom row while the piece is being dragged:
      childWhenDragging: Opacity(opacity: 0.25, child: pieceImage),
      // The normal interactive piece:
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
