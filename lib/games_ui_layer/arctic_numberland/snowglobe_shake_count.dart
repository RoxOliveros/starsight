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

class _TagOption {
  final String id;
  final int number;
  const _TagOption({required this.id, required this.number});
}

class _RoundSpec {
  final int targetNumber;
  final List<_TagOption> shelves;
  const _RoundSpec({required this.targetNumber, required this.shelves});
}

class SnowglobeShakeGame extends StatefulWidget {
  final int level;

  const SnowglobeShakeGame({super.key,required this.level});

  @override
  State<SnowglobeShakeGame> createState() => _SnowglobeShakeGameState();
}

class _SnowglobeShakeGameState extends State<SnowglobeShakeGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<SnowglobeShakeGame>,
        GameLoadingMixin<SnowglobeShakeGame>,
        ArcticAudioMixin<SnowglobeShakeGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _snowglobeEmptyAsset = 'assets/images/objects/arctic/empty_snowglobe.png';
  static const String _snowballAsset = 'assets/images/objects/arctic/snowball.png';
  static const String _tagAsset = 'assets/images/objects/arctic/tag.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/snowglobe_shake_intro.wav';
  static const String _audioInstruction = '$_audioBase/snowglobe_shake_instuction.wav';

  static const List<Alignment> _ballPositions = [
    Alignment(-0.28, -0.55),
    Alignment(0.30, -0.53),
    Alignment(0.0, -0.68),
    Alignment(-0.45, -0.28),
    Alignment(0.45, -0.26),
    Alignment(0.0, -0.22),
    Alignment(-0.48, 0.05),
    Alignment(0.48, 0.07),
    Alignment(0.19, 0.17),
    Alignment(-0.19, 0.17),
  ];

  static const double _shakeDistanceThreshold = 26.0;
  static const List<int> _tagOptionCounts = [2, 2, 3, 3, 3];
  static const int _totalRounds = 5;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<_RoundSpec> _rounds;
  int _currentRound = 0;
  int _solvedRounds = 0;
  int _shakeCount = 0;
  bool _globeFull = false;
  bool _resolving = false;
  _TagOption? _attachedTag;
  bool _showWinDialog = false;

  double _strokeDelta = 0;
  int _strokeSign = 0;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _wiggleCtrl;
  late Animation<double> _wiggle;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _rounds = _buildRounds();
    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  List<_RoundSpec> _buildRounds() {
    final rng = Random();

    final targets = List.generate(10, (n) => n + 1)..shuffle(rng);   // ADD: pool of 1-10, shuffled
    final chosenTargets = targets.take(_totalRounds).toList();       // ADD: pick 5 unique, no repeats

    return List.generate(_totalRounds, (i) {
      final target = chosenTargets[i];                               // CHANGED from: i + 1
      final count = _tagOptionCounts[i];
      final possible = List.generate(10, (n) => n + 1)..remove(target);
      possible.shuffle(rng);
      final distractors = possible.take(count - 1).toList();
      final numbers = [target, ...distractors]..shuffle(rng);
      final shelves = List.generate(
        count,
            (idx) => _TagOption(id: 'r$i-s$idx', number: numbers[idx]),
      );
      return _RoundSpec(targetNumber: target, shelves: shelves);
    });
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

    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _wiggle = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.12), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.12), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _wiggleCtrl, curve: Curves.easeInOut));
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

  // ── Shake detection ──────────────────────────────────────────────────────
  // Tracks alternating drag direction. Each time the drag reverses after
  // travelling far enough in one direction, it counts as one "shake" and
  // adds a snowball — mimicking a real back-and-forth shake motion rather
  // than a simple tap.
  void _onShakePanUpdate(DragUpdateDetails details) {
    if (_globeFull || _resolving) return;
    final dx = details.delta.dx;
    if (dx.abs() < 0.5) return;
    final sign = dx > 0 ? 1 : -1;

    if (_strokeSign == 0) {
      _strokeSign = sign;
      _strokeDelta = dx.abs();
    } else if (sign == _strokeSign) {
      _strokeDelta += dx.abs();
    } else {
      if (_strokeDelta >= _shakeDistanceThreshold) {
        _registerShake();
      }
      _strokeSign = sign;
      _strokeDelta = dx.abs();
    }
  }

  void _onShakePanEnd(DragEndDetails details) {
    if (!_globeFull && _strokeDelta >= _shakeDistanceThreshold) {
      _registerShake();
    }
    _strokeSign = 0;
    _strokeDelta = 0;
  }

  void _registerShake() {
    final target = _rounds[_currentRound].targetNumber;
    if (_shakeCount >= target || _globeFull) return;

    HapticFeedback.selectionClick();
    _wiggleCtrl.forward(from: 0);
    setState(() => _shakeCount++);
    _strokeDelta = 0;

    if (_shakeCount >= target) {
      HapticFeedback.mediumImpact();
      setState(() => _globeFull = true);
    }
  }

  Future<void> _advanceRound() async {
    setState(() => _solvedRounds++);

    if (_currentRound + 1 >= _totalRounds) {
      if (!mounted) return;
      setState(() => _showWinDialog = true);
      return;
    }

    setState(() {
      _currentRound++;
      _shakeCount = 0;
      _globeFull = false;
      _resolving = false;
      _attachedTag = null;
      _strokeDelta = 0;
      _strokeSign = 0;
    });
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
  }

  Future<void> _onCorrectTagDroppedOnGlobe(_TagOption tag) async {
    if (_resolving) return;
    _resolving = true;
    HapticFeedback.mediumImpact();
    setState(() => _attachedTag = tag);
    await playSfx('$_audioBase/${_rounds[_currentRound].targetNumber}.wav');
    showDomaReaction(DomaState.correct);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _advanceRound();
  }

  @override
  void dispose() {
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _wiggleCtrl.dispose();
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
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      0,
                      Tween<double>(begin: -6, end: 6).evaluate(
                        CurvedAnimation(parent: _domaFloatCtrl, curve: Curves.easeInOut),
                      ),
                    ),
                    child: child,
                  ),
                  child: Image.asset(
                    _characterImage,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Image.asset(
                  _snowglobeEmptyAsset,
                  height: screenH * 0.5,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('🔮', style: TextStyle(fontSize: 90)),
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
                        Center(child: _buildInstructionBanner(h)),
                      ],
                    ),
                  ),
                  Expanded(child: _buildGlobeArea(h)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildProgressDots(),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(child: _buildTagsColumn(h)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTagsColumn(double h) {
    final round = _rounds[_currentRound];
    final tagSize = (h * 0.25);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: round.shelves
          .map((s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildTag(s, tagSize),
      ))
          .toList(),
    );
  }

  Widget _buildInstructionBanner(double h) {
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
            _globeFull ? 'Now put the matching tag!' : 'Shake the snowglobe to reveal!',
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

  Widget _buildGlobeArea(double h) {
    final size = (h * 0.65);

    return Center(
      child: AnimatedBuilder(
        animation: _wiggle,
        builder: (_, child) => Transform.rotate(angle: _wiggle.value, child: child),
        child: _globeFull ? _buildGlobeDropTarget(size) : _buildShakeableGlobe(size),
      ),
    );
  }

  Widget _buildShakeableGlobe(double size) {
    return GestureDetector(
      onPanUpdate: _onShakePanUpdate,
      onPanEnd: _onShakePanEnd,
      child: _globeVisual(size),
    );
  }

  Widget _buildGlobeDropTarget(double size) {
    return DragTarget<_TagOption>(
      onWillAcceptWithDetails: (details) =>
      !_resolving && details.data.number == _rounds[_currentRound].targetNumber,
      onAcceptWithDetails: (details) => _onCorrectTagDroppedOnGlobe(details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedScale(
          scale: hovering ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: _globeVisual(size),
        );
      },
    );
  }

  Widget _globeVisual(double size) {
    return SizedBox(
      width: size,
      height: size * 1.15, // a little extra room below for the attached tag
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            _snowglobeEmptyAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text('🔮', style: TextStyle(fontSize: size * 0.6)),
          ),
          ...List.generate(_shakeCount, (i) {
            final pos = _ballPositions[i % _ballPositions.length];
            return Align(
              alignment: pos,
              child: Image.asset(
                _snowballAsset,
                width: size * 0.15,
                height: size * 0.15,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.circle, size: size * 0.14, color: ArcticColorTheme.pictonblue),
              ),
            );
          }),
          if (_attachedTag != null)
            Positioned(
              top: size * 0.70,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (_, value, child) => Transform.scale(scale: value, child: child),
                child: _tagVisual(_attachedTag!, size * 0.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(_TagOption tag, double size) {
    return Draggable<_TagOption>(
      data: tag,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.1, child: _tagVisual(tag, size)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _tagVisual(tag, size)),
      onDragStarted: () => HapticFeedback.selectionClick(),
      onDraggableCanceled: (_, __) async {
        HapticFeedback.heavyImpact();
        await playSfx('assets/audio/sound_effects/bubble_pop.wav');
        showDomaReaction(DomaState.wrong);
      },
      child: _tagVisual(tag, size),
    );
  }

  Widget _tagVisual(_TagOption tag, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            _tagAsset,
            width: size,
            height: size,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                color: ArcticColorTheme.cotton.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(size * 0.15),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
          Transform.translate(                      // ADD: wrap the Text in this
            offset: Offset(0, size * 0.05),           // ADD: push down a bit — tweak the 0.1 factor to taste
            child: Text(
              '${tag.number}',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.40,
                color: ArcticColorTheme.cotton,
              ),
            ),
          ),
        ],
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
        // TODO: navigate to next game
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedRounds = 0;
          _shakeCount = 0;
          _globeFull = false;
          _resolving = false;
          _attachedTag = null;
          _rounds = _buildRounds();
        });
        _sceneEnterCtrl.forward(from: 0);
        _instructionCtrl.forward(from: 0);
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}