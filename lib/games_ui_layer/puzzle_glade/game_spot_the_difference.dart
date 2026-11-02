import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/puzzle_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/game_pattern_match.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';

enum _ScreenPhase { intro, playing }

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
const int _kGridSize = 4;

class _RoundData {
  final List<String> leftObjects;
  final List<String> rightObjects;
  final int diffIndex;

  const _RoundData({
    required this.leftObjects,
    required this.rightObjects,
    required this.diffIndex,
  });
}

class SpotDifferenceScreen extends StatefulWidget {
  final int level;

  const SpotDifferenceScreen({super.key, required this.level});

  @override
  State<SpotDifferenceScreen> createState() => _SpotDifferenceScreenState();
}

class _SpotDifferenceScreenState extends State<SpotDifferenceScreen>
    with
        TickerProviderStateMixin,
        RoxieReactionMixin,
        GameLoadingMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<SpotDifferenceScreen>,
        IdleHintMixin<SpotDifferenceScreen> {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _roxiePlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _roxiePlayer];

  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/spot_the_difference_intro.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/spot_the_difference_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/spot_the_difference_complete.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  _ScreenPhase _phase = _ScreenPhase.intro;
  int _round = 1;
  late _RoundData _currentRound;

  int? _highlightedCorrectIndex;

  bool _showWinDialog = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _inputEnabled = false;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _roxieFloatCtrl;
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;
  late AnimationController _roundEnterCtrl;
  late Animation<double> _roundFade;
  late AnimationController _correctGlowCtrl;

  late List<AnimationController> _cellShakeCtrl;
  late List<Animation<double>> _cellShakeAnim;

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
    disposeIdleTimer();
    _audioPlayer.dispose();
    _roxiePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _gameEnterCtrl.dispose();
    _roundEnterCtrl.dispose();
    _correctGlowCtrl.dispose();
    for (final c in _cellShakeCtrl) {
      c.dispose();
    }
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

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _roundEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _roundFade = CurvedAnimation(
      parent: _roundEnterCtrl,
      curve: Curves.easeOut,
    );

    _correctGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _cellShakeCtrl = List.generate(
      8,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _cellShakeAnim = _cellShakeCtrl
        .map(
          (c) => Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut)),
    )
        .toList();
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _roxieSlideCtrl.forward();
    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioIntro);
    if (!mounted) return;

    _gameEnterCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    _buildRound();
    setState(() => _phase = _ScreenPhase.playing);
    _roundEnterCtrl.forward(from: 0);
    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioInstructions);
    if (!mounted) return;
    setState(() => _inputEnabled = true);
    startIdleTimer();
  }

  void _buildRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);

    final base = shuffled.take(_kGridSize).toList();

    final diffIndex = rng.nextInt(_kGridSize);
    final replacement = shuffled
        .skip(_kGridSize)
        .firstWhere((o) => !base.contains(o), orElse: () => shuffled.last);

    final right = List<String>.from(base);
    right[diffIndex] = replacement;

    _currentRound = _RoundData(
      leftObjects: base,
      rightObjects: right,
      diffIndex: diffIndex,
    );

    _highlightedCorrectIndex = null;

    cancelIdleTimer();
    showHowToPlay = false;

    for (final c in _cellShakeCtrl) {
      c.reset();
    }
    _correctGlowCtrl.stop();
    _correctGlowCtrl.reset();
  }

  void _onCellTapped(int panel, int cellIndex) async {
    if (!_inputEnabled) return;
    if (_phase != _ScreenPhase.playing) return;
    if (_highlightedCorrectIndex != null) return;

    final isCorrect = cellIndex == _currentRound.diffIndex;

    if (isCorrect) {
      cancelIdleTimer();
      _tapTracker.recordCorrectTap();
      showRoxieReaction(RoxieState.correct);

      setState(() => _highlightedCorrectIndex = cellIndex);
      _correctGlowCtrl.repeat(reverse: true);

      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _correctGlowCtrl.stop();
      _correctGlowCtrl.reset();

      if (_round >= _kTotalRounds) {
        await _roxiePlayer.stop();
        await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioComplete);

        PuzzleProgressService.instance
            .markLevelComplete(widget.level)
            .catchError((e) {
          debugPrint("Database Error marking level complete: $e");
        });
        await _saveDataAndShowWinDialog();
      } else {
        await _roundEnterCtrl.reverse();
        if (!mounted) return;
        setState(() {
          _round++;
          _buildRound();
          _phase = _ScreenPhase.playing;
        });
        _roundEnterCtrl.forward(from: 0);
        startIdleTimer();
      }
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showRoxieReaction(RoxieState.wrong);

      final shakeIndex = panel * _kGridSize + cellIndex;
      _cellShakeCtrl[shakeIndex].forward(from: 0).then((_) {
        if (!mounted) return;
      });
    }
  }

  Future<void> _saveDataAndShowWinDialog() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    PuzzleDatabaseService.saveGameData(
      gameId: 'puzzle_spot_the_difference',
      activityName: 'Spot The Difference',
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

  // ── How to play helpers ────────────────────────────────────────────────────
  bool get _canShowHint =>
      _phase == _ScreenPhase.playing &&
          _inputEnabled &&
          _highlightedCorrectIndex == null &&
          !_showWinDialog;

  Widget _buildHowToPreview(Size s) {
    // Sample objects that are not used in the current round.
    final used = {..._currentRound.leftObjects, ..._currentRound.rightObjects};
    var pool = _kAllObjects.where((o) => !used.contains(o)).toList();
    if (pool.length < 5) pool = List<String>.from(_kAllObjects);

    return _SpotDemo(
      screen: s,
      bgImage: _bgImage,
      handAsset: 'assets/images/objects/lagoon/pointing_hand.png',
      base: pool.take(4).toList(),
      replacement: pool[4],
      handOffset: const Offset(0.15, 0.55),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Listener(
      onPointerDown: (_) {
        if (_canShowHint) resetIdleTimer();
      },
      child: Scaffold(
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
              _phase == _ScreenPhase.intro
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

              if (showHowToPlay && _canShowHint)
                Positioned.fill(
                  child: HowToPlayOverlay(
                    previewChild: _buildHowToPreview(screenSize),
                    handAlignment: Alignment.center,
                    showHand: false,
                    onDismiss: resetIdleTimer,
                  ),
                ),

              Positioned(top: 25, left: 25, child: PuzzleXButton()),

              if (hasCapturedFirstFrame &&
                  !isFaceDetected &&
                  !_hideLightingCard)
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
              Expanded(flex: 6, child: _buildIntroPreview()),
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
        return Align(
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
        );
      },
    );
  }

  Widget _buildIntroPreview() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPreviewPanel(showMark: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.search_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          _buildPreviewPanel(showMark: true),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel({required bool showMark}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                alpha: 0.3,
              ),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(2, (row) {
              return Row(
                children: List.generate(2, (col) {
                  final isMarkCell = showMark && row == 0 && col == 1;
                  return Container(
                    margin: const EdgeInsets.all(3),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isMarkCell
                          ? Colors.amber.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMarkCell
                            ? Colors.amber
                            : PuzzleColorTheme.darkdesaturatedblue.withValues(
                          alpha: 0.2,
                        ),
                        width: isMarkCell ? 2 : 1,
                      ),
                    ),
                    child: isMarkCell
                        ? const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 22,
                    )
                        : Icon(
                      Icons.image_outlined,
                      color: PuzzleColorTheme.darkdesaturatedblue
                          .withValues(alpha: 0.3),
                      size: 20,
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildGameLayer() {
    return FadeTransition(
      opacity: _roundFade,
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
          Expanded(
            child: AnimatedOpacity(
              opacity: _inputEnabled ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 300),
              child: Row(children: [Expanded(child: _buildMainArea())]),
            ),
          ),
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

  Widget _buildMainArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPanel(panelIndex: 0, objects: _currentRound.leftObjects),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 28,
                  ),
                ],
              ),
            ),
            _buildPanel(panelIndex: 1, objects: _currentRound.rightObjects),
          ],
        ),
      ],
    );
  }

  Widget _buildPanel({required int panelIndex, required List<String> objects}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(2, (row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(2, (col) {
              final cellIndex = row * 2 + col;
              return _buildCell(
                panelIndex: panelIndex,
                cellIndex: cellIndex,
                objectName: objects[cellIndex],
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildCell({
    required int panelIndex,
    required int cellIndex,
    required String objectName,
  }) {
    final isTheDiff = cellIndex == _currentRound.diffIndex;
    final isHighlighted = _highlightedCorrectIndex != null && isTheDiff;

    final shakeIndex = panelIndex * _kGridSize + cellIndex;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _cellShakeAnim[shakeIndex],
        _correctGlowCtrl,
      ]),
      builder: (_, child) {
        final shake = sin(_cellShakeAnim[shakeIndex].value * pi * 6) * 6;
        final glowValue = isHighlighted ? _correctGlowCtrl.value : 0.0;

        return Transform.translate(
          offset: Offset(shake, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(5),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Color.lerp(
                Colors.green.withValues(alpha: 0.25),
                Colors.green.withValues(alpha: 0.55),
                glowValue,
              )
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHighlighted
                    ? Colors.green
                    : PuzzleColorTheme.darkdesaturatedblue.withValues(
                  alpha: 0.25,
                ),
                width: isHighlighted ? 3 : 2,
              ),
              boxShadow: isHighlighted
                  ? [
                BoxShadow(
                  color: Colors.green.withValues(
                    alpha: 0.3 + glowValue * 0.3,
                  ),
                  blurRadius: 10 + glowValue * 8,
                  spreadRadius: 2,
                ),
              ]
                  : [],
            ),
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _onCellTapped(panelIndex, cellIndex),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/objects/puzzle/$objectName.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                objectName[0].toUpperCase(),
                style: TextStyle(
                  fontFamily: PuzzleAppTextStyles.fredoka,
                  fontSize: 28,
                  color: PuzzleColorTheme.darkdesaturatedblue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,

      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PatternMatchScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SpotDifferenceScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ── How to play demo ─────────────────────────────────────────────────────────
// Standalone looping animation: two sample panels, one item differs. The hand
// moves to the different item on the right panel, taps it, and it lights up.

class _SpotDemo extends StatefulWidget {
  final Size screen;
  final String bgImage;
  final String handAsset;
  final List<String> base; // 4 sample objects for the left panel
  final String replacement; // replaces one object on the right panel
  final Offset handOffset;

  const _SpotDemo({
    required this.screen,
    required this.bgImage,
    required this.handAsset,
    required this.base,
    required this.replacement,
    this.handOffset = const Offset(0.15, 0.46),
  });

  @override
  State<_SpotDemo> createState() => _SpotDemoState();
}

class _SpotDemoState extends State<_SpotDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const double _handW = 100;
  static const int _diffIndex = 1; // top-right cell of the right panel

  // Real layout sizes: cell 88 + margin 5*2 = 98, panel padding 8, border 2.
  static const double _cell = 98;
  static const double _panelSize = _cell * 2 + 16 + 4; // 216
  static const double _gap = 14 * 2 + 28; // 56

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _demoCell(String object, {required double glow}) {
    final lit = glow > 0;
    return Container(
      margin: const EdgeInsets.all(5),
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: lit
            ? Colors.green.withValues(alpha: 0.25 + 0.3 * glow)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lit
              ? Colors.green
              : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.25),
          width: lit ? 3 : 2,
        ),
        boxShadow: lit
            ? [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3 + glow * 0.3),
            blurRadius: 10 + glow * 8,
            spreadRadius: 2,
          ),
        ]
            : [],
      ),
      padding: const EdgeInsets.all(10),
      child: Image.asset(
        'assets/images/objects/puzzle/$object.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(),
      ),
    );
  }

  Widget _demoPanel(List<String> objects, {required double glow}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(2, (row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(2, (col) {
              final i = row * 2 + col;
              return _demoCell(
                objects[i],
                glow: (glow > 0 && i == _diffIndex) ? glow : 0.0,
              );
            }),
          );
        }),
      ),
    );
  }

  double _press(double t, double a, double b) {
    if (t < a || t > b) return 0.0;
    final m = (t - a) / (b - a);
    return m < 0.5 ? m * 2 : (1 - m) * 2;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.screen;

    final left = List<String>.from(widget.base);
    final right = List<String>.from(widget.base);
    right[_diffIndex] = widget.replacement;

    // The panels row is centered on the screen. The right panel's center is
    // half a panel plus half the gap to the right of center.
    final cx = s.width / 2;
    final cy = s.height / 2;
    final rightPanelCx = cx + _gap / 2 + _panelSize / 2;
    final target = Offset(rightPanelCx + _cell / 2, cy - _cell / 2);
    final start = target + const Offset(130, 120);

    return SizedBox(
      width: s.width,
      height: s.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;

          // Hand: appear, move to the different item, tap, hold, fade.
          final approach = Curves.easeOut.transform(
            ((t - 0.12) / 0.26).clamp(0.0, 1.0),
          );
          final pos = Offset.lerp(start, target, approach)!;

          final tapV = _press(t, 0.40, 0.52);
          final handOpacity = t < 0.10
              ? 0.0
              : t < 0.18
              ? (t - 0.10) / 0.08
              : t < 0.88
              ? 1.0
              : t < 0.95
              ? 1.0 - (t - 0.88) / 0.07
              : 0.0;

          // Highlight after the tap, pulsing a little.
          final litWindow = t >= 0.46 && t < 0.93;
          final glow = litWindow
              ? 0.5 + 0.5 * sin((t - 0.46) * pi * 10)
              : 0.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(widget.bgImage, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.15)),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _demoPanel(left, glow: 0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(
                        Icons.compare_arrows_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 28,
                      ),
                    ),
                    _demoPanel(right, glow: glow.clamp(0.0, 1.0)),
                  ],
                ),
              ),
              Positioned(
                left: pos.dx - _handW / 2 + widget.handOffset.dx * _handW,
                top:
                pos.dy -
                    _handW / 2 +
                    widget.handOffset.dy * _handW -
                    tapV * 20,
                width: _handW,
                height: _handW,
                child: Opacity(
                  opacity: handOpacity,
                  child: Transform.scale(
                    scale: 1.0 - tapV * 0.08,
                    child: Image.asset(widget.handAsset, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}