import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/lunchbox_game.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'lagoon_game_ui.dart';

class AnimalLevel {
  final String animalName;
  final String animalImagePath;
  final String animalHappyImagePath;
  final String correctFood;
  final List<FoodOption> tableFoods;
  final String questionAudioPath;
  final String correctAudioPath;

  AnimalLevel({
    required this.animalName,
    required this.animalImagePath,
    required this.animalHappyImagePath,
    required this.correctFood,
    required this.tableFoods,
    required this.questionAudioPath,
    required this.correctAudioPath,
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

class _FeedTheAnimalGameState extends State<FeedTheAnimalGame>
    with AiCameraMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  StreamSubscription? _audioSub;
  final GameTapTracker _tapTracker = GameTapTracker();

  int _currentLevelIndex = 0;
  bool _isHappy = false;
  bool _showSuccessUI = false;
  bool _readyForEntrance = false;
  bool _showIntro = true;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  static const String _audioIntro =
      'audio/discovery_lagoon/feed_the_animal_game_intro.wav';
  static const String _audioCorrect = 'audio/sound_effects/shine.wav';
  static const String _audioWrong = 'audio/discovery_lagoon/kiki_tryagain.wav';

  late final List<AnimalLevel> _levels = [
    AnimalLevel(
      animalName: 'Rabbit',
      animalImagePath: 'assets/images/characters/roxie_the_rabbit.png',
      animalHappyImagePath: 'assets/images/characters/roxie_try_again.png',
      correctFood: 'carrot2',
      questionAudioPath:
          'audio/discovery_lagoon/feed_animal_bunny_question.wav',
      correctAudioPath: 'audio/discovery_lagoon/feed_animal_bunny_correct.wav',
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
      questionAudioPath: 'audio/discovery_lagoon/feed_animal_cow_question.wav',
      correctAudioPath: 'audio/discovery_lagoon/feed_animal_cow_correct.wav',
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
      questionAudioPath:
          'audio/discovery_lagoon/feed_animal_penguin_question.wav',
      correctAudioPath:
          'audio/discovery_lagoon/feed_animal_penguin_correct.wav',
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
      questionAudioPath: 'audio/discovery_lagoon/feed_animal_dog_question.wav',
      correctAudioPath: 'audio/discovery_lagoon/feed_animal_dog_correct.wav',
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
      questionAudioPath: 'audio/discovery_lagoon/feed_animal_bear_question.wav',
      correctAudioPath: 'audio/discovery_lagoon/feed_animal_bear_correct.wav',
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
      questionAudioPath:
          'audio/discovery_lagoon/feed_animal_chicken_question.wav',
      correctAudioPath:
          'audio/discovery_lagoon/feed_animal_chicken_correct.wav',
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

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _playIntroSequence();
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioSub?.cancel();
    _audioPlayer.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  void _playIntroSequence() async {
    setState(() {
      _showIntro = true;
    });

    await _audioPlayer.play(AssetSource(_audioIntro));

    _audioSub = _audioPlayer.onPlayerComplete.listen((_) {
      _audioSub?.cancel();
      if (mounted) {
        setState(() {
          _showIntro = false;
        });

        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _readyForEntrance = true);
            _playQuestionAudioForCurrentLevel();
          }
        });
      }
    });
  }

  void _playQuestionAudioForCurrentLevel() {
    final currentLevel = _levels[_currentLevelIndex];
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _audioPlayer.play(AssetSource(currentLevel.questionAudioPath));
      }
    });
  }

  void _handleFoodAccepted(String foodId) {
    final currentLevel = _levels[_currentLevelIndex];

    if (foodId == currentLevel.correctFood) {
      _tapTracker.recordCorrectTap();
      setState(() {
        _isHappy = true;
      });

      _audioPlayer.play(AssetSource(_audioCorrect));

      Future.delayed(const Duration(milliseconds: 400), () async {
        if (!mounted) return;

        await _voicePlayer.play(AssetSource(currentLevel.correctAudioPath));

        try {
          await _voicePlayer.onPlayerComplete.first;
        } catch (_) {}

        if (!mounted) return;

        if (_currentLevelIndex < _levels.length - 1) {
          setState(() {
            _readyForEntrance = false;
            _currentLevelIndex++;
            _isHappy = false;
          });

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() => _readyForEntrance = true);
              _playQuestionAudioForCurrentLevel();
            }
          });
        } else {
          await _saveDataAndShowGoodJob();
        }
      });
    } else {
      _tapTracker.recordMistake();
      _audioPlayer.play(AssetSource(_audioWrong));
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    try {
      await LagoonDatabaseService.saveGameData(
        gameId: 'lagoon_feed_the_animal',
        activityName: 'Feed the Animal',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      );
    } catch (e) {
      debugPrint("Database Error saving metrics: $e");
    }
    await LagoonProgressService.instance.markLevelComplete(6);

    if (mounted) {
      setState(() {
        _readyForEntrance = false;
        _showSuccessUI = true;
      });
    }
  }

  Widget _buildIntroScreen(double sw, double sh) {
    final double animalHeight = sh * 0.95;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_lagoon.png',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                Container(color: const Color(0xFF90D060)),
          ),
          Positioned(
            bottom: -sh * 0.23,
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
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    if (_showIntro) {
      return _buildIntroScreen(sw, sh);
    }

    final double tableBottom = -sh * 0.60;
    final double foodBaseOffset = sh * 0.055;
    const double animalBottom = 0.0;
    final double animalHeight = sh * 0.95;

    final currentLevel = _levels[_currentLevelIndex];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_lagoon.png',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                Container(color: const Color(0xFF90D060)),
          ),
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
                if (!_readyForEntrance) return const SizedBox.shrink();

                return Center(
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
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
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
          Positioned(top: 25, left: 25, child: const LagoonXButton()),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (_showSuccessUI)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage:
                    'assets/images/characters/cat_holding_fishbone.png',
                characterSizeFactor: 0.9,
                onNext: () {
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LunchboxGameIntro(level: widget.level + 1),
                      ),
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    _currentLevelIndex = 0;
                    _isHappy = false;
                    _showSuccessUI = false;
                    _showIntro = false;
                    _hasSavedResult = false;
                    _tapTracker.startSession();
                  });
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) setState(() => _readyForEntrance = true);
                  });
                },
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalkingAnimalEntrance extends StatefulWidget {
  final Widget child;
  final double bounceHeightPx;

  const _WalkingAnimalEntrance({
    super.key,
    required this.child,
    required this.bounceHeightPx,
  });

  final Duration walkDuration = const Duration(milliseconds: 1800);
  final Duration stepDuration = const Duration(milliseconds: 260);

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
    final double startX = sw;

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
