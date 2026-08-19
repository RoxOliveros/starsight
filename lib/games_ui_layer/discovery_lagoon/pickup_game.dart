import 'dart:math' as math;
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart'; // Make sure this path matches your project structure
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// 1. Define a class to hold specific size and position for each character
class CharacterConfig {
  final String imagePath;
  final double leftOffset; // Percentage of screen width (e.g., 0.36 = 36%)
  final double bottomOffset; // Percentage of screen height
  final double startHeight; // Percentage of screen height

  // Adjusters for when the child moves to the parent
  final double endLeftOffset;
  final double endBottomOffset;
  final double endHeight;

  CharacterConfig({
    required this.imagePath,
    required this.leftOffset,
    required this.bottomOffset,
    required this.startHeight,
    this.endLeftOffset = 0.34, // Default fallback values
    this.endBottomOffset = -0.10,
    this.endHeight = 0.55,
  });
}

// 2. Define the level to accept the configurations
class PickupLevel {
  final String parentImage;
  final CharacterConfig targetChild;
  final CharacterConfig? wrongChild1; // Made optional for 1-choice levels
  final CharacterConfig? wrongChild2; // Made optional for 2-choice levels

  PickupLevel({
    required this.parentImage,
    required this.targetChild,
    this.wrongChild1,
    this.wrongChild2,
  });
}

class PickupGame extends StatefulWidget {
  const PickupGame({super.key});

  @override
  State<PickupGame> createState() => _PickupGameState();
}

class _PickupGameState extends State<PickupGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentLevelIndex = 0;
  bool _hasChildMoved = false;
  bool _showSuccessUI = false; // Tracks end-game overlay

  // 3. Configure your levels and character adjusters here!
  late final List<PickupLevel> _levels = [
    // --- LEVEL 1: Mom Bear ---
    PickupLevel(
      parentImage: 'assets/images/characters/mom_bear.png',
      // Little Bear
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/little_bear_uniform.png',
        leftOffset: 0.36,
        bottomOffset: 0.30,
        startHeight: 0.40,
        endLeftOffset: 0.34,
        endBottomOffset: -0.10,
        endHeight: 0.55,
      ),
      // Jack the Fox
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/jack_the_fox.png',
        leftOffset: 0.48,
        bottomOffset: 0.31,
        startHeight: 0.36,
      ),
      // Roxie the Bunny
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/roxie_standing.png',
        leftOffset: 0.59,
        bottomOffset: 0.30,
        startHeight: 0.42,
      ),
    ),

    // --- LEVEL 2: Dad Jack ---
    PickupLevel(
      parentImage: 'assets/images/characters/dad_jack.png',
      // Jack the Fox (Target)
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/jack_the_fox.png',
        leftOffset: 0.36,
        bottomOffset: 0.31,
        startHeight: 0.36,
        endLeftOffset: 0.32,
        endBottomOffset: -0.05,
        endHeight: 0.50,
      ),
      // Roxie the Bunny
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/roxie_standing.png',
        leftOffset: 0.48,
        bottomOffset: 0.30,
        startHeight: 0.42,
      ),
      // Chicken
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/chicken.png',
        leftOffset: 0.62,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
    ),

    // --- LEVEL 3: Mom Roxie ---
    PickupLevel(
      parentImage: 'assets/images/characters/mom_roxie.png',
      // Roxie the Bunny (Target)
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/roxie_standing.png',
        leftOffset: 0.35,
        bottomOffset: 0.30,
        startHeight: 0.42,
        endLeftOffset: 0.26,
        endBottomOffset: -0.08,
        endHeight: 0.58,
      ),
      // Chicken
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/chicken.png',
        leftOffset: 0.48,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
      // Doma the Penguin
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/doma_the_penguin2.png',
        leftOffset: 0.59,
        bottomOffset: 0.30,
        startHeight: 0.38,
      ),
    ),

    // --- LEVEL 4: Mom Chicken ---
    PickupLevel(
      parentImage: 'assets/images/characters/mom_chichken.png',
      // Chicken (Target)
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/chicken.png',
        leftOffset: 0.48,
        bottomOffset: 0.30,
        startHeight: 0.34,
        endLeftOffset: 0.34,
        endBottomOffset: -0.05,
        endHeight: 0.48,
      ),
      // Doma the Penguin
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/doma_the_penguin2.png',
        leftOffset: 0.35,
        bottomOffset: 0.30,
        startHeight: 0.38,
      ),
      // Pig
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/pig_dressed.png',
        leftOffset: 0.62,
        bottomOffset: 0.30,
        startHeight: 0.36,
      ),
    ),

    // --- LEVEL 5: Mom Doma ---
    PickupLevel(
      parentImage: 'assets/images/characters/mom_doma.png',
      // Doma the Penguin (Target)
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/doma_the_penguin2.png',
        leftOffset: 0.59,
        bottomOffset: 0.30,
        startHeight: 0.38,
        endLeftOffset: 0.34,
        endBottomOffset: -0.05,
        endHeight: 0.50,
      ),
      // Pig
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/pig_dressed.png',
        leftOffset: 0.34,
        bottomOffset: 0.30,
        startHeight: 0.36,
      ),
      // Snake
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/snake.png',
        leftOffset: 0.46,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
    ),

    // --- LEVEL 6: Dad Pig ---
    PickupLevel(
      parentImage: 'assets/images/characters/dad_pig.png',
      // Pig (Target)
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/pig_dressed.png',
        leftOffset: 0.42,
        bottomOffset: 0.30,
        startHeight: 0.36,
        endLeftOffset: 0.34,
        endBottomOffset: -0.05,
        endHeight: 0.50,
      ),
      // Snake
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/snake.png',
        leftOffset: 0.56,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
      wrongChild2: null,
    ),

    // --- LEVEL 7: Dad Snake ---
    PickupLevel(
      parentImage: 'assets/images/characters/dad_snake.png',
      // Snake (Target - Only choice in center)
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/snake.png',
        leftOffset: 0.48,
        bottomOffset: 0.30,
        startHeight: 0.34,
        endLeftOffset: 0.34,
        endBottomOffset: -0.05,
        endHeight: 0.46,
      ),
      wrongChild1: null,
      wrongChild2: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
  }

  Future<void> _playAudio(String path) async {
    await _audioPlayer.play(AssetSource(path));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final currentLevel = _levels[_currentLevelIndex];

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Layer
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_school.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. The Parent
          Positioned(
            bottom: -screenSize.height * 0.05,
            left: screenSize.width * 0.15,
            height: screenSize.height * 0.65,
            child: GestureDetector(
              onTap: () {
                if (!_hasChildMoved)
                  _playAudio('audio/discovery_lagoon/kiki_tryagain.wav');
              },
              child: _WalkingAnimalEntrance(
                key: ValueKey(currentLevel.parentImage),
                bounceHeightPx: screenSize.height * 0.65 * 0.045,
                child: Image.asset(currentLevel.parentImage),
              ),
            ),
          ),

          // 3. Wrong Choice 1 (Conditionally rendered)
          if (currentLevel.wrongChild1 != null)
            Positioned(
              bottom:
                  screenSize.height * currentLevel.wrongChild1!.bottomOffset,
              left: screenSize.width * currentLevel.wrongChild1!.leftOffset,
              height: screenSize.height * currentLevel.wrongChild1!.startHeight,
              child: GestureDetector(
                onTap: () {
                  if (!_hasChildMoved)
                    _playAudio('audio/discovery_lagoon/kiki_tryagain.wav');
                },
                child: Image.asset(currentLevel.wrongChild1!.imagePath),
              ),
            ),

          // 4. Wrong Choice 2 (Conditionally rendered)
          if (currentLevel.wrongChild2 != null)
            Positioned(
              bottom:
                  screenSize.height * currentLevel.wrongChild2!.bottomOffset,
              left: screenSize.width * currentLevel.wrongChild2!.leftOffset,
              height: screenSize.height * currentLevel.wrongChild2!.startHeight,
              child: GestureDetector(
                onTap: () {
                  if (!_hasChildMoved)
                    _playAudio('audio/discovery_lagoon/kiki_tryagain.wav');
                },
                child: Image.asset(currentLevel.wrongChild2!.imagePath),
              ),
            ),

          // 5. Target Child
          AnimatedPositioned(
            duration: _hasChildMoved
                ? const Duration(milliseconds: 1200)
                : Duration.zero,
            curve: Curves.easeInOut,

            // Using custom "end" adjusters when moved
            bottom: _hasChildMoved
                ? screenSize.height * currentLevel.targetChild.endBottomOffset
                : screenSize.height * currentLevel.targetChild.bottomOffset,
            left: _hasChildMoved
                ? screenSize.width * currentLevel.targetChild.endLeftOffset
                : screenSize.width * currentLevel.targetChild.leftOffset,
            height: _hasChildMoved
                ? screenSize.height * currentLevel.targetChild.endHeight
                : screenSize.height * currentLevel.targetChild.startHeight,

            child: GestureDetector(
              onTap: () {
                if (_hasChildMoved) return;

                _playAudio('audio/sound_effects/shine.wav');
                setState(() {
                  _hasChildMoved = true;
                });

                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    if (_currentLevelIndex < _levels.length - 1) {
                      // Advance to next level
                      setState(() {
                        _hasChildMoved = false;
                        _currentLevelIndex++;
                      });
                    } else {
                      // Finished the final level -> Show GoodJobOverlay
                      setState(() {
                        _hasChildMoved = false;
                        _showSuccessUI = true;
                      });
                    }
                  }
                });
              },
              child: Image.asset(currentLevel.targetChild.imagePath),
            ),
          ),

          // 6. Good Job Prompt Overlay (Shown after completing the final level)
          if (_showSuccessUI)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/kiki_smiling.png',
                closeButtonColor: const Color(0xFF266589),
                onNext: () {
                  Navigator.of(context).maybePop();
                },
                onRestart: () {
                  setState(() {
                    _currentLevelIndex = 0;
                    _hasChildMoved = false;
                    _showSuccessUI = false;
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
    final double startX = -sw;

    final int stepCount =
        (widget.walkDuration.inMilliseconds /
                widget.stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _controller.value;

        final double easedT = Curves.easeOutCubic.transform(t);
        final double dx = startX * (1 - easedT);

        final double bounce = t < 1.0
            ? (math.sin(t * stepCount * math.pi)).abs() * widget.bounceHeightPx
            : 0.0;

        return Transform.translate(offset: Offset(dx, -bounce), child: child);
      },
      child: widget.child,
    );
  }
}
