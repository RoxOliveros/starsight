import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'game_345_odd_one_out.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

enum _ScreenPhase { intro, miniGame }

class Number345CountingObjectsScreen extends StatefulWidget {
  final int level;

  const Number345CountingObjectsScreen({super.key, required this.level});

  @override
  State<Number345CountingObjectsScreen> createState() =>
      _Number345CountingObjectsScreenState();
}

class _Number345CountingObjectsScreenState
    extends State<Number345CountingObjectsScreen>
    with
        TickerProviderStateMixin,
        DomaReactionMixin,
        GameLoadingMixin,
        AiCameraMixin<Number345CountingObjectsScreen>,
        AppAudioLifecycleMixin<Number345CountingObjectsScreen>,
        IdleHintMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _domaPlayer= AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _domaPlayer];

  @override
  AudioPlayer get domaPlayer => _domaPlayer;

  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const List<int> _numbers = [3, 4, 5];

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/level14/intro.wav';

  // ── How-to-play sample (fixed): 3 objects → tap "3" ────────────────────────
  static const String _hintObjectAsset = 'assets/images/objects/arctic/snowball.png';
  static const List<int> _hintChoices = [5, 3, 4];

  final GameTapTracker _tapTracker = GameTapTracker();

  bool _hideLightingCard = false;
  bool _loadingScreenElapsed = false;
  Timer? _minLoadTimer;

  // ── Objects pool (all arctic_numberland assets) ─────────────────────────────
  static const List<Map<String, String>> _objects = [
    {
      'name': 'Candy Cane',
      'asset': 'assets/images/objects/arctic/candy_cane.png',
    },
    {'name': 'Earmuffs', 'asset': 'assets/images/objects/arctic/earmuffs.png'},
    {'name': 'Ice', 'asset': 'assets/images/objects/arctic/ice.png'},
    {
      'name': 'Ice Skates',
      'asset': 'assets/images/objects/arctic/ice_skates.png',
    },
    {'name': 'Ice Cream', 'asset': 'assets/images/objects/arctic/icecream.png'},
    {'name': 'Igloo', 'asset': 'assets/images/objects/arctic/igloo.png'},
    {'name': 'Sled', 'asset': 'assets/images/objects/arctic/sled.png'},
    {'name': 'Snowball', 'asset': 'assets/images/objects/arctic/snowball.png'},
    {
      'name': 'Snow Globe',
      'asset': 'assets/images/objects/arctic/snowglobe.png',
    },
    {'name': 'Snowman', 'asset': 'assets/images/objects/arctic/snowman.png'},
    {
      'name': 'Snowy Sign',
      'asset': 'assets/images/objects/arctic/snowy_signboard.png',
    },
    {
      'name': 'Snowy Tree',
      'asset': 'assets/images/objects/arctic/snowy_tree.png',
    },
    {
      'name': 'Winter Hat',
      'asset': 'assets/images/objects/arctic/winter_hat.png',
    },
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  bool _showWinDialog = false;

  int _round = 1;
  late int _correctCount;
  late List<int> _choices;
  late String _currentObjectAsset;
  int? _tappedIndex;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  late AnimationController _domaFloatCtrl;

  late AnimationController _objectsEnterCtrl;
  late Animation<double> _objectsEnter;

  late AnimationController _choicesEnterCtrl;
  late Animation<double> _choicesEnter;

  late AnimationController _correctPulseCtrl;
  late Animation<double> _correctPulse;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _generateRound();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    _minLoadTimer = Timer(minLoadTime, () {
      if (mounted) setState(() => _loadingScreenElapsed = true);
    });

    if (widget.level == 1) {
      onFirstFaceDetected = () {
        finishLoading(_startIntroFlow);
      };
      if (isFaceDetected) {
        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;
      }
    } else {
      finishLoading(_startIntroFlow);
    }

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) {
        setState(() => _hideLightingCard = false);
      }
    };
  }

  void _initAnimations() {
    // Intro: numbers dance
    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    // Doma floating
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Objects display box entrance
    _objectsEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _objectsEnter = CurvedAnimation(
      parent: _objectsEnterCtrl,
      curve: Curves.elasticOut,
    );

    // Choices entrance
    _choicesEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _choicesEnter = CurvedAnimation(
      parent: _choicesEnterCtrl,
      curve: Curves.easeOutBack,
    );

    // Correct answer pulse
    _correctPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _correctPulse =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _correctPulseCtrl, curve: Curves.easeOut),
        );
  }

  // ── Round Logic ─────────────────────────────────────────────────────────────
  void _generateRound() {
    final rng = Random();

    _correctCount = _numbers[rng.nextInt(_numbers.length)];

    final others = _numbers.where((n) => n != _correctCount).toList()
      ..shuffle(rng);
    final wrongChoices = [...others];

    _choices = [...wrongChoices.take(2), _correctCount]..shuffle(rng);

    // Pick a random object
    final obj = List.from(_objects)..shuffle(rng);
    _currentObjectAsset = (obj.first as Map<String, String>)['asset']!;

    _tappedIndex = null;
  }

  // ── Flow ───────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioIntro);
    if (!mounted) return;
    setState(() => _screenPhase = _ScreenPhase.miniGame);
    _animateRoundIn();
    startIdleTimer();
  }

  void _animateRoundIn() {
    _objectsEnterCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _choicesEnterCtrl.forward(from: 0);
    });
  }

  Future<void> _onChoiceTap(int index) async {
    if (_tappedIndex != null) return;
    cancelIdleTimer();
    setState(() => _tappedIndex = index);

    final isCorrect = _choices[index] == _correctCount;

    if (isCorrect) {
      _tapTracker.recordCorrectTap();

      _correctPulseCtrl.forward(from: 0);
      showDomaReaction(DomaState.correct);
      await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/arctic_numberland/$_correctCount.wav');

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      if (_round >= _totalRounds) {
        // --- ADDED AI STOP & DATABASE SAVE ---
        List<String> finalEmotions = stopAiCamera();

        ArcticDatabaseService.saveGameData(
          gameId: 'arctic_numberland_${widget.level}',
          mistakes: _tapTracker.mistakeCount,
          emotions: finalEmotions,
        ).catchError((e) {
          debugPrint("Database Error saving metrics: $e");
        });

        await ArcticProgressService.instance
            .markLevelComplete(widget.level)
            .catchError((e) {
          debugPrint("Database Error marking level complete: $e");
        });
        cancelIdleTimer();
        setState(() => _showWinDialog = true);
      } else {
        setState(() {
          _round++;
          _generateRound();
        });
        _animateRoundIn();
        showHowToPlay = false;
        startIdleTimer();
      }
    } else {
      _tapTracker.recordMistake();

      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showDomaReaction(DomaState.wrong);
      if (!mounted) return;
      setState(() => _tappedIndex = null);
      startIdleTimer();
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _minLoadTimer?.cancel();
    _audioPlayer.dispose();
    _domaPlayer.dispose();
    _numberDanceCtrl.dispose();
    _domaFloatCtrl.dispose();
    _objectsEnterCtrl.dispose();
    _choicesEnterCtrl.dispose();
    _correctPulseCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Choice Colors ──────────────────────────────────────────────────────────
  Color _choiceColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.pictonblue;
    return ArcticColorTheme.pictonblue;
  }

  Color _choiceBorderColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.slateblue;
    if (_choices[index] == _correctCount) return ArcticColorTheme.pictonblue;
    return ArcticColorTheme.slateblue;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final gateNeedsLightingPrompt = widget.level == 1 && !isFaceDetected;

    final reactiveNeedsLightingPrompt =
        hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard;

    Widget gateLightingCard() => LightingPromptCard(
      onClose: () {
        setState(() => isFaceDetected = true);
        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;
      },
    );

    Widget reactiveLightingCard() => LightingPromptCard(
      onClose: () => setState(() => _hideLightingCard = true),
    );

    final gameContent = Stack(
      children: [
        // Background
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),

        if (_screenPhase == _ScreenPhase.intro)
          _buildIntroLayer()
        else
          _buildGameContent(),

        if (showHowToPlay &&
            _screenPhase == _ScreenPhase.miniGame &&
            _tappedIndex == null &&
            !_showWinDialog)
          Positioned.fill(child: _buildHowToPlayOverlay()),

        if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
      ],
    );

    final contentWithOverlay = reactiveNeedsLightingPrompt
        ? Stack(
      children: [
        Positioned.fill(child: gameContent),
        Positioned.fill(child: reactiveLightingCard()),
      ],
    )
        : gameContent;

    final loadingSlot = (_loadingScreenElapsed && gateNeedsLightingPrompt)
        ? gateLightingCard()
        : LoadingScreen.arctic();

    return Listener(
      onPointerDown: (_) {
        _tapTracker.recordGenericTap();
        if (_screenPhase == _ScreenPhase.miniGame && _tappedIndex == null) {
          resetIdleTimer();
        }
      },
      child: Scaffold(
        body: buildWithLoading(
          loadingScreen: loadingSlot,
          gameBuilder: () => gateNeedsLightingPrompt
              ? Stack(
            children: [
              Positioned.fill(child: gameContent),
              Positioned.fill(child: gateLightingCard()),
            ],
          )
              : contentWithOverlay,
        ),
      ),
    );
  }

  // ── How to play (fixed sample: 3 objects, tap the "3") ────────────────────
  Widget _buildHowToPlayOverlay() {
    final sz = MediaQuery.of(context).size;
    final sw = sz.width, sh = sz.height;

    // objects box
    final boxW = sw * 0.52, boxH = sh * 0.58;
    final boxLeft = sw * 0.06, boxTop = sh * 0.22;
    final objSize = min(boxW / 3 - 24, boxH * 0.6);

    // choices (2 columns, same 1.4 ratio as the real cards)
    const gap = 12.0;
    final cardW = sw * 0.14;
    final cardH = cardW / 1.4;
    final gridW = cardW * 2 + gap;
    final gridH = cardH * 2 + gap;
    final gridLeft = sw * 0.66;
    final gridTop = (sh - gridH) / 2;

    // "3" is the second card (top right)
    final tapX = gridLeft + cardW + gap + cardW / 2;
    final tapY = gridTop + cardH / 2;

    final preview = Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(_bgImage, fit: BoxFit.cover),
        Positioned(
          left: boxLeft,
          top: boxTop,
          width: boxW,
          height: boxH,
          child: Container(
            decoration: BoxDecoration(
              color: ArcticColorTheme.cotton,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ArcticColorTheme.pictonblue, width: 4),
              boxShadow: [
                BoxShadow(
                  color: ArcticColorTheme.pictonblue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                      (_) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Image.asset(
                      _hintObjectAsset,
                      width: objSize,
                      height: objSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: gridLeft,
          top: gridTop,
          width: gridW,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: _hintChoices
                .map((n) => _hintNumberCard(n, cardW, cardH))
                .toList(),
          ),
        ),
      ],
    );

    return HowToPlayOverlay(
      previewChild: preview,
      handAlignment: Alignment(2 * tapX / sw - 1, 2 * tapY / sh - 1),
      handOffset: const Offset(0.15, 0.65),
      onDismiss: resetIdleTimer,
    );
  }

  Widget _hintNumberCard(int number, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: ArcticColorTheme.pictonblue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ArcticColorTheme.slateblue, width: 3),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(h * 0.12),
        child: Image.asset(
          'assets/fonts/game_numbers/$number.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$number',
              style: const TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: ArcticColorTheme.cotton,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Intro ──────────────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(top: 20, left: 20, child: ArcticXButton()),
          Positioned(
            top: 20,
            right: 20,
            child: ArcticLevelBadge(level: widget.level),
          ),
          Positioned.fill(
            top: 50,
            child: Row(
              children: [
                // Doma – scales down to whatever space is available
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Image.asset(
                        _characterImage,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                        const Text('🐧', style: TextStyle(fontSize: 60)),
                      ),
                    ),
                  ),
                ),
                // Dancing numbers – FittedBox guarantees no horizontal overflow
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedBuilder(
                        animation: _numberDanceCtrl,
                        builder: (_, __) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (i) {
                              final angle =
                                  _numberDance.value * ((i % 2 == 0) ? 1 : -1);
                              return Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                                child: Transform.rotate(
                                  angle: angle,
                                  child: _buildIntroNumberCard(i),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Game Content ───────────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return Column(
        children: [
          // ── HEADER ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ArcticXButton(),
                ArcticLevelBadge(level: widget.level),
              ],
            ),
          ),

          // ── MAIN ROW ────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: ScaleTransition(
                      scale: _objectsEnter,
                      child: _buildObjectsBox(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ScaleTransition(
                      scale: _choicesEnter,
                      child: _buildChoicesGrid(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── PROGRESS DOTS ───────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildProgressDots(),
          ),
        ],
    );
  }

  Widget _buildObjectsBox() {
    return Container(
      decoration: BoxDecoration(
        color: ArcticColorTheme.cotton,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ArcticColorTheme.pictonblue, width: 4),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _buildObjectGrid(),
      ),
    );
  }

  /// Finds the largest square size at which [count] items fit inside
  /// [maxW] x [maxH] (trying every possible column count).
  double _bestFitSize(int count, double maxW, double maxH, double spacing) {
    double best = 0;
    for (int cols = 1; cols <= count; cols++) {
      final rows = (count / cols).ceil();
      final byW = (maxW - spacing * (cols - 1)) / cols;
      final byH = (maxH - spacing * (rows - 1)) / rows;
      best = max(best, min(byW, byH));
    }
    return max(best, 0);
  }

  Widget _buildObjectGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final objSize = _bestFitSize(
          _correctCount,
          constraints.maxWidth,
          constraints.maxHeight,
          spacing,
        ).clamp(0.0, 140.0).toDouble();

        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(_correctCount, (i) {
              return Image.asset(
                _currentObjectAsset,
                width: objSize,
                height: objSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  '❄️',
                  style: TextStyle(fontSize: objSize * 0.6),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildChoicesGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        const ratio = 1.4; // width / height of each card

        // 2 columns x 2 rows must fit in BOTH width and height
        final byWidth = (constraints.maxWidth - gap) / 2;
        final byHeight = ((constraints.maxHeight - gap) / 2) * ratio;
        final cardW = max(0.0, min(byWidth, byHeight)).clamp(0.0, 200.0).toDouble();
        final cardH = cardW / ratio;

        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: List.generate(_choices.length, (index) {
              final isCorrect = _choices[index] == _correctCount;
              final isTappedCorrect = _tappedIndex == index && isCorrect;

              return SizedBox(
                width: cardW,
                height: cardH,
                child: GestureDetector(
                  onTap: () => _onChoiceTap(index),
                  child: ScaleTransition(
                    scale: isTappedCorrect
                        ? _correctPulse
                        : const AlwaysStoppedAnimation(1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: _choiceColor(index),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _choiceBorderColor(index),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                            _choiceColor(index).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(cardH * 0.12),
                        child: Image.asset(
                          'assets/fonts/game_numbers/${_choices[index]}.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${_choices[index]}',
                              style: const TextStyle(
                                fontFamily: ArcticAppTextStyles.fredoka,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: ArcticColorTheme.cotton,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildIntroNumberCard(int i) {
    final number = _numbers[i]; // 3, 4, 5
    final size = MediaQuery.of(context).size.height * 0.28;
    const words = ['THREE', 'FOUR', 'FIVE'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Image.asset(
              'assets/fonts/game_numbers/$number.png',
              width: size * 0.64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                '$number',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          words[i],
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : current
                ? ArcticColorTheme.slateblue
                : ArcticColorTheme.slateblue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Number345OddOneOutScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Number345CountingObjectsScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}