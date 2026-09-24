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
import 'game_same_or_different.dart';

enum _ScreenPhase { intro, game }

class _OddOneOutQuestion {
  final List<String> objects;
  final String oddObject;

  const _OddOneOutQuestion({required this.objects, required this.oddObject});
}

const List<_OddOneOutQuestion> _kQuestions = [
  _OddOneOutQuestion(
    objects: ['apple', 'banana', 'orange', 'ball'],
    oddObject: 'ball',
  ),
  _OddOneOutQuestion(
    objects: ['dog', 'cat', 'rabbit', 'car'],
    oddObject: 'car',
  ),
  _OddOneOutQuestion(
    objects: ['car', 'bus', 'train', 'flower'],
    oddObject: 'flower',
  ),
  _OddOneOutQuestion(
    objects: ['pen', 'notebook', 'book', 'banana'],
    oddObject: 'banana',
  ),
  _OddOneOutQuestion(
    objects: ['flower', 'tree', 'leaf', 'car'],
    oddObject: 'car',
  ),
];

const int _kTotalRounds = 5;

class OddOneOutScreen extends StatefulWidget {
  final int level;

  const OddOneOutScreen({super.key, required this.level});

  @override
  State<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends State<OddOneOutScreen>
    with
        TickerProviderStateMixin,
        RoxieReactionMixin<OddOneOutScreen>,
        GameLoadingMixin,
        AiCameraMixin {
  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
  static const String _objectAssetPath = 'assets/images/objects/puzzle';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/odd_one_out_intro.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/odd_one_out_instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/odd_one_out_complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late String _oddObject;
  late List<String> _choices;
  bool _wrongFlash = false;
  bool _roundComplete = false;
  int? _tappedIndex;
  int? _wrongIndex;
  bool _showWinDialog = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _roxiePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _roxieFloatCtrl;
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _previewPulseCtrl;
  late Animation<double> _previewPulse;
  late AnimationController _speechBubbleCtrl;

  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _revealCtrl;
  late Animation<double> _revealAnim;

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
    _bgPlayer.dispose();
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxiePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _previewPulseCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    _revealCtrl.dispose();
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

    _previewPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _previewPulse = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _previewPulseCtrl, curve: Curves.easeInOut),
    );

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
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeIn);
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _roxieSlideCtrl.forward();
    _speechBubbleCtrl.forward(from: 0);

    await _playBgAudio(_audioIntro);
    if (!mounted) return;

    _speechBubbleCtrl.forward(from: 0);
    _gameEnterCtrl.forward();
    _startRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
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

  void _startRound() {
    final rng = Random();
    final question = _kQuestions[_round - 1];

    _oddObject = question.oddObject;
    _choices = List<String>.from(question.objects)..shuffle(rng);

    _wrongFlash = false;
    _roundComplete = false;
    _tappedIndex = null;
    _wrongIndex = null;

    _bounceCtrl.reset();
    _shakeCtrl.reset();
    _revealCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  Future<void> _onObjectTapped(String tapped, int index) async {
    if (_roundComplete || _wrongFlash) return;

    if (tapped == _oddObject) {
      _tapTracker.recordCorrectTap();
      setState(() {
        _tappedIndex = index;
        _roundComplete = true;
      });
      _bounceCtrl.forward(from: 0);
      _revealCtrl.forward(from: 0);
      unawaited(showRoxieReaction(RoxieState.correct));

      await Future.delayed(const Duration(milliseconds: 1200));

      if (_round >= _kTotalRounds) {
        await _bgPlayer.stop();
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
        setState(() {
          _round++;
          _startRound();
        });
      }
    } else {
      _tapTracker.recordMistake();
      unawaited(showRoxieReaction(RoxieState.wrong));
      setState(() {
        _wrongFlash = true;
        _wrongIndex = index;
      });
      _shakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        setState(() {
          _wrongFlash = false;
          _wrongIndex = null;
        });
      }
    }
  }

  Future<void> _saveDataAndShowWinDialog() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    PuzzleDatabaseService.saveGameData(
      gameId: 'puzzle_odd_one_out',
      activityName: 'Odd One Out',
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroPreview() {
    const previewGroup = ['apple', 'banana', 'orange'];
    const previewOdd = 'ball';

    final previewItems = [...previewGroup, previewOdd];

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: previewItems.map((object) {
          final isOdd = object == previewOdd;

          Widget card = Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOdd
                    ? PuzzleColorTheme.sunnyhue
                    : PuzzleColorTheme.darkdesaturatedblue.withValues(
                        alpha: 0.30,
                      ),
                width: isOdd ? 3 : 2.5,
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
                '$_objectAssetPath/$object.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
          );

          if (isOdd) {
            card = ScaleTransition(scale: _previewPulse, child: card);
          }

          return card;
        }).toList(),
      ),
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
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 20,
        children: List.generate(
          _choices.length,
          (i) => KeyedSubtree(
            key: ValueKey(_choices[i]),
            child: _buildObjectCard(i),
          ),
        ),
      ),
    );
  }

  Widget _buildObjectCard(int index) {
    final object = _choices[index];
    final isOdd = object == _oddObject;
    final isWrongTap = _wrongFlash && _wrongIndex == index;
    final isCorrectTap = _roundComplete && isOdd;
    final isDimmed = _roundComplete && !isOdd;

    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(
      alpha: 0.28,
    );
    Color bgColor = Colors.white.withValues(alpha: 0.85);

    if (isWrongTap) {
      borderColor = const Color(0xFFE05A5A);
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.10);
    }
    if (isCorrectTap) {
      borderColor = PuzzleColorTheme.sunnyhue;
      bgColor = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28);
    }

    Widget image = Image.asset(
      '$_objectAssetPath/$object.png',
      width: 72,
      height: 72,
      fit: BoxFit.contain,
      color: isDimmed
          ? PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.25)
          : null,
      colorBlendMode: isDimmed ? BlendMode.modulate : null,
    );

    if (isCorrectTap) {
      image = ScaleTransition(scale: _bounceAnim, child: image);
    }

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: image),
    );

    if (isWrongTap) {
      card = AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        ),
        child: card,
      );
    }

    return GestureDetector(
      onTap: () => _onObjectTapped(object, index),
      child: card,
    );
  }

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SameOrDifferentScreen(level: widget.level + 1),
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
