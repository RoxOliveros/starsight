import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_buttons.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart'; // Added GoodJobOverlay
import 'package:StarSight/business_layer/town_progress_service.dart'; // Added for progression

class FamilyTreeGame extends StatefulWidget {
  const FamilyTreeGame({Key? key}) : super(key: key);

  @override
  State<FamilyTreeGame> createState() => _FamilyTreeGameState();
}

class _FamilyTreeGameState extends State<FamilyTreeGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _handAnimCtrl;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- GAME STATE ---
  int _gamePhase = 0; // 0 = Bear only, 1 = Bear + Sample Tree, 2 = Puzzle Table
  bool _showHand = true;
  int _currentStage = 1; // 1 = First 3 pics, 2 = Last 4 pics
  bool _isGameWon = false; // Tracks if everything is completely done

  // Stage 1 Placements
  bool isGrandpaPlaced = false;
  bool isMotherPlaced = false;
  bool isLittleBearPlaced = false;

  // Stage 2 Placements
  bool isGrandmaPlaced = false;
  bool isFatherPlaced = false;
  bool isSisterPlaced = false;
  bool isBrotherPlaced = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Setup the Hand Tapping Animation
    _handAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // Audio Listener: Waits for the intro audio to finish completely!
    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;

      // If the intro audio finishes, move to Phase 2 (The Puzzle Table)
      if (_gamePhase < 2) {
        setState(() {
          _gamePhase = 2;
        });

        // Now that the puzzle has started, start the 4-second hand timer
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showHand = false;
            });
          }
        });
      }
    });

    // PLAY THE NEW INTRO AUDIO IMMEDIATELY
    _playAudio('audio/lumi_town/level13/family_tree_game_intro.wav');

    // INTRO SEQUENCE TIMER
    // Wait exactly 6 seconds into the audio, then pop up the sample tree drawing
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _gamePhase == 0) {
        setState(() {
          _gamePhase = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _handAnimCtrl.dispose();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _playShineSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint("Error playing audio ($path): $e");
    }
  }

  void _checkWinCondition() {
    // Check if Stage 1 is complete
    if (_currentStage == 1 &&
        isGrandpaPlaced &&
        isMotherPlaced &&
        isLittleBearPlaced) {
      setState(() {
        _currentStage = 2; // Advance to Stage 2 to show the next 4 pictures!
      });
    }
    // Check if Stage 2 (Entire Tree) is complete
    else if (_currentStage == 2 &&
        isGrandmaPlaced &&
        isFatherPlaced &&
        isSisterPlaced &&
        isBrotherPlaced) {
      debugPrint("Family Tree Fully Complete!");
      setState(() {
        _isGameWon = true; // Trigger the success overlay!
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. FULL SCREEN Background (Switches based on _gamePhase)
          Image.asset(
            _gamePhase < 2
                ? 'assets/images/backgrounds/bg_classroom_closeup.png'
                : 'assets/images/backgrounds/bg_table.png',
            fit: BoxFit.cover,
          ),

          // 2. THE 16:9 LOCKED GAME CANVAS
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sw = constraints.maxWidth;
                  final sh = constraints.maxHeight;

                  // ==========================================
                  // 🛠️ INTRO SCENE ADJUSTERS (Phase 0 & 1)
                  // ==========================================
                  final double introBearWidth = 0.35;
                  final double introBearX = 0.325; // Centered
                  final double introBearBottom = -0.15;

                  final double introTreeWidth = 0.28;
                  final double introTreeX = 0.03; // Left side
                  final double introTreeBottom = 0.10;

                  // ==========================================
                  // 🛠️ PUZZLE TABLE ADJUSTERS (Phase 2)
                  // ==========================================

                  // --- MAIN TREE ---
                  final double treeWidth = 0.50;
                  final double treeX = 0.25;
                  final double treeY = 0.00;

                  // --- 7 CIRCLE HITBOXES ON THE TREE ---
                  final double holderWidth = 0.09;

                  final double h1X = 0.38; // Top Left (GRANDPA)
                  final double h1Y = 0.18;

                  final double h2X = 0.51; // Top Right (GRANDMA)
                  final double h2Y = 0.18;

                  final double h3X = 0.34; // Middle Left (FATHER)
                  final double h3Y = 0.35;

                  final double h4X = 0.56; // Middle Right (MOTHER)
                  final double h4Y = 0.35;

                  final double h5X = 0.35; // Bottom Left (SISTER)
                  final double h5Y = 0.55;

                  final double h6X = 0.45; // Bottom Center (LITTLE BEAR)
                  final double h6Y = 0.50;

                  final double h7X = 0.55; // Bottom Right (BROTHER)
                  final double h7Y = 0.55;

                  // --- POINTING HAND ---
                  final double handWidth = 0.08;
                  final double handX = 0.43;
                  final double handY = 0.08;
                  final double handAngle = math.pi * 1.2;
                  final double handBounceX = -10.0;
                  final double handBounceY = 10.0;

                  // --- STAGE 1 TORN PICTURES ---
                  final double grandpaPicWidth = 0.20;
                  final double grandpaPicX = 0.78;
                  final double grandpaPicY = 0.20;

                  final double motherPicWidth = 0.20;
                  final double motherPicX = 0.03;
                  final double motherPicY = 0.20;

                  final double littleBearPicWidth = 0.20;
                  final double littleBearPicX = 0.05;
                  final double littleBearPicY = 0.60;

                  // --- STAGE 2 TORN PICTURES ---
                  final double grandmaPicWidth = 0.20;
                  final double grandmaPicX = 0.03;
                  final double grandmaPicY = 0.20;

                  final double daddyPicWidth = 0.20;
                  final double daddyPicX = 0.78;
                  final double daddyPicY = 0.20;

                  final double sisterPicWidth = 0.20;
                  final double sisterPicX = 0.05;
                  final double sisterPicY = 0.60;

                  final double brotherPicWidth = 0.20;
                  final double brotherPicX = 0.78;
                  final double brotherPicY = 0.60;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // ==========================================
                      // INTRO SCENES (Phase 0 and 1)
                      // ==========================================
                      if (_gamePhase < 2) ...[
                        // Little Bear (Always visible in intro)
                        Positioned(
                          left: sw * introBearX,
                          bottom: sh * introBearBottom,
                          child: Image.asset(
                            'assets/images/characters/little_bear_uniform.png',
                            width: sw * introBearWidth,
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Sample Tree (Appears in Phase 1)
                        if (_gamePhase == 1)
                          Positioned(
                            left: sw * introTreeX,
                            bottom: sh * introTreeBottom,
                            child: Image.asset(
                              'assets/images/objects/lumi/familytree_sample.png',
                              width: sw * introTreeWidth,
                              fit: BoxFit.contain,
                            ),
                          ),
                      ]
                      // ==========================================
                      // PUZZLE TABLE SCENE (Phase 2)
                      // ==========================================
                      else ...[
                        // The Tree Base
                        Positioned(
                          top: sh * treeY,
                          left: sw * treeX,
                          child: Image.asset(
                            'assets/images/objects/lumi/familytree.png',
                            width: sw * treeWidth,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // THE 7 CIRCLES (Targets)
                        // h1: Top Left (GRANDPA)
                        Positioned(
                          top: sh * h1Y,
                          left: sw * h1X,
                          child: _buildCircleTarget(
                            expectedId: 'grandpa',
                            isPlaced: isGrandpaPlaced,
                            placedAssetPath:
                                'assets/images/objects/lumi/grandpa_pfp.png',
                            width: sw * holderWidth,
                            onPlaced: () {
                              setState(() => isGrandpaPlaced = true);
                              _checkWinCondition();
                            },
                          ),
                        ),

                        // h2: Top Right (GRANDMA)
                        Positioned(
                          top: sh * h2Y,
                          left: sw * h2X,
                          child: _buildCircleTarget(
                            expectedId: 'grandma',
                            isPlaced: isGrandmaPlaced,
                            placedAssetPath:
                                'assets/images/objects/lumi/grandma_pfp.png',
                            width: sw * holderWidth,
                            onPlaced: () {
                              setState(() => isGrandmaPlaced = true);
                              _checkWinCondition();
                            },
                          ),
                        ),

                        // h3: Middle Left (FATHER)
                        Positioned(
                          top: sh * h3Y,
                          left: sw * h3X,
                          child: _buildCircleTarget(
                            expectedId: 'father',
                            isPlaced: isFatherPlaced,
                            placedAssetPath:
                                'assets/images/objects/lumi/father_pfp.png',
                            width: sw * holderWidth,
                            onPlaced: () {
                              setState(() => isFatherPlaced = true);
                              _checkWinCondition();
                            },
                          ),
                        ),

                        // h4: Middle Right (MOTHER)
                        Positioned(
                          top: sh * h4Y,
                          left: sw * h4X,
                          child: _buildCircleTarget(
                            expectedId: 'mother',
                            isPlaced: isMotherPlaced,
                            placedAssetPath:
                                'assets/images/objects/lumi/mother_pfp.png',
                            width: sw * holderWidth,
                            onPlaced: () {
                              setState(() => isMotherPlaced = true);
                              _checkWinCondition();
                            },
                          ),
                        ),

                        // h5: Bottom Left (SISTER)
                        Positioned(
                          top: sh * h5Y,
                          left: sw * h5X,
                          child: _buildCircleTarget(
                            expectedId: 'sister',
                            isPlaced: isSisterPlaced,
                            placedAssetPath:
                                'assets/images/objects/lumi/sister_pfp.png',
                            width: sw * holderWidth,
                            onPlaced: () {
                              setState(() => isSisterPlaced = true);
                              _checkWinCondition();
                            },
                          ),
                        ),

                        // h6: Bottom Center (LITTLE BEAR)
                        Positioned(
                          top: sh * h6Y,
                          left: sw * h6X,
                          child: _buildCircleTarget(
                            expectedId: 'little_bear',
                            isPlaced: isLittleBearPlaced,
                            placedAssetPath:
                                'assets/images/objects/lumi/littllebear_pfp.png',
                            width: sw * holderWidth,
                            onPlaced: () {
                              setState(() => isLittleBearPlaced = true);
                              _checkWinCondition();
                            },
                          ),
                        ),

                        // h7: Bottom Right (BROTHER)
                        Positioned(
                          top: sh * h7Y,
                          left: sw * h7X,
                          child: _buildCircleTarget(
                            expectedId: 'brother',
                            isPlaced: isBrotherPlaced,
                            placedAssetPath:
                                'assets/images/objects/lumi/brother_pfp.png',
                            width: sw * holderWidth,
                            onPlaced: () {
                              setState(() => isBrotherPlaced = true);
                              _checkWinCondition();
                            },
                          ),
                        ),

                        // THE POINTING HAND
                        if (_showHand)
                          Positioned(
                            top: sh * handY,
                            left: sw * handX,
                            child: AnimatedBuilder(
                              animation: _handAnimCtrl,
                              builder: (context, child) {
                                final double curve = Curves.easeInOut.transform(
                                  _handAnimCtrl.value,
                                );
                                return Transform.translate(
                                  offset: Offset(
                                    curve * handBounceX,
                                    curve * handBounceY,
                                  ),
                                  child: child,
                                );
                              },
                              child: Transform.rotate(
                                angle: handAngle,
                                child: Image.asset(
                                  'assets/images/objects/lumi/pointing_hand.png',
                                  width: sw * handWidth,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                        // DRAGGABLE PICTURES (STAGE 1)
                        if (_currentStage == 1) ...[
                          // Grandpa Bear
                          Positioned(
                            top: sh * grandpaPicY,
                            left: sw * grandpaPicX,
                            child: _buildDraggablePic(
                              id: 'grandpa',
                              assetPath:
                                  'assets/images/objects/lumi/grandpa_bear_pic.png',
                              width: sw * grandpaPicWidth,
                              isPlaced: isGrandpaPlaced,
                            ),
                          ),
                          // Mother Bear
                          Positioned(
                            top: sh * motherPicY,
                            left: sw * motherPicX,
                            child: _buildDraggablePic(
                              id: 'mother',
                              assetPath:
                                  'assets/images/objects/lumi/mother_bear_pic.png',
                              width: sw * motherPicWidth,
                              isPlaced: isMotherPlaced,
                            ),
                          ),
                          // Little Bear
                          Positioned(
                            top: sh * littleBearPicY,
                            left: sw * littleBearPicX,
                            child: _buildDraggablePic(
                              id: 'little_bear',
                              assetPath:
                                  'assets/images/objects/lumi/little_bear_pic.png',
                              width: sw * littleBearPicWidth,
                              isPlaced: isLittleBearPlaced,
                            ),
                          ),
                        ],

                        // DRAGGABLE PICTURES (STAGE 2)
                        if (_currentStage == 2) ...[
                          // Grandma Bear
                          Positioned(
                            top: sh * grandmaPicY,
                            left: sw * grandmaPicX,
                            child: _buildDraggablePic(
                              id: 'grandma',
                              assetPath:
                                  'assets/images/objects/lumi/grandma_bear_pic.png',
                              width: sw * grandmaPicWidth,
                              isPlaced: isGrandmaPlaced,
                            ),
                          ),
                          // Daddy Bear
                          Positioned(
                            top: sh * daddyPicY,
                            left: sw * daddyPicX,
                            child: _buildDraggablePic(
                              id: 'father',
                              assetPath:
                                  'assets/images/objects/lumi/daddy_bear_pic.png',
                              width: sw * daddyPicWidth,
                              isPlaced: isFatherPlaced,
                            ),
                          ),
                          // Sister Bear
                          Positioned(
                            top: sh * sisterPicY,
                            left: sw * sisterPicX,
                            child: _buildDraggablePic(
                              id: 'sister',
                              assetPath:
                                  'assets/images/objects/lumi/sister_bear_pic.png',
                              width: sw * sisterPicWidth,
                              isPlaced: isSisterPlaced,
                            ),
                          ),
                          // Brother Bear
                          Positioned(
                            top: sh * brotherPicY,
                            left: sw * brotherPicX,
                            child: _buildDraggablePic(
                              id: 'brother',
                              assetPath:
                                  'assets/images/objects/lumi/brother_bear_pic.png',
                              width: sw * brotherPicWidth,
                              isPlaced: isBrotherPlaced,
                            ),
                          ),
                        ],
                      ], // End of Puzzle Table Scene
                    ],
                  );
                },
              ),
            ),
          ),

          // Universal Back Button
          const Positioned(top: 25, left: 20, child: LumiBackButton()),

          // SUCCESS OVERLAY (Shows when all pieces are placed)
          if (_isGameWon)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/dr.woo_smiling.png',
                
                onNext: () async {
                  // Mark complete via progress service for Level 13
                  await TownProgressService.instance.markLevelComplete(13);
                  // TODO: Navigate to the next level
                  print("Proceed to next level!");
                },
                onRestart: () {
                  setState(() {
                    // Completely restart the entire sequence!
                    _gamePhase = 0;
                    _showHand = true;
                    _currentStage = 1;
                    _isGameWon = false;

                    isGrandpaPlaced = false;
                    isMotherPlaced = false;
                    isLittleBearPlaced = false;
                    isGrandmaPlaced = false;
                    isFatherPlaced = false;
                    isSisterPlaced = false;
                    isBrotherPlaced = false;

                    _handAnimCtrl.reset();
                    _handAnimCtrl.repeat(reverse: true);
                    _playAudio(
                      'audio/lumi_town/level13/family_tree_game_intro.wav',
                    );

                    // Restart the Intro Timeline
                    Future.delayed(const Duration(seconds: 6), () {
                      if (mounted && _gamePhase == 0) {
                        setState(() {
                          _gamePhase = 1;
                        });
                      }
                    });
                  });
                },
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }

  // --- HELPER: Builds the invisible hitboxes over the tree ---
  Widget _buildCircleTarget({
    required String expectedId,
    required bool isPlaced,
    required String placedAssetPath,
    required double width,
    required VoidCallback onPlaced,
  }) {
    return DragTarget<String>(
      builder: (context, candidateData, rejectedData) {
        return Image.asset(
          isPlaced
              ? placedAssetPath
              : 'assets/images/objects/lumi/picture_holder.png',
          width: width,
          fit: BoxFit.contain,
        );
      },
      onWillAcceptWithDetails: (details) =>
          details.data == expectedId && !isPlaced,
      onAcceptWithDetails: (details) {
        _playShineSound(); // Plays the success sound!
        onPlaced();
      },
    );
  }

  // --- HELPER: Builds the draggable torn polaroids ---
  Widget _buildDraggablePic({
    required String id,
    required String assetPath,
    required double width,
    required bool isPlaced,
  }) {
    if (isPlaced)
      return const SizedBox.shrink(); // Hide the polaroid once placed

    return Draggable<String>(
      data: id,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(assetPath, width: width * 1.1, fit: BoxFit.contain),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Image.asset(assetPath, width: width, fit: BoxFit.contain),
      ),
      child: Image.asset(assetPath, width: width, fit: BoxFit.contain),
    );
  }
}
