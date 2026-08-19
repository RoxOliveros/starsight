import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // Standard Flutter audio package
import 'package:StarSight/business_layer/orientation_service.dart';

class AnimalLifecycleGame extends StatefulWidget {
  const AnimalLifecycleGame({Key? key}) : super(key: key);

  @override
  _AnimalLifecycleGameState createState() => _AnimalLifecycleGameState();
}

class _AnimalLifecycleGameState extends State<AnimalLifecycleGame> {
  // Initialize the audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Track the current level (0 = First Seed, 1 = Strawberry, 2 = Mango)
  int currentLevelIndex = 0;
  bool isCorrect = false;
  late List<String> currentSequence;

  // The correct sequences for all levels
  final List<List<String>> allCorrectSequences = [
    [
      'assets/images/objects/lagoon/b1_egg.png',
      'assets/images/objects/lagoon/b2_caterpillar.png',
      'assets/images/objects/lagoon/b3_chrysalis.png',
      'assets/images/objects/lagoon/b4_butterfly.png',
    ],
    [
      'assets/images/objects/lagoon/fr1_egg.png',
      'assets/images/objects/lagoon/fr2_tadpoles.png',
      'assets/images/objects/lagoon/fr3_froglet.png',
      'assets/images/objects/lagoon/frog.png',
    ],
    [
      'assets/images/objects/lagoon/c1_egg.png',
      'assets/images/objects/lagoon/c2_chick.png',
      'assets/images/objects/lagoon/c3_hen.png',
      'assets/images/objects/lagoon/c4_chicken.png',
    ],
    [
      'assets/images/objects/lagoon/cow_1.png',
      'assets/images/objects/lagoon/cow_2.png',
      'assets/images/objects/lagoon/cow_3.png',
      'assets/images/objects/lagoon/cow_4.png',
    ],
  ];

  // The initial shuffled sequences for all levels
  final List<List<String>> allInitialSequences = [
    [
      'assets/images/objects/lagoon/b2_caterpillar.png',
      'assets/images/objects/lagoon/b4_butterfly.png',
      'assets/images/objects/lagoon/b1_egg.png',
      'assets/images/objects/lagoon/b3_chrysalis.png',
    ],
    [
      'assets/images/objects/lagoon/fr3_froglet.png',
      'assets/images/objects/lagoon/fr1_egg.png',
      'assets/images/objects/lagoon/frog.png',
      'assets/images/objects/lagoon/fr2_tadpoles.png',
    ],
    [
      'assets/images/objects/lagoon/c2_chick.png',
      'assets/images/objects/lagoon/c4_chicken.png',
      'assets/images/objects/lagoon/c1_egg.png',
      'assets/images/objects/lagoon/c3_hen.png',
    ],
    [
      'assets/images/objects/lagoon/cow_4.png',
      'assets/images/objects/lagoon/cow_1.png',
      'assets/images/objects/lagoon/cow_2.png',
      'assets/images/objects/lagoon/cow_3.png',
    ],
  ];

  @override
  void initState() {
    super.initState();
    // Load the first level's sequence on startup
    currentSequence = List.from(allInitialSequences[currentLevelIndex]);
    OrientationService.setLandscape();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _onItemDropped(int oldIndex, int newIndex) {
    // Prevent dragging if the current level is already solved and waiting to transition
    if (isCorrect) return;

    setState(() {
      final temp = currentSequence[oldIndex];
      currentSequence[oldIndex] = currentSequence[newIndex];
      currentSequence[newIndex] = temp;

      _checkWinCondition();
    });
  }

  void _checkWinCondition() {
    bool win = true;
    for (int i = 0; i < allCorrectSequences[currentLevelIndex].length; i++) {
      if (currentSequence[i] != allCorrectSequences[currentLevelIndex][i]) {
        win = false;
        break;
      }
    }

    setState(() {
      isCorrect = win;
    });

    if (isCorrect) {
      // Play the success sound effect
      // AssetSource automatically prefixes 'assets/', so this targets 'assets/audio/sound_effects/shine.wav'
      _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));

      // Progress to the next level if there are more levels remaining
      if (currentLevelIndex < allCorrectSequences.length - 1) {
        Future.delayed(const Duration(seconds: 2), () {
          // Prevent setting state if the widget was closed during the delay
          if (!mounted) return;

          setState(() {
            currentLevelIndex++;
            currentSequence = List.from(allInitialSequences[currentLevelIndex]);
            isCorrect = false; // Reset UI for the new level
          });
        });
      } else {
        // TODO: All levels completed. Trigger final celebration dialog or navigation here
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_rainbow_closeup2.png',
              fit: BoxFit.cover,
            ),
          ),

          // Universal Responsive Game Area
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Determine max size based on height and width to prevent overflow
                double maxByHeight = constraints.maxHeight * 0.45;
                double maxByWidth = constraints.maxWidth / 5.5;

                // Pick the smaller one to guarantee it fits entirely
                double universalCardSize = maxByHeight < maxByWidth
                    ? maxByHeight
                    : maxByWidth;

                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      height: universalCardSize,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(7, (index) {
                          if (index % 2 == 1) {
                            return _buildArrow(universalCardSize);
                          }
                          int cardIndex = index ~/ 2;
                          // Pass the exact card size down to prevent any squishing
                          return _buildDraggableSlot(
                            cardIndex,
                            universalCardSize,
                          );
                        }),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow(double height) {
    return Visibility(
      visible: isCorrect,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: height * 0.3,
          color: const Color(0xFF3E2723),
        ),
      ),
    );
  }

  Widget _buildDraggableSlot(int index, double cardSize) {
    return DragTarget<int>(
      onAccept: (draggedIndex) => _onItemDropped(draggedIndex, index),
      builder: (context, candidateData, rejectedData) {
        return Draggable<int>(
          data: index,
          // Disable dragging if the sequence is solved and waiting to transition
          maxSimultaneousDrags: isCorrect ? 0 : 1,
          feedback: Material(
            color: Colors.transparent,
            child: _buildCardUI(currentSequence[index], true, cardSize),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _buildCardUI(currentSequence[index], false, cardSize),
          ),
          child: _buildCardUI(currentSequence[index], false, cardSize),
        );
      },
    );
  }

  Widget _buildCardUI(String imagePath, bool isDragging, double cardSize) {
    return SizedBox(
      width: cardSize,
      height: cardSize,
      child: Container(
        margin: const EdgeInsets.all(6.0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect ? const Color(0xFF81C784) : Colors.grey.shade500,
            width: 5,
          ),
          color: Colors.white,
          boxShadow: isDragging
              ? [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
