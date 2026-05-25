import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import '../goodjob_prompt.dart';

enum _ScreenPhase { intro, miniGame }

enum _IntroPhase {
  domaEntering,
  playingIntro,
  playingSayOne,
  listening,
  celebrating,
  done,
}

class NumberOneIntroductionScreen extends StatefulWidget {
  const NumberOneIntroductionScreen({super.key});

  @override
  State<NumberOneIntroductionScreen> createState() =>
      _NumberOneIntroductionScreenState();
}

class _NumberOneIntroductionScreenState
    extends State<NumberOneIntroductionScreen>
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
  String _lastWords = '';

  // ── Mini-game state ────────────────────────────────────────────────────────
  bool _objectTapped = false;
  bool _showWinDialog = false;
  late Offset _objectPos; // randomised each game start

  // ── Shared animations ─────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl; // idle float

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
  late AnimationController _bubbleCtrl;
  late AnimationController _starsCtrl;

  // ── Mini-game animations ──────────────────────────────────────────────────
  late AnimationController _mgTransitionCtrl; // fade intro → game
  late Animation<double> _mgFade;
  late AnimationController _objectWiggleCtrl;
  late AnimationController _objectTapCtrl;
  late Animation<double> _objectTapScale;
  late AnimationController _winCtrl;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _initSpeech();
    _startIntroFlow();
  }

  // ── Animation init ────────────────────────────────────────────────────────
  void _initAnimations() {
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Intro
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

    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Mini-game
    _mgTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _mgFade = CurvedAnimation(parent: _mgTransitionCtrl, curve: Curves.easeIn);

    _objectWiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _objectTapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _objectTapScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _objectTapCtrl, curve: Curves.easeOut));

    _winCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  // ── Speech init ───────────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('STT error: $e'),
    );
  }

  // ── Intro flow ────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _domaSlideCtrl.forward(); // Doma slides in

    _setIntroPhase(_IntroPhase.playingIntro);
    _bubbleCtrl.forward();
    await _playAudio('assets/audio/arctic/level1/one_intro.wav');

    _setIntroPhase(_IntroPhase.playingSayOne);
    _numberPopCtrl.forward();
    _numberDanceCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    _numberDanceCtrl.stop();
    await _playAudio('assets/audio/arctic/level1/say_one.wav');
    await Future.delayed(const Duration(milliseconds: 300));

    _setIntroPhase(_IntroPhase.listening);
    _startListening();
  }

  Future<void> _playAudio(String asset) async {
    try {
      final completer = Completer<void>();
      _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future;
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

    // ← ADD THIS: restart automatically on timeout/done
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
        setState(() => _lastWords = words);
        if (words.contains('one') || words.contains('won')) {
          _speech.stop();
          setState(() => _isListening = false);
          _onWordRecognized();
        }
      },
      onSoundLevelChange: (_) {},
      // keeps session alive on some devices
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
    _starsCtrl.forward(from: 0);

    await _playAudio('assets/audio/arctic/level1/tara_laro.wav');
    await Future.delayed(const Duration(milliseconds: 500));

    // ── Transition to mini game ──────────────────────────────────────────
    _setIntroPhase(_IntroPhase.done);
    _mgTransitionCtrl.forward();
    _randomiseObjectPosition();
    setState(() => _screenPhase = _ScreenPhase.miniGame);
  }

  // ── Mini-game logic ───────────────────────────────────────────────────────
  void _randomiseObjectPosition() {
    final rng = Random();
    // We'll position within a normalised 0-1 box; actual layout uses LayoutBuilder
    _objectPos = Offset(
      0.25 + rng.nextDouble() * 0.50, // 25%–75% horizontally
      0.20 + rng.nextDouble() * 0.45, // 20%–65% vertically
    );
  }

  Future<void> _onObjectTapped() async {
    if (_objectTapped) return;
    setState(() => _objectTapped = true);
    await _objectTapCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() => _showWinDialog = true);
    _winCtrl.forward(from: 0);
    _starsCtrl.forward(from: 0);
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
      _bubbleCtrl,
      _starsCtrl,
      _mgTransitionCtrl,
      _objectWiggleCtrl,
      _objectTapCtrl,
      _winCtrl,
      _numberDanceCtrl,
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
                if (_screenPhase == _ScreenPhase.miniGame)
                  FadeTransition(opacity: _mgFade, child: _buildMiniGame()),
              ],
            ),
          ),

          // ← Win dialog OUTSIDE SafeArea, directly on root Stack
          if (_showWinDialog)
            Positioned.fill(child: _buildGoodJobOverlay()),
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
      child: Row(
        children: [
          Expanded(flex: 4, child: _buildIntroDoma()),
          Expanded(flex: 3, child: _buildIntroNumber()),
          Expanded(flex: 3, child: _buildIntroRight()),
        ],
      ),
    );
  }

  Widget _buildIntroDoma() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final domaH = h * 1.1; // bigger than screen height so body clips out
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _domaFloatCtrl, curve: Curves.easeInOut),
        );

        return ClipRect(
          // clips the lower body
          child: Align(
            alignment: Alignment.bottomCenter,
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

  Widget _buildIntroRight() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_introPhase == _IntroPhase.listening) _buildMicArea(h, w),
            // if (_introPhase == _IntroPhase.celebrating)
            //   _buildCelebrateMessage(h),
          ],
        );
      },
    );
  }

  Widget _buildIntroNumber() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final cardSize = (h * 0.45).clamp(100.0, 160.0); // bigger card

        return Center(
          child:
              _introPhase != _IntroPhase.domaEntering &&
                  _introPhase != _IntroPhase.playingIntro
              ? AnimatedBuilder(
                  animation: _numberDanceCtrl,
                  builder: (_, child) => Transform.rotate(
                    angle: _numberDance.value,
                    child: ScaleTransition(scale: _numberPop, child: child),
                  ),
                  child: _NumberCard(number: 1, size: cardSize),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildMicArea(double h, double w) {
    final micSize = (h * 0.22).clamp(56.0, 90.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Text(
            'Say  "ONE" 🎙️',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: (h * 0.09).clamp(16.0, 26.0),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _micPulseCtrl,
          builder: (_, child) => Transform.scale(
            scale: _isListening ? _micPulse.value : 1.0,
            child: child,
          ),
          child: GestureDetector(
            onTap: _isListening ? null : _startListening,
            child: Container(
              width: micSize,
              height: micSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? const Color(0xFFFF6B6B)
                    : ArcticColorTheme.pictonblue,
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isListening
                                ? const Color(0xFFFF6B6B)
                                : ArcticColorTheme.pictonblue)
                            .withValues(alpha: 0.55),
                    blurRadius: _isListening ? 28 : 14,
                    spreadRadius: _isListening ? 6 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: Colors.white,
                size: micSize * 0.52,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isListening)
          _ListeningRings(controller: _micPulseCtrl, size: micSize),
        if (_lastWords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '"$_lastWords"',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
      ],
    );
  }

  // Widget _buildCelebrateMessage(double h) {
  //   return Column(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       const Text('🎉', style: TextStyle(fontSize: 52)),
  //       const SizedBox(height: 8),
  //       Text(
  //         'Amazing!',
  //         style: TextStyle(
  //           fontFamily: ArcticAppTextStyles.fredoka,
  //           fontSize: (h * 0.12).clamp(24.0, 40.0),
  //           fontWeight: FontWeight.bold,
  //           color: Colors.white,
  //           shadows: const [
  //             Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 3)),
  //           ],
  //         ),
  //       ),
  //       const SizedBox(height: 6),
  //       Text(
  //         'You said ONE! ⭐',
  //         style: TextStyle(
  //           fontFamily: ArcticAppTextStyles.fredoka,
  //           fontSize: (h * 0.08).clamp(16.0, 24.0),
  //           color: Colors.white.withValues(alpha: 0.9),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // ══════════════════════════════════════════════════════════════════════════
  // MINI GAME
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMiniGame() {
    return Positioned.fill(
      top: 50,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final objSize = (h * 0.28).clamp(72.0, 120.0);

          // Absolute position from normalised coords
          final objX = (_objectPos.dx * w - objSize / 2).clamp(
            0.0,
            w - objSize,
          );
          final objY = (_objectPos.dy * h - objSize / 2).clamp(
            60.0,
            h - objSize,
          );

          return Stack(
            children: [
              // Instruction banner
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👆', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          'Tap the Snowman!',
                          style: TextStyle(
                            fontFamily: ArcticAppTextStyles.fredoka,
                            fontSize: (h * 0.09).clamp(16.0, 26.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Color(0x55003366),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Doma watching from the side (small)
              Positioned(
                bottom: 0,
                left: 12,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) {
                    final f = Tween<double>(begin: -5, end: 5).evaluate(
                      CurvedAnimation(
                        parent: _domaFloatCtrl,
                        curve: Curves.easeInOut,
                      ),
                    );
                    return Transform.translate(
                      offset: Offset(0, f),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/images/characters/doma_the_penguin.png',
                    height: (h * 0.38).clamp(70.0, 130.0),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _FallbackDoma(height: (h * 0.38).clamp(70.0, 130.0)),
                  ),
                ),
              ),

              // The tappable object
              if (!_objectTapped)
                Positioned(
                  left: objX,
                  top: objY,
                  child: AnimatedBuilder(
                    animation: _objectWiggleCtrl,
                    builder: (_, child) {
                      final wiggle = (_objectWiggleCtrl.value - 0.5) * 10;
                      return Transform.translate(
                        offset: Offset(0, wiggle),
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onTap: _onObjectTapped,
                      child: Container(
                        width: objSize,
                        height: objSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ArcticColorTheme.pictonblue,
                          boxShadow: [
                            BoxShadow(
                              color: ArcticColorTheme.pictonblue.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(objSize * 0.12),
                          child: Image.asset(
                            'assets/images/objects/arctic/snowman.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('', style: TextStyle(fontSize: 40)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Tap burst (scale-out on tap)
              if (_objectTapped &&
                  _objectTapCtrl.status != AnimationStatus.completed)
                Positioned(
                  left: objX,
                  top: objY,
                  child: ScaleTransition(
                    scale: _objectTapScale,
                    child: Container(
                      width: objSize,
                      height: objSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.yellow.withValues(alpha: 0.7),
                      ),
                      child: const Center(
                        child: Text('⭐', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIN DIALOG
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGoodJobOverlay() {
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: const Color(0xFF4A90D9),
      // or your arctic blue
      onNext: () {
        // TODO: @Tin push to your next level screen
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(builder: (_) => const NextLevelScreen()),
        // );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NumberOneIntroductionScreen()),
        );
      },
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ArcticLevelScreen()),
          (route) => false,
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
      height: size,
      child: Center(
        child: Image.asset(
          'assets/fonts/game_numbers/$number.png',
          width: size * 0.65,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            '$number',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: size * 0.65,
              fontWeight: FontWeight.bold,
              color: ArcticColorTheme.pictonblue,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio waveform
// ─────────────────────────────────────────────────────────────────────────────
class _AudioWaveform extends StatefulWidget {
  const _AudioWaveform();

  @override
  State<_AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<_AudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        const heights = [12.0, 20.0, 28.0, 20.0, 12.0];
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final h =
                heights[i] * (0.5 + 0.5 * sin((_ctrl.value + i * 0.2) * pi));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5,
              height: h.clamp(4.0, 28.0),
              decoration: BoxDecoration(
                color: ArcticColorTheme.pictonblue,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Listening rings
// ─────────────────────────────────────────────────────────────────────────────
class _ListeningRings extends StatelessWidget {
  final AnimationController controller;
  final double size;

  const _ListeningRings({required this.controller, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return SizedBox(
          width: size * 2.2,
          height: size * 1.2,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(3, (i) {
              final scale = 1.0 + controller.value * 0.4 * (i + 1) * 0.35;
              final opacity =
                  (1.0 - controller.value * 0.6).clamp(0.0, 1.0) / (i + 1);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withValues(alpha: opacity),
                      width: 2.5,
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
