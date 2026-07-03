import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/ai_summary_service.dart';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/generating_summary_card.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl2_pattern_match.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

enum _IntroPhase { playingIntro, playingWelcome, done }

class Lvl1JarColorSortScreen extends StatefulWidget {
  const Lvl1JarColorSortScreen({super.key});

  @override
  State<Lvl1JarColorSortScreen> createState() => _Lvl1JarColorSortScreenState();
}

class _Lvl1JarColorSortScreenState extends State<Lvl1JarColorSortScreen>
    with TickerProviderStateMixin, RoxieReactionMixin, AiCameraMixin {
  //wag tong AiCameraMixin tin
  // Required by the mixin — point it to your existing _player
  @override
  AudioPlayer get roxiePlayer => _player;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _audioIntro =
      'assets/audio/puzzle_glade/level1/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level1/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level1/instruction.wav';
  static const String _audioCorrect =
      'assets/audio/sound_effects/bubble_pop.wav';

  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _starImage = 'assets/images/objects/puzzle/star_bnw.png';
  static const String _jarImage = 'assets/images/objects/puzzle/jar_bnw.png';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioGameComplete =
      'assets/audio/puzzle_glade/level1/complete.wav';

  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  int _countA = 3;
  int _countB = 3;

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
  late List<_Ball> _poolBalls;
  late List<_Ball> _jarABalls;
  late List<_Ball> _jarBBalls;
  DateTime? _gameStartTime;
  int _mistakeCount = 0;
  bool _hideLightingPrompt = false;
  bool _wrongFlashA = false;
  bool _wrongFlashB = false;
  bool _roundComplete = false;
  bool _showWinDialog = false;
  bool _isGeneratingSummary = false;

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
    _startRound();
    startAiCamera(); //wag to tin
    _startIntroFlow();
  }

  @override
  void dispose() {
    disposeAiCamera(); // Eto pa tin
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
    if (!mounted) return; // <-- add
    _roxieSlideCtrl.forward();

    _setIntroPhase(_IntroPhase.playingIntro);
    _speechBubbleCtrl.forward(from: 0);
    await _playAudio(_audioIntro);
    if (!mounted) return; // <-- add

    _setIntroPhase(_IntroPhase.playingWelcome);
    _speechBubbleCtrl.forward(from: 0);
    await _playAudio(_audioWelcome);
    if (!mounted) return; // <-- add

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return; // <-- add

    // Transition to game
    _setIntroPhase(_IntroPhase.done);
    if (mounted) {
      setState(() {
        _screenPhase = _ScreenPhase.game;
        _gameStartTime = DateTime.now();
      });
      _gameEnterCtrl.forward(); // <-- add this
    }

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
    final rng = Random();
    final shuffled = List<_JarPair>.from(_allPairs)..shuffle(rng);
    _jarA = shuffled[0];
    _jarB = shuffled[1];

    _countA = rng.nextInt(5) + 1;
    _countB = 6 - _countA;

    final balls = [
      ...List.generate(_countA, (_) => _Ball(jarIndex: 0, pair: _jarA)),
      ...List.generate(_countB, (_) => _Ball(jarIndex: 1, pair: _jarB)),
    ]..shuffle(rng);

    _poolBalls = balls;
    _jarABalls = [];
    _jarBBalls = [];
    _wrongFlashA = false;
    _wrongFlashB = false;
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
        } else {
          _jarBBalls.add(ball);
        }
      });
      _player.play(AssetSource(_audioCorrect.replaceFirst('assets/', '')));
      showRoxieReaction(RoxieState.correct);

      if (_jarABalls.length == _countA && _jarBBalls.length == _countB) {
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
          //Wag To
          setState(() {
            _isGeneratingSummary = true;
          });

          // ---> 1. GRAB THE EMOTIONS FROM THE CAMERA <---
          List<String> finalEmotions = stopAiCamera();

          String parentUid = FirebaseAuth.instance.currentUser!.uid;
          String actualChildName = "Little Explorer";

          try {
            var childrenSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(parentUid)
                .collection('children')
                .limit(1)
                .get();

            if (childrenSnapshot.docs.isNotEmpty) {
              var childData = childrenSnapshot.docs.first.data();
              if (childData.containsKey('nickname')) {
                actualChildName = childData['nickname'];
              }
            }
          } catch (e) {
            debugPrint("Could not fetch nickname: $e");
          }
          // ---> CALCULATE EXACT TIME PLAYED <---
          final int playedSeconds = DateTime.now()
              .difference(_gameStartTime!)
              .inSeconds;
          final int mins = playedSeconds ~/ 60;
          final int secs = playedSeconds % 60;
          final String timePlayed = "${mins}m ${secs}s";

          // ---> 2. ASK GEMINI FOR THE SUMMARY <---
          debugPrint("Sending data to Gemini... Please wait.");
          String geminiSummary = await AiSummaryService.generateParentSummary(
            childName: actualChildName,
            activityName: "Star Color Sort",
            emotionsList: finalEmotions,
            timePlayed: timePlayed,
            mistakesMade: _mistakeCount,
          );
          debugPrint("GEMINI SAYS: $geminiSummary");

          // ---> 3. SAVE TO YOUR EXISTING FIRESTORE ARCHITECTURE <---
          debugPrint("Saving report to parent database...");
          try {
            // AUTOMATICALLY gets the ID of whoever is currently logged into the app!
            String parentUid = FirebaseAuth.instance.currentUser!.uid;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(parentUid)
                .collection('reports')
                .add({
                  'activityName': "Star Color Sort",
                  'summary': geminiSummary,
                  'timestamp': FieldValue.serverTimestamp(),
                });
            debugPrint("Successfully saved to: $parentUid");

            try {
              var checkData = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(parentUid)
                  .collection('reports')
                  .get();
              debugPrint(
                "RADAR TEST: I can see ${checkData.docs.length} reports saved here!",
              );
            } catch (e) {
              debugPrint("RADAR TEST ERROR: $e");
            }
          } catch (e) {
            debugPrint("Database Error: $e");
          }

          await Future.delayed(const Duration(milliseconds: 800));

          await PuzzleProgressService.instance.markLevelComplete(1);

          if (mounted) {
            _isGeneratingSummary = false;
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
      setState(() {
        _mistakeCount++;
        if (jarIndex == 0) {
          _wrongFlashA = true;
        } else {
          _wrongFlashB = true;
        }
      });
      showRoxieReaction(RoxieState.wrong);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        setState(() {
          _wrongFlashA = false;
          _wrongFlashB = false;
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
                : FadeTransition(
                    opacity: _gameFade,
                    child: _buildGameContent(),
                  ),
          ),
          //wag to tin
          // ---> LIVE DEMO CAMERA <---
          if (isCameraInitialized && aiCameraController != null)
            const SizedBox.shrink(),

          // ---> CONDITIONAL LIGHTING PROMPT <---
          if ((!isCameraInitialized || !isFaceDetected) && !_hideLightingPrompt)
            Positioned.fill(
              child: LightingPromptCard(
                onClose: () {
                  setState(() {
                    _hideLightingPrompt =
                        true; // This forces it to stay hidden!
                  });
                },
              ),
            ),

          if (_isGeneratingSummary)
            const Positioned.fill(child: GeneratingSummaryCard()),

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
                        fontFamily: PuzzleAppTextStyles.fredoka,
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
    return Stack(
      // ← wrap in Stack
      children: [
        Column(
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
        ),
        buildRoxie(context),
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
                      fontFamily: PuzzleAppTextStyles.fredoka,
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
      child: _poolBalls.isEmpty
          ? Center(
              child: Icon(
                Icons.star_rounded,
                size: 50,
                color: PuzzleColorTheme.sunnyhue,
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
        : contents.length == _countB;

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
                    fontFamily: PuzzleAppTextStyles.fredoka,
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
                          ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.6)
                          : pair.jarColor.withValues(alpha: 0.85),
                      colorBlendMode: BlendMode.modulate,
                    ),
                  ),
                  if (contents.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      child: _buildStarsInJar(contents),
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
                          fontFamily: PuzzleAppTextStyles.fredoka,
                          fontSize: 13,
                          color: PuzzleColorTheme.darkbrown,
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

  Widget _buildStarsInJar(List<_Ball> contents) {
    Widget star(_Ball b) => Image.asset(
      _starImage,
      width: 24,
      height: 24,
      color: b.pair.ballColor,
      colorBlendMode: BlendMode.modulate,
    );

    Widget row(List<_Ball> items) => Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map(star).toList(),
    );

    final count = contents.length;

    if (count <= 3) {
      return row(contents);
    } else if (count == 4) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(contents.sublist(0, 1)), // 1 above
          row(contents.sublist(1, 4)), // 3 below
        ],
      );
    } else { // 5 or 6
      final topCount = count - 3;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(contents.sublist(0, topCount)),      // 2 above (for 5), 3 above (for 6)
          row(contents.sublist(topCount, count)),  // 3 below
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

  // ── Win overlay ────────────────────────────────────────────────────────────
  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.pop(context, const Lvl2PatternMatchScreen());
      },
      onRestart: () {
        Navigator.pop(context, const Lvl1JarColorSortScreen());
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
