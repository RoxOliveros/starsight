import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';

class LunchboxGame extends StatefulWidget {
  const LunchboxGame({Key? key}) : super(key: key);

  @override
  State<LunchboxGame> createState() => _LunchboxGameState();
}

class _LunchboxGameState extends State<LunchboxGame> {
  // Track current progression stage
  int currentBatch = 1;

  // Track which foods are in which compartments
  String? leftCompartmentFoodId;
  String? topRightCompartmentFoodId;

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

  // Helper method to get the correct image asset based on the ID
  String getFoodAsset(String id) {
    switch (id) {
      // Batch 1
      case 'pizza':
        return 'assets/images/objects/lagoon/pizza_colored.png';
      case 'rice':
        return 'assets/images/objects/lagoon/rice.png';
      case 'fries':
        return 'assets/images/objects/lagoon/fries.png';
      // Batch 2 (Adjust these filenames to match your assets!)
      case 'drumstick':
        return 'assets/images/objects/lagoon/drumstick.png';
      case 'chips':
        return 'assets/images/objects/lagoon/chips.png';
      case 'fish':
        return 'assets/images/objects/lagoon/cooked_fish.png';
      case 'cookie':
        return 'assets/images/objects/lagoon/cookie.png';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;

          return Stack(
            children: [
              // 1. Background Table
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_table.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Center Lunchbox with Multiple Drop Zones
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: screenWidth * 0.45,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Lunchbox Graphic
                      Image.asset(
                        'assets/images/objects/lagoon/lunchbox.png',
                        width: screenWidth * 0.45,
                        fit: BoxFit.contain,
                      ),

                      // --- DROP ZONE 1: Left Compartment ---
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: screenWidth * 0.025),
                            child: FractionallySizedBox(
                              widthFactor: 0.48,
                              heightFactor: 0.8,
                              child: DragTarget<String>(
                                builder:
                                    (context, candidateData, rejectedData) {
                                      return Container(
                                        alignment: Alignment.center,
                                        child: leftCompartmentFoodId != null
                                            ? Image.asset(
                                                getFoodAsset(
                                                  leftCompartmentFoodId!,
                                                ),
                                                width: screenWidth * 0.15,
                                                fit: BoxFit.contain,
                                              )
                                            : null,
                                      );
                                    },
                                onAccept: (data) {
                                  // Only accept in left compartment if we are on Batch 1
                                  if (currentBatch == 1) {
                                    setState(() {
                                      leftCompartmentFoodId = data;
                                      currentBatch = 2; // Move to next batch
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // --- DROP ZONE 2: Top Right Compartment ---
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: screenWidth * 0.025,
                              right: screenWidth * 0.025,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: 0.48,
                              heightFactor: 0.45,
                              child: DragTarget<String>(
                                builder:
                                    (context, candidateData, rejectedData) {
                                      return Container(
                                        alignment: Alignment.center,
                                        child: topRightCompartmentFoodId != null
                                            ? Image.asset(
                                                getFoodAsset(
                                                  topRightCompartmentFoodId!,
                                                ),
                                                width: screenWidth * 0.12,
                                                fit: BoxFit.contain,
                                              )
                                            : null,
                                      );
                                    },
                                onAccept: (data) {
                                  // Only accept in top-right compartment if we are on Batch 2
                                  if (currentBatch == 2) {
                                    setState(() {
                                      topRightCompartmentFoodId = data;
                                      // Optional: currentBatch = 3; for the final compartment
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- BATCH 1 FOODS ---
              if (currentBatch == 1) ...[
                // Left side: Pizza on Plate
                Align(
                  alignment: const Alignment(-1.0, 0.0),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('pizza'),
                    foodId: 'pizza',
                    size: screenWidth * 0.22,
                  ),
                ),
                // Top Right: Rice on Plate
                Align(
                  alignment: const Alignment(0.85, -0.65),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('rice'),
                    foodId: 'rice',
                    size: screenWidth * 0.20,
                    foodScale: 0.85,
                  ),
                ),
                // Bottom Right: Fries
                Align(
                  alignment: const Alignment(0.8, 0.75),
                  child: DraggableFood(
                    foodAsset: getFoodAsset('fries'),
                    foodId: 'fries',
                    size: screenWidth * 0.15,
                    isTilted: true,
                    tiltAngle: -0.20,
                  ),
                ),
              ],

              // --- BATCH 2 FOODS ---
              if (currentBatch == 2) ...[
                // Top Left: drumstick on Plate
                Align(
                  alignment: const Alignment(-0.8, -0.3),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('drumstick'),
                    foodId: 'drumstick',
                    size: screenWidth * 0.22,
                    isTilted:
                        true, // Tilts the draggable food item on the plate
                    tiltAngle: -0.3,
                    isVisible: topRightCompartmentFoodId != 'drumstick',
                  ),
                ),
                // Bottom Left: Chips (No plate)
                Align(
                  alignment: const Alignment(-0.8, 0.75),
                  child: topRightCompartmentFoodId != 'chips'
                      ? DraggableFood(
                          foodAsset: getFoodAsset('chips'),
                          foodId: 'chips',
                          size: screenWidth * 0.15,
                          isTilted: true,
                          tiltAngle: -0.15,
                        )
                      : SizedBox(width: screenWidth * 0.15),
                ),
                // Top Right: Fish on Plate
                Align(
                  alignment: const Alignment(0.85, -0.65),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('fish'),
                    foodId: 'fish',
                    size: screenWidth * 0.20,
                    foodScale: 0.85,
                    isVisible: topRightCompartmentFoodId != 'fish',
                  ),
                ),
                // Bottom Right: Cookie on Plate
                Align(
                  alignment: const Alignment(0.85, 0.65),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('cookie'),
                    foodId: 'cookie',
                    size: screenWidth * 0.20,
                    foodScale: 0.85,
                    isVisible: topRightCompartmentFoodId != 'cookie',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A reusable widget to stack draggable food items on top of the static plate graphic
class PlateWithFood extends StatelessWidget {
  final String foodAsset;
  final String foodId;
  final double size;
  final double foodScale;
  final bool isVisible;
  final bool isTilted;
  final double tiltAngle;

  const PlateWithFood({
    Key? key,
    required this.foodAsset,
    required this.foodId,
    required this.size,
    this.foodScale = 0.75,
    this.isVisible = true,
    this.isTilted = false,
    this.tiltAngle = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base Plate (Static, does not move)
          Image.asset(
            'assets/images/objects/lagoon/plate_top.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
          // Food Item
          if (isVisible)
            DraggableFood(
              foodAsset: foodAsset,
              foodId: foodId,
              size: size * foodScale,
              isTilted: isTilted,
              tiltAngle: tiltAngle,
            ),
        ],
      ),
    );
  }
}

/// The core logic for making the food images draggable
class DraggableFood extends StatelessWidget {
  final String foodAsset;
  final String foodId;
  final double size;
  final bool isTilted;
  final double tiltAngle;

  const DraggableFood({
    Key? key,
    required this.foodAsset,
    required this.foodId,
    required this.size,
    this.isTilted = false,
    this.tiltAngle = -0.20, // Default negative radians for a leftward tilt
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. Setup the food image
    Widget foodImage = Image.asset(
      foodAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    // 2. Apply tilt if requested
    if (isTilted) {
      foodImage = Transform.rotate(angle: tiltAngle, child: foodImage);
    }

    // 3. Make it draggable
    return Draggable<String>(
      data: foodId,
      feedback: Material(color: Colors.transparent, child: foodImage),
      childWhenDragging: SizedBox(width: size, height: size),
      child: foodImage,
    );
  }
}
