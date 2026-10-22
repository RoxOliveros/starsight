import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/soft_hard_game.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import 'kiki_reaction.dart';
import 'lagoon_game_ui.dart';

enum GamePhase {
  intro,
  sweetPrompt,
  playing,
  sourPrompt,
  saltyPrompt,
  bitterPrompt,
  favoriteTaste,
  goodJob,
}

enum TasteRound { sweet, sour, salty, bitter }

class FallingFood {
  String imagePath;
  double x;
  double y;
  double speed;
  bool isTarget;

  FallingFood({
    required this.imagePath,
    required this.x,
    required this.y,
    required this.speed,
    required this.isTarget,
  });
}

class CatchingGameScreen extends StatefulWidget {
  final int level;

  const CatchingGameScreen({super.key, required this.level});

  @override
  State<CatchingGameScreen> createState() => _CatchingGameScreenState();
}

class _CatchingGameScreenState extends State<CatchingGameScreen>
    with
        SingleTickerProviderStateMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<CatchingGameScreen>,
        KikiReactionMixin {

  late AnimationController _gameLoopController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _kikiPlayer= AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _kikiPlayer];

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  final Random _random = Random();
  final GameTapTracker _tapTracker = GameTapTracker();

  GamePhase _currentPhase = GamePhase.intro;
  TasteRound _currentRound = TasteRound.sweet;

  double _basketX = 0.5;
  final List<FallingFood> _fallingItems = [];
  int _spawnTimer = 0;

  int _caughtCount = 0;
  int _wrongCatchCount = 0;
  final int _targetToWin = 15;

  bool _canTapFavorite = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  static const double _catchTop = 0.65;
  static const double _catchBottom = 0.90;
  static const double _catchHalfWidth = 0.085;

  final String _catchMissedFoods = 'audio/discovery_lagoon/catching_missed_food.wav';

  final List<String> _sweetFoodImages = [
    'assets/images/objects/lagoon/cookie.png',
    'assets/images/objects/lagoon/chocolate.png',
    'assets/images/objects/lagoon/candy_colored.png',
    'assets/images/objects/lagoon/strawberry.png',
    'assets/images/objects/lagoon/banana_colored.png',
  ];

  final List<String> _sourFoodImages = [
    'assets/images/objects/lagoon/orange.png',
    'assets/images/objects/lagoon/lemon.png',
    'assets/images/objects/lagoon/yogurt.png',
    'assets/images/objects/lagoon/tamarid.png',
    'assets/images/objects/lagoon/vinegar.png',
  ];

  final List<String> _saltyFoodImages = [
    'assets/images/objects/lagoon/pizza_colored.png',
    'assets/images/objects/lagoon/fries.png',
    'assets/images/objects/lagoon/chips.png',
    'assets/images/objects/lagoon/cheese.png',
    'assets/images/objects/lagoon/bacon.png',
  ];

  final List<String> _bitterFoodImages = [
    'assets/images/objects/lagoon/coffee.png',
    'assets/images/objects/lagoon/lettuce.png',
    'assets/images/objects/lagoon/bittergourd.png',
    'assets/images/objects/lagoon/broccoli.png',
  ];

  final List<String> _wrongFoodImages = [
    'assets/images/objects/lagoon/onion.png',
    'assets/images/objects/lagoon/perfume_fish.png',
    'assets/images/objects/lagoon/socks.png',
  ];

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

    _playIntroSequence();

    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_updateGame);
  }

  Future<void> _playIntroSequence() async {
    await playVoiceRestartingOnFaceLoss(
      _audioPlayer,
      'audio/discovery_lagoon/catching_intro.wav',
    );
    if (!mounted) return;
    await _startSweetRound();
  }

  Future<void> _startRound(
      TasteRound round,
      GamePhase promptPhase,
      String audio,
      ) async {
    setState(() {
      _fallingItems.clear();
      _caughtCount = 0;
      _wrongCatchCount = 0;
      _currentRound = round;
      _currentPhase = promptPhase;
    });

    await playVoiceRestartingOnFaceLoss(_audioPlayer, audio);
    if (!mounted) return;

    setState(() => _currentPhase = GamePhase.playing);
    _gameLoopController.forward();
  }

  Future<void> _startSweetRound() => _startRound(
    TasteRound.sweet,
    GamePhase.sweetPrompt,
    'audio/discovery_lagoon/catching_sweet.wav',
  );

  Future<void> _startSourRound() => _startRound(
    TasteRound.sour,
    GamePhase.sourPrompt,
    'audio/discovery_lagoon/catching_sour.wav',
  );

  Future<void> _startSaltyRound() => _startRound(
    TasteRound.salty,
    GamePhase.saltyPrompt,
    'audio/discovery_lagoon/catching_salty.wav',
  );

  Future<void> _startBitterRound() => _startRound(
    TasteRound.bitter,
    GamePhase.bitterPrompt,
    'audio/discovery_lagoon/catching_bitter.wav',
  );

  Future<void> _repeatCurrentRound() async {
    switch (_currentRound) {
      case TasteRound.sweet:
        await _startSweetRound();
        break;
      case TasteRound.sour:
        await _startSourRound();
        break;
      case TasteRound.salty:
        await _startSaltyRound();
        break;
      case TasteRound.bitter:
        await _startBitterRound();
        break;
    }
  }

  Future<void> _startFavoriteTastePhase() async {
    setState(() {
      _fallingItems.clear();
      _currentPhase = GamePhase.favoriteTaste;
      _canTapFavorite = false;
    });

    await playVoiceRestartingOnFaceLoss(
      _audioPlayer,
      'audio/discovery_lagoon/catching_fav_taste.wav',
    );
    if (!mounted) return;

    setState(() => _canTapFavorite = true);
  }

  Future<void> _onFavoriteTasteTapped() async {
    if (!_canTapFavorite || _currentPhase != GamePhase.favoriteTaste) return;

    _tapTracker.recordCorrectTap();
    setState(() => _canTapFavorite = false);

    showKikiReaction(KikiState.correct);
    if (!mounted) return;

    await playVoiceRestartingOnFaceLoss(
      _audioPlayer,
      'audio/discovery_lagoon/catching_ending.wav',
    );
    if (!mounted) return;

    await _saveDataAndShowGoodJob();
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    LagoonDatabaseService.saveGameData(
      gameId: 'lagoon_catching_game',
      activityName: 'Catching Game',
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
      setState(() => _currentPhase = GamePhase.goodJob);
    }
  }

  void _updateGame() {
    if (_currentPhase != GamePhase.playing) return;

    var roundDone = false;

    setState(() {
      _spawnTimer++;
      if (_spawnTimer >= 40) {
        _spawnTimer = 0;
        _spawnFood();
      }

      for (int i = _fallingItems.length - 1; i >= 0; i--) {
        if (roundDone) break;

        _fallingItems[i].y += _fallingItems[i].speed;

        if (_fallingItems[i].y >= _catchTop &&
            _fallingItems[i].y <= _catchBottom) {
          final double horizontalDistance =
          (_fallingItems[i].x - _basketX).abs();

          if (horizontalDistance < _catchHalfWidth) {
            final caughtItem = _fallingItems[i];
            _fallingItems.removeAt(i);

            if (caughtItem.isTarget) {
              _tapTracker.recordCorrectTap();
              _caughtCount++;
            } else {
              _tapTracker.recordMistake();
              _wrongCatchCount++;
            }

            if (_caughtCount + _wrongCatchCount >= _targetToWin) {
              _gameLoopController.stop();
              roundDone = true;
            } else if (caughtItem.isTarget) {
              showKikiReaction(KikiState.correct);
            } else {
              GamesSfxPlayer.instance.play(GameSfx.bubblePop);
              showKikiReaction(KikiState.wrong);
            }
            continue;
          }
        }

        if (_fallingItems[i].y > 1.1) {
          _fallingItems.removeAt(i);
        }
      }
    });

    if (roundDone) unawaited(_onRoundFinished());
  }

  Future<void> _onRoundFinished() async {
    final passed = _caughtCount > _wrongCatchCount;

    if (!passed) {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, _catchMissedFoods);
      if (!mounted) return;
      await _repeatCurrentRound();
      return;
    }

    await showKikiReaction(KikiState.correct);
    if (!mounted) return;

    switch (_currentRound) {
      case TasteRound.sweet:
        await _startSourRound();
      case TasteRound.sour:
        await _startSaltyRound();
      case TasteRound.salty:
        await _startBitterRound();
      case TasteRound.bitter:
        await _startFavoriteTastePhase();
    }
  }

  void _spawnFood() {
    bool spawnTarget = _random.nextDouble() < 0.50;

    String randomImage;
    if (spawnTarget) {
      if (_currentRound == TasteRound.sweet) {
        randomImage =
            _sweetFoodImages[_random.nextInt(_sweetFoodImages.length)];
      } else if (_currentRound == TasteRound.sour) {
        randomImage = _sourFoodImages[_random.nextInt(_sourFoodImages.length)];
      } else if (_currentRound == TasteRound.salty) {
        randomImage =
            _saltyFoodImages[_random.nextInt(_saltyFoodImages.length)];
      } else {
        randomImage =
            _bitterFoodImages[_random.nextInt(_bitterFoodImages.length)];
      }
    } else {
      List<String> distractionPool = [..._wrongFoodImages];
      if (_currentRound == TasteRound.sweet) {
        distractionPool.addAll(_sourFoodImages);
        distractionPool.addAll(_saltyFoodImages);
        distractionPool.addAll(_bitterFoodImages);
      } else if (_currentRound == TasteRound.sour) {
        distractionPool.addAll(_sweetFoodImages);
        distractionPool.addAll(_saltyFoodImages);
        distractionPool.addAll(_bitterFoodImages);
      } else if (_currentRound == TasteRound.salty) {
        distractionPool.addAll(_sweetFoodImages);
        distractionPool.addAll(_sourFoodImages);
        distractionPool.addAll(_bitterFoodImages);
      } else {
        distractionPool.addAll(_sweetFoodImages);
        distractionPool.addAll(_sourFoodImages);
        distractionPool.addAll(_saltyFoodImages);
      }
      randomImage = distractionPool[_random.nextInt(distractionPool.length)];
    }

    _fallingItems.add(
      FallingFood(
        imagePath: randomImage,
        x: 0.1 + (_random.nextDouble() * 0.8),
        y: -0.15,
        speed: 0.006 + (_random.nextDouble() * 0.005),
        isTarget: spawnTarget,
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails details, double screenWidth) {
    if (_currentPhase != GamePhase.playing) return;

    setState(() {
      _basketX += details.delta.dx / screenWidth;
      _basketX = _basketX.clamp(0.15, 0.85);
    });
  }

  void _restartGame() {
    setState(() {
      _caughtCount = 0;
      _wrongCatchCount = 0;
      _fallingItems.clear();
      _currentRound = TasteRound.sweet;
      _currentPhase = GamePhase.intro;
      _hasSavedResult = false;
      _tapTracker.startSession();
    });
    _playIntroSequence();
  }

  @override
  void dispose() {
    disposeAiCamera();
    _gameLoopController.dispose();
    _audioPlayer.dispose();
    _kikiPlayer.dispose();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPhaseContent(sw, sh),

          if (_currentPhase != GamePhase.goodJob) ...[
            Positioned(top: 25, left: 25, child: const LagoonXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LagoonLevelBadge(level: widget.level),
            ),
          ],

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(double sw, double sh) {
    if (_currentPhase == GamePhase.intro) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_closeup2.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: -sh * 0.10,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/characters/kiki_the_cat.png',
                height: sh * 0.90,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: -sh * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/objects/lagoon/basket.png',
                width: sh * 0.75,
                height: sh * 0.55,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      );
    }

    if (_currentPhase == GamePhase.sweetPrompt) {
      return Image.asset(
        'assets/images/objects/lagoon/sweet.png',
        width: sw,
        height: sh,
        fit: BoxFit.cover,
      );
    }

    if (_currentPhase == GamePhase.sourPrompt) {
      return Image.asset(
        'assets/images/objects/lagoon/sour.png',
        width: sw,
        height: sh,
        fit: BoxFit.cover,
      );
    }

    if (_currentPhase == GamePhase.saltyPrompt) {
      return Image.asset(
        'assets/images/objects/lagoon/salty.png',
        width: sw,
        height: sh,
        fit: BoxFit.cover,
      );
    }

    if (_currentPhase == GamePhase.bitterPrompt) {
      return Image.asset(
        'assets/images/objects/lagoon/bitter.png',
        width: sw,
        height: sh,
        fit: BoxFit.cover,
      );
    }

    if (_currentPhase == GamePhase.favoriteTaste) {
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_closeup.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: -sh * 0.20,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/characters/kiki_the_cat.png',
                height: sh * 1.15,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: -sh * 0.12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFavoriteChoice(
                  'assets/images/objects/lagoon/chocolate.png',
                  sh,
                  sw,
                ),
                _buildFavoriteChoice(
                  'assets/images/objects/lagoon/lemon.png',
                  sh,
                  sw,
                ),
                _buildFavoriteChoice(
                  'assets/images/objects/lagoon/fries.png',
                  sh,
                  sw,
                ),
                _buildFavoriteChoice(
                  'assets/images/objects/lagoon/bittergourd.png',
                  sh,
                  sw,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final double basketWidth = sh * 0.75;
    final double basketHeight = sh * 0.55;
    final double foodSize = sh * 0.26;

    return GestureDetector(
      onPanUpdate: (details) => _onPanUpdate(details, sw),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_closeup.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            left: (_basketX * sw) - (basketWidth / 2),
            bottom: -sh * 0.15,
            child: Image.asset(
              'assets/images/objects/lagoon/basket.png',
              width: basketWidth,
              height: basketHeight,
              fit: BoxFit.contain,
            ),
          ),
          ..._fallingItems.map((food) {
            return Positioned(
              left: (food.x * sw) - (foodSize / 2),
              top: food.y * sh,
              child: Image.asset(
                food.imagePath,
                width: foodSize,
                height: foodSize,
                fit: BoxFit.contain,
              ),
            );
          }),
          if (_currentPhase == GamePhase.goodJob)
            GoodJobOverlay(
              characterImage:
                  'assets/images/characters/cat_holding_fishbone.png',
              characterSizeFactor: 0.9,
              onNext: () {
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SoftHardGameScreen(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: _restartGame,
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoriteChoice(
    String foodImagePath,
    double screenHeight,
    double screenWidth,
  ) {
    final double basketW = screenWidth * 0.23;
    final double basketH = screenHeight * 0.38;
    final double foodS = screenHeight * 0.28;

    return GestureDetector(
      onTap: _onFavoriteTasteTapped,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Image.asset(
            'assets/images/objects/lagoon/basket.png',
            width: basketW,
            height: basketH,
            fit: BoxFit.contain,
          ),
          Positioned(
            bottom: screenHeight * 0.15,
            child: Image.asset(
              foodImagePath,
              width: foodS,
              height: foodS,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
