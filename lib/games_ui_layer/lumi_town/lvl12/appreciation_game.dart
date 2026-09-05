import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl13/family_tree_game.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart'; // Added GoodJobOverlay

class AppreciationGame extends StatefulWidget {
  const AppreciationGame({Key? key}) : super(key: key);

  @override
  State<AppreciationGame> createState() => _AppreciationGameState();
}

// Upgraded to TickerProviderStateMixin to support multiple animations!
class _AppreciationGameState extends State<AppreciationGame>
    with TickerProviderStateMixin {
  // ==========================================
  // 🛠️ PUZZLE 1 ADJUSTERS (Screen Percentages 0.0 to 1.0)
  // ==========================================

  // --- INTRO SCENE ADJUSTERS ---
  final double littleBearWidth = 0.30;
  final double littleBearX = 0.20;
  final double littleBearBottom = 0.02;

  final double domaWidth = 0.20;
  final double domaTargetX = 0.45;
  final double domaBottom = 0.10;
  final double walkBounceHeight = 20.0;

  // --- TOP PLACEHOLDERS (The gray targets) ---
  final double place1Width = 0.124;
  final double place1X = 0.32;
  final double place1Y = 0.19;

  final double place2Width = 0.20;
  final double place2X = 0.40;
  final double place2Y = 0.20;

  final double place3Width = 0.12;
  final double place3X = 0.56;
  final double place3Y = 0.20;

  // --- BOTTOM DRAGGABLE PIECES ---
  final double drag1Width = 0.20;
  final double drag1X = 0.10;
  final double drag1Y = 0.65;

  final double drag2Width = 0.12;
  final double drag2X = 0.35;
  final double drag2Y = 0.65;

  final double drag3Width = 0.124;
  final double drag3X = 0.55;
  final double drag3Y = 0.65;

  final double drag4Width = 0.12;
  final double drag4X = 0.75;
  final double drag4Y = 0.65;

  // ==========================================
  // 🧩 PUZZLE 2 ADJUSTERS (Dahil Tinulungan Mo Ako)
  // ==========================================

  // --- TOP PLACEHOLDERS ---
  final double p2Place1Width = 0.13;
  final double p2Place1X = 0.35;
  final double p2Place1Y = 0.18;

  final double p2Place2Width = 0.12;
  final double p2Place2X = 0.45;
  final double p2Place2Y = 0.12;

  final double p2Place3Width = 0.14;
  final double p2Place3X = 0.535;
  final double p2Place3Y = 0.17;

  // --- BOTTOM DRAGGABLE PIECES ---
  final double p2Drag1Width = 0.13;
  final double p2Drag1X = 0.15;
  final double p2Drag1Y = 0.70;

  final double p2Drag2Width = 0.12;
  final double p2Drag2X = 0.35;
  final double p2Drag2Y = 0.65;

  final double p2Drag3Width = 0.13;
  final double p2Drag3X = 0.55;
  final double p2Drag3Y = 0.70;

  final double p2Drag4Width = 0.12;
  final double p2Drag4X = 0.75;
  final double p2Drag4Y = 0.65;

  // ==========================================
  // 🧩 PUZZLE 3 ADJUSTERS (Walang Anuman Iyon)
  // ==========================================

  // --- TOP PLACEHOLDERS ---
  // Placeholder 1 (Left - Walang)
  final double p3Place1Width = 0.128;
  final double p3Place1X = 0.34;
  final double p3Place1Y = 0.19;

  // Placeholder 2 (Middle - Anuman)
  final double p3Place2Width = 0.128;
  final double p3Place2X = 0.44;
  final double p3Place2Y = 0.19;

  // Placeholder 3 (Right - Iyon)
  final double p3Place3Width = 0.11;
  final double p3Place3X = 0.54;
  final double p3Place3Y = 0.19;

  // --- BOTTOM DRAGGABLE PIECES ---
  // Draggable 1 (Blue Iyon)
  final double p3Drag1Width = 0.11;
  final double p3Drag1X = 0.15;
  final double p3Drag1Y = 0.65;

  // Draggable 2 (Orange Anuman)
  final double p3Drag2Width = 0.13;
  final double p3Drag2X = 0.35;
  final double p3Drag2Y = 0.65;

  // Draggable 3 (Yellow Walang)
  final double p3Drag3Width = 0.13;
  final double p3Drag3X = 0.55;
  final double p3Drag3Y = 0.65;

  // Draggable 4 (Orange Kwenta - Distractor)
  final double p3Drag4Width = 0.20;
  final double p3Drag4X = 0.70;
  final double p3Drag4Y = 0.63;

  // ==========================================
  // 🎉 END SCENE ADJUSTERS (Scene 3 & 4)
  // ==========================================
  // Little Bear (Used in both scenes)
  final double endBearWidth = 0.25;
  final double endBearX = 0.26;
  final double endBearBottom = -0.15;

  // Scene 3: Doma Neutral
  final double endDomaWidth = 0.25;
  final double endDomaX = 0.53;
  final double endDomaBottom = -0.15;

  // Scene 4: Doma Smiling
  final double smilingDomaWidth = 0.35;
  final double smilingDomaX = 0.50;
  final double smilingDomaBottom = -0.10;
  final double finalJumpHeight = 30.0; // How high they jump at the end

  // ==========================================
  // 🦉 DR. WOO ENDING ADJUSTERS (Scene 5)
  // ==========================================
  final double drWooHeightPercentage = 0.85;
  final double darkOverlayOpacity = 0.7;
  final double drWooVerticalOffset = 60.00;

  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _walkCtrl;
  late final AnimationController _jumpCtrl; // New controller for jumping

  // --- GAME STATE ---
  // Temporarily set to 2 & 3 so you can test Puzzle 3 immediately!
  // Change back to 0 & 1 when you are ready to play from the beginning.
  int _introStep =
      0; // 0=Walk In, 1=Tutorial, 2=Puzzles, 3=Audio 1, 4=Audio 2 & Jump, 5=Dr. Woo
  int _currentPuzzle = 1; // Tracks which puzzle we are on (1, 2, or 3)
  bool _isGameWon = false; // Tracks if everything is completely done
  bool _isJumping = false; // Tracks if characters should be bouncing

  // Puzzle 1 State
  bool isMaramingPlaced = false;
  bool isSalamatPlaced = false;
  bool isDomaPlaced = false;

  // Puzzle 2 State
  bool isDahilPlaced = false;
  bool isTinulunganPlaced = false;
  bool isMoAkoPlaced = false;

  // Puzzle 3 State
  bool isWalangPlaced = false;
  bool isAnumanPlaced = false;
  bool isIyonPlaced = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _jumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // Speed of the happy jump
    );

    _audioPlayer.onPlayerComplete.listen((event) async {
      if (!mounted) return;

      if (_introStep == 0) {
        setState(() => _introStep = 1);
        _playAudio('audio/lumi_town/level12/appreciation_game_tutorial.wav');
      } else if (_introStep == 1) {
        setState(() => _introStep = 2);
      } else if (_introStep == 3) {
        // Scene 3 audio finished! Jump straight to Puzzle 3.
        setState(() {
          _introStep = 2; // Back to puzzle view
          _currentPuzzle = 3; // Load puzzle 3
        });
      } else if (_introStep == 4 && !_isJumping) {
        // Scene 4 final audio finished! Time to jump!
        setState(() {
          _isJumping = true;
        });
        _jumpCtrl.repeat(reverse: true);

        // Added the audio playback here!
        await _audioPlayer.play(AssetSource('audio/sound_effects/yey.wav'));

        // Jump for 2 seconds, then show Dr. Woo
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _jumpCtrl.stop();
            setState(() {
              _isJumping = false;
              _introStep = 5; // Transition to Dr. Woo scene
            });
            _playAudio('audio/lumi_town/level12/appreciation_game_ending.wav');
          }
        });
      } else if (_introStep == 5) {
        // Dr. Woo's audio is finished! Show the victory overlay.
        setState(() {
          _isGameWon = true;
        });
      }
    });

    if (_introStep == 0) {
      _walkCtrl.forward();
      _playAudio('audio/lumi_town/level12/appreciation_game_intro.wav');
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

  Future<void> _playShineSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  void _checkWinCondition() {
    // Check Puzzle 1 Completion
    if (_currentPuzzle == 1 &&
        isMaramingPlaced &&
        isSalamatPlaced &&
        isDomaPlaced) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _currentPuzzle = 2; // Move to the second puzzle!
          });
        }
      });
    }
    // Check Puzzle 2 Completion
    else if (_currentPuzzle == 2 &&
        isDahilPlaced &&
        isTinulunganPlaced &&
        isMoAkoPlaced) {
      // Show Scene 3
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _introStep = 3;
          });
          _playAudio('audio/lumi_town/level12/appreciation_game_part1.wav');
        }
      });
    }
    // Check Puzzle 3 Completion
    else if (_currentPuzzle == 3 &&
        isWalangPlaced &&
        isAnumanPlaced &&
        isIyonPlaced) {
      // Show Scene 4 (Final Smiling Scene)
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _introStep = 4;
          });
          _playAudio('audio/lumi_town/level12/appreciation_game_part2.wav');
        }
      });
    }
  }

  @override
  void dispose() {
    _walkCtrl.dispose();
    _jumpCtrl.dispose();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ==========================================
          // SCENE 0: WALKING INTRO
          // ==========================================
          if (_introStep == 0) ...[
            Image.asset(
              'assets/images/backgrounds/bg_classroom_closeup.png',
              fit: BoxFit.cover,
            ),

            // DOMA (Bottom Layer)
            AnimatedBuilder(
              animation: _walkCtrl,
              builder: (context, child) {
                final double t = _walkCtrl.value;
                final double easedT = Curves.easeOutCubic.transform(t);
                final double dx = sw * (1 - easedT);
                final int stepCount = 8;
                final double bounce = t < 1.0
                    ? (math.sin(t * stepCount * math.pi)).abs() *
                          walkBounceHeight
                    : 0.0;

                return Positioned(
                  left: (sw * domaTargetX) + dx,
                  bottom: (sh * domaBottom) + bounce,
                  child: child!,
                );
              },
              child: Image.asset(
                'assets/images/characters/doma_the_penguin.png',
                width: sw * domaWidth,
                fit: BoxFit.contain,
              ),
            ),

            // LITTLE BEAR (Top Layer)
            Positioned(
              left: sw * littleBearX,
              bottom: sh * littleBearBottom,
              child: Image.asset(
                'assets/images/characters/little_bear_stressed.png',
                width: sw * littleBearWidth,
                fit: BoxFit.contain,
              ),
            ),
          ]
          // ==========================================
          // SCENE 1: TUTORIAL IMAGE
          // ==========================================
          else if (_introStep == 1) ...[
            Image.asset(
              'assets/images/objects/lumi/littlebear_and_doma.png',
              fit: BoxFit.cover,
            ),
          ]
          // ==========================================
          // SCENE 2: PUZZLE GAMEPLAY
          // ==========================================
          else if (_introStep == 2) ...[
            // Base Background Image
            Image.asset(
              'assets/images/backgrounds/bg_lumi_puzzle.png',
              fit: BoxFit.cover,
            ),

            // ------------------------------------------
            // PUZZLE 1: Maraming Salamat Doma
            // ------------------------------------------
            if (_currentPuzzle == 1) ...[
              // 1. Right Piece (Doma)
              Positioned(
                top: sh * place3Y,
                left: sw * place3X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/doma_placeholder.png',
                  activePath: 'assets/images/objects/lumi/doma_rp.png',
                  width: sw * place3Width,
                  expectedId: 'doma',
                  isPlaced: isDomaPlaced,
                  onPlaced: () {
                    setState(() => isDomaPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // 2. Left Piece (Maraming)
              Positioned(
                top: sh * place1Y,
                left: sw * place1X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/maraming_placeholder.png',
                  activePath: 'assets/images/objects/lumi/maraming_rp.png',
                  width: sw * place1Width,
                  expectedId: 'maraming',
                  isPlaced: isMaramingPlaced,
                  onPlaced: () {
                    setState(() => isMaramingPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // 3. Middle Piece (Salamat)
              Positioned(
                top: sh * place2Y,
                left: sw * place2X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/salamat_placeholder.png',
                  activePath: 'assets/images/objects/lumi/salamat_rp.png',
                  width: sw * place2Width,
                  expectedId: 'salamat_orange',
                  isPlaced: isSalamatPlaced,
                  onPlaced: () {
                    setState(() => isSalamatPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // BOTTOM DRAGGABLES
              Positioned(
                top: sh * drag1Y,
                left: sw * drag1X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/salamat_rp.png',
                  width: sw * drag1Width,
                  id: 'salamat_orange',
                  isPlaced: isSalamatPlaced,
                ),
              ),
              Positioned(
                top: sh * drag2Y,
                left: sw * drag2X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/doma_rp.png',
                  width: sw * drag2Width,
                  id: 'doma',
                  isPlaced: isDomaPlaced,
                ),
              ),
              Positioned(
                top: sh * drag3Y,
                left: sw * drag3X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/maraming_rp.png',
                  width: sw * drag3Width,
                  id: 'maraming',
                  isPlaced: isMaramingPlaced,
                ),
              ),
              Positioned(
                top: sh * drag4Y,
                left: sw * drag4X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/salamat_wp.png',
                  width: sw * drag4Width,
                  id: 'salamat_blue',
                  isPlaced: false, // Distractor
                ),
              ),
            ]
            // ------------------------------------------
            // PUZZLE 2: Dahil Tinulungan Mo Ako
            // ------------------------------------------
            else if (_currentPuzzle == 2) ...[
              // 2. Left Piece (Dahil)
              Positioned(
                top: sh * p2Place1Y,
                left: sw * p2Place1X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/dahil_placeholder.png',
                  activePath: 'assets/images/objects/lumi/dahil_rp.png',
                  width: sw * p2Place1Width,
                  expectedId: 'dahil',
                  isPlaced: isDahilPlaced,
                  onPlaced: () {
                    setState(() => isDahilPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // 3. Right Piece (Mo Ako)
              Positioned(
                top: sh * p2Place3Y,
                left: sw * p2Place3X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/moako_placeholder.png',
                  activePath: 'assets/images/objects/lumi/moako_rp.png',
                  width: sw * p2Place3Width,
                  expectedId: 'mo_ako',
                  isPlaced: isMoAkoPlaced,
                  onPlaced: () {
                    setState(() => isMoAkoPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // 1. Middle Piece (Tinulungan)
              Positioned(
                top: sh * p2Place2Y,
                left: sw * p2Place2X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/tinulungan_placeholder.png',
                  activePath: 'assets/images/objects/lumi/tinulungan_rp.png',
                  width: sw * p2Place2Width,
                  expectedId: 'tinulungan',
                  isPlaced: isTinulunganPlaced,
                  onPlaced: () {
                    setState(() => isTinulunganPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // BOTTOM DRAGGABLES
              Positioned(
                top: sh * p2Drag1Y,
                left: sw * p2Drag1X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/dahil_rp.png',
                  width: sw * p2Drag1Width,
                  id: 'dahil',
                  isPlaced: isDahilPlaced,
                ),
              ),
              Positioned(
                top: sh * p2Drag2Y,
                left: sw * p2Drag2X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/ginulo_wp.png',
                  width: sw * p2Drag2Width,
                  id: 'ginulo_distractor',
                  isPlaced: false, // Distractor
                ),
              ),
              Positioned(
                top: sh * p2Drag3Y,
                left: sw * p2Drag3X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/moako_rp.png',
                  width: sw * p2Drag3Width,
                  id: 'mo_ako',
                  isPlaced: isMoAkoPlaced,
                ),
              ),
              Positioned(
                top: sh * p2Drag4Y,
                left: sw * p2Drag4X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/tinulungan_rp.png',
                  width: sw * p2Drag4Width,
                  id: 'tinulungan',
                  isPlaced: isTinulunganPlaced,
                ),
              ),
            ]
            // ------------------------------------------
            // PUZZLE 3: Walang Anuman Iyon
            // ------------------------------------------
            else if (_currentPuzzle == 3) ...[
              // 1. Right Piece (Iyon) - Painted First (Bottom Layer)
              Positioned(
                top: sh * p3Place3Y,
                left: sw * p3Place3X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/iyon_placeholder.png',
                  activePath: 'assets/images/objects/lumi/iyon_rp.png',
                  width: sw * p3Place3Width,
                  expectedId: 'iyon',
                  isPlaced: isIyonPlaced,
                  onPlaced: () {
                    setState(() => isIyonPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // 2. Middle Piece (Anuman) - Painted Second (Middle Layer)
              Positioned(
                top: sh * p3Place2Y,
                left: sw * p3Place2X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/anuman_placeholder.png',
                  activePath: 'assets/images/objects/lumi/anuman_rp.png',
                  width: sw * p3Place2Width,
                  expectedId: 'anuman',
                  isPlaced: isAnumanPlaced,
                  onPlaced: () {
                    setState(() => isAnumanPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // 3. Left Piece (Walang) - Painted Third (Top Layer)
              Positioned(
                top: sh * p3Place1Y,
                left: sw * p3Place1X,
                child: _buildPlaceholder(
                  placeholderPath:
                      'assets/images/objects/lumi/walang_placeholder.png',
                  activePath: 'assets/images/objects/lumi/walang_rp.png',
                  width: sw * p3Place1Width,
                  expectedId: 'walang',
                  isPlaced: isWalangPlaced,
                  onPlaced: () {
                    setState(() => isWalangPlaced = true);
                    _checkWinCondition();
                  },
                ),
              ),

              // BOTTOM DRAGGABLES
              Positioned(
                top: sh * p3Drag1Y,
                left: sw * p3Drag1X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/iyon_rp.png',
                  width: sw * p3Drag1Width,
                  id: 'iyon',
                  isPlaced: isIyonPlaced,
                ),
              ),
              Positioned(
                top: sh * p3Drag2Y,
                left: sw * p3Drag2X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/anuman_rp.png',
                  width: sw * p3Drag2Width,
                  id: 'anuman',
                  isPlaced: isAnumanPlaced,
                ),
              ),
              Positioned(
                top: sh * p3Drag3Y,
                left: sw * p3Drag3X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/walang_rp.png',
                  width: sw * p3Drag3Width,
                  id: 'walang',
                  isPlaced: isWalangPlaced,
                ),
              ),
              Positioned(
                top: sh * p3Drag4Y,
                left: sw * p3Drag4X,
                child: _buildDraggablePiece(
                  assetPath: 'assets/images/objects/lumi/kwenta_wp.png',
                  width: sw * p3Drag4Width,
                  id: 'kwenta_distractor',
                  isPlaced: false, // Distractor
                ),
              ),
            ],
          ]
          // ==========================================
          // SCENE 3: AUDIO CUTSCENE (After Puzzle 2)
          // ==========================================
          else if (_introStep == 3) ...[
            Image.asset(
              'assets/images/backgrounds/bg_classroom_closeup.png',
              fit: BoxFit.cover,
            ),
            // Little Bear Happy
            Positioned(
              left: sw * endBearX,
              bottom: sh * endBearBottom,
              child: Image.asset(
                'assets/images/characters/little_bear_happy.png',
                width: sw * endBearWidth,
                fit: BoxFit.contain,
              ),
            ),
            // Doma (Neutral)
            Positioned(
              left: sw * endDomaX,
              bottom: sh * endDomaBottom,
              child: Image.asset(
                'assets/images/characters/doma_the_penguin.png',
                width: sw * endDomaWidth,
                fit: BoxFit.contain,
              ),
            ),
          ]
          // ==========================================
          // SCENE 4 & 5: FINAL APPRECIATION & DR. WOO
          // ==========================================
          else if (_introStep >= 4) ...[
            Image.asset(
              'assets/images/backgrounds/bg_classroom_closeup.png',
              fit: BoxFit.cover,
            ),
            // Little Bear Happy (Jumps during Step 4 end)
            AnimatedBuilder(
              animation: _jumpCtrl,
              builder: (context, child) {
                final bounce = _isJumping
                    ? _jumpCtrl.value * finalJumpHeight
                    : 0.0;
                return Positioned(
                  left: sw * endBearX,
                  bottom: sh * endBearBottom + bounce,
                  child: child!,
                );
              },
              child: Image.asset(
                'assets/images/characters/little_bear_happy.png',
                width: sw * endBearWidth,
                fit: BoxFit.contain,
              ),
            ),
            // Doma (Smiling & Jumps during Step 4 end)
            AnimatedBuilder(
              animation: _jumpCtrl,
              builder: (context, child) {
                final bounce = _isJumping
                    ? _jumpCtrl.value * finalJumpHeight
                    : 0.0;
                return Positioned(
                  left: sw * smilingDomaX,
                  bottom: sh * smilingDomaBottom + bounce,
                  child: child!,
                );
              },
              child: Image.asset(
                'assets/images/characters/doma_smiling.png',
                width: sw * smilingDomaWidth,
                fit: BoxFit.contain,
              ),
            ),

            // DR. WOO OVERLAY (Appears in Step 5)
            if (_introStep == 5)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(darkOverlayOpacity),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: Offset(0, drWooVerticalOffset),
                      child: Image.asset(
                        'assets/images/characters/dr.woo_the_owl.png',
                        height: sh * drWooHeightPercentage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
          ],

          // Universal Back Button (Always visible on all steps)
          const Positioned(top: 25, left: 20, child: LumiBackButton()),

          // SUCCESS OVERLAY (Shows after Scene 5)
          if (_isGameWon)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/dr.woo_smiling.png',
                
                onNext: () async {
                  await TownProgressService.instance.markLevelComplete(12);

                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const FamilyTreeGame()),
                      (route) => route.isFirst,
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    _introStep = 0; // Completely restart the entire sequence!
                    _currentPuzzle = 1;
                    _isGameWon = false;
                    _isJumping = false;

                    isMaramingPlaced = false;
                    isSalamatPlaced = false;
                    isDomaPlaced = false;

                    isDahilPlaced = false;
                    isTinulunganPlaced = false;
                    isMoAkoPlaced = false;

                    isWalangPlaced = false;
                    isAnumanPlaced = false;
                    isIyonPlaced = false;

                    _walkCtrl.reset();
                    _jumpCtrl.stop();
                    _walkCtrl.forward();
                    _playAudio(
                      'audio/lumi_town/level12/appreciation_game_intro.wav',
                    );
                  });
                },
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }

  // Helper Widget for the drag targets (placeholders)
  Widget _buildPlaceholder({
    required String placeholderPath,
    required String activePath,
    required double width,
    required String expectedId,
    required bool isPlaced,
    required VoidCallback onPlaced,
  }) {
    return DragTarget<String>(
      builder: (context, candidateData, rejectedData) {
        return Image.asset(
          isPlaced ? activePath : placeholderPath,
          width: width,
          fit: BoxFit.contain,
        );
      },
      onWillAcceptWithDetails: (details) {
        return details.data == expectedId && !isPlaced;
      },
      onAcceptWithDetails: (details) {
        _playShineSound();
        onPlaced();
      },
    );
  }

  // Helper Widget for the colorful dragging pieces
  Widget _buildDraggablePiece({
    required String assetPath,
    required double width,
    required String id,
    required bool isPlaced,
  }) {
    if (isPlaced) {
      return SizedBox(width: width);
    }

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
