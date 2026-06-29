import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'goodjob_doma_prompt.dart';
import 'lvl8_three_introduction.dart';

enum _ScreenPhase { intro, miniGame }

class Number012TapCountScreen extends StatefulWidget {
  const Number012TapCountScreen({super.key});

  @override
  State<Number012TapCountScreen> createState() =>
      _Number012TapCountScreenState();
}

class _Number012TapCountScreenState extends State<Number012TapCountScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────

  static const int _totalRounds = 5;
  static const int _poolSize = 5;

  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  bool _showWinDialog = false;
  final AudioPlayer _player = AudioPlayer();

  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  static const _themes = [
    _RoundTheme(
      asset: 'assets/images/objects/arctic/snowball.png',
      label: 'Snowball',
      color: Color(0xFF4FC3F7),
    ), // index 0
    _RoundTheme(
      asset: 'assets/images/objects/arctic/candy_cane.png',
      label: 'Candy Cane',
      color: Color(0xFFFFC857),
    ), // index 1
    _RoundTheme(
      asset: 'assets/images/objects/arctic/igloo.png',
      label: 'Igloo',
      color: Color(0xFF81C784),
    ), // index 2
  ];

  // ── State ──────────────────────────────────────────────────────────────────

  int _round = 0; // index into _roundOrder
  late List<int> _roundOrder;

  int get _targetNumber => _roundOrder[_round];

  _RoundTheme get _theme => _themes[_targetNumber];

  // Which of the 5 objects are selected
  late List<bool> _selected;

  // Submit feedback
  bool _submitFlashWrong = false;
  bool _locked = false;

  // Animations
  late AnimationController _numberBounce;
  late Animation<double> _numberBounceAnim;

  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  late AnimationController _celebrationCtrl;

  late AnimationController _wrongShakeCtrl;

  // Object scale animations (one per object)
  late List<AnimationController> _objScaleCtrls;
  late List<Animation<double>> _objScaleAnims;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    final random = Random();

    _roundOrder = [1, 2];
    while (_roundOrder.length < _totalRounds) {
      _roundOrder.add(random.nextBool() ? 1 : 2);
    }
    _roundOrder.shuffle(random);

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    _startIntroFlow();

    _numberBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _numberBounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _numberBounce, curve: Curves.easeOut));

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _wrongShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _initObjectAnimations();
    _startRound();
  }

  void _initObjectAnimations() {
    _objScaleCtrls = List.generate(
      _poolSize,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      ),
    );
    _objScaleAnims = _objScaleCtrls.map((ctrl) {
      return TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 60),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }).toList();
  }

  @override
  void dispose() {
    _numberDanceCtrl.dispose();
    _player.dispose();
    OrientationService.setLandscape();
    _numberBounce.dispose();
    _enterCtrl.dispose();
    _celebrationCtrl.dispose();
    _wrongShakeCtrl.dispose();
    for (final c in _objScaleCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Round logic ────────────────────────────────────────────────────────────

  void _startRound() {
    _selected = List.filled(_poolSize, false);
    _submitFlashWrong = false;
    _locked = false;
    _celebrationCtrl.reset();
    _enterCtrl.forward(from: 0);
    _numberBounce.forward(from: 0);
  }

  int get _selectedCount => _selected.where((s) => s).length;

  void _onObjectTap(int index) {
    if (_locked) return;
    setState(() {
      _selected[index] = !_selected[index];
    });
    _objScaleCtrls[index].forward(from: 0);

    final count = _selected.where((s) => s).length;
    if (_selected[index]) {
      _playAudio('assets/audio/arctic_numberland/$count.wav');
    }
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _playAudio(
      'assets/audio/arctic_numberland/level8/012_countandtap.wav',
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _screenPhase = _ScreenPhase.miniGame);
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

  Future<void> _onSubmit() async {
    if (_locked) return;
    _locked = true;

    if (_selectedCount == _targetNumber) {
      // ✅ Correct
      _playAudio('assets/audio/arctic_numberland/$_targetNumber.wav');
      _celebrationCtrl.forward(from: 0);
      _numberBounce.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1000));

      if (_round + 1 >= _totalRounds) {
        await ArcticProgressService.instance.markLevelComplete(7);
        setState(() => _showWinDialog = true);
      } else {
        await _enterCtrl.reverse();
        setState(() {
          _round++;
          _startRound();
        });
      }
    } else {

      _playAudio('assets/audio/sound_effects/bubble_pop.wav');
      setState(() => _submitFlashWrong = true);
      _wrongShakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 2000));
      _wrongShakeCtrl.reset();
      setState(() {
        _submitFlashWrong = false;
        _locked = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcticColorTheme.lightgrayishcyan,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_arctic.png',
              fit: BoxFit.cover,
            ),
          ),
          if (_screenPhase == _ScreenPhase.intro)
            _buildIntroContent()
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // ── Header ──────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ArcticBackButton(),
                          ),
                          Container(
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
                              'Tap and count the number of object/s needed',
                              style: TextStyle(
                                fontFamily: ArcticAppTextStyles.fredoka,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Main game area ───────────────────────────────────────────────
                    Expanded(
                      child: FadeTransition(
                        opacity: _enterAnim,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Spacer(),
                            // LEFT — Number card
                            _buildNumberCard(),

                            const SizedBox(width: 24),

                            //Arrow
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: ArcticColorTheme.slateblue,
                              size: 28,
                            ),

                            const SizedBox(width: 12),

                            _buildObjectArea(),

                            const Spacer(),
                          ],
                        ),
                      ),
                    ),

                    _buildProgressDots(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Number card (left) ─────────────────────────────────────────────────────

  Widget _buildNumberCard() {
    final s = MediaQuery.of(context).size;
    final cardSize = (s.height * 0.32).clamp(80.0, 130.0);
    return ScaleTransition(
      scale: _numberBounceAnim,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          color: ArcticColorTheme.cadetblue,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ArcticColorTheme.slateblue, width: 3),
          boxShadow: [
            BoxShadow(
              color: ArcticColorTheme.pictonblue.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            'assets/fonts/game_numbers/$_targetNumber.png',
            width: cardSize * 0.6,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              '$_targetNumber',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: cardSize * 0.6,
                fontWeight: FontWeight.bold,
                color: ArcticColorTheme.cotton,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Object grid + submit (right) ───────────────────────────────────────────

  Widget _buildObjectArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Object row (5 objects)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_poolSize, _buildObjectTile),
        ),

        const SizedBox(height: 18),

        // Submit button
        GestureDetector(
          onTap: _onSubmit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
            decoration: BoxDecoration(
              color: ArcticColorTheme.cadetblue,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ArcticColorTheme.cadetblue.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'Submit',
              style: const TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ArcticColorTheme.cotton,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildObjectTile(int index) {
    final tileSize = (MediaQuery.of(context).size.height * 0.18).clamp(
      52.0,
      80.0,
    );
    final isSelected = _selected[index];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tileSize * 0.08),
      child: GestureDetector(
        onTap: () => _onObjectTap(index),
        child: ScaleTransition(
          scale: _objScaleAnims[index],
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: isSelected ? _theme.color : ArcticColorTheme.cotton,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? _theme.color : ArcticColorTheme.pictonblue,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? _theme.color.withValues(alpha: 0.45)
                      : ArcticColorTheme.pictonblue.withValues(alpha: 0.15),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(tileSize * 0.13),
                  child: Image.asset(
                    _theme.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.star_rounded,
                      color: isSelected ? Colors.white : _theme.color,
                      size: tileSize * 0.5,
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: tileSize * 0.26,
                      height: tileSize * 0.26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: tileSize * 0.18,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _round;
        final current = i == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : current
                ? ArcticColorTheme.pictonblue
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pop(context, const NumberThreeIntroductionScreen());
      },
      onRestart: () {
        Navigator.pop(context, const Number012TapCountScreen());
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }

  Widget _buildIntroContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Stack(
          children: [
            Positioned(top: 8, left: 12, child: ArcticBackButton()),
            Positioned.fill(
              top: 50,
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/characters/doma_the_penguin.png',
                        height: MediaQuery.of(context).size.height * 0.65,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Text('🐧', style: TextStyle(fontSize: 60)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _numberDanceCtrl,
                        builder: (_, __) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              final angle =
                                  _numberDance.value * ((i % 2 == 0) ? 1 : -1);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Transform.rotate(
                                  angle: angle,
                                  child: _buildIntroNumberCard(i),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroNumberCard(int number) {
    final size = MediaQuery.of(context).size.height * 0.28;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Image.asset(
              'assets/fonts/game_numbers/$number.png',
              width: size * 0.64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                '$number',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ['ZERO', 'ONE', 'TWO'][number],
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RoundTheme {
  final String asset;
  final String label;
  final Color color;

  const _RoundTheme({
    required this.asset,
    required this.label,
    required this.color,
  });
}
