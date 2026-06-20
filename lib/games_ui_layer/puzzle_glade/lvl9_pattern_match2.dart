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
import 'lvl10_memory_match2.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _totalRounds = 5;

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

// Longer patterns (5 items shown, 1 answer) for higher difficulty
const _patternTemplates = [
  [0, 1, 0, 1, 0, 1, 0], // A-B-A-B-A-B → A
  [0, 0, 1, 0, 0, 1, 0], // A-A-B-A-A-B → A
  [1, 0, 0, 1, 0, 0, 1], // B-A-A-B-A-A → B
  [0, 1, 1, 0, 1, 1, 0], // A-B-B-A-B-B → A
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Lvl9PatternMatch2Screen extends StatefulWidget {
  const Lvl9PatternMatch2Screen({super.key});

  @override
  State<Lvl9PatternMatch2Screen> createState() =>
      _Lvl9PatternMatch2ScreenState();
}

class _Lvl9PatternMatch2ScreenState extends State<Lvl9PatternMatch2Screen>
    with TickerProviderStateMixin, RoxieReactionMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/level9/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level9/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level9/instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/level9/complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late List<String> _sequenceObjects;
  late String _answerObject;
  late List<String> _choices;
  bool _wrongFlash = false;
  bool _rightFlash = false;
  bool _roundComplete = false;
  bool _showWinDialog = false;

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
    _startIntroFlow();
  }

  @override
  void dispose() {
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
    await _playBgAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));

    _gameEnterCtrl.forward();
    _buildRound();
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

  // ── Round setup ────────────────────────────────────────────────────────────

  void _buildRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);

    final objectA = shuffled[0];
    final objectB = shuffled[1];

    final template = _patternTemplates[rng.nextInt(_patternTemplates.length)];
    final pair = [objectA, objectB];

    _sequenceObjects = template
        .sublist(0, template.length - 1)
        .map((i) => pair[i])
        .toList();
    _answerObject = pair[template.last];

    final wrongChoice = (_answerObject == objectA) ? objectB : objectA;
    _choices = [_answerObject, wrongChoice]..shuffle(rng);

    _wrongFlash = false;
    _rightFlash = false;
    _roundComplete = false;
    _celebCtrl.reset();
    _bounceCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Choice tap ─────────────────────────────────────────────────────────────

  Future<void> _onChoiceTapped(String tapped) async {
    if (_roundComplete || _wrongFlash || _rightFlash) return;

    if (tapped == _answerObject) {
      showRoxieReaction(RoxieState.correct);

      setState(() {
        _rightFlash = true;
        _roundComplete = true;
      });
      _bounceCtrl.forward(from: 0);
      _celebCtrl.forward(from: 0);
      _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));

      await Future.delayed(const Duration(milliseconds: 1100));

      if (_round >= _totalRounds) {
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

        await PuzzleProgressService.instance.markLevelComplete(9);
        if (mounted) setState(() => _showWinDialog = true);
      } else {
        await _enterCtrl.reverse();
        setState(() {
          _round++;
          _buildRound();
        });
      }
    } else {
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      showRoxieReaction(RoxieState.wrong);
      setState(() => _wrongFlash = true);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _wrongFlash = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
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
              Expanded(flex: 4, child: _buildIntroRoxie()),
              Expanded(flex: 6, child: _buildIntroDancingObjects()),
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

  Widget _buildIntroDancingObjects() {
    const previewObjects = ['compass', 'star', 'compass', 'star'];

    return AnimatedBuilder(
      animation: _starDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: List.generate(previewObjects.length + 1, (i) {
              final isQuestion = i == previewObjects.length;
              final angle = _starDance.value * ((i % 2 == 0) ? 1 : -1);
              return Transform.rotate(
                angle: angle,
                child: isQuestion
                    ? Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: JarColorTheme.goldenyellow.withValues(
                            alpha: 0.25,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: JarColorTheme.sunnyhue,
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
                              fontFamily: JarAppTextStyles.fredoka,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: JarColorTheme.sunnyhue,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: JarColorTheme.darkdesaturatedblue.withValues(
                              alpha: 0.30,
                            ),
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
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/images/objects/puzzle/${previewObjects[i]}.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Text('📦', style: TextStyle(fontSize: 28)),
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

  Widget _buildGameContent() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildGameHeader(),
          const SizedBox(height: 12),
          Expanded(child: _buildGameArea()),
          _buildProgressDots(),
          const SizedBox(height: 10),
        ],
      ),
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
            Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
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
              child: Text(
                'Object Pattern',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 22,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.45),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ..._sequenceObjects.map(
            (obj) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _objectTile(obj, 56),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '→',
              style: TextStyle(
                fontSize: 28,
                color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.5),
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
        child: _objectTile(_answerObject, 58),
      );
    }
    return _PulseWidget(
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: JarColorTheme.goldenyellow.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: JarColorTheme.sunnyhue, width: 2.5),
        ),
        child: Center(
          child: Text(
            '?',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: JarColorTheme.sunnyhue,
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

  Widget _buildChoiceButton(String choice) {
    final isAnswer = choice == _answerObject;
    final showWrong = _wrongFlash && !isAnswer;
    final showRight = _rightFlash && isAnswer;

    Color borderColor = JarColorTheme.darkdesaturatedblue.withValues(
      alpha: 0.30,
    );
    if (showWrong) borderColor = const Color(0xFFE05A5A);
    if (showRight) borderColor = JarColorTheme.sunnyhue;

    return GestureDetector(
      onTap: () => _onChoiceTapped(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: showRight
              ? JarColorTheme.goldenyellow.withValues(alpha: 0.35)
              : showWrong
              ? const Color(0xFFE05A5A).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Opacity(
            opacity: showWrong ? 0.30 : 1.0,
            child: _objectTile(choice, 54),
          ),
        ),
      ),
    );
  }

  // ── Star widget ────────────────────────────────────────────────────────────

  Widget _objectTile(String objectName, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        'assets/images/objects/puzzle/$objectName.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Text('📦', style: TextStyle(fontSize: 20)),
      ),
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

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
        Navigator.pop(context, const Lvl10JarMemoryMatch2Screen());
      },
      onRestart: () {
        Navigator.pop(context, const Lvl9PatternMatch2Screen());
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
