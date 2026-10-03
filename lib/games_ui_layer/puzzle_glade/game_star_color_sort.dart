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
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/game_shadow_match.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';

enum _ScreenPhase { intro, game }

enum _IntroPhase { playingIntro, playingWelcome, done }

class StarColorSortScreen extends StatefulWidget {
  final int level;

  const StarColorSortScreen({super.key, required this.level});

  @override
  State<StarColorSortScreen> createState() => _StarColorSortScreenState();
}

class _StarColorSortScreenState extends State<StarColorSortScreen>
    with
        TickerProviderStateMixin,
        RoxieReactionMixin,
        GameLoadingMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<StarColorSortScreen> {
  @override
  AudioPlayer get roxiePlayer => _player;
  @override
  List<AudioPlayer> get lifecyclePlayers => [_player];

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _audioIntro =
      'assets/audio/puzzle_glade/star_sort_intro.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/star_sort_instruction.wav';
  static const String _audioGameComplete =
      'assets/audio/puzzle_glade/star_sort_complete.wav';

  static const String _audioCorrect =
      'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';

  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
  static const String _starImage = 'assets/images/objects/puzzle/star_bnw.png';
  static const String _jarImage = 'assets/images/objects/puzzle/jar_bnw.png';

  static final ImageProvider _starProvider = ResizeImage(
    const AssetImage(_starImage),
    width: 160,
  );
  static final ImageProvider _jarProvider = ResizeImage(
    const AssetImage(_jarImage),
    width: 240,
  );

  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  int _countA = 3;
  int _countB = 3;
  int _countC = 0;

  static const _allPairs = [
    _JarPair(jarColor: Color(0xFFFF6B6B), ballColor: Color(0xFFFF6B6B)),
    _JarPair(jarColor: Color(0xFF1E88E5), ballColor: Color(0xFF1E88E5)),
    _JarPair(jarColor: Color(0xFF43A047), ballColor: Color(0xFF43A047)),
    _JarPair(jarColor: Color(0xFFFDD835), ballColor: Color(0xFFFDD835)),
    _JarPair(jarColor: Color(0xFFCE93D8), ballColor: Color(0xFFCE93D8)),
    _JarPair(jarColor: Color(0xFFFF9800), ballColor: Color(0xFFFF9800)),
  ];

  // ── Phase state ────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;

  late _JarPair _jarA;
  late _JarPair _jarB;
  late _JarPair _jarC;
  late List<_Ball> _poolBalls;
  late List<_Ball> _jarABalls;
  late List<_Ball> _jarBBalls;
  late List<_Ball> _jarCBalls = [];

  bool _wrongFlashA = false;
  bool _wrongFlashB = false;
  bool _wrongFlashC = false;
  bool _roundComplete = false;
  bool _showWinDialog = false;
  bool _assetsReady = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _canDrag = false;
  bool _isTripleJar = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _roxieFloatCtrl;
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _jarDanceCtrl;
  late Animation<double> _jarDance;
  late AnimationController _speechBubbleCtrl;
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;
  late AnimationController _celebCtrl;

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
    _startRound();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _precacheAssets();
      if (!mounted) return;
      setState(() => _assetsReady = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      finishLoading(_startIntroFlow);
    });
  }

  @override
  void dispose() {
    disposeAiCamera();
    _player.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _jarDanceCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _celebCtrl.dispose();
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

    _jarDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _jarDance = Tween<double>(
      begin: -0.07,
      end: 0.07,
    ).animate(CurvedAnimation(parent: _jarDanceCtrl, curve: Curves.easeInOut));

    _speechBubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _roxieSlideCtrl.forward();

    _setIntroPhase(_IntroPhase.playingIntro);
    _speechBubbleCtrl.forward(from: 0);
    await _playAudio(_audioIntro);
    if (!mounted) return;

    _setIntroPhase(_IntroPhase.playingWelcome);
    _speechBubbleCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    _setIntroPhase(_IntroPhase.done);
    if (mounted) {
      setState(() {
        _screenPhase = _ScreenPhase.game;
      });
      _gameEnterCtrl.forward();
    }

    await _playAudio(_audioInstructions);
    if (!mounted) return;
    setState(() => _canDrag = true);
  }

  Future<void> _playAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> _precacheOne(ImageProvider p) => precacheImage(
    p,
    context,
    onError: (e, st) => debugPrint('Precache FAILED: $e'),
  );

  Future<void> _precacheAssets() async {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes = 300 << 20;
    cache.maximumSize = 200;

    await Future.wait([_starProvider, _jarProvider].map(_precacheOne));
    await Future.wait(
      [AssetImage(_characterImage), AssetImage(_bgImage)].map(_precacheOne),
    );

    await WidgetsBinding.instance.endOfFrame;
  }

  void _setIntroPhase(_IntroPhase p) {
    if (!mounted) return;
  }

  void _startRound() {
    final rng = Random();
    final shuffled = List<_JarPair>.from(_allPairs)..shuffle(rng);
    _isTripleJar = _round >= 4;
    _jarA = shuffled[0];
    _jarB = shuffled[1];

    if (_isTripleJar) {
      _jarC = shuffled[2];
      _countA = 2;
      _countB = 2;
      _countC = 2;
    } else {
      _countA = rng.nextInt(5) + 1;
      _countB = 6 - _countA;
      _countC = 0;
    }

    final balls = [
      ...List.generate(_countA, (_) => _Ball(jarIndex: 0, pair: _jarA)),
      ...List.generate(_countB, (_) => _Ball(jarIndex: 1, pair: _jarB)),
      if (_isTripleJar)
        ...List.generate(_countC, (_) => _Ball(jarIndex: 2, pair: _jarC)),
    ]..shuffle(rng);

    _poolBalls = balls;
    _jarABalls = [];
    _jarBBalls = [];
    _jarCBalls = [];
    _wrongFlashA = false;
    _wrongFlashB = false;
    _wrongFlashC = false;
    _roundComplete = false;
    _celebCtrl.reset();
  }

  Future<void> _onDroppedOnJar(int jarIndex, _Ball ball) async {
    if (_roundComplete) return;

    final correct = ball.jarIndex == jarIndex;

    if (correct) {
      _tapTracker.recordCorrectTap();
      setState(() {
        _poolBalls.remove(ball);
        if (jarIndex == 0) {
          _jarABalls.add(ball);
        } else if (jarIndex == 1) {
          _jarBBalls.add(ball);
        } else {
          _jarCBalls.add(ball);
        }
      });
      _player.play(AssetSource(_audioCorrect.replaceFirst('assets/', '')));
      showRoxieReaction(RoxieState.correct);

      final allFilled = _isTripleJar
          ? _jarABalls.length == _countA &&
                _jarBBalls.length == _countB &&
                _jarCBalls.length == _countC
          : _jarABalls.length == _countA && _jarBBalls.length == _countB;

      if (allFilled) {
        _player.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
        await Future.delayed(const Duration(milliseconds: 300));

        setState(() => _roundComplete = true);
        _celebCtrl.forward(from: 0);

        await Future.delayed(const Duration(milliseconds: 1200));

        if (_round >= _totalRounds) {
          await Future.delayed(const Duration(milliseconds: 300));
          await _playAudio(_audioGameComplete);
          await Future.delayed(const Duration(milliseconds: 800));

          await _saveDataAndShowWinDialog();
        } else {
          setState(() {
            _round++;
            _startRound();
          });
        }
      }
    } else {
      _tapTracker.recordMistake();
      setState(() {
        if (jarIndex == 0) {
          _wrongFlashA = true;
        } else if (jarIndex == 1) {
          _wrongFlashB = true;
        } else {
          _wrongFlashC = true;
        }
      });
      showRoxieReaction(RoxieState.wrong);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        setState(() {
          _wrongFlashA = false;
          _wrongFlashB = false;
          _wrongFlashC = false;
        });
      }
    }
  }

  Future<void> _saveDataAndShowWinDialog() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    PuzzleDatabaseService.saveGameData(
      gameId: 'puzzle_star_color_sort',
      activityName: 'Star Color Sort',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    PuzzleProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
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
                : FadeTransition(opacity: _gameFade, child: _buildGameLayer()),

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
              Expanded(flex: 6, child: _buildIntroDancingJars()),
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

  Widget _buildIntroDancingJars() {
    return AnimatedOpacity(
      opacity: _assetsReady ? 1 : 0.01,
      duration: const Duration(milliseconds: 200),
      child: AnimatedBuilder(
        animation: _jarDanceCtrl,
        builder: (_, __) {
          return Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 24,
              children: _allPairs.asMap().entries.map((entry) {
                final i = entry.key;
                final pair = entry.value;
                final angle = _jarDance.value * ((i % 2 == 0) ? 1 : -1);

                return Transform.rotate(
                  angle: angle,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image(
                        image: _starProvider,
                        width: 58,
                        height: 58,
                        color: pair.ballColor,
                        colorBlendMode: BlendMode.modulate,
                        errorBuilder: (_, __, ___) =>
                            const Text('⭐', style: TextStyle(fontSize: 42)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameLayer() {
    return Stack(
      children: [
        Column(
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
                  Expanded(flex: 4, child: _buildBallPool()),
                  Expanded(flex: 5, child: _buildJarsRow()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _buildProgressDots(),
            ),
          ],
        ),
        buildRoxie(context),
      ],
    );
  }

  Widget _buildBallPool() {
    if (_poolBalls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(150, 10, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: PuzzleColorTheme.vandecane,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.55),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: PuzzleColorTheme.goldenyellow.withValues(alpha: 0.20),
            blurRadius: 0,
            spreadRadius: 3,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: List.generate(
          _poolBalls.length,
          (i) => _buildDraggableBall(_poolBalls[i]),
        ),
      ),
    );
  }

  Widget _buildDraggableBall(_Ball ball) {
    Widget starWidget(double size) => Image(
      image: _starProvider,
      width: size,
      height: size,
      color: ball.pair.ballColor,
      colorBlendMode: BlendMode.modulate,
      errorBuilder: (_, __, ___) =>
          Text('⭐', style: TextStyle(fontSize: size * 0.7)),
    );

    return RepaintBoundary(
      child: Draggable<_Ball>(
        data: ball,
        maxSimultaneousDrags: _canDrag ? 1 : 0,
        feedback: Material(color: Colors.transparent, child: starWidget(62)),
        childWhenDragging: Opacity(opacity: 0.25, child: starWidget(54)),
        child: Opacity(opacity: _canDrag ? 1 : 0.6, child: starWidget(54)),
      ),
    );
  }

  Widget _buildJarsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildJarTarget(0, _jarA, _jarABalls, _wrongFlashA),
        _buildJarTarget(1, _jarB, _jarBBalls, _wrongFlashB),
        if (_isTripleJar) _buildJarTarget(2, _jarC, _jarCBalls, _wrongFlashC),
      ],
    );
  }

  Widget _buildJarTarget(
    int jarIndex,
    _JarPair pair,
    List<_Ball> contents,
    bool wrongFlash,
  ) {
    final isFull = jarIndex == 0
        ? contents.length == _countA
        : jarIndex == 1
        ? contents.length == _countB
        : contents.length == _countC;

    return RepaintBoundary(
      child: DragTarget<_Ball>(
        onWillAcceptWithDetails: (details) => !isFull,
        onAcceptWithDetails: (details) =>
            _onDroppedOnJar(jarIndex, details.data),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isHovering ? 115 : 105,
                    height: isHovering ? 130 : 120,
                    child: Image(
                      image: _jarProvider,
                      fit: BoxFit.fill,
                      color: wrongFlash
                          ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.6)
                          : pair.jarColor.withValues(alpha: 0.85),
                      colorBlendMode: BlendMode.modulate,
                    ),
                  ),
                  if (contents.isNotEmpty)
                    Positioned(bottom: 20, child: _buildStarsInJar(contents)),
                  if (isHovering && !isFull)
                    Positioned(
                      bottom: 20,
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        color: pair.jarColor,
                        size: 28,
                      ),
                    ),
                  if (wrongFlash)
                    Positioned(
                      bottom: 8,
                      child: Text(
                        'Oops! 💛',
                        style: TextStyle(
                          fontFamily: PuzzleAppTextStyles.fredoka,
                          fontSize: 13,
                          color: PuzzleColorTheme.darkbrown,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStarsInJar(List<_Ball> contents) {
    Widget star(_Ball b) => Image(
      image: _starProvider,
      width: 24,
      height: 24,
      color: b.pair.ballColor,
      colorBlendMode: BlendMode.modulate,
    );

    Widget row(List<_Ball> items) =>
        Row(mainAxisSize: MainAxisSize.min, children: items.map(star).toList());

    final count = contents.length;

    if (count <= 3) {
      return row(contents);
    } else if (count == 4) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [row(contents.sublist(0, 1)), row(contents.sublist(1, 4))],
      );
    } else {
      final topCount = count - 3;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(contents.sublist(0, topCount)),
          row(contents.sublist(topCount, count)),
        ],
      );
    }
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
                ? PuzzleColorTheme.darkdesaturatedblue
                : current
                ? PuzzleColorTheme.sunnyhue
                : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ShadowMatchScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StarColorSortScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

class _JarPair {
  final Color jarColor;
  final Color ballColor;

  const _JarPair({required this.jarColor, required this.ballColor});
}

class _Ball {
  final int jarIndex;
  final _JarPair pair;

  _Ball({required this.jarIndex, required this.pair});
}
