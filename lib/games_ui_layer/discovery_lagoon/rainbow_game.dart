  import 'dart:async';
  import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
  import 'package:StarSight/business_layer/lagoon_progress_service.dart';
  import 'package:StarSight/business_layer/orientation_service.dart';
  import 'package:StarSight/games_ui_layer/discovery_lagoon/perfume_game.dart';
  import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
  import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
  import 'package:flutter/material.dart';
  import 'package:audioplayers/audioplayers.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:StarSight/business_layer/lagoon_database_service.dart';
  import 'package:StarSight/business_layer/game_tap_tracker.dart';
  import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
  import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
  import '../games_audio_helper.dart';
  import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'kiki_reaction.dart';
  import 'lagoon_game_ui.dart';

  class RainbowGameScreen extends StatefulWidget {
    final int level;

    const RainbowGameScreen({super.key, required this.level});

    @override
    State<RainbowGameScreen> createState() => _RainbowGameScreenState();
  }

  class _RainbowGameScreenState extends State<RainbowGameScreen>
      with
          KikiReactionMixin,
          AiCameraMixin,
          AppAudioLifecycleMixin<RainbowGameScreen>,
          IdleHintMixin {

    final AudioPlayer _audioPlayer = AudioPlayer();
    final AudioPlayer _kikiPlayer= AudioPlayer();

    @override
    List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _kikiPlayer];

    @override
    AudioPlayer get kikiPlayer => _kikiPlayer;

    final GameTapTracker _tapTracker = GameTapTracker();
    final GlobalKey _choiceKey = GlobalKey();

    bool get _hintAllowed =>
        showHowToPlay &&
            !_isIntroPlaying &&
            !_isTransitioning &&
            !_showGoodJob;

    int _currentLevel = 1;

    bool _isIntroPlaying = true;
    bool _showGoodJob = false;
    bool _isTransitioning = false;
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

      _startLevel1Intro();
    }

    void _onBackgroundTapped() {
      if (_isIntroPlaying || _isTransitioning || _showGoodJob) return;

      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      if (kikiState != KikiState.wrong) {
        showKikiReaction(KikiState.wrong);
      }
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

    void _endIntro() {
      if (!mounted) return;
      setState(() {
        _isIntroPlaying = false;
        showHowToPlay = false;
      });
      startIdleTimer();
    }

    Alignment _alignmentOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      final root = context.findRenderObject() as RenderBox?;
      if (box == null || root == null || !box.hasSize) return Alignment.center;

      final center =
      box.localToGlobal(box.size.center(Offset.zero), ancestor: root);
      return Alignment(
        center.dx / root.size.width * 2 - 1,
        center.dy / root.size.height * 2 - 1,
      );
    }

    Future<void> _startLevel1Intro() async {
      setState(() => _isIntroPlaying = true);
      await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/whereis_therainbow.wav');
      _endIntro();
    }

    void _onRainbowTapped() async {
      if (_isIntroPlaying || _isTransitioning || _showGoodJob) return;
      _isTransitioning = true;
      cancelIdleTimer();
      if (showHowToPlay) setState(() => showHowToPlay = false);

      _tapTracker.recordCorrectTap();
      await showKikiReaction(KikiState.correct);

      if (mounted) {
        setState(() {
          _currentLevel = 2;
          _isIntroPlaying = true;
        });

        await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_color1.wav');

        _isTransitioning = false;
        _endIntro();
      }
    }

    void _onItemTapped(bool isCorrect) async {
      if (_isIntroPlaying || _isTransitioning || _showGoodJob) return;

      if (isCorrect) {
        _isTransitioning = true;
        cancelIdleTimer();
        if (showHowToPlay) setState(() => showHowToPlay = false);
        unawaited(_kikiPlayer.stop());

        try {
          _tapTracker.recordCorrectTap();
          setState(() => kikiState = KikiState.correct);

          await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/sound_effects/sfx_shine.wav');

          if (_currentLevel == 8) {
            await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_part_rc.wav');
          } else {
            await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_color_rc.wav');
          }

          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) setState(() => kikiState = KikiState.normal);

          if (_currentLevel == 2 && mounted) {
            setState(() {
              _currentLevel = 3;
              _isIntroPlaying = true;
            });
            await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_color2.wav');
            _endIntro();
          } else if (_currentLevel == 3 && mounted) {
            setState(() {
              _currentLevel = 4;
              _isIntroPlaying = true;
            });
            await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_color3.wav');
            _endIntro();
          } else if (_currentLevel == 4 && mounted) {
            setState(() {
              _currentLevel = 5;
              _isIntroPlaying = true;
            });
            await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_color4.wav');
            _endIntro();
          } else if (_currentLevel == 5 && mounted) {
            setState(() {
              _currentLevel = 6;
              _isIntroPlaying = true;
            });
            await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_color5.wav');
            _endIntro();
          } else if (_currentLevel == 6 && mounted) {
            setState(() {
              _currentLevel = 7;
              _isIntroPlaying = true;
            });
            await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_color6.wav');
            _endIntro();
          } else if (_currentLevel == 7 && mounted) {
            setState(() {
              _currentLevel = 8;
              _isIntroPlaying = true;
            });
            await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/what_part.wav');
            _endIntro();
          } else if (_currentLevel == 8 && mounted) {
            await _saveDataAndShowGoodJob();
          }
        } finally {
          _isTransitioning = false;
        }
      } else {
        _tapTracker.recordMistake();
        GamesSfxPlayer.instance.play(GameSfx.bubblePop);
        if (kikiState != KikiState.wrong) {
          showKikiReaction(KikiState.wrong);
        }
      }
    }

    Future<void> _saveDataAndShowGoodJob() async {
      if (_hasSavedResult) return;
      _hasSavedResult = true;
      List<String> finalEmotions = stopAiCamera();

      LagoonDatabaseService.saveGameData(
        gameId: 'lagoon_rainbow_game',
        activityName: 'Rainbow Game',
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
        setState(() => _showGoodJob = true);
      }
    }

    void _restartGame() {
      setState(() {
        _currentLevel = 1;
        _showGoodJob = false;
        _hasSavedResult = false;
        _tapTracker.startSession();
      });
      _startLevel1Intro();
    }

    @override
    Widget buildKiki(BuildContext context, {double heightFactor = 0.78}) {
      final kikiWidget = SizedBox(
        height: MediaQuery.of(context).size.height * heightFactor,
        child: switch (kikiState) {
          KikiState.correct => Image.asset(
            'assets/animations/characters/kiki_cheering.webp',
            fit: BoxFit.contain,
          ),
          KikiState.wrong => Image.asset(
            'assets/images/characters/kiki_tryagain.png',
            fit: BoxFit.contain,
          ),
          KikiState.normal => Image.asset(
            'assets/images/characters/kiki_standing.png',
            fit: BoxFit.contain,
          ),
        },
      );

      if (_currentLevel == 8) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: -35,
          child: Align(alignment: Alignment.bottomCenter, child: kikiWidget),
        );
      }

      return Positioned(left: 16, bottom: -35, child: kikiWidget);
    }

    @override
    Widget build(BuildContext context) {
      return Listener(
        onPointerDown: (_) {
          if (!_isIntroPlaying && !_isTransitioning && !_showGoodJob) {
            resetIdleTimer();
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: _buildScene()),

              if (_hintAllowed) Positioned.fill(child: _buildHowToPlay()),

              if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
                LightingPromptCard(
                  onClose: () {
                    setState(() => _hideLightingCard = true);
                    releaseFaceGate();
                  },
                ),

              if (_showGoodJob)
                GoodJobOverlay(
                  characterImage:
                  'assets/images/characters/cat_holding_fishbone.png',
                  characterSizeFactor: 0.9,
                  onNext: () {
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => PerfumeGame(level: widget.level + 1),
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

    static const _lagoon = 'assets/images/objects/lagoon';
    static const _puzzle = 'assets/images/objects/puzzle';

    List<(String, bool)> _levelOptions(int level) => switch (level) {
      2 => [('$_lagoon/apple_colored.png', true), ('$_lagoon/comb.png', false), ('$_lagoon/toothbrush.png', false)],
      3 => [('$_lagoon/duck.png', false), ('$_lagoon/comb.png', true), ('$_lagoon/apple_colored.png', false)],
      4 => [('$_lagoon/comb.png', false), ('$_lagoon/rug.png', false), ('$_lagoon/duck.png', true)],
      5 => [('$_lagoon/leaves.png', true), ('$_lagoon/chair.png', false), ('$_lagoon/rug.png', false)],
      6 => [('$_lagoon/rug.png', true), ('$_lagoon/car.png', false), ('$_lagoon/ball.png', false)],
      7 => [('$_puzzle/pen.png', true), ('$_puzzle/compass.png', false), ('$_puzzle/notebook.png', false)],
      8 => [('$_lagoon/eye.png', true), ('$_lagoon/lips.png', false), ('$_lagoon/nose.png', false)],
      _ => [],
    };

    List<Widget> _buildChoices(double width, int level, bool preview) {
      final cards = _levelOptions(level).map((o) {
        return _buildItemCard(
          width: width,
          imageAsset: o.$1,
          isCorrect: o.$2,
          preview: preview,
        );
      }).toList();

      if (cards.isNotEmpty && !preview) {
        cards[0] = KeyedSubtree(key: _choiceKey, child: cards[0]);
      }
      return cards;
    }

    Widget _buildItemCard({
      required double width,
      required String imageAsset,
      required bool isCorrect,
      bool preview = false,
    }) {
      final cardSize = width * 0.14;
      return GestureDetector(
        onTap: preview ? null : () => _onItemTapped(isCorrect),
        child: Container(
          width: cardSize,
          height: cardSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: preview
              ? const SizedBox.shrink()
              : Image.asset(imageAsset, fit: BoxFit.contain),
        ),
      );
    }

    Widget _buildHowToPlay() {
      final handAlign = _currentLevel == 1
          ? const Alignment(0.0, -0.65)
          : _alignmentOf(_choiceKey);

      return HowToPlayOverlay(
        handAlignment: handAlign,
        handOffset: const Offset(0.15, 0.55),
        onDismiss: resetIdleTimer,
        previewChild: _buildScene(preview: true),
      );
    }

    Widget _buildScene({bool preview = false}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(switch (_currentLevel) {
                  1 => 'assets/images/backgrounds/bg_rainbow_lagoon.png',
                  2 => 'assets/images/objects/lagoon/rainbow_bg_c1.png',
                  3 => 'assets/images/objects/lagoon/rainbow_bg_c2.png',
                  4 => 'assets/images/objects/lagoon/rainbow_bg_c3.png',
                  5 => 'assets/images/objects/lagoon/rainbow_bg_c4.png',
                  6 => 'assets/images/objects/lagoon/rainbow_bg_c5.png',
                  7 => 'assets/images/objects/lagoon/rainbow_bg_c6.png',
                  _ => 'assets/images/backgrounds/bg_rainbow_lagoon.png',
                }, fit: BoxFit.cover),
              ),

              if (_currentLevel == 1 && !preview) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onBackgroundTapped,
                  ),
                ),
                if (kikiState == KikiState.correct)
                  Positioned(
                    left: width * 0.35,
                    top: height * 0.08,
                    width: width * 0.30,
                    height: height * 0.35,
                    child: Image.asset(
                      'assets/images/objects/lagoon/sparkle.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                Positioned(
                  left: width * 0.22,
                  top: height * 0.05,
                  width: width * 0.56,
                  height: height * 0.45,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onRainbowTapped,
                  ),
                ),
              ],

              if (_currentLevel >= 2 && _currentLevel <= 7)
                Positioned(
                  left: width * 0.38,
                  top: height * 0.52,
                  right: width * 0.08,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _buildChoices(width, _currentLevel, preview),
                  ),
                ),

              if (_currentLevel == 8)
                Positioned(
                  left: width * 0.20,
                  top: height * 0.15,
                  right: width * 0.20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _buildChoices(width, _currentLevel, preview),
                  ),
                ),

              buildKiki(context),

              Positioned(top: 25, left: 25, child: const LagoonXButton()),
              Positioned(
                top: 25,
                right: 25,
                child: LagoonLevelBadge(level: widget.level),
              ),
            ],
          );
        },
      );
    }
  }
