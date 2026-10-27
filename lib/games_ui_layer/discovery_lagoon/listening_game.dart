import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/catching_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'kiki_reaction.dart';
import 'lagoon_game_ui.dart';

enum GamePhase {
  intro,
  listening,
  choosing,
  answered,
  completed,
  bodyParts,
  goodJob,
  bodyPartsAnswered,
}

class ListeningGame extends StatefulWidget {
  final int level;

  const ListeningGame({super.key, required this.level});

  @override
  State<ListeningGame> createState() => _ListeningGameState();
}

class _ListeningGameState extends State<ListeningGame>
    with AiCameraMixin, AppAudioLifecycleMixin<ListeningGame>, KikiReactionMixin, IdleHintMixin  {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _kikiPlayer= AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _kikiPlayer];

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  GamePhase _currentPhase = GamePhase.intro;

  String _targetAnimal = 'chicken';

  final List<Map<String, String>> _allAnimals = [
    {'id': 'chicken', 'image': 'assets/images/objects/lagoon/chicken.png'},
    {'id': 'frog', 'image': 'assets/images/objects/lagoon/frog.png'},
    {'id': 'snake', 'image': 'assets/images/objects/lagoon/snake.png'},
    {'id': 'pig', 'image': 'assets/images/objects/lagoon/pig.png'},
    {'id': 'cow', 'image': 'assets/images/objects/lagoon/cow.png'},
    {
      'id': 'penguin',
      'image': 'assets/images/characters/doma_the_penguin2.png',
    },
    {'id': 'dog', 'image': 'assets/images/characters/tofi_smiling.png'},
  ];

  List<Map<String, String>> _currentChoices = [];
  List<Map<String, String>> _hintAnimals = [];

  final List<Map<String, String>> _bodyParts = [
    {'id': 'ear', 'image': 'assets/images/objects/lagoon/ear.png'},
    {'id': 'hand', 'image': 'assets/images/objects/lagoon/pointing_hand.png'},
    {'id': 'nose', 'image': 'assets/images/objects/lagoon/nose.png'},
  ];

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _playIntroAudio();
  }

  void _generateChoices() {
    final targetObj = _allAnimals.firstWhere((a) => a['id'] == _targetAnimal);
    final wrongChoices = _allAnimals
        .where((a) => a['id'] != _targetAnimal)
        .toList();
    wrongChoices.shuffle(Random());

    final selected = [targetObj, wrongChoices[0], wrongChoices[1]];
    selected.shuffle(Random());

    setState(() {
      _currentChoices = selected;
    });
  }

  Future<void> _playIntroAudio() async {
    await playVoiceRestartingOnFaceLoss(
        _audioPlayer, 'audio/discovery_lagoon/listening_intro.wav');
    if (!mounted) return;
    await _startListeningPhase();
  }

  Future<void> _startListeningPhase() async {
    _generateChoices();
    _hintAnimals = (_allAnimals.where((a) => a['id'] != _targetAnimal).toList()
      ..shuffle(Random()))
        .take(3)
        .toList();
    setState(() => _currentPhase = GamePhase.choosing);
    showHowToPlay = false;
    startIdleTimer();

    setState(() => _currentPhase = GamePhase.listening);

    await playVoiceRestartingOnFaceLoss(
        _audioPlayer, 'audio/discovery_lagoon/listening_$_targetAnimal.wav');
    if (!mounted) return;

    await playVoiceRestartingOnFaceLoss(
        _audioPlayer, 'audio/discovery_lagoon/listening_whatanimal.wav');
    if (!mounted) return;

    setState(() => _currentPhase = GamePhase.choosing);
    showHowToPlay = false;
    startIdleTimer();
  }

  Future<void> _onAnimalTapped(String animalName) async {
    if (_currentPhase != GamePhase.choosing) return;

    if (animalName == _targetAnimal) {
      cancelIdleTimer();
      _tapTracker.recordCorrectTap();
      setState(() => _currentPhase = GamePhase.answered);
      showKikiReaction(KikiState.correct);

      await playVoiceRestartingOnFaceLoss(
          _audioPlayer, 'audio/discovery_lagoon/listening_rc.wav');
      if (!mounted) return;

      const order = ['chicken', 'frog', 'snake', 'pig', 'cow'];
      final i = order.indexOf(_targetAnimal);

      if (i < order.length - 1) {
        setState(() => _targetAnimal = order[i + 1]);
        await _startListeningPhase();
      } else {
        setState(() => _currentPhase = GamePhase.completed);
        await playVoiceRestartingOnFaceLoss(
            _audioPlayer, 'audio/discovery_lagoon/listening_ending1.wav');
        if (!mounted) return;

        setState(() => _currentPhase = GamePhase.bodyParts);
        await playVoiceRestartingOnFaceLoss(
            _audioPlayer, 'audio/discovery_lagoon/listening_whatpart.wav');
        if (!mounted) return; 
        showHowToPlay = false; 
        startIdleTimer();
      }
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      if (kikiState != KikiState.wrong) showKikiReaction(KikiState.wrong);
      startIdleTimer();
    }
  }

  Future<void> _onBodyPartTapped(String partId) async {
    if (_currentPhase != GamePhase.bodyParts) return;

    if (partId == 'ear') {
      cancelIdleTimer();
      _tapTracker.recordCorrectTap();
      setState(() => _currentPhase = GamePhase.bodyPartsAnswered);
      showKikiReaction(KikiState.correct);

      await playVoiceRestartingOnFaceLoss(
          _audioPlayer, 'audio/discovery_lagoon/listening_whatpart_rc.wav');
      if (!mounted) return;
      await _saveDataAndShowGoodJob();
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      if (kikiState != KikiState.wrong) showKikiReaction(KikiState.wrong);
      startIdleTimer();
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    LagoonDatabaseService.saveGameData(
      gameId: 'lagoon_listening_game',
      activityName: 'Listening Game',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    LagoonProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
    });
    if (mounted) {
      setState(() {
        _currentPhase = GamePhase.goodJob;
      });
    }
  }

  void _restartGame() {
    setState(() {
      _targetAnimal = 'chicken';
      _currentPhase = GamePhase.intro;
      _hasSavedResult = false;
      _tapTracker.startSession();
    });
    _playIntroAudio();
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    _kikiPlayer.dispose();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sh = MediaQuery.of(context).size.height;
    final double catHeight = sh * 1.0;
    final double catBottom = sh * -0.25;

    return Listener(
        onPointerDown: (_) {
          if (_currentPhase == GamePhase.choosing ||
              _currentPhase == GamePhase.bodyParts) {
            resetIdleTimer();
          }
        },
        child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_lagoon.png',
            fit: BoxFit.cover,
          ),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          if (_currentPhase == GamePhase.intro ||
              _currentPhase == GamePhase.completed)
            Positioned(
              bottom: catBottom,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/characters/kiki_the_cat.png',
                  height: catHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          if (_currentPhase == GamePhase.listening)
            Center(
              child: Image.asset(
                'assets/images/objects/lagoon/speaker.gif',
                height: sh * 0.60,
                fit: BoxFit.contain,
              ),
            ),

          if (_currentPhase == GamePhase.choosing ||
              _currentPhase == GamePhase.answered)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _currentChoices.map((animal) {
                    return _buildAnimalChoice(
                      animal['image']!,
                      animal['id']!,
                      sh,
                    );
                  }).toList(),
                ),
              ),
            ),

          if (_currentPhase == GamePhase.bodyParts) ...[
            Positioned(
              bottom: sh * -0.35,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/characters/cat_holding_fishbone.png',
                  height: sh * 0.95,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: sh * 0.05,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _bodyParts.map((part) {
                      return _buildBodyPartCard(
                        part['image']!,
                        part['id']!,
                        sh,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],

          if (showHowToPlay &&
              (_currentPhase == GamePhase.choosing ||
                  _currentPhase == GamePhase.bodyParts))
            Positioned.fill(child: _buildHowToPlayOverlay()),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (_currentPhase == GamePhase.goodJob)
            GoodJobOverlay(
              characterImage:
                  'assets/images/characters/cat_holding_fishbone.png',
              characterSizeFactor: 0.9,
              onNext: () {
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          CatchingGameScreen(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: _restartGame,
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
        ),
    );
  }

  Widget _sampleCard(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
      ],
    ),
  );

  Widget _buildHowToPlayOverlay() {
    final sz = MediaQuery.of(context).size;
    final sh = sz.height;

    final bg = Positioned.fill(
      child: Image.asset('assets/images/backgrounds/bg_rainbow_lagoon.png', fit: BoxFit.cover),
    );

    // ── Body parts: 3 cards on top, cat holding fishbone below ──
    if (_currentPhase == GamePhase.bodyParts) {
      final card = sh * 0.35;
      return HowToPlayOverlay(
        previewChild: Stack(children: [
          bg,
          Positioned(
            bottom: sh * -0.35,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/characters/cat_holding_fishbone.png',
                height: sh * 0.95,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: sh * 0.05,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: _sampleCard(card),
                  ),
              ],
            ),
          ),
        ]),
        handAlignment: Alignment(0, 2 * (sh * 0.05 + card / 2) / sh - 1), 
        handOffset: const Offset(0.05, 0.46),
        onDismiss: resetIdleTimer,
      );
    }

    return HowToPlayOverlay(
      previewChild: Stack(children: [
        bg,
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _hintAnimals
                  .map(
                    (a) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Image.asset(
                      a['image']!,
                      height: sh * 0.55,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
                  .toList(),
            ),
          ),
        ),
      ]),
      handAlignment: Alignment.center,
      handOffset: const Offset(0.05, 0.46),
      onDismiss: resetIdleTimer,
    );
  }

  Widget _buildAnimalChoice(
    String imagePath,
    String animalId,
    double screenHeight,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onAnimalTapped(animalId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Image.asset(
            imagePath,
            height: screenHeight * 0.55,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyPartCard(
    String imagePath,
    String partId,
    double screenHeight,
  ) {
    final double cardSize = screenHeight * 0.35;

    return GestureDetector(
      onTap: () => _onBodyPartTapped(partId),
      child: Container(
        width: cardSize,
        height: cardSize,
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
