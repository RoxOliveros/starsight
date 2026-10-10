import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../business_layer/town_progress_service.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/lumi_town/lumi_buttons.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import 'lumi_game_behavior.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';

import 'lumi_game_ui_layer.dart';

// ============================================================================
// ASSET PATHS — replace if your exact filenames/folders differ
// ============================================================================

const String _roomBg = 'assets/images/backgrounds/bg_classroom_closeup.png';
const String _tableBg = 'assets/images/backgrounds/bg_table.png';
const String _bearWritingBookImage = 'assets/images/characters/bear_writing_book.png';

const String _audioBase = 'assets/audio/lumi_town/';
const String _introAudio = '${_audioBase}diary_intro.wav';
const String _instructionAudio = '${_audioBase}diary_instruction.wav';
const String _completeAudio = '${_audioBase}diary_win.wav';

const String _wakeScene = 'assets/images/objects/lumi/wake_scene.png';
const String _bathScene = 'assets/images/objects/lumi/bathroom_scene.png';
const String _eatScene = 'assets/images/objects/lumi/eat_scene.png';
const String _schoolScene = 'assets/images/objects/lumi/school_scene.png';

// ============================================================================
// MODEL
// ============================================================================

enum DailySequencePhase { intro, instruction, game, complete }

class DiarySceneCard {
  final String id;
  final int correctNumber;
  final String imageAsset;

  const DiarySceneCard({
    required this.id,
    required this.correctNumber,
    required this.imageAsset,
  });
}

const List<DiarySceneCard> _diaryScenes = [
  DiarySceneCard(id: 'wake', correctNumber: 1, imageAsset: _wakeScene),
  DiarySceneCard(id: 'bath', correctNumber: 2, imageAsset: _bathScene),
  DiarySceneCard(id: 'eat', correctNumber: 3, imageAsset: _eatScene),
  DiarySceneCard(id: 'school', correctNumber: 4, imageAsset: _schoolScene),
];

// ============================================================================
// SCREEN
// ============================================================================

class DiaryGameScreen extends StatefulWidget {
  final int level;

  const DiaryGameScreen({super.key, required this.level});

  @override
  State<DiaryGameScreen> createState() => _DiaryGameScreenState();
}

class _DiaryGameScreenState extends State<DiaryGameScreen>
    with
        TrWooReactionMixin<DiaryGameScreen>,
        AiCameraMixin<DiaryGameScreen>,
        AppAudioLifecycleMixin<DiaryGameScreen> {
  final DateTime _loadStart = DateTime.now();

  // --- Audio ----------------------------------------------------------
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _trWooPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _trWooPlayer];

  @override
  AudioPlayer get trWooPlayer => _trWooPlayer;

  // --- Game state -------------------------------------------------------
  late List<DiarySceneCard> _slotScenes;
  List<bool> _slotLocked = [false, false, false, false];

  bool _dragEnabled = false;
  bool _checkingAnswer = false;
  int? _wrongFlashSlot;
  DailySequencePhase _phase = DailySequencePhase.intro;
  bool _isLoading = true;
  bool _gameComplete = false;

  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

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

    _slotScenes = _shuffledScenes();
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

  List<DiarySceneCard> _shuffledScenes() {
    final rand = Random();
    List<DiarySceneCard> arr = List.of(_diaryScenes);
    bool anyCorrect;
    do {
      for (int i = arr.length - 1; i > 0; i--) {
        final j = rand.nextInt(i + 1);
        final tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;
      }
      anyCorrect = false;
      for (int i = 0; i < arr.length; i++) {
        if (arr[i].correctNumber == i + 1) {
          anyCorrect = true;
          break;
        }
      }
    } while (anyCorrect);
    return arr;
  }

  Future<void> _startIntroFlow() async {
    if (!mounted) return;

    setState(() {
      _phase = DailySequencePhase.intro;
      _dragEnabled = false;
    });

    await playAssetAudio(_audioPlayer, _introAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() {
      _phase = DailySequencePhase.instruction;
      _dragEnabled = false;
    });

    await playAssetAudio(_audioPlayer, _instructionAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() {
      _phase = DailySequencePhase.game;
      _dragEnabled = true;
    });
  }

  Future<void> _onDrop(int originIndex, int targetIndex) async {
    if (!_dragEnabled || _checkingAnswer || !mounted) return;
    if (originIndex == targetIndex || _slotLocked[targetIndex]) return;

    setState(() => _checkingAnswer = true);

    final draggedCard = _slotScenes[originIndex];
    final targetNumber = targetIndex + 1;
    final bool isCorrect = draggedCard.correctNumber == targetNumber;

    if (isCorrect) {
      _tapTracker.recordCorrectTap();
      final other = _slotScenes[targetIndex];
      setState(() {
        _slotScenes[targetIndex] = draggedCard;
        _slotScenes[originIndex] = other;
        _slotLocked[targetIndex] = true;
        if (other.correctNumber == originIndex + 1) {
          _slotLocked[originIndex] = true;
        }
      });
      unawaited(_trWooPlayer.stop());
      showTrWooReaction(TrWooState.correct);

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      setState(() => _checkingAnswer = false);

      if (_slotLocked.every((locked) => locked)) {
        await _completeGame();
      }
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTrWooReaction(TrWooState.wrong);
      setState(() => _wrongFlashSlot = targetIndex);

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      setState(() {
        _checkingAnswer = false;
        _wrongFlashSlot = null;
      });
    }
  }

  Future<void> _completeGame() async {
    if (!mounted) return;

    setState(() {
      _dragEnabled = false;
      _checkingAnswer = true;
      _phase = DailySequencePhase.complete;
    });

    if (!_hasSavedResult) {
      _hasSavedResult = true;
      List<String> finalEmotions = stopAiCamera();

      TownDatabaseService.saveGameData(
        gameId: 'lumi_town_diary',
        activityName: 'Daily Routine Diary',
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
      _slotScenes = _shuffledScenes();
      _slotLocked = [false, false, false, false];
      _wrongFlashSlot = null;
      _checkingAnswer = false;
      _gameComplete = false;
      _phase = DailySequencePhase.game;
      _dragEnabled = true;
      _hasSavedResult = false;
      _tapTracker.startSession();
    });
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
            Positioned.fill(
              child: Image.asset(
                (_phase == DailySequencePhase.game ||
                        _phase == DailySequencePhase.instruction ||
                        _phase == DailySequencePhase.complete)
                    ? _tableBg
                    : _roomBg,
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
                    if (_phase == DailySequencePhase.intro)
                      Positioned(
                        right: 0,
                        left: 0,
                        bottom: -110,
                        child: SizedBox(
                          height: height * 1.2,
                          child: Image.asset(
                            _bearWritingBookImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                    if (_phase == DailySequencePhase.instruction ||
                        _phase == DailySequencePhase.game ||
                        _phase == DailySequencePhase.complete)
                      Positioned(
                        left: width * 0.10,
                        right: width * 0.10,
                        top: height * 0.15,
                        bottom: height * 0.08,
                        child: _DiaryGrid(
                          slotScenes: _slotScenes,
                          slotLocked: _slotLocked,
                          dragEnabled: _dragEnabled && !_checkingAnswer,
                          wrongFlashSlot: _wrongFlashSlot,
                          onDrop: _onDrop,
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
                          BehaviorGameScreen(level: widget.level + 1),
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

class _DiaryGrid extends StatelessWidget {
  final List<DiarySceneCard> slotScenes;
  final List<bool> slotLocked;
  final bool dragEnabled;
  final int? wrongFlashSlot;
  final void Function(int originIndex, int targetIndex) onDrop;

  const _DiaryGrid({
    required this.slotScenes,
    required this.slotLocked,
    required this.dragEnabled,
    required this.wrongFlashSlot,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _slotAt(0)),
                  const SizedBox(width: 14),
                  Expanded(child: _slotAt(1)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _slotAt(2)),
                  const SizedBox(width: 14),
                  Expanded(child: _slotAt(3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotAt(int index) {
    return _DiarySlot(
      slotNumber: index + 1,
      scene: slotScenes[index],
      locked: slotLocked[index],
      dragEnabled: dragEnabled,
      wrongFlash: wrongFlashSlot == index,
      onAccept: (originIndex) => onDrop(originIndex, index),
      canAccept: (originIndex) =>
          dragEnabled && !slotLocked[index] && originIndex != index,
      slotIndex: index,
    );
  }
}

class _DiarySlot extends StatelessWidget {
  final int slotNumber;
  final int slotIndex;
  final DiarySceneCard scene;
  final bool locked;
  final bool dragEnabled;
  final bool wrongFlash;
  final bool Function(int originIndex) canAccept;
  final void Function(int originIndex) onAccept;

  const _DiarySlot({
    required this.slotNumber,
    required this.slotIndex,
    required this.scene,
    required this.locked,
    required this.dragEnabled,
    required this.wrongFlash,
    required this.canAccept,
    required this.onAccept,
  });

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    final Widget image = locked
        ? Image.asset(scene.imageAsset, fit: BoxFit.cover)
        : ColorFiltered(
            colorFilter: _greyscale,
            child: Image.asset(scene.imageAsset, fit: BoxFit.cover),
          );

    final Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(fit: StackFit.expand, children: [image]),
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => canAccept(details.data),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final bool hovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: wrongFlash
                  ? Colors.redAccent
                  : locked
                  ? Colors.amber
                  : hovering
                  ? Colors.greenAccent
                  : Colors.brown.shade200,
              width: locked ? 4 : 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              (!locked && dragEnabled)
                  ? Draggable<int>(
                      data: slotIndex,
                      feedback: SizedBox(
                        width: 140,
                        height: 120,
                        child: Material(
                          color: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: card,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: card),
                      child: card,
                    )
                  : card,

              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: locked ? Colors.amber : LumiColorTheme.rust,
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 3),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: locked
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '$slotNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
