import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/bodyparts_assembly.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'kiki_reaction.dart';
import 'lagoon_game_ui.dart';

class SeedGame extends StatefulWidget {
  final int level;

  const SeedGame({super.key, required this.level});

  @override
  State<SeedGame> createState() => _SeedGameState();
}

class _SeedGameState extends State<SeedGame>
    with AiCameraMixin, AppAudioLifecycleMixin<SeedGame>, KikiReactionMixin, IdleHintMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _kikiPlayer= AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _kikiPlayer];

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  final GameTapTracker _tapTracker = GameTapTracker();
  final double kikiVerticalOffset = 40.0;
  late List<String> currentSequence;
  final List<GlobalKey> _slotKeys = List.generate(4, (_) => GlobalKey());

  bool showIntro = true;
  bool showGoodJob = false;
  bool _disposed = false;
  bool _isProcessingRound = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool isCorrect = false;

  int currentLevelIndex = 0;

  final List<String> roundAudio = [
    'audio/discovery_lagoon/seed_game_flower_round.wav',
    'audio/discovery_lagoon/seed_game_strawberry_round.wav',
    'audio/discovery_lagoon/seed_game_mango_round.wav',
  ];

  static const String _thankYouAudio = 'audio/discovery_lagoon/seed_game_thankyou.wav';
  static const String _introAudio = 'audio/discovery_lagoon/seed_game_intro.wav';

  final List<List<String>> allCorrectSequences = [
    [
      'assets/images/objects/lagoon/f1.png',
      'assets/images/objects/lagoon/f2.png',
      'assets/images/objects/lagoon/f3.png',
      'assets/images/objects/lagoon/f4.png',
    ],
    [
      'assets/images/objects/lagoon/s1.png',
      'assets/images/objects/lagoon/s2.png',
      'assets/images/objects/lagoon/s3.png',
      'assets/images/objects/lagoon/s4.png',
    ],
    [
      'assets/images/objects/lagoon/m1.png',
      'assets/images/objects/lagoon/m2.png',
      'assets/images/objects/lagoon/m3.png',
      'assets/images/objects/lagoon/m4.png',
    ],
  ];

  final List<List<String>> allInitialSequences = [
    [
      'assets/images/objects/lagoon/f2.png',
      'assets/images/objects/lagoon/f4.png',
      'assets/images/objects/lagoon/f1.png',
      'assets/images/objects/lagoon/f3.png',
    ],
    [
      'assets/images/objects/lagoon/s3.png',
      'assets/images/objects/lagoon/s1.png',
      'assets/images/objects/lagoon/s4.png',
      'assets/images/objects/lagoon/s2.png',
    ],
    [
      'assets/images/objects/lagoon/m2.png',
      'assets/images/objects/lagoon/m4.png',
      'assets/images/objects/lagoon/m1.png',
      'assets/images/objects/lagoon/m3.png',
    ],
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

    currentSequence = List.from(allInitialSequences[currentLevelIndex]);
    _playIntro();
  }

  Future<void> _playIntro() async {
    if (_disposed) return;

    await playVoiceRestartingOnFaceLoss(_audioPlayer, _introAudio);

    if (!mounted || _disposed) return;

    setState(() {
      showIntro = false;
      _isProcessingRound = true;
    });

    await playVoiceRestartingOnFaceLoss(_audioPlayer, roundAudio[currentLevelIndex]);

    if (!mounted || _disposed) return;

    setState(() {
      _isProcessingRound = false;
    });
    startIdleTimer();
  }

  @override
  void dispose() {
    _disposed = true;
    disposeAiCamera();
    disposeIdleTimer();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _onItemDropped(int oldIndex, int newIndex) {
    if (isCorrect || showGoodJob || _isProcessingRound) return;

    GamesSfxPlayer.instance.play(GameSfx.bubbleClick);

    setState(() {
      final temp = currentSequence[oldIndex];
      currentSequence[oldIndex] = currentSequence[newIndex];
      currentSequence[newIndex] = temp;
    });

    _checkWinCondition();
  }

  Future<void> _checkWinCondition() async {
    if (_isProcessingRound || isCorrect || showGoodJob) return;

    bool win = true;

    for (int i = 0; i < allCorrectSequences[currentLevelIndex].length; i++) {
      if (currentSequence[i] != allCorrectSequences[currentLevelIndex][i]) {
        win = false;
        break;
      }
    }

    if (!win) {
      _tapTracker.recordMistake();
      return;
    }

    _tapTracker.recordCorrectTap();

    setState(() {
      isCorrect = true;
      _isProcessingRound = true;
    });

    showKikiReaction(KikiState.correct);
    if (!mounted || _disposed) return;

    await Future.delayed(Duration(milliseconds: 1500));
    if (!mounted || _disposed) return;

    if (currentLevelIndex < allCorrectSequences.length - 1) {
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted || _disposed) return;

      setState(() {
        currentLevelIndex++;
        currentSequence = List.from(allInitialSequences[currentLevelIndex]);
        isCorrect = false;
      });

      await playVoiceRestartingOnFaceLoss(_audioPlayer, roundAudio[currentLevelIndex]);

      if (!mounted || _disposed) return;

      setState(() {
        _isProcessingRound = false;
      });
      startIdleTimer();
    } else {
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted || _disposed) return;

      await playVoiceRestartingOnFaceLoss(_audioPlayer, _thankYouAudio);

      if (!mounted || _disposed) return;

      await _saveDataAndShowGoodJob();
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;

    _hasSavedResult = true;
    cancelIdleTimer();

    List<String> finalEmotions = stopAiCamera();

    LagoonDatabaseService.saveGameData(
      gameId: 'lagoon_seed_game',
      activityName: 'Seed Game',
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
        _isProcessingRound = false;
        showGoodJob = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
        onPointerDown: (_) {
          _tapTracker.recordGenericTap();
          if (!showIntro && !_isProcessingRound && !isCorrect && !showGoodJob) {
            resetIdleTimer();
          }
        },
        child: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_rainbow_closeup2.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          if (showIntro)
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, kikiVerticalOffset),
                child: FractionallySizedBox(
                  heightFactor: 0.9,
                  child: Image.asset(
                    'assets/images/characters/kiki_gardener.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          else
            SafeArea(
              child: LayoutBuilder(
                  builder: (context, constraints) => _buildCardsRow(constraints),
              ),
            ),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (showHowToPlay &&
              !showIntro &&
              !_isProcessingRound &&
              !isCorrect &&
              !showGoodJob)
            Positioned.fill(
              child: HowToPlayOverlay(
                previewChild: _buildHowToPreview(),
                handAlignment: _alignmentOf(_slotKeys[0]),
                handEndAlignment: _alignmentOf(_slotKeys[1]),
                handOffset: const Offset(0.15, 0.46),
                onDismiss: resetIdleTimer,
              ),
            ),

          if (showGoodJob)
            GoodJobOverlay(
              characterImage:
                  'assets/images/characters/cat_holding_fishbone.png',
              characterSizeFactor: 0.9,
              onNext: () async {
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BodyPartsAssemblyScreen(level: 12),
                    ),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  currentLevelIndex = 0;
                  currentSequence = List.from(allInitialSequences[0]);
                  isCorrect = false;
                  showGoodJob = false;
                  _hasSavedResult = false;
                  _tapTracker.startSession();
                });
                startIdleTimer();
              },
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
        ),
    );
  }

  Widget _buildCardsRow(BoxConstraints constraints, {bool preview = false}) {
    double maxByHeight = constraints.maxHeight * 0.45;
    double maxByWidth = constraints.maxWidth / 5.5;

    double universalCardSize =
    maxByHeight < maxByWidth ? maxByHeight : maxByWidth;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          height: universalCardSize,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (index) {
              if (index % 2 == 1) {
                return _buildArrow(universalCardSize, preview: preview);
              }
              int cardIndex = index ~/ 2;
              return _buildDraggableSlot(
                cardIndex,
                universalCardSize,
                preview: preview,
              );
            }),
          ),
        ),
      ),
    );
  }

  Alignment _alignmentOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    if (box == null || root == null || !box.hasSize) return Alignment.center;

    final center = box.localToGlobal(box.size.center(Offset.zero), ancestor: root);
    return Alignment(
      center.dx / root.size.width * 2 - 1,
      center.dy / root.size.height * 2 - 1,
    );
  }

  Widget _buildHowToPreview() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/bg_rainbow_closeup2.png',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _buildCardsRow(constraints, preview: true),
          ),
        ),
      ],
    );
  }

  Widget _buildArrow(double height, {bool preview = false}) {
    return Visibility(
      visible: !preview && isCorrect,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: height * 0.3,
          color: const Color(0xFF3E2723),
        ),
      ),
    );
  }

  Widget _buildDraggableSlot(int index, double cardSize, {bool preview = false}) {
    return DragTarget<int>(
      onAcceptWithDetails: (details) => _onItemDropped(details.data, index),
      builder: (context, candidateData, rejectedData) {
        return KeyedSubtree(
          key: (!preview && index < 4) ? _slotKeys[index] : null,
          child: Draggable<int>(
            data: index,
            maxSimultaneousDrags: isCorrect || showGoodJob || _isProcessingRound
                ? 0
                : 1,
            onDragStarted: cancelIdleTimer,
            onDragEnd: (_) {
              if (!isCorrect && !_isProcessingRound && !showGoodJob) {
                startIdleTimer();
              }
            },
            feedback: Material(
              color: Colors.transparent,
              child: _buildCardUI(currentSequence[index], true, cardSize),
            ),
            childWhenDragging: Opacity(
              opacity: 0.5,
              child: _buildCardUI(currentSequence[index], false, cardSize),
            ),
            child: _buildCardUI(
              preview ? allInitialSequences[0][index] : currentSequence[index],
              false,
              cardSize,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardUI(String imagePath, bool isDragging, double cardSize) {
    return SizedBox(
      width: cardSize,
      height: cardSize,
      child: Container(
        margin: const EdgeInsets.all(6.0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect ? const Color(0xFF81C784) : Colors.grey.shade500,
            width: 5,
          ),
          color: Colors.white,
          boxShadow: isDragging
              ? [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
