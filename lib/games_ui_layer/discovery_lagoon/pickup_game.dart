import 'dart:math' as math;
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/weather_scene_builder_screen.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'lagoon_game_ui.dart';

// 1. Define a class to hold specific size and position for each character
class CharacterConfig {
  final String imagePath;
  final double leftOffset;
  final double bottomOffset;
  final double startHeight;

  final double entranceLeftOffset;

  final double endLeftOffset;
  final double endBottomOffset;
  final double endHeight;

  CharacterConfig({
    required this.imagePath,
    required this.leftOffset,
    required this.bottomOffset,
    required this.startHeight,
    required this.entranceLeftOffset,
    this.endLeftOffset = 0.34,
    this.endBottomOffset = -0.10,
    this.endHeight = 0.55,
  });
}

// 2. Define the level to accept the configurations
class PickupLevel {
  final String parentImage;
  final CharacterConfig targetChild;
  final CharacterConfig? wrongChild1;
  final CharacterConfig? wrongChild2;

  PickupLevel({
    required this.parentImage,
    required this.targetChild,
    this.wrongChild1,
    this.wrongChild2,
  });
}

class PickupGame extends StatefulWidget {
  final int level;

  const PickupGame({super.key, required this.level});

  @override
  State<PickupGame> createState() => _PickupGameState();
}

class _PickupGameState extends State<PickupGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentLevelIndex = 0;

  bool _isIntro = true;
  bool _forceEntrancePositions = true;
  bool _isChildrenEntering = false;
  bool _isTargetMoving = false;
  bool _isWalkingAway = false;
  bool _showSuccessUI = false;
  bool _disposed = false;

  // 3. Configure your levels and character adjusters here!
  late final List<PickupLevel> _levels = [
    // --- LEVEL 1: Mom Bear ---
    PickupLevel(
      parentImage: 'assets/images/characters/mom_bear.png',
      // Little Bear
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/little_bear_uniform.png',
        leftOffset: 0.36,
        entranceLeftOffset: 1.05,
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
        entranceLeftOffset: 1.25,
        bottomOffset: 0.31,
        startHeight: 0.36,
      ),
      // Roxie the Bunny
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/roxie_standing.png',
        leftOffset: 0.59,
        entranceLeftOffset: 1.45,
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
        entranceLeftOffset: 0.48,
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
        entranceLeftOffset: 0.59,
        bottomOffset: 0.30,
        startHeight: 0.42,
      ),
      // Chicken
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/chicken.png',
        leftOffset: 0.62,
        entranceLeftOffset: 1.05,
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
        entranceLeftOffset: 0.48,
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
        entranceLeftOffset: 0.62,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
      // Doma the Penguin
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/doma_the_penguin2.png',
        leftOffset: 0.59,
        entranceLeftOffset: 1.05,
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
        leftOffset: 0.35,
        entranceLeftOffset: 0.48,
        bottomOffset: 0.30,
        startHeight: 0.34,
        endLeftOffset: 0.34,
        endBottomOffset: -0.05,
        endHeight: 0.48,
      ),
      // Doma the Penguin
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/doma_the_penguin2.png',
        leftOffset: 0.48,
        entranceLeftOffset: 0.59,
        bottomOffset: 0.30,
        startHeight: 0.38,
      ),
      // Pig
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/pig_dressed.png',
        leftOffset: 0.62,
        entranceLeftOffset: 1.05,
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
        leftOffset: 0.35,
        entranceLeftOffset: 0.48,
        bottomOffset: 0.30,
        startHeight: 0.38,
        endLeftOffset: 0.34,
        endBottomOffset: -0.05,
        endHeight: 0.50,
      ),
      // Pig
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/pig_dressed.png',
        leftOffset: 0.50,
        entranceLeftOffset: 0.62,
        bottomOffset: 0.30,
        startHeight: 0.36,
      ),
      // Snake
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/snake.png',
        leftOffset: 0.62,
        entranceLeftOffset: 1.05,
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
        entranceLeftOffset: 0.50,
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
        entranceLeftOffset: 0.62,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
      wrongChild2: null,
    ),

    // --- LEVEL 7: Dad Snake ---
    PickupLevel(
      parentImage: 'assets/images/characters/dad_snake.png',
      // Snake (Target)
      targetChild: CharacterConfig(
        imagePath: 'assets/images/characters/snake.png',
        leftOffset: 0.48,
        entranceLeftOffset: 0.56,
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
    _playIntroSequence();
  }

  // Orchestrates the kids sliding and bouncing into view
  void _triggerEntranceAnimation() {
    setState(() {
      _forceEntrancePositions = true;
      _isChildrenEntering = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _forceEntrancePositions = false;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isChildrenEntering = false;
          });
        }
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

  Future<void> _playIntroSequence() async {
    // 1. Wait for Kiki's walking entrance
    await Future.delayed(const Duration(milliseconds: 1800));
    if (_disposed) return;

    // 2. Play the Schoolbell and wait for it to finish
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/pickup_game_schoolbell.wav'),
    );
    await _waitForAudioComplete();
    if (_disposed) return;

    // 3. Play the Intro sequence and wait for it to finish
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/pickup_game_intro.wav'),
    );
    await _waitForAudioComplete();
    if (_disposed) return;

    // 4. Hide intro and start the actual game entrance
    if (mounted) {
      setState(() {
        _isIntro = false;
      });
      _triggerEntranceAnimation();
    }
  }

  Future<void> _playAudio(String path) async {
    if (_disposed) return;
    await _audioPlayer.play(AssetSource(path));
  }

  @override
  void dispose() {
    _disposed = true; // set FIRST so any in-flight steps bail out
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _handleTargetTap() {
    if (_isTargetMoving ||
        _isWalkingAway ||
        _isChildrenEntering ||
        _forceEntrancePositions ||
        _isIntro) {
      return;
    }

    _playAudio('audio/sound_effects/shine.wav');

    setState(() {
      _isTargetMoving = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      setState(() {
        _isWalkingAway = true;
      });

      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;

        setState(() {
          _isTargetMoving = false;
          _isWalkingAway = false;
        });

        if (_currentLevelIndex < _levels.length - 1) {
          _currentLevelIndex++;
          _triggerEntranceAnimation();
        } else {
          setState(() {
            _showSuccessUI = true;
          });
        }
      });
    });
  }

  Widget _buildChildCharacter({
    required CharacterConfig config,
    required bool isTarget,
    required Size screenSize,
  }) {
    double currentLeft;
    double currentBottom;
    double currentHeight;
    Duration animDuration;
    Curve animCurve;
    bool shouldBounce;

    if (isTarget) {
      if (_isWalkingAway) {
        currentLeft = screenSize.width * (config.endLeftOffset - 0.75);
        currentBottom = screenSize.height * config.endBottomOffset;
        currentHeight = screenSize.height * config.endHeight;
        animDuration = const Duration(milliseconds: 1800);
        animCurve = Curves.linear;
        shouldBounce = true;
      } else if (_isTargetMoving) {
        currentLeft = screenSize.width * config.endLeftOffset;
        currentBottom = screenSize.height * config.endBottomOffset;
        currentHeight = screenSize.height * config.endHeight;
        animDuration = const Duration(milliseconds: 1200);
        animCurve = Curves.easeInOut;
        shouldBounce = true;
      } else if (_forceEntrancePositions) {
        currentLeft = screenSize.width * config.entranceLeftOffset;
        currentBottom = screenSize.height * config.bottomOffset;
        currentHeight = screenSize.height * config.startHeight;
        animDuration = Duration.zero;
        animCurve = Curves.linear;
        shouldBounce = _isChildrenEntering;
      } else {
        currentLeft = screenSize.width * config.leftOffset;
        currentBottom = screenSize.height * config.bottomOffset;
        currentHeight = screenSize.height * config.startHeight;
        animDuration = const Duration(milliseconds: 1500);
        animCurve = Curves.easeInOut;
        shouldBounce = _isChildrenEntering;
      }
    } else {
      if (_forceEntrancePositions) {
        currentLeft = screenSize.width * config.entranceLeftOffset;
        currentBottom = screenSize.height * config.bottomOffset;
        currentHeight = screenSize.height * config.startHeight;
        animDuration = Duration.zero;
        animCurve = Curves.linear;
        shouldBounce = _isChildrenEntering;
      } else {
        currentLeft = screenSize.width * config.leftOffset;
        currentBottom = screenSize.height * config.bottomOffset;
        currentHeight = screenSize.height * config.startHeight;
        animDuration = const Duration(milliseconds: 1500);
        animCurve = Curves.easeInOut;
        shouldBounce = _isChildrenEntering;
      }
    }

    return AnimatedPositioned(
      duration: animDuration,
      curve: animCurve,
      left: currentLeft,
      bottom: currentBottom,
      height: currentHeight,
      child: _WalkingBounce(
        isWalking: shouldBounce,
        bounceHeightPx: screenSize.height * 0.045,
        child: GestureDetector(
          onTap: () {
            if (_isTargetMoving ||
                _isWalkingAway ||
                _isChildrenEntering ||
                _forceEntrancePositions ||
                _isIntro) {
              return;
            }

            if (isTarget) {
              _handleTargetTap();
            } else {
              _playAudio('audio/discovery_lagoon/kiki_tryagain.wav');
            }
          },
          child: Image.asset(config.imagePath),
        ),
      ),
    );
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

          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

          // 2. Kiki The Cat Intro Overlay (Only shows if _isIntro is true)
          if (_isIntro)
            Positioned(
              bottom: -screenSize.height * 0.05,
              left: screenSize.width * 0.15, // Exact same spot as the parents
              height: screenSize.height * 0.65,
              child: _WalkingAnimalEntrance(
                walkDuration: const Duration(milliseconds: 1800),
                stepDuration: const Duration(milliseconds: 260),
                bounceHeightPx: screenSize.height * 0.045,
                child: Image.asset('assets/images/characters/kiki_the_cat.png'),
              ),
            ),

          // 3. The Parent (Only shown after Intro is done)
          if (!_isIntro)
            AnimatedPositioned(
              duration: _isWalkingAway
                  ? const Duration(milliseconds: 1800)
                  : Duration.zero,
              curve: Curves.linear,
              bottom: -screenSize.height * 0.05,
              left: _isWalkingAway
                  ? -screenSize.width * 0.60
                  : screenSize.width * 0.15,
              height: screenSize.height * 0.65,
              child: _WalkingBounce(
                isWalking: _isWalkingAway,
                bounceHeightPx: screenSize.height * 0.045,
                child: GestureDetector(
                  onTap: () {
                    if (!_isTargetMoving &&
                        !_isWalkingAway &&
                        !_isChildrenEntering) {
                      _playAudio('audio/discovery_lagoon/kiki_tryagain.wav');
                    }
                  },
                  child: _WalkingAnimalEntrance(
                    key: ValueKey(currentLevel.parentImage),
                    bounceHeightPx: screenSize.height * 0.045,
                    child: Image.asset(currentLevel.parentImage),
                  ),
                ),
              ),
            ),

          // 4. Wrong Choice 1
          if (!_isIntro && currentLevel.wrongChild1 != null)
            _buildChildCharacter(
              config: currentLevel.wrongChild1!,
              isTarget: false,
              screenSize: screenSize,
            ),

          // 5. Wrong Choice 2
          if (!_isIntro && currentLevel.wrongChild2 != null)
            _buildChildCharacter(
              config: currentLevel.wrongChild2!,
              isTarget: false,
              screenSize: screenSize,
            ),

          // 6. Target Child
          if (!_isIntro)
            _buildChildCharacter(
              config: currentLevel.targetChild,
              isTarget: true,
              screenSize: screenSize,
            ),

          // 7. Good Job Prompt Overlay
          if (_showSuccessUI)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/kiki_smiling.png',
                closeButtonColor: const Color(0xFF266589),
                onNext: () async {
                  // 1. Mark the current level as complete (Change the number for each game)
                  await LagoonProgressService.instance.markLevelComplete(15);

                  if (context.mounted) {
                    // 2. Push directly to the next level's screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const WeatherSceneBuilderScreen(level: 16),
                      ),
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    _currentLevelIndex = 0;
                    _showSuccessUI = false;
                    _isIntro = true; // Show intro again on restart
                  });
                  _playIntroSequence();
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

// ── CUSTOM CONTINUOUS WALKING BOUNCE ──────────────────────────────────────────

class _WalkingBounce extends StatefulWidget {
  final Widget child;
  final bool isWalking;
  final double bounceHeightPx;

  const _WalkingBounce({
    super.key,
    required this.child,
    required this.isWalking,
    required this.bounceHeightPx,
  });

  @override
  State<_WalkingBounce> createState() => _WalkingBounceState();
}

class _WalkingBounceState extends State<_WalkingBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.isWalking) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _WalkingBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWalking != oldWidget.isWalking) {
      if (widget.isWalking) {
        _ctrl.repeat();
      } else {
        _ctrl.animateTo(0, duration: const Duration(milliseconds: 150));
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final double bounce =
            (math.sin(_ctrl.value * math.pi * 2)).abs() * widget.bounceHeightPx;
        final double angle = math.sin(_ctrl.value * math.pi * 2) * 0.06;

        return Transform.translate(
          offset: Offset(0, -bounce),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: widget.child,
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

        final double angle = t < 1.0
            ? math.sin(t * stepCount * math.pi) * 0.04
            : 0.0;

        return Transform.translate(
          offset: Offset(dx, -bounce),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: widget.child,
    );
  }
}
