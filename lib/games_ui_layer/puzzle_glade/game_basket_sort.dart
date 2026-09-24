import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/puzzle_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'game_size_sort.dart';

enum _ScreenPhase { intro, game }

const _kAllObjects = [
  'compass',
  'jar',
  'lamp',
  'magnifying_glass',
  'map',
  'pen',
  'notebook',
  'puzzle_piece',
  'star',
  'telescope',
];

const int _kTotalRounds = 5;

class BasketSortScreen extends StatefulWidget {
  final int level;

  const BasketSortScreen({super.key, required this.level});

  @override
  State<BasketSortScreen> createState() => _BasketSortScreenState();
}

class _BasketSortScreenState extends State<BasketSortScreen>
    with
        TickerProviderStateMixin,
        RoxieReactionMixin<BasketSortScreen>,
        GameLoadingMixin,
        AiCameraMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/basket_sort_intro.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/basket_sort_instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/basket_sort_complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;

  late String _basketObjectA;
  late String _basketObjectB;
  String? _basketObjectC;

  late List<String> _itemQueue;
  int _currentItemIndex = 0;

  int _placedA = 0;
  int _placedB = 0;
  int _placedC = 0;

  int _countA = 2;
  int _countB = 2;
  int _countC = 0;

  int _basketCountForRound(int round) => round >= 4 ? 3 : 2;

  bool _flashA = false;
  bool _flashB = false;
  bool _flashC = false;

  bool _roundComplete = false;
  bool _showWinDialog = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  bool _itemHeld = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  AudioPlayer? _introPlayer;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _roxieFloatCtrl;
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _itemDanceCtrl;
  late Animation<double> _itemDance;
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _itemEnterCtrl;
  late Animation<double> _itemEnterAnim;
  late Animation<double> _itemEnterFade;

  late AnimationController _bounceACtrl;
  late Animation<double> _bounceAAnim;
  late AnimationController _bounceBCtrl;
  late Animation<double> _bounceBAnim;
  late AnimationController _bounceCCtrl;
  late Animation<double> _bounceCAnim;

  late AnimationController _completePulseCtrl;

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

    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  @override
  void dispose() {
    disposeAiCamera();
    try {
      _sfxPlayer.dispose();
    } catch (_) {}
    try {
      _completePlayer.dispose();
    } catch (_) {}
    try {
      _introPlayer?.dispose();
    } catch (_) {}
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _itemDanceCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _itemEnterCtrl.dispose();
    _bounceACtrl.dispose();
    _bounceBCtrl.dispose();
    _bounceCCtrl.dispose();
    _completePulseCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _initAnimations() {
    _roxieFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _roxieSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _roxieSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut),
        );
    _roxieFade = CurvedAnimation(
      parent: _roxieSlideCtrl,
      curve: const Interval(0, 0.4),
    );

    _itemDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _itemDance = Tween<double>(
      begin: -0.06,
      end: 0.06,
    ).animate(CurvedAnimation(parent: _itemDanceCtrl, curve: Curves.easeInOut));

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _itemEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _itemEnterAnim = Tween<double>(begin: -60, end: 0).animate(
      CurvedAnimation(parent: _itemEnterCtrl, curve: Curves.elasticOut),
    );
    _itemEnterFade = CurvedAnimation(
      parent: _itemEnterCtrl,
      curve: const Interval(0, 0.4),
    );

    _bounceACtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceAAnim = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _bounceACtrl, curve: Curves.elasticOut));
    _bounceCCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _bounceBCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceBAnim = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _bounceBCtrl, curve: Curves.elasticOut));
    _bounceCAnim = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _bounceCCtrl, curve: Curves.elasticOut));

    _completePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _roxieSlideCtrl.forward();

    await _playAudio(_audioIntro);
    if (!mounted) return;

    _gameEnterCtrl.forward();
    _startRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);

    await _playAudio(_audioInstructions);
  }

  Future<void> _playAudio(String asset) async {
    final player = AudioPlayer();
    _introPlayer = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      final completer = Completer<void>();
      final sub = player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 20));
      await sub.cancel();
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
      if (_introPlayer == player) _introPlayer = null;
    }
  }

  void _startRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);

    final basketCount = _basketCountForRound(_round);

    _basketObjectA = shuffled[0];
    _basketObjectB = shuffled[1];
    _basketObjectC = basketCount == 3 ? shuffled[2] : null;

    if (basketCount == 3) {
      _countA = rng.nextInt(3) + 2;
      _countB = rng.nextInt(3) + 2;
      _countC = rng.nextInt(3) + 2;

      _itemQueue = [
        ...List.generate(_countA, (_) => _basketObjectA),
        ...List.generate(_countB, (_) => _basketObjectB),
        ...List.generate(_countC, (_) => _basketObjectC!),
      ]..shuffle(rng);
    } else {
      _countA = rng.nextInt(3) + 1;
      _countB = 4 - _countA;
      _countC = 0;

      _itemQueue = [
        ...List.generate(_countA, (_) => _basketObjectA),
        ...List.generate(_countB, (_) => _basketObjectB),
      ]..shuffle(rng);
    }

    _currentItemIndex = 0;
    _placedA = 0;
    _placedB = 0;
    _placedC = 0;
    _flashA = false;
    _flashB = false;
    _flashC = false;
    _roundComplete = false;
    _itemHeld = false;

    _bounceACtrl.reset();
    _bounceBCtrl.reset();
    _bounceCCtrl.reset();
    _completePulseCtrl.stop();
    _completePulseCtrl.reset();
    _enterCtrl.forward(from: 0);

    _itemEnterCtrl.forward(from: 0);
  }

  Future<void> _dropOnBasket(String basketObject) async {
    if (_roundComplete) return;
    if (_currentItemIndex >= _itemQueue.length) return;

    final currentItem = _itemQueue[_currentItemIndex];
    final isCorrect = currentItem == basketObject;

    if (isCorrect) {
      _tapTracker.recordCorrectTap();
      _sfxPlayer
          .play(AssetSource(_audioWrong.replaceFirst('assets/', '')))
          .catchError((e) {
            debugPrint('SFX error: $e');
          });

      setState(() {
        if (basketObject == _basketObjectA) {
          _placedA++;
          _bounceACtrl.forward(from: 0);
        } else if (basketObject == _basketObjectB) {
          _placedB++;
          _bounceBCtrl.forward(from: 0);
        } else {
          _placedC++;
          _bounceCCtrl.forward(from: 0);
        }
        _currentItemIndex++;
        _itemHeld = false;
      });

      showRoxieReaction(RoxieState.correct);
      if (_currentItemIndex >= _itemQueue.length) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _roundComplete = true);
        _completePulseCtrl.repeat(reverse: true);
        _sfxPlayer
            .play(AssetSource(_audioSuccess.replaceFirst('assets/', '')))
            .catchError((e) {
              debugPrint('SFX error: $e');
            });
        await Future.delayed(const Duration(milliseconds: 1400));

        if (_round >= _kTotalRounds) {
          await _sfxPlayer.stop();

          final completer = Completer<void>();
          final sub = _completePlayer.onPlayerComplete.listen((_) {
            if (!completer.isCompleted) completer.complete();
          });
          await _completePlayer.play(
            AssetSource(_audioComplete.replaceFirst('assets/', '')),
          );
          await completer.future.timeout(const Duration(seconds: 10));
          await sub.cancel();

          PuzzleProgressService.instance
              .markLevelComplete(widget.level)
              .catchError((e) {
                debugPrint("Database Error marking level complete: $e");
              });

          await _saveDataAndShowWinDialog();
        } else {
          await _enterCtrl.reverse();
          if (mounted) {
            setState(() {
              _round++;
              _startRound();
            });
          }
        }
      } else {
        _itemEnterCtrl.forward(from: 0);
      }
    } else {
      _tapTracker.recordMistake();
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      setState(() {
        _itemHeld = false;
        if (basketObject == _basketObjectA) {
          _flashA = true;
        } else if (basketObject == _basketObjectB) {
          _flashB = true;
        } else {
          _flashC = true;
        }
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _flashA = false;
          _flashB = false;
          _flashC = false;
        });
      }

      await showRoxieReaction(RoxieState.wrong);
    }
  }

  Future<void> _saveDataAndShowWinDialog() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    PuzzleDatabaseService.saveGameData(
      gameId: 'puzzle_basket_sort',
      activityName: 'Basket Sort',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    if (mounted) {
      setState(() => _showWinDialog = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.puzzleGlade(),
        gameBuilder: () => Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  Image.asset(
                    _bgImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.15)),
                ],
              ),
            ),

            _screenPhase == _ScreenPhase.intro
                ? _buildIntroLayer()
                : Stack(
                    children: [
                      FadeTransition(
                        opacity: _gameFade,
                        child: _buildGameLayer(),
                      ),
                      buildRoxie(context),
                    ],
                  ),

            Positioned(top: 25, left: 25, child: PuzzleXButton()),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroLayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: PuzzleLevelBadge(level: widget.level),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildIntroRoxie()),
              Expanded(flex: 6, child: _buildIntroDancingItems()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroRoxie() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final roxieH = h * 0.95;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _roxieFloatCtrl, curve: Curves.easeInOut),
        );
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _roxieSlide,
              child: FadeTransition(
                opacity: _roxieFade,
                child: AnimatedBuilder(
                  animation: _roxieFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, floatY),
                    child: child,
                  ),
                  child: Image.asset(
                    _characterImage,
                    height: roxieH,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Text('🐰', style: TextStyle(fontSize: roxieH * 0.5)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroDancingItems() {
    final sampleObjects = ['star', 'compass', 'jar', 'telescope'];

    return AnimatedBuilder(
      animation: _itemDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: List.generate(sampleObjects.length, (i) {
              final angle = _itemDance.value * ((i % 2 == 0) ? 1 : -1);
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                        alpha: 0.25,
                      ),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/objects/puzzle/${sampleObjects[i]}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🧺', style: TextStyle(fontSize: 28)),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildGameLayer() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: PuzzleLevelBadge(level: widget.level),
                ),
              ],
            ),
          ),
          Expanded(child: _buildGameArea()),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: PuzzleProgressDots(
              currentRound: _round,
              totalRounds: _kTotalRounds,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    final basketCount = _basketCountForRound(_round);

    return LayoutBuilder(
      builder: (context, constraints) {
        final reservedWidth = basketCount == 3
            ? constraints.maxWidth * 0.13
            : 0.0;

        return Row(
          children: [
            if (reservedWidth > 0) SizedBox(width: reservedWidth),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildBasket(
                      objectName: _basketObjectA,
                      placedCount: _placedA,
                      targetCount: _countA,
                      isFlashing: _flashA,
                      bounceAnim: _bounceAAnim,
                      bounceCtrl: _bounceACtrl,
                    ),
                    const SizedBox(width: 12),
                    _buildCenterItem(),
                    const SizedBox(width: 12),
                    _buildBasket(
                      objectName: _basketObjectB,
                      placedCount: _placedB,
                      targetCount: _countB,
                      isFlashing: _flashB,
                      bounceAnim: _bounceBAnim,
                      bounceCtrl: _bounceBCtrl,
                    ),
                    if (basketCount == 3) ...[
                      const SizedBox(width: 12),
                      _buildBasket(
                        objectName: _basketObjectC!,
                        placedCount: _placedC,
                        targetCount: _countC,
                        isFlashing: _flashC,
                        bounceAnim: _bounceCAnim,
                        bounceCtrl: _bounceCCtrl,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCenterItem() {
    if (_currentItemIndex >= _itemQueue.length) {
      return const SizedBox(width: 80);
    }

    final currentObject = _itemQueue[_currentItemIndex];
    final remaining = _itemQueue.length - _currentItemIndex;

    final itemWidget = AnimatedBuilder(
      animation: _itemEnterCtrl,
      builder: (_, child) {
        return FadeTransition(
          opacity: _itemEnterFade,
          child: Transform.translate(
            offset: Offset(0, _itemEnterAnim.value),
            child: child,
          ),
        );
      },
      child: Draggable<String>(
        data: currentObject,
        onDragStarted: () => setState(() => _itemHeld = true),
        onDraggableCanceled: (_, __) => setState(() => _itemHeld = false),
        onDragCompleted: () => setState(() => _itemHeld = false),
        feedback: Material(
          color: Colors.transparent,
          child: _buildItemTile(currentObject, size: 82, isDragging: true),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: _buildItemTile(currentObject, size: 80),
        ),
        child: GestureDetector(
          onTap: () => setState(() => _itemHeld = !_itemHeld),
          child: _buildItemTile(currentObject, size: 80, isHeld: _itemHeld),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        itemWidget,
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$remaining left',
            style: TextStyle(
              fontFamily: PuzzleAppTextStyles.fredoka,
              fontSize: 14,
              color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                alpha: 0.65,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(
    String objectName, {
    double size = 80,
    bool isHeld = false,
    bool isDragging = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isHeld || isDragging
            ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isHeld || isDragging
              ? PuzzleColorTheme.sunnyhue
              : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
          width: isHeld || isDragging ? 3 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isHeld || isDragging
                ? PuzzleColorTheme.sunnyhue.withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: isHeld || isDragging ? 14 : 8,
            spreadRadius: isHeld || isDragging ? 2 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Image.asset(
        'assets/images/objects/puzzle/$objectName.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Text('🧺', style: TextStyle(fontSize: 28)),
      ),
    );
  }

  Widget _buildBasket({
    required String objectName,
    required int placedCount,
    required int targetCount,
    required bool isFlashing,
    required Animation<double> bounceAnim,
    required AnimationController bounceCtrl,
  }) {
    final hasItem = _currentItemIndex < _itemQueue.length && !_roundComplete;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _dropOnBasket(objectName),
      builder: (context, candidateData, _) {
        return GestureDetector(
          onTap: hasItem ? () => _dropOnBasket(objectName) : null,
          child: ScaleTransition(
            scale: bounceAnim,
            child: SizedBox(
              width: 220,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/objects/puzzle/basket.png',
                        width: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Text('🧺', style: TextStyle(fontSize: 40)),
                      ),
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: PuzzleColorTheme.darkdesaturatedblue
                                  .withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/images/objects/puzzle/$objectName.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('?', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ),
                      if (placedCount > 0)
                        Positioned(
                          bottom: 18,
                          child: _buildPlacedItems(objectName, placedCount),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlacedItems(String objectName, int count) {
    Widget item() => Image.asset(
      'assets/images/objects/puzzle/$objectName.png',
      width: 60,
      height: 60,
      fit: BoxFit.contain,
    );

    Widget row(int n) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(n, (_) => item()),
    );

    if (count <= 2) {
      return row(count);
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [row(count - 2), row(2)],
      );
    }
  }

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SizeSortScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        setState(() {
          _round = 1;
          _showWinDialog = false;
          _hasSavedResult = false;
          _tapTracker.startSession();
        });
        _startRound();
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
