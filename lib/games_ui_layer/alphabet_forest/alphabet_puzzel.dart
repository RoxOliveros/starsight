import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- GENERIC THEME ---
abstract class ColorTheme {
  static const Color background = Color(0xFFE8F4F8);
  static const Color textDark = Color(0xFF5E463E);
  static const Color primary = Color(0xFF75D5FF);
  static const Color success = Color(0xFF82C84B);
  static const Color accent = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

// --- NEW MODEL FOR PUZZLE PIECES ---
class PuzzlePiece {
  final int id; // 0=TL, 1=TR, 2=BL, 3=BR
  final String imagePath;

  PuzzlePiece({required this.id, required this.imagePath});
}

class AlphabetPuzzleScreen extends StatefulWidget {
  const AlphabetPuzzleScreen({super.key});

  @override
  State<AlphabetPuzzleScreen> createState() => _AlphabetPuzzleScreenState();
}

class _AlphabetPuzzleScreenState extends State<AlphabetPuzzleScreen> {
  late List<PuzzlePiece> _availablePieces;
  final Map<int, PuzzlePiece> _placedPieces = {};

  // The 4 pre-cropped images!
  final List<PuzzlePiece> _allPieces = [
    PuzzlePiece(id: 0, imagePath: 'assets/images/apple_tl.png'), // Top Left
    PuzzlePiece(id: 1, imagePath: 'assets/images/apple_tr.png'), // Top Right
    PuzzlePiece(id: 2, imagePath: 'assets/images/apple_bl.png'), // Bottom Left
    PuzzlePiece(id: 3, imagePath: 'assets/images/apple_br.png'), // Bottom Right
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _resetGame();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _placedPieces.clear();
      _availablePieces = List.from(_allPieces)
        ..shuffle(); // Shuffle the pieces!
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Amazing!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.success,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "You completed the picture!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 22,
            color: ColorTheme.textDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: const Text(
              "Play Again",
              style: TextStyle(
                color: ColorTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Universal screen math
    final Size screenSize = MediaQuery.of(context).size;
    final double boardSize =
        screenSize.height * 0.65; // The total 2x2 grid size
    final double pieceSize = boardSize / 2; // Size of a single square piece

    return Scaffold(
      backgroundColor: ColorTheme.background,
      body: SafeArea(
        child: Row(
          children: [
            // --- LEFT SIDE: BACK BUTTON ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: ColorTheme.textDark,
                    size: 32,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // --- CENTER: THE PUZZLE BOARD ---
            Expanded(
              flex: 3,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Complete the Picture!',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: ColorTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // The 2x2 Grid
                    Container(
                      width: boardSize,
                      height: boardSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        border: Border.all(color: ColorTheme.primary, width: 4),
                        borderRadius: BorderRadius.circular(12),
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

            // --- RIGHT SIDE: AVAILABLE PIECES (Draggables) ---
            Container(
              width: screenSize.width * 0.25,
              color: Colors.white.withOpacity(0.4),
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
    );
  }

  // The empty slots on the board waiting to receive a piece
  Widget _buildTargetSlot(int slotIndex, double size) {
    bool isFilled = _placedPieces.containsKey(slotIndex);
    PuzzlePiece? placedPiece = _placedPieces[slotIndex];

    return DragTarget<PuzzlePiece>(
      // Only accept if the piece's ID matches the Slot Index (0 goes to 0, 1 to 1)
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
                  ? ColorTheme.success
                  : ColorTheme.textDark.withOpacity(0.1),
              width: isHovering ? 4 : 1,
            ),
            color: isHovering
                ? ColorTheme.success.withOpacity(0.2)
                : Colors.transparent,
          ),
          child: isFilled
              ? _PuzzlePieceWidget(
                  imagePath: placedPiece!.imagePath,
                  size: size,
                )
              : null, // Empty slot
        );
      },
    );
  }
}

// --- SIMPLIFIED WIDGET FOR THE IMAGES ---
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
                  color: Colors.black.withOpacity(0.3),
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
