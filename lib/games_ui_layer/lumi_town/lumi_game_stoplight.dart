import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../business_layer/town_progress_service.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/lumi_town/lumi_buttons.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import 'lumi_game_diary.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';
import 'lumi_game_ui_layer.dart';

// ============================================================================
// ASSET PATHS — replace if your exact filenames/folders differ
// ============================================================================

const String _roadBg = 'assets/images/backgrounds/bg_road.png';
const String _stoplight = 'assets/images/objects/lumi/stoplight.png';
const String _park = 'assets/images/backgrounds/bg_park_sunny.png';
const String _imageTrWoo = 'assets/images/characters/tr.woo_standing.png';
const String _domaExercise = 'assets/animations/characters/doma_flying.webp';

const String _audioBase = 'assets/audio/lumi_town/';
const String _introAudio = '${_audioBase}stoplight_intro.wav';
const String _instructionAudio = '${_audioBase}stoplight_instruction.wav';
const String _completeAudio = '${_audioBase}stoplight_complete.wav';

const String _sleepingScene = 'assets/animations/sleeping.webp';
const String _bikingScene = 'assets/images/objects/lumi/biking_scene.png';
const String _snacksScene = 'assets/images/objects/lumi/snacks_scene.png';
const String _watchingTvScene = 'assets/images/objects/lumi/watching_tv_scene.png';
const String _gamingScene = 'assets/images/objects/lumi/gaming_scene.png';

// ============================================================================
// MODEL
// ============================================================================

enum StoplightAnswer { green, yellow, red }

enum StoplightPhase { intro, instruction, game, complete }

class StoplightScenario {
  final String id;
  final String audio;
  final StoplightAnswer correctAnswer;
  final String? imageAsset;
  final bool isComposite;

  const StoplightScenario({
    required this.id,
    required this.audio,
    required this.correctAnswer,
    this.imageAsset,
    this.isComposite = false,
  });
}

final List<StoplightScenario> _scenarios = [
  const StoplightScenario(
    id: 'sleeping',
    audio: '${_audioBase}stoplight_sleeping.wav',
    correctAnswer: StoplightAnswer.green,
    imageAsset: _sleepingScene,
  ),
  const StoplightScenario(
    id: 'biking',
    audio: '${_audioBase}stoplight_biking.wav',
    correctAnswer: StoplightAnswer.green,
    imageAsset: _bikingScene,
  ),
  const StoplightScenario(
    id: 'snacks',
    audio: '${_audioBase}stoplight_snacks.wav',
    correctAnswer: StoplightAnswer.red,
    imageAsset: _snacksScene,
  ),
  const StoplightScenario(
    id: 'watching_tv',
    audio: '${_audioBase}stoplight_watching_tv.wav',
    correctAnswer: StoplightAnswer.yellow,
    imageAsset: _watchingTvScene,
  ),
  const StoplightScenario(
    id: 'exercise',
    audio: '${_audioBase}stoplight_exercise.wav',
    correctAnswer: StoplightAnswer.green,
    isComposite: true,
  ),
  const StoplightScenario(
    id: 'gaming',
    audio: '${_audioBase}stoplight_gaming.wav',
    correctAnswer: StoplightAnswer.red,
    imageAsset: _gamingScene,
  ),
];

// ============================================================================
// SCREEN
// ============================================================================

class StoplightGameScreen extends StatefulWidget {
  final int level;

  const StoplightGameScreen({super.key, required this.level});

  @override
  State<StoplightGameScreen> createState() => _StoplightGameScreenState();
}

class _StoplightGameScreenState extends State<StoplightGameScreen>
    with
        TrWooReactionMixin<StoplightGameScreen>,
        AiCameraMixin<StoplightGameScreen>,
        AppAudioLifecycleMixin<StoplightGameScreen> {
  final DateTime _loadStart = DateTime.now();

  // --- Audio ----------------------------------------------------------

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _trWooPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [
    _audioPlayer,
    _trWooPlayer,
  ];

  @override
  AudioPlayer get trWooPlayer => _trWooPlayer;

  // --- Game state -------------------------------------------------------
  int _currentRound = 0;
  StoplightAnswer? _selectedAnswer;
  StoplightAnswer? _instructionFlash;
  bool _buttonsEnabled = false;
  bool _checkingAnswer = false;
  StoplightPhase _phase = StoplightPhase.intro;
  bool _isLoading = true;
  bool _gameComplete = false;

  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  StoplightScenario get _scenario => _scenarios[_currentRound];

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

    _initializeGame();
  }

  Future<void> _initializeGame() async {
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    if (_isLoading) {
      final elapsed = DateTime.now().difference(_loadStart);
      final remaining = const Duration(milliseconds: 1500) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      if (!mounted) return;
    }

    setState(() {
      _isLoading = false;
    });

    await _startIntroFlow();
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    _trWooPlayer.dispose();
    super.dispose();
  }

  Future<void> _startIntroFlow() async {
    if (!mounted) return;

    setState(() {
      _phase = StoplightPhase.intro;
      _buttonsEnabled = false;
    });

    await playAssetAudio(_audioPlayer, _introAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() {
      _phase = StoplightPhase.instruction;
      _selectedAnswer = null;
      _instructionFlash = null;
      _buttonsEnabled = false;
    });

    unawaited(_runInstructionFlashes());

    await playAssetAudio(_audioPlayer, _instructionAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() {
      _phase = StoplightPhase.game;
    });

    await _startRound(0);
  }

  Future<void> _runInstructionFlashes() async {
    // 4 sec → GREEN
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted || _phase != StoplightPhase.instruction) return;

    setState(() {
      _instructionFlash = StoplightAnswer.green;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _phase != StoplightPhase.instruction) return;

    setState(() {
      _instructionFlash = null;
    });

    // 7 sec → YELLOW
    await Future.delayed(const Duration(milliseconds: 2300));
    if (!mounted || _phase != StoplightPhase.instruction) return;

    setState(() {
      _instructionFlash = StoplightAnswer.yellow;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _phase != StoplightPhase.instruction) return;

    setState(() {
      _instructionFlash = null;
    });

    // 9 sec → RED
    await Future.delayed(const Duration(milliseconds: 2300));
    if (!mounted || _phase != StoplightPhase.instruction) return;

    setState(() {
      _instructionFlash = StoplightAnswer.red;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _phase != StoplightPhase.instruction) return;

    setState(() {
      _instructionFlash = null;
    });
  }

  Future<void> _startRound(int index) async {
    if (!mounted) return;
    setState(() {
      _currentRound = index;
      _selectedAnswer = null;
      _buttonsEnabled = false;
      _checkingAnswer = false;
    });

    await playAssetAudio(_audioPlayer, _scenario.audio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() => _buttonsEnabled = true);
  }

  Future<void> _onLightTapped(StoplightAnswer answer) async {
    if (!_buttonsEnabled || _checkingAnswer || !mounted) return;

    setState(() {
      _selectedAnswer = answer;
      _buttonsEnabled = false;
      _checkingAnswer = true;
    });

    final bool isCorrect = answer == _scenario.correctAnswer;

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (isCorrect) {
      _tapTracker.recordCorrectTap();
      unawaited(_trWooPlayer.stop());
      showTrWooReaction(TrWooState.correct);

      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;

      _checkingAnswer = false;
      await _advanceRound();
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTrWooReaction(TrWooState.wrong);

      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;

      setState(() {
        _selectedAnswer = null;
        _buttonsEnabled = true;
        _checkingAnswer = false;
      });
    }
  }

  Future<void> _advanceRound() async {
    final int next = _currentRound + 1;
    if (next >= _scenarios.length) {
      await _completeGame();
    } else {
      await _startRound(next);
    }
  }

  Future<void> _completeGame() async {
    if (!mounted) return;

    setState(() {
      _buttonsEnabled = false;
      _checkingAnswer = true;
      _phase = StoplightPhase.complete;
    });

    if (!_hasSavedResult) {
      _hasSavedResult = true;
      List<String> finalEmotions = stopAiCamera();

      TownDatabaseService.saveGameData(
        gameId: 'lumi_town_stoplight',
        activityName: 'Stoplight Game',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      ).catchError((e) {
        debugPrint("Database Error saving metrics: $e");
      });
    }

    TownProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
    });

    if (!mounted) return;

    await playAssetAudio(_audioPlayer, _completeAudio);
    await waitForAudio(_audioPlayer);

    if (!mounted) return;

    setState(() {
      _gameComplete = true;
      _checkingAnswer = false;
    });
  }

  Future<void> _restartGame() async {
    if (!mounted) return;

    setState(() {
      _currentRound = 0;
      _selectedAnswer = null;
      _instructionFlash = null;
      _buttonsEnabled = false;
      _checkingAnswer = false;
      _gameComplete = false;
      _phase = StoplightPhase.game;
      _hasSavedResult = false;
      _tapTracker.startSession();
    });

    await _startRound(0);
  }

  Future<void> _goBack() async {
    await _audioPlayer.stop();
    await _trWooPlayer.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: LoadingScreen.lumiTown());
    }

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: Image.asset(_roadBg, fit: BoxFit.cover)),

            Offstage(child: Image.asset(_sleepingScene, width: 1, height: 1)),

            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final stoplightWidth = width * 0.21;
                final scenarioWidth = width * 0.48;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: width * 0.15,
                      bottom: -80,
                      child: SizedBox(
                        width: stoplightWidth,
                        child: _StoplightWidget(
                          imagePath: _stoplight,
                          enabled: _buttonsEnabled && !_checkingAnswer,
                          selectedAnswer: _phase == StoplightPhase.complete
                              ? null
                              : _phase == StoplightPhase.instruction
                              ? _instructionFlash
                              : _selectedAnswer,
                          onTap: _onLightTapped,
                        ),
                      ),
                    ),

                    if (_phase == StoplightPhase.intro ||
                        _phase == StoplightPhase.complete)
                      Positioned(
                        right: width * 0.05,
                        bottom: -50,
                        child: SizedBox(
                          height: height * 1.2,
                          child: Image.asset(_imageTrWoo, fit: BoxFit.contain),
                        ),
                      ),

                    if (_phase == StoplightPhase.instruction ||
                        _phase == StoplightPhase.game)
                      Positioned(
                        right: width * 0.08,
                        top: height * 0.20,
                        child: SizedBox(
                          width: scenarioWidth,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _ScenarioCard(
                              scenario: _scenario,
                              selectedAnswer: _selectedAnswer,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LumiLevelBadge(level: widget.level),
            ),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_gameComplete)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/tr.woo_the_owl.png',
                onNext: () async {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => DiaryGameScreen(level: widget.level + 1),
                    ),
                  );
                },
                onRestart: _restartGame,
                onBack: _goBack,
              ),
          ],
        ),
      ),
    );
  }
}

class _StoplightWidget extends StatelessWidget {
  final String imagePath;
  final bool enabled;
  final StoplightAnswer? selectedAnswer;
  final ValueChanged<StoplightAnswer> onTap;

  const _StoplightWidget({
    required this.imagePath,
    required this.enabled,
    required this.selectedAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AspectRatio(
          aspectRatio: 0.45,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(imagePath, fit: BoxFit.contain),
              ),
              _lightHitArea(
                topFraction: 0.03,
                heightFraction: 0.15,
                answer: StoplightAnswer.red,
                color: Colors.red,
              ),
              _lightHitArea(
                topFraction: 0.20,
                heightFraction: 0.15,
                answer: StoplightAnswer.yellow,
                color: Colors.amber,
              ),
              _lightHitArea(
                topFraction: 0.37,
                heightFraction: 0.15,
                answer: StoplightAnswer.green,
                color: Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _lightHitArea({
    required double topFraction,
    required double heightFraction,
    required StoplightAnswer answer,
    required Color color,
  }) {
    final bool isSelected = selectedAnswer == answer;

    return FractionallySizedBox(
      alignment: Alignment.topCenter,
      heightFactor: 1.0,
      child: Align(
        alignment: Alignment(0, -1 + 2 * (topFraction + heightFraction / 2)),
        child: FractionallySizedBox(
          heightFactor: heightFraction,
          widthFactor: 0.62,
          child: GestureDetector(
            onTap: enabled ? () => onTap(answer) : null,
            child: AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.85),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final StoplightScenario scenario;
  final StoplightAnswer? selectedAnswer;

  const _ScenarioCard({required this.scenario, required this.selectedAnswer});

  Color _borderColor() {
    if (selectedAnswer == null) return Colors.grey;
    switch (selectedAnswer!) {
      case StoplightAnswer.green:
        return Colors.green;
      case StoplightAnswer.yellow:
        return Colors.amber;
      case StoplightAnswer.red:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _borderColor(), width: 8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: scenario.isComposite
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(_park, fit: BoxFit.cover),
                  Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      heightFactor: 0.75,
                      child: Image.asset(_domaExercise, fit: BoxFit.contain),
                    ),
                  ),
                ],
              )
            : Image.asset(
                scenario.imageAsset!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSyncLoaded) {
                  if (wasSyncLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: child,
                  );
                },
              ),
      ),
    );
  }
}
