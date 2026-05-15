import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- GENERIC THEME (Update later when you have your map theme!) ---
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

// --- DATA MODELS ---
class Habitat {
  final String id;
  final String imagePath;
  final String name;

  Habitat({required this.id, required this.imagePath, required this.name});
}

class Animal {
  final String name;
  final String imagePath;
  final String targetHabitatId;

  Animal({
    required this.name,
    required this.imagePath,
    required this.targetHabitatId,
  });
}

class AnimalHabitatMatchScreen extends StatefulWidget {
  const AnimalHabitatMatchScreen({super.key});

  @override
  State<AnimalHabitatMatchScreen> createState() =>
      _AnimalHabitatMatchScreenState();
}

class _AnimalHabitatMatchScreenState extends State<AnimalHabitatMatchScreen>
    with SingleTickerProviderStateMixin {
  bool _isMatched = false;
  int _currentAnimalIndex = 0;
  late final AnimationController _floatingController;

  // 1. Define the Habitats (The backgrounds they drag onto)
  final List<Habitat> _habitats = [
    Habitat(
      id: 'town',
      imagePath: 'assets/images/backgrounds/bg_town.png',
      name: 'Town',
    ),
    Habitat(
      id: 'arctic',
      imagePath: 'assets/images/backgrounds/bg_arctic.png',
      name: 'Arctic',
    ),
    Habitat(
      id: 'forest',
      imagePath: 'assets/images/backgrounds/bg_forest.png',
      name: 'Forest',
    ),
  ];

  // 2. Define the Animals (The sequence they will play through)
  // NOTE: Make sure you add dog.png and bear.png to your assets folder!
  late List<Animal> _animals;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    OrientationService.setLandscape();
    // Shuffle the animals so it's different every time they play!
    _animals = [
      Animal(
        name: 'Penguin',
        imagePath: 'assets/images/penguin.png',
        targetHabitatId: 'arctic',
      ),
      Animal(
        name: 'Dog',
        imagePath: 'assets/images/dog.png',
        targetHabitatId: 'town',
      ),
      Animal(
        name: 'Bear',
        imagePath: 'assets/images/bear.png',
        targetHabitatId: 'forest',
      ),
    ]..shuffle();

    // Floating animation for the animal
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    OrientationService.setLandscape();
    super.dispose();
  }

  void _showSuccessDialog() {
    bool isLast = _currentAnimalIndex == _animals.length - 1;
    final currentAnimal = _animals[_currentAnimalIndex];
    final correctHabitat = _habitats.firstWhere(
      (h) => h.id == currentAnimal.targetHabitatId,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Correct!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.success,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "The ${currentAnimal.name} lives in the ${correctHabitat.name}!",
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 22,
            color: ColorTheme.textDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isMatched = false;
                if (isLast) {
                  _currentAnimalIndex = 0; // Restart game
                  _animals.shuffle(); // Shuffle for the new round
                } else {
                  _currentAnimalIndex++; // Move to the next animal
                }
              });
            },
            child: Text(
              isLast ? "Play Again" : "Next Animal",
              style: const TextStyle(
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
    final currentAnimal = _animals[_currentAnimalIndex];

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
                    'Animal Habitats',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),

            // --- 3 HABITAT BACKGROUNDS (Drag Targets) ---
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: _habitats.map((habitat) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: DragTarget<String>(
                          onWillAcceptWithDetails: (details) =>
                              details.data == habitat.id,
                          onAcceptWithDetails: (details) {
                            setState(() {
                              _isMatched = true;
                            });
                            // Small delay before showing dialog so they see the animal land
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              _showSuccessDialog,
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            bool isHovering = candidateData.isNotEmpty;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isHovering
                                      ? ColorTheme.success
                                      : Colors.transparent,
                                  width: isHovering ? 6 : 0,
                                ),
                                boxShadow: [
                                  if (isHovering)
                                    BoxShadow(
                                      color: ColorTheme.success.withOpacity(
                                        0.6,
                                      ),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                ],
                                image: DecorationImage(
                                  image: AssetImage(habitat.imagePath),
                                  fit: BoxFit.cover,
                                  colorFilter: isHovering
                                      ? null
                                      : ColorFilter.mode(
                                          Colors.black.withOpacity(0.1),
                                          BlendMode.darken,
                                        ),
                                ),
                              ),
                              child:
                                  _isMatched &&
                                      currentAnimal.targetHabitatId ==
                                          habitat.id
                                  ? Center(
                                      child: Image.asset(
                                        currentAnimal.imagePath,
                                        height:
                                            120, // Size of animal when placed in habitat
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // --- DRAGGABLE ANIMAL AREA ---
            Expanded(
              flex: 2,
              child: Center(
                child: _isMatched
                    ? const SizedBox.shrink() // Hide when matched
                    : AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -10 * _floatingController.value),
                            child: child,
                          );
                        },
                        child: Draggable<String>(
                          data: currentAnimal
                              .targetHabitatId, // Passing the correct habitat ID
                          feedback: _DraggableAnimal(
                            imagePath: currentAnimal.imagePath,
                            isDragging: true,
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.0,
                            child: _DraggableAnimal(
                              imagePath: currentAnimal.imagePath,
                            ),
                          ),
                          child: _DraggableAnimal(
                            imagePath: currentAnimal.imagePath,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for the animal image
class _DraggableAnimal extends StatelessWidget {
  final String imagePath;
  final bool isDragging;

  const _DraggableAnimal({required this.imagePath, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: isDragging ? 1.2 : 1.0,
        child: Container(
          height: 140, // Height of the animal character
          decoration: BoxDecoration(
            boxShadow: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
