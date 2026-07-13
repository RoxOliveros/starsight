import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_audio_helper.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';

class BuildSnowmanGame extends StatefulWidget {
  final int level;

  const BuildSnowmanGame({super.key,required this.level});

  @override
  State<BuildSnowmanGame> createState() => _BuildSnowmanGameState();
}

class _BuildSnowmanGameState extends State<BuildSnowmanGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<BuildSnowmanGame>,
        GameLoadingMixin<BuildSnowmanGame>,
        ArcticAudioMixin<BuildSnowmanGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _snowballAsset = 'assets/images/objects/arctic/snowball_clean.png';
  static const String _snowmanHatAsset = 'assets/images/objects/arctic/snowman_hat.png';
  static const String _tagAsset = 'assets/images/objects/arctic/tag.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/build_snowman_intro.wav';
  static const String _audioInstruction = '$_audioBase/build_snowman_instruction.wav';
  static const String _audioWin = '$_audioBase/build_snowman_win.wav';

  static const int _totalRounds = 5;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<int> _targets; // one shuffled target per round, 1-8, no repeats
  int _currentRound = 0;
  int _solvedRounds = 0;
  int _stackCount = 0;
  bool _roundResolving = false;
  bool _showWinDialog = false;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _popCtrl; // per-snowball pop-in when stacked
  late Animation<double> _pop;
  late AnimationController _tumbleCtrl; // stack collapsing on overshoot
  late Animation<double> _tumble;
  late AnimationController _completeCtrl; // hat drops on + celebratory bounce
  late Animation<double> _complete;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _targets = _buildTargets();
    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  List<int> _buildTargets() {
    final rng = Random();
    final targets = List.generate(8, (n) => n + 1)..shuffle(rng);
    return targets.take(_totalRounds).toList();
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
    _sceneEnter = CurvedAnimation(parent: _sceneEnterCtrl, curve: Curves.elasticOut);

    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _pop = CurvedAnimation(parent: _popCtrl, curve: Curves.easeOutBack);

    _tumbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tumble = CurvedAnimation(parent: _tumbleCtrl, curve: Curves.easeIn);

    _completeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _complete = CurvedAnimation(parent: _completeCtrl, curve: Curves.elasticOut);
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
    if (mounted) await _announceRound();
  }

  Future<void> _announceRound() async {
    final target = _targets[_currentRound];
    if (_currentRound == 0) {
      await playVoice(_audioInstruction);
    }
    if (mounted) await playSfx('$_audioBase/$target.wav');
  }

  // ── Snow pile interaction ───────────────────────────────────────────────
  Future<void> _onSnowballDropped() async {
    if (_roundResolving) return;
    final target = _targets[_currentRound];
    final next = _stackCount + 1;

    HapticFeedback.selectionClick();
    setState(() => _stackCount = next);
    _popCtrl.forward(from: 0);
    await playSfx('$_audioBase/$next.wav');

    if (next == target) {
      _roundResolving = true;
      HapticFeedback.mediumImpact();
      showDomaReaction(DomaState.correct);
      _completeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      await _advanceRound();
    }
  }

  Future<void> _advanceRound() async {
    setState(() => _solvedRounds++);

    if (_currentRound + 1 >= _totalRounds) {
      await playVoice(_audioWin);
      if (!mounted) return;
      setState(() => _showWinDialog = true);
      return;
    }

    setState(() {
      _currentRound++;
      _stackCount = 0;
      _roundResolving = false;
    });
    _completeCtrl.reset();
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) await _announceRound();
  }

  @override
  void dispose() {
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _popCtrl.dispose();
    _tumbleCtrl.dispose();
    _completeCtrl.dispose();
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
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFFDCEFFA)),
              ),
            ),
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _introPlaying ? _buildIntroLayer() : _buildGameContent(),
              ),

            if (!_introPlaying) buildDoma(context),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) =>
                      Transform.translate(
                        offset: Offset(
                          0,
                          Tween<double>(begin: -6, end: 6).evaluate(
                            CurvedAnimation(parent: _domaFloatCtrl,
                                curve: Curves.easeInOut),
                          ),
                        ),
                        child: child,
                      ),
                  child: Image.asset(
                    _characterImage,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                    const Text('🐧', style: TextStyle(fontSize: 70)),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Image.asset(
                  _snowballAsset,
                  height: screenH * 0.5,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                  const Text('⛄', style: TextStyle(fontSize: 90)),
                ),
              ),
            ],
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
        final w = constraints.maxWidth;

        return Stack(
          children: [
            ScaleTransition(
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
                  Expanded(child: _buildStackArea(w, h)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildProgressDots(),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 70,
              top: 100,
              child: _buildTargetBadge(h * 0.22),
            ),
            Positioned(
              right: 20,
              bottom: 16,
              child: _buildSnowballSource((h * 0.16).clamp(36.0, 70.0)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPromptBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: _announceRound,
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
            'Drag the snowball to build the snowman!',
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

  Widget _buildSnowballSource(double size) {
    final target = _targets[_currentRound];
    final disabled = _roundResolving || _stackCount >= target;

    final ball = Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: Image.asset(
        _snowballAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.circle, size: size, color: Colors.white),
      ),
    );

    if (disabled) return ball;

    return Draggable<int>(
      data: 1,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(_snowballAsset, width: size * 1.15, fit: BoxFit.contain),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: ball),
      onDragStarted: () => HapticFeedback.selectionClick(),
      child: ball,
    );
  }

  Widget _buildTargetBadge(double size) {
    final target = _targets[_currentRound];
    final tagSize = size.clamp(60.0, 96.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: tagSize,
            height: tagSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  _tagAsset,
                  width: tagSize,
                  height: tagSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      color: ArcticColorTheme.pictonblue,
                      borderRadius: BorderRadius.circular(tagSize * 0.2),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, tagSize * 0.08),
                  child: Text(
                    '$target',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontWeight: FontWeight.bold,
                      fontSize: tagSize * 0.5,
                      color: ArcticColorTheme.cotton,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stack area ───────────────────────────────────────────────────────────
  Widget _buildStackArea(double w, double h) {
    final ballSize = h * 0.30;
    final target = _targets[_currentRound];
    final isComplete = _stackCount == target && _roundResolving;

    // Each ball's scale, biggest at the bottom (i = 0).
    final scales = List<double>.generate(_stackCount, (i) => 1.0 - (i * 0.1));

    // Cumulative bottom offset per ball -- proportional to that ball's own
    // (already-shrunk) height, so the overlap stays consistent as balls
    // get smaller toward the top instead of using one fixed gap for all.
    const overlapFraction = 0.45; // fraction of a ball's height it overlaps the one below
    final bottoms = <double>[];
    double cumulative = 0;
    for (int i = 0; i < _stackCount; i++) {
      bottoms.add(cumulative);
      cumulative += ballSize * scales[i] * overlapFraction;
    }
    final topHeight = _stackCount == 0 ? ballSize : ballSize * scales.last;
    final stackHeight = cumulative + topHeight + ballSize * 0.9; // + room for hat

    return Center(
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => !_roundResolving && _stackCount < target,
        onAcceptWithDetails: (_) => _onSnowballDropped(),
        builder: (context, candidateData, rejectedData) {
          final hovering = candidateData.isNotEmpty;
          return AnimatedScale(
            scale: hovering ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedBuilder(
              animation: _tumbleCtrl,
              builder: (_, child) {
                final t = _tumble.value;
                return Transform.rotate(
                  angle: t * 0.35 * (_stackCount.isEven ? 1 : -1),
                  child: Transform.translate(
                    offset: Offset(0, t * h * 0.15),
                    child: Opacity(opacity: 1 - t * 0.6, child: child),
                  ),
                );
              },
              child: SizedBox(
                width: ballSize * 1.6,
                height: stackHeight,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    if (_stackCount == 0)
                      Container(
                        width: ballSize,
                        height: ballSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.25),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3),
                        ),
                      ),

                    ...List.generate(_stackCount, (i) {
                      final scale = scales[i];
                      final isNewest = i == _stackCount - 1;
                      return Positioned(
                        bottom: bottoms[i],
                        child: AnimatedBuilder(
                          animation: _popCtrl,
                          builder: (_, child) => Transform.scale(
                            scale: isNewest ? (0.3 + 0.7 * _pop.value) * scale : scale,
                            child: child,
                          ),
                          child: Image.asset(
                            _snowballAsset,
                            width: ballSize * scale,
                            height: ballSize * scale,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.circle, size: ballSize * scale, color: Colors.white),
                          ),
                        ),
                      );
                    }),

                    Positioned(
                      bottom: cumulative + ballSize * 0.02,
                      child: AnimatedBuilder(
                        animation: _completeCtrl,
                        builder: (_, child) => Transform.scale(
                          scale: isComplete ? _complete.value : 0,
                          child: child,
                        ),
                        child: Image.asset(
                          _snowmanHatAsset,
                          width: ballSize * 0.9,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text('🎩', style: TextStyle(fontSize: ballSize * 0.6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedRounds;
        final current = !_showWinDialog && i == _currentRound;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : current
                ? ArcticColorTheme.slateblue
                : ArcticColorTheme.slateblue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }

  // ── Win / celebration overlay ────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        // TODO: @Tin navigate after number intro is done
        // Navigator.pop(context, (level: widget.level + 1));
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedRounds = 0;
          _stackCount = 0;
          _roundResolving = false;
          _targets = _buildTargets();
        });
        _completeCtrl.reset();
        _sceneEnterCtrl.forward(from: 0);
        _instructionCtrl.forward(from: 0);
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}