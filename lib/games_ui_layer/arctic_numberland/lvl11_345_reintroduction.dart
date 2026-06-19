import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl12_345_counting.dart';

class Number345ReintroductionScreen extends StatefulWidget {
  const Number345ReintroductionScreen({super.key});

  @override
  State<Number345ReintroductionScreen> createState() =>
      _Number345ReintroductionScreenState();
}

class _Number345ReintroductionScreenState
    extends State<Number345ReintroductionScreen>
    with TickerProviderStateMixin {
  // ── Stage config ───────────────────────────────────────────────────────────
  static const int _totalStages = 3;

  static const _stages = [
    _StageTheme(
      number: 3,
      label: 'THREE',
      objectAsset: 'assets/images/objects/arctic/snowball.png',
      objectEmoji: '⚪',
      hereIsAudio: 'assets/audio/arctic_numberland/level12/here_is_three.wav',
    ),
    _StageTheme(
      number: 4,
      label: 'FOUR',
      objectAsset: 'assets/images/objects/arctic/candy_cane.png',
      objectEmoji: '🍬',
      hereIsAudio: 'assets/audio/arctic_numberland/level12/here_is_four.wav',
    ),
    _StageTheme(
      number: 5,
      label: 'FIVE',
      objectAsset: 'assets/images/objects/arctic/snowglobe.png',
      objectEmoji: '🔮',
      hereIsAudio: 'assets/audio/arctic_numberland/level12/here_is_five.wav',
    ),
  ];

  static const List<String> _countAudio = [
    'assets/audio/arctic_numberland/1.wav',
    'assets/audio/arctic_numberland/2.wav',
    'assets/audio/arctic_numberland/3.wav',
    'assets/audio/arctic_numberland/4.wav',
    'assets/audio/arctic_numberland/5.wav',
  ];

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage =
      'assets/images/characters/doma_the_penguin.png';
  static const String _audioIntro =
      'assets/audio/arctic_numberland/level12/reintro_345.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  int _currentStage = 0;
  late List<bool> _objectsTapped;
  bool _allTapped = false;
  bool _transitioning = false;
  bool _introPlaying = true;
  bool _showWinDialog = false;

  // How many objects are currently "visible" (pop in one by one)
  int _visibleCount = 0;

  _StageTheme get _stage => _stages[_currentStage];

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _numberBounceCtrl;
  late Animation<double> _numberBounce;
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _wiggleCtrl;
  late List<AnimationController> _objectPopCtrls;
  late List<Animation<double>> _objectPopAnims;
  late AnimationController _countBadgeCtrl;
  late Animation<double> _countBadge;

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

    _numberBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _numberBounce =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _numberBounceCtrl, curve: Curves.easeOut),
        );

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Max 5 objects
    _objectPopCtrls = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      ),
    );
    _objectPopAnims = _objectPopCtrls.map((ctrl) {
      return TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 55),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 25),
        TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }).toList();

    _countBadgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _countBadge = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _countBadgeCtrl, curve: Curves.easeOut));
  }

  // ── Flow ───────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _playAudio(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _setupStage();
  }

  Future<void> _setupStage() async {
    setState(() {
      _objectsTapped = List.filled(_stage.number, false);
      _allTapped = false;
      _transitioning = false;
      _visibleCount = 0;
    });

    _enterCtrl.forward(from: 0);
    _numberBounceCtrl.forward(from: 0);

    // Reset pop controllers
    for (final c in _objectPopCtrls) {
      c.reset();
    }

    // Play "here is THREE/FOUR/FIVE"
    await Future.delayed(const Duration(milliseconds: 300));
    await _playAudio(_stage.hereIsAudio);
    if (!mounted) return;

    // Pop objects in one by one
    for (int i = 0; i < _stage.number; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() => _visibleCount = i + 1);
      _objectPopCtrls[i].forward(from: 0);
    }
  }

  Future<void> _onObjectTapped(int index) async {
    if (_objectsTapped[index] || _allTapped || _transitioning) return;

    final newCount = _objectsTapped.where((t) => t).length + 1;

    setState(() => _objectsTapped[index] = true);
    _countBadgeCtrl.forward(from: 0);

    // Play count audio
    if (newCount <= _countAudio.length) {
      _playAudio(_countAudio[newCount - 1]);
    }

    final allDone = _objectsTapped.every((t) => t);
    if (allDone && !_allTapped) {
      setState(() => _allTapped = true);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _nextStage();
    }
  }

  Future<void> _nextStage() async {
    if (_transitioning) return;
    setState(() => _transitioning = true);

    if (_currentStage >= _totalStages - 1) {
      await ArcticProgressService.instance.markLevelComplete(11);
      setState(() => _showWinDialog = true);
      return;
    }

    _enterCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentStage++);
      _setupStage();
    });
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
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _domaFloatCtrl.dispose();
    _numberBounceCtrl.dispose();
    _enterCtrl.dispose();
    _wiggleCtrl.dispose();
    _countBadgeCtrl.dispose();
    for (final c in _objectPopCtrls) {
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

          if (_introPlaying)
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned(top: 8, left: 12, child: ArcticBackButton()),

                      // Center intro content
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Big animated penguin
                            _buildDoma(constraints.maxHeight * 0.55),

                            const SizedBox(height: 20),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: ArcticColorTheme.pictonblue.withValues(
                                  alpha: 0.92,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Text(
                                'Let\'s Learn 3, 4, and 5!',
                                style: TextStyle(
                                  fontFamily: ArcticAppTextStyles.fredoka,
                                  fontSize: (constraints.maxHeight * 0.07)
                                      .clamp(20.0, 34.0),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          else
            SafeArea(child: _buildGameContent()),

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
            // ── Header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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

            const SizedBox(height: 8),

            // ── Main content ─────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _enterAnim,
                child: Row(
                  children: [
                    // LEFT — Number showcase
                    Expanded(flex: 4, child: _buildNumberShowcase(h)),

                    // Divider
                    Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      color: Colors.white.withValues(alpha: 0.3),
                    ),

                    // RIGHT — Object tapping area
                    Expanded(flex: 6, child: _buildObjectArea(h, w)),
                  ],
                ),
              ),
            ),

            // ── Progress dots ─────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildProgressDots(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionBanner(double h) {
    final tappedCount = _objectsTapped.where((t) => t).length;
    final total = _stage.number;
    final isDone = _allTapped;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: ArcticColorTheme.pictonblue.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isDone ? '⭐ Great job!' : '👆 Tap all the ${_stage.label}!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: (h * 0.07).clamp(16.0, 24.0),
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
          if (!isDone) ...[
            const SizedBox(width: 10),
            // Count badge
            ScaleTransition(
              scale: _countBadge,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$tappedCount / $total',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontSize: (h * 0.065).clamp(14.0, 20.0),
                    fontWeight: FontWeight.bold,
                    color: ArcticColorTheme.pictonblue,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberShowcase(double h) {
    final numberSize = (h * 0.32).clamp(70.0, 120.0);
    final labelFontSize = (h * 0.08).clamp(14.0, 22.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Number image with bounce
        ScaleTransition(
          scale: _numberBounce,
          child: Image.asset(
            'assets/fonts/game_numbers/${_stage.number}.png',
            height: numberSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              '${_stage.number}',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: numberSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Word label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: ArcticColorTheme.cadetblue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _stage.label,
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: labelFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildObjectArea(double h, double w) {
    final objSize = (h * 0.26).clamp(60.0, 100.0);
    final rightW = w * 0.6;

    // Fixed grid positions for up to 5 objects — centered nicely
    final positions = _getObjectPositions(_stage.number, rightW, h, objSize);

    return Stack(
      children: List.generate(_visibleCount, (i) {
        final tapped = _objectsTapped[i];
        final pos = positions[i];

        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: ScaleTransition(
            scale: _objectPopAnims[i],
            child: GestureDetector(
              onTap: () => _onObjectTapped(i),
              child: AnimatedBuilder(
                animation: _wiggleCtrl,
                builder: (_, child) {
                  final wiggle = tapped
                      ? 0.0
                      : (_wiggleCtrl.value - 0.5) * 8 * ((i % 2 == 0) ? 1 : -1);
                  return Transform.translate(
                    offset: Offset(0, wiggle),
                    child: child,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: tapped ? objSize * 0.88 : objSize,
                  height: tapped ? objSize * 0.88 : objSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tapped
                        ? ArcticColorTheme.cadetblue
                        : ArcticColorTheme.pictonblue.withValues(alpha: 0.9),
                    border: Border.all(
                      color: tapped ? Colors.greenAccent : Colors.white,
                      width: tapped ? 4 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tapped
                            ? Colors.greenAccent.withValues(alpha: 0.4)
                            : ArcticColorTheme.pictonblue.withValues(
                                alpha: 0.5,
                              ),
                        blurRadius: tapped ? 8 : 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: tapped
                        ? Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: objSize * 0.48,
                          )
                        : Padding(
                            padding: EdgeInsets.all(objSize * 0.12),
                            child: Image.asset(
                              _stage.objectAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Text(
                                _stage.objectEmoji,
                                style: TextStyle(fontSize: objSize * 0.45),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // Returns centered positions for N objects in the right panel
  List<Offset> _getObjectPositions(
    int count,
    double panelW,
    double panelH,
    double objSize,
  ) {
    final List<Offset> positions = [];
    final rng = Random(_currentStage * 100); // consistent per stage

    // Layout: max 3 per row
    final cols = count <= 3 ? count : 3;
    final rows = (count / cols).ceil();

    final totalW = cols * objSize + (cols - 1) * 16.0;
    final totalH = rows * objSize + (rows - 1) * 16.0;

    final startX = (panelW - totalW) / 2;
    final startY = (panelH - totalH) / 2 - 60;

    for (int i = 0; i < count; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final jx = (rng.nextDouble() - 0.5) * 12;
      final jy = (rng.nextDouble() - 0.5) * 12;
      positions.add(
        Offset(
          startX + col * (objSize + 16) + jx,
          startY + row * (objSize + 16) + jy,
        ),
      );
    }
    return positions;
  }

  Widget _buildDoma(double h) {
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
        height: h,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Text('🐧', style: TextStyle(fontSize: h * 0.5)),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalStages, (i) {
        final done = i < _currentStage;
        final current = i == _currentStage;
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
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pop(context, const Number345CountingScreen());
      },
      onRestart: () {
        Navigator.pop(context, const Number345ReintroductionScreen());
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ── Stage theme data ──────────────────────────────────────────────────────────
class _StageTheme {
  final int number;
  final String label;
  final String objectAsset;
  final String objectEmoji;
  final String hereIsAudio;

  const _StageTheme({
    required this.number,
    required this.label,
    required this.objectAsset,
    required this.objectEmoji,
    required this.hereIsAudio,
  });
}
