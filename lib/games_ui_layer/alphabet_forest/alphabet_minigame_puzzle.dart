import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_woodpecker_letter_listen.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'alphabet_game_ui.dart';
import 'forest_game_acorn_basket.dart';

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
            'assets/images/alphabets_puzzle/apple_full.png'; // image for the background
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/apple_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/apple_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/apple_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/apple_br.png'),
        ];
        break;
      case 'B':
        _fullImagePath = 'assets/images/alphabets_puzzle/ball_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/ball_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/ball_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/ball_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/ball_br.png'),
        ];
        break;
      case 'C':
        _fullImagePath = 'assets/images/alphabets_puzzle/car_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/car_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/car_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/car_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/car_br.png'),
        ];
        break;
      case 'D':
        _fullImagePath = 'assets/images/alphabets_puzzle/duck_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/duck_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/duck_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/duck_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/duck_br.png'),
        ];
        break;
      case 'E':
        _fullImagePath = 'assets/images/alphabets_puzzle/egg_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/egg_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/egg_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/egg_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/egg_br.png'),
        ];
        break;
      case 'F':
        _fullImagePath = 'assets/images/alphabets_puzzle/feet_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/feet_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/feet_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/feet_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/feet_br.png'),
        ];
        break;
      case 'G':
        _fullImagePath = 'assets/images/alphabets_puzzle/glass_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/glass_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/glass_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/glass_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/glass_br.png'),
        ];
        break;
      case 'H':
        _fullImagePath = 'assets/images/alphabets_puzzle/hat_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/hat_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/hat_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/hat_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/hat_br.png'),
        ];
        break;
      case 'I':
        _fullImagePath = 'assets/images/alphabets_puzzle/igloo_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/igloo_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/igloo_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/igloo_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/igloo_br.png'),
        ];
        break;
      case 'J':
        _fullImagePath = 'assets/images/alphabets_puzzle/jar_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/jar_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/jar_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/jar_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/jar_br.png'),
        ];
        break;
      case 'K':
        _fullImagePath = 'assets/images/alphabets_puzzle/key_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/key_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/key_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/key_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/key_br.png'),
        ];
        break;

      case 'L':
        _fullImagePath = 'assets/images/alphabets_puzzle/lamp_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/lamp_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/lamp_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/lamp_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/lamp_br.png'),
        ];
        break;

      case 'M':
        _fullImagePath = 'assets/images/alphabets_puzzle/milk_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/milk_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/milk_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/milk_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/milk_br.png'),
        ];
        break;
      case 'N':
        _fullImagePath =
        'assets/images/alphabets_puzzle/nose_full.png'; // Make sure this matches your image name!
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/nose_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/nose_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/nose_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/nose_br.png'),
        ];
        break;
      case 'O':
        _fullImagePath = 'assets/images/alphabets_puzzle/oil_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/oil_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/oil_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/oil_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/oil_br.png'),
        ];
        break;

      case 'P':
        _fullImagePath = 'assets/images/alphabets_puzzle/pan_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/pan_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/pan_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/pan_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/pan_br.png'),
        ];
        break;

      case 'Q':
        _fullImagePath = 'assets/images/alphabets_puzzle/queen_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/queen_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/queen_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/queen_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/queen_br.png'),
        ];
        break;

      case 'R':
        _fullImagePath = 'assets/images/alphabets_puzzle/rain_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/rain_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/rain_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/rain_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/rain_br.png'),
        ];
        break;

      case 'S':
        _fullImagePath = 'assets/images/alphabets_puzzle/sun_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/sun_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/sun_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/sun_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/sun_br.png'),
        ];
        break;
      case 'T':
        _fullImagePath =
        'assets/images/alphabets_puzzle/tree_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/tree_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/tree_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/tree_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/tree_br.png'),
        ];
        break;
      case 'U':
        _fullImagePath = 'assets/images/alphabets_puzzle/umbrella_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/umbrella_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/umbrella_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/umbrella_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/umbrella_br.png'),
        ];
        break;

      case 'V':
        _fullImagePath = 'assets/images/alphabets_puzzle/vase_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/vase_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/vase_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/vase_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/vase_br.png'),
        ];
        break;
      case 'W':
        _fullImagePath =
        'assets/images/alphabets_puzzle/window_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/window_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/window_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/window_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/window_br.png'),
        ];
        break;
      case 'X':
        _fullImagePath = 'assets/images/alphabets_puzzle/xylophone_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/xylophone_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/xylophone_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/xylophone_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/xylophone_br.png'),
        ];
        break;

      case 'Y':
        _fullImagePath = 'assets/images/alphabets_puzzle/yarn_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/yarn_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/yarn_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/yarn_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/yarn_br.png'),
        ];
        break;

      case 'Z':
        _fullImagePath = 'assets/images/alphabets_puzzle/zero_full.png';
        _allPieces = [
          PuzzlePiece(id: 0, imagePath: 'assets/images/alphabets_puzzle/zero_tl.png'),
          PuzzlePiece(id: 1, imagePath: 'assets/images/alphabets_puzzle/zero_tr.png'),
          PuzzlePiece(id: 2, imagePath: 'assets/images/alphabets_puzzle/zero_bl.png'),
          PuzzlePiece(id: 3, imagePath: 'assets/images/alphabets_puzzle/zero_br.png'),
        ];
        break;
      default:
        // Fallback just in case
        _fullImagePath = 'assets/images/alphabets_puzzle/apple_full.png';
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
    final String currentLetter = widget.letter.toUpperCase();

    const skipGoodJobLetters = {
      'A', 'B',
      'D', 'E',
      'G', 'H',
      'J', 'K',
      'M', 'N',
      'P', 'Q',
      'S', 'T',
      'V', 'W',
      'Y', 'Z',
    };

    if (skipGoodJobLetters.contains(currentLetter)) {
      String nextLetter =
      String.fromCharCode(currentLetter.codeUnitAt(0) + 1);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AlphabetIntroScreen(letter: nextLetter),
        ),
      );
      return;
    }

    // mark level complete for some letters
    const completeLevelsLetters = {
      'C',
      'F',
      'I',
      'L',
      'O',
      'R',
      'U',
      'X',
      'Z',
    };

    if (completeLevelsLetters.contains(currentLetter)) {
      final completedLevel =
      ForestProgressService.levelNumberForLetter(currentLetter);

      if (completedLevel != null) {
        ForestProgressService.instance.markLevelComplete(completedLevel);
      }
    }

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

            if (currentLetter == 'C'){
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const WoodpeckerLetterListenGame(level: 2),
                ),
              );
            } else if (currentLetter == 'F'){
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcornBasketGame(level: 4),
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
                        AlphabetIntroScreen(letter: nextLetter),
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
