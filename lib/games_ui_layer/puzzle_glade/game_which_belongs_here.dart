import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Question model
// ─────────────────────────────────────────────────────────────────────────────

class _WhichBelongsQuestion {
  final String scene;
  final String correctObject;
  final List<String> choices;

  const _WhichBelongsQuestion({
    required this.scene,
    required this.correctObject,
    required this.choices,
  });

  /// Unique-ish key used to avoid repeating the exact same question
  /// within a single playthrough.
  String get key => '$scene-$correctObject-${choices.join(",")}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const int _kTotalRounds = 5;

// Round 1 — very obvious associations, clearly unrelated distractors.
const List<_WhichBelongsQuestion> _kRound1Pool = [
  _WhichBelongsQuestion(
    scene: 'bg_lumi_bathroom',
    correctObject: 'toothbrush',
    choices: ['toothbrush', 'ball', 'pan'],
  ),
  _WhichBelongsQuestion(
    scene: 'bg_lumi_classroom',
    correctObject: 'pen',
    choices: ['pen', 'soap', 'plate'],
  ),
];

// Round 2 — another familiar place, still obvious.
const List<_WhichBelongsQuestion> _kRound2Pool = [
  _WhichBelongsQuestion(
    scene: 'bg_kitchen',
    correctObject: 'pan',
    choices: ['pan', 'pillow', 'toothbrush'],
  ),
  _WhichBelongsQuestion(
    scene: 'bg_game_forest_garden',
    correctObject: 'watering_can',
    choices: ['watering_can', 'shirt', 'spork'],
  ),
];

// Round 3 — slightly more similar (domestic) distractors from other rooms.
const List<_WhichBelongsQuestion> _kRound3Pool = [
  _WhichBelongsQuestion(
    scene: 'bg_lumi_bed',
    correctObject: 'pillow',
    choices: ['pillow', 'plate', 'school_bag'],
  ),
  _WhichBelongsQuestion(
    scene: 'bg_lumi_park',
    correctObject: 'ball',
    choices: ['ball', 'toothbrush', 'plate'],
  ),
  _WhichBelongsQuestion(
    scene: 'bg_beach_sunny',
    correctObject: 'beach_ball',
    choices: ['beach_ball', 'pen', 'plate'],
  ),
];

// Round 4 — visually similar-shaped distractors, but one clear correct answer.
const List<_WhichBelongsQuestion> _kRound4Pool = [
  _WhichBelongsQuestion(
    scene: 'bg_kitchen',
    correctObject: 'pot',
    choices: ['pot', 'bucket', 'watering_can'],
  ),
  _WhichBelongsQuestion(
    scene: 'bg_lumi_bathroom',
    correctObject: 'towel',
    choices: ['towel', 'blanket', 'shirt'],
  ),
  _WhichBelongsQuestion(
    scene: 'bg_living_room',
    correctObject: 'tv_remote',
    choices: ['tv_remote', 'spork', 'pen'],
  ),
];

// Round 5 — a little more thoughtful, still gentle and unambiguous.
const List<_WhichBelongsQuestion> _kRound5Pool = [
  _WhichBelongsQuestion(
    scene: 'bg_game_forest_garden',
    correctObject: 'flower_pot',
    choices: ['flower_pot', 'bucket', 'pot'],
  ),
  _WhichBelongsQuestion(
    scene: 'bg_lumi_classroom',
    correctObject: 'notebook',
    choices: ['notebook', 'shoes', 'spatula'],
  ),
  _WhichBelongsQuestion(
    scene: 'bg_living_room',
    correctObject: 'sofa',
    choices: ['sofa', 'room_lamp', 'bucket'],
  ),
];

const List<List<_WhichBelongsQuestion>> _kRoundQuestionPools = [
  _kRound1Pool,
  _kRound2Pool,
  _kRound3Pool,
  _kRound4Pool,
  _kRound5Pool,
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class WhichBelongsHereScreen extends StatefulWidget {
  final int level;

  const WhichBelongsHereScreen({super.key, required this.level});

  @override
  State<WhichBelongsHereScreen> createState() => _WhichBelongsHereScreenState();
}

class _WhichBelongsHereScreenState extends State<WhichBelongsHereScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<WhichBelongsHereScreen>, GameLoadingMixin {
  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
  static const String _objectAssetPath = 'assets/images/objects/puzzle';
  static const String _sceneAssetPath = 'assets/images/backgrounds';

  static const String _audioIntro = 'assets/audio/puzzle_glade/which_belongs_here_intro.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/which_belongs_here_complete.wav';
  static const String _audioBathroom = 'assets/audio/puzzle_glade/which_belongs_here_bathroom.wav';
  static const String _audioBeach = 'assets/audio/puzzle_glade/which_belongs_here_beach.wav';
  static const String _audioClassroom = 'assets/audio/puzzle_glade/which_belongs_here_classroom.wav';
  static const String _audioGarden = 'assets/audio/puzzle_glade/which_belongs_here_garden.wav';
  static const String _audioKitchen = 'assets/audio/puzzle_glade/which_belongs_here_kitchen.wav';
  static const String _audioLivingRoom = 'assets/audio/puzzle_glade/which_belongs_here_living_room.wav';
  static const String _audioPark = 'assets/audio/puzzle_glade/which_belongs_here_park.wav';
  static const String _audioBedroom = 'assets/audio/puzzle_glade/which_belongs_here_bedroom.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late _WhichBelongsQuestion _question;
  late List<String> _shuffledChoices;
  late int _correctIndex;
  final Set<String> _usedQuestionKeys = {};

  int? _selectedIndex;
  int? _wrongIndex;
  bool _buttonsDisabled = true;
  bool _roundComplete = false;
  bool _showWinDialog = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _roxiePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _previewPulseCtrl;
  late Animation<double> _previewPulse;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneFade;
  late Animation<double> _sceneScale;
  late AnimationController _choicesEnterCtrl;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  @override
  void dispose() {
    _bgPlayer.stop();
    _completePlayer.stop();
    _roxiePlayer.stop();

    _bgPlayer.dispose();
    _completePlayer.dispose();
    _roxiePlayer.dispose();

    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _previewPulseCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _choicesEnterCtrl.dispose();
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();

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
        .animate(CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut));
    _roxieFade = CurvedAnimation(parent: _roxieSlideCtrl, curve: const Interval(0, 0.4));

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

    _sceneEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _sceneFade = CurvedAnimation(parent: _sceneEnterCtrl, curve: Curves.easeOut);
    _sceneScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _sceneEnterCtrl, curve: Curves.easeOut),
    );

    _choicesEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );

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
  }

  Animation<double> _choiceEntranceFor(int index) {
    final start = index * 0.15;
    final end = (start + 0.6).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _choicesEnterCtrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

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

    if (!mounted) return;

    setState(() {
      _screenPhase = _ScreenPhase.game;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;

    await _playCurrentSceneAudio();
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

  String? _getAudioForScene(String scene) {
    switch (scene) {
      case 'bg_lumi_bathroom':
        return _audioBathroom;

      case 'bg_lumi_park':
        return _audioPark;

      case 'bg_lumi_classroom':
        return _audioClassroom;

      case 'bg_kitchen':
        return _audioKitchen;

      case 'bg_beach_sunny':
        return _audioBeach;

      case 'bg_game_forest_garden':
        return _audioGarden;

      case 'bg_lumi_bed':
        return _audioBedroom;

      case 'bg_living_room':
        return _audioLivingRoom;

      default:
        debugPrint('No question audio configured for scene: $scene');
        return null;
    }
  }

  Future<void> _playCurrentSceneAudio() async {
    if (!mounted) return;

    final audio = _getAudioForScene(_question.scene);

    if (audio == null) {
      if (mounted) {
        setState(() {
          _buttonsDisabled = false;
        });
      }
      return;
    }

    // Prevent answering before the question narration finishes.
    if (mounted) {
      setState(() {
        _buttonsDisabled = true;
      });
    }

    await _playBgAudio(audio);

    if (!mounted) return;

    if (!_roundComplete) {
      setState(() {
        _buttonsDisabled = false;
      });
    }
  }

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    if (!mounted) return;

    final rng = Random();
    final pool = _kRoundQuestionPools[_round - 1];

    final available = pool.where((q) => !_usedQuestionKeys.contains(q.key)).toList();
    final candidates = available.isNotEmpty ? available : pool;

    _question = candidates[rng.nextInt(candidates.length)];
    _usedQuestionKeys.add(_question.key);

    _shuffledChoices = List<String>.from(_question.choices)..shuffle(rng);
    _correctIndex = _shuffledChoices.indexOf(_question.correctObject);

    _selectedIndex = null;
    _wrongIndex = null;
    _buttonsDisabled = false;
    _roundComplete = false;

    _bounceCtrl.reset();
    _shakeCtrl.reset();
    _sceneEnterCtrl.forward(from: 0);
    _choicesEnterCtrl.forward(from: 0);
  }

  // ── Answer handling ────────────────────────────────────────────────────────

  Future<void> _onChoiceTapped(int index) async {
    if (_buttonsDisabled || _roundComplete) return;

    final isCorrect = index == _correctIndex;

    if (isCorrect) {
      setState(() {
        _selectedIndex = index;
        _buttonsDisabled = true;
        _roundComplete = true;
      });

      _bounceCtrl.forward(from: 0);

      unawaited(showRoxieReaction(RoxieState.correct));

      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      if (_round >= _kTotalRounds) {
        await _bgPlayer.stop();

        if (!mounted) return;

        final completer = Completer<void>();
        final sub = _completePlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });

        try {
          await _completePlayer.play(
            AssetSource(_audioComplete.replaceFirst('assets/', '')),
          );
          await completer.future.timeout(const Duration(seconds: 10));
        } finally {
          await sub.cancel();
        }

        if (!mounted) return;

        await PuzzleProgressService.instance.markLevelComplete(widget.level);

        if (!mounted) return;

        setState(() => _showWinDialog = true);
      } else {
        await _sceneEnterCtrl.reverse();

        if (!mounted) return;

        setState(() {
          _round++;
        });

        _startRound();

        await Future.delayed(const Duration(milliseconds: 300));

        if (!mounted) return;

        await _playCurrentSceneAudio();
      }
    } else {
      setState(() {
        _wrongIndex = index;
        _buttonsDisabled = true;
      });

      unawaited(showRoxieReaction(RoxieState.wrong));

      _shakeCtrl.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 650));

      if (!mounted) return;

      setState(() {
        _wrongIndex = null;
        _buttonsDisabled = false;
      });
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
                        child: _buildGameArea(),
                      ),
                      buildRoxie(context),
                    ],
                  ),
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
              Align(alignment: Alignment.center, child: PuzzleGameHeader(title: 'Which Belongs Here?')),
              Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _previewPulse,
            child: Container(
              width: 150,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PuzzleColorTheme.sunnyhue, width: 3),
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
                  '$_sceneAssetPath/bg_lumi_bathroom.png',
                  width: 120,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildPreviewObjectCard('toothbrush', highlighted: true),
        ],
      ),
    );
  }

  Widget _buildPreviewObjectCard(String object, {bool highlighted = false}) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? PuzzleColorTheme.sunnyhue
              : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.30),
          width: highlighted ? 3 : 2.5,
        ),
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
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameArea() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
              Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
            ],
          ),
        ),
        Expanded(child: _buildScene()),
        Padding(
          padding: const EdgeInsets.only(top: 15, bottom: 15),
          child: _buildChoiceRow(),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: PuzzleProgressDots(
            currentRound: _round,
            totalRounds: _kTotalRounds,
          ),
        ),
      ],
    );
  }

  Widget _buildScene() {
    return Center(
      child: FadeTransition(
        opacity: _sceneFade,
        child: ScaleTransition(
          scale: _sceneScale,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              '$_sceneAssetPath/${_question.scene}.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _shuffledChoices.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
          KeyedSubtree(
            key: ValueKey('${_round}_${i}_${_shuffledChoices[i]}'),
            child: _buildChoiceCard(i),
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceCard(int index) {
    final object = _shuffledChoices[index];
    final isCorrectSelected = _roundComplete && index == _selectedIndex;
    final isWrongTap = _wrongIndex == index;
    final isDimmed = _roundComplete && index != _selectedIndex;

    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28);
    Color bgColor = Colors.white.withValues(alpha: 0.85);

    if (isCorrectSelected) {
      borderColor = PuzzleColorTheme.sunnyhue;
      bgColor = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28);
    }
    if (isWrongTap) {
      borderColor = const Color(0xFFE05A5A);
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.10);
    }

    Widget image = Image.asset(
      '$_objectAssetPath/$object.png',
      width: 76,
      fit: BoxFit.contain,
      color: isDimmed ? PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.25) : null,
      colorBlendMode: isDimmed ? BlendMode.modulate : null,
    );

    if (isCorrectSelected) {
      image = ScaleTransition(scale: _bounceAnim, child: image);
    }

    Widget card = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: isCorrectSelected
                ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.35)
                : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
            blurRadius: isCorrectSelected ? 16 : 10,
            spreadRadius: isCorrectSelected ? 1 : 0,
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

    final entrance = _choiceEntranceFor(index);
    card = FadeTransition(
      opacity: entrance,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(entrance),
        child: card,
      ),
    );

    return GestureDetector(
      onTap: () => _onChoiceTapped(index),
      child: card,
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        // Navigator.pushReplacement( TODO: @Tin add nav
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => (level: widget.level + 1),
        //   ),
        // );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WhichBelongsHereScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
