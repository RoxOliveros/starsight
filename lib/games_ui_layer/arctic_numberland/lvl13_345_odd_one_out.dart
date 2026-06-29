import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'goodjob_doma_prompt.dart';
import 'lvl14_12345_sequence.dart';

class Number345OddOneOutScreen extends StatefulWidget {
  const Number345OddOneOutScreen({super.key});

  @override
  State<Number345OddOneOutScreen> createState() =>
      _Number345OddOneOutScreenState();
}

class _Number345OddOneOutScreenState extends State<Number345OddOneOutScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const List<int> _numbers = [3, 4, 5];

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage =
      'assets/images/characters/doma_the_penguin.png';

  static const String _audioIntro =
      'assets/audio/arctic_numberland/level16/intro.wav';

  static const Map<int, String> _numberAudio = {
    3: 'assets/audio/arctic_numberland/level16/odd_three.wav',
    4: 'assets/audio/arctic_numberland/level16/odd_four.wav',
    5: 'assets/audio/arctic_numberland/level16/odd_five.wav',
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
  late int _targetNumber; // the number that 3 cards will show
  late int _oddCount; // the number the odd-one-out card shows
  late int _oddCardIndex; // which of the 4 cards is the odd one out
  late List<int> _cardCounts; // count per card (4 cards)
  late List<String> _cardAssets; // object asset per card (4 cards)

  bool _roundComplete = false;
  bool _showWinDialog = false;
  bool _introPlaying = true;

  int _wrongTappedIndex = -1;
  int _correctTappedIndex = -1;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;

  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;

  late AnimationController _cardsEnterCtrl;
  late Animation<double> _cardsEnter;

  late AnimationController _correctCtrl;
  late Animation<double> _correctScale;

  // 4 shake controllers, one per card
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
    _instructionBounce = TweenSequence(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
      ],
    ).animate(CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut));

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
    ]).animate(CurvedAnimation(parent: _correctCtrl, curve: Curves.easeOut));

    // 4 shake controllers — one per card
    _wrongCtrlList = List.generate(
      4,
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

    // Pick the target number (3 cards will show this)
    _targetNumber = _numbers[rng.nextInt(_numbers.length)];

    // Pick the odd count — must be different from target
    final oddOptions = _numbers.where((n) => n != _targetNumber).toList()
      ..shuffle(rng);
    _oddCount = oddOptions.first;

    // 4 card counts: 3 × target + 1 × odd, then shuffle
    final counts = [_targetNumber, _targetNumber, _targetNumber, _oddCount]
      ..shuffle(rng);
    _cardCounts = counts;
    _oddCardIndex = counts.indexOf(_oddCount);

    // Each card uses a different object
    final shuffledAssets = [..._objectAssets]..shuffle(rng);
    _cardAssets = shuffledAssets.take(4).toList();

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

    final isOdd = cardIndex == _oddCardIndex;

    if (isOdd) {
      // ── Correct: found the odd one out ──
      setState(() {
        _correctTappedIndex = cardIndex;
        _roundComplete = true;
      });
      _correctCtrl.forward(from: 0);
      await _playAudio('assets/audio/arctic_numberland/$_oddCount.wav');
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      if (_currentRound + 1 >= _totalRounds) {
        await ArcticProgressService.instance.markLevelComplete(13);
        setState(() => _showWinDialog = true);
      } else {
        setState(() => _currentRound++);
        _setupRound();
      }
    } else {
      // ── Wrong: tapped a matching card ──
      setState(() => _wrongTappedIndex = cardIndex);
      _wrongCtrlList[cardIndex].forward(from: 0);
      await _playAudio('assets/audio/sound_effects/bubble_pop.wav');
      await Future.delayed(const Duration(milliseconds: 200));
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
            child: _introPlaying ? _buildIntroLayer() : _buildGameContent(),
          ),

          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Intro ──────────────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        return Center(child: _buildDoma(h));
      },
    );
  }

  // ── Game ───────────────────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return Column(
          children: [
            // ── HEADER ─────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 20),
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

            const SizedBox(height: 16),

            // ── 4 CARDS ROW ────────────────────────
            Expanded(
              child: Stack(children: [Center(child: _buildCardsRow(w, h))]),
            ),

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

  // ── Banner ─────────────────────────────────────────────────────────────────
  Widget _buildInstructionBanner(double h) {
    final word = _numberWords[_targetNumber] ?? '';
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => _playAudio(_numberAudio[_targetNumber]!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                'Which is NOT $word?',
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
              const SizedBox(width: 10),
              // Number image
              Image.asset(
                'assets/fonts/game_numbers/$_targetNumber.png',
                height: (h * 0.08).clamp(28.0, 44.0),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  '$_targetNumber',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontSize: (h * 0.08).clamp(22.0, 34.0),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Speaker hint
              Image.asset(
                'assets/images/icons/speaker.png',
                height: (h * 0.25).clamp(18.0, 28.0),
                width: (h * 0.25).clamp(18.0, 28.0),
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────
  Widget _buildCardsRow(double w, double h) {
    final cardW = (w * 0.18).clamp(105.0, 155.0);
    final cardH = (h * 0.52).clamp(150.0, 220.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(4, (i) => _buildCard(i, cardW, cardH)),
      ),
    );
  }

  Widget _buildCard(int index, double cardW, double cardH) {
    final count = _cardCounts[index];
    final asset = _cardAssets[index];

    final isCorrect = _correctTappedIndex == index;
    final isWrong = _wrongTappedIndex == index;
    final isOdd = index == _oddCardIndex;

    final isDimmed = _roundComplete && !isOdd && !isCorrect;

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
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isDimmed ? 0.45 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: cardW,
                height: cardH,
                padding: const EdgeInsets.all(12),
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
                          ? Colors.greenAccent.withValues(alpha: 0.45)
                          : isWrong
                          ? Colors.red.withValues(alpha: 0.25)
                          : ArcticColorTheme.pictonblue.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(child: _buildCardObjects(count, asset, cardW)),

                    // ✓ check
                    if (isCorrect)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),

                    // ✗ wrong
                    if (isWrong)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardObjects(int count, String asset, double cardW) {
    final objSize = _objectSizeForCount(count, cardW);

    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        count,
        (_) => Image.asset(
          asset,
          width: objSize,
          height: objSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  double _objectSizeForCount(int count, double cardW) {
    if (count <= 3) return (cardW * 0.30).clamp(30.0, 52.0);
    if (count == 4) return (cardW * 0.26).clamp(26.0, 46.0);
    return (cardW * 0.22).clamp(22.0, 40.0);
  }

  // ── Doma ───────────────────────────────────────────────────────────────────
  Widget _buildDoma(double h) {
    final domaH = (h * 0.75).clamp(300.0, 520.0);
    return Center(
      child: AnimatedBuilder(
        animation: _domaFloatCtrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(
            0,
            Tween<double>(begin: -10, end: 10).evaluate(
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
      ),
    );
  }

  // ── Progress ───────────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  // ── Win Overlay ────────────────────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pop(context, const Number012345SequenceScreen());
      },
      onRestart: () {
        Navigator.pop(context, const Number345OddOneOutScreen());
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
