import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl16_345_odd_one_out.dart';

class Number345MatchingScreen extends StatefulWidget {
  const Number345MatchingScreen({super.key});

  @override
  State<Number345MatchingScreen> createState() =>
      _Number345MatchingScreenState();
}

class _Number345MatchingScreenState extends State<Number345MatchingScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const List<int> _numbers = [3, 4, 5];

  static const String _bgImage =
      'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage =
      'assets/images/characters/doma_the_penguin.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/level15/intro.wav';
  static const String _audioCorrect = 'assets/audio/bubble_pop.wav';

  static const Map<int, String> _numberAudio = {
    3: 'assets/audio/arctic_numberland/level15/find_3.wav',
    4: 'assets/audio/arctic_numberland/level15/find_4.wav',
    5: 'assets/audio/arctic_numberland/level15/find_5.wav',
  };

  static const Map<int, String> _numberWords = {
    3: 'THREE',
    4: 'FOUR',
    5: 'FIVE',
  };

  // ── Objects pool ───────────────────────────────────────────────────────────
  static const List<String> _objectAssets = [
    'assets/images/objects/arctic/candy_cane.png',
    'assets/images/objects/arctic/earmuffs.png',
    'assets/images/objects/arctic/ice.png',
    'assets/images/objects/arctic/ice_skates.png',
    'assets/images/objects/arctic/icecream.png',
    'assets/images/objects/arctic/igloo.png',
    'assets/images/objects/arctic/sled.png',
    'assets/images/objects/arctic/snowball.png',
    'assets/images/objects/arctic/snowglobe.png',
    'assets/images/objects/arctic/snowman.png',
    'assets/images/objects/arctic/snowy_signboard.png',
    'assets/images/objects/arctic/snowy_tree.png',
    'assets/images/objects/arctic/winter_hat.png',
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  int _currentRound = 0;
  late int _targetNumber;         // the number shown in the banner
  late List<int> _groupCounts;    // how many objects each card shows (3 cards)
  late List<String> _groupAssets; // which object each card uses
  bool _roundComplete = false;
  bool _showWinDialog = false;
  bool _introPlaying = true;

  int _wrongTappedIndex = -1;
  int _correctTappedIndex = -1;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;

  // Banner bounce (same as recognition screen)
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;

  // Cards entrance
  late AnimationController _cardsEnterCtrl;
  late Animation<double> _cardsEnter;

  // Correct card pulse (same sequence as recognition screen)
  late AnimationController _correctCtrl;
  late Animation<double> _correctScale;

  // Wrong card shake — one per card slot
  late List<AnimationController> _wrongCtrlList;
  late List<Animation<double>> _wrongShakeList;

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

    _instructionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _instructionBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut),
    );

    _cardsEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardsEnter = CurvedAnimation(
      parent: _cardsEnterCtrl,
      curve: Curves.elasticOut,
    );

    _correctCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _correctScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.08), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 10),
    ]).animate(
      CurvedAnimation(parent: _correctCtrl, curve: Curves.easeOut),
    );

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
      ]).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
    }).toList();
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

    // Pick the target number to display
    _targetNumber = _numbers[rng.nextInt(_numbers.length)];

    // Build group counts: always one card per number (3,4,5) shuffled
    // so exactly one card has _targetNumber objects
    final shuffledCounts = [..._numbers]..shuffle(rng);
    _groupCounts = shuffledCounts;

    // Each card uses a different object for visual variety
    final shuffledAssets = [..._objectAssets]..shuffle(rng);
    _groupAssets = shuffledAssets.take(3).toList();

    _roundComplete = false;
    _wrongTappedIndex = -1;
    _correctTappedIndex = -1;

    _cardsEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _playAudio(_numberAudio[_targetNumber]!);
    });
  }

  Future<void> _onCardTapped(int cardIndex) async {
    if (_roundComplete) return;
    if (_wrongTappedIndex == cardIndex) return;

    final tappedCount = _groupCounts[cardIndex];

    if (tappedCount == _targetNumber) {
      // ── Correct ──
      setState(() {
        _correctTappedIndex = cardIndex;
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
      setState(() => _wrongTappedIndex = cardIndex);
      _wrongCtrlList[cardIndex].forward(from: 0);
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
    _instructionCtrl.dispose();
    _cardsEnterCtrl.dispose();
    _correctCtrl.dispose();
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
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),

          SafeArea(
            child: Stack(
              children: [
                if (_introPlaying)
                  _buildIntroLayer()
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

  // ── Intro (Doma only, while audio plays) ───────────────────────────────────
  Widget _buildIntroLayer() {
    return LayoutBuilder(
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
    );
  }

  // ── Game Layout ────────────────────────────────────────────────────────────
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
                  Center(child: _buildInstructionBanner(h)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── CARDS ROW ──────────────────────────
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: _buildCardsRow(w, h),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── PROGRESS DOTS ──────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildRoundIndicator(),
            ),
          ],
        );
      },
    );
  }

  // ── Instruction Banner ─────────────────────────────────────────────────────
  Widget _buildInstructionBanner(double h) {
    final word = _numberWords[_targetNumber] ?? '';
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => _playAudio(_numberAudio[_targetNumber]!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
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
              // Number image in the banner
              Image.asset(
                'assets/fonts/game_numbers/$_targetNumber.png',
                height: (h * 0.09).clamp(30.0, 48.0),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  '$_targetNumber',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontSize: (h * 0.09).clamp(24.0, 38.0),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Find the group of $word!',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: (h * 0.08).clamp(16.0, 26.0),
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

  // ── Cards Row ──────────────────────────────────────────────────────────────
  Widget _buildCardsRow(double w, double h) {
    final cardW = (w * 0.22).clamp(140.0, 210.0);
    final cardH = (h * 0.72).clamp(160.0, 240.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(3, (i) => _buildCard(i, cardW, cardH)),
    );
  }

  Widget _buildCard(int index, double cardW, double cardH) {
    final count = _groupCounts[index];
    final asset = _groupAssets[index];
    final isCorrect = _correctTappedIndex == index;
    final isWrong = _wrongTappedIndex == index;

    return ScaleTransition(
      scale: _cardsEnter,
      child: AnimatedBuilder(
        animation: _wrongShakeList[index],
        builder: (_, child) => Transform.translate(
          offset: Offset(_wrongShakeList[index].value, 0),
          child: child,
        ),
        child: ScaleTransition(
          scale: isCorrect ? _correctScale : const AlwaysStoppedAnimation(1.0),
          child: GestureDetector(
            onTap: () => _onCardTapped(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.shade50
                    : isWrong
                    ? Colors.red.shade50
                    : ArcticColorTheme.cotton,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green
                      : isWrong
                      ? Colors.red
                      : ArcticColorTheme.pictonblue,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isCorrect
                        ? Colors.greenAccent.withValues(alpha: 0.5)
                        : isWrong
                        ? Colors.red.withValues(alpha: 0.3)
                        : ArcticColorTheme.pictonblue.withValues(alpha: 0.25),
                    blurRadius: isCorrect ? 24 : 10,
                    spreadRadius: isCorrect ? 4 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Object grid inside the card
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildCardObjectGrid(count, asset, cardW, cardH),
                  ),

                  // ✓ checkmark badge on correct
                  if (isCorrect)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                  // ✗ cross badge on wrong
                  if (isWrong)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
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

  Widget _buildCardObjectGrid(
      int count, String asset, double cardW, double cardH) {
    // Fit objects neatly: 3 → row of 3, 4 → 2x2, 5 → 2+3
    final objSize = _objectSizeForCount(count, cardW, cardH);

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: List.generate(count, (_) {
          return Image.asset(
            asset,
            width: objSize,
            height: objSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Text('❄️', style: TextStyle(fontSize: objSize * 0.8)),
          );
        }),
      ),
    );
  }

  double _objectSizeForCount(int count, double cardW, double cardH) {
    // Scale object size so they fit comfortably in the card
    if (count <= 3) return (cardW * 0.28).clamp(40.0, 62.0);
    if (count == 4) return (cardW * 0.24).clamp(36.0, 56.0);
    return (cardW * 0.22).clamp(32.0, 50.0); // 5
  }

  // ── Doma Floating ──────────────────────────────────────────────────────────
  Widget _buildDoma(double h) {
    final domaH = h.clamp(160.0, 320.0);

    return Center(
      child: AnimatedBuilder(
        animation: _domaFloatCtrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(
            0,
            Tween<double>(begin: -8, end: 8).evaluate(
              CurvedAnimation(
                parent: _domaFloatCtrl,
                curve: Curves.easeInOut,
              ),
            ),
          ),
          child: child,
        ),
        child: Image.asset(
          _characterImage,
          height: domaH,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            '🐧',
            style: TextStyle(fontSize: domaH * 0.5),
          ),
        ),
      ),
    );
  }

  // ── Progress Indicator ─────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalRounds, (i) {
          final done = i < _currentRound;
          final current = i == _currentRound;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
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

  // ── Win Overlay ────────────────────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number345OddOneOutScreen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) => const Number345MatchingScreen()),
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