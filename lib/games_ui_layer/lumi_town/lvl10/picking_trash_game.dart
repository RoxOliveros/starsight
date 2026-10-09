import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl11/throwing_trash_game.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';
import '../../../ui_layer/game_loading_mixin.dart';
import '../../../ui_layer/loading_screen.dart';
import '../../games_audio_helper.dart';
import '../lumi_game_ui_layer.dart';

class PickingTrashGame extends StatefulWidget {
  final int level;

  const PickingTrashGame({super.key, required this.level});

  @override
  State<PickingTrashGame> createState() => _PickingTrashGameState();
}

class _PickingTrashGameState extends State<PickingTrashGame>
    with
        AiCameraMixin<PickingTrashGame>,
        GameLoadingMixin,
        AppAudioLifecycleMixin<PickingTrashGame> {
  // ==========================================
  // GAME STATE
  // ==========================================
  bool _showDrWoo = true;
  bool _isGameFinished = false;

  final double drWooX = 0.35;
  final double drWooY = 0.33;
  final double drWooSize = 0.30;

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _playerCompleteSubscription;

  List<TrashItemData> trashItems = [];

  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

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

    finishLoading(_startGameAfterLoading);
  }

  // ==========================================
  // LEVEL INITIALIZATION & RESTART
  // ==========================================
  void _startGameAfterLoading() {
    _resetLevel();
  }

  void _resetLevel() {
    setState(() {
      _isGameFinished = false;
      _showDrWoo = true;

      trashItems = [
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_apple.png',
          x: 0.00,
          y: 0.68,
          size: 0.08,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_chips2.png',
          x: 0.10,
          y: 0.83,
          size: 0.10,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_garbagebag2.png',
          x: 0.10,
          y: 0.38,
          size: 0.10,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_styro.png',
          x: 0.21,
          y: 0.39,
          size: 0.075,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_banana.png',
          x: 0.27,
          y: 0.40,
          size: 0.07,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_spork.png',
          x: 0.35,
          y: 0.49,
          size: 0.06,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_plasticbag.png',
          x: 0.25,
          y: 0.58,
          size: 0.11,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_chips1.png',
          x: 0.26,
          y: 0.85,
          size: 0.08,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_sodacan.png',
          x: 0.42,
          y: 0.46,
          size: 0.07,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_stick.png',
          x: 0.40,
          y: 0.55,
          size: 0.12,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_plastic1.png',
          x: 0.46,
          y: 0.78,
          size: 0.08,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_waterbottle.png',
          x: 0.53,
          y: 0.63,
          size: 0.09,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_drink.png',
          x: 0.58,
          y: 0.36,
          size: 0.03,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_leaf.png',
          x: 0.62,
          y: 0.50,
          size: 0.09,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_garbagebag1.png',
          x: 0.79,
          y: 0.54,
          size: 0.06,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_glassbottle.png',
          x: 0.90,
          y: 0.48,
          size: 0.04,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_fishbone.png',
          x: 0.67,
          y: 0.76,
          size: 0.07,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_rug.png',
          x: 0.90,
          y: 0.82,
          size: 0.09,
        ),
      ];
    });

    _playIntroSequence();
  }

  Future<void> _playIntroSequence() async {
    await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level10/picking_trash_game_intro.wav');

    _playerCompleteSubscription?.cancel();

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _showDrWoo = false;
        });
      }
    });
  }

  Future<void> _playEndingSequence() async {
    setState(() {
      _showDrWoo = true;
    });

    await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level10/picking_trash_game_ending.wav');

    _playerCompleteSubscription?.cancel();

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        _saveDataAndShowGoodJob();
      }
    });
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_picking_trash',
      activityName: 'Picking Trash',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });
    TownProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
    });

    if (mounted) {
      setState(() {
        _showDrWoo = false;
        _isGameFinished = true;
      });
    }
  }

  // ==========================================
  // ANIMATION & WIN LOGIC
  // ==========================================
  Future<void> _handleTrashTap(TrashItemData item) async {
    if (_showDrWoo || item.isCollected || _isGameFinished) return;

    _tapTracker.recordCorrectTap();

    bool startedOnLeft = item.x < 0.5;

    setState(() {
      trashItems.remove(item);
      trashItems.add(item);

      item.x = 0.5 - (item.size / 2);
      item.y = 0.5 - (item.size / 2);
    });

    await Future.delayed(const Duration(milliseconds: 800));
    await GamesSfxPlayer.instance.play(GameSfx.shine);

    setState(() {
      if (startedOnLeft) {
        item.x = -0.5;
      } else {
        item.x = 1.5;
      }
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        item.isCollected = true;

        if (trashItems.every((t) => t.isCollected)) {
          _playEndingSequence();
        }
      });
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.lumiTown(),
        gameBuilder: () => Listener(
          onPointerDown: (_) => _tapTracker.recordGenericTap(),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_park_sunny.png',
                  fit: BoxFit.cover,
                ),
              ),

              ...trashItems.where((item) => !item.isCollected).map((item) {
                return AnimatedPositioned(
                  key: ValueKey(item.image),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  left: screenSize.width * item.x,
                  top: screenSize.height * item.y,
                  width: screenSize.width * item.size,
                  child: GestureDetector(
                    onTap: () {
                      GamesSfxPlayer.instance.play(GameSfx.shine);
                      _handleTrashTap(item);
                    },
                    child: Image.asset(item.image, fit: BoxFit.contain),
                  ),
                );
              }),

              Positioned(top: 25, left: 25, child: LumiXButton()),
              Positioned(
                top: 25,
                right: 25,
                child: LumiLevelBadge(level: widget.level),
              ),

              if (_showDrWoo)
                Positioned(
                  left: screenSize.width * drWooX,
                  top: screenSize.height * drWooY,
                  width: screenSize.width * drWooSize,
                  child: Image.asset(
                    'assets/images/characters/tr.woo_the_owl.png',
                    fit: BoxFit.contain,
                  ),
                ),

              if (hasCapturedFirstFrame &&
                  !isFaceDetected &&
                  !_hideLightingCard)
                LightingPromptCard(
                  onClose: () {
                    setState(() => _hideLightingCard = true);
                    releaseFaceGate();
                  },
                ),

              if (_isGameFinished)
                Positioned.fill(
                  child: GoodJobOverlay(
                    characterImage:
                        'assets/images/characters/tr.woo_the_owl.png',
                    onNext: () {
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) =>
                                ThrowingTrashGame(level: widget.level + 1),
                          ),
                          (route) => route.isFirst,
                        );
                      }
                    },
                    onRestart: () {
                      _hasSavedResult = false;
                      _tapTracker.startSession();
                      _resetLevel();
                    },
                    onBack: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrashItemData {
  final String image;
  double x;
  double y;
  final double size;
  bool isCollected;

  TrashItemData({
    required this.image,
    required this.x,
    required this.y,
    required this.size,
    this.isCollected = false,
  });
}
