import 'dart:async';
import 'dart:math';
import 'package:StarSight/games_ui_layer/arctic_numberland/shooting_star.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

enum _AuroraColor { red, blue, green, yellow, purple }

extension on _AuroraColor {
  Color get swatch {
    switch (this) {
      case _AuroraColor.red:
        return const Color(0xFFE84855);
      case _AuroraColor.blue:
        return const Color(0xFF4CB8E4);
      case _AuroraColor.green:
        return const Color(0xFF3B873B);
      case _AuroraColor.yellow:
        return const Color(0xFFF9D552);
      case _AuroraColor.purple:
        return const Color(0xFF8E6BC4);
    }
  }

  // Reuses the same color call-out clips as the tree game.
  String get audioAsset {
    const base = 'assets/audio/arctic_numberland';
    switch (this) {
      case _AuroraColor.red:
        return '$base/red.wav';
      case _AuroraColor.blue:
        return '$base/blue.wav';
      case _AuroraColor.green:
        return '$base/green.wav';
      case _AuroraColor.yellow:
        return '$base/yellow.wav';
      case _AuroraColor.purple:
        return '$base/purple.wav';
    }
  }

  String get imageAsset {
    const base = 'assets/images/objects/arctic';
    switch (this) {
      case _AuroraColor.red:
        return '$base/aurora_red.png';
      case _AuroraColor.blue:
        return '$base/aurora_blue.png';
      case _AuroraColor.green:
        return '$base/aurora_green.png';
      case _AuroraColor.yellow:
        return '$base/aurora_yellow.png';
      case _AuroraColor.purple:
        return '$base/aurora_purple.png';
    }
  }
}

class _RoundSpec {
  final List<_AuroraColor> targets; // colors to catch, in order
  final int ribbonCount; // total ribbons on screen (targets + distractors)
  const _RoundSpec({required this.targets, required this.ribbonCount});
}

class _AuroraRibbon {
  final int id;
  final _AuroraColor color;
  final double baseY; // 0..1 vertical band
  final double phase;
  final double speed;
  final double ampY;
  final double driftSpeed;
  final double startX;

  const _AuroraRibbon({
    required this.id,
    required this.color,
    required this.baseY,
    required this.phase,
    required this.speed,
    required this.ampY,
    required this.driftSpeed,
    required this.startX,
  });
}

class AuroraCatcherGame extends StatefulWidget {
  final int level;

  const AuroraCatcherGame({super.key, required this.level});

  @override
  State<AuroraCatcherGame> createState() => _AuroraCatcherGameState();
}

class _AuroraCatcherGameState extends State<AuroraCatcherGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<AuroraCatcherGame>,
        GameLoadingMixin<AuroraCatcherGame>,
        ArcticAudioMixin<AuroraCatcherGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic_night.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _auroraAsset = 'assets/images/objects/arctic/aurora.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/aurora_catch_intro.wav';
  static const String _audioInstruction = '$_audioBase/aurora_catch_instruction.wav';
  static const String _audioWin = '$_audioBase/aurora_catch_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  // Ramp: 1 target -> 2 -> 3 -> 3 -> 4, with more ribbons on screen (more
  // distractors) as rounds progress.
  static const List<_RoundSpec> _rounds = [
    _RoundSpec(targets: [_AuroraColor.red], ribbonCount: 2),
    _RoundSpec(targets: [_AuroraColor.blue, _AuroraColor.yellow], ribbonCount: 3),
    _RoundSpec(targets: [_AuroraColor.green, _AuroraColor.red, _AuroraColor.purple], ribbonCount: 4),
    _RoundSpec(targets: [_AuroraColor.yellow, _AuroraColor.blue, _AuroraColor.green], ribbonCount: 4),
    _RoundSpec(
      targets: [_AuroraColor.purple, _AuroraColor.red, _AuroraColor.blue, _AuroraColor.yellow],
      ribbonCount: 5,
    ),
  ];

  static final int _totalRounds = _rounds.length;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  bool _showWinDialog = false;
  bool _showWinAurora = false;

  late _RoundSpec _round;
  List<_AuroraRibbon> _ribbons = [];
  Set<int> _caughtIds = {};
  int _targetIndex = 0;

  int? _catchingId; // ribbon mid "fly to jar" animation
  int? _wrongId; // ribbon mid "wrong tap" fizzle

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _jarBounceCtrl;

  late final Ticker _skyTicker;
  double _elapsed = 0;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRound(playInstruction: false);
    _skyTicker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed.inMilliseconds / 1000.0);
    })
      ..start();
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
    _sceneEnter = CurvedAnimation(parent: _sceneEnterCtrl, curve: Curves.elasticOut);

    _jarBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) playVoice(_audioInstruction);
  }

  List<_AuroraRibbon> _buildRibbonsForRound(_RoundSpec round) {
    final rng = Random();
    final colors = <_AuroraColor>[...round.targets];
    final remaining = round.ribbonCount - colors.length;
    final pool = _AuroraColor.values.where((c) => !colors.contains(c)).toList()..shuffle(rng);
    colors.addAll(pool.take(remaining));
    colors.shuffle(rng);

    return List.generate(colors.length, (i) {
      final baseY = -0.15 - rng.nextDouble() * 1.0;
      return _AuroraRibbon(
        id: i,
        color: colors[i],
        baseY: baseY,
        phase: rng.nextDouble() * 2 * pi,
        speed: 0.6 + rng.nextDouble() * 0.4,
        ampY: 0.045 + rng.nextDouble() * 0.025,
        driftSpeed: 0.10 + rng.nextDouble() * 0.05,
        startX: 0.1 + rng.nextDouble() * 0.8,
      );
    });
  }

  void _setupRound({bool playInstruction = true}) {
    _round = _rounds[_currentRound];
    _ribbons = _buildRibbonsForRound(_round);
    _caughtIds = {};
    _targetIndex = 0;
    _catchingId = null;
    _wrongId = null;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) playVoice(_audioInstruction);
      });
    }

    setState(() {});
  }

  // ── Ribbon interaction ───────────────────────────────────────────────────
  Offset _ribbonFraction(_AuroraRibbon r) {
    final xFrac = r.startX + 0.03 * sin(_elapsed * r.speed + r.phase);
    final yFrac = ((r.baseY + _elapsed * r.driftSpeed) % 1.3) - 0.15;
    return Offset(xFrac, yFrac);
  }

  Future<void> _onRibbonTapped(_AuroraRibbon ribbon) async {
    if (_caughtIds.contains(ribbon.id) || _catchingId != null) return;
    if (_targetIndex >= _round.targets.length) return;

    final targetColor = _round.targets[_targetIndex];
    if (ribbon.color == targetColor) {
      HapticFeedback.mediumImpact();
      setState(() => _catchingId = ribbon.id);
      await playSfx(ribbon.color.audioAsset);
      showDomaReaction(DomaState.correct);
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() {
        _caughtIds.add(ribbon.id);
        _catchingId = null;
        _targetIndex++;
      });
      _jarBounceCtrl.forward(from: 0);

      if (_targetIndex >= _round.targets.length) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _onRoundComplete();
      }
    } else {
      await playSfx('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);
      HapticFeedback.heavyImpact();
      setState(() => _wrongId = ribbon.id);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _wrongId = null);
    }
  }

  Future<void> _onRoundComplete() async {
    setState(() {
      _solvedRounds++;
    });

    if (_currentRound + 1 >= _totalRounds) {
      setState(() => _showWinAurora = true);
      await playVoice(_audioWin);
      await ArcticProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;
      setState(() {
        _showWinAurora = false;
        _showWinDialog = true;
      });
    } else {
      setState(() => _currentRound++);
      _setupRound(playInstruction: false);
    }
  }

  @override
  void dispose() {
    _skyTicker.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _jarBounceCtrl.dispose();
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
                      colors: [Color(0xFF0B1E3D), Color(0xFF16406B)],
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
            if (_showWinAurora) _buildWinAurora(),
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
                  SizedBox(width: 130),
                  Image.asset(
                    _auroraAsset,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('🌌', style: TextStyle(fontSize: 70)),
                  ),
                ],
              )
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
            Column(
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
                Expanded(
                  child: ScaleTransition(
                    scale: _sceneEnter,
                    child: _buildSkyScene(w, h),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: _buildRoundIndicator(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPromptBanner(double h) {
    final done = _targetIndex >= _round.targets.length;
    final promptColor = done ? null : _round.targets[_targetIndex];

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (promptColor != null) ...[
                Container(
                  width: (h * 0.05).clamp(16.0, 22.0),
                  height: (h * 0.05).clamp(16.0, 22.0),
                  decoration: BoxDecoration(
                    color: promptColor.swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                promptColor == null ? 'Catch the lights!' : 'Catch the light!',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sky scene ────────────────────────────────────────────────────────────
  Widget _buildSkyScene(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: _showWinAurora
            ? []
            : _ribbons
            .where((r) => !_caughtIds.contains(r.id))
            .map((r) => _buildRibbon(r, w, h))
            .toList(),
      ),
    );
  }

  Widget _buildRibbon(_AuroraRibbon ribbon, double w, double h) {
    final ribbonSize = w * 0.14;
    final frac = _ribbonFraction(ribbon);
    final left = frac.dx * w;
    final top = frac.dy * h;

    final catching = _catchingId == ribbon.id;
    final wrong = _wrongId == ribbon.id;

    return Positioned(
      left: left,
      top: top,
      width: ribbonSize,
      height: ribbonSize,
      child: GestureDetector(
        onTap: () => _onRibbonTapped(ribbon),
        child: AnimatedScale(
          scale: catching ? 1.4 : (wrong ? 0.85 : 1.0),
          duration: const Duration(milliseconds: 220),
          child: AnimatedOpacity(
            opacity: catching ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 220),
            child: ColorFiltered(
              colorFilter: wrong
                  ? const ColorFilter.mode(Colors.red, BlendMode.modulate)
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Image.asset(
                ribbon.color.imageAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _ribbonVisual(ribbon.color, ribbonSize, ribbonSize * 0.42, wrong: wrong),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ribbonVisual(_AuroraColor color, double w, double h, {bool wrong = false}) {
    final tint = wrong ? Colors.red.shade300 : color.swatch;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h),
        gradient: LinearGradient(
          colors: [tint.withValues(alpha: 0.55), tint, tint.withValues(alpha: 0.55)],
        ),
        boxShadow: [
          BoxShadow(color: tint.withValues(alpha: 0.6), blurRadius: 14, spreadRadius: 1),
        ],
      ),
    );
  }

  Widget _buildWinAurora() {
    final screenH = MediaQuery.of(context).size.height;
    return Positioned.fill(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (_, value, child) => Transform.scale(scale: value, child: child),
          child: Image.asset(
            _auroraAsset,
            height: screenH * 0.7,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('🌌', style: TextStyle(fontSize: 90)),
          ),
        ),
      ),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
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
                ? ArcticColorTheme.cotton
                : ArcticColorTheme.cotton.withValues(alpha: 0.35),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ShootingStarCountingGame(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedRounds = 0;
          _setupRound();
        });
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}