import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';

class PickingTrashGame extends StatefulWidget {
  const PickingTrashGame({Key? key}) : super(key: key);

  @override
  State<PickingTrashGame> createState() => _PickingTrashGameState();
}

class _PickingTrashGameState extends State<PickingTrashGame> {
  // ==========================================
  // ADJUSTERS: Tweak positions and sizes here!
  // x: 0.0 (left) to 1.0 (right)
  // y: 0.0 (top) to 1.0 (bottom)
  // size: percentage of screen width (e.g., 0.05 is 5%)
  // ==========================================
  final List<TrashItemData> trashItems = [
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_apple.png',
      x: 0.00,
      y: 0.68,
      size: 0.08,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_chips2.png',
      x: 0.10,
      y: 0.83,
      size: 0.10,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_garbagebag2.png',
      x: 0.10,
      y: 0.38,
      size: 0.10,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_styro.png',
      x: 0.21,
      y: 0.39,
      size: 0.075,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_banana.png',
      x: 0.27,
      y: 0.40,
      size: 0.07,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_spoon.png',
      x: 0.35,
      y: 0.49,
      size: 0.06,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_plasticbag.png',
      x: 0.25,
      y: 0.58,
      size: 0.11,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_chips1.png',
      x: 0.26,
      y: 0.85,
      size: 0.08,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_sodacan.png',
      x: 0.42,
      y: 0.46,
      size: 0.07,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_stick.png',
      x: 0.40,
      y: 0.55,
      size: 0.12,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_plastic1.png',
      x: 0.46,
      y: 0.78,
      size: 0.08,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_waterbottle.png',
      x: 0.53,
      y: 0.63,
      size: 0.09,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_drink.png',
      x: 0.58,
      y: 0.36,
      size: 0.03,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_leaf.png',
      x: 0.62,
      y: 0.50,
      size: 0.09,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_garbagebag1.png',
      x: 0.79,
      y: 0.54,
      size: 0.06,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_glassbottle.png',
      x: 0.84,
      y: 0.48,
      size: 0.06,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_fishbone.png',
      x: 0.67,
      y: 0.76,
      size: 0.07,
    ),
    TrashItemData(
      image: 'assets/images/objects/lumi/trash_rug.png',
      x: 0.90,
      y: 0.82,
      size: 0.09,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Force landscape mode when this level loads
    OrientationService.setLandscape();
  }

  @override
  void dispose() {
    // Optional: Return to portrait when leaving this screen
    // OrientationService.setPortrait();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions to calculate relative positions
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_park_sunny.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Trash Assets Overlay
          ...trashItems.map((item) {
            return Positioned(
              left: screenSize.width * item.x,
              top: screenSize.height * item.y,
              width: screenSize.width * item.size,
              // Using a GestureDetector early so it's ready for your logic later
              child: GestureDetector(
                onTap: () {
                  // TODO: Add logic here later (e.g., removing the item)
                  print('${item.image} tapped!');
                },
                child: Image.asset(item.image, fit: BoxFit.contain),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// Simple data class to hold the properties for each trash item
class TrashItemData {
  final String image;
  final double x;
  final double y;
  final double size;

  TrashItemData({
    required this.image,
    required this.x,
    required this.y,
    required this.size,
  });
}
