import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/arctic_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_audio_helper.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'igloo_peekaboo.dart';

/// How many penguins to play with. Defaults to 1-8.
class PenguinLineWalkGame extends StatefulWidget {
  final int level;
  final int count;

  const PenguinLineWalkGame({super.key, this.count = 8, required this.level});

  @override
  State<PenguinLineWalkGame> createState() => _PenguinLineWalkGameState();
}

class _PenguinLineWalkGameState extends State<PenguinLineWalkGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<PenguinLineWalkGame>,
        GameLoadingMixin<PenguinLineWalkGame>,
        ArcticAudioMixin<PenguinLineWalkGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _babyPenguinAsset = 'assets/images/characters/baby_penguin_sideview.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/penguin_line_walk_intro.wav';
  static const String _audioInstruction = '$_audioBase/penguin_line_walk_instruction.wav';
  static const String _audioWin = '$_audioBase/penguin_line_walk_win.wav';

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<int> _stagingNumbers; // shuffled, unplaced penguins
  final Set<int> _placed = {};
  bool _showWinDialog = false;
  bool _showWinBurst = false;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _walkOffCtrl;

  int get _totalCount => widget.count;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _stagingNumbers = List.generate(_totalCount, (i) => i + 1)..shuffle();
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _instructionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _instructionBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut));

    _sceneEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sceneEnter =
        CurvedAnimation(parent: _sceneEnterCtrl, curve: Curves.elasticOut);

    _walkOffCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) playVoice(_audioInstruction);
  }

  // ── Match handling ───────────────────────────────────────────────────────
  Future<void> _onPenguinMatched(int number) async {
    if (_placed.contains(number)) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _placed.add(number);
      _stagingNumbers.remove(number);
    });
    await playSfx('$_audioBase/$number.wav');
    showDomaReaction(DomaState.correct);

    if (_placed.length >= _totalCount) {
      await Future.delayed(const Duration(milliseconds: 400));
      await _onAllMatched();
    }
  }

  Future<void> _onPenguinMissed() async {
    HapticFeedback.heavyImpact();
    await playSfx('assets/audio/sound_effects/bubble_pop.wav');
    showDomaReaction(DomaState.wrong);
  }

  Future<void> _onAllMatched() async {
    await _walkOffCtrl.forward(from: 0);
    if (!mounted) return;
    setState(() => _showWinBurst = true);
    await playVoice(_audioWin);
    await ArcticProgressService.instance.markLevelComplete(widget.level);
    if (!mounted) return;
    setState(() {
      _showWinBurst = false;
      _showWinDialog = true;
    });
  }

  @override
  void dispose() {
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _walkOffCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.arctic(),
        gameBuilder: () => Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _bgImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1B4B7A), Color(0xFF6FB8E0)],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _introPlaying ? _buildIntroLayer() : _buildGameContent(),
              ),

            if (!_introPlaying) buildDoma(context),
            if (_showWinBurst) _buildWinBurst(),
            if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
          ],
        ),
      ),
    );
  }

  // ── Intro layer ──────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(top: 25, left: 20, child: ArcticBackButton()),
        Positioned(top: 25, right: 20, child: ArcticLevelBadge(level: widget.level)),
        Center(
          child: AnimatedBuilder(
            animation: _domaFloatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                0,
                Tween<double>(begin: -6, end: 6).evaluate(
                  CurvedAnimation(parent: _domaFloatCtrl, curve: Curves.easeInOut),
                ),
              ),
              child: child,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  _characterImage,
                  height: screenH * 0.7,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
                ),
                SizedBox(width: 150),
                Image.asset(
                  _babyPenguinAsset,
                  height: screenH * 0.3,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
                ),
                SizedBox(width: 50),
                Image.asset(
                  _babyPenguinAsset,
                  height: screenH * 0.3,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
                ),
                SizedBox(width: 50),
                Image.asset(
                  _babyPenguinAsset,
                  height: screenH * 0.3,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  // ── Main game layout ─────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        return ScaleTransition(
          scale: _sceneEnter,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: ArcticBackButton()),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ArcticLevelBadge(level: widget.level),
                    ),
                    Center(child: _buildPromptBanner(h)),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _walkOffCtrl,
                builder: (context, child) {
                  final t = _walkOffCtrl.value;
                  final dx = -1.4 * MediaQuery.of(context).size.width * Curves.easeInCubic.transform(t);
                  final bounce = (sin(t * pi * 8).abs()) * 10 * (1 - t); // 8 "steps", fades out as it exits
                  return Transform.translate(
                    offset: Offset(dx, -bounce),
                    child: child,
                  );
                },
                child: _buildLineRow(h * 0.33),
              ),
              Expanded(child: _buildStagingArea(h)),
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: _buildProgressDots(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromptBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => playVoice(_audioInstruction),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: ArcticColorTheme.pictonblue.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Match each penguin to its floe!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],            ),
          ),
        ),
      ),
    );
  }

  // ── Staging area (draggable penguins) ────────────────────────────────────
  Widget _buildStagingArea(double h) {
    final size = (h * 0.20).clamp(50.0, 92.0);
    final visibleNumbers = _stagingNumbers.take(4).toList();

    return Center(
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: visibleNumbers.map((n) => _buildStagingPenguin(n, size)).toList(),   // CHANGED from _stagingNumbers
      ),
    );
  }

  Widget _buildStagingPenguin(int n, double size) {
    return Draggable<int>(
      key: ValueKey('staging-$n'),
      data: n,
      feedback: Material(
        color: Colors.transparent,
        child: _penguinBadge(n, size * 1.2, elevated: true),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: _penguinBadge(n, size)),
      onDragStarted: () => HapticFeedback.selectionClick(),
      onDraggableCanceled: (_, __) => _onPenguinMissed(),
      child: _penguinBadge(n, size),
    );
  }

  Widget _penguinBadge(int n, double size, {bool elevated = false}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            _babyPenguinAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text('🐧', style: TextStyle(fontSize: size * 0.8)),
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ArcticColorTheme.pictonblue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: elevated
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: size * 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Floe row (drag targets) ──────────────────────────────────────────────
  Widget _buildLineRow(double h) {
    return SizedBox(
      height: h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_totalCount, (i) => _buildLine(i + 1, h)),
      ),
    );
  }

  Widget _buildLine(int n, double slotSize) {
    final placed = _placed.contains(n);

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => !placed && details.data == n,
      onAcceptWithDetails: (details) => _onPenguinMatched(details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        final rejected = rejectedData.isNotEmpty;

        return AnimatedScale(
          scale: hovering ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            width: slotSize - 50,
            height: slotSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!placed)
                  Container(
                    width: slotSize * 0.6,
                    height: slotSize * 0.6,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: hovering ? 0.9 : 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: rejected
                            ? Colors.red
                            : ArcticColorTheme.slateblue.withValues(alpha: hovering ? 1.0 : 0.55),
                        width: 2.5,
                      ),
                    ),
                    child: Text(
                      '$n',
                      style: TextStyle(
                        fontFamily: ArcticAppTextStyles.fredoka,
                        fontWeight: FontWeight.bold,
                        fontSize: slotSize * 0.32,
                        color: rejected
                            ? Colors.red
                            : ArcticColorTheme.slateblue.withValues(alpha: hovering ? 1.0 : 0.55),
                      ),
                    ),
                  ),
                if (placed)
                  AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    child: _penguinBadge(n, slotSize * 0.7),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalCount, (i) {
        final done = i < _placed.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : ArcticColorTheme.slateblue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }

  // ── Win burst (shown while win audio plays) ──────────────────────────────
  Widget _buildWinBurst() {
    final screenH = MediaQuery
        .of(context)
        .size
        .height;
    return Positioned.fill(
      child: Center(
        child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (_, value, child) =>
                Transform.scale(scale: value, child: child),
            child:
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  _babyPenguinAsset,
                  height: screenH * 0.3,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                  const Text('🎉', style: TextStyle(fontSize: 90)),
                ),
                Image.asset(
                  _babyPenguinAsset,
                  height: screenH * 0.3,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                  const Text('🎉', style: TextStyle(fontSize: 90)),
                ),
                Image.asset(
                  _babyPenguinAsset,
                  height: screenH * 0.3,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                  const Text('🎉', style: TextStyle(fontSize: 90)),
                ),
              ],
            )
        ),
      ),
    );
  }

  // ── Win / celebration overlay ────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => IglooPeekabooGame(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _placed.clear();
          _stagingNumbers = List.generate(_totalCount, (i) => i + 1)..shuffle();
        });
        _walkOffCtrl.reset();
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}