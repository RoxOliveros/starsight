import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_stars_screen.dart';
import 'package:StarSight/ui_layer/lumi_town/town_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../tryagain_prompt.dart';
import '../lumi_game_ui_layer.dart';
import 'character_entrance.dart';
import 'sharing_tutorial_prompt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';

class Sharing2 extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Sharing2({
    super.key,
    required this.priorEmotions,
    required this.tapTracker, required this.level,
  });

  @override
  State<Sharing2> createState() => _Sharing2State();
}

class _Sharing2State extends State<Sharing2> with AiCameraMixin<Sharing2> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── State Variables ──────────────────────────────────────────────────
  Timer? _cancelBtnTimer;

  String _currentMood = 'normal';

  bool _showCancelBtn = false;
  bool _readyForEntrance = false;
  bool _showSadBearFailedUI = false;
  bool _showAllCharactersSuccessUI = false;
  bool _showGoodJobOverlay = false;
  bool _showTryAgainButton = false;
  bool _showTutorial = true;
  bool _secondFoxCanceled = false;
  bool _canGive = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _hasGivenPancake = false;
  bool _hasGivenWater = false;
  bool _bearPhase = false;
  bool _isCancelProcessing = false;

  int _pancakesLeft = 7;
  int _waterLeft = 7;
  int _charIndex = 0;

  final int _retryCount = 0;

  static const Map<String, String> characters = {
    'bunny': 'assets/images/characters/roxie_the_rabbit.png',
    'cat': 'assets/images/characters/kiki_the_cat.png',
    'fox': 'assets/images/characters/jack_the_fox.png',
    'penguin': 'assets/images/characters/doma_the_penguin2.png',
    'owl': 'assets/images/characters/tr.woo_the_owl.png',
    'dog': 'assets/images/characters/tofi_the_dog.png',
  };

  static const Map<String, String> charactersSmiling = {
    'bunny': 'assets/images/characters/roxie_try_again.png',
    'cat': 'assets/images/characters/kiki_smiling.png',
    'fox': 'assets/images/characters/jack_smiling.png',
    'penguin': 'assets/images/characters/doma_smiling.png',
    'owl': 'assets/images/characters/tr.woo_smiling.png',
    'dog': 'assets/images/characters/tofi_smiling.png',
  };

  static const Map<String, String> characterThankYouVoiceovers = {
    'bunny': 'audio/lumi_town/level5/bunny_thankyou.wav',
    'cat': 'audio/lumi_town/level5/cat_thankyou.wav',
    'fox': 'audio/lumi_town/level5/fox_thankyou.wav',
    'penguin': 'audio/lumi_town/level5/penguin_thankyou.wav',
    'owl': 'audio/lumi_town/level5/owl_thankyou.wav',
    'dog': 'audio/lumi_town/level5/dog_thankyou.wav',
  };

  final List<String> _sequence = [
    'bunny',
    'cat',
    'fox',
    'penguin',
    'owl',
    'fox',
    'dog',
  ];

  String get currentCharacterImage {
    if (_bearPhase) return 'assets/images/characters/little_bear_uniform.png';

    String charKey = _sequence[_charIndex];

    if (_currentMood == 'smiling') {
      return charactersSmiling[charKey] ?? characters[charKey]!;
    } else if (_currentMood == 'sad' && charKey == 'fox') {
      return 'assets/images/characters/jack_sad.png';
    }

    return characters[charKey] ?? characters['bunny']!;
  }

  @override
  void initState() {
    super.initState();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _lockOrientationThenStartEntrance();

    if (!_showTutorial) {
      _startRoundAudioAndTimers();
    }
  }

  void _startRoundAudioAndTimers() {
    _cancelBtnTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showCancelBtn = true;
        });
      }
    });
  }

  void _handleTutorialClose() {
    setState(() {
      _showTutorial = false;
    });
    _startRoundAudioAndTimers();
  }

  void _setReady(bool ready) {
    _readyForEntrance = ready;
    _canGive = false;
  }

  Future<void> _lockOrientationThenStartEntrance() async {
    OrientationService.setLandscape();

    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 250));

    if (mounted) {
      setState(() {
        _setReady(true);
      });
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    _cancelBtnTimer?.cancel();
    _audioPlayer.dispose();

    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _checkNextCharacter() async {
    final bool done = _hasGivenPancake && _hasGivenWater;

    if (done) {
      String currentCharKey = _sequence[_charIndex];

      setState(() {
        _currentMood = 'smiling';
      });

      String audioPath = _bearPhase
          ? 'audio/lumi_town/level5/littlebear_thankyou.wav'
          : (characterThankYouVoiceovers[currentCharKey] ??
          'audio/lumi_town/level5/littlebear_thankyou.wav');

      await _audioPlayer.play(AssetSource(audioPath));

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;

        if (_charIndex < _sequence.length - 1) {
          setState(() {
            _setReady(false);
            _charIndex++;
            _hasGivenPancake = false;
            _hasGivenWater = false;
            _currentMood = 'normal';
          });

          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            setState(() {
              _setReady(true);
            });
          });
        } else if (_secondFoxCanceled && !_bearPhase) {
        setState(() {
          _setReady(false);
          _bearPhase = true;
          _hasGivenPancake = false;
          _hasGivenWater = false;
          _currentMood = 'normal';
        });

        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {
            _setReady(true);
          });
        });
      } else {
          setState(() {
            _setReady(false);
          });

          if (_secondFoxCanceled) {
            _saveDataAndShowWinDialog();
          } else {
            setState(() {
              _showSadBearFailedUI = true;
            });
            _audioPlayer.play(
              AssetSource('audio/lumi_town/level5/sharing_wrong.wav'),
            );
            Future.delayed(const Duration(seconds: 17), () {
              if (!mounted) return;
              setState(() {
                _showTryAgainButton = true;
              });
            });
          }
        }
      });
    }
  }

  Future<void> _saveDataAndShowWinDialog() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;

    final finalEmotions = [...widget.priorEmotions, ...stopAiCamera()];

    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_sharing',
      activityName: 'Sharing',
      emotions: finalEmotions,
      totalTaps: widget.tapTracker.totalTaps,
      mistakes: widget.tapTracker.mistakeCount,
      timePlayedSeconds: widget.tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });
    TownProgressService.instance.markLevelComplete(widget.level).catchError((e) {
      debugPrint("Database Error marking level complete: $e");
    });

    if (mounted) {
      setState(() {
        _showAllCharactersSuccessUI = true;
      });
      _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showGoodJobOverlay = true;
          });
        }
      });
    }
  }

  void _handleCancel() {
    if (_isCancelProcessing) return;

    if (_charIndex != 5) {
      widget.tapTracker.recordMistake();
      _audioPlayer.play(
        AssetSource('audio/lumi_town/level5/cancel_wrong.wav'),
      );
      return;
    }

    _isCancelProcessing = true;

    widget.tapTracker.recordCorrectTap();

    setState(() {
      _showCancelBtn = false;

      _secondFoxCanceled = true;
      _currentMood = 'sad';
      _canGive = false;

      if (_hasGivenPancake) _pancakesLeft++;
      if (_hasGivenWater) _waterLeft++;

      _hasGivenPancake = false;
      _hasGivenWater = false;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      setState(() {
        _setReady(false);
        _charIndex++;
        _currentMood = 'normal';
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;

        setState(() {
          _setReady(true);
          _isCancelProcessing = false;
        });
      });
    });
  }

  Widget _positionedCharacter(
    String imagePath, {
    required double left,
    required double bottom,
    required double width,
    required int delayMs,
  }) {
    return Positioned(
      left: left,
      bottom: bottom,
      width: width,
      child: Image.asset(imagePath, fit: BoxFit.contain)
          .animate(
            onPlay: (c) => c.repeat(reverse: true),
            delay: Duration(milliseconds: delayMs),
          )
          .moveY(
            begin: 0,
            end: -14,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final double tableBottom = -sh * 0.60;
    final double tableWidth = sw;

    final double plateWidth = sw * 0.26;
    final double pancakeWidth = sw * 0.20;
    final double stackBaseOffset = sh * 0.055;
    final double pancakeThickness = sh * 0.055;

    final rng = math.Random(7);
    final List<double> jitterDx = List.generate(
      10,
      (_) => (rng.nextDouble() - 0.5) * pancakeWidth * 0.18,
    );

    final double glassWidth = sw * 0.075;
    final double glassSpacing = sw * 0.085;
    final double glassFrontRowOffset = sh * 0.04;
    final double glassBackRowOffset = sh * 0.12;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_park.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) =>
                  Container(color: const Color(0xFF90D060)),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  if (!_canGive) return false;
                  if (details.data == 'pancake' && !_hasGivenPancake) return true;
                  if (details.data == 'water' && !_hasGivenWater) return true;
                  return false;
                },
                onAcceptWithDetails: (details) {
                  widget.tapTracker.recordCorrectTap();
                  if (details.data == 'pancake') {
                    setState(() {
                      _pancakesLeft--;
                      _hasGivenPancake = true;
                    });
                  } else if (details.data == 'water') {
                    setState(() {
                      _waterLeft--;
                      _hasGivenWater = true;
                    });
                  }
                  _checkNextCharacter();
                },
                builder: (context, candidateData, rejectedData) {
                  return Center(
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        if (_readyForEntrance)
                          CharacterEntrance(
                            key: ValueKey('$_charIndex-$_retryCount-$_bearPhase'),
                            characterImagePath: currentCharacterImage,
                            characterHeightFraction: 0.95,
                            plateWidthFraction: 0.18,
                            plateHeightFraction: 0.24,
                            plateOffsetXFraction: -0.55,
                            primaryItemOverlayImagePath: _hasGivenPancake
                                ? 'assets/images/objects/lumi/pancke_maple_syrup_butter.png'
                                : null,
                            secondaryItemImagePath: _hasGivenWater
                                ? 'assets/images/objects/lumi/water_glass.png'
                                : null,
                            secondaryItemWidthFraction: 0.10,
                            secondaryItemOffsetXFraction: 0.40,
                            from: AxisDirection.right,
                            walkDuration: const Duration(milliseconds: 3000),
                            stepDuration: const Duration(milliseconds: 380),
                            onArrived: () {
                              if (!mounted) return;

                              setState(() {
                                _canGive = true;
                                _showCancelBtn = true;
                              });
                            },
                          )
                        else
                          const SizedBox.shrink(),
                      ],
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
                  width: tableWidth,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => Container(
                    height: sh * 0.22,
                    color: const Color(0xFFCD853F),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: stackBaseOffset,
              left: sw * 0.08,
              child: SizedBox(
                width: plateWidth,
                height: sh * 1.1,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: 0,
                      child: Image.asset(
                        'assets/images/objects/lumi/plate.png',
                        width: plateWidth,
                        errorBuilder: (ctx, err, st) => Container(
                          width: plateWidth,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    ...List.generate(_pancakesLeft, (index) {
                      final dx = jitterDx[index];
                      final isTop = index == _pancakesLeft - 1;

                      final pancakeWidget = Image.asset(
                        isTop
                            ? 'assets/images/objects/lumi/pancke_maple_syrup_butter.png'
                            : 'assets/images/objects/lumi/pancake.png',
                        width: pancakeWidth,
                      );

                      final positionedPancake = Positioned(
                        bottom: stackBaseOffset + (index * pancakeThickness),
                        left: plateWidth / 2 - pancakeWidth / 2 + dx,
                        child: AnimatedOpacity(
                          opacity: _canGive ? 1.0 : 0.35,
                          duration: const Duration(milliseconds: 250),
                          child: isTop
                              ? Draggable<String>(
                            data: 'pancake',
                            maxSimultaneousDrags: _canGive ? 1 : 0,
                            onDragEnd: (details) {
                              if (!details.wasAccepted) {
                                widget.tapTracker.recordMistake();
                              }
                            },
                            feedback: Material(
                              color: Colors.transparent,
                              child: pancakeWidget,
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: pancakeWidget,
                            ),
                            child: pancakeWidget,
                          )
                              : pancakeWidget,
                        ),
                      );

                      return positionedPancake;
                    }),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              right: sw * 0.05,
              child: SizedBox(
                width: sw * 0.40,
                height: sh * 0.45,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...List.generate(7, (index) {
                      if (index >= _waterLeft) return const SizedBox.shrink();

                      bool isFrontRow = index >= 4;
                      int rowIdx = isFrontRow ? index - 4 : index;
                      double bottom = isFrontRow
                          ? glassFrontRowOffset
                          : glassBackRowOffset;
                      double left = isFrontRow
                          ? (glassSpacing / 2) + (rowIdx * glassSpacing)
                          : rowIdx * glassSpacing;

                      final glassWidget = Image.asset(
                        'assets/images/objects/lumi/water_glass.png',
                        width: glassWidth,
                      );

                      return Positioned(
                        bottom: bottom,
                        left: left,
                        child: AnimatedOpacity(
                          opacity: _canGive ? 1.0 : 0.35,
                          duration: const Duration(milliseconds: 250),
                          child: Draggable<String>(
                            data: 'water',
                            maxSimultaneousDrags: _canGive ? 1 : 0,
                            onDragEnd: (details) {
                              if (!details.wasAccepted) {
                                widget.tapTracker.recordMistake();
                              }
                            },
                            feedback: Material(
                              color: Colors.transparent,
                              child: glassWidget,
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: glassWidget,
                            ),
                            child: glassWidget,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            if (_showCancelBtn)
              Positioned(
                bottom: sh * 0.05,
                right: sw * 0.02,
                child: IgnorePointer(
                  ignoring: !_canGive,
                  child: AnimatedOpacity(
                    opacity: _canGive ? 1.0 : 0.35,
                    duration: const Duration(milliseconds: 250),
                    child: GestureDetector(
                      onTap: _canGive ? _handleCancel : null,
                      child:
                      Image.asset(
                        'assets/images/objects/lumi/cancel_btn.png',
                        width: sw * 0.10,
                        errorBuilder: (ctx, err, st) => Icon(
                          Icons.cancel,
                          color: Colors.red,
                          size: sw * 0.10,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.06, 1.06),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                      )
                          .animate()
                          .scale(
                        begin: const Offset(0.0, 0.0),
                        end: const Offset(1.0, 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                      ),
                    ),
                  ),
                ),
              ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(top: 25, right: 25, child: LumiLevelBadge(level: widget.level)),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_showTutorial)
              Positioned.fill(
                key: const ValueKey('sharing_tutorial'),
                child: SharingTutorialPrompt(onClose: _handleTutorialClose),
              ),

            if (_showSadBearFailedUI)
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/backgrounds/bg_lumi_park.png',
                      fit: BoxFit.cover,
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          'assets/images/characters/bear_sad.png',
                          height: sh * 0.95,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: tableBottom,
                      left: 0,
                      right: 0,
                      child: Image.asset(
                        'assets/images/objects/lumi/table.png',
                        width: tableWidth,
                        fit: BoxFit.contain,
                      ),
                    ),

                    Positioned(
                      bottom: stackBaseOffset,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          'assets/images/objects/lumi/plate.png',
                          width: plateWidth,
                        ),
                      ),
                    ),

                    if (_showTryAgainButton)
                      Positioned.fill(
                        child: TryJobOverlay(
                          characterImage:
                              'assets/images/characters/tr.woo_smiling.png',
                          onRestart: () {
                            setState(() {
                              _showSadBearFailedUI = false;
                              _showTryAgainButton = false;
                              _charIndex = 0;
                              _pancakesLeft = 7;
                              _waterLeft = 7;
                              _hasGivenPancake = false;
                              _hasGivenWater = false;
                              _setReady(true);
                              _secondFoxCanceled = false;
                              _currentMood = 'normal';
                              _bearPhase = false;
                              _hasSavedResult = false;
                              widget.tapTracker.startSession();
                            });
                          },
                          onBack: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const LumiLevelScreen(),
                              ),
                              (route) => route.isFirst,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

            if (_showAllCharactersSuccessUI)
              Positioned.fill(
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            'assets/images/backgrounds/bg_lumi_park.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        alignment: Alignment.bottomCenter,
                        children: [

                          Positioned(top: 25, left: 25, child: LumiXButton()),
                          Positioned(top: 25, right: 25, child: LumiLevelBadge(level: widget.level)),

                          _positionedCharacter(
                            charactersSmiling['dog']!,
                            left: -sw * 0.02,
                            bottom: -sh * 0.15,
                            width: sw * 0.38,
                            delayMs: 0,
                          ),
                          _positionedCharacter(
                            charactersSmiling['cat']!,
                            left: sw * 0.62,
                            bottom: -sh * 0.12,
                            width: sw * 0.40,
                            delayMs: 150,
                          ),

                          _positionedCharacter(
                            charactersSmiling['bunny']!,
                            left: -sw * 0.01,
                            bottom: -sh * 0.22,
                            width: sw * 0.26,
                            delayMs: 300,
                          ),
                          _positionedCharacter(
                            charactersSmiling['penguin']!,
                            left: sw * 0.18,
                            bottom: -sh * 0.20,
                            width: sw * 0.26,
                            delayMs: 450,
                          ),
                          _positionedCharacter(
                            charactersSmiling['owl']!,
                            left: sw * 0.55,
                            bottom: -sh * 0.18,
                            width: sw * 0.28,
                            delayMs: 750,
                          ),
                          _positionedCharacter(
                            charactersSmiling['fox']!,
                            left: sw * 0.74,
                            bottom: -sh * 0.20,
                            width: sw * 0.28,
                            delayMs: 900,
                          ),

                          _positionedCharacter(
                            'assets/images/characters/little_bear_uniform.png',
                            left: sw * 0.33,
                            bottom: -sh * 0.28,
                            width: sw * 0.35,
                            delayMs: 600,
                          ),
                        ],
                      ),
                    ),

                    if (_showGoodJobOverlay)
                      GoodJobOverlay(
                        characterImage:
                            'assets/images/characters/tr.woo_smiling.png',

                        onNext: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => EmotionStarsScreen(level: widget.level + 1),
                            ),
                          );
                        },
                        onRestart: () {
                          setState(() {
                            _showAllCharactersSuccessUI = false;
                            _showGoodJobOverlay = false;
                            _charIndex = 0;
                            _pancakesLeft = 7;
                            _waterLeft = 7;
                            _hasGivenPancake = false;
                            _hasGivenWater = false;
                            _setReady(true);
                            _secondFoxCanceled = false;
                            _currentMood = 'normal';
                            _bearPhase = false;
                            _hasSavedResult = false;
                            widget.tapTracker.startSession();
                          });
                        },
                        onBack: () {
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const LumiLevelScreen(),
                              ),
                              (route) => route.isFirst,
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
