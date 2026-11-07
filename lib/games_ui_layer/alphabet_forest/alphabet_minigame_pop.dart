import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/forest_database_service.dart';
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_mail_delivery.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'alphabet_game_ui.dart';
import 'forest_flow.dart';
import 'forest_game_acorn_basket.dart';
import 'forest_game_berry_bush_harvest.dart';
import 'forest_game_butterfly_flower.dart';
import 'forest_game_letter_match.dart';
import 'forest_game_mushroom_hidenseek.dart';
import 'forest_game_paw_print.dart';
import 'forest_game_stick_letter_builder.dart';
import 'forest_game_yak_zebra_race.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlphabetPopScreen extends StatefulWidget {
  final List<String> letters;
  const AlphabetPopScreen({super.key, required this.letters});

  @override
  State<AlphabetPopScreen> createState() => _AlphabetPopScreenState();
}

class _AlphabetPopScreenState extends State<AlphabetPopScreen>
    with
        TofiReactionMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<AlphabetPopScreen>,
        IdleHintMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _tofiPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _tofiPlayer];

  @override
  AudioPlayer get tofiPlayer => _tofiPlayer;

  final Random _random = Random();

  final GameTapTracker _tapTracker = GameTapTracker();

  Timer? _gameTimer;
  final List<BouncingBall> _activeBalls = [];

  int _correctCount = 0;
  final List<Map<String, double>> _wrongEffects = [];

  final List<double> _lanes = [0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.82, 0.92];

  late List<double> _availableLanes;

  static const String _popInstructionWav = 'assets/audio/alphabet_forest/alphabet_minigame_pop_instruction.wav';

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _inputEnabled = false;

  static const int _targetsPerRound = 3;

  int _roundIndex = 0;
  String get _target =>
      widget.letters[min(_roundIndex, widget.letters.length - 1)].toUpperCase();

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

    _generateBalls();
    _startGameLoop();
    _playInstructionThenLetter();
  }

  void _generateBalls() {
    _activeBalls.clear();
    _availableLanes = List.from(_lanes)..shuffle();

    final others = _distractorLetters();
    for (int i = 0; i < 5; i++) {
      _activeBalls.add(_createBall(others[i % others.length]));
    }
    for (int i = 0; i < _targetsPerRound; i++) {
      _activeBalls.add(_createBall(_target));
    }
  }

  List<String> _distractorLetters() {
    final others = widget.letters
        .map((l) => l.toUpperCase())
        .where((l) => l != _target)
        .toList();

    if (others.length < 2) {
      final first = widget.letters.first.toUpperCase().codeUnitAt(0);
      final earlier = [for (var c = 65; c < first; c++) String.fromCharCode(c)]
        ..shuffle();
      others.addAll(earlier.take(2 - others.length));
    }
    return others;
  }

  BouncingBall _createBall(String letter) {
    double x;

    if (_availableLanes.isNotEmpty) {
      x = _availableLanes.removeLast();
    } else {
      x = 0.30 + _random.nextDouble() * 0.64;
    }

    double y = 0.05 + _random.nextDouble() * 0.45;

    return BouncingBall(
      id: UniqueKey().toString(),
      key: GlobalKey(),
      letter: letter,
      xPos: x,
      yPos: y,
      dx: 0,
      dy: 0,
      isPopped: false,
    );
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;

      setState(() {
        for (var ball in _activeBalls) {
          if (ball.isPopped) continue;

          ball.dy += 0.00015;

          ball.yPos += ball.dy;
          ball.xPos += ball.dx;

          if (ball.yPos >= 1.0) {
            ball.yPos = 1.0;
            ball.dy = -(0.014 + _random.nextDouble() * 0.005);
          }

          if (ball.yPos <= 0.0) {
            ball.yPos = 0.0;
            ball.dy = ball.dy.abs();
          }
        }
      });
    });
  }

  Future<void> _onBallTap(BouncingBall ball) async {
    if (!_inputEnabled || ball.isPopped) return;

    if (ball.letter == _target) {
      _tapTracker.recordCorrectTap();

      final bool roundDone = _correctCount + 1 >= _targetsPerRound;
      final bool lastRound = _roundIndex + 1 >= widget.letters.length;
      if (roundDone) cancelIdleTimer();

      // pop first, so a double tap can't count the same ball twice
      setState(() {
        ball.isPopped = true;
        _correctCount++;
        if (roundDone) _inputEnabled = false;
      });
      unawaited(showTofiReaction(TofiState.correct));

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _activeBalls.removeWhere((b) => b.id == ball.id));
        }
      });

      try {
        await _playTargetSound();
      } catch (e) {
        debugPrint('Target audio error: $e');
      }
      if (!mounted || !roundDone) return;

      if (lastRound) {
        _gameTimer?.cancel();
        _saveDataAndShowApplause();
      } else {
        _nextRound();
      }
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTofiReaction(TofiState.wrong);

      final double tapX = ball.xPos;
      final double tapY = ball.yPos;
      setState(() => _wrongEffects.add({'x': tapX, 'y': tapY}));

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _wrongEffects.removeWhere(
                  (e) => e['x'] == tapX && e['y'] == tapY,
            );
          });
        }
      });
    }
  }

  Future<void> _nextRound() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _roundIndex++;
      _correctCount = 0;
      _generateBalls();
    });

    try {
      await _playTargetSound();
    } catch (e) {
      debugPrint('Target audio error: $e');
    }
    if (!mounted) return;
    setState(() => _inputEnabled = true);
    startIdleTimer();
  }

  Future<void> _playInstructionThenLetter() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        _popInstructionWav,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      await _playTargetSound();
    } catch (e) {
      debugPrint('Instruction audio error: $e');
    }
    if (mounted) {
      setState(() => _inputEnabled = true);
      startIdleTimer();
    }
  }

  Future<void> _playTargetSound() => playVoiceRestartingOnFaceLoss(
    _audioPlayer,
    'assets/audio/alphabet_forest/sound_effects/sound_${_target.toLowerCase()}.wav',
  );

  void _replayTarget() => _playTargetSound().catchError((_) {});

  Future<void> _saveDataAndShowApplause() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'letter_pop_${widget.letters.map((l) => l.toLowerCase()).join()}',
      activityName: "Alphabet Pop (${widget.letters.map((l) => l.toUpperCase()).join(', ')})",
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    _showApplause();
  }

  void _showApplause() {
    ForestProgressService.instance.markLevelComplete(
      ForestFlow.levelOf(widget.letters),
    );

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
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ForestFlow.screenAfter(widget.letters),
              ),
            );
          },
          onRestart: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AlphabetPopScreen(letters: widget.letters),
              ),
            );
          },
          onBack: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ForestLevelScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _audioPlayer.dispose();
    _tofiPlayer.dispose();
    disposeAiCamera();
    disposeIdleTimer();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double ballSize = (screenSize.height * 0.22).clamp(80.0, 150.0);
    final double letterFontSize = ballSize * 0.55;
    final preview = _previewBalls();

    return Listener(
      onPointerDown: (_) {
        if (_inputEnabled && !_hasSavedResult) resetIdleTimer();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/backgrounds/bg_game_forest.png',
                fit: BoxFit.cover,
              ),
            ),
            Stack(
              children: [
                buildTofi(context),

                Positioned(top: 25, left: 25, child: ForestXButton()),

                Positioned(
                  top: 25,
                  right: 20,
                  child: ForestLevelBadge(
                    level: ForestFlow.levelOf(widget.letters),
                  ),
                ),

                Positioned(
                  top: 25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _inputEnabled ? _replayTarget : null,
                      child: _buildTargetCard(_target),
                    ),
                  ),
                ),

                Positioned(
                  top: screenSize.height * 0.30,
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          ..._activeBalls.map((ball) {
                            return Positioned(
                              left:
                                  ball.xPos * (constraints.maxWidth - ballSize),
                              top:
                                  ball.yPos *
                                  (constraints.maxHeight - ballSize),
                              child: GestureDetector(
                                key: ball.key,
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _onBallTap(ball),
                                child: Opacity(
                                  opacity: _inputEnabled ? 1.0 : 0.7,
                                  child: SizedBox(
                                    width: ballSize,
                                    height: ballSize,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Image.asset(
                                          ball.isPopped
                                              ? 'assets/images/objects/forest/ball_popped.png'
                                              : 'assets/images/objects/forest/ball.png',
                                          fit: BoxFit.contain,
                                        ),
                                        if (!ball.isPopped)
                                          Text(
                                            ball.letter,
                                            textScaler: const TextScaler.linear(
                                              1.0,
                                            ),
                                            style: TextStyle(
                                              fontFamily:
                                                  ForestAppTextStyles.fredoka,
                                              fontSize: letterFontSize,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              shadows: const [
                                                Shadow(
                                                  blurRadius: 6,
                                                  color: Colors.black87,
                                                  offset: Offset(2, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),

            if (showHowToPlay && _inputEnabled && !_hasSavedResult)
              Positioned.fill(
                child: HowToPlayOverlay(
                  previewChild: _buildHowToPreview(
                    screenSize, ballSize, letterFontSize, preview,
                  ),
                  handAlignment: _handAlignmentForBall(
                    screenSize, ballSize, preview[1].$2, preview[1].$3,
                  ),
                  handOffset: const Offset(0.15, 0.60),
                  onDismiss: resetIdleTimer,
                ),
              ),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard(String letter, {double size = 84}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ForestColorTheme.darkseagreen, width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        textScaler: const TextScaler.linear(1.0),
        style: TextStyle(
          fontFamily: ForestAppTextStyles.fredoka,
          fontSize: size * 0.62,
          height: 1,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF3C5729),
        ),
      ),
    );
  }

// Static sample from letters NOT in this level; index 1 is the match.
// (letter, xPos, yPos), same 0..1 space as the live balls
  List<(String, double, double)> _previewBalls() {
    final inLevel = widget.letters.map((l) => l.toUpperCase()).toSet();
    final spare = [for (var c = 65; c < 91; c++) String.fromCharCode(c)]
        .where((l) => !inLevel.contains(l))
        .toList();
    final s = spare[0], a = spare[1], b = spare[2];
    return [(a, 0.12, 0.25), (s, 0.40, 0.55), (b, 0.68, 0.20), (s, 0.88, 0.60)];
  }

  Alignment _handAlignmentForBall(Size s, double ballSize, double x, double y) {
    final double areaW = s.width - 40;
    final double areaH = s.height * 0.70 - 20;

    final double cx = 20 + x * (areaW - ballSize) + ballSize / 2;
    final double cy = s.height * 0.30 + y * (areaH - ballSize) + ballSize / 2;

    return Alignment((2 * cx / s.width) - 1, (2 * cy / s.height) - 1);
  }

  Widget _buildHowToPreview(
      Size screenSize,
      double ballSize,
      double letterFontSize,
      List<(String, double, double)> balls,
      ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/backgrounds/bg_game_forest.png', fit: BoxFit.cover),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(child: _buildTargetCard(balls[1].$1)),
        ),
        Positioned(
          top: screenSize.height * 0.30,
          bottom: 20,
          left: 20,
          right: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: balls.map((b) {
                  return Positioned(
                    left: b.$2 * (constraints.maxWidth - ballSize),
                    top: b.$3 * (constraints.maxHeight - ballSize),
                    child: SizedBox(
                      width: ballSize,
                      height: ballSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset('assets/images/objects/forest/ball.png', fit: BoxFit.contain),
                          Text(
                            b.$1,
                            textScaler: const TextScaler.linear(1.0),
                            style: TextStyle(
                              fontFamily: ForestAppTextStyles.fredoka,
                              fontSize: letterFontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black87, offset: Offset(2, 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class BouncingBall {
  final String id;
  final GlobalKey key;
  final String letter;
  double xPos;
  double yPos;
  double dx;
  double dy;
  bool isPopped;

  BouncingBall({
    required this.id,
    required this.key,
    required this.letter,
    required this.xPos,
    required this.yPos,
    required this.dx,
    required this.dy,
    required this.isPopped,
  });
}
