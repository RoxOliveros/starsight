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
  final String letter;

  const AlphabetPopScreen({super.key, required this.letter});

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
  final int _winCondition = 3;
  final List<Map<String, double>> _wrongEffects = [];

  final List<double> _lanes = [0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.82, 0.92];

  late List<double> _availableLanes;

  static const String _popInstructionWav =
      'assets/audio/alphabet_forest/alphabet_minigame_pop_instruction.wav';

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _inputEnabled = false;

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

    _availableLanes = List.from(_lanes);
    _availableLanes.shuffle();

    List<String> distractors = _getDistractorLetters(widget.letter);
    for (int i = 0; i < 5; i++) {
      String randomDistractor =
          distractors[_random.nextInt(distractors.length)];
      _activeBalls.add(_createBall(randomDistractor));
    }

    for (int i = 0; i < _winCondition; i++) {
      _activeBalls.add(_createBall(widget.letter.toUpperCase()));
    }
  }

  List<String> _getDistractorLetters(String target) {
    List<String> pool = [];
    for (int i = 65; i <= 90; i++) {
      String l = String.fromCharCode(i);
      if (l != target.toUpperCase()) pool.add(l);
    }
    return pool;
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

  void _onBallTap(BouncingBall ball) async {
    if (!_inputEnabled || ball.isPopped) return;

    if (ball.letter == widget.letter.toUpperCase()) {
      _tapTracker.recordCorrectTap();
      String audioFile =
          'assets/audio/alphabet_forest/sound_effects/sound_${widget.letter.toLowerCase()}.wav';

      await playVoiceRestartingOnFaceLoss(_audioPlayer, audioFile);

      showTofiReaction(TofiState.correct);

      setState(() {
        ball.isPopped = true;
        _correctCount++;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _activeBalls.removeWhere((item) => item.id == ball.id);
            if (_correctCount >= _winCondition) {
              _gameTimer?.cancel();
              _saveDataAndShowApplause();
            }
          });
        }
      });
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTofiReaction(TofiState.wrong);

      final double tapX = ball.xPos;
      final double tapY = ball.yPos;

      setState(() {
        _wrongEffects.add({'x': tapX, 'y': tapY});
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _wrongEffects.removeWhere(
              (effect) => effect['x'] == tapX && effect['y'] == tapY,
            );
          });
        }
      });
    }
  }

  Future<void> _playInstructionThenLetter() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        _popInstructionWav,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        'assets/audio/alphabet_forest/sound_effects/sound_${widget.letter.toLowerCase()}.wav',
      );
    } catch (e) {
      debugPrint('Instruction audio error: $e');
    }
    if (mounted) {
      setState(() => _inputEnabled = true);
      startIdleTimer();
    }
  }

  Future<void> _saveDataAndShowApplause() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'letter_pop_${widget.letter.toLowerCase()}',
      activityName: "Alphabet Pop (${widget.letter.toUpperCase()})",
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
    final String currentLetter = widget.letter.toUpperCase();

    const skipGoodJobLetters = {
      'A',
      'B',
      'D',
      'E',
      'G',
      'H',
      'J',
      'K',
      'M',
      'N',
      'P',
      'Q',
      'S',
      'T',
      'V',
      'W',
      'Y',
    };

    if (skipGoodJobLetters.contains(currentLetter)) {
      String nextLetter = String.fromCharCode(currentLetter.codeUnitAt(0) + 1);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlphabetIntroScreen(letter: nextLetter),
        ),
      );
      return;
    }

    const completeLevelsLetters = {'C', 'F', 'I', 'L', 'O', 'R', 'U', 'X', 'Z'};

    if (completeLevelsLetters.contains(currentLetter)) {
      final completedLevel = ForestProgressService.levelNumberForLetter(
        currentLetter,
      );

      if (completedLevel != null) {
        ForestProgressService.instance.markLevelComplete(completedLevel);
      }
    }

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

            if (currentLetter == 'C') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ForestMailDeliveryGame(level: 2),
                ),
              );
            } else if (currentLetter == 'F') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcornBasketGame(level: 4),
                ),
              );
            } else if (currentLetter == 'I') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ButterflyFlowerGardenGame(level: 6),
                ),
              );
            } else if (currentLetter == 'L') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ButterflyLetterMatchGame(level: 8),
                ),
              );
            } else if (currentLetter == 'O') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const MushroomHideAndSeekGame(level: 10),
                ),
              );
            } else if (currentLetter == 'R') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BerryBushHarvestGame(level: 12),
                ),
              );
            } else if (currentLetter == 'U') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowThePawPrintsGame(level: 14),
                ),
              );
            } else if (currentLetter == 'X') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const FallenStickLetterBuilderGame(level: 16),
                ),
              );
            } else if (currentLetter == 'Z') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const YakZebraRaceGame(level: 18),
                ),
              );
            } else {
              int charCode = currentLetter.codeUnitAt(0);
              if (charCode >= 65 && charCode < 90) {
                String nextLetter = String.fromCharCode(charCode + 1);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetIntroScreen(letter: nextLetter),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForestLevelScreen(),
                  ),
                );
              }
            }
          },

          onRestart: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AlphabetPopScreen(letter: widget.letter),
              ),
            );
          },

          onBack: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ForestLevelScreen(),
              ),
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
                    level:
                        ForestProgressService.levelNumberForLetter(
                          widget.letter.toUpperCase(),
                        ) ??
                        1,
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

            if (showHowToPlay &&
                _inputEnabled &&
                !_hasSavedResult &&
                _firstTargetBall() != null)
              Positioned.fill(
                child: HowToPlayOverlay(
                  previewChild: _buildHowToPreview(
                    screenSize,
                    ballSize,
                    letterFontSize,
                  ),
                  handAlignment: _handAlignmentForBall(screenSize, ballSize),
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

  BouncingBall? _firstTargetBall() {
    final String target = widget.letter.toUpperCase();
    for (final b in _activeBalls) {
      if (!b.isPopped && b.letter == target) return b;
    }
    return null;
  }

  Alignment _handAlignmentForBall(Size s, double ballSize) {
    final BouncingBall? ball = _firstTargetBall();
    if (ball == null) return Alignment.center;

    final double areaW = s.width - 40;
    final double areaH = s.height * 0.70 - 20;

    final double cx = 20 + ball.xPos * (areaW - ballSize) + ballSize / 2;
    final double cy =
        s.height * 0.30 + ball.yPos * (areaH - ballSize) + ballSize / 2;

    return Alignment((2 * cx / s.width) - 1, (2 * cy / s.height) - 1);
  }

  Widget _buildHowToPreview(
    Size screenSize,
    double ballSize,
    double letterFontSize,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/bg_game_forest.png',
          fit: BoxFit.cover,
        ),
        Positioned(
          top: screenSize.height * 0.30,
          bottom: 20,
          left: 20,
          right: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: _activeBalls.where((b) => !b.isPopped).map((ball) {
                  return Positioned(
                    left: ball.xPos * (constraints.maxWidth - ballSize),
                    top: ball.yPos * (constraints.maxHeight - ballSize),
                    child: SizedBox(
                      width: ballSize,
                      height: ballSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/objects/forest/ball.png',
                            fit: BoxFit.contain,
                          ),
                          Text(
                            ball.letter,
                            textScaler: const TextScaler.linear(1.0),
                            style: TextStyle(
                              fontFamily: ForestAppTextStyles.fredoka,
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
