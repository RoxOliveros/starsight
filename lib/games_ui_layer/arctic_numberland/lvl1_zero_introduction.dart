import 'dart:async';
import 'dart:math';
import 'package:StarSight/games_ui_layer/arctic_numberland/lvl2_one_introduction.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import '../goodjob_prompt.dart';

enum _ScreenPhase { intro, tracing }

enum _IntroPhase {
  domaEntering,
  playingIntro,
  playingSayZero,
  listening,
  celebrating,
  done,
}

class NumberZeroIntroductionScreen extends StatefulWidget {
  const NumberZeroIntroductionScreen({super.key});

  @override
  State<NumberZeroIntroductionScreen> createState() =>
      _NumberZeroIntroductionScreenState();
}

class _NumberZeroIntroductionScreenState
    extends State<NumberZeroIntroductionScreen>
    with TickerProviderStateMixin {
  // ── Top-level phase ────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  _IntroPhase _introPhase = _IntroPhase.domaEntering;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Speech ─────────────────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _recognized = false;

  // ── Tracing ────────────────────────────────────────────────────────────────
  final List<Offset> _tracedPoints = [];
  bool _tracingComplete = false;
  Offset? _canePosition;
  bool _showWinDialog = false;

  // ── Shared animations ─────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;

  // ── Intro animations ──────────────────────────────────────────────────────
  late AnimationController _domaSlideCtrl;
  late Animation<Offset> _domaSlide;
  late Animation<double> _domaFade;
  late AnimationController _celebrateCtrl;
  late Animation<double> _celebrateScale;
  late AnimationController _micPulseCtrl;
  late Animation<double> _micPulse;
  late AnimationController _numberPopCtrl;
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;
  late Animation<double> _numberPop;

  // ── Tracing animations ────────────────────────────────────────────────────
  late AnimationController _mgTransitionCtrl;
  late Animation<double> _mgFade;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _initSpeech();
    _startIntroFlow();
  }

  void _initAnimations() {
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _domaSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _domaSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _domaSlideCtrl, curve: Curves.elasticOut),
        );
    _domaFade = CurvedAnimation(
      parent: _domaSlideCtrl,
      curve: const Interval(0, 0.4),
    );

    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebrateScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.08), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _celebrateCtrl, curve: Curves.easeOut));

    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _micPulse = Tween<double>(
      begin: 1.0,
      end: 1.22,
    ).animate(CurvedAnimation(parent: _micPulseCtrl, curve: Curves.easeInOut));

    _numberPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _numberPop = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _numberPopCtrl, curve: Curves.easeOut));

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    _mgTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _mgFade = CurvedAnimation(parent: _mgTransitionCtrl, curve: Curves.easeIn);
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('STT error: $e'),
    );
  }

  // ── Intro flow ────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _domaSlideCtrl.forward();

    _setIntroPhase(_IntroPhase.playingIntro);
    await _playAudio('assets/audio/arctic/level1/zero_intro.wav');

    _setIntroPhase(_IntroPhase.playingSayZero);
    _numberPopCtrl.forward();
    _numberDanceCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    await _playAudio('assets/audio/arctic/level1/say_zero.wav');
    await Future.delayed(const Duration(milliseconds: 300));

    _setIntroPhase(_IntroPhase.listening);
    _startListening();
    _numberDanceCtrl.stop();
  }

  Future<void> _playAudio(String asset) async {
    try {
      final completer = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future;
      await sub.cancel();
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _setIntroPhase(_IntroPhase p) {
    if (!mounted) return;
    setState(() => _introPhase = p);
  }

  // ── Speech ────────────────────────────────────────────────────────────────
  void _startListening() {
    if (!_speechAvailable) {
      Future.delayed(const Duration(seconds: 6), _onWordRecognized);
      return;
    }

    _speech.statusListener = (status) {
      if (!mounted) return;
      if (status == 'done' || status == 'notListening') {
        if (_isListening && _introPhase == _IntroPhase.listening) {
          Future.delayed(const Duration(milliseconds: 500), _startListening);
        }
      }
    };

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        if (words.contains('zero') || words.contains('hero')) {
          _speech.stop();
          setState(() => _isListening = false);
          _onWordRecognized();
        }
      },
      onSoundLevelChange: (_) {},
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 15),
      localeId: 'en_US',
    );
  }

  Future<void> _onWordRecognized() async {
    if (_recognized) return;
    _recognized = true;

    _setIntroPhase(_IntroPhase.celebrating);
    _celebrateCtrl.forward(from: 0);

    await _playAudio('assets/audio/arctic/level1/now_you_know_zero.wav');
    await Future.delayed(const Duration(milliseconds: 500));

    _setIntroPhase(_IntroPhase.done);
    _mgTransitionCtrl.forward();
    setState(() => _screenPhase = _ScreenPhase.tracing);
    await _playAudio('assets/audio/arctic/level1/write_zero.wav');
  }

  // ── Tracing logic ─────────────────────────────────────────────────────────
  void _checkTracingComplete(double w, double h) {
    final validPoints = _tracedPoints
        .where((p) => p != const Offset(-1, -1))
        .toList();

    if (validPoints.length < 40) return;

    // Zero is a closed oval — check it covers both vertical and horizontal range
    final ys = validPoints.map((p) => p.dy).toList();
    final xs = validPoints.map((p) => p.dx).toList();
    final traceH = h * 0.55;
    final traceW = traceH * 0.5; // matches traceW = numberSize * 0.5

    final verticalCoverage = (ys.reduce(max) - ys.reduce(min)) / traceH;
    final horizontalCoverage = (xs.reduce(max) - xs.reduce(min)) / traceW;

    if (verticalCoverage < 0.50) return;
    if (horizontalCoverage < 0.40) return;

    // Must have points in both top and bottom halves (closed loop)
    final topPoints = validPoints.where((p) => p.dy < traceH * 0.5).length;
    final bottomPoints = validPoints.where((p) => p.dy >= traceH * 0.5).length;
    if (topPoints < 3 || bottomPoints < 3) return;

    _onTracingAccepted();
  }

  Future<void> _onTracingAccepted() async {
    if (_tracingComplete) return;
    setState(() => _tracingComplete = true);
    await _playAudio('assets/audio/arctic/mahusay.wav');
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _showWinDialog = true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _player.dispose();
    _speech.stop();
    for (final c in [
      _domaFloatCtrl,
      _domaSlideCtrl,
      _celebrateCtrl,
      _micPulseCtrl,
      _numberPopCtrl,
      _numberDanceCtrl,
      _mgTransitionCtrl,
    ]) {
      c.dispose();
    }
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_arctic.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(top: 8, left: 12, child: ArcticBackButton()),
                if (_screenPhase == _ScreenPhase.intro) _buildIntroContent(),
                if (_screenPhase == _ScreenPhase.tracing)
                  FadeTransition(
                    opacity: _mgFade,
                    child: _buildTracingScreen(),
                  ),
              ],
            ),
          ),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO CONTENT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildIntroContent() {
    return Positioned.fill(
      top: 50,
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.38,
                    child: _buildIntroDoma(),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.28,
                    child: _buildIntroNumber(),
                  ),
                ),
              ),
            ],
          ),
          if (_introPhase == _IntroPhase.listening)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: _buildBottomListeningPrompt(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntroDoma() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final domaH = h * 1.1;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _domaFloatCtrl, curve: Curves.easeInOut),
        );

        return ClipRect(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SlideTransition(
              position: _domaSlide,
              child: FadeTransition(
                opacity: _domaFade,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      0,
                      _introPhase == _IntroPhase.celebrating ? 0 : floatY,
                    ),
                    child: child,
                  ),
                  child: ScaleTransition(
                    scale: _introPhase == _IntroPhase.celebrating
                        ? _celebrateScale
                        : const AlwaysStoppedAnimation(1.0),
                    child: Image.asset(
                      'assets/images/characters/doma_the_penguin.png',
                      height: domaH,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          _FallbackDoma(height: domaH),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomListeningPrompt() {
    return AnimatedBuilder(
      animation: _micPulseCtrl,
      builder: (_, child) => Transform.scale(
        scale: _isListening ? _micPulse.value : 1.0,
        child: child,
      ),
      child: GestureDetector(
        onTap: _isListening ? null : _startListening,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 34,
              ),
              const SizedBox(width: 10),
              Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.multitrack_audio_rounded,
                color: Colors.white,
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroNumber() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final cardSize = (h * 0.5).clamp(100.0, 160.0);

        return Align(
          alignment: Alignment.center,
          child:
              _introPhase != _IntroPhase.domaEntering &&
                  _introPhase != _IntroPhase.playingIntro
              ? AnimatedBuilder(
                  animation: _numberDanceCtrl,
                  builder: (_, child) => Transform.rotate(
                    angle: _numberDance.value,
                    child: ScaleTransition(scale: _numberPop, child: child),
                  ),
                  child: _NumberCard(number: 0, size: cardSize),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRACING SCREEN
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTracingScreen() {
    return Positioned.fill(
      top: 50,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return _buildTracingLayer(w, h);
        },
      ),
    );
  }

  Widget _buildTracingLayer(double w, double h) {
    final caneSize = h * 0.14;
    final numberSize = h * 0.55;

    final centerX = w / 2;
    final centerY = h / 2;
    final traceW = numberSize * 0.5;
    final traceH = numberSize;
    final traceLeft = centerX - traceW / 2;
    final traceTop = centerY - traceH / 2;

    return Stack(
      children: [
        // Progress bar
        if (_tracedPoints.where((p) => p != const Offset(-1, -1)).length > 5)
          Positioned(
            bottom: h * 0.06,
            left: w * 0.15,
            right: w * 0.15,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor:
                          (_tracedPoints
                                      .where((p) => p != const Offset(-1, -1))
                                      .length /
                                  40)
                              .clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          gradient: LinearGradient(
                            colors: _tracingComplete
                                ? [Colors.greenAccent, Colors.green]
                                : [
                                    ArcticColorTheme.pictonblue,
                                    ArcticColorTheme.slateblue,
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_tracingComplete
                                          ? Colors.greenAccent
                                          : ArcticColorTheme.pictonblue)
                                      .withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      left: 6,
                      right: 6,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Instruction banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: ArcticColorTheme.pictonblue.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✏️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    'Trace the number 0!',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: (h * 0.09).clamp(14.0, 22.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Tracing image
        Positioned(
          left: traceLeft,
          top: traceTop,
          width: traceW,
          height: traceH,
          child: Image.asset(
            'assets/fonts/game_numbers/0_tracing.png',
            fit: BoxFit.contain,
          ),
        ),

        // Gesture + user trace layer
        Positioned(
          left: traceLeft,
          top: traceTop,
          width: traceW,
          height: traceH,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _tracedPoints.add(details.localPosition);
                _canePosition = Offset(
                  traceLeft + details.localPosition.dx,
                  traceTop + details.localPosition.dy,
                );
              });
              _checkTracingComplete(w, h);
            },
            onPanEnd: (_) {
              setState(() {
                _tracedPoints.add(const Offset(-1, -1));
              });
            },
            child: CustomPaint(
              size: Size(traceW, traceH),
              painter: _UserTracePainter(
                tracedPoints: _tracedPoints,
                isComplete: _tracingComplete,
              ),
            ),
          ),
        ),

        // Cane follows finger
        if (_canePosition != null)
          Positioned(
            left: _canePosition!.dx - caneSize * 0.15,
            top: _canePosition!.dy - caneSize * 0.92,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/objects/arctic/sugarcane.png',
                width: caneSize,
                fit: BoxFit.contain,
              ),
            ),
          ),

        // Cane resting position
        if (_canePosition == null && !_tracingComplete)
          Positioned(
            bottom: h * 0.08,
            left: w * 0.06,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/objects/arctic/sugarcane.png',
                width: caneSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIN DIALOG
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGoodJobOverlay() {
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const NumberOneIntroductionScreen(),
          ),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const NumberZeroIntroductionScreen(),
          ),
        );
      },
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ArcticLevelScreen()),
          (route) => route.isFirst,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Number Card
// ─────────────────────────────────────────────────────────────────────────────
class _NumberCard extends StatelessWidget {
  final int number;
  final double size;

  const _NumberCard({required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/fonts/game_numbers/0.png',
            width: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              '0',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: size * 0.75,
                fontWeight: FontWeight.bold,
                color: ArcticColorTheme.pictonblue,
              ),
            ),
          ),
          SizedBox(height: size * 0.05),
          Text(
            'ZERO',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: size * 0.26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Trace Painter
// ─────────────────────────────────────────────────────────────────────────────
class _UserTracePainter extends CustomPainter {
  final List<Offset> tracedPoints;
  final bool isComplete;

  _UserTracePainter({required this.tracedPoints, required this.isComplete});

  @override
  void paint(Canvas canvas, Size size) {
    if (tracedPoints.length < 2) return;

    final tracePaint = Paint()
      ..color = isComplete ? Colors.greenAccent : Colors.yellowAccent
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool newStroke = true;
    for (final p in tracedPoints) {
      if (p == const Offset(-1, -1)) {
        newStroke = true;
      } else if (newStroke) {
        path.moveTo(p.dx, p.dy);
        newStroke = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, tracePaint);
  }

  @override
  bool shouldRepaint(_UserTracePainter old) =>
      old.tracedPoints != tracedPoints || old.isComplete != isComplete;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback Doma
// ─────────────────────────────────────────────────────────────────────────────
class _FallbackDoma extends StatelessWidget {
  final double height;

  const _FallbackDoma({required this.height});

  @override
  Widget build(BuildContext context) =>
      Text('🐧', style: TextStyle(fontSize: height * 0.7));
}
