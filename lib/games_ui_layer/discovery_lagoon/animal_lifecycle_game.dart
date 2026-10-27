  import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
  import 'package:flutter/material.dart';
  import 'package:audioplayers/audioplayers.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:StarSight/business_layer/lagoon_database_service.dart';
  import 'package:StarSight/business_layer/game_tap_tracker.dart';
  import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
  import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
  import 'package:StarSight/business_layer/lagoon_progress_service.dart';
  import 'package:StarSight/games_ui_layer/discovery_lagoon/cold_hot_game.dart';
  import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
  import 'package:StarSight/business_layer/orientation_service.dart';
  import '../games_audio_helper.dart';
  import '../goodjob_prompt.dart';
  import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'kiki_reaction.dart';
  import 'lagoon_game_ui.dart';

  class AnimalLifecycleGame extends StatefulWidget {
    final int level;

    const AnimalLifecycleGame({super.key, required this.level});

    @override
    State<AnimalLifecycleGame> createState() => _AnimalLifecycleGameState();
  }

  class _AnimalLifecycleGameState extends State<AnimalLifecycleGame>
      with AiCameraMixin, AppAudioLifecycleMixin<AnimalLifecycleGame>, KikiReactionMixin, IdleHintMixin {

    final AudioPlayer _audioPlayer = AudioPlayer();
    final AudioPlayer _kikiPlayer= AudioPlayer();

    @override
    List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _kikiPlayer];

    @override
    AudioPlayer get kikiPlayer => _kikiPlayer;

    final GameTapTracker _tapTracker = GameTapTracker();
    final List<GlobalKey> _slotKeys = List.generate(4, (_) => GlobalKey());

    final double kikiHorizontalOffset = 0.0;
    final double kikiVerticalOffset = 40.0;
    final double kikiSizeFactor = 1.20;

    late List<String> currentSequence;

    int currentLevelIndex = 0;

    bool showIntro = true;
    bool showGoodJob = false;

    bool _hideLightingCard = false;
    bool _hasSavedResult = false;

    bool isCorrect = false;

    final List<List<String>> allCorrectSequences = [
      [
        'assets/images/objects/lagoon/b1_egg.png',
        'assets/images/objects/lagoon/b2_caterpillar.png',
        'assets/images/objects/lagoon/b3_chrysalis.png',
        'assets/images/objects/lagoon/b4_butterfly.png',
      ],
      [
        'assets/images/objects/lagoon/fr1_egg.png',
        'assets/images/objects/lagoon/fr2_tadpoles.png',
        'assets/images/objects/lagoon/fr3_froglet.png',
        'assets/images/objects/lagoon/frog.png',
      ],
      [
        'assets/images/objects/lagoon/c1_egg.png',
        'assets/images/objects/lagoon/c2_chick.png',
        'assets/images/objects/lagoon/c3_hen.png',
        'assets/images/objects/lagoon/c4_chicken.png',
      ],
      [
        'assets/images/objects/lagoon/cow_1.png',
        'assets/images/objects/lagoon/cow_2.png',
        'assets/images/objects/lagoon/cow_3.png',
        'assets/images/objects/lagoon/cow_4.png',
      ],
    ];

    final List<List<String>> allInitialSequences = [
      [
        'assets/images/objects/lagoon/b2_caterpillar.png',
        'assets/images/objects/lagoon/b4_butterfly.png',
        'assets/images/objects/lagoon/b1_egg.png',
        'assets/images/objects/lagoon/b3_chrysalis.png',
      ],
      [
        'assets/images/objects/lagoon/fr3_froglet.png',
        'assets/images/objects/lagoon/fr1_egg.png',
        'assets/images/objects/lagoon/frog.png',
        'assets/images/objects/lagoon/fr2_tadpoles.png',
      ],
      [
        'assets/images/objects/lagoon/c2_chick.png',
        'assets/images/objects/lagoon/c4_chicken.png',
        'assets/images/objects/lagoon/c1_egg.png',
        'assets/images/objects/lagoon/c3_hen.png',
      ],
      [
        'assets/images/objects/lagoon/cow_4.png',
        'assets/images/objects/lagoon/cow_1.png',
        'assets/images/objects/lagoon/cow_2.png',
        'assets/images/objects/lagoon/cow_3.png',
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
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        'assets/audio/discovery_lagoon/animal_lifecycle_game_intro.wav',
      );
      if (!mounted) return;
      setState(() => showIntro = false);
      startIdleTimer();
    }

    @override
    void dispose() {
      disposeAiCamera();
      disposeIdleTimer();
      _audioPlayer.dispose();
      _kikiPlayer.dispose();
      OrientationService.setLandscape();
      super.dispose();
    }

    void _onItemDropped(int oldIndex, int newIndex) {
      if (isCorrect || showGoodJob) return;

      setState(() {
        final temp = currentSequence[oldIndex];
        currentSequence[oldIndex] = currentSequence[newIndex];
        currentSequence[newIndex] = temp;

        _checkWinCondition();
      });
    }

    Future<void> _checkWinCondition() async {
      bool win = true;
      for (int i = 0; i < allCorrectSequences[currentLevelIndex].length; i++) {
        if (currentSequence[i] != allCorrectSequences[currentLevelIndex][i]) {
          win = false;
          break;
        }
      }

      setState(() {
        isCorrect = win;
      });

      if (isCorrect) {
        cancelIdleTimer();
        _tapTracker.recordCorrectTap();
        await GamesSfxPlayer.instance.play(GameSfx.bubbleClick);
        if (!mounted) return;
        showKikiReaction(KikiState.correct);

        if (currentLevelIndex < allCorrectSequences.length - 1) {
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            setState(() {
              currentLevelIndex++;
              currentSequence = List.from(allInitialSequences[currentLevelIndex]);
              isCorrect = false;
            });
            startIdleTimer();
          });
        } else {
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            _saveDataAndShowGoodJob();
          });
        }
      } else {
        startIdleTimer();
        _tapTracker.recordMistake();
        GamesSfxPlayer.instance.play(GameSfx.bubbleClick);
      }
    }

    Future<void> _saveDataAndShowGoodJob() async {
      if (_hasSavedResult) return;
      cancelIdleTimer();
      _hasSavedResult = true;
      List<String> finalEmotions = stopAiCamera();

      LagoonDatabaseService.saveGameData(
        gameId: 'lagoon_animal_lifecycle',
        activityName: 'Animal Lifecycle',
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
          showGoodJob = true;
        });
      }
    }

    @override
    Widget build(BuildContext context) {
      return Listener(
          onPointerDown: (_) {
            _tapTracker.recordGenericTap();
            if (!showIntro && !isCorrect && !showGoodJob) resetIdleTimer();
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
              Center(
                child: Transform.translate(
                  offset: Offset(kikiHorizontalOffset, kikiVerticalOffset),
                  child: FractionallySizedBox(
                    heightFactor: kikiSizeFactor,
                    child: Image.asset(
                      'assets/images/characters/kiki_standing.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
            else
              SafeArea(child: _buildCardsRow(currentSequence)),

            if (showHowToPlay && !showIntro && !isCorrect && !showGoodJob)
              Positioned.fill(
                child: HowToPlayOverlay(
                  previewChild: _buildHowToPreview(),
                  handAlignment: _alignmentOf(_slotKeys[2]),
                  handEndAlignment: _alignmentOf(_slotKeys[0]),
                  handOffset: const Offset(0.15, 0.4),
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

            if (showGoodJob)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/cat_holding_fishbone.png',
                characterSizeFactor: 0.9,
                onNext: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ColdHotGame(level: widget.level + 1),
                    ),
                  );
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
                onBack: () {
                  Navigator.pop(context);
                },
              ),
          ],
        ),
          ),
      );
    }

    Widget _buildCardsRow(List<String> sequence, {bool preview = false}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxByHeight = constraints.maxHeight * 0.45;
          final maxByWidth = constraints.maxWidth / 5.5;
          final size = maxByHeight < maxByWidth ? maxByHeight : maxByWidth;

          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                height: size,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(7, (index) {
                    if (index % 2 == 1) return _buildArrow(size);
                    final cardIndex = index ~/ 2;
                    if (preview) {
                      return _buildCardUI(sequence[cardIndex], false, size);
                    }
                    return _buildDraggableSlot(cardIndex, size);
                  }),
                ),
              ),
            ),
          );
        },
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
            child: _buildCardsRow(allInitialSequences[0], preview: true),
          ),
        ],
      );
    }

    Alignment _alignmentOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      final root = context.findRenderObject() as RenderBox?;
      if (box == null || root == null || !box.hasSize) return Alignment.center;
      final c = box.localToGlobal(box.size.center(Offset.zero), ancestor: root);
      return Alignment(
        c.dx / root.size.width * 2 - 1,
        c.dy / root.size.height * 2 - 1,
      );
    }

    Widget _buildArrow(double height) {
      return Visibility(
        visible: isCorrect,
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

    Widget _buildDraggableSlot(int index, double cardSize) {
      return DragTarget<int>(
        onAcceptWithDetails: (details) => _onItemDropped(details.data, index),
        builder: (context, candidateData, rejectedData) {
          return Draggable<int>(
            key: _slotKeys[index],
            data: index,
            maxSimultaneousDrags: isCorrect || showGoodJob ? 0 : 1,
            feedback: Material(
              color: Colors.transparent,
              child: _buildCardUI(currentSequence[index], true, cardSize),
            ),
            childWhenDragging: Opacity(
              opacity: 0.5,
              child: _buildCardUI(currentSequence[index], false, cardSize),
            ),
            child: _buildCardUI(currentSequence[index], false, cardSize),
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
              color: isCorrect ? Colors.orange : Colors.grey.shade500,
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
