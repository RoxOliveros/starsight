import 'dart:async';
import 'dart:math';
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
import 'lumi_game_cleaning.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';

import 'lumi_game_ui_layer.dart';

const String _classroomBg = 'assets/images/backgrounds/bg_lumi_classroom.png';
const String _gameBg = 'assets/images/backgrounds/bg_table.png';
const String _teacherWooImage = 'assets/images/characters/tr.woo_the_owl.png';

const String _audioBase = 'assets/audio/lumi_town/';
const String _introAudio = '${_audioBase}behavior_intro.wav';
const String _instructionAudio = '${_audioBase}behavior_instruction.wav';
const String _winAudio = '${_audioBase}behavior_win.wav';

const String _redButton = 'assets/images/buttons/red_button.png';
const String _redButtonClicked = 'assets/images/buttons/red_clicked.png';
const String _greenButton = 'assets/images/buttons/green_button.png';
const String _greenButtonClicked = 'assets/images/buttons/green_clicked.png';

const String _sceneImageBase = 'assets/images/objects/lumi/';

// ============================================================================
// MODEL
// ============================================================================

enum BehaviorSequencePhase { intro, instruction, game, complete }

class BehaviorSceneModel {
  final String id;
  final String imageAsset;
  final String narrationAudio;
  final String correctFeedbackAudio;
  final bool expectedGreen;

  const BehaviorSceneModel({
    required this.id,
    required this.imageAsset,
    required this.narrationAudio,
    required this.correctFeedbackAudio,
    required this.expectedGreen,
  });
}

const List<BehaviorSceneModel> _behaviors = [
  BehaviorSceneModel(
    id: 'giving',
    imageAsset: '${_sceneImageBase}behavior_giving.png',
    narrationAudio: '${_audioBase}behavior_round_giving.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_giving.wav',
    expectedGreen: true,
  ),
  BehaviorSceneModel(
    id: 'fighting',
    imageAsset: '${_sceneImageBase}behavior_fighting.png',
    narrationAudio: '${_audioBase}behavior_round_fighting.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_fighting.wav',
    expectedGreen: false,
  ),
  BehaviorSceneModel(
    id: 'helping',
    imageAsset: '${_sceneImageBase}behavior_helping.png',
    narrationAudio: '${_audioBase}behavior_round_helping.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_helping.wav',
    expectedGreen: true,
  ),
  BehaviorSceneModel(
    id: 'littering',
    imageAsset: '${_sceneImageBase}behavior_littering.png',
    narrationAudio: '${_audioBase}behavior_round_littering.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_littering.wav',
    expectedGreen: false,
  ),
  BehaviorSceneModel(
    id: 'talking_in_class',
    imageAsset: '${_sceneImageBase}behavior_talking_in_class.png',
    narrationAudio: '${_audioBase}behavior_round_talking_in_class.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_talking_in_class.wav',
    expectedGreen: false,
  ),
  BehaviorSceneModel(
    id: 'cleaning_room',
    imageAsset: '${_sceneImageBase}behavior_cleaning_room.png',
    narrationAudio: '${_audioBase}behavior_round_cleaning_room.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_cleaning_room.wav',
    expectedGreen: true,
  ),
];

// ============================================================================
// SCREEN
// ============================================================================

class BehaviorGameScreen extends StatefulWidget {
  final int level;

  const BehaviorGameScreen({super.key, required this.level});

  @override
  State<BehaviorGameScreen> createState() => _BehaviorGameScreenState();
}

class _BehaviorGameScreenState extends State<BehaviorGameScreen>
    with
        TrWooReactionMixin<BehaviorGameScreen>,
        AiCameraMixin<BehaviorGameScreen>,
        AppAudioLifecycleMixin<BehaviorGameScreen> {
  final DateTime _loadStart = DateTime.now();

  // --- Audio ----------------------------------------------------------
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _trWooPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _trWooPlayer];

  @override
  AudioPlayer get trWooPlayer => _trWooPlayer;

  // --- Game state -------------------------------------------------------
  late List<BehaviorSceneModel> _queue;
  int _currentIndex = 0;

  bool _inputEnabled = false;
  bool _checkingAnswer = false;
  String? _pressedButton;
  BehaviorSequencePhase _phase = BehaviorSequencePhase.intro;
  bool _isLoading = true;
  bool _gameComplete = false;

  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  BehaviorSceneModel get _current => _queue[_currentIndex];

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

    _queue = _shuffledBehaviors();
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

  List<BehaviorSceneModel> _shuffledBehaviors() {
    final rand = Random();
    final arr = List<BehaviorSceneModel>.of(_behaviors);
    for (int i = arr.length - 1; i > 0; i--) {
      final j = rand.nextInt(i + 1);
      final tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
    }
    return arr;
  }

  Future<void> _startIntroFlow() async {
    if (!mounted) return;

    setState(() {
      _phase = BehaviorSequencePhase.intro;
      _inputEnabled = false;
    });

    await playAssetAudio(_audioPlayer, _introAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() {
      _phase = BehaviorSequencePhase.instruction;
      _inputEnabled = false;
    });

    await playAssetAudio(_audioPlayer, _instructionAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() {
      _phase = BehaviorSequencePhase.game;
    });

    await _playCurrentNarration();
  }

  Future<void> _playCurrentNarration() async {
    setState(() => _inputEnabled = false);

    await playAssetAudio(_audioPlayer, _current.narrationAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() => _inputEnabled = true);
  }

  Future<void> _onAnswer(bool pickedGreen) async {
    if (!_inputEnabled || _checkingAnswer || !mounted) return;

    setState(() {
      _checkingAnswer = true;
      _inputEnabled = false;
      _pressedButton = pickedGreen ? 'green' : 'red';
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _pressedButton = null);

    final bool isCorrect = pickedGreen == _current.expectedGreen;

    if (isCorrect) {
      _tapTracker.recordCorrectTap();
      unawaited(_trWooPlayer.stop());
      await GamesSfxPlayer.instance.play(GameSfx.shine);
      if (!mounted) return;

      await playAssetAudio(_audioPlayer, _current.correctFeedbackAudio);
      await waitForAudio(_audioPlayer);

      if (!mounted) return;

      if (_currentIndex == _queue.length - 1) {
        await _completeGame();
      } else {
        setState(() {
          _currentIndex += 1;
          _checkingAnswer = false;
        });
        await _playCurrentNarration();
      }
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTrWooReaction(TrWooState.wrong);
      if (!mounted) return;

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      setState(() {
        _checkingAnswer = false;
        _inputEnabled = true;
      });
    }
  }

  Future<void> _completeGame() async {
    if (!mounted) return;

    setState(() {
      _phase = BehaviorSequencePhase.complete;
    });

    if (!_hasSavedResult) {
      _hasSavedResult = true;
      List<String> finalEmotions = stopAiCamera();

      TownDatabaseService.saveGameData(
        gameId: 'lumi_town_behavior',
        activityName: 'Good Behavior Game',
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

    await playAssetAudio(_audioPlayer, _winAudio);
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
      _queue = _shuffledBehaviors();
      _currentIndex = 0;
      _checkingAnswer = false;
      _pressedButton = null;
      _gameComplete = false;
      _phase = BehaviorSequencePhase.game;
      _inputEnabled = false;
      _hasSavedResult = false;
      _tapTracker.startSession();
    });

    await _playCurrentNarration();
  }

  Future<void> _goBack() async {
    _audioPlayer.dispose();
    _trWooPlayer.dispose();
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
            Positioned.fill(
              child: Image.asset(
                (_phase == BehaviorSequencePhase.intro ||
                        _phase == BehaviorSequencePhase.complete)
                    ? _classroomBg
                    : _gameBg,
                fit: BoxFit.cover,
              ),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_phase == BehaviorSequencePhase.intro)
                      Positioned(
                        right: 0,
                        left: 0,
                        bottom: -70,
                        child: SizedBox(
                          height: height * 1,
                          child: Image.asset(
                            _teacherWooImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                    if (_phase == BehaviorSequencePhase.game)
                      Positioned(
                        left: width * 0.08,
                        right: width * 0.08,
                        top: height * 0.08,
                        bottom: height * 0.10,
                        child: _BehaviorRound(
                          scene: _current,
                          inputEnabled: _inputEnabled && !_checkingAnswer,
                          pressedButton: _pressedButton,
                          onRed: () => _onAnswer(false),
                          onGreen: () => _onAnswer(true),
                        ),
                      ),

                    if (_phase == BehaviorSequencePhase.complete)
                      Positioned(
                        right: 0,
                        left: 0,
                        bottom: -70,
                        child: SizedBox(
                          height: height * 1,
                          child: Image.asset(
                            _teacherWooImage,
                            fit: BoxFit.contain,
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
                      builder: (_) =>
                          CleaningGameScreen(level: widget.level + 1),
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

class _BehaviorRound extends StatelessWidget {
  final BehaviorSceneModel scene;
  final bool inputEnabled;
  final String? pressedButton;
  final VoidCallback onRed;
  final VoidCallback onGreen;

  const _BehaviorRound({
    required this.scene,
    required this.inputEnabled,
    required this.pressedButton,
    required this.onRed,
    required this.onGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AnswerButton(
          normalAsset: _redButton,
          clickedAsset: _redButtonClicked,
          isPressed: pressedButton == 'red',
          enabled: inputEnabled,
          onTap: onRed,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFf5dbb6), width: 8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 15,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                scene.imageAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        _AnswerButton(
          normalAsset: _greenButton,
          clickedAsset: _greenButtonClicked,
          isPressed: pressedButton == 'green',
          enabled: inputEnabled,
          onTap: onGreen,
        ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String normalAsset;
  final String clickedAsset;
  final bool isPressed;
  final bool enabled;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.normalAsset,
    required this.clickedAsset,
    required this.isPressed,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Image.asset(
          isPressed ? clickedAsset : normalAsset,
          width: 100,
          height: 100,
        ),
      ),
    );
  }
}
