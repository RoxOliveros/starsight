import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

enum _RoundPhase { watching, answering }

class _RoundSpec {
  final int starCount; // correct answer for this round
  final int optionCount; // how many number buttons to show
  const _RoundSpec({required this.starCount, required this.optionCount});
}


class _StarSpec {
  final int id;
  final double startTime;
  final double duration;
  final Offset start;
  final Offset control;
  final Offset end;
  const _StarSpec({
    required this.id,
    required this.startTime,
    required this.duration,
    required this.start,
    required this.control,
    required this.end,
  });
}

Offset _bezierPoint(Offset p0, Offset p1, Offset p2, double t) {
  final mt = 1 - t;
  return Offset(
    mt * mt * p0.dx + 2 * mt * t * p1.dx + t * t * p2.dx,
    mt * mt * p0.dy + 2 * mt * t * p1.dy + t * t * p2.dy,
  );
}

Offset _bezierTangent(Offset p0, Offset p1, Offset p2, double t) {
  final mt = 1 - t;
  return Offset(
    2 * mt * (p1.dx - p0.dx) + 2 * t * (p2.dx - p1.dx),
    2 * mt * (p1.dy - p0.dy) + 2 * t * (p2.dy - p1.dy),
  );
}

class ShootingStarCountingGame extends StatefulWidget {
  final int level;

  const ShootingStarCountingGame({super.key, required this.level});

  @override
  State<ShootingStarCountingGame> createState() => _ShootingStarCountingGameState();
}

class _ShootingStarCountingGameState extends State<ShootingStarCountingGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<ShootingStarCountingGame>,
        GameLoadingMixin<ShootingStarCountingGame>,
        ArcticAudioMixin<ShootingStarCountingGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic_night.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _shootingStarAsset = 'assets/images/objects/arctic/shooting_star.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/shooting_star_intro.wav';
  static const String _audioInstruction = '$_audioBase/shooting_star_instruction.wav';
  static const String _audioAskCount = '$_audioBase/shooting_star_ask.wav';
  static const String _audioWin = '$_audioBase/shooting_star_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  static const List<_RoundSpec> _rounds = [
    _RoundSpec(starCount: 2, optionCount: 3),
    _RoundSpec(starCount: 3, optionCount: 3),
    _RoundSpec(starCount: 4, optionCount: 4),
    _RoundSpec(starCount: 5, optionCount: 4),
    _RoundSpec(starCount: 6, optionCount: 4),
  ];

  static final int _totalRounds = _rounds.length;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  bool _showWinDialog = false;
  bool _showWinBurst = false;

  late _RoundSpec _round;
  List<_StarSpec> _starSchedule = [];
  double _roundStartElapsed = 0;
  double _roundTotalDuration = 0; // schedule end + tail buffer, in seconds

  _RoundPhase _phase = _RoundPhase.watching;
  List<int> _answerOptions = [];
  int? _selectedAnswer;
  bool _answerLocked = false;
  bool _wasWrong = false;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;

  late final Ticker _skyTicker;
  double _elapsed = 0;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRound(playInstruction: false);
    _skyTicker = createTicker((elapsed) {
      final t = elapsed.inMilliseconds / 1000.0;
      setState(() => _elapsed = t);
      _checkPhaseTransition(t);
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

  // Builds a fixed schedule of stars with randomized gaps/paths, and works
  // out how long the whole round will take to play out.
  List<_StarSpec> _buildScheduleForRound(_RoundSpec round) {
    final rng = Random();
    final specs = <_StarSpec>[];
    double t = 0.6; // small delay before the first star appears
    for (int i = 0; i < round.starCount; i++) {
      final duration = 1.5 + rng.nextDouble() * 0.8;

      // Always top-left -> bottom-right, with some randomized spread so
      // stars don't all trace the exact same line.
      final start = Offset(
        rng.nextDouble() * 0.3, // 0.0 .. 0.3
        -0.15 - rng.nextDouble() * 0.15, // just above the top edge
      );
      final end = Offset(
        0.65 + rng.nextDouble() * 0.35, // 0.65 .. 1.0
        1.05 + rng.nextDouble() * 0.15, // just below the bottom edge
      );

      // Bow the control point toward the start's height so the star stays
      // high and mostly horizontal at first, then curves down and
      // accelerates into the fall -- a parabolic arc rather than a straight line.
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final bow = 0.12 + rng.nextDouble() * 0.1;
      final control = Offset(mid.dx, start.dy + (end.dy - start.dy) * bow);

      specs.add(_StarSpec(
        id: i,
        startTime: t,
        duration: duration,
        start: start,
        control: control,
        end: end,
      ));
      t += duration * 0.4 + 0.5 + rng.nextDouble() * 0.7; // stagger next star
    }
    return specs;
  }

  void _setupRound({bool playInstruction = true}) {
    _round = _rounds[_currentRound];
    _starSchedule = _buildScheduleForRound(_round);
    final last = _starSchedule.last;
    _roundTotalDuration = last.startTime + last.duration + 0.6; // tail buffer
    _roundStartElapsed = _elapsed;
    _phase = _RoundPhase.watching;
    _answerOptions = [];
    _selectedAnswer = null;
    _answerLocked = false;
    _wasWrong = false;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) playVoice(_audioInstruction);
      });
    }

    setState(() {});
  }

  void _checkPhaseTransition(double t) {
    if (_phase != _RoundPhase.watching) return;
    if (t - _roundStartElapsed >= _roundTotalDuration) {
      setState(() {
        _phase = _RoundPhase.answering;
        _answerOptions = _buildAnswerOptions(_round.starCount, _round.optionCount);
      });
      playVoice(_audioAskCount);
    }
  }

  List<int> _buildAnswerOptions(int correct, int count) {
    final rng = Random();
    final options = <int>{correct};
    while (options.length < count) {
      final delta = rng.nextInt(4) + 1; // 1..4 away
      final candidate = rng.nextBool() ? correct + delta : correct - delta;
      if (candidate >= 1) options.add(candidate);
    }
    final list = options.toList()..shuffle(rng);
    return list;
  }

  // ── Answer interaction ───────────────────────────────────────────────────
  Future<void> _onAnswerTapped(int value) async {
    if (_answerLocked) return;
    setState(() {
      _answerLocked = true;
      _selectedAnswer = value;
    });

    final correct = value == _round.starCount;
    if (correct) {
      HapticFeedback.mediumImpact();
      showDomaReaction(DomaState.correct);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await _onRoundComplete();
    } else {
      HapticFeedback.heavyImpact();
      await playSfx('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);
      setState(() => _wasWrong = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _selectedAnswer = null;
        _answerLocked = false;
        _wasWrong = false;
      });
    }
  }

  Future<void> _onRoundComplete() async {
    setState(() => _solvedRounds++);

    if (_currentRound + 1 >= _totalRounds) {
      setState(() => _showWinBurst = true);
      await playVoice(_audioWin);
      if (!mounted) return;
      setState(() {
        _showWinBurst = false;
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
            child:
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  _characterImage,
                  height: screenH * 0.7,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                  const Text('🐧', style: TextStyle(fontSize: 70)),
                ),
                SizedBox(width: 130),
                Image.asset(
                  _shootingStarAsset,
                  height: screenH * 0.4,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                  const Text('🐧', style: TextStyle(fontSize: 70)),
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
                  child: _phase == _RoundPhase.answering
                      ? _buildAnswerPanel(h)
                      : _buildRoundIndicator(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPromptBanner(double h) {
    final watching = _phase == _RoundPhase.watching;
    final text = watching ? 'Watch the shooting stars!' : 'How many did you count?';

    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => playVoice(watching ? _audioInstruction : _audioAskCount),
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
            text,
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sky scene ────────────────────────────────────────────────────────────
  Widget _buildSkyScene(double w, double h) {
    final roundElapsed = _elapsed - _roundStartElapsed;
    final visible = _phase == _RoundPhase.watching
        ? _starSchedule.where((s) {
      final t = roundElapsed - s.startTime;
      return t >= 0 && t <= s.duration;
    }).toList()
        : <_StarSpec>[];

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: visible.map((s) => _buildStar(s, w, h, roundElapsed - s.startTime)).toList(),
      ),
    );
  }

  Widget _buildStar(_StarSpec spec, double w, double h, double t) {
    final progress = (t / spec.duration).clamp(0.0, 1.0);
    final pos = _bezierPoint(spec.start, spec.control, spec.end, progress);
    final fade = progress < 0.15
        ? progress / 0.15
        : progress > 0.85
        ? (1 - progress) / 0.15
        : 1.0;
    final tangent = _bezierTangent(spec.start, spec.control, spec.end, progress);
    final angle = atan2(tangent.dy, tangent.dx);
    final starSize = w * 0.15;

    return Positioned(
      left: pos.dx * w,
      top: pos.dy * h,
      width: starSize,
      height: starSize,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle,
          child: Image.asset(
            _shootingStarAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('🌠', style: TextStyle(fontSize: 34)),
          ),
        ),
      ),
    );
  }

  // ── Answer panel ─────────────────────────────────────────────────────────
  Widget _buildAnswerPanel(double h) {
    final buttonSize = (h * 0.18).clamp(48.0, 72.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _answerOptions.map((value) {
        final selected = _selectedAnswer == value;
        final isCorrectSelection = selected && !_wasWrong;
        final isWrongSelection = selected && _wasWrong;

        Color bg = Colors.white.withValues(alpha: 0.92);
        if (isCorrectSelection) bg = ArcticColorTheme.cadetblue;
        if (isWrongSelection) bg = Colors.red.shade300;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureDetector(
            onTap: () => _onAnswerTapped(value),
            child: AnimatedScale(
              scale: selected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: ArcticColorTheme.pictonblue, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontSize: buttonSize * 0.42,
                    fontWeight: FontWeight.bold,
                    color: ArcticColorTheme.slateblue,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
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

  // ── Win burst (shown while win audio plays) ──────────────────────────────
  Widget _buildWinBurst() {
    final screenH = MediaQuery.of(context).size.height;
    return Positioned.fill(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (_, value, child) => Transform.scale(scale: value, child: child),
          child: Image.asset(
            _shootingStarAsset,
            height: screenH * 0.6,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('✨', style: TextStyle(fontSize: 90)),
          ),
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
        // TODO: navigate to next game
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