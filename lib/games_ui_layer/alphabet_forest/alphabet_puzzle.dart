import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_trace.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:flutter/material.dart';

class PuzzlePiece {
  final int id; // 0=TL, 1=TR, 2=BL, 3=BR
  final String imagePath;

  PuzzlePiece({required this.id, required this.imagePath});
}

class AlphabetPuzzleScreen extends StatefulWidget {
  // You can pass the letter you want to play through the constructor later!
  final String startingLetter;

  const AlphabetPuzzleScreen({super.key, required this.startingLetter});

  @override
  State<AlphabetPuzzleScreen> createState() => _AlphabetPuzzleScreenState();
}

class _AlphabetPuzzleScreenState extends State<AlphabetPuzzleScreen> {
  late List<PuzzlePiece> _availablePieces;
  final Map<int, PuzzlePiece> _placedPieces = {};

  late List<PuzzlePiece> _allPieces;
  late String _fullImagePath; // Added for the background hint

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Load the correct pieces and background before starting the game
    _loadLetter(widget.startingLetter);
    _resetGame();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
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

  // Helper to find the next letter in the alphabet
  String _getNextLetter(String currentLetter) {
    int charCode = currentLetter.toUpperCase().codeUnitAt(0);

    // If the letter is between A (65) and Y (89), return the next letter!
    if (charCode >= 65 && charCode < 90) {
      return String.fromCharCode(charCode + 1);
    }

    // If they finished 'Z', return a flag to tell the app they are done
    return 'DONE';
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

          // 2. Goes from PUZZLE to TRACE (stays on the same letter)
          onNext: () {
            Navigator.pop(context); // Close the Good Job prompt

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AlphabetTraceScreen(startingLetter: widget.startingLetter),
              ),
            );
          },

          onRestart: () {
            Navigator.pop(context);
            _resetGame();
          },

          onBack: () {
            Navigator.pop(context);
            Navigator.pop(context);
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
        child: SafeArea(
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ForestBackButton(),
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Complete the Picture!',
                        style: TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: ForestColorTheme.darkseagreen,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        width: boardSize,
                        height: boardSize,
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
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                              ),
                          itemCount: 4,
                          itemBuilder: (context, index) {
                            return _buildTargetSlot(index, pieceSize);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: screenSize.width * 0.25,
                color: Colors.white.withValues(alpha: 0.4),
                child: Center(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: _availablePieces.map((piece) {
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
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
