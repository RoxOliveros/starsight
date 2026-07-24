import 'dart:math';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_buttons.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../goodjob_prompt.dart';
import 'alphabet_game_ui.dart';
import 'alphabet_intro.dart';
import 'forest_audio_helper.dart';

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
  final double xFraction; // 0..1 horizontal position within the fall zone
  bool isBusy = false; // true while its acorn is being dragged / resolved

  _FallingLane({
    required this.letter,
    required this.controller,
    required this.xFraction,
  });
}

class _AcornBasketGameState extends State<AcornBasketGame>
    with TickerProviderStateMixin, GameLoadingMixin, ForestAudioMixin, TofiReactionMixin {

  @override
  AudioPlayer get tofiPlayer => _player;

  final AudioPlayer _player = AudioPlayer();

  static const List<String> _letterPool = [
    'D', 'E', 'F', 'd', 'e', 'f'
  ];

  static const List<double> _laneXFractions = [0.12, 0.38, 0.64, 0.88];

  late final List<_FallingLane> _lanes;

  late String _targetLetter;

  int _currentRound = 0;
  static const int _totalRounds = 5;

  // Child must drop this many correct-letter acorns per round.
  static const int _catchesPerRound = 1;
  int _catchesThisRound = 0;

  bool _roundLocked = false; // guards against overlap during round transition
  bool _wrongHoverFlash = false;

  late AnimationController _basketPulseController; // correct-drop "gulp"
  late AnimationController _wrongShakeController; // wrong-drop basket shake

  bool _introPlaying = true;
  late AnimationController _tofiFloatCtrl;

  final Random _rand = Random();

  final List<String> _basketAcorns = [];

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();

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

    _basketAcorns.clear();

    finishLoading(_startIntroFlow);
    _loadRound();
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));

    await playVoice(
      'assets/audio/alphabet_forest/acorn_intro.wav',
    );

    if (!mounted) return;

    setState(() {
      _introPlaying = false;
    });

    // Let the game appear first.
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await playVoice(
      'assets/audio/alphabet_forest/acorn_instruction.wav',
    );

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 150));

    playVoice(ForestAudioAssets.forLetter(_targetLetter));
  }

  String _pickLetterForLane() {
    // Weighted so the target letter shows up often enough to catch,
    // while distractors keep the round from being trivial.
    if (_rand.nextDouble() < 0.45) return _targetLetter;

    String distractor;
    do {
      distractor = _letterPool[_rand.nextInt(_letterPool.length)];
    } while (distractor.toUpperCase() == _targetLetter.toUpperCase());
    return distractor;
  }

  void _spawnLane(_FallingLane lane) {
    lane.letter = _pickLetterForLane();
    final durationMs = 4500 + _rand.nextInt(2600); // ~4.5s – 7.1s fall
    lane.controller.duration = Duration(milliseconds: durationMs);
    lane.controller.forward(from: 0);

    if (mounted) setState(() {});
  }

  void _loadRound() {
    final target = _letterPool[_rand.nextInt(_letterPool.length)];

    _targetLetter = target;
    _catchesThisRound = 0;
    _roundLocked = false;
    _wrongHoverFlash = false;

    // First time only: start the falling animation
    if (_currentRound == 0) {
      for (final lane in _lanes) {
        lane.isBusy = false;
        _spawnLane(lane);
      }
    } else {
      // Keep the acorns falling, just update the letters
      _refreshLaneLetters();
    }

    setState(() {});
  }

  void _refreshLaneLetters() {
    for (final lane in _lanes) {
      lane.letter = _pickLetterForLane();
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _basketPulseController.dispose();
    _wrongShakeController.dispose();
    for (final lane in _lanes) {
      lane.controller.dispose();
    }
    _player.dispose();
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
    showTofiReaction(TofiState.correct);

    _basketPulseController.forward(from: 0);

    _catchesThisRound++;
    _basketAcorns.add(lane.letter);
    lane.isBusy = false;

    if (_catchesThisRound >= _catchesPerRound) {
      _roundLocked = true;

      _currentRound++;

      if (_currentRound >= _totalRounds) {
        Future.delayed(const Duration(milliseconds: 700), () async {
          if (!mounted) return;

          await ForestProgressService.instance.markLevelComplete(widget.level);

          if (!mounted) return;

          _showGoodJob();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 700), () async {
          if (!mounted) return;

          _loadRound();

          await Future.delayed(const Duration(milliseconds: 200));

          if (mounted) {
            playVoice(ForestAudioAssets.forLetter(_targetLetter));
          }
        });
      }
    } else {
      // Round continues — this lane immediately drops a fresh acorn.
      _spawnLane(lane);
    }

    setState(() {});
  }

  void _handleWrong(_FallingLane lane) {
    showTofiReaction(TofiState.wrong);

    setState(() {
      _wrongHoverFlash = true;
    });

    _wrongShakeController.forward(from: 0);

    // The dropped Draggable snaps back to its own start position
    // automatically since the DragTarget rejects it. The lane's acorn
    // simply resumes its fall from wherever it paused mid-drag.
    lane.isBusy = false;
    lane.controller.forward(from: lane.controller.value);

    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() {
        _wrongHoverFlash = false;
      });
    });
  }

  void _showGoodJob() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) =>
          Material(
            type: MaterialType.transparency,
            child: GoodJobOverlay(
              characterImage: 'assets/images/characters/dog.png',
              closeButtonColor: ForestColorTheme.seagreen,
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
                Navigator.of(context).pop(); // pop AcornBasket → back to level screen
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.alphabetForest(),
        gameBuilder: () => Stack(
          children: [
            if (_introPlaying)
              _buildIntroLayer()
            else
              _buildGameContent(),
          ],
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

        const Positioned(
          top: 25,
          left: 20,
          child: ForestBackButton(),
        ),

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
                    Tween<double>(
                      begin: -6,
                      end: 6,
                    ).evaluate(
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

        const Positioned(top: 25, left: 20, child: ForestBackButton()),

        Positioned(
          top: 25,
          left: 0,
          right: 0,
          child: Center(
            child: ForestInstructionBanner(
              text: 'Put the $_targetLetter acorn in the basket!',
            ),
          ),
        ),

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

                      final top =
                          (-acornSize) + (zoneH + acornSize * 2) * t;

                      final left =
                          zoneW * lane.xFraction - acornSize / 2;

                      // Gentle left-right sway
                      final sway = sin(t * pi * 2 + i) * 12;

                      // Slight rotation
                      final rotation = sin(t * pi * 2 + i) * 0.10;

                      return Positioned(
                        top: top,
                        left: left + sway,
                        child: Transform.rotate(
                          angle: rotation,
                          child: child!,
                        ),
                      );
                    },
                    child: _FallingAcorn(
                      laneIndex: i,
                      letter: lane.letter,
                      size: acornSize,
                      onDragStarted: () => lane.isBusy = true,
                      onDragEnd: () => lane.isBusy = false,
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

  const _FallingAcorn({
    required this.laneIndex,
    required this.letter,
    required this.size,
    required this.onDragStarted,
    required this.onDragEnd,
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
                    Offset(20, 20),   // left
                    Offset(60, 16),   // center
                    Offset(100, 28),  // right
                    Offset(30, 72),   // bottom-left
                    Offset(83, 85),   // bottom-right
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
                          Image.asset(
                            'assets/images/objects/forest/acorn.png',
                          ),

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
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 3,
                                  ),
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