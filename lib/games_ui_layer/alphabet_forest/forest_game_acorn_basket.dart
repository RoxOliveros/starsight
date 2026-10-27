import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/forest_database_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_buttons.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'alphabet_game_ui.dart';
import 'alphabet_intro.dart';
import 'forest_audio_path.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AcornBasketGame extends StatefulWidget {
  final int level;

  const AcornBasketGame({super.key, required this.level});

  @override
  State<AcornBasketGame> createState() => _AcornBasketGameState();
}

class _AcornDragData {
  final int laneIndex;
  final String letter;

  const _AcornDragData(this.laneIndex, this.letter);
}

class _FallingLane {
  String letter;
  final AnimationController controller;
  final double xFraction;
  bool isBusy = false;

  _FallingLane({
    required this.letter,
    required this.controller,
    required this.xFraction,
  });
}

class _AcornBasketGameState extends State<AcornBasketGame>
    with
        TickerProviderStateMixin,
        GameLoadingMixin,
        TofiReactionMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<AcornBasketGame>,
        IdleHintMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _tofiPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _tofiPlayer];

  @override
  AudioPlayer get tofiPlayer => _tofiPlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  static const List<String> _letterPool = ['D', 'E', 'F', 'd', 'e', 'f'];
  static const List<double> _laneXFractions = [0.12, 0.38, 0.64, 0.88];

  late final List<String> _roundLetters;
  late final List<_FallingLane> _lanes;

  late String _targetLetter;

  int _currentRound = 0;
  static const int _totalRounds = 5;

  static const int _catchesPerRound = 1;
  int _catchesThisRound = 0;

  bool _roundLocked = false;
  bool _wrongHoverFlash = false;

  late AnimationController _basketPulseController;
  late AnimationController _wrongShakeController;

  bool _introPlaying = true;
  late AnimationController _tofiFloatCtrl;

  final Random _rand = Random();

  final List<String> _basketAcorns = [];

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _inputEnabled = false;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _basketPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _wrongShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _lanes = _laneXFractions
        .map(
          (x) => _FallingLane(
            letter: 'A',
            xFraction: x,
            controller: AnimationController(vsync: this),
          ),
        )
        .toList();

    for (final lane in _lanes) {
      lane.controller.addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            !lane.isBusy &&
            !_roundLocked &&
            mounted) {
          _spawnLane(lane);
        }
      });
    }

    _roundLetters = List<String>.of(_letterPool)..shuffle(_rand);
    _basketAcorns.clear();
    _loadRound();

    finishLoading(_startIntroFlow);
  }

  Future<void> _startIntroFlow() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));

      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        'assets/audio/alphabet_forest/acorn_intro.wav',
      );

      if (!mounted) return;

      setState(() {
        _introPlaying = false;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        'assets/audio/alphabet_forest/acorn_instruction.wav',
      );

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 150));

      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        ForestAudioAssets.forLetter(_targetLetter),
      );
    } catch (e) {
      debugPrint('Intro audio error: $e');
    } finally {
      if (mounted) {
        setState(() => _inputEnabled = true);
        startIdleTimer();
      }
    }
  }

  String _pickLetterForLane(_FallingLane lane) {
    final othersHaveTarget = _lanes.any(
      (l) => l != lane && l.letter == _targetLetter,
    );
    if (!othersHaveTarget) return _targetLetter;

    if (_rand.nextBool()) return _targetLetter;

    final others = _letterPool.where((l) => l != _targetLetter).toList();
    return others[_rand.nextInt(others.length)];
  }

  void _spawnLane(_FallingLane lane) {
    lane.letter = _pickLetterForLane(lane);
    final durationMs = 4500 + _rand.nextInt(2600);
    lane.controller.duration = Duration(milliseconds: durationMs);
    lane.controller.forward(from: 0);

    if (mounted) setState(() {});
  }

  void _loadRound() {
    _targetLetter = _roundLetters[_currentRound % _roundLetters.length];
    _catchesThisRound = 0;
    _roundLocked = false;
    _wrongHoverFlash = false;

    if (_currentRound == 0) {
      for (final lane in _lanes) {
        lane.isBusy = false;
        _spawnLane(lane);
      }
    } else {
      for (final lane in _lanes) {
        if (lane.isBusy) continue;
        lane.letter = _targetLetter;
        if (lane.controller.isCompleted) _spawnLane(lane);
      }
    }

    if (!_lanes.any((l) => l.letter == _targetLetter)) {
      final free = _lanes.firstWhere(
        (l) => !l.isBusy,
        orElse: () => _lanes.first,
      );
      free.letter = _targetLetter;
    }

    setState(() {});
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _basketPulseController.dispose();
    _wrongShakeController.dispose();
    for (final lane in _lanes) {
      lane.controller.dispose();
    }
    _audioPlayer.dispose();
    _tofiPlayer.dispose();
    _tofiFloatCtrl.dispose();
    super.dispose();
  }

  void _onAcornAccepted(_AcornDragData data) {
    final lane = _lanes[data.laneIndex];

    if (_roundLocked) {
      lane.isBusy = false;
      return;
    }

    if (data.letter == _targetLetter) {
      _handleCorrect(lane);
    } else {
      _handleWrong(lane);
    }
  }

  void _handleCorrect(_FallingLane lane) {
    _tapTracker.recordCorrectTap();
    showTofiReaction(TofiState.correct);

    _basketPulseController.forward(from: 0);

    _catchesThisRound++;
    _basketAcorns.add(lane.letter);
    lane.isBusy = false;

    if (_catchesThisRound >= _catchesPerRound) {
      _roundLocked = true;
      cancelIdleTimer();

      _currentRound++;

      if (_currentRound >= _totalRounds) {
        Future.delayed(const Duration(milliseconds: 700), () async {
          if (!mounted) return;

          ForestProgressService.instance
              .markLevelComplete(widget.level)
              .catchError((e) {
                debugPrint("Database Error marking level complete: $e");
              });

          if (!mounted) return;

          _saveDataAndShowGoodJob();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 700), () async {
          if (!mounted) return;

          setState(() => _inputEnabled = false);
          _loadRound();

          try {
            await Future.delayed(const Duration(milliseconds: 200));
            if (!mounted) return;

            await playVoiceRestartingOnFaceLoss(
              _audioPlayer,
              ForestAudioAssets.forLetter(_targetLetter),
            );
          } catch (e) {
            debugPrint('Round audio error: $e');
          } finally {
            if (mounted) {
              setState(() => _inputEnabled = true);
              startIdleTimer();
            }
          }
        });
      }
    } else {
      _spawnLane(lane);
    }

    setState(() {});
  }

  void _handleWrong(_FallingLane lane) {
    _tapTracker.recordMistake();
    GamesSfxPlayer.instance.play(GameSfx.bubblePop);
    showTofiReaction(TofiState.wrong);

    setState(() {
      _wrongHoverFlash = true;
    });

    _wrongShakeController.forward(from: 0);

    lane.isBusy = false;
    lane.controller.forward(from: lane.controller.value);

    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() {
        _wrongHoverFlash = false;
      });
    });
  }

  Future<void> _saveDataAndShowGoodJob() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'forest_acorn_basket',
      activityName: "Acorn Basket",
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    await Future.delayed(Duration(seconds: 2));
    if (!mounted) return;

    _showGoodJob();
  }

  void _showGoodJob() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: 'assets/images/characters/dog.png',

          onNext: () {
            Navigator.of(context).pop(); // close the dialog
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlphabetIntroScreen(letter: 'G'),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop(); // close the dialog
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AcornBasketGame(level: widget.level),
              ),
            );
          },
          onBack: () {
            Navigator.of(context).pop(); // close the dialog
            Navigator.of(
              context,
            ).pop(); // pop AcornBasket → back to level screen
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Listener(
      onPointerDown: (_) {
        if (_inputEnabled && !_roundLocked && !_hasSavedResult) {
          resetIdleTimer();
        }
      },
      child: Scaffold(
        body: buildWithLoading(
          loadingScreen: LoadingScreen.alphabetForest(),
          gameBuilder: () => Stack(
            children: [
              if (_introPlaying) _buildIntroLayer() else _buildGameContent(),

              if (showHowToPlay &&
                  !_introPlaying &&
                  _inputEnabled &&
                  !_roundLocked &&
                  !_hasSavedResult)
                Positioned.fill(
                  child: HowToPlayOverlay(
                    previewChild: _buildHowToPreview(screenSize),
                    handAlignment: _toAlignment(
                      _sampleAcornCenter(screenSize),
                      screenSize,
                    ),
                    handEndAlignment: _toAlignment(
                      _basketCenter(screenSize),
                      screenSize,
                    ),
                    handOffset: const Offset(0.15, 0.4),
                    onDismiss: resetIdleTimer,
                  ),
                ),

              if (hasCapturedFirstFrame &&
                  !isFaceDetected &&
                  !_hideLightingCard)
                LightingPromptCard(
                  onClose: () {
                    setState(() => _hideLightingCard = true);
                    releaseFaceGate(); // don't leave the tutorial audio waiting
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/bg_game_forest.png',
            fit: BoxFit.cover,
          ),
        ),

        const Positioned(top: 25, left: 25, child: ForestXButton()),

        Positioned(
          top: 25,
          right: 20,
          child: ForestLevelBadge(level: widget.level),
        ),

        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _tofiFloatCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    0,
                    Tween<double>(begin: -6, end: 6).evaluate(
                      CurvedAnimation(
                        parent: _tofiFloatCtrl,
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ),
                  child: child,
                ),
                child: Image.asset(
                  'assets/images/characters/dog.png',
                  height: screenH * .72,
                ),
              ),

              const SizedBox(width: 120),

              Image.asset(
                'assets/images/objects/forest/acorn.png',
                height: screenH * .35,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/bg_game_forest.png',
            fit: BoxFit.cover,
          ),
        ),

        const Positioned(top: 25, left: 25, child: ForestXButton()),

        Positioned(
          bottom: 15,
          left: 0,
          right: 0,
          child: _buildRoundIndicator(),
        ),

        Positioned(
          top: 25,
          right: 20,
          child: ForestLevelBadge(level: widget.level),
        ),

        // BASKET — bottom-left
        Positioned(
          bottom: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 6),
              _BasketTarget(
                basketAcorns: _basketAcorns,
                pulseController: _basketPulseController,
                shakeController: _wrongShakeController,
                isWrongHover: _wrongHoverFlash,
                onAccept: _onAcornAccepted,
              ),
            ],
          ),
        ),

        buildTofi(context),

        // FALLING ACORN RAIN ZONE
        Positioned(
          top: 110,
          bottom: 60,
          left: 0,
          right: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final zoneW = constraints.maxWidth;
              final zoneH = constraints.maxHeight;

              return Stack(
                clipBehavior: Clip.none,
                children: List.generate(_lanes.length, (i) {
                  final lane = _lanes[i];
                  const acornSize = 92.0;

                  return AnimatedBuilder(
                    animation: lane.controller,
                    builder: (context, child) {
                      final t = lane.controller.value;
                      final top = (-acornSize) + (zoneH + acornSize * 2) * t;
                      final left = zoneW * lane.xFraction - acornSize / 2;
                      final sway = sin(t * pi * 2 + i) * 12;
                      final rotation = sin(t * pi * 2 + i) * 0.10;

                      return Positioned(
                        top: top,
                        left: left + sway,
                        child: Transform.rotate(angle: rotation, child: child!),
                      );
                    },
                    child: _FallingAcorn(
                      laneIndex: i,
                      letter: lane.letter,
                      size: acornSize,
                      onDragStarted: () {
                        lane.isBusy = true;
                        cancelIdleTimer();
                      },
                      onDragEnd: () {
                        lane.isBusy = false;
                        if (_inputEnabled &&
                            !_roundLocked &&
                            !_hasSavedResult) {
                          startIdleTimer();
                        }
                      },
                      enabled: _inputEnabled,
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  static const double _sampleAcornSize = 92.0;
  static const double _basketHeight = 170.0;

  // Sample acorn position (upper-middle of the rain zone).
  Offset _sampleAcornCenter(Size s) => Offset(s.width * 0.38, s.height * 0.35);

  // Basket centre: bottom: 20, right: 20, height 170.
  Offset _basketCenter(Size s) => Offset(
    s.width - 20 - _basketHeight / 2,
    s.height - 20 - _basketHeight / 2,
  );

  Alignment _toAlignment(Offset c, Size s) {
    return Alignment((2 * c.dx / s.width) - 1, (2 * c.dy / s.height) - 1);
  }

  Widget _buildHowToPreview(Size s) {
    final Offset acorn = _sampleAcornCenter(s);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/bg_game_forest.png',
          fit: BoxFit.cover,
        ),

        Positioned(
          bottom: 20,
          right: 20,
          child: Image.asset(
            'assets/images/objects/puzzle/basket.png',
            height: _basketHeight,
            fit: BoxFit.contain,
          ),
        ),

        Positioned(
          left: acorn.dx - _sampleAcornSize / 2,
          top: acorn.dy - _sampleAcornSize / 2,
          child: _FallingAcorn(
            laneIndex: 0,
            letter: 'D',
            size: _sampleAcornSize,
            onDragStarted: () {},
            onDragEnd: () {},
            enabled: false,
          ),
        ),
      ],
    );
  }

  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _currentRound;
        final current = i == _currentRound && _currentRound < _totalRounds;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ForestColorTheme.darkseagreen
                : current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// _FallingAcorn — a single draggable acorn riding its lane's fall animation.
/// ─────────────────────────────────────────────────────────────────────────
class _FallingAcorn extends StatelessWidget {
  final int laneIndex;
  final String letter;
  final double size;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final bool enabled;

  const _FallingAcorn({
    required this.laneIndex,
    required this.letter,
    required this.size,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.enabled,
  });

  Widget _acornVisual({double? overrideSize}) {
    final s = overrideSize ?? size;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/objects/forest/acorn.png',
            width: s,
            height: s,
            fit: BoxFit.contain,
          ),

          // Letter in the center of the acorn
          Positioned(
            top: s * 0.40,
            left: s * 0.32,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: s * 0.32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<_AcornDragData>(
      data: _AcornDragData(laneIndex, letter),
      maxSimultaneousDrags: enabled ? 1 : 0,
      onDragStarted: onDragStarted,
      onDraggableCanceled: (_, __) => onDragEnd(),
      onDragCompleted: onDragEnd,
      feedback: Material(
        color: Colors.transparent,
        child: _acornVisual(overrideSize: size * 1.15),
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: _acornVisual(),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// _BasketTarget — the drop target the child drags acorns into.
/// ─────────────────────────────────────────────────────────────────────────
class _BasketTarget extends StatelessWidget {
  final AnimationController pulseController;
  final AnimationController shakeController;
  final bool isWrongHover;
  final List<String> basketAcorns;
  final void Function(_AcornDragData data) onAccept;

  const _BasketTarget({
    required this.pulseController,
    required this.shakeController,
    required this.isWrongHover,
    required this.basketAcorns,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<_AcornDragData>(
      onWillAccept: (_) => true,
      onAccept: onAccept,
      builder: (context, candidateData, rejectedData) {
        return AnimatedBuilder(
          animation: Listenable.merge([pulseController, shakeController]),
          builder: (context, child) {
            final pulseT = pulseController.value;
            final pulseScale = pulseController.isAnimating
                ? 1.0 + (sin(pulseT * pi) * 0.18)
                : 1.0;

            final shakeT = shakeController.value;
            final shakeOffsetX = shakeController.isAnimating
                ? sin(shakeT * pi * 4) * 8 * (1 - shakeT)
                : 0.0;

            return Transform.translate(
              offset: Offset(shakeOffsetX, 0),
              child: Transform.scale(scale: pulseScale, child: child),
            );
          },
          child: Container(
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/objects/puzzle/basket.png',
                  height: 170,
                  fit: BoxFit.contain,
                ),

                ...List.generate(basketAcorns.length, (i) {
                  const positions = [
                    Offset(20, 20), // left
                    Offset(60, 16), // center
                    Offset(100, 28), // right
                    Offset(30, 72), // bottom-left
                    Offset(83, 85), // bottom-right
                  ];

                  final p = positions[i];

                  return Positioned(
                    left: p.dx,
                    top: p.dy,
                    child: SizedBox(
                      height: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset('assets/images/objects/forest/acorn.png'),

                          Positioned(
                            top: 28,
                            left: 16,
                            child: Text(
                              basketAcorns[i],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 3),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
