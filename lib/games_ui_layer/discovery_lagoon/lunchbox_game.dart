import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart'; // <-- Imported your existing overlay here
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// ==========================================
// DATA MODELS
// ==========================================

/// Data Model for the freehand drawing
class SauceStroke {
  final String sauceId;
  final List<Offset> points;

  SauceStroke({required this.sauceId, required this.points});
}

// ==========================================
// INTRO SCREEN
// ==========================================

class LunchboxGameIntro extends StatefulWidget {
  const LunchboxGameIntro({Key? key}) : super(key: key);

  @override
  State<LunchboxGameIntro> createState() => _LunchboxGameIntroState();
}

class _LunchboxGameIntroState extends State<LunchboxGameIntro> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _playIntroAudio();

    // Listen for the audio to finish playing, then automatically start the game
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        _startGame();
      }
    });
  }

  Future<void> _playIntroAudio() async {
    // Plays the audio file from your assets folder
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/lunchboxgame_intro.wav'),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _startGame() {
    _audioPlayer.stop();
    // Navigate to the main LunchboxGame screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LunchboxGame()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          return Stack(
            children: [
              // 1. Background (Rainbow Lagoon)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_rainbow_closeup2.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Kiki (Left Side)
              Positioned(
                bottom: -screenHeight * 0.15,
                left: screenWidth * 0.02,
                child: Image.asset(
                  'assets/images/characters/kiki_the_cat.png',
                  height: screenHeight * 1.00,
                  fit: BoxFit.contain,
                ),
              ),

              // 3. Roxie (Right Side)
              Positioned(
                bottom: -screenHeight * 0.15,
                right: screenWidth * 0.02,
                child: Image.asset(
                  'assets/images/characters/roxie_standing.png',
                  height: screenHeight * 1.00,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// UNHEALTHY ENDING SCREEN
// ==========================================

class LunchboxGameUnhealthyEnding extends StatefulWidget {
  const LunchboxGameUnhealthyEnding({Key? key}) : super(key: key);

  @override
  State<LunchboxGameUnhealthyEnding> createState() =>
      _LunchboxGameUnhealthyEndingState();
}

class _LunchboxGameUnhealthyEndingState
    extends State<LunchboxGameUnhealthyEnding> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showSadRoxie = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _playEndingSequence();
  }

  Future<void> _playEndingSequence() async {
    // Play the wrong ending audio
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/lunchboxgame_wrong_ending.wav'),
    );

    // After 4 seconds, change Roxie to sad and show the restart button
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showSadRoxie = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _restartGame() {
    _audioPlayer.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LunchboxGameIntro()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          return Stack(
            children: [
              // 1. Background (Rainbow Lagoon)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_rainbow_closeup2.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Kiki (Left Side)
              Positioned(
                bottom: -screenHeight * 0.15,
                left: screenWidth * 0.02,
                child: Image.asset(
                  'assets/images/characters/kiki_the_cat.png',
                  height: screenHeight * 1.00,
                  fit: BoxFit.contain,
                ),
              ),

              // 3. Roxie holding the closed Lunchbox (Right Side)
              Positioned(
                bottom: -screenHeight * 0.15,
                right: screenWidth * 0.02,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Swap between standing and sad Roxie based on the 4-second timer
                    Image.asset(
                      _showSadRoxie
                          ? 'assets/images/characters/roxie_sad.png'
                          : 'assets/images/characters/roxie_standing.png',
                      height: screenHeight * 1.00,
                      fit: BoxFit.contain,
                    ),
                    // The lunchbox positioned in her left hand
                    Positioned(
                      bottom: screenHeight * 0.15,
                      left: screenWidth * 0.07,
                      child: Image.asset(
                        'assets/images/objects/lagoon/lunchbox_closed.png',
                        width: screenWidth * 0.13,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Try Again / Restart Button (Pops up in center)
              if (_showSadRoxie)
                Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: _restartGame,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/buttons/restart.png',
                        width: screenWidth * 0.15,
                        height: screenWidth * 0.15,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// HEALTHY ENDING SCREEN
// ==========================================

class LunchboxGameHealthyEnding extends StatefulWidget {
  const LunchboxGameHealthyEnding({Key? key}) : super(key: key);

  @override
  State<LunchboxGameHealthyEnding> createState() =>
      _LunchboxGameHealthyEndingState();
}

class _LunchboxGameHealthyEndingState extends State<LunchboxGameHealthyEnding> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _playEndingSequence();

    // Listen for the audio to finish playing, then show the GoodJobOverlay
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _showOverlay = true;
        });
      }
    });
  }

  Future<void> _playEndingSequence() async {
    // Play the right ending audio
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/lunchboxgame_right_ending.wav'),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _restartGame() {
    _audioPlayer.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LunchboxGameIntro()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          return Stack(
            children: [
              // 1. Background (Rainbow Lagoon)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_rainbow_closeup2.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Kiki Smiling (Left Side)
              Positioned(
                bottom: -screenHeight * 0.15,
                left: screenWidth * 0.02,
                child: Image.asset(
                  'assets/images/characters/kiki_smiling.png',
                  height: screenHeight * 1.00,
                  fit: BoxFit.contain,
                ),
              ),

              // 3. Roxie Smiling/Happy (Right Side)
              Positioned(
                bottom: -screenHeight * 0.15,
                right: screenWidth * 0.02,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/images/characters/roxie_try_again.png',
                      height: screenHeight * 1.00,
                      fit: BoxFit.contain,
                    ),
                    // The lunchbox positioned in her left hand (viewer's right)
                    Positioned(
                      bottom: screenHeight * 0.15,
                      left: screenWidth * 0.07,
                      child: Image.asset(
                        'assets/images/objects/lagoon/lunchbox_closed.png',
                        width: screenWidth * 0.13,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Good Job Overlay Triggered
              if (_showOverlay)
                Positioned.fill(
                  child: GoodJobOverlay(
                    characterImage:
                        'assets/images/characters/kiki_tryagain.png',
                    closeButtonColor: Colors.deepOrange,
                    onNext: _restartGame,
                    onRestart: _restartGame,
                    onBack: _restartGame,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// MAIN GAME SCREEN
// ==========================================

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
  String? bottomRightCompartmentFoodId;

  // Batch 4: Freehand drawing variables
  String? activeSauceId;
  List<SauceStroke> sauceStrokes = [];
  SauceStroke? currentStroke;

  // Batch 5: Dessert selection
  String? selectedDessertId;

  // Batch 6: Drink selection
  String? selectedDrinkId;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  // Helper method to evaluate if the lunchbox is unhealthy
  void _evaluateLunchbox() {
    // List of everything considered unhealthy
    final List<String> unhealthyItems = [
      'pizza',
      'fries',
      'drumstick',
      'chips',
      'cookie',
      'bacon',
      'chocolate',
      'coffee',
      'chocomilk',
    ];

    // Check if ANY of the selected items fall into the unhealthy list
    bool isUnhealthy = [
      leftCompartmentFoodId,
      topRightCompartmentFoodId,
      bottomRightCompartmentFoodId,
      selectedDessertId,
      selectedDrinkId,
    ].any((item) => unhealthyItems.contains(item));

    if (isUnhealthy) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LunchboxGameUnhealthyEnding(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LunchboxGameHealthyEnding(),
        ),
      );
    }
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
      // Batch 2
      case 'drumstick':
        return 'assets/images/objects/lagoon/drumstick.png';
      case 'chips':
        return 'assets/images/objects/lagoon/chips.png';
      case 'fish':
        return 'assets/images/objects/lagoon/cooked_fish.png';
      case 'cookie':
        return 'assets/images/objects/lagoon/cookie.png';
      // Batch 3
      case 'lettuce':
        return 'assets/images/objects/lagoon/lettuce.png';
      case 'broccoli':
        return 'assets/images/objects/lagoon/broccoli.png';
      case 'bacon':
        return 'assets/images/objects/lagoon/bacon.png';
      // Batch 5 (Desserts)
      case 'chocolate':
        return 'assets/images/objects/lagoon/chocolate.png';
      case 'banana':
        return 'assets/images/objects/lagoon/banana_colored.png';
      case 'strawberry':
        return 'assets/images/objects/lagoon/strawberry.png';
      case 'orange':
        return 'assets/images/objects/lagoon/orange.png';
      // Batch 6 (Drinks)
      case 'coffee':
        return 'assets/images/objects/lagoon/coffee.png';
      case 'water':
        return 'assets/images/objects/lagoon/water.png';
      case 'chocomilk':
        return 'assets/images/objects/lagoon/chocolatedrink.png';
      case 'orangejuice':
        return 'assets/images/objects/lagoon/orangejuice.png';
      default:
        return '';
    }
  }

  // Helper method to get the correct sauce bottle asset
  String getSauceAsset(String id) {
    switch (id) {
      case 'ketchup':
        return 'assets/images/objects/lagoon/ketchup.png';
      case 'mustard':
        return 'assets/images/objects/lagoon/mustard.png';
      case 'mayo':
        return 'assets/images/objects/lagoon/mayonnaise.png';
      default:
        return '';
    }
  }

  // Helper to build the 3-broccoli group
  Widget _buildBroccoliGroup(double size) {
    double childSize = size * 0.65;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Transform.rotate(
              angle: -0.20,
              child: Image.asset(getFoodAsset('broccoli'), width: childSize),
            ),
          ),
          Positioned(
            right: 0,
            top: size * 0.05,
            child: Image.asset(getFoodAsset('broccoli'), width: childSize),
          ),
          Positioned(
            bottom: 0,
            child: Image.asset(getFoodAsset('broccoli'), width: childSize),
          ),
        ],
      ),
    );
  }

  // Helper method to render the dropped food with its correct rotation
  Widget _buildDroppedFood(String id, double size) {
    double finalSize = size;
    if (id == 'cookie')
      finalSize = size * 0.8;
    else if (id == 'lettuce' || id == 'broccoli' || id == 'chips')
      finalSize = size * 0.75;

    if (id == 'broccoli') return _buildBroccoliGroup(finalSize);

    Widget img = Image.asset(
      getFoodAsset(id),
      width: finalSize,
      fit: BoxFit.contain,
    );
    if (id == 'chips')
      img = Transform.rotate(angle: -1.57, child: img);
    else if (id == 'fries')
      img = Transform.rotate(angle: -0.20, child: img);
    else if (id == 'drumstick')
      img = Transform.rotate(angle: -0.3, child: img);

    return img;
  }

  // Helper to build the selectable dessert items for Batch 5
  Widget _buildDessertOption(String id, Alignment alignment, double size) {
    final isSelected = selectedDessertId == id;
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: () {
          setState(() => selectedDessertId = id);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => currentBatch = 6);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isSelected ? size * 1.15 : size,
          height: isSelected ? size * 1.15 : size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.all(6.0),
          child: Image.asset(getFoodAsset(id), fit: BoxFit.contain),
        ),
      ),
    );
  }

  // Helper to build the selectable drink items for Batch 6
  Widget _buildDrinkOption(String id, Alignment alignment, double size) {
    final isSelected = selectedDrinkId == id;
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: () {
          setState(() => selectedDrinkId = id);

          // Tiny delay so the user sees the glow animation before evaluating
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              _evaluateLunchbox();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isSelected ? size * 1.15 : size,
          height: isSelected ? size * 1.15 : size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.all(6.0),
          child: Image.asset(getFoodAsset(id), fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final plateSize = screenWidth * 0.18;
          final droppedFoodSize = screenWidth * 0.15;

          return Stack(
            children: [
              // 1. Background Table
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_table.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Center Lunchbox with Multiple Drop Zones & Canvas Overlay
              if (currentBatch < 5)
                Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onPanStart: currentBatch == 4 && activeSauceId != null
                        ? (details) => setState(() {
                            currentStroke = SauceStroke(
                              sauceId: activeSauceId!,
                              points: [details.localPosition],
                            );
                            sauceStrokes.add(currentStroke!);
                          })
                        : null,
                    onPanUpdate: currentBatch == 4 && activeSauceId != null
                        ? (details) {
                            if (currentStroke != null)
                              setState(
                                () => currentStroke!.points.add(
                                  details.localPosition,
                                ),
                              );
                          }
                        : null,
                    onPanEnd: currentBatch == 4 && activeSauceId != null
                        ? (details) => currentStroke = null
                        : null,
                    child: SizedBox(
                      width: screenWidth * 0.45,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
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
                                padding: EdgeInsets.only(
                                  left: screenWidth * 0.025,
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: 0.48,
                                  heightFactor: 0.8,
                                  child: DragTarget<String>(
                                    builder:
                                        (
                                          context,
                                          candidateData,
                                          rejectedData,
                                        ) => Container(
                                          alignment: Alignment.center,
                                          child: leftCompartmentFoodId != null
                                              ? _buildDroppedFood(
                                                  leftCompartmentFoodId!,
                                                  droppedFoodSize,
                                                )
                                              : null,
                                        ),
                                    onAccept: (data) {
                                      if (currentBatch == 1)
                                        setState(() {
                                          leftCompartmentFoodId = data;
                                          currentBatch = 2;
                                        });
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
                                  top: screenWidth * 0.085,
                                  right: screenWidth * 0.04,
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: 0.45,
                                  heightFactor: 0.40,
                                  child: DragTarget<String>(
                                    builder:
                                        (
                                          context,
                                          candidateData,
                                          rejectedData,
                                        ) => Container(
                                          alignment: Alignment.center,
                                          child:
                                              topRightCompartmentFoodId != null
                                              ? _buildDroppedFood(
                                                  topRightCompartmentFoodId!,
                                                  droppedFoodSize,
                                                )
                                              : null,
                                        ),
                                    onAccept: (data) {
                                      if (currentBatch == 2)
                                        setState(() {
                                          topRightCompartmentFoodId = data;
                                          currentBatch = 3;
                                        });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // --- DROP ZONE 3: Bottom Right Compartment ---
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: screenWidth * 0.08,
                                  right: screenWidth * 0.04,
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: 0.45,
                                  heightFactor: 0.40,
                                  child: DragTarget<String>(
                                    builder:
                                        (
                                          context,
                                          candidateData,
                                          rejectedData,
                                        ) => Container(
                                          alignment: Alignment.center,
                                          child:
                                              bottomRightCompartmentFoodId !=
                                                  null
                                              ? _buildDroppedFood(
                                                  bottomRightCompartmentFoodId!,
                                                  droppedFoodSize,
                                                )
                                              : null,
                                        ),
                                    onAccept: (data) {
                                      if (currentBatch == 3)
                                        setState(() {
                                          bottomRightCompartmentFoodId = data;
                                          currentBatch = 4;
                                        });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // --- THE CANVAS OVERLAY FOR SAUCE ---
                          if (currentBatch == 4)
                            Positioned.fill(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.015,
                                  vertical: screenWidth * 0.02,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.04,
                                  ),
                                  child: CustomPaint(
                                    painter: FreehandSaucePainter(
                                      strokes: sauceStrokes,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              // --- BATCH 1 FOODS ---
              if (currentBatch == 1) ...[
                Align(
                  alignment: const Alignment(-0.9, 0.0),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('pizza'),
                    foodId: 'pizza',
                    size: plateSize,
                    foodScale: 0.9,
                  ),
                ),
                Align(
                  alignment: const Alignment(0.85, -0.65),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('rice'),
                    foodId: 'rice',
                    size: plateSize,
                    foodScale: 0.9,
                  ),
                ),
                Align(
                  alignment: const Alignment(0.8, 0.75),
                  child: DraggableFood(
                    foodAsset: getFoodAsset('fries'),
                    foodId: 'fries',
                    size: plateSize * 0.85,
                    isTilted: true,
                    tiltAngle: -0.20,
                  ),
                ),
              ],

              // --- BATCH 2 FOODS ---
              if (currentBatch == 2) ...[
                Align(
                  alignment: const Alignment(-0.85, -0.3),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('drumstick'),
                    foodId: 'drumstick',
                    size: plateSize,
                    foodScale: 0.9,
                    isTilted: true,
                    tiltAngle: -0.3,
                    isVisible: topRightCompartmentFoodId != 'drumstick',
                  ),
                ),
                Align(
                  alignment: const Alignment(-0.85, 0.75),
                  child: topRightCompartmentFoodId != 'chips'
                      ? DraggableFood(
                          foodAsset: getFoodAsset('chips'),
                          foodId: 'chips',
                          size: plateSize * 0.85,
                          isTilted: true,
                          tiltAngle: -1.57,
                        )
                      : SizedBox(width: plateSize * 0.85),
                ),
                Align(
                  alignment: const Alignment(0.85, -0.65),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('fish'),
                    foodId: 'fish',
                    size: plateSize,
                    foodScale: 0.9,
                    isVisible: topRightCompartmentFoodId != 'fish',
                  ),
                ),
                Align(
                  alignment: const Alignment(0.85, 0.65),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('cookie'),
                    foodId: 'cookie',
                    size: plateSize,
                    foodScale: 0.8,
                    isVisible: topRightCompartmentFoodId != 'cookie',
                  ),
                ),
              ],

              // --- BATCH 3 FOODS ---
              if (currentBatch == 3) ...[
                Align(
                  alignment: const Alignment(-0.85, -0.3),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('lettuce'),
                    foodId: 'lettuce',
                    size: plateSize,
                    foodScale: 0.85,
                    isVisible: bottomRightCompartmentFoodId != 'lettuce',
                  ),
                ),
                Align(
                  alignment: const Alignment(-0.85, 0.75),
                  child: bottomRightCompartmentFoodId != 'chips'
                      ? DraggableFood(
                          foodAsset: getFoodAsset('chips'),
                          foodId: 'chips',
                          size: plateSize * 0.85,
                          isTilted: true,
                          tiltAngle: -1.57,
                        )
                      : SizedBox(width: plateSize * 0.85),
                ),
                Align(
                  alignment: const Alignment(0.85, -0.65),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('broccoli'),
                    foodId: 'broccoli',
                    size: plateSize,
                    foodScale: 0.9,
                    isVisible: bottomRightCompartmentFoodId != 'broccoli',
                  ),
                ),
                Align(
                  alignment: const Alignment(0.85, 0.65),
                  child: PlateWithFood(
                    foodAsset: getFoodAsset('bacon'),
                    foodId: 'bacon',
                    size: plateSize,
                    foodScale: 0.8,
                    isVisible: bottomRightCompartmentFoodId != 'bacon',
                  ),
                ),
              ],

              // --- BATCH 4: SELECTABLE SAUCE BOTTLES & "DONE" BUTTON ---
              if (currentBatch == 4) ...[
                Align(
                  alignment: const Alignment(0.62, 0.05),
                  child: SauceBottleSelector(
                    sauceId: 'ketchup',
                    assetPath: getSauceAsset('ketchup'),
                    size: plateSize * 0.8,
                    isActive: activeSauceId == 'ketchup',
                    onTap: () => setState(() => activeSauceId = 'ketchup'),
                  ),
                ),
                Align(
                  alignment: const Alignment(0.9, -0.55),
                  child: SauceBottleSelector(
                    sauceId: 'mustard',
                    assetPath: getSauceAsset('mustard'),
                    size: plateSize * 0.8,
                    isActive: activeSauceId == 'mustard',
                    onTap: () => setState(() => activeSauceId = 'mustard'),
                  ),
                ),
                Align(
                  alignment: const Alignment(0.9, 0.6),
                  child: SauceBottleSelector(
                    sauceId: 'mayo',
                    assetPath: getSauceAsset('mayo'),
                    size: plateSize * 0.8,
                    isActive: activeSauceId == 'mayo',
                    onTap: () => setState(() => activeSauceId = 'mayo'),
                  ),
                ),
                Positioned(
                  bottom: screenWidth * 0.05,
                  left: screenWidth * 0.05,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => setState(() => currentBatch = 5),
                    child: const Text('Ready for Dessert!'),
                  ),
                ),
              ],

              // --- BATCH 5: FINAL DESSERT SELECTION ---
              if (currentBatch == 5) ...[
                _buildDessertOption(
                  'chocolate',
                  const Alignment(-0.80, -0.50),
                  plateSize * 1.0,
                ),
                _buildDessertOption(
                  'cookie',
                  const Alignment(-0.20, -0.30),
                  plateSize * 1.0,
                ),
                _buildDessertOption(
                  'orange',
                  const Alignment(0.60, -0.60),
                  plateSize * 1.0,
                ),
                _buildDessertOption(
                  'banana',
                  const Alignment(-0.60, 0.70),
                  plateSize * 1.0,
                ),
                _buildDessertOption(
                  'strawberry',
                  const Alignment(0.20, 0.80),
                  plateSize * 1.0,
                ),
                _buildDessertOption(
                  'fries',
                  const Alignment(0.80, 0.60),
                  plateSize * 1.0,
                ),
              ],

              // --- BATCH 6: FINAL DRINK SELECTION ---
              if (currentBatch == 6) ...[
                _buildDrinkOption(
                  'coffee',
                  const Alignment(-0.75, 0.0),
                  plateSize * 1.2,
                ),
                _buildDrinkOption(
                  'water',
                  const Alignment(-0.25, 0.0),
                  plateSize * 1.2,
                ),
                _buildDrinkOption(
                  'chocomilk',
                  const Alignment(0.25, 0.0),
                  plateSize * 1.2,
                ),
                _buildDrinkOption(
                  'orangejuice',
                  const Alignment(0.75, 0.0),
                  plateSize * 1.2,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// SHARED WIDGETS
// ==========================================

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
          Image.asset(
            'assets/images/objects/lagoon/plate_top.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
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
    this.tiltAngle = -0.20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget foodImage;
    if (foodId == 'broccoli') {
      double childSize = size * 0.65;
      foodImage = SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Transform.rotate(
                angle: -0.20,
                child: Image.asset(foodAsset, width: childSize),
              ),
            ),
            Positioned(
              right: 0,
              top: size * 0.05,
              child: Image.asset(foodAsset, width: childSize),
            ),
            Positioned(
              bottom: 0,
              child: Image.asset(foodAsset, width: childSize),
            ),
          ],
        ),
      );
    } else {
      foodImage = Image.asset(
        foodAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    if (isTilted)
      foodImage = Transform.rotate(angle: tiltAngle, child: foodImage);

    return Draggable<String>(
      data: foodId,
      feedback: Material(color: Colors.transparent, child: foodImage),
      childWhenDragging: SizedBox(width: size, height: size),
      child: foodImage,
    );
  }
}

class SauceBottleSelector extends StatelessWidget {
  final String sauceId;
  final String assetPath;
  final double size;
  final bool isActive;
  final VoidCallback onTap;

  const SauceBottleSelector({
    Key? key,
    required this.sauceId,
    required this.assetPath,
    required this.size,
    required this.isActive,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: isActive ? size * 1.15 : size,
        height: isActive ? size * 1.15 : size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }
}

class FreehandSaucePainter extends CustomPainter {
  final List<SauceStroke> strokes;

  FreehandSaucePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      Color fillColor;
      switch (stroke.sauceId) {
        case 'ketchup':
          fillColor = const Color(0xFFE0392B);
          break;
        case 'mustard':
          fillColor = const Color(0xFFF2B705);
          break;
        case 'mayo':
          fillColor = const Color(0xFFFFF6E0);
          break;
        default:
          fillColor = Colors.transparent;
      }
      final hsl = HSLColor.fromColor(fillColor);
      final outlineColor = hsl
          .withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0))
          .toColor();

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      final outlinePaint = Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, outlinePaint);
      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FreehandSaucePainter oldDelegate) => true;
}
