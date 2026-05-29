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
import 'lvl10_four_introduction.dart';
import 'number_tracing_widget.dart';

enum _ScreenPhase { intro, miniGame }

enum _IntroPhase {
  domaEntering,
  playingIntro,
  playingSayTwo,
  listening,
  celebrating,
  done,
}

enum _MiniGamePhase { tracing, tapping }

class NumberThreeIntroductionScreen extends StatefulWidget {
  const NumberThreeIntroductionScreen({super.key});

  @override
  State<NumberThreeIntroductionScreen> createState() =>
      _NumberThreeIntroductionScreenState();
}

class _NumberThreeIntroductionScreenState
    extends State<NumberThreeIntroductionScreen>
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
  Timer? _listenRestartTimer;

  // ── Mini-game state ────────────────────────────────────────────────────────
  int _iceCreamsTapped = 0;
  static const int _targetCount = 3;
  bool _showWinDialog = false;
  late Offset _objectPos;
  late Offset _objectPos2;
  late Offset _objectPos3;
  bool _wrongTapped = false;
  late Offset _decoyPos;
  late String _decoyAsset;
  late String _decoyEmoji;
  Offset? _lastTappedPos;

  // ── Tracing ────────────────────────────────────────────────────────
  _MiniGamePhase _miniGamePhase = _MiniGamePhase.tracing;

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

  // ── Mini-game animations ──────────────────────────────────────────────────
  late AnimationController _mgTransitionCtrl;
  late Animation<double> _mgFade;
  late AnimationController _objectWiggleCtrl;
  late AnimationController _objectTapCtrl;
  late Animation<double> _objectTapScale;

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
    _domaSlideCtrl.forward();

    _setIntroPhase(_IntroPhase.playingIntro);
    await _playAudio('assets/audio/arctic_numberland/level9/three_intro.wav');

    _setIntroPhase(_IntroPhase.playingSayTwo);
    _numberPopCtrl.forward();
    _numberDanceCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    await _playAudio('assets/audio/arctic_numberland/level9/say_three.wav');
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

    if (!mounted || _introPhase != _IntroPhase.listening) return;

    _speech.statusListener = (status) {
      if (!mounted) return;
      if ((status == 'done' || status == 'notListening') &&
          _introPhase == _IntroPhase.listening &&
          !_recognized) {
        // Cancel any pending restart, schedule a new one
        _listenRestartTimer?.cancel();
        _listenRestartTimer = Timer(
          const Duration(milliseconds: 100),
          _startListening,
        ); // shorter gap
      }
    };

    if (_speech.isListening) return; // already listening, don't double-start

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return; // only act on final results
        final words = result.recognizedWords.toLowerCase();
        if (words.contains('three') ||
            words.contains('tree') ||
            words.contains('thre') ||
            words.contains('tri') ||
            words.contains('cri') ||
            words.contains('cree') ||
            words.contains('free')) {
          _listenRestartTimer?.cancel();
          _speech.stop();
          setState(() => _isListening = false);
          _onWordRecognized();
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  Future<void> _onWordRecognized() async {
    if (_recognized) return;
    _recognized = true;

    _setIntroPhase(_IntroPhase.celebrating);
    _celebrateCtrl.forward(from: 0);

    await _playAudio('assets/audio/arctic_numberland/magaling.wav');
    await Future.delayed(const Duration(milliseconds: 500));

    // ── Transition to mini game ──────────────────────────────────────────
    _setIntroPhase(_IntroPhase.done);
    _mgTransitionCtrl.forward();
    _randomiseObjectPosition();
    setState(() => _screenPhase = _ScreenPhase.miniGame);
    await _playAudio('assets/audio/arctic_numberland/level9/write_three.wav');
  }

  // ── Mini-game logic ───────────────────────────────────────────────────────
  void _randomiseObjectPosition() {
    final rng = Random();

    // Spread 3 objects vertically in the right half
    final ySlots = [0.15, 0.38, 0.62, 0.82]..shuffle(rng);

    _objectPos = Offset(0.58 + rng.nextDouble() * 0.30, ySlots[0]);
    _objectPos2 = Offset(0.58 + rng.nextDouble() * 0.30, ySlots[1]);
    _objectPos3 = Offset(0.58 + rng.nextDouble() * 0.30, ySlots[2]);
    _decoyPos = Offset(0.58 + rng.nextDouble() * 0.30, ySlots[3]);

    final useSled = Random().nextBool();
    _decoyAsset = useSled
        ? 'assets/images/objects/arctic/sled.png'
        : 'assets/images/objects/arctic/snowy_tree.png';
    _decoyEmoji = useSled ? '🛷' : '🌲';
  }

  // Add parameter: isFirst, isSecond, isThird — or use an index instead
  // Simplest: switch to an index-based approach:

  final List<bool> _iceCreamTapped = [false, false, false];

  void _onObjectTapped(Offset tappedPos, {required int index}) async {
    if (_iceCreamsTapped >= _targetCount) return;
    if (_iceCreamTapped[index]) return;
    setState(() {
      _iceCreamsTapped++;
      _lastTappedPos = tappedPos;
      _iceCreamTapped[index] = true;
    });
    _objectTapCtrl.forward(from: 0);
    if (_iceCreamsTapped >= _targetCount) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _showWinDialog = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _speech.stop();
    _listenRestartTimer?.cancel();
    for (final c in [
      _domaFloatCtrl,
      _domaSlideCtrl,
      _celebrateCtrl,
      _micPulseCtrl,
      _numberPopCtrl,
      _mgTransitionCtrl,
      _objectWiggleCtrl,
      _objectTapCtrl,
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
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  Widget _buildObjectCircle(
    double size,
    String asset,
    String emoji,
    bool isWrong,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ArcticColorTheme.pictonblue.withValues(
          alpha: isWrong ? 1.0 : 0.85,
        ),
        border: Border.all(
          color: isWrong ? Colors.red : Colors.white,
          width: isWrong ? 4 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Text(emoji, style: const TextStyle(fontSize: 40)),
        ),
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
              // LEFT SIDE — Penguin
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.38,
                    child: _buildIntroDoma(),
                  ),
                ),
              ),

              // RIGHT SIDE — Number
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

          // Listening prompt
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
          // clips the lower body
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
              Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 34),

              const SizedBox(width: 10),

              Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: Colors.white,
                size: 30,
              ),

              const SizedBox(width: 10),

              Icon(
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
                  child: _NumberCard(number: 3, size: cardSize),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

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

          return Stack(
            children: [
              if (_miniGamePhase == _MiniGamePhase.tracing)
                NumberTracingWidget(
                  number: 3,
                  player: _player,
                  successAudio: 'assets/audio/arctic_numberland/mahusay.wav',
                  onComplete: () {
                    setState(() => _miniGamePhase = _MiniGamePhase.tapping);
                    _playAudio(
                      'assets/audio/arctic_numberland/level9/count_three_tree.wav',
                    );
                  },
                )
              else ...[
                // Instruction banner — anchored top center
                Positioned(
                  top: 0,
                  left: w * 0.35,
                  right: 0,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ArcticColorTheme.pictonblue.withValues(
                          alpha: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('👆', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(
                            'Tap THREE Tree!',
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

                // Number card — left side
                Positioned(
                  left: w * 0.08,
                  top: h * 0.5 - (h * 0.30) / 2,
                  child: _NumberCard(number: 3, size: h * 0.3),
                ),

                // ── Ice Cream (correct) ──
                if (!_iceCreamTapped[0])
                  Positioned(
                    left: (_objectPos.dx * w - objSize / 2).clamp(
                      w * 0.55,
                      w - objSize,
                    ),
                    top: (_objectPos.dy * h - objSize / 2).clamp(
                      h * 0.25,
                      h - objSize,
                    ),
                    child: AnimatedBuilder(
                      animation: _objectWiggleCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, (_objectWiggleCtrl.value - 0.5) * 10),
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: () => _onObjectTapped(_objectPos, index: 0),
                        child: _buildObjectCircle(
                          objSize,
                          'assets/images/objects/arctic/snowy_tree.png',
                          '🌲',
                          false,
                        ),
                      ),
                    ),
                  ),

                if (!_iceCreamTapped[1])
                  Positioned(
                    left: (_objectPos2.dx * w - objSize / 2).clamp(
                      w * 0.55,
                      w - objSize,
                    ),
                    top: (_objectPos2.dy * h - objSize / 2).clamp(
                      h * 0.20,
                      h - objSize,
                    ),
                    child: AnimatedBuilder(
                      animation: _objectWiggleCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, (_objectWiggleCtrl.value - 0.5) * 10),
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: () => _onObjectTapped(_objectPos2, index: 1),
                        child: _buildObjectCircle(
                          objSize,
                          'assets/images/objects/arctic/snowy_tree.png',
                          '🌲',
                          false,
                        ),
                      ),
                    ),
                  ),

                if (!_iceCreamTapped[2])
                  Positioned(
                    left: (_objectPos3.dx * w - objSize / 2).clamp(
                      w * 0.55,
                      w - objSize,
                    ),
                    top: (_objectPos3.dy * h - objSize / 2).clamp(
                      h * 0.20,
                      h - objSize,
                    ),
                    child: AnimatedBuilder(
                      animation: _objectWiggleCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, (_objectWiggleCtrl.value - 0.5) * 10),
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: () => _onObjectTapped(_objectPos3, index: 2),
                        child: _buildObjectCircle(
                          objSize,
                          'assets/images/objects/arctic/snowy_tree.png',
                          '🍦',
                          false,
                        ),
                      ),
                    ),
                  ),

                // tap burst
                if (_iceCreamsTapped > 0 &&
                    _lastTappedPos != null &&
                    _objectTapCtrl.status != AnimationStatus.completed)
                  Positioned(
                    left: (_lastTappedPos!.dx * w - objSize / 2).clamp(
                      w * 0.55,
                      w - objSize,
                    ),
                    top: (_lastTappedPos!.dy * h - objSize / 2).clamp(
                      h * 0.20,
                      h - objSize,
                    ),
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

                if (_iceCreamsTapped < _targetCount)
                  Positioned(
                    left: (_decoyPos.dx * w - objSize / 2).clamp(
                      w * 0.55,
                      w - objSize,
                    ),
                    top: (_decoyPos.dy * h - objSize / 2).clamp(
                      h * 0.20,
                      h - objSize,
                    ),
                    child: AnimatedBuilder(
                      animation: _objectWiggleCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(
                          0,
                          (_objectWiggleCtrl.value - 0.5) * -10,
                        ),
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _wrongTapped = true);
                          Future.delayed(
                            const Duration(milliseconds: 1000),
                            () {
                              if (mounted) setState(() => _wrongTapped = false);
                            },
                          );
                        },
                        child: _buildObjectCircle(
                          objSize,
                          _decoyAsset,
                          _decoyEmoji,
                          _wrongTapped,
                        ),
                      ),
                    ),
                  ),
              ],
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
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NumberFourIntroductionScreen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const NumberThreeIntroductionScreen(),
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
            'assets/fonts/game_numbers/3.png',
            width: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              '3',
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
            'THREE',
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
// Fallback Doma
// ─────────────────────────────────────────────────────────────────────────────
class _FallbackDoma extends StatelessWidget {
  final double height;

  const _FallbackDoma({required this.height});

  @override
  Widget build(BuildContext context) =>
      Text('🐧', style: TextStyle(fontSize: height * 0.7));
}
