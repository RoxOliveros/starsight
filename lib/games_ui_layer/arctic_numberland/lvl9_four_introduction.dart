import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import '../goodjob_prompt.dart';
import 'lvl10_five_introduction.dart';
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

class NumberFourIntroductionScreen extends StatefulWidget {
  const NumberFourIntroductionScreen({super.key});

  @override
  State<NumberFourIntroductionScreen> createState() =>
      _NumberFourIntroductionScreenState();
}

class _NumberFourIntroductionScreenState
    extends State<NumberFourIntroductionScreen>
    with TickerProviderStateMixin {
  // ── Asset config ────────────────────────────────
  static const int _targetCount = 4;
  static const String _numberWord = 'FOUR';
  static const int _numberInt = 4;
  static const String _numberImagePath = 'assets/fonts/game_numbers/4.png';
  static const String _characterImage =
      'assets/images/characters/doma_the_penguin.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';

  // Correct tap targets
  static const String _objectAsset =
      'assets/images/objects/arctic/snowball.png';
  static const String _objectEmoji = '⚪';

  // Decoy options
  static const String _decoyOptionAsset1 =
      'assets/images/objects/arctic/ice.png';
  static const String _decoyOptionEmoji1 = '🧊';
  static const String _decoyOptionAsset2 =
      'assets/images/objects/arctic/winter_hat.png';
  static const String _decoyOptionEmoji2 = '🧢';

  // Audio
  static const String _audioIntro =
      'assets/audio/arctic_numberland/level10/four_intro.wav';
  static const String _audioSayNumber =
      'assets/audio/arctic_numberland/level10/say_four.wav';
  static const String _audioWrite =
      'assets/audio/arctic_numberland/level10/write_four.wav';
  static const String _audioCount =
      'assets/audio/arctic_numberland/level10/count_four.wav';
  static const String _audioGoodJob =
      'assets/audio/arctic_numberland/magaling.wav';
  static const String _audioVeryGood =
      'assets/audio/arctic_numberland/sobrang_husay.wav';

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
  int _objectsTapped = 0;
  bool _showWinDialog = false;
  late Offset _objectPos;
  late Offset _objectPos2;
  late Offset _objectPos3;
  late Offset _objectPos4;
  bool _wrongTapped = false;
  bool _wrongTapped2 = false;
  late Offset _decoyPos;
  late Offset _decoyPos2;
  late String _decoyAsset;
  late String _decoyAsset2;
  late String _decoyEmoji;
  late String _decoyEmoji2;
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
    await _playAudio(_audioIntro);

    _setIntroPhase(_IntroPhase.playingSayTwo);
    _numberPopCtrl.forward();
    _numberDanceCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    await _playAudio(_audioSayNumber);
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

    if (!mounted || _introPhase != _IntroPhase.listening || _recognized) return;

    // Stop any existing session before starting a new one
    if (_speech.isListening) {
      _speech.stop();
      _listenRestartTimer?.cancel();
      _listenRestartTimer = Timer(
        const Duration(milliseconds: 800),
        _startListening,
      );
      return;
    }

    _speech.statusListener = (status) {
      if (!mounted || _recognized) return;
      if ((status == 'done' || status == 'notListening') &&
          _introPhase == _IntroPhase.listening) {
        _listenRestartTimer?.cancel();
        _listenRestartTimer = Timer(
          const Duration(milliseconds: 1500),
          _startListening,
        );
      }
    };

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        final cleaned = words.replaceAll(RegExp(r'[^a-z]'), '');
        if (RegExp(
              r'\b(four|for|fore|fur|por|pore|phor|foor|fo|faw|foh|forr|foru|fawr|fower|foar)\b',
            ).hasMatch(words) ||
            cleaned.contains('four') ||
            cleaned.contains('for') ||
            cleaned.length >= 2 && cleaned.startsWith('f') ||
            cleaned.length >= 2 &&
                cleaned.startsWith('p') &&
                cleaned.contains('o')) {
          _listenRestartTimer?.cancel();
          _speech.stop();
          setState(() => _isListening = false);
          _onWordRecognized();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  Future<void> _onWordRecognized() async {
    if (_recognized) return;
    _recognized = true;

    _setIntroPhase(_IntroPhase.celebrating);
    _celebrateCtrl.forward(from: 0);

    await _playAudio(_audioGoodJob);
    await Future.delayed(const Duration(milliseconds: 500));

    // ── Transition to mini game ──────────────────────────────────────────
    _setIntroPhase(_IntroPhase.done);
    _mgTransitionCtrl.forward();
    _randomiseObjectPosition();
    setState(() => _screenPhase = _ScreenPhase.miniGame);
    await _playAudio(_audioWrite);
  }

  // ── Mini-game logic ───────────────────────────────────────────────────────
  void _randomiseObjectPosition() {
    final rng = Random();

    final slots = [
      const Offset(0.58, 0.45),
      const Offset(0.72, 0.45),
      const Offset(0.86, 0.45),
      const Offset(0.58, 0.82),
      const Offset(0.72, 0.82),
      const Offset(0.86, 0.82),
    ]..shuffle(rng);

    _objectPos = slots[0];
    _objectPos2 = slots[1];
    _objectPos3 = slots[2];
    _objectPos4 = slots[3];
    _decoyPos = slots[4];
    _decoyPos2 = slots[5];

    _decoyAsset = rng.nextBool() ? _decoyOptionAsset1 : _decoyOptionAsset2;
    _decoyEmoji = (_decoyAsset == _decoyOptionAsset1)
        ? _decoyOptionEmoji1
        : _decoyOptionEmoji2;
    _decoyAsset2 = rng.nextBool() ? _decoyOptionAsset1 : _decoyOptionAsset2;
    _decoyEmoji2 = (_decoyAsset2 == _decoyOptionAsset1)
        ? _decoyOptionEmoji1
        : _decoyOptionEmoji2;
  }

  final List<bool> _objectTapped = [false, false, false, false];

  void _onObjectTapped(Offset tappedPos, {required int index}) async {
    if (_objectsTapped >= _targetCount) return;
    if (_objectTapped[index]) return;
    setState(() {
      _objectsTapped++;
      _lastTappedPos = tappedPos;
      _objectTapped[index] = true;
    });
    _objectTapCtrl.forward(from: 0);
    await _playAudio('assets/audio/arctic_numberland/$_objectsTapped.wav');
    if (_objectsTapped >= _targetCount) {
      await ArcticProgressService.instance.markLevelComplete(9);
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
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
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
          if (_introPhase == _IntroPhase.listening)
            Positioned(
              bottom: 20,
              right: 20,
              child: ArcticSkipButton(onTap: _onWordRecognized),
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
                      _characterImage,
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
        onTap: _onWordRecognized,
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
                  child: _NumberCard(
                    number: _numberInt,
                    numberWord: _numberWord,
                    imagePath: _numberImagePath,
                    size: cardSize,
                  ),
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
          final cardSize = (h * 0.30).clamp(80.0, 140.0);

          return Stack(
            children: [
              if (_miniGamePhase == _MiniGamePhase.tracing)
                NumberTracingWidget(
                  number: _numberInt,
                  player: _player,
                  successAudio: _audioVeryGood,
                  onComplete: () {
                    setState(() => _miniGamePhase = _MiniGamePhase.tapping);
                    _playAudio(_audioCount);
                  },
                )
              else ...[
                // Instruction banner — anchored top center
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ArcticColorTheme.pictonblue.withValues(
                          alpha: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Text(
                        ' 👆 Tap FOUR Snowball!',
                        style: TextStyle(
                          fontFamily: ArcticAppTextStyles.fredoka,
                          fontSize: 24,
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
                    ),
                  ),
                ),

                // Number card — left side
                Positioned(
                  left: 0,
                  top: 30,
                  bottom: 0,
                  width: w * 0.40,
                  child: Center(
                    child: _NumberCard(
                      number: _numberInt,
                      numberWord: _numberWord,
                      imagePath: _numberImagePath,
                      size: cardSize,
                    ),
                  ),
                ),

                // ── Correct Object ──
                if (!_objectTapped[0])
                  Positioned(
                    left: _objectPos.dx * w - objSize / 2,
                    top: _objectPos.dy * h - objSize / 2,
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
                          _objectAsset,
                          _objectEmoji,
                          false,
                        ),
                      ),
                    ),
                  ),

                if (!_objectTapped[1])
                  Positioned(
                    left: _objectPos2.dx * w - objSize / 2,
                    top: _objectPos2.dy * h - objSize / 2,
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
                          _objectAsset,
                          _objectEmoji,
                          false,
                        ),
                      ),
                    ),
                  ),

                if (!_objectTapped[2])
                  Positioned(
                    left: _objectPos3.dx * w - objSize / 2,
                    top: _objectPos3.dy * h - objSize / 2,
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
                          _objectAsset,
                          _objectEmoji,
                          false,
                        ),
                      ),
                    ),
                  ),

                if (!_objectTapped[3])
                  Positioned(
                    left: _objectPos4.dx * w - objSize / 2,
                    top: _objectPos4.dy * h - objSize / 2,
                    child: AnimatedBuilder(
                      animation: _objectWiggleCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, (_objectWiggleCtrl.value - 0.5) * 10),
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: () => _onObjectTapped(_objectPos4, index: 3),
                        child: _buildObjectCircle(
                          objSize,
                          _objectAsset,
                          _objectEmoji,
                          false,
                        ),
                      ),
                    ),
                  ),

                // tap burst
                if (_objectsTapped > 0 &&
                    _lastTappedPos != null &&
                    _objectTapCtrl.status != AnimationStatus.completed)
                  Positioned(
                    left: (_lastTappedPos!.dx * w - objSize / 2).clamp(
                      w * 0.55,
                      w - objSize,
                    ),
                    top: (_lastTappedPos!.dy * h - objSize / 2).clamp(
                      h * 0.28,
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

                if (_objectsTapped < _targetCount)
                  Positioned(
                    left: _decoyPos.dx * w - objSize / 2,
                    top: _decoyPos.dy * h - objSize / 2,
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
                if (_objectsTapped < _targetCount)
                  Positioned(
                    left: _decoyPos2.dx * w - objSize / 2,
                    top: _decoyPos2.dy * h - objSize / 2,
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
                          setState(() => _wrongTapped2 = true);
                          Future.delayed(
                            const Duration(milliseconds: 1000),
                            () {
                              if (mounted) {
                                setState(() => _wrongTapped2 = false);
                              }
                            },
                          );
                        },
                        child: _buildObjectCircle(
                          objSize,
                          _decoyAsset2,
                          _decoyEmoji2,
                          _wrongTapped2,
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
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const NumberFiveIntroductionScreen(),
          ),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const NumberFourIntroductionScreen(),
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
  final String numberWord;
  final String imagePath;
  final double size;

  const _NumberCard({
    required this.number,
    required this.numberWord,
    required this.imagePath,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            imagePath,
            width: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              numberWord,
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
            numberWord,
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
