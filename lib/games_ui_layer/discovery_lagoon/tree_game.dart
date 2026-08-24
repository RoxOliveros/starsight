import 'package:flutter/material.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../goodjob_prompt.dart';

class TreeGameScreen extends StatefulWidget {
  const TreeGameScreen({super.key});

  @override
  State<TreeGameScreen> createState() => _TreeGameScreenState();
}

/// A single piece: its asset, its own fixed size, where it belongs in the
/// finished tree, and where it starts out scattered on screen.
class _TreePart {
  final String id;
  final String asset;
  final double width;
  final double height;
  final double targetLeft;
  final double targetTop;
  final Alignment scatterPosition;
  final double scatterTilt;

  const _TreePart({
    required this.id,
    required this.asset,
    required this.width,
    required this.height,
    required this.targetLeft,
    required this.targetTop,
    required this.scatterPosition,
    this.scatterTilt = 0.0,
  });
}

class _TreeGameScreenState extends State<TreeGameScreen> {
  static const String _fullTreeAsset =
      'assets/images/objects/lagoon/t5_tree.png';

  static const double _canvasWidth = 260;
  static const double _canvasHeight = 311;

  // ==========================================
  // MANUAL ADJUSTERS
  // ==========================================

  static const double _kikiAlignX = -1.00;
  static const double _kikiAlignY = 1.70;
  static const double _kikiHeight = 250.0;

  static const double _trunkScatterX = -0.45;
  static const double _trunkScatterY = 0.55;

  // ==========================================

  static const List<_TreePart> _parts = [
    _TreePart(
      id: 'leaves',
      asset: 'assets/images/objects/lagoon/t4_leaves.png',
      width: 1.0,
      height: 0.65,
      targetLeft: 0.0,
      targetTop: 0.0,
      scatterPosition: Alignment(-0.85, -0.8),
      scatterTilt: -0.08,
    ),
    _TreePart(
      id: 'branch',
      asset: 'assets/images/objects/lagoon/t3_branch.png',
      width: 0.388,
      height: 0.248,
      targetLeft: 0.310,
      targetTop: 0.434,
      scatterPosition: Alignment(0.9, -0.6),
      scatterTilt: 0.12,
    ),
    _TreePart(
      id: 'trunk',
      asset: 'assets/images/objects/lagoon/t2_trunk.png',
      width: 0.244,
      height: 0.30,
      targetLeft: 0.394,
      targetTop: 0.564,
      scatterPosition: Alignment(_trunkScatterX, _trunkScatterY),
      scatterTilt: -0.10,
    ),
    _TreePart(
      id: 'root',
      asset: 'assets/images/objects/lagoon/t1_root.png',
      width: 1.0,
      height: 0.20,
      targetLeft: 0.0,
      targetTop: 0.78,
      scatterPosition: Alignment(0.85, 0.85),
      scatterTilt: 0.07,
    ),
  ];

  final Set<String> _placed = {};

  // NEW: State variable to track when to show the prompt
  bool _showOverlay = false;

  bool get isCompleted => _placed.length == _parts.length;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
  }

  @override
  void dispose() {
    OrientationService.setPortrait();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgrounds/bg_lagoon_fields.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // 1. The Tree (Either Building Phase or Completed)
            isCompleted ? _buildCompletedTree() : _buildGameArea(),

            // 2. Kiki the Cat (Moved here so she never disappears)
            Align(
              alignment: const Alignment(_kikiAlignX, _kikiAlignY),
              child: Image.asset(
                'assets/images/characters/kiki_the_cat.png',
                height: _kikiHeight,
              ),
            ),

            // 3. The Delayed "Good Job" Overlay
            if (_showOverlay)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/kiki_the_cat.png',
                closeButtonColor: Colors.orange,
                onNext: () {
                  // TODO: Navigate to the next level
                },
                onRestart: () {
                  // Reset game
                  setState(() {
                    _placed.clear();
                    _showOverlay = false;
                  });
                },
                onBack: () {
                  // TODO: Pop screen or go home
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTree() {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final treeHeight = (constraints.maxHeight * 0.8).clamp(120.0, 350.0);
          return Center(child: Image.asset(_fullTreeAsset, height: treeHeight));
        },
      ),
    );
  }

  Widget _buildGameArea() {
    return SafeArea(
      child: Stack(
        children: [
          // Assembly area: fixed target rectangles for each piece.
          Center(
            child: SizedBox(
              width: _canvasWidth,
              height: _canvasHeight,
              child: Stack(
                children: [for (final part in _parts) _buildTarget(part)],
              ),
            ),
          ),

          // Scattered draggable pieces, each starting off in a corner
          for (final part in _parts)
            if (!_placed.contains(part.id))
              Align(
                alignment: part.scatterPosition,
                child: Transform.rotate(
                  angle: part.scatterTilt,
                  child: _buildDraggable(part),
                ),
              ),
        ],
      ),
    );
  }

  Widget _piece(_TreePart part) => Image.asset(
    part.asset,
    width: part.width * _canvasWidth,
    height: part.height * _canvasHeight,
    fit: BoxFit.contain,
  );

  Widget _buildDraggable(_TreePart part) {
    return Draggable<String>(
      data: part.id,
      feedback: Material(color: Colors.transparent, child: _piece(part)),
      childWhenDragging: Opacity(opacity: 0.3, child: _piece(part)),
      child: _piece(part),
    );
  }

  Widget _buildTarget(_TreePart part) {
    final boxWidth = part.width * _canvasWidth;
    final boxHeight = part.height * _canvasHeight;

    return Positioned(
      left: part.targetLeft * _canvasWidth,
      top: part.targetTop * _canvasHeight,
      width: boxWidth,
      height: boxHeight,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data == part.id,
        onAcceptWithDetails: (details) {
          setState(() {
            _placed.add(part.id);

            // Check if game was just completed
            if (_placed.length == _parts.length) {
              // Wait 2 seconds, then show the prompt
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() => _showOverlay = true);
                }
              });
            }
          });
        },
        builder: (context, candidateData, rejectedData) {
          final isPlaced = _placed.contains(part.id);
          final isTargeted = candidateData.isNotEmpty;
          return Container(
            decoration: isTargeted && !isPlaced
                ? BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  )
                : null,
            child: isPlaced ? _piece(part) : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
