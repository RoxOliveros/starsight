import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/Puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl19_memory_match3.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

enum _IntroPhase { playingIntro, playingWelcome, done }

class Lvl18JarColorSort2Screen extends StatefulWidget {
  const Lvl18JarColorSort2Screen({super.key});

  @override
  State<Lvl18JarColorSort2Screen> createState() =>
      _Lvl18JarColorSort2ScreenState();
}

class _Lvl18JarColorSort2ScreenState extends State<Lvl18JarColorSort2Screen>
    with TickerProviderStateMixin, RoxieReactionMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _audioIntro =
      'assets/audio/puzzle_glade/level1/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level1/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level1/instruction.wav';

  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _starImage = 'assets/images/objects/puzzle/star_bnw.png';
  static const String _jarImage = 'assets/images/objects/puzzle/jar_bnw.png';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioGameComplete =
      'assets/audio/puzzle_glade/level1/complete.wav';

  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const int _ballsPerColor = 3;

  static const _allPairs = [
    _JarPair(
      label: 'Red',
      jarColor: Color(0xFFFF6B6B),
      ballColor: Color(0xFFFF6B6B),
    ),
    _JarPair(
      label: 'Blue',
      jarColor: Color(0xFF1E88E5),
      ballColor: Color(0xFF1E88E5),
    ),
    _JarPair(
      label: 'Green',
      jarColor: Color(0xFF43A047),
      ballColor: Color(0xFF43A047),
    ),
    _JarPair(
      label: 'Yellow',
      jarColor: Color(0xFFFDD835),
      ballColor: Color(0xFFFDD835),
    ),
    _JarPair(
      label: 'Purple',
      jarColor: Color(0xFFCE93D8),
      ballColor: Color(0xFFCE93D8),
    ),
    _JarPair(
      label: 'Orange',
      jarColor: Color(0xFFFF9800),
      ballColor: Color(0xFFFF9800),
    ),
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
  List<_Ball> _jarCBalls = [];

  bool _wrongFlashA = false;
  bool _wrongFlashB = false;
  bool _wrongFlashC = false;

  bool _roundComplete = false;
  bool _showWinDialog = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _jarDanceCtrl;
  late Animation<double> _jarDance;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _celebCtrl;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
  }

  @override
  void dispose() {
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

  // ── Animation init ─────────────────────────────────────────────────────────
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

  // ── Intro flow ─────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();

    _setIntroPhase(_IntroPhase.playingIntro);
    _speechBubbleCtrl.forward(from: 0);
    await _playAudio(_audioIntro);

    _setIntroPhase(_IntroPhase.playingWelcome);
    _speechBubbleCtrl.forward(from: 0);
    await _playAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));

    // Transition to game
    _setIntroPhase(_IntroPhase.done);
    _gameEnterCtrl.forward();
    _startRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
    await _playAudio(_audioInstructions);
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

  void _setIntroPhase(_IntroPhase p) {
    if (!mounted) return;
  }

  // ── Round logic ────────────────────────────────────────────────────────────
  void _startRound() {
    final shuffled = List<_JarPair>.from(_allPairs)..shuffle(Random());
    _jarA = shuffled[0];
    _jarB = shuffled[1];
    _jarC = shuffled[2];

    final balls = [
      ...List.generate(_ballsPerColor, (_) => _Ball(jarIndex: 0, pair: _jarA)),
      ...List.generate(_ballsPerColor, (_) => _Ball(jarIndex: 1, pair: _jarB)),
      ...List.generate(_ballsPerColor, (_) => _Ball(jarIndex: 2, pair: _jarC)),
    ]..shuffle(Random());

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

      showRoxieReaction(RoxieState.correct);

      if (_jarABalls.length == _ballsPerColor &&
          _jarBBalls.length == _ballsPerColor &&
          _jarCBalls.length == _ballsPerColor) {
        _player.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));

        // small delay so success feels “acknowledged”
        await Future.delayed(const Duration(milliseconds: 300));

        setState(() => _roundComplete = true);
        _celebCtrl.forward(from: 0);

        // give time for celebration sound to land before transition
        await Future.delayed(const Duration(milliseconds: 1200));

        if (_round >= _totalRounds) {
          await Future.delayed(const Duration(milliseconds: 300));

          await _player.play(
            AssetSource(_audioGameComplete.replaceFirst('assets/', '')),
          );

          await PuzzleProgressService.instance.markLevelComplete(18);

          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            setState(() => _showWinDialog = true);
          }
        } else {
          setState(() {
            _round++;
            _startRound();
          });
        }
      }
    } else {
      showRoxieReaction(RoxieState.wrong);
      setState(() {
        if (jarIndex == 0) {
          _wrongFlashA = true;
        } else if (jarIndex == 1) {
          _wrongFlashB = true;
        } else {
          _wrongFlashC = true;
        }
      });
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
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

                // soft fade overlay
                Container(color: Colors.black.withValues(alpha: 0.15)),
              ],
            ),
          ),
          SafeArea(
            child: _screenPhase == _ScreenPhase.intro
                ? _buildIntroContent()
                : Stack(
                    children: [
                      FadeTransition(
                        opacity: _gameFade,
                        child: _buildGameContent(),
                      ),
                      buildRoxie(context),
                    ],
                  ),
          ),
          if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildIntroContent() {
    return Stack(
      children: [
        Positioned(top: 8, left: 12, child: PuzzleBackButton()),

        Positioned.fill(
          top: 48,
          child: Row(
            children: [
              // LEFT — Roxie sliding in
              Expanded(flex: 4, child: _buildIntroRoxie()),

              // RIGHT — Dancing jars showcase
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

  Widget _buildIntroDancingJars() {
    return AnimatedBuilder(
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
                    // Floating colored star only
                    Image.asset(
                      _starImage,
                      width: 58,
                      height: 58,
                      color: pair.ballColor,
                      colorBlendMode: BlendMode.modulate,
                      errorBuilder: (_, __, ___) =>
                          const Text('⭐', style: TextStyle(fontSize: 42)),
                    ),

                    const SizedBox(height: 6),

                    // Color name below
                    Text(
                      pair.label,
                      style: TextStyle(
                        fontFamily: JarAppTextStyles.fredoka,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: pair.jarColor,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGameContent() {
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildGameHeader(),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildBallPool()),
              Expanded(flex: 5, child: _buildJarsRow()),
            ],
          ),
        ),
        _buildProgressDots(),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildGameHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // LEFT
            Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),

            // CENTER TITLE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Star Color Sort',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: JarAppTextStyles.fredoka,
                      fontSize: 22,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBallPool() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: JarColorTheme.vandecane,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.55),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: JarColorTheme.goldenyellow.withValues(alpha: 0.20),
            blurRadius: 0,
            spreadRadius: 3,
            offset: Offset.zero,
          ),
        ],
      ),
      child: _poolBalls.isEmpty
          ? Center(
              child: Icon(
                Icons.star_rounded,
                size: 50,
                color: JarColorTheme.sunnyhue,
              ),
            )
          : Wrap(
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
    Widget starWidget(double size) => Image.asset(
      _starImage,
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
        feedback: Material(color: Colors.transparent, child: starWidget(62)),
        childWhenDragging: Opacity(opacity: 0.25, child: starWidget(54)),
        child: starWidget(54),
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
        _buildJarTarget(2, _jarC, _jarCBalls, _wrongFlashC),
      ],
    );
  }

  Widget _buildJarTarget(
    int jarIndex,
    _JarPair pair,
    List<_Ball> contents,
    bool wrongFlash,
  ) {
    final isFull = contents.length == _ballsPerColor;

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
              // Color label above jar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pair.jarColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  pair.label,
                  style: TextStyle(
                    fontFamily: JarAppTextStyles.fredoka,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: pair.jarColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isHovering ? 115 : 105,
                    height: isHovering ? 130 : 120,
                    child: Image.asset(
                      _jarImage,
                      fit: BoxFit.fill,
                      color: wrongFlash
                          ? JarColorTheme.goldenyellow.withValues(alpha: 0.6)
                          : pair.jarColor.withValues(alpha: 0.85),
                      colorBlendMode: BlendMode.modulate,
                    ),
                  ),
                  if (contents.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 0,
                        runSpacing: 2,
                        children: contents
                            .map(
                              (b) => Image.asset(
                                _starImage,
                                width: 26,
                                height: 26,
                                color: b.pair.ballColor,
                                colorBlendMode: BlendMode.modulate,
                              ),
                            )
                            .toList(),
                      ),
                    ),
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
                          fontFamily: JarAppTextStyles.fredoka,
                          fontSize: 13,
                          color: JarColorTheme.darkbrown,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // Full checkmark
                  if (isFull)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
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
                ? JarColorTheme.darkdesaturatedblue
                : current
                ? JarColorTheme.sunnyhue
                : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────
  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: JarColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.pop(context, const Lvl19JarMemoryMatch3Screen());
      },
      onRestart: () {
        Navigator.pop(context, const Lvl18JarColorSort2Screen());
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _JarPair {
  final String label;
  final Color jarColor;
  final Color ballColor;

  const _JarPair({
    required this.label,
    required this.jarColor,
    required this.ballColor,
  });
}

class _Ball {
  final int jarIndex;
  final _JarPair pair;

  _Ball({required this.jarIndex, required this.pair});
}
