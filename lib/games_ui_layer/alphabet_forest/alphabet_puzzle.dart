import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_fall.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_match.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'alphabet_game_ui.dart';

class PuzzlePiece {
  final int id; // 0=TL, 1=TR, 2=BL, 3=BR
  final String imagePath;

  PuzzlePiece({required this.id, required this.imagePath});
}

class AlphabetPuzzleScreen extends StatefulWidget {
  // You can pass the letter you want to play through the constructor later!
  final String letter;

  const AlphabetPuzzleScreen({super.key, required this.letter});

  @override
  State<AlphabetPuzzleScreen> createState() => _AlphabetPuzzleScreenState();
}

class _AlphabetPuzzleScreenState extends State<AlphabetPuzzleScreen>
  with TofiReactionMixin {
  @override
  AudioPlayer get tofiPlayer => _player;

  final AudioPlayer _player = AudioPlayer();

  late List<PuzzlePiece> _availablePieces;
  final Map<int, PuzzlePiece> _placedPieces = {};

  late List<PuzzlePiece> _allPieces;
  late String _fullImagePath; // Added for the background hint

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Load the correct pieces and background before starting the game
    _loadLetter(widget.letter);
    _resetGame();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _player.dispose();
    super.dispose();
  }

  // --- 1. THE LETTER LOADING METHOD ---
  void _loadLetter(String letter) {
    switch (letter.toUpperCase()) {
      case 'A':
        _fullImagePath =
            'assets/images/alphabets/apple_full.png'; // image for the background
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/apple_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/apple_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/apple_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/apple_br.png'),
        ];
        break;
      case 'B':
        _fullImagePath = 'assets/images/alphabets/ball_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/ball_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/ball_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/ball_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/ball_br.png'),
        ];
        break;
      case 'C':
        _fullImagePath = 'assets/images/alphabets/car_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/car_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/car_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/car_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/car_br.png'),
        ];
        break;
      case 'D':
        _fullImagePath = 'assets/images/alphabets/duck_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/duck_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/duck_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/duck_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/duck_br.png'),
        ];
        break;
      case 'E':
        _fullImagePath = 'assets/images/alphabets/egg_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/egg_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/egg_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/egg_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/egg_br.png'),
        ];
        break;
      case 'F':
        _fullImagePath = 'assets/images/alphabets/feet_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/feet_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/feet_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/feet_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/feet_br.png'),
        ];
        break;
      case 'G':
        _fullImagePath = 'assets/images/alphabets/glass_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/glass_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/glass_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/glass_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/glass_br.png'),
        ];
        break;
      case 'H':
        _fullImagePath = 'assets/images/alphabets/hat_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/hat_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/hat_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/hat_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/hat_br.png'),
        ];
        break;
      case 'I':
        _fullImagePath = 'assets/images/alphabets/igloo_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/igloo_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/igloo_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/igloo_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/igloo_br.png'),
        ];
        break;
      case 'J':
        _fullImagePath = 'assets/images/alphabets/jar_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/jar_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/jar_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/jar_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/jar_br.png'),
        ];
        break;
      case 'N':
        _fullImagePath =
            'assets/images/alphabets/nose_full.png'; // Make sure this matches your image name!
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets/nose_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets/nose_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets/nose_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets/nose_br.png'),
        ];
        break;
      default:
        // Fallback just in case
        _fullImagePath = 'assets/images/alphabets/apple_full.png';
        _allPieces = [];
    }
  }

  void _resetGame() {
    setState(() {
      _placedPieces.clear();
      _availablePieces = List.from(_allPieces)..shuffle();
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: 'assets/images/characters/dog.png',
          closeButtonColor: ForestColorTheme.mediumseagreen,

          //Wag po buburahin 1
          // 1. NEXT BUTTON: What happens when they click the right arrow?
          // onNext: () {
          // Navigator.pop(context);
          // Navigator.pop(
          //   context,
          // );
          // },
          //Wag po buburahin 2

          // 2. Goes from PUZZLE to PUZZLE continuously (D -> E -> F)
          onNext: () {
            Navigator.pop(context); // Close the prompt

            String current = widget.letter.toUpperCase();

            // Mark this letter's level as complete, unlocking the next one.
            final completedLevel = ForestProgressService.levelNumberForLetter(
              current,
            );
            if (completedLevel != null) {
              ForestProgressService.instance.markLevelComplete(completedLevel);
            }

            if (current == 'G') {
              // If they just finished G, send them to Level 8 (Match Game!)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlphabetMatchScreen(),
                ),
              );
            } else if (current == 'N') {
              // If they just finished N, send them to Level 16 (Fall Game!)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlphabetFallScreen(),
                ),
              );
            } else {
              // Otherwise, just go to the next normal Intro screen!
              int charCode = current.codeUnitAt(0);
              if (charCode >= 65 && charCode < 90) {
                String nextLetter = String.fromCharCode(charCode + 1);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetIntroScreen(startingLetter: nextLetter),
                  ),
                );
              } else {
                // Reached the end with no more letters/boss levels mapped.
                // Go back to a fresh level-select screen so it reloads
                // progress on its own, instead of popping back to a
                // potentially stale existing instance.
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForestLevelScreen(),
                  ),
                );
              }
            }
          },
          onRestart: () {
            Navigator.pop(context);
            _resetGame();
          },

          onBack: () {
            Navigator.pop(context); // Close the prompt
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ForestLevelScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double boardSize = screenSize.height * 0.65;
    final double pieceSize = boardSize / 2;

    return Scaffold(
      body: ForestBackground(
        child: Stack(
          children: [
            buildTofi(context),

            // Back button
            const Positioned(
              top: 25,
              left: 20,
              child: ForestBackButton(),
            ),

            // Title
            const Positioned(
              top: 25,
              left: 0,
              right: 0,
              child: Center(
                child: ForestInstructionBanner(
                  text: 'Complete the Picture!',
                ),
              ),
            ),

            // Level badge
            Positioned(
              top: 25,
              right: 20,
              child: ForestLevelBadge(
                level: ForestProgressService.levelNumberForLetter(
                  widget.letter.toUpperCase(),
                ) ??
                    1,
              ),
            ),

            Stack(
              children: [
                Padding(padding: const EdgeInsets.only(top: 70),
                  child: Center(
                    child: SizedBox(
                      width: boardSize,
                      height: boardSize,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          border: Border.all(
                            color: ForestColorTheme.lightgreen,
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: AssetImage(_fullImagePath),
                            fit: BoxFit.cover,
                            opacity: 0.65,
                          ),
                        ),
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          removeBottom: true,
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 4,
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                            ),
                            itemBuilder: (context, index) {
                              return _buildTargetSlot(index, pieceSize);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                ),
                Positioned(
                  right: 20,
                  top: 80,
                  bottom: 20,
                  child: SizedBox(
                    width: screenSize.width * 0.28,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _availablePieces.length,
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final piece = _availablePieces[index];

                          return Draggable<PuzzlePiece>(
                            data: piece,
                            feedback: _PuzzlePieceWidget(
                              imagePath: piece.imagePath,
                              size: pieceSize,
                              isDragging: true,
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.2,
                              child: _PuzzlePieceWidget(
                                imagePath: piece.imagePath,
                                size: pieceSize,
                              ),
                            ),
                            child: _PuzzlePieceWidget(
                              imagePath: piece.imagePath,
                              size: pieceSize,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSlot(int slotIndex, double size) {
    bool isFilled = _placedPieces.containsKey(slotIndex);
    PuzzlePiece? placedPiece = _placedPieces[slotIndex];

    return DragTarget<PuzzlePiece>(
      onWillAcceptWithDetails: (details) =>
          details.data.id == slotIndex && !isFilled,
      onAcceptWithDetails: (details) {
        setState(() {
          _placedPieces[slotIndex] = details.data;
          _availablePieces.removeWhere((p) => p.id == details.data.id);
        });

        showTofiReaction(TofiState.correct);

        if (_placedPieces.length == 4) {
          Future.delayed(const Duration(milliseconds: 400), _showSuccessDialog);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isHovering
                  ? ForestColorTheme.seagreen
                  : ForestColorTheme.darkseagreen.withValues(alpha: 0.1),
              width: isHovering ? 4 : 1,
            ),
            // Changed this to be more transparent so the background hint shows through clearly
            color: isHovering
                ? ForestColorTheme.lightgreen.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          child: isFilled
              ? _PuzzlePieceWidget(
                  imagePath: placedPiece!.imagePath,
                  size: size,
                )
              : null,
        );
      },
    );
  }
}

class _PuzzlePieceWidget extends StatelessWidget {
  final String imagePath;
  final double size;
  final bool isDragging;

  const _PuzzlePieceWidget({
    required this.imagePath,
    required this.size,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: isDragging ? 1.05 : 1.0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            boxShadow: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(5, 5),
                ),
            ],
          ),
          child: Image.asset(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
