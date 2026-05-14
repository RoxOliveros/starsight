import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';

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

class BodyPartItem {
  final String id;
  final String imagePath;

  BodyPartItem({required this.id, required this.imagePath});
}

class BodyPartsAssemblyScreen extends StatefulWidget {
  const BodyPartsAssemblyScreen({super.key});

  @override
  State<BodyPartsAssemblyScreen> createState() =>
      _BodyPartsAssemblyScreenState();
}

class _BodyPartsAssemblyScreenState extends State<BodyPartsAssemblyScreen> {
  final Set<String> _matchedParts = {};
  late List<BodyPartItem> _availableParts;

  final List<BodyPartItem> _allParts = [
    BodyPartItem(id: 'head', imagePath: 'assets/images/objects/head.png'),
    BodyPartItem(
      id: 'shoulder',
      imagePath: 'assets/images/objects/shoulder.png',
    ),
    BodyPartItem(id: 'knee', imagePath: 'assets/images/objects/knee.png'),
    BodyPartItem(id: 'feet', imagePath: 'assets/images/objects/feet.png'),
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _resetGame();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _matchedParts.clear();
      _availableParts = List.from(_allParts)..shuffle();
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
          "You labeled all the body parts!",
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
    return Scaffold(
      backgroundColor: ColorTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: ColorTheme.textDark,
                        size: 32,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Label the Body',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.textDark,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: ColorTheme.accent,
                        size: 32,
                      ),
                      onPressed: _resetGame,
                    ),
                  ),
                ],
              ),
            ),

            // --- MAIN PUZZLE AREA ---
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Universal Math Base
                  final double h = constraints.maxHeight;
                  final double cx = constraints.maxWidth / 2;
                  final double cy = h / 2;
                  final double boxSize = h * 0.25; // Box scales with height

                  // Calculate EXACT Box Centers anchored to the middle
                  final Offset headBoxCenter = Offset(
                    cx - h * 0.45,
                    cy - h * 0.25,
                  );
                  final Offset shoulderBoxCenter = Offset(
                    cx + h * 0.45,
                    cy - h * 0.20,
                  );
                  final Offset feetBoxCenter = Offset(
                    cx - h * 0.45,
                    cy + h * 0.25,
                  );
                  final Offset kneeBoxCenter = Offset(
                    cx + h * 0.45,
                    cy + h * 0.25,
                  );

                  // Calculate EXACT Body Part Targets on the boy image
                  final Offset headTarget = Offset(
                    cx - h * 0.08,
                    cy - h * 0.22,
                  );
                  final Offset shoulderTarget = Offset(
                    cx + h * 0.13,
                    cy - h * 0.05,
                  );
                  final Offset feetTarget = Offset(
                    cx - h * 0.10,
                    cy + h * 0.35,
                  );
                  final Offset kneeTarget = Offset(
                    cx + h * 0.07,
                    cy + h * 0.20,
                  );

                  return Stack(
                    children: [
                      // 1. Draw connecting lines
                      CustomPaint(
                        size: Size.infinite,
                        painter: ConnectingLinesPainter(
                          headBox: headBoxCenter,
                          headTarget: headTarget,
                          shoulderBox: shoulderBoxCenter,
                          shoulderTarget: shoulderTarget,
                          feetBox: feetBoxCenter,
                          feetTarget: feetTarget,
                          kneeBox: kneeBoxCenter,
                          kneeTarget: kneeTarget,
                        ),
                      ),

                      // 2. The Center Boy Image
                      Center(
                        child: Image.asset(
                          'assets/images/objects/boy.png', // Keep your boy image path here!
                          height: h * 0.8,
                          fit: BoxFit.contain,
                        ),
                      ),

                      // 3. Target Boxes positioned exactly on their calculated centers
                      Positioned(
                        left: headBoxCenter.dx - (boxSize / 2),
                        top: headBoxCenter.dy - (boxSize / 2),
                        child: _buildTargetBox('head', boxSize),
                      ),
                      Positioned(
                        left: shoulderBoxCenter.dx - (boxSize / 2),
                        top: shoulderBoxCenter.dy - (boxSize / 2),
                        child: _buildTargetBox('shoulder', boxSize),
                      ),
                      Positioned(
                        left: feetBoxCenter.dx - (boxSize / 2),
                        top: feetBoxCenter.dy - (boxSize / 2),
                        child: _buildTargetBox('feet', boxSize),
                      ),
                      Positioned(
                        left: kneeBoxCenter.dx - (boxSize / 2),
                        top: kneeBoxCenter.dy - (boxSize / 2),
                        child: _buildTargetBox('knee', boxSize),
                      ),
                    ],
                  );
                },
              ),
            ),

            // --- DRAGGABLE PARTS ROW ---
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.white.withValues(alpha: .5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _availableParts.map((part) {
                  if (_matchedParts.contains(part.id)) {
                    return const SizedBox(width: 100);
                  }

                  return Draggable<String>(
                    data: part.id,
                    feedback: _DraggableImage(
                      imagePath: part.imagePath,
                      isDragging: true,
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _DraggableImage(imagePath: part.imagePath),
                    ),
                    child: _DraggableImage(imagePath: part.imagePath),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetBox(String targetId, double size) {
    bool isMatched = _matchedParts.contains(targetId);
    String? matchedImagePath = isMatched
        ? _allParts.firstWhere((p) => p.id == targetId).imagePath
        : null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          details.data == targetId && !isMatched,
      onAcceptWithDetails: (details) {
        setState(() {
          _matchedParts.add(targetId);
        });
        if (_matchedParts.length == _allParts.length) {
          Future.delayed(const Duration(milliseconds: 300), _showSuccessDialog);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isHovering ? Colors.white : Colors.white.withValues(alpha: 0.9),
            border: Border.all(
              color: isHovering ? ColorTheme.success : Colors.black87,
              width: isHovering ? 6 : 4,
            ),
            boxShadow: [
              if (isHovering)
                BoxShadow(
                  color: ColorTheme.success.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
            ],
          ),
          child: isMatched
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(matchedImagePath!, fit: BoxFit.contain),
                )
              : null,
        );
      },
    );
  }
}

class _DraggableImage extends StatelessWidget {
  final String imagePath;
  final bool isDragging;

  const _DraggableImage({required this.imagePath, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: isDragging ? 1.2 : 1.0,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// --- UPDATED CUSTOM PAINTER ---
class ConnectingLinesPainter extends CustomPainter {
  final Offset headBox, headTarget;
  final Offset shoulderBox, shoulderTarget;
  final Offset feetBox, feetTarget;
  final Offset kneeBox, kneeTarget;

  ConnectingLinesPainter({
    required this.headBox,
    required this.headTarget,
    required this.shoulderBox,
    required this.shoulderTarget,
    required this.feetBox,
    required this.feetTarget,
    required this.kneeBox,
    required this.kneeTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Helper function to draw a line with a dot at the target
    void drawConnection(Offset box, Offset target) {
      canvas.drawLine(box, target, linePaint);
      canvas.drawCircle(target, 6.0, dotPaint); // Draws the pointer dot!
    }

    drawConnection(headBox, headTarget);
    drawConnection(shoulderBox, shoulderTarget);
    drawConnection(feetBox, feetTarget);
    drawConnection(kneeBox, kneeTarget);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
