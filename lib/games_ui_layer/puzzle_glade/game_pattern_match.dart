import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/ai_summary_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/generating_summary_card.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'game_memory_match.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTotalRounds = 5;

const _allColors = [
  _StarColor(label: 'Red', color: Color(0xFFE05A5A)),
  _StarColor(label: 'Blue', color: Color(0xFF4C7FBE)),
  _StarColor(label: 'Green', color: Color(0xFF5AAE6A)),
  _StarColor(label: 'Yellow', color: Color(0xFFF9AB19)),
  _StarColor(label: 'Purple', color: Color(0xFF9B6DC5)),
];

const _patternTemplates = [
  [0, 1, 0, 1, 0],
  [0, 0, 1, 0, 0],
  [1, 0, 1, 0, 1],
];

const _hardPatternTemplates = [
  [0, 1, 0, 1, 0, 1, 0],
  [0, 0, 1, 0, 0, 1, 0],
  [1, 0, 0, 1, 0, 0, 1],
  [0, 1, 1, 0, 1, 1, 0],
];

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _StarColor {
  final String label;
  final Color color;

  const _StarColor({required this.label, required this.color});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PatternMatchScreen extends StatefulWidget {
  final int level;

  const PatternMatchScreen({super.key, required this.level});

  @override
  State<PatternMatchScreen> createState() => _PatternMatchScreenState();
}

class _PatternMatchScreenState extends State<PatternMatchScreen>
    with
        TickerProviderStateMixin,
        RoxieReactionMixin,
        AiCameraMixin,
        GameLoadingMixin {
  final AudioPlayer _roxiePlayer = AudioPlayer();

  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/pattern_match_intro.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/pattern_match_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/pattern_match_complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late List<_StarColor> _sequenceColors;
  late _StarColor _answerColor;
  late List<_StarColor> _choices;
  bool _wrongFlash = false;
  bool _rightFlash = false;
  bool _roundComplete = false;
  bool _showWinDialog = false;

  // ── AI TRACKERS  ────────────────────────────────────────────────────────────

  bool _isGeneratingSummary = false;
  bool _hideLightingPrompt = false;
  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _starDanceCtrl;
  late Animation<double> _starDance;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _celebCtrl;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    startAiCamera();
    finishLoading(_startIntroFlow);
  }

  @override
  void dispose() {
    disposeAiCamera();
    _roxiePlayer.dispose();
    _bgPlayer.dispose();
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _starDanceCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _bounceCtrl.dispose();
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

    _starDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _starDance = Tween<double>(
      begin: -0.08,
      end: 0.08,
    ).animate(CurvedAnimation(parent: _starDanceCtrl, curve: Curves.easeInOut));

    _speechBubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.22,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioIntro);

    _speechBubbleCtrl.forward(from: 0);

    _gameEnterCtrl.forward();
    _buildRound();
    if (mounted) {
      setState(() {
        _screenPhase = _ScreenPhase.game;
        _tapTracker.startSession();
      });
    }
    await _playBgAudio(_audioInstructions);
  }

  Future<void> _playBgAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _bgPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _bgPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  // ── Round setup ────────────────────────────────────────────────────────────

  void _buildRound() {
    final rng = Random();
    final shuffled = List<_StarColor>.from(_allColors)..shuffle(rng);

    final colorA = shuffled[0];
    final colorB = shuffled.firstWhere(
      (c) => c != colorA && _colorDistance(c.color, colorA.color) > 120,
      orElse: () => shuffled[1],
    );

    final templatesForRound = _round >= 4
        ? _hardPatternTemplates
        : _patternTemplates;
    final template = templatesForRound[rng.nextInt(templatesForRound.length)];
    final pair = [colorA, colorB];

    _sequenceColors = template
        .sublist(0, template.length - 1)
        .map((i) => pair[i])
        .toList();
    _answerColor = pair[template.last];

    final wrongChoice = (_answerColor == colorA) ? colorB : colorA;

    _choices = [_answerColor, wrongChoice]..shuffle(rng);

    _wrongFlash = false;
    _rightFlash = false;
    _roundComplete = false;
    _celebCtrl.reset();
    _bounceCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  double _colorDistance(Color a, Color b) {
    return sqrt(
      pow(a.red - b.red, 2) +
          pow(a.green - b.green, 2) +
          pow(a.blue - b.blue, 2),
    );
  }

  // ── Choice tap ─────────────────────────────────────────────────────────────

  Future<void> _onChoiceTapped(_StarColor tapped) async {
    if (_roundComplete || _wrongFlash || _rightFlash) return;

    if (tapped == _answerColor) {
      _tapTracker.recordCorrectTap();
      setState(() {
        _rightFlash = true;
        _roundComplete = true;
      });

      unawaited(showRoxieReaction(RoxieState.correct));

      _bounceCtrl.forward(from: 0);
      _celebCtrl.forward(from: 0);
      _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));

      await Future.delayed(const Duration(milliseconds: 1100));

      if (_round >= _kTotalRounds) {
        await _bgPlayer.stop();
        await _sfxPlayer.stop();
        setState(() {
          _isGeneratingSummary = true; // Shows the loading screen
        });

        // 1. Grab Emotions & Time
        List<String> finalEmotions = stopAiCamera();

        // 2. Get Child's Name
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

        // 3. Ask Gemini for Summary
        debugPrint("Sending data to Gemini... Please wait.");
        String geminiSummary = await AiSummaryService.generateParentSummary(
          gameId: 'puzzle_pattern_match', // <-- Use your registry ID
          childName: actualChildName,
          emotionsList: finalEmotions,
          timePlayed: _tapTracker.formattedDuration, // <-- Use tracker
          totalTaps: _tapTracker.totalTaps, // <-- Use tracker
          mistakesMade: _tapTracker.mistakeCount, // <-- Use tracker
        );

        // 4. Save to Firestore
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(parentUid)
              .collection('reports')
              .add({
                'gameId': 'puzzle_pattern_match',
                'activityName': "Star Pattern Match",
                'summary': geminiSummary,
                'totalTaps': _tapTracker.totalTaps, // <-- Save metrics
                'mistakes': _tapTracker.mistakeCount, // <-- Save metrics
                'timePlayed': _tapTracker.formattedDuration, // <-- Save metrics
                'timestamp': FieldValue.serverTimestamp(),
              });
        } catch (e) {
          debugPrint("Database Error: $e");
        }

        final completer = Completer<void>();
        final sub = _completePlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        await _completePlayer.play(
          AssetSource(_audioComplete.replaceFirst('assets/', '')),
        );
        await completer.future.timeout(const Duration(seconds: 10));
        await sub.cancel();

        await PuzzleProgressService.instance.markLevelComplete(2);

        if (mounted) setState(() => _showWinDialog = true);
      } else {
        await _enterCtrl.reverse();
        setState(() {
          _round++;
          _buildRound();
        });
      }
    } else {
      _tapTracker.recordMistake();
      setState(() {
        _wrongFlash = true;
      });
      unawaited(showRoxieReaction(RoxieState.wrong));

      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _wrongFlash = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.puzzleGlade(),
        gameBuilder: () => Stack(
          children: [
            // Background
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

            if (_screenPhase == _ScreenPhase.game) buildRoxie(context),

            // ---> CONDITIONAL LIGHTING PROMPT <---
            if ((!isCameraInitialized || !isFaceDetected) &&
                !_hideLightingPrompt)
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

            // ---> LOADING SUMMARY PROMPT <---
            if (_isGeneratingSummary)
              const Positioned.fill(child: GeneratingSummaryCard()),

            if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIntroLayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
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
              Expanded(flex: 6, child: _buildIntroDancingStars()),
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

  Widget _buildIntroDancingStars() {
    // Show a little A-B-A-B pattern preview to hint at the game
    final previewColors = [
      const Color(0xFFE05A5A),
      const Color(0xFF4C7FBE),
      const Color(0xFFE05A5A),
      const Color(0xFF4C7FBE),
    ];
    return AnimatedBuilder(
      animation: _starDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: List.generate(previewColors.length + 1, (i) {
              final isQuestion = i == previewColors.length;
              final angle = _starDance.value * ((i % 2 == 0) ? 1 : -1);
              return Transform.rotate(
                angle: angle,
                child: isQuestion
                    ? Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: PuzzleColorTheme.goldenyellow.withValues(
                            alpha: 0.25,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PuzzleColorTheme.sunnyhue,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '?',
                            style: TextStyle(
                              fontFamily: PuzzleAppTextStyles.fredoka,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: PuzzleColorTheme.sunnyhue,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: PuzzleColorTheme.vandecane,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PuzzleColorTheme.darkdesaturatedblue
                                .withValues(alpha: 0.30),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/objects/puzzle/star.png',
                            width: 42,
                            height: 42,
                            color: previewColors[i],
                            colorBlendMode: BlendMode.modulate,
                            errorBuilder: (_, __, ___) =>
                                Text('⭐', style: TextStyle(fontSize: 28)),
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

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

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
                  alignment: Alignment.centerLeft,
                  child: PuzzleBackButton(),
                ),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSequenceRow(),
        const SizedBox(height: 28),
        _buildChoicesRow(),
      ],
    );
  }

  // ── Sequence row ───────────────────────────────────────────────────────────

  Widget _buildSequenceRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.45),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ..._sequenceColors.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _starWidget(c.color, 52),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '→',
              style: TextStyle(
                fontSize: 28,
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                  alpha: 0.5,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildQuestionSlot(),
        ],
      ),
    );
  }

  Widget _buildQuestionSlot() {
    if (_roundComplete) {
      return ScaleTransition(
        scale: _bounceAnim,
        child: _starWidget(_answerColor.color, 58),
      );
    }
    return _PulseWidget(
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: PuzzleColorTheme.goldenyellow.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PuzzleColorTheme.sunnyhue, width: 2.5),
        ),
        child: Center(
          child: Text(
            '?',
            style: TextStyle(
              fontFamily: PuzzleAppTextStyles.fredoka,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: PuzzleColorTheme.sunnyhue,
            ),
          ),
        ),
      ),
    );
  }

  // ── Choices row ────────────────────────────────────────────────────────────

  Widget _buildChoicesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _choices.map((choice) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildChoiceButton(choice),
        );
      }).toList(),
    );
  }

  Widget _buildChoiceButton(_StarColor choice) {
    final isAnswer = choice == _answerColor;
    final showWrong = _wrongFlash && !isAnswer;
    final showRight = _rightFlash && isAnswer;

    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(
      alpha: 0.30,
    );
    if (showWrong) borderColor = const Color(0xFFE05A5A);
    if (showRight) borderColor = PuzzleColorTheme.sunnyhue;

    return GestureDetector(
      onTap: () => _onChoiceTapped(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: showRight
              ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.35)
              : showWrong
              ? const Color(0xFFE05A5A).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: choice.color.withValues(alpha: 0.20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _starWidget(
            showWrong
                ? PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.30)
                : choice.color,
            54,
          ),
        ),
      ),
    );
  }

  // ── Star widget ────────────────────────────────────────────────────────────

  Widget _starWidget(Color tint, double size) {
    return Image.asset(
      'assets/images/objects/puzzle/star.png',
      width: size,
      height: size,
      color: tint,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, __, ___) =>
          Text('⭐', style: TextStyle(fontSize: size * 0.65)),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryMatchScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PatternMatchScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PulseWidget
// ─────────────────────────────────────────────────────────────────────────────

class _PulseWidget extends StatefulWidget {
  final Widget child;

  const _PulseWidget({required this.child});

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.93,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _anim, child: widget.child);
}
