import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/bodyparts_assembly.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // Standard Flutter audio package
import 'package:StarSight/business_layer/orientation_service.dart';
import '../goodjob_prompt.dart';

class SeedGame extends StatefulWidget {
  const SeedGame({Key? key}) : super(key: key);

  @override
  _SeedGameState createState() => _SeedGameState();
}

class _SeedGameState extends State<SeedGame> {
  // Initialize the audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Intro & End state
  bool showIntro = true;
  bool showGoodJob = false;

  // ==========================================
  // 🛠️ KIKI VERTICAL ADJUSTER
  // Change this value to move Kiki manually.
  // Negative values (e.g., -20.0) move him UP.
  // Positive values (e.g., 20.0) move him DOWN.
  // ==========================================
  final double kikiVerticalOffset = 40.0;

  // Track the current level (0 = First Seed, 1 = Strawberry, 2 = Mango)
  int currentLevelIndex = 0;
  bool isCorrect = false;
  late List<String> currentSequence;

  // The correct sequences for all levels
  final List<List<String>> allCorrectSequences = [
    [
      'assets/images/objects/lagoon/f1.png', // Seed 1
      'assets/images/objects/lagoon/f2.png', // Sprout 1
      'assets/images/objects/lagoon/f3.png', // Small Plant 1
      'assets/images/objects/lagoon/f4.png', // Flower 1
    ],
    [
      'assets/images/objects/lagoon/s1.png', // Strawberry Seed
      'assets/images/objects/lagoon/s2.png', // Strawberry Sprout
      'assets/images/objects/lagoon/s3.png', // Strawberry Plant
      'assets/images/objects/lagoon/s4.png', // Strawberry Fruit
    ],
    [
      'assets/images/objects/lagoon/m1.png', // Mango Seed
      'assets/images/objects/lagoon/m2.png', // Mango Sprout
      'assets/images/objects/lagoon/m3.png', // Mango Tree
      'assets/images/objects/lagoon/m4.png', // Mango Fruit Tree
    ],
  ];

  // The initial shuffled sequences for all levels
  final List<List<String>> allInitialSequences = [
    [
      'assets/images/objects/lagoon/f2.png',
      'assets/images/objects/lagoon/f4.png',
      'assets/images/objects/lagoon/f1.png',
      'assets/images/objects/lagoon/f3.png',
    ],
    [
      'assets/images/objects/lagoon/s3.png',
      'assets/images/objects/lagoon/s1.png',
      'assets/images/objects/lagoon/s4.png',
      'assets/images/objects/lagoon/s2.png',
    ],
    [
      'assets/images/objects/lagoon/m2.png',
      'assets/images/objects/lagoon/m4.png',
      'assets/images/objects/lagoon/m1.png',
      'assets/images/objects/lagoon/m3.png',
    ],
  ];

  @override
  void initState() {
    super.initState();
    // Load the first level's sequence
    currentSequence = List.from(allInitialSequences[currentLevelIndex]);
    OrientationService.setLandscape();

    // Start the intro sequence
    _playIntro();
  }

  void _playIntro() async {
    // Play the requested intro audio
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/seed_game_intro.wav'),
    );

    // Wait for the audio to finish completely, then update the UI
    _audioPlayer.onPlayerComplete.first.then((_) {
      if (mounted) {
        setState(() {
          showIntro = false;
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

  void _onItemDropped(int oldIndex, int newIndex) {
    if (isCorrect || showGoodJob) return;

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
      _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));

      if (currentLevelIndex < allCorrectSequences.length - 1) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;

          setState(() {
            currentLevelIndex++;
            currentSequence = List.from(allInitialSequences[currentLevelIndex]);
            isCorrect = false;
          });
        });
      } else {
        // Last level completed - show the Good Job Overlay
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;

          setState(() {
            showGoodJob = true;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image (Always visible)
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_rainbow_closeup2.png',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned(top: 25, left: 20, child: LagoonBackButton()),
          // Show Kiki during the intro, show the game board after
          if (showIntro)
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, kikiVerticalOffset),
                child: FractionallySizedBox(
                  heightFactor: 0.9,
                  child: Image.asset(
                    'assets/images/characters/kiki_gardener.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          else
            // Universal Responsive Game Area
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double maxByHeight = constraints.maxHeight * 0.45;
                  double maxByWidth = constraints.maxWidth / 5.5;

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

          // ── Final Success Overlay ──
          if (showGoodJob)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/kiki_the_cat.png',
              closeButtonColor: const Color(0xFFF44336), // A gentle red/orange
              onNext: () async {
                // 1. Mark the current level as complete (Change the number for each game)
                await LagoonProgressService.instance.markLevelComplete(11);

                if (context.mounted) {
                  // 2. Push directly to the next level's screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BodyPartsAssemblyScreen(level: 12),
                    ),
                  );
                }
              },
              onRestart: () {
                // Resets the game seamlessly to the first seed level
                setState(() {
                  currentLevelIndex = 0;
                  currentSequence = List.from(allInitialSequences[0]);
                  isCorrect = false;
                  showGoodJob = false;
                });
              },
              onBack: () {
                // Navigates out of the game screen
                Navigator.of(context).pop();
              },
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
          maxSimultaneousDrags: isCorrect || showGoodJob ? 0 : 1,
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
