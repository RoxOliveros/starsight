import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/season_scene_tap_screen.dart';
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
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'kiki_reaction.dart';
import 'lagoon_game_ui.dart';

enum GamePhase { intro, prompt, playing, favoriteTaste, goodJob }

enum TasteRound { sweet, sour, salty, bitter }

class FoodItem {
  final int id;
  final String imagePath;
  final bool isTarget;

  /// Center position as a fraction of screen width / height.
  final double cx;
  final double cy;

  const FoodItem({
    required this.id,
    required this.imagePath,
    required this.isTarget,
    required this.cx,
    required this.cy,
  });
}

class CatchingDifferentTasteGameScreen extends StatefulWidget {
  final int level;

  const CatchingDifferentTasteGameScreen({super.key, required this.level});

  @override
  State<CatchingDifferentTasteGameScreen> createState() =>
      _CatchingDifferentTasteGameScreenState();
}

class _CatchingDifferentTasteGameScreenState
    extends State<CatchingDifferentTasteGameScreen>
    with
        SingleTickerProviderStateMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<CatchingDifferentTasteGameScreen>,
        KikiReactionMixin,
        IdleHintMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _kikiPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _kikiPlayer];

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  final Random _random = Random();
  final GameTapTracker _tapTracker = GameTapTracker();

  GamePhase _currentPhase = GamePhase.intro;
  TasteRound _currentRound = TasteRound.sweet;

  List<FoodItem> _foods = [];
  int _nextFoodId = 0;
  int _caughtCount = 0;
  bool _roundLocked = true;
  bool _canTapFavorite = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  static const int _targetsPerRound = 3;
  static const int _distractorsPerRound = 3;

  // ── Assets ───────────────────────────────────────────────────────────
  static const String _bgPlaying = 'assets/images/backgrounds/bg_rainbow_closeup.png';
  static const String _bgIntro = 'assets/images/backgrounds/bg_rainbow_closeup2.png';
  static const String _kikiImage = 'assets/images/characters/kiki_the_cat.png';
  static const String _basketImage = 'assets/images/objects/lagoon/basket.png';

  static const Map<TasteRound, String> _tasteImages = {
    TasteRound.sweet: 'assets/images/objects/lagoon/sweet.png',
    TasteRound.sour: 'assets/images/objects/lagoon/sour.png',
    TasteRound.salty: 'assets/images/objects/lagoon/salty.png',
    TasteRound.bitter: 'assets/images/objects/lagoon/bitter.png',
  };

  static const Map<TasteRound, String> _promptAudio = {
    TasteRound.sweet: 'audio/discovery_lagoon/catching_sweet.wav',
    TasteRound.sour: 'audio/discovery_lagoon/catching_sour.wav',
    TasteRound.salty: 'audio/discovery_lagoon/catching_salty.wav',
    TasteRound.bitter: 'audio/discovery_lagoon/catching_bitter.wav',
  };

  static const Map<TasteRound, List<String>> _foodsByTaste = {
    TasteRound.sweet: [
      'assets/images/objects/lagoon/cookie.png',
      'assets/images/objects/lagoon/chocolate.png',
      'assets/images/objects/lagoon/candy_colored.png',
      'assets/images/objects/lagoon/strawberry.png',
      'assets/images/objects/lagoon/banana_colored.png',
    ],
    TasteRound.sour: [
      'assets/images/objects/lagoon/orange.png',
      'assets/images/objects/lagoon/lemon.png',
      'assets/images/objects/lagoon/yogurt.png',
      'assets/images/objects/lagoon/tamarid.png',
      'assets/images/objects/lagoon/vinegar.png',
    ],
    TasteRound.salty: [
      'assets/images/objects/lagoon/pizza_colored.png',
      'assets/images/objects/lagoon/fries.png',
      'assets/images/objects/lagoon/chips.png',
      'assets/images/objects/lagoon/cheese.png',
      'assets/images/objects/lagoon/bacon.png',
    ],
    TasteRound.bitter: [
      'assets/images/objects/lagoon/coffee.png',
      'assets/images/objects/lagoon/lettuce.png',
      'assets/images/objects/lagoon/bittergourd.png',
      'assets/images/objects/lagoon/broccoli.png',
    ],
  };

  static const List<String> _wrongFoodImages = [
    'assets/images/objects/lagoon/onion.png',
    'assets/images/objects/lagoon/perfume_fish.png',
    'assets/images/objects/lagoon/socks.png',
  ];

  // 3 columns x 2 rows, left side of the screen (basket is on the right).
  static const List<Offset> _slots = [
    Offset(0.14, 0.34), Offset(0.31, 0.34), Offset(0.48, 0.34),
    Offset(0.14, 0.66), Offset(0.31, 0.66), Offset(0.48, 0.66),
  ];

  // ── Layout helpers ───────────────────────────────────────────────────
  double _foodSize(double sh) => sh * 0.26;
  double _basketW(double sh) => sh * 0.65;
  double _basketH(double sh) => sh * 0.50;

  Offset _basketCenter(double sw, double sh) =>
      Offset(sw - sw * 0.04 - _basketW(sh) / 2, sh * 0.78);

  bool get _canDrag => _currentPhase == GamePhase.playing && !_roundLocked;

  // ── Lifecycle ────────────────────────────────────────────────────────
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
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _audioPlayer.dispose();
    _kikiPlayer.dispose();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Flow ─────────────────────────────────────────────────────────────
  Future<void> _playIntroSequence() async {
    await playVoiceRestartingOnFaceLoss(
      _audioPlayer,
      'audio/discovery_lagoon/catching_intro.wav',
    );
    if (!mounted) return;
    await _startRound(TasteRound.sweet);
  }

  Future<void> _startRound(TasteRound round) async {
    setState(() {
      _foods = _buildFoods(round);
      _caughtCount = 0;
      _currentRound = round;
      _currentPhase = GamePhase.prompt;
      _roundLocked = true;
    });

    await playVoiceRestartingOnFaceLoss(_audioPlayer, _promptAudio[round]!);
    if (!mounted) return;

    setState(() {
      _currentPhase = GamePhase.playing;
      _roundLocked = false;
    });
    showHowToPlay = false;
    startIdleTimer();
  }

  List<FoodItem> _buildFoods(TasteRound round) {
    final targets = [..._foodsByTaste[round]!]..shuffle(_random);
    final distractors = [
      ..._wrongFoodImages,
      for (final e in _foodsByTaste.entries)
        if (e.key != round) ...e.value,
    ]..shuffle(_random);

    final picks = <(String, bool)>[
      for (final p in targets.take(_targetsPerRound)) (p, true),
      for (final p in distractors.take(_distractorsPerRound)) (p, false),
    ]..shuffle(_random);

    return [
      for (var i = 0; i < picks.length; i++)
        FoodItem(
          id: _nextFoodId++,
          imagePath: picks[i].$1,
          isTarget: picks[i].$2,
          cx: _slots[i].dx,
          cy: _slots[i].dy,
        ),
    ];
  }

  Future<void> _onFoodDropped(int id) async {
    if (!_canDrag) return;
    final index = _foods.indexWhere((f) => f.id == id);
    if (index < 0) return;
    final food = _foods[index];

    resetIdleTimer();

    if (!food.isTarget) {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showKikiReaction(KikiState.wrong);
      return; // food stays where it was
    }

    _tapTracker.recordCorrectTap();
    GamesSfxPlayer.instance.play(GameSfx.bubblePop);

    var roundDone = false;
    setState(() {
      _foods.removeAt(index);
      _caughtCount++;
      if (_caughtCount >= _targetsPerRound) {
        roundDone = true;
        _roundLocked = true;
      }
    });

    if (roundDone) {
      await _onRoundFinished();
    } else {
      showKikiReaction(KikiState.correct);
    }
  }

  Future<void> _onRoundFinished() async {
    cancelIdleTimer();
    showHowToPlay = false;

    await showKikiReaction(KikiState.correct);
    if (!mounted) return;

    final next = _currentRound.index + 1;
    if (next < TasteRound.values.length) {
      await _startRound(TasteRound.values[next]);
    } else {
      await _startFavoriteTastePhase();
    }
  }

  Future<void> _startFavoriteTastePhase() async {
    setState(() {
      _foods = [];
      _currentPhase = GamePhase.favoriteTaste;
      _canTapFavorite = false;
    });

    await playVoiceRestartingOnFaceLoss(
      _audioPlayer,
      'audio/discovery_lagoon/catching_fav_taste.wav',
    );
    if (!mounted) return;

    setState(() => _canTapFavorite = true);
    showHowToPlay = false;
    startIdleTimer();
  }

  Future<void> _onFavoriteTasteTapped() async {
    if (!_canTapFavorite || _currentPhase != GamePhase.favoriteTaste) return;
    cancelIdleTimer();

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

  void _restartGame() {
    cancelIdleTimer();
    setState(() {
      _foods = [];
      _caughtCount = 0;
      _roundLocked = true;
      _currentRound = TasteRound.sweet;
      _currentPhase = GamePhase.intro;
      _hasSavedResult = false;
      _tapTracker.startSession();
    });
    _playIntroSequence();
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final showPlayHint = showHowToPlay &&
        ((_currentPhase == GamePhase.playing && !_roundLocked) ||
            (_currentPhase == GamePhase.favoriteTaste && _canTapFavorite));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPhaseContent(sw, sh),

          if (_currentPhase != GamePhase.goodJob) ...[
            const Positioned(top: 25, left: 25, child: LagoonXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LagoonLevelBadge(level: widget.level),
            ),
          ],

          if (showPlayHint) Positioned.fill(child: _buildHowToPlayOverlay(sw, sh)),

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
    switch (_currentPhase) {
      case GamePhase.intro:
        return _buildIntro(sh);

      case GamePhase.prompt:
        return Image.asset(
          _tasteImages[_currentRound]!,
          width: sw,
          height: sh,
          fit: BoxFit.cover,
        );

      case GamePhase.favoriteTaste:
        return _buildFavoriteScene(sw, sh);

      case GamePhase.goodJob:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_bgPlaying, fit: BoxFit.cover),
            GoodJobOverlay(
              characterImage: 'assets/images/characters/cat_holding_fishbone.png',
              characterSizeFactor: 0.9,
              onNext: () {
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SeasonSceneTapScreen(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: _restartGame,
              onBack: () => Navigator.of(context).pop(),
            ),
          ],
        );

      case GamePhase.playing:
        return _buildPlayArea(sw, sh);
    }
  }

  Widget _buildIntro(double sh) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(_bgIntro, fit: BoxFit.cover),
        Positioned(
          bottom: -sh * 0.10,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(_kikiImage, height: sh * 0.90, fit: BoxFit.contain),
          ),
        ),
        Positioned(
          bottom: -sh * 0.15,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              _basketImage,
              width: sh * 0.75,
              height: sh * 0.55,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  // ── Playing: drag foods to the basket ────────────────────────────────
  Widget _buildPlayArea(double sw, double sh) {
    final size = _foodSize(sh);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(_bgPlaying, fit: BoxFit.cover),
        _buildBasket(sw, sh, isTarget: true),
        ..._foods.map((f) => _buildDraggableFood(f, sw, sh, size)),
      ],
    );
  }

  Widget _buildBasket(double sw, double sh, {required bool isTarget}) {
    final image = Image.asset(
      _basketImage,
      width: _basketW(sh),
      height: _basketH(sh),
      fit: BoxFit.contain,
    );

    return Positioned(
      right: sw * 0.04,
      bottom: -sh * 0.08,
      child: isTarget
          ? DragTarget<int>(
        onWillAcceptWithDetails: (_) => _canDrag,
        onAcceptWithDetails: (details) => _onFoodDropped(details.data),
        builder: (context, candidate, rejected) => AnimatedScale(
          scale: candidate.isNotEmpty ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: image,
        ),
      )
          : image,
    );
  }

  Widget _foodImage(FoodItem f, double size) => Image.asset(
    f.imagePath,
    width: size,
    height: size,
    fit: BoxFit.contain,
  );

  Widget _buildDraggableFood(FoodItem f, double sw, double sh, double size) {
    final child = _foodImage(f, size);

    return Positioned(
      key: ValueKey(f.id),
      left: f.cx * sw - size / 2,
      top: f.cy * sh - size / 2,
      child: Draggable<int>(
        data: f.id,
        maxSimultaneousDrags: _canDrag ? 1 : 0,
        onDragStarted: resetIdleTimer,
        feedback: Material(color: Colors.transparent, child: child),
        childWhenDragging: Opacity(opacity: 0.3, child: child),
        child: child,
      ),
    );
  }

  // ── Favorite taste ───────────────────────────────────────────────────
  Widget _buildFavoriteScene(double sw, double sh) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Image.asset(_bgPlaying, fit: BoxFit.cover),
        Positioned(
          bottom: -sh * 0.20,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(_kikiImage, height: sh * 1.15, fit: BoxFit.contain),
          ),
        ),
        Positioned(
          bottom: -sh * 0.12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFavoriteChoice('assets/images/objects/lagoon/chocolate.png', sh, sw),
              _buildFavoriteChoice('assets/images/objects/lagoon/lemon.png', sh, sw),
              _buildFavoriteChoice('assets/images/objects/lagoon/fries.png', sh, sw),
              _buildFavoriteChoice('assets/images/objects/lagoon/bittergourd.png', sh, sw),
            ],
          ),
        ),
      ],
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
          Image.asset(_basketImage, width: basketW, height: basketH, fit: BoxFit.contain),
          Positioned(
            bottom: screenHeight * 0.15,
            child: Image.asset(foodImagePath, width: foodS, height: foodS, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  // ── How to play ──────────────────────────────────────────────────────
  FoodItem? _pickHintFood() {
    for (final f in _foods) {
      if (f.isTarget) return f;
    }
    return null;
  }

  Widget _buildHowToPlayOverlay(double sw, double sh) {
    Alignment al(double cx, double cy) =>
        Alignment(2 * cx / sw - 1, 2 * cy / sh - 1);

    // Favorite taste: tap a basket
    if (_currentPhase == GamePhase.favoriteTaste) {
      return HowToPlayOverlay(
        previewChild: _buildFavoriteScene(sw, sh),
        handAlignment: al(sw * 0.38, sh * 0.83), // 2nd basket's food
        handOffset: const Offset(0.05, 0.46),
        onDismiss: resetIdleTimer,
      );
    }

    // Playing: drag a food of the current taste into the basket
    final hint = _pickHintFood();
    if (hint == null) return const SizedBox.shrink();

    final size = _foodSize(sh);
    final basket = _basketCenter(sw, sh);

    final preview = Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(_bgPlaying, fit: BoxFit.cover),
        _buildBasket(sw, sh, isTarget: false),
        ..._foods.map(
              (f) => Positioned(
            left: f.cx * sw - size / 2,
            top: f.cy * sh - size / 2,
            child: _foodImage(f, size),
          ),
        ),
      ],
    );

    return HowToPlayOverlay(
      previewChild: preview,
      handAlignment: al(hint.cx * sw, hint.cy * sh),
      handEndAlignment: al(basket.dx, basket.dy),
      handOffset: const Offset(0.05, 0.46),
      onDismiss: resetIdleTimer,
    );
  }
}