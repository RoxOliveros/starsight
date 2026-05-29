import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl14_345_counting.dart';

class Number345RecognitionScreen extends StatefulWidget {
  const Number345RecognitionScreen({super.key});

  @override
  State<Number345RecognitionScreen> createState() =>
      _Number345RecognitionScreenState();
}

class _Number345RecognitionScreenState extends State<Number345RecognitionScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const List<int> _numbers = [3, 4, 5];

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _iglooAsset = 'assets/images/objects/arctic/igloo.png';
  static const String _characterImage =
      'assets/images/characters/doma_the_penguin.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/level13/intro.wav';
  static const String _audioCorrect = 'assets/audio/bubble_pop.wav';

  static const Map<int, String> _tapAudio = {
    3: 'assets/audio/arctic_numberland/level13/tap_three.wav',
    4: 'assets/audio/arctic_numberland/level13/tap_four.wav',
    5: 'assets/audio/arctic_numberland/level13/tap_five.wav',
  };

  static const Map<int, String> _numberWords = {
    3: 'THREE',
    4: 'FOUR',
    5: 'FIVE',
  };

  // ── State ──────────────────────────────────────────────────────────────────
  int _currentRound = 0;
  late int _targetNumber;
  late List<int> _iglooNumbers; // numbers shown on igloos this round
  bool _roundComplete = false;
  bool _showWinDialog = false;
  bool _introPlaying = true;

  // Which igloo is wrong-tapped (index), -1 = none
  int _wrongTappedIndex = -1;

  // Which igloo is correct-tapped
  int _correctTappedIndex = -1;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _correctCtrl;
  late Animation<double> _correctScale;
  late List<AnimationController> _wrongCtrlList;
  late List<Animation<double>> _wrongShakeList;
  late AnimationController _iglooEnterCtrl;
  late Animation<double> _iglooEnter;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
  }

  void _initAnimations() {
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _correctCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _correctScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.08), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 10),
    ]).animate(CurvedAnimation(parent: _correctCtrl, curve: Curves.easeOut));

    // 3 shake controllers, one per igloo
    _wrongCtrlList = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _wrongShakeList = _wrongCtrlList.map((ctrl) {
      return TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 20),
        TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 20),
        TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 20),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
    }).toList();

    _iglooEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iglooEnter = CurvedAnimation(
      parent: _iglooEnterCtrl,
      curve: Curves.elasticOut,
    );

    _instructionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _instructionBounce = TweenSequence(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
      ],
    ).animate(CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut));
  }

  // ── Flow ───────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _playAudio(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _setupRound();
  }

  void _setupRound() {
    final rng = Random();

    // Always show 3, 4, 5 but shuffled
    final shuffled = [..._numbers]..shuffle(rng);
    _iglooNumbers = shuffled;

    // Pick which one to ask (cycle through rounds)
    // Ensure good variety: pick randomly but track usage
    _targetNumber = _numbers[_currentRound % _numbers.length];
    // randomize target each round
    _targetNumber = _numbers[rng.nextInt(_numbers.length)];

    _roundComplete = false;
    _wrongTappedIndex = -1;
    _correctTappedIndex = -1;

    _iglooEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    // Play the instruction audio
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _playAudio(_tapAudio[_targetNumber]!);
    });
  }

  Future<void> _onIglooTapped(int iglooIndex) async {
    if (_roundComplete) return;
    if (_wrongTappedIndex == iglooIndex) return;

    final tappedNumber = _iglooNumbers[iglooIndex];

    if (tappedNumber == _targetNumber) {
      // ── Correct ──
      setState(() {
        _correctTappedIndex = iglooIndex;
        _roundComplete = true;
      });
      _correctCtrl.forward(from: 0);
      await _playAudio(_audioCorrect);
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      if (_currentRound + 1 >= _totalRounds) {
        setState(() => _showWinDialog = true);
      } else {
        setState(() => _currentRound++);
        _setupRound();
      }
    } else {
      // ── Wrong ──
      setState(() => _wrongTappedIndex = iglooIndex);
      _wrongCtrlList[iglooIndex].forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _wrongTappedIndex = -1);
    }
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
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _domaFloatCtrl.dispose();
    _correctCtrl.dispose();
    _iglooEnterCtrl.dispose();
    _instructionCtrl.dispose();
    for (final c in _wrongCtrlList) {
      c.dispose();
    }
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),

          SafeArea(
            child: Stack(
              children: [
                if (_introPlaying)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final h = constraints.maxHeight;

                        return Stack(
                          children: [
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: _buildDoma(h),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                else
                  _buildGameContent(),
              ],
            ),
          ),

          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return Column(
          children: [

            // ── HEADER ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ArcticBackButton(),
                  ),

                  Center(
                    child: _buildInstructionBanner(h),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── MAIN CONTENT ──────────────────────
            Expanded(
              child: Stack(
                children: [
                  // Igloos centered
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: w * 0.12,
                        right: 0,
                        bottom: 0,
                      ),
                      child: _buildIglooRow(w, h),
                    ),
                  ),

                  // Doma bottom left
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: _buildDoma(h * 0.78),
                  ),
                ],
              ),
            ),

            // ── PROGRESS DOTS ─────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildRoundIndicator(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionBanner(double h) {
    final word = _numberWords[_targetNumber] ?? '';
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => _playAudio(_tapAudio[_targetNumber]!),
        child: Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
              Text(
                'Tap the igloo with $word!',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: (h * 0.09).clamp(18.0, 28.0),
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
    );
  }

  Widget _buildIglooRow(double w, double h) {
    final iglooSize = (h * 0.52).clamp(120.0, 200.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(3, (i) => _buildIgloo(i, iglooSize)),
    );
  }

  Widget _buildIgloo(int index, double size) {
    final number = _iglooNumbers[index];
    final isCorrect = _correctTappedIndex == index;
    final isWrong = _wrongTappedIndex == index;

    return ScaleTransition(
      scale: _iglooEnter,
      child: AnimatedBuilder(
        animation: _wrongShakeList[index],
        builder: (_, child) => Transform.translate(
          offset: Offset(_wrongShakeList[index].value, 0),
          child: child,
        ),
        child: ScaleTransition(
          scale: isCorrect ? _correctScale : const AlwaysStoppedAnimation(1.0),
          child: GestureDetector(
            onTap: () => _onIglooTapped(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Igloo image with colored overlay effect
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow behind igloo when correct
                      if (isCorrect)
                        Container(
                          width: size * 0.95,
                          height: size * 0.75,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.greenAccent.withValues(alpha: 0.35),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),

                      // Red tint when wrong
                      if (isWrong)
                        Container(
                          width: size * 0.85,
                          height: size * 0.65,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: 0.25),
                          ),
                        ),

                      // Igloo image
                      ColorFiltered(
                        colorFilter: isCorrect
                            ? const ColorFilter.matrix([
                                0.5,
                                0,
                                0,
                                0,
                                80,
                                0,
                                1,
                                0,
                                0,
                                80,
                                0,
                                0,
                                0.5,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ])
                            : isWrong
                            ? const ColorFilter.matrix([
                                1.5,
                                0,
                                0,
                                0,
                                20,
                                0,
                                0.5,
                                0,
                                0,
                                0,
                                0,
                                0,
                                0.5,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ])
                            : const ColorFilter.matrix([
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                        child: Image.asset(
                          _iglooAsset,
                          width: size * 0.85,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.home_rounded,
                            size: size * 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // ✓ checkmark on correct
                      if (isCorrect)
                        Positioned(
                          top: 0,
                          right: size * 0.02,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Number badge on igloo
                  Transform.translate(
                    offset: const Offset(0, -18), // moves number closer to igloo
                    child: AnimatedScale(
                      scale: isCorrect ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      child: Image.asset(
                        'assets/fonts/game_numbers/$number.png',
                        height: size * 0.24,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          '$number',
                          style: TextStyle(
                            fontSize: size * 0.22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // decoration: BoxDecoration(
      //   color: ArcticColorTheme.slateblue.withValues(alpha: 0.85),
      //   borderRadius: BorderRadius.circular(20),
      //   border: Border.all(color: Colors.white, width: 2),
      // ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_totalRounds, (i) {
          final done = i < _currentRound;
          final current = i == _currentRound;
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
      ),
    );
  }

  Widget _buildDoma(double h) {
    final domaH = h.clamp(90.0, 180.0);
    return AnimatedBuilder(
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
        height: domaH,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Text('🐧', style: TextStyle(fontSize: domaH * 0.5)),
      ),
    );
  }

  Widget _buildGoodJobOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number345CountingScreen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number345RecognitionScreen()),
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
