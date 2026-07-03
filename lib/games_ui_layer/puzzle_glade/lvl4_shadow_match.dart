import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl5_jigsaw_puzzle.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

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

const int _kChoices = 2;
const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Lvl4ShadowMatchScreen extends StatefulWidget {
  const Lvl4ShadowMatchScreen({super.key});

  @override
  State<Lvl4ShadowMatchScreen> createState() => _Lvl4ShadowMatchScreenState();
}

class _Lvl4ShadowMatchScreenState extends State<Lvl4ShadowMatchScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<Lvl4ShadowMatchScreen> {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/level4/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level4/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level4/shadow_match_instruction.wav';
  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/level4/complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;
  late String _answerObject;
  late List<String> _choices;
  bool _wrongFlash = false;
  bool _roundComplete = false;
  int? _tappedIndex;
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
  late AnimationController _shadowDanceCtrl;
  late Animation<double> _shadowDance;
  late AnimationController _speechBubbleCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _revealCtrl;
  late Animation<double> _revealAnim;

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
    _shadowDanceCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _bounceCtrl.dispose();
    _revealCtrl.dispose();
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

    _shadowDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _shadowDance = Tween<double>(begin: -0.07, end: 0.07).animate(
      CurvedAnimation(parent: _shadowDanceCtrl, curve: Curves.easeInOut),
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

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeIn);
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

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);

    _answerObject = shuffled[0];
    _choices = shuffled.take(_kChoices).toList()..shuffle(rng);

    _wrongFlash = false;
    _roundComplete = false;
    _tappedIndex = null;

    _bounceCtrl.reset();
    _revealCtrl.reset();
    _pulseCtrl.repeat(reverse: true);
    _enterCtrl.forward(from: 0);
  }

  // ── Choice tap ─────────────────────────────────────────────────────────────

  Future<void> _onChoiceDropped(String tapped, int index) async {
    if (_roundComplete || _wrongFlash) return;

    if (tapped == _answerObject) {
      _pulseCtrl.stop();
      setState(() {
        _tappedIndex = index;
        _roundComplete = true;
      });
      _bounceCtrl.forward(from: 0);
      _revealCtrl.forward(from: 0);
      _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
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

        await PuzzleProgressService.instance.markLevelComplete(4);

        if (mounted) setState(() => _showWinDialog = true);
      } else {
        await _enterCtrl.reverse();
        setState(() {
          _round++;
          _startRound();
        });
      }
    } else {
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      unawaited(showRoxieReaction(RoxieState.wrong));
      setState(() {
        _tappedIndex = index;
        _wrongFlash = true;
      });
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        setState(() {
          _wrongFlash = false;
          _tappedIndex = null;
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
              Expanded(flex: 6, child: _buildIntroDancingShadows()),
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

  Widget _buildIntroDancingShadows() {
    const previewObjects = ['compass', 'lamp'];
    return AnimatedBuilder(
      animation: _shadowDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: List.generate(previewObjects.length, (i) {
              final isShadow = i % 2 == 0;
              final angle = _shadowDance.value * ((i % 2 == 0) ? 1 : -1);
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isShadow
                        ? PuzzleColorTheme.vandecane
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PuzzleColorTheme.darkdesaturatedblue.withValues(
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
                  child: Center(
                    child: Image.asset(
                      'assets/images/objects/puzzle/${previewObjects[i]}.png',
                      width: 60,
                      height: 60,
                      color: isShadow
                          ? PuzzleColorTheme.verydarkdesaturatedblue.withValues(
                              alpha: 0.80,
                            )
                          : null,
                      colorBlendMode: isShadow
                          ? BlendMode.srcIn
                          : BlendMode.modulate,
                      errorBuilder: (_, __, ___) =>
                          Text('🔍', style: TextStyle(fontSize: 28)),
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
                'Shadow Match',
                style: TextStyle(
                  fontFamily: PuzzleAppTextStyles.fredoka,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSilhouetteCard(),
        const SizedBox(width: 20),
        _buildChoicesRow(),
      ],
    );
  }

  // ── Silhouette card ────────────────────────────────────────────────────────

  Widget _buildSilhouetteCard() {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => !_roundComplete,
      onAcceptWithDetails: (details) {
        final index = _choices.indexOf(details.data);
        _onChoiceDropped(details.data, index);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isHovering ? 0.95 : 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isHovering
                  ? PuzzleColorTheme.sunnyhue
                  : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.35),
              width: isHovering ? 3.5 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(child: _buildSilhouetteImage()),
        );
      },
    );
  }

  Widget _buildSilhouetteImage() {
    if (_roundComplete) {
      return AnimatedBuilder(
        animation: _revealAnim,
        builder: (_, __) {
          final tintValue = (_revealAnim.value * 255).round().clamp(0, 255);
          final tint = Color.fromARGB(255, tintValue, tintValue, tintValue);
          return Image.asset(
            'assets/images/objects/puzzle/$_answerObject.png',
            width: 110,
            height: 110,
            color: tint,
            colorBlendMode: BlendMode.modulate,
            errorBuilder: (_, __, ___) =>
                Text('🖼️', style: TextStyle(fontSize: 60)),
          );
        },
      );
    }
    return ScaleTransition(
      scale: _pulseAnim,
      child: Image.asset(
        'assets/images/objects/puzzle/$_answerObject.png',
        width: 110,
        height: 110,
        color: PuzzleColorTheme.verydarkdesaturatedblue.withValues(alpha: 0.85),
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) =>
            Text('🔍', style: TextStyle(fontSize: 60)),
      ),
    );
  }

  // ── Choices ────────────────────────────────────────────────────────────────

  Widget _buildChoicesRow() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: List.generate(
        _kChoices,
            (i) => KeyedSubtree(
          key: ValueKey(_choices[i]),
          child: _buildChoiceButton(i),
        ),
      ),
    );
  }

  Widget _buildChoiceButton(int index) {
    final object = _choices[index];
    final isAnswer = object == _answerObject;
    final isWrong = _wrongFlash && _tappedIndex == index;
    final isCorrect = _roundComplete && isAnswer;

    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(
      alpha: 0.28,
    );
    Color bgColor = Colors.white.withValues(alpha: 0.85);

    if (_roundComplete && isAnswer) {
      return Container(
        key: ValueKey('${object}_done'),
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(22),
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
      );
    }
    if (isWrong) {
      borderColor = const Color(0xFFE05A5A);
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.10);
    }
    if (isCorrect) {
      borderColor = PuzzleColorTheme.sunnyhue;
      bgColor = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.28);
    }


    Widget child = Image.asset(
      'assets/images/objects/puzzle/$object.png',
      width: 60,
      height: 60,
      fit: BoxFit.contain,
      color: (_roundComplete && !isAnswer)
          ? PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.25)
          : null,
      colorBlendMode: BlendMode.modulate,
      errorBuilder: (_, __, ___) => Text('🖼️', style: TextStyle(fontSize: 36)),
    );

    if (isCorrect) {
      child = ScaleTransition(scale: _bounceAnim, child: child);
    }

    final cardDecoration = BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderColor, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.09),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return Draggable<String>(
      key: ValueKey(object),
      data: object,
      maxSimultaneousDrags: (_roundComplete || _wrongFlash) ? 0 : 1,
      feedback: Material(
        color: Colors.transparent,
        child: child,
      ),
      childWhenDragging: Container(
        width: 82,
        height: 82,
        decoration: cardDecoration,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        height: 82,
        decoration: cardDecoration,
        child: Center(child: child),
      ),
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kTotalRounds, (i) {
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
        Navigator.pop(context, const Lvl5JigsawPuzzleScreen());
      },
      onRestart: () {
        Navigator.pop(context, const Lvl4ShadowMatchScreen());
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
