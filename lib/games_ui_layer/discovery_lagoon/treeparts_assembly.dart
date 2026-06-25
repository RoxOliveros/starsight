import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_background.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'bodyparts_drag.dart';

class TreePartItem {
  final String id;
  final String imagePath;

  TreePartItem({required this.id, required this.imagePath});
}

class TreePartsAssemblyScreen extends StatefulWidget {
  final int level;

  const TreePartsAssemblyScreen({super.key, required this.level});

  @override
  State<TreePartsAssemblyScreen> createState() =>
      _TreePartsAssemblyScreenState();
}

class _TreePartsAssemblyScreenState extends State<TreePartsAssemblyScreen> {
  final Set<String> _matchedParts = {};
  late List<TreePartItem> _availableParts;

  final List<TreePartItem> _allParts = [
    TreePartItem(
      id: 'leaves',
      imagePath: 'assets/images/objects/lagoon/leaves.png',
    ),
    TreePartItem(
      id: 'branch',
      imagePath: 'assets/images/objects/lagoon/branch.png',
    ),
    TreePartItem(
      id: 'trunk',
      imagePath: 'assets/images/objects/lagoon/trunk.png',
    ),
    TreePartItem(
      id: 'roots',
      imagePath: 'assets/images/objects/lagoon/roots.png',
    ),
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
    LagoonProgressService.instance.markLevelComplete(widget.level);
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (context) => GoodJobOverlay(
        characterImage: 'assets/images/characters/cat_holding_fishbone.png',
        closeButtonColor: LagoonTheme.wasteland,
        onNext: () {
          Navigator.pop(context);
          // Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => WeatherLineMatchScreen(level: widget.level + 1),
          //   ),
          // );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LagoonColorTheme.pastelorange,
      body: LagoonBackground(
        child: SafeArea(
          child: Column(
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: LagoonBackButton(),
                    ),
                  ],
                ),
              ),

              // --- MAIN PUZZLE AREA ---
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double h = constraints.maxHeight;
                    final double w = constraints.maxWidth;
                    final double cx = w / 2;
                    final double cy = h / 2;
                    final double boxSize = h * 0.35;

                    final double treeHeight = h * 1;
                    final double treeWidth = treeHeight * 0.6;
                    final double treeLeft = cx - treeWidth / 2;
                    final double treeTop = cy - treeHeight / 2;

                    // Pointer targets ON the tree image
                    final Offset leavesTarget = Offset(
                      treeLeft + treeWidth * 0.05,
                      treeTop + treeHeight * 0.30,
                    );
                    final Offset branchTarget = Offset(
                      treeLeft + treeWidth * 0.75,
                      treeTop + treeHeight * 0.57,
                    );
                    final Offset trunkTarget = Offset(
                      treeLeft + treeWidth * 0.50,
                      treeTop + treeHeight * 0.75,
                    );
                    final Offset rootsTarget = Offset(
                      treeLeft + treeWidth * 0.20,
                      treeTop + treeHeight * 0.87,
                    );

                    // Label box positions (left/right of tree)
                    final Offset leavesBox = Offset(
                      cx - h * 0.80,
                      cy - h * 0.32,
                    );
                    final Offset branchBox = Offset(
                      cx + h * 0.80,
                      cy - h * 0.25,
                    );
                    final Offset trunkBox = Offset(
                      cx + h * 0.80,
                      cy + h * 0.22,
                    );
                    final Offset rootsBox = Offset(
                      cx - h * 0.80,
                      cy + h * 0.20,
                    );

                    return Stack(
                      children: [
                        // Tree image
                        Center(
                          child: Image.asset(
                            'assets/images/objects/lagoon/tree.png',
                            height: treeHeight,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Connecting lines
                        CustomPaint(
                          size: Size.infinite,
                          painter: TreeLinesPainter(
                            leavesBox: leavesBox,
                            leavesTarget: leavesTarget,
                            branchBox: branchBox,
                            branchTarget: branchTarget,
                            trunkBox: trunkBox,
                            trunkTarget: trunkTarget,
                            rootsBox: rootsBox,
                            rootsTarget: rootsTarget,
                          ),
                        ),

                        // Drop boxes
                        Positioned(
                          left: leavesBox.dx - boxSize / 2,
                          top: leavesBox.dy - boxSize / 2,
                          child: _buildTargetBox('leaves', boxSize),
                        ),
                        Positioned(
                          left: branchBox.dx - boxSize / 2,
                          top: branchBox.dy - boxSize / 2,
                          child: _buildTargetBox('branch', boxSize),
                        ),
                        Positioned(
                          left: trunkBox.dx - boxSize / 2,
                          top: trunkBox.dy - boxSize / 2,
                          child: _buildTargetBox('trunk', boxSize),
                        ),
                        Positioned(
                          left: rootsBox.dx - boxSize / 2,
                          top: rootsBox.dy - boxSize / 2,
                          child: _buildTargetBox('roots', boxSize),
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
      ),
    );
  }

  Widget _buildTargetBox(String targetId, double size) {
    bool isMatched = _matchedParts.contains(targetId);
    String? matchedImagePath = isMatched
        ? _allParts.firstWhere((p) => p.id == targetId).imagePath
        : null;

    // Label for each target
    final labels = {
      'leaves': 'Leaves',
      'branch': 'Branch',
      'trunk': 'Trunk',
      'roots': 'Roots',
    };

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
      builder: (context, candidateData, _) {
        bool isHovering = candidateData.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isHovering
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.9),
                border: Border.all(
                  color: isHovering
                      ? LagoonColorTheme.ferngreen
                      : Colors.black87,
                  width: isHovering ? 6 : 4,
                ),
                boxShadow: [
                  if (isHovering)
                    BoxShadow(
                      color: LagoonColorTheme.ferngreen.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                ],
              ),
              child: isMatched
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        matchedImagePath!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              labels[targetId] ?? targetId,
              style: const TextStyle(
                fontFamily: LagoonAppTextStyles.fredoka,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
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

class TreeLinesPainter extends CustomPainter {
  final Offset leavesBox, leavesTarget;
  final Offset branchBox, branchTarget;
  final Offset trunkBox, trunkTarget;
  final Offset rootsBox, rootsTarget;

  TreeLinesPainter({
    required this.leavesBox,
    required this.leavesTarget,
    required this.branchBox,
    required this.branchTarget,
    required this.trunkBox,
    required this.trunkTarget,
    required this.rootsBox,
    required this.rootsTarget,
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

    void drawConnection(Offset box, Offset target) {
      canvas.drawLine(box, target, linePaint);
      canvas.drawCircle(target, 6.0, dotPaint);
    }

    drawConnection(leavesBox, leavesTarget);
    drawConnection(branchBox, branchTarget);
    drawConnection(trunkBox, trunkTarget);
    drawConnection(rootsBox, rootsTarget);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
