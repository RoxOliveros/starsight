import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/lunchbox_game.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'lagoon_game_ui.dart';

/// Defines a single round in the Feed the Animal game.
class AnimalLevel {
  final String animalName;
  final String animalImagePath;
  final String animalHappyImagePath;
  final String correctFood;
  final List<FoodOption> tableFoods;

  AnimalLevel({
    required this.animalName,
    required this.animalImagePath,
    required this.animalHappyImagePath,
    required this.correctFood,
    required this.tableFoods,
  });
}

class FoodOption {
  final String id;
  final String imagePath;

  FoodOption({required this.id, required this.imagePath});
}

class FeedTheAnimalGame extends StatefulWidget {
  final int level;

  const FeedTheAnimalGame({super.key, required this.level});

  @override
  State<FeedTheAnimalGame> createState() => _FeedTheAnimalGameState();
}

class _FeedTheAnimalGameState extends State<FeedTheAnimalGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _audioSub;

  int _currentLevelIndex = 0;
  bool _isHappy = false;
  bool _showSuccessUI = false;
  bool _readyForEntrance = false;

  // Controls the intro screen visibility
  bool _showIntro = true;

  // Define the sequence based on the new idea
  late final List<AnimalLevel> _levels = [
    AnimalLevel(
      animalName: 'Rabbit',
      animalImagePath: 'assets/images/characters/roxie_the_rabbit.png',
      animalHappyImagePath: 'assets/images/characters/roxie_try_again.png',
      correctFood: 'carrot2',
      tableFoods: [
        FoodOption(
          id: 'fries',
          imagePath: 'assets/images/objects/lagoon/fries.png',
        ),
        FoodOption(
          id: 'carrot2',
          imagePath: 'assets/images/objects/lagoon/carrot2.png',
        ),
        FoodOption(
          id: 'cheese',
          imagePath: 'assets/images/objects/lagoon/cheese.png',
        ),
      ],
    ),
    AnimalLevel(
      animalName: 'Cow',
      animalImagePath: 'assets/images/objects/lagoon/cow.png',
      animalHappyImagePath: 'assets/images/objects/lagoon/cow.png',
      correctFood: 'lettuce',
      tableFoods: [
        FoodOption(
          id: 'lettuce',
          imagePath: 'assets/images/objects/lagoon/lettuce.png',
        ),
        FoodOption(
          id: 'coffee',
          imagePath: 'assets/images/objects/lagoon/coffee.png',
        ),
        FoodOption(
          id: 'bacon',
          imagePath: 'assets/images/objects/lagoon/bacon.png',
        ),
      ],
    ),
    AnimalLevel(
      animalName: 'Penguin',
      animalImagePath: 'assets/images/characters/doma_the_penguin.png',
      animalHappyImagePath: 'assets/images/characters/doma_smiling.png',
      correctFood: 'perfume_fish',
      tableFoods: [
        FoodOption(
          id: 'perfume_fish',
          imagePath: 'assets/images/objects/lagoon/perfume_fish.png',
        ),
        FoodOption(
          id: 'strawberry',
          imagePath: 'assets/images/objects/lagoon/strawberry.png',
        ),
        FoodOption(
          id: 'cucumber',
          imagePath: 'assets/images/objects/lagoon/bittergourd.png',
        ),
      ],
    ),
    AnimalLevel(
      animalName: 'Dog',
      animalImagePath: 'assets/images/characters/tofi_the_dog.png',
      animalHappyImagePath: 'assets/images/characters/tofi_smiling.png',
      correctFood: 'meat',
      tableFoods: [
        FoodOption(
          id: 'chocolate',
          imagePath: 'assets/images/objects/lagoon/chocolate.png',
        ),
        FoodOption(
          id: 'cheese',
          imagePath: 'assets/images/objects/lagoon/cheese.png',
        ),
        FoodOption(
          id: 'meat',
          imagePath: 'assets/images/objects/lagoon/bacon.png',
        ),
      ],
    ),
    AnimalLevel(
      animalName: 'Bear',
      animalImagePath: 'assets/images/characters/little_bear_uniform.png',
      animalHappyImagePath: 'assets/images/characters/little_bear_uniform.png',
      correctFood: 'honey',
      tableFoods: [
        FoodOption(
          id: 'broccoli',
          imagePath: 'assets/images/objects/lagoon/broccoli.png',
        ),
        FoodOption(
          id: 'banana',
          imagePath: 'assets/images/objects/lagoon/banana_colored.png',
        ),
        FoodOption(
          id: 'honey',
          imagePath: 'assets/images/objects/lagoon/honey.png',
        ),
      ],
    ),
    AnimalLevel(
      animalName: 'Chicken',
      animalImagePath: 'assets/images/objects/lagoon/chicken.png',
      animalHappyImagePath: 'assets/images/objects/lagoon/chicken.png',
      correctFood: 'worm',
      tableFoods: [
        FoodOption(
          id: 'pizza',
          imagePath: 'assets/images/objects/lagoon/pizza_colored.png',
        ),
        FoodOption(
          id: 'worm',
          imagePath: 'assets/images/objects/lagoon/worm.png',
        ),
        FoodOption(
          id: 'lemon',
          imagePath: 'assets/images/objects/lagoon/lemon.png',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _playIntroSequence();
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playIntroSequence() async {
    setState(() {
      _showIntro = true;
    });

    // Play the intro audio
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/feed_the_animal_game_intro.wav'),
    );

    // Listen for the audio to finish, then transition to the game
    _audioSub = _audioPlayer.onPlayerComplete.listen((_) {
      _audioSub?.cancel();
      if (mounted) {
        setState(() {
          _showIntro = false;
        });

        // Small delay before the first character walks in
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _readyForEntrance = true);
          }
        });
      }
    });
  }

  void _handleFoodAccepted(String foodId) {
    final currentLevel = _levels[_currentLevelIndex];

    if (foodId == currentLevel.correctFood) {
      setState(() {
        _isHappy = true;
      });

      _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        if (_currentLevelIndex < _levels.length - 1) {
          // Hide character, prepare next level, then trigger walk-in
          setState(() {
            _readyForEntrance = false;
            _currentLevelIndex++;
            _isHappy = false;
          });

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _readyForEntrance = true);
          });
        } else {
          setState(() {
            _readyForEntrance = false;
            _showSuccessUI = true;
          });
        }
      });
    } else {
      _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/kiki_tryagain.wav'),
      );
    }
  }

  // ── Builds the Intro Screen with Kiki and the Basket ───────────
  Widget _buildIntroScreen(double sw, double sh) {
    final double animalHeight = sh * 0.95;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_lagoon.png',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                Container(color: const Color(0xFF90D060)),
          ),

          // Kiki + Basket animated together in the center
          // Kiki + Basket anchored to the bottom and pushed down
          Positioned(
            bottom: -sh * 0.23, // Adjust this number to move her up or down!
            left: 0,
            right: 0,
            child:
                Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(
                          'assets/images/characters/kiki_the_cat.png',
                          height: animalHeight,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          // Positioning the basket over Kiki's belly/hands
                          bottom: animalHeight * 0.10,
                          child: Image.asset(
                            'assets/images/objects/lagoon/basket.png',
                            width: animalHeight * 0.50,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: 0,
                      end: -10,
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeInOut,
                    ),
          ),

          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    // ── Show Intro Sequence ────────────────────────────────────────────────
    if (_showIntro) {
      return _buildIntroScreen(sw, sh);
    }

    // Layout constants
    final double tableBottom = -sh * 0.60;
    final double foodBaseOffset = sh * 0.055;
    const double animalBottom = 0.0;
    final double animalHeight = sh * 0.95;

    final currentLevel = _levels[_currentLevelIndex];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background ──────────────────────────────────────────────
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_lagoon.png',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                Container(color: const Color(0xFF90D060)),
          ),

          // ── 2. The Animal (Drag Target) ────────────────────────────────
          Positioned(
            bottom: animalBottom,
            left: 0,
            right: 0,
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) => !_isHappy,
              onAcceptWithDetails: (details) {
                _handleFoodAccepted(details.data);
              },
              builder: (context, candidateData, rejectedData) {
                // Only build the animal if it is ready to enter
                if (!_readyForEntrance) return const SizedBox.shrink();

                return Center(
                  // The custom walk-in animation wrapper
                  child: _WalkingAnimalEntrance(
                    key: ValueKey('entrance_${currentLevel.animalName}'),
                    bounceHeightPx: animalHeight * 0.045,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child:
                          Image.asset(
                                _isHappy
                                    ? currentLevel.animalHappyImagePath
                                    : currentLevel.animalImagePath,
                                key: ValueKey(
                                  '${currentLevel.animalName}_$_isHappy',
                                ),
                                height: animalHeight,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, st) => Container(
                                  height: animalHeight,
                                  width: animalHeight * 0.6,
                                  color: Colors.grey,
                                ),
                              )
                              // The constant idle bounce animation (happens after walking)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(
                                begin: 0,
                                end: _isHappy ? -20 : -5,
                                duration: Duration(
                                  milliseconds: _isHappy ? 300 : 900,
                                ),
                                curve: Curves.easeInOut,
                              ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 3. The Table ───────────────────────────────────────────────
          Positioned(
            bottom: tableBottom,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/objects/lumi/table.png',
                width: sw,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => Container(
                  height: sh * 0.22,
                  color: const Color(0xFFCD853F),
                ),
              ),
            ),
          ),

          // ── 4. The Plates & Food Options ───────────────────────────────
          Positioned(
            bottom: foodBaseOffset,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: currentLevel.tableFoods.map((food) {
                final double plateWidth = sw * 0.20;
                final double foodWidth = sw * 0.14;

                final Widget foodWidget = Image.asset(
                  food.imagePath,
                  width: foodWidth,
                  height: foodWidth,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => Container(
                    width: foodWidth,
                    height: foodWidth,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        food.id,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                );

                return SizedBox(
                  width: plateWidth,
                  height: plateWidth,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Bottom layer: Static Plate
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Image.asset(
                          'assets/images/objects/lumi/plate.png',
                          width: plateWidth,
                          errorBuilder: (ctx, err, st) => Container(
                            width: plateWidth,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      // Top layer: Draggable Food
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          // Reduced the padding significantly so it sits exactly on the plate
                          padding: EdgeInsets.only(bottom: plateWidth * 0.04),
                          child: _isHappy
                              ? Opacity(opacity: 0.5, child: foodWidget)
                              : Draggable<String>(
                                  data: food.id,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Transform.scale(
                                      scale: 1.2,
                                      child: foodWidget,
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: foodWidget,
                                  ),
                                  child: foodWidget,
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ).animate().fadeIn(duration: 500.ms),
          ),

          // ── 5. Close / Exit Button ─────────────────────────────────────
          Positioned(
            top: sh * 0.05,
            left: sw * 0.03,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Image.asset(
                'assets/images/buttons/x_blue.png',
                width: sw * 0.065,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => Container(
                  width: sw * 0.065,
                  height: sw * 0.065,
                  decoration: const BoxDecoration(
                    color: Color(0xFF266589),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: sw * 0.04,
                  ),
                ),
              ),
            ),
          ),

          // ── 6. End Game UI (GoodJobOverlay) ───────────────────────────
          if (_showSuccessUI)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/kiki_smiling.png',
                closeButtonColor: const Color(0xFF266589),
                onNext: () async {
                  // 1. Mark the current level as complete (Change the number for each game)
                  await LagoonProgressService.instance.markLevelComplete(6);

                  if (context.mounted) {
                    // 2. Push directly to the next level's screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LunchboxGameIntro(level: widget.level + 1),
                      ),
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    _currentLevelIndex = 0;
                    _isHappy = false;
                    _showSuccessUI = false;
                    _showIntro = false; // Skip the intro on restart
                  });
                  // Trigger the first walk-in again upon restart
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) setState(() => _readyForEntrance = true);
                  });
                },
                onBack: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── CUSTOM WALKING ENTRANCE ──────────────────────────────────────────────────

/// Reusable walk-in entrance mimicking the math from CharacterEntrance
/// without needing plate/glass parameters.
class _WalkingAnimalEntrance extends StatefulWidget {
  final Widget child;
  final Duration walkDuration;
  final Duration stepDuration;
  final double bounceHeightPx;

  const _WalkingAnimalEntrance({
    super.key,
    required this.child,
    this.walkDuration = const Duration(milliseconds: 1800),
    this.stepDuration = const Duration(milliseconds: 260),
    required this.bounceHeightPx,
  });

  @override
  State<_WalkingAnimalEntrance> createState() => _WalkingAnimalEntranceState();
}

class _WalkingAnimalEntranceState extends State<_WalkingAnimalEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.walkDuration,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double startX = sw; // Always slide in from the right

    final int stepCount =
        (widget.walkDuration.inMilliseconds /
                widget.stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _controller.value;

        // Horizontal slide
        final double easedT = Curves.easeOutCubic.transform(t);
        final double dx = startX * (1 - easedT);

        // Footstep bounce
        final double bounce = t < 1.0
            ? (math.sin(t * stepCount * math.pi)).abs() * widget.bounceHeightPx
            : 0.0;

        return Transform.translate(offset: Offset(dx, -bounce), child: child);
      },
      child: widget.child,
    );
  }
}
