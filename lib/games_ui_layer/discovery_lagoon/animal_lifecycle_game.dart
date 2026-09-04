import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/cold_hot_game.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // Standard Flutter audio package
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'lagoon_game_ui.dart';

class AnimalLifecycleGame extends StatefulWidget {
  final int level;

  const AnimalLifecycleGame({super.key, required this.level});

  @override
  _AnimalLifecycleGameState createState() => _AnimalLifecycleGameState();
}

class _AnimalLifecycleGameState extends State<AnimalLifecycleGame> {
  // Initialize the audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Intro & End state
  bool showIntro = true;
  bool showGoodJob = false; // Added state for the final overlay
  bool _disposed = false;

  // ==========================================
  // 🛠️ KIKI ADJUSTER
  // Change these values to move Kiki manually.
  // X: Negative (LEFT), Positive (RIGHT)
  // Y: Negative (UP), Positive (DOWN)
  // ==========================================
  final double kikiHorizontalOffset = 0.0;
  final double kikiVerticalOffset = 40.0;
  final double kikiSizeFactor = 1.20;

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
    currentSequence = List.from(allInitialSequences[currentLevelIndex]);
    OrientationService.setLandscape();
    _playIntro();
  }

  void _playIntro() async {
    if (_disposed) return;
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/animal_lifecycle_game_intro.wav'),
    );

    _waitForAudioComplete().then((_) {
      if (!mounted || _disposed) return;
      setState(() {
        showIntro = false;
      });
    });
  }

  Future<void> _waitForAudioComplete() async {
    try {
      await _audioPlayer.onPlayerComplete.first;
    } catch (_) {
      // Stream closed (player disposed) before it ever completed — ignore.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _onItemDropped(int oldIndex, int newIndex) {
    // Prevent dragging if the current level is already solved or the game is finished
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
      // Play the success sound effect
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

          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

          // Show Kiki during the intro, show the game board after
          if (showIntro)
            Center(
              child: Transform.translate(
                offset: Offset(kikiHorizontalOffset, kikiVerticalOffset),
                child: FractionallySizedBox(
                  heightFactor: kikiSizeFactor,
                  child: Image.asset(
                    'assets/images/characters/kiki_standing.png',
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

          // ── Final Success Overlay ──
          if (showGoodJob)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/cat_holding_fishbone.png',
              closeButtonColor: LagoonColorTheme.wasteland,
              characterSizeFactor: 0.9,
              onNext: () async {
                // 1. Mark the current level as complete (Change the number for each game)
                await LagoonProgressService.instance.markLevelComplete(17);

                if (context.mounted) {
                  // 2. Push directly to the next level's screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ColdHotGame(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: () {
                // Resets the game seamlessly to the first level
                setState(() {
                  currentLevelIndex = 0;
                  currentSequence = List.from(allInitialSequences[0]);
                  isCorrect = false;
                  showGoodJob = false;
                });
              },
              onBack: () => Navigator.of(context).pop(),
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
          // Disable dragging if the sequence is solved or the game is finished
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
            color: isCorrect
                ? Colors.orange
                : Colors.grey.shade500, // Changed to Orange!
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
