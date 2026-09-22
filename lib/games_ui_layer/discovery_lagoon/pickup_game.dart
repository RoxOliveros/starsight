import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/weather_scene_builder_screen.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';

import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import 'lagoon_game_ui.dart';

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

class _PickupGameState extends State<PickupGame> with AiCameraMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GameTapTracker _tapTracker = GameTapTracker();
  int _currentLevelIndex = 0;

  CharacterConfig? _assignedTarget;
  CharacterConfig? _assignedWrong1;
  CharacterConfig? _assignedWrong2;

  bool _isIntro = true;
  bool _forceEntrancePositions = true;
  bool _isChildrenEntering = false;
  bool _isTargetMoving = false;
  bool _isWalkingAway = false;
  bool _isGlowing = false;
  bool _showSuccessUI = false;
  bool _disposed = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  late final List<PickupLevel> _levels = [
    PickupLevel(
      parentImage: 'assets/images/characters/mom_bear.png',
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
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/jack_the_fox.png',
        leftOffset: 0.48,
        entranceLeftOffset: 1.25,
        bottomOffset: 0.31,
        startHeight: 0.36,
      ),
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/roxie_standing.png',
        leftOffset: 0.59,
        entranceLeftOffset: 1.45,
        bottomOffset: 0.30,
        startHeight: 0.42,
      ),
    ),
    PickupLevel(
      parentImage: 'assets/images/characters/dad_jack.png',
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
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/roxie_standing.png',
        leftOffset: 0.48,
        entranceLeftOffset: 0.59,
        bottomOffset: 0.30,
        startHeight: 0.42,
      ),
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/chicken.png',
        leftOffset: 0.62,
        entranceLeftOffset: 1.05,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
    ),
    PickupLevel(
      parentImage: 'assets/images/characters/mom_roxie.png',
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
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/chicken.png',
        leftOffset: 0.48,
        entranceLeftOffset: 0.62,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/doma_the_penguin2.png',
        leftOffset: 0.59,
        entranceLeftOffset: 1.05,
        bottomOffset: 0.30,
        startHeight: 0.38,
      ),
    ),
    PickupLevel(
      parentImage: 'assets/images/characters/mom_chichken.png',
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
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/doma_the_penguin2.png',
        leftOffset: 0.48,
        entranceLeftOffset: 0.59,
        bottomOffset: 0.30,
        startHeight: 0.38,
      ),
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/pig_dressed.png',
        leftOffset: 0.62,
        entranceLeftOffset: 1.05,
        bottomOffset: 0.30,
        startHeight: 0.36,
      ),
    ),
    PickupLevel(
      parentImage: 'assets/images/characters/mom_doma.png',
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
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/pig_dressed.png',
        leftOffset: 0.50,
        entranceLeftOffset: 0.62,
        bottomOffset: 0.30,
        startHeight: 0.36,
      ),
      wrongChild2: CharacterConfig(
        imagePath: 'assets/images/characters/snake.png',
        leftOffset: 0.62,
        entranceLeftOffset: 1.05,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
    ),
    PickupLevel(
      parentImage: 'assets/images/characters/dad_pig.png',
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
      wrongChild1: CharacterConfig(
        imagePath: 'assets/images/characters/snake.png',
        leftOffset: 0.56,
        entranceLeftOffset: 0.62,
        bottomOffset: 0.30,
        startHeight: 0.34,
      ),
      wrongChild2: null,
    ),
    PickupLevel(
      parentImage: 'assets/images/characters/dad_snake.png',
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

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _assignCurrentLevelPositions();
    _playIntroSequence();
  }

  void _assignCurrentLevelPositions() {
    final level = _levels[_currentLevelIndex];
    _assignedTarget = level.targetChild;
    _assignedWrong1 = level.wrongChild1;
    _assignedWrong2 = level.wrongChild2;
  }

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
    } catch (_) {}
  }

  Future<void> _playIntroSequence() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (_disposed) return;

    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/pickup_game_schoolbell.wav'),
    );
    await _waitForAudioComplete();
    if (_disposed) return;

    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/pickup_game_intro.wav'),
    );
    await _waitForAudioComplete();
    if (_disposed) return;

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
    _disposed = true;
    disposeAiCamera();
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

    _tapTracker.recordCorrectTap();
    _playAudio('audio/sound_effects/shine.wav');

    setState(() {
      _isTargetMoving = true;
      _isGlowing = true;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isGlowing = false);
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      setState(() {
        _isWalkingAway = true;
      });

      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;

        // ONLY reset the walking positions if there is another round left
        if (_currentLevelIndex < _levels.length - 1) {
          setState(() {
            _isTargetMoving = false;
            _isWalkingAway = false;
          });
          _currentLevelIndex++;
          _assignCurrentLevelPositions();
          _triggerEntranceAnimation();
        } else {
          _saveDataAndShowGoodJob();
        }
      });
    });
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    try {
      await LagoonDatabaseService.saveGameData(
        gameId: 'lagoon_pickup_game',
        activityName: 'Pickup Game',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      );
    } catch (e) {
      debugPrint("Database Error saving metrics: $e");
    }
    await LagoonProgressService.instance.markLevelComplete(15);

    if (mounted) {
      setState(() {
        _showSuccessUI = true;
      });
    }
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
              _tapTracker.recordMistake();
              _playAudio('audio/discovery_lagoon/kiki_tryagain.wav');
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              boxShadow: (isTarget && _isGlowing)
                  ? [
                      BoxShadow(
                        color: Colors.yellowAccent.withValues(alpha: 0.50),
                        blurRadius: 100,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: Image.asset(config.imagePath),
          ),
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
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_school.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          if (_isIntro)
            Positioned(
              bottom: -screenSize.height * 0.05,
              left: screenSize.width * 0.15,
              height: screenSize.height * 0.65,
              child: _WalkingAnimalEntrance(
                walkDuration: const Duration(milliseconds: 1800),
                stepDuration: const Duration(milliseconds: 260),
                bounceHeightPx: screenSize.height * 0.045,
                child: Image.asset('assets/images/characters/kiki_the_cat.png'),
              ),
            ),

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

          if (!_isIntro && _assignedWrong1 != null)
            _buildChildCharacter(
              config: _assignedWrong1!,
              isTarget: false,
              screenSize: screenSize,
            ),

          if (!_isIntro && _assignedWrong2 != null)
            _buildChildCharacter(
              config: _assignedWrong2!,
              isTarget: false,
              screenSize: screenSize,
            ),

          if (!_isIntro && _assignedTarget != null)
            _buildChildCharacter(
              config: _assignedTarget!,
              isTarget: true,
              screenSize: screenSize,
            ),

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
                            const WeatherSceneBuilderScreen(level: 16),
                      ),
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    _currentLevelIndex = 0;
                    _showSuccessUI = false;
                    _isIntro = true;
                    _hasSavedResult = false;
                    _isTargetMoving = false;
                    _isWalkingAway = false;
                    _tapTracker.startSession();
                  });
                  _assignCurrentLevelPositions();
                  _playIntroSequence();
                },
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

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
