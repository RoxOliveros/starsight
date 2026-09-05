import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_buttons.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'alphabet_game_ui.dart';
import 'alphabet_intro.dart';
import 'forest_audio_helper.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

// ═════════════════════════════════════════════════════════════════════════
// MODELS
// ═════════════════════════════════════════════════════════════════════════

class _PawTrail {
  final String letter;
  final List<Offset> pawPositions; // fractional, bottom-to-top order
  final List<double> pawAngles; // slight per-paw rotation for a natural trail
  final Offset letterPos; // fractional, where the big letter sits
  final String animalAsset; // revealed once the trail is completed

  const _PawTrail({
    required this.letter,
    required this.pawPositions,
    required this.pawAngles,
    required this.letterPos,
    required this.animalAsset,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// GAME
// ═════════════════════════════════════════════════════════════════════════

/// "Follow the Paw Prints" -- three paw trails lead to three letters (S, T,
/// U); each round the child must tap the target trail's paws in order,
/// start to finish, ignoring the two decoy trails.
class FollowThePawPrintsGame extends StatefulWidget {
  final int level;
  const FollowThePawPrintsGame({super.key, required this.level});

  @override
  State<FollowThePawPrintsGame> createState() => _FollowThePawPrintsGameState();
}

class _FollowThePawPrintsGameState extends State<FollowThePawPrintsGame>
    with TickerProviderStateMixin, GameLoadingMixin<FollowThePawPrintsGame>, ForestAudioMixin<FollowThePawPrintsGame>, TofiReactionMixin<FollowThePawPrintsGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest_grassland.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _pawAsset = 'assets/images/objects/forest/paw_print.png';
  static const String _sparkleAsset = 'assets/images/objects/forest/sparkle.png';
  static const String _leafAsset = 'assets/images/objects/forest/leaf.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/paw_prints_intro.wav';
  static const String _audioTap = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioWin = '$_audioBase/paw_prints_win.wav';

  static const Map<String, String> _instructionAudioForLetter = {
    'S': '$_audioBase/follow_paws_s.wav',
    'T': '$_audioBase/follow_paws_t.wav',
    'U': '$_audioBase/follow_paws_u.wav',
  };

  static const Map<String, String> _letterAnimalAudio = {
    'S': '$_audioBase/s_is_for_squirrel.wav',
    'T': '$_audioBase/t_is_for_tiger.wav',
    'U': '$_audioBase/u_is_for_unicorn.wav',
  };

  static const List<String> _roundOrder = ['S', 'T', 'U'];
  static final List<double> _leafAngles = List.generate(8, (i) => i * pi / 4);

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<_PawTrail> _trails; // fixed layout: S, T, U trails, every round
  int _currentRoundIndex = 0;
  int _solvedRounds = 0;

  int _targetProgress = 0; // paws correctly tapped so far on the target trail
  String? _wrongPawKey; // "$letter-$index" of the paw currently wiggling
  String? _sparkleKey; // "$letter-$index" of the paw currently sparkling
  bool _resolving = false;
  bool _showCelebration = false;
  _PawTrail? _celebratingTrail;
  bool _showAllAnimals = false;

  String get _targetLetter => _roundOrder[_currentRoundIndex];

  late AnimationController _tofiFloatCtrl; // intro-only idle float
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _pulseCtrl; // repeating -- the "tap me next" pulse
  late AnimationController _shakeCtrl; // one-shot wrong-tap wiggle
  late Animation<double> _shake;
  late AnimationController _letterPopCtrl; // one-shot letter enlarge on completion
  late AnimationController _tofiWalkCtrl; // one-shot walk-along-the-trail
  late AnimationController _animalWaveCtrl; // repeating wave once the animal appears
  late AnimationController _ambientLeavesCtrl; // always-on slow background drift

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _trails = _buildTrails();
    _initAnimations();
    _setupRound(playInstruction: false);
    finishLoading(_startIntroFlow);
  }

  List<_PawTrail> _buildTrails() {
    return [
      _buildSingleTrail(
        letter: 'S',
        centerX: 0.28,
        count: 5,
        animalAsset: 'assets/images/objects/forest/squirrel.png',
      ),

      _buildSingleTrail(
        letter: 'T',
        centerX: 0.56,
        count: 3,
        animalAsset: 'assets/images/objects/forest/tiger.png',
      ),

      _buildSingleTrail(
        letter: 'U',
        centerX: 0.85,
        count: 6,
        animalAsset: 'assets/images/objects/forest/unicorn.png',
      ),
    ];
  }

  _PawTrail _buildSingleTrail({
    required String letter,
    required double centerX,
    required int count,
    required String animalAsset,
  }) {
    final positions = List.generate(count, (i) {
      final t = count == 1 ? 0.0 : i / (count - 1);
      final y = 0.86 - t * 0.50;
      final curve = sin(t * pi) * 0.05;
      final x = (centerX + (centerX < 0.5 ? curve : -curve)).clamp(0.08, 0.92);
      return Offset(x, y);
    });
    final angles = List.generate(count, (i) => (i.isEven ? -0.18 : 0.18) + i * 0.015);

    return _PawTrail(
      letter: letter,
      pawPositions: positions,
      pawAngles: angles,
      letterPos: Offset(centerX, 0.20),
      animalAsset: animalAsset,
    );
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
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

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.14), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.14, end: 0.14), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.14, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _letterPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _tofiWalkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _animalWaveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _ambientLeavesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    )..repeat();
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
    if (mounted) await playVoice(_instructionAudioForLetter[_targetLetter]!);
  }

  void _setupRound({bool playInstruction = true}) {
    _targetProgress = 0;
    _wrongPawKey = null;
    _sparkleKey = null;
    _resolving = false;
    _showCelebration = false;
    _celebratingTrail = null;
    _showAllAnimals = false;

    _letterPopCtrl.reset();
    _tofiWalkCtrl.reset();
    _animalWaveCtrl.stop();
    _animalWaveCtrl.reset();
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) playVoice(_instructionAudioForLetter[_targetLetter]!);
      });
    }

    setState(() {});
  }

  // ── Paw interaction ──────────────────────────────────────────────────────
  Future<void> _onPawTapped(_PawTrail trail, int index) async {
    if (_resolving) return;

    final isTargetTrail = trail.letter == _targetLetter;
    final isNextExpected = isTargetTrail && index == _targetProgress;

    if (!isNextExpected) {
      HapticFeedback.heavyImpact();

      await showTofiReaction(TofiState.wrong);

      final key = '${trail.letter}-$index';
      setState(() => _wrongPawKey = key);
      _shakeCtrl.forward(from: 0);
      playSfx(_audioTap); // fire-and-forget, gentle
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _wrongPawKey = null);
      return;
    }

    HapticFeedback.selectionClick();
    final key = '${trail.letter}-$index';
    setState(() {
      _targetProgress++;
      _sparkleKey = key;
    });
    await playSfx(_audioTap);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _sparkleKey == key) setState(() => _sparkleKey = null);
    });

    if (_targetProgress >= trail.pawPositions.length) {
      await _onTrailCompleted(trail);
    }
  }

  Offset _positionAlongTrail(_PawTrail trail, double t) {
    final points = trail.pawPositions;
    if (points.length == 1) return points.first;
    final scaled = t * (points.length - 1);
    final i = scaled.floor().clamp(0, points.length - 2);
    final localT = scaled - i;
    final a = points[i];
    final b = points[i + 1];
    return Offset(a.dx + (b.dx - a.dx) * localT, a.dy + (b.dy - a.dy) * localT);
  }

  Future<void> _onTrailCompleted(_PawTrail trail) async {
    _resolving = true;
    HapticFeedback.mediumImpact();
    setState(() {
      _showCelebration = true;
      _celebratingTrail = trail;
    });

    _tofiWalkCtrl.forward(from: 0);
    _letterPopCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    showTofiReaction(TofiState.correct);

    _animalWaveCtrl.repeat(reverse: true);

    await playVoice(_letterAnimalAudio[trail.letter]!);
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    _animalWaveCtrl.stop();
    setState(() {
      _showCelebration = false;
      _celebratingTrail = null;
    });

    await _advanceRound();
  }

  Future<void> _advanceRound() async {
    _solvedRounds++;

    if (_currentRoundIndex >= _roundOrder.length - 1) {
      // Reveal all animals
      setState(() {
        _showAllAnimals = true;
      });

      // Make them wave
      _animalWaveCtrl.repeat(reverse: true);

      // Let the child enjoy seeing all animals
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      _animalWaveCtrl.stop();

      await playVoice(_audioWin);

      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);

      if (!mounted) return;

      _showGoodJob();
      return;
    }

    _currentRoundIndex++;
    _setupRound();
  }

  void _showGoodJob() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: _dogImage,
          
          onNext: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => AlphabetIntroScreen(letter: 'V')),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => FollowThePawPrintsGame(level: widget.level)),
            );
          },
          onBack: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tofiFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _letterPopCtrl.dispose();
    _tofiWalkCtrl.dispose();
    _animalWaveCtrl.dispose();
    _ambientLeavesCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.alphabetForest(),
        gameBuilder: () => Stack(
          children: [
            if (_introPlaying) _buildIntroLayer() else _buildGameContent(),
            if (!_introPlaying) buildTofi(context),
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
        Positioned.fill(
          child: Image.asset(
            _bgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: ForestColorTheme.lightgrayishgreen),
          ),
        ),
        const Positioned(top: 25, left: 20, child: ForestBackButton()),
        Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),
        Center(
          child: AnimatedBuilder(
            animation: _tofiFloatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                0,
                Tween<double>(begin: -6, end: 6).evaluate(
                  CurvedAnimation(parent: _tofiFloatCtrl, curve: Curves.easeInOut),
                ),
              ),
              child: child,
            ),
            child: Image.asset(
              _dogImage,
              height: screenH * 0.72,
              errorBuilder: (_, __, ___) => const Text('🐶', style: TextStyle(fontSize: 90)),
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
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _bgImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: ForestColorTheme.lightgrayishgreen),
              ),
            ),
            Positioned.fill(child: _buildAmbientLeaves(w, h)),
            _buildGameUI(w, h),
          ],
        );
      },
    );
  }

  Widget _buildGameUI(double w, double h) {
    return ScaleTransition(
      scale: _sceneEnter,
      child: Stack(
        children: [
          const Positioned(top: 25, left: 20, child: ForestBackButton()),
          Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),

          Positioned(
            top: 25,
            left: 0,
            right: 0,
            child: Center(
              child: ScaleTransition(
                scale: _instructionBounce,
                child: GestureDetector(
                  onTap: () => playVoice(_instructionAudioForLetter[_targetLetter]!),
                  child: ForestInstructionBanner(text: 'Follow the paw prints to $_targetLetter!'),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 90),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, inner) => _buildTrailsArea(inner.maxWidth, inner.maxHeight),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildProgressDots(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Trails area ──────────────────────────────────────────────────────────
  Widget _buildTrailsArea(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          for (final trail in _trails) _buildTrailLetter(trail, w, h),
          for (final trail in _trails)
            for (int i = 0; i < trail.pawPositions.length; i++) _buildPaw(trail, i, w, h),
          if (_sparkleKey != null) _buildSparkleForKey(_sparkleKey!, w, h),
          if (_showCelebration) _buildTofiWalkOverlay(w, h),
        ],
      ),
    );
  }

  Widget _buildPaw(_PawTrail trail, int index, double w, double h) {
    final isTarget = trail.letter == _targetLetter;
    final completed = isTarget && index < _targetProgress;
    final isNext = isTarget && index == _targetProgress;
    final wrong = _wrongPawKey == '${trail.letter}-$index';
    final pos = trail.pawPositions[index];
    final angle = trail.pawAngles[index];
    final size = (h * 0.09).clamp(44.0, 70.0);

    return Positioned(
      left: pos.dx * w - size / 2,
      top: pos.dy * h - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _onPawTapped(trail, index),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseCtrl, _shakeCtrl]),
          builder: (_, child) {
            final pulseScale = isNext ? 1.0 + 0.12 * sin(_pulseCtrl.value * 2 * pi) : 1.0;
            final scale = completed ? 1.15 : pulseScale;
            final shakeAngle = wrong ? _shake.value : 0.0;
            return Transform.rotate(
              angle: angle + shakeAngle,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Container(
            decoration: completed
                ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ForestColorTheme.mediumseagreen.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            )
                : null,
            child: ColorFiltered(
              colorFilter: completed
                  ? ColorFilter.mode(ForestColorTheme.mediumseagreen.withValues(alpha: 0.55), BlendMode.srcATop)
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Image.asset(
                _pawAsset,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  '🐾',
                  style: TextStyle(
                    fontSize: size * 0.8,
                    color: completed ? ForestColorTheme.mediumseagreen : Colors.brown,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSparkleForKey(String key, double w, double h) {
    for (final trail in _trails) {
      for (int i = 0; i < trail.pawPositions.length; i++) {
        if ('${trail.letter}-$i' != key) continue;
        final pos = trail.pawPositions[i];
        return Positioned(
          left: pos.dx * w - 25,
          top: pos.dy * h - 25,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (_, v, __) => Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.5 + v,
                child: Image.asset(
                  _sparkleAsset,
                  width: 50,
                  errorBuilder: (_, __, ___) => const Text('✨', style: TextStyle(fontSize: 34)),
                ),
              ),
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildTrailLetter(_PawTrail trail, double w, double h) {
    final isTarget = trail.letter == _targetLetter;
    final showAnimal = _showAllAnimals || (isTarget && _showCelebration);

    return Positioned(
      left: trail.letterPos.dx * w - 40,
      top: trail.letterPos.dy * h - 54,
      child: AnimatedBuilder(
        animation: _letterPopCtrl,
        builder: (_, child) {
          final scale = isTarget ? 1.0 + 0.18 * Curves.elasticOut.transform(_letterPopCtrl.value) : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _outlinedLetter(
                trail.letter,
                fontSize: 60,
                fillColor: ForestColorTheme.darkseagreen
            ),
            if (showAnimal) ...[
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _animalWaveCtrl,
                builder: (_, child) => Transform.rotate(
                  angle: 0.15 * sin(_animalWaveCtrl.value * 2 * pi),
                  child: child,
                ),
                child: Image.asset(
                  trail.animalAsset,
                  height: 70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTofiWalkOverlay(double w, double h) {
    final trail = _celebratingTrail;
    if (trail == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _tofiWalkCtrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_tofiWalkCtrl.value);
        final pos = _positionAlongTrail(trail, t);
        final size = (h * 0.21);

        return Stack(
          children: [
            ..._leafAngles.map((baseAngle) {
              final angle = baseAngle + _tofiWalkCtrl.value * 6;
              final radius = size * 0.55;
              final dx = pos.dx * w + cos(angle) * radius;
              final dy = pos.dy * h + sin(angle) * radius;
              return Positioned(
                left: dx - 10,
                top: dy - 10,
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    _leafAsset,
                    width: 20,
                    errorBuilder: (_, __, ___) => const Text('🍃', style: TextStyle(fontSize: 16)),
                  ),
                ),
              );
            }),
            Positioned(
              left: pos.dx * w - size / 2,
              top: pos.dy * h - size,
              child: Image.asset(
                _dogImage,
                height: size,
                errorBuilder: (_, __, ___) => const Text('🐶', style: TextStyle(fontSize: 60)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAmbientLeaves(double w, double h) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ambientLeavesCtrl,
        builder: (_, __) {
          return Stack(
            children: List.generate(4, (i) {
              final speedOffset = i * 0.25;
              final t = (_ambientLeavesCtrl.value + speedOffset) % 1.0;
              final x = t;
              final y = 0.05 + 0.15 * i + 0.05 * sin(t * 2 * pi);
              return Positioned(
                left: x * w,
                top: y * h,
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    _leafAsset,
                    width: 18,
                    errorBuilder: (_, __, ___) => const Text('🍃', style: TextStyle(fontSize: 14)),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  /// Letter with a white outline behind a solid fill, for legibility
  /// against the forest background.
  Widget _outlinedLetter(String letter, {required double fontSize, required Color fillColor}) {
    return Stack(
      children: [
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.09
              ..color = Colors.white,
          ),
        ),
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            color: fillColor,
          ),
        ),
      ],
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_roundOrder.length, (i) {
        final done = i < _solvedRounds;
        final current = i == _currentRoundIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ForestColorTheme.mediumseagreen
                : current
                ? ForestColorTheme.seagreen
                : ForestColorTheme.seagreen.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}