import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/Puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl14_size_sort2.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAllObjects = [
  'compass',
  'jar',
  'lamp',
  'magnifying_glass',
  'map',
  'pen',
  'notebook',
  'puzzle_piece',
  'star',
  'telescope',
];

const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Lvl13BasketSort2Screen extends StatefulWidget {
  const Lvl13BasketSort2Screen({super.key});

  @override
  State<Lvl13BasketSort2Screen> createState() => _Lvl13BasketSort2ScreenState();
}

class _Lvl13BasketSort2ScreenState extends State<Lvl13BasketSort2Screen>
    with TickerProviderStateMixin, RoxieReactionMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/level6/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level6/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level6/instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/level6/complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;

  /// The two object types used as baskets this round
  late String _basketObjectA;
  late String _basketObjectB;

  /// Queue of object names to sort (4 items: 2×A + 2×B, shuffled)
  late List<String> _itemQueue;
  int _currentItemIndex = 0;

  /// How many items have been correctly placed per basket
  int _placedA = 0;
  int _placedB = 0;

  /// Flash state for wrong-drop highlight
  bool _flashA = false;
  bool _flashB = false;

  bool _roundComplete = false;
  bool _showWinDialog = false;

  /// Whether the current item is being held / dragged
  bool _itemHeld = false;

  late String _basketObjectC;
  int _placedC = 0;
  bool _flashC = false;
  late AnimationController _bounceCCtrl;
  late Animation<double> _bounceCAnim;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared float
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _itemDanceCtrl;
  late Animation<double> _itemDance;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round fade
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  // Item entrance (bounce in from top)
  late AnimationController _itemEnterCtrl;
  late Animation<double> _itemEnterAnim;
  late Animation<double> _itemEnterFade;

  // Correct-drop bounce on basket
  late AnimationController _bounceACtrl;
  late Animation<double> _bounceAAnim;
  late AnimationController _bounceBCtrl;
  late Animation<double> _bounceBAnim;

  // Round complete pulse
  late AnimationController _completePulseCtrl;
  late Animation<double> _completePulseAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _itemDanceCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _itemEnterCtrl.dispose();
    _bounceACtrl.dispose();
    _bounceBCtrl.dispose();
    _bounceCCtrl.dispose();
    _completePulseCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Animation init ─────────────────────────────────────────────────────────

  void _initAnimations() {
    _roxieFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _roxieSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _roxieSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut),
        );
    _roxieFade = CurvedAnimation(
      parent: _roxieSlideCtrl,
      curve: const Interval(0, 0.4),
    );

    _itemDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _itemDance = Tween<double>(
      begin: -0.06,
      end: 0.06,
    ).animate(CurvedAnimation(parent: _itemDanceCtrl, curve: Curves.easeInOut));

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _itemEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _itemEnterAnim = Tween<double>(begin: -60, end: 0).animate(
      CurvedAnimation(parent: _itemEnterCtrl, curve: Curves.elasticOut),
    );
    _itemEnterFade = CurvedAnimation(
      parent: _itemEnterCtrl,
      curve: const Interval(0, 0.4),
    );

    _bounceACtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceAAnim = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _bounceACtrl, curve: Curves.elasticOut));

    _bounceBCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceBAnim = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _bounceBCtrl, curve: Curves.elasticOut));

    _bounceCCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceCAnim = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _bounceCCtrl, curve: Curves.elasticOut));

    _completePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _completePulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _completePulseCtrl, curve: Curves.easeInOut),
    );
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();

    await _playAudio(_audioIntro);
    await _playAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));

    _gameEnterCtrl.forward();
    _startRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
    await _playAudio(_audioInstructions);
  }

  Future<void> _playAudio(String asset) async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      final completer = Completer<void>();
      final sub = player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 20));
      await sub.cancel();
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await player.stop();
      await player.dispose();
    }
  }

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);
    _basketObjectA = shuffled[0];
    _basketObjectB = shuffled[1];
    _basketObjectC = shuffled[2];

    // 3 of each, shuffled
    _itemQueue = [
      _basketObjectA,
      _basketObjectA,
      _basketObjectA,
      _basketObjectB,
      _basketObjectB,
      _basketObjectB,
      _basketObjectC,
      _basketObjectC,
      _basketObjectC,
    ]..shuffle(rng);

    _currentItemIndex = 0;
    _placedA = 0;
    _placedB = 0;
    _placedC = 0;

    _flashA = false;
    _flashB = false;
    _flashC = false;

    _roundComplete = false;

    _bounceACtrl.reset();
    _bounceBCtrl.reset();
    _itemHeld = false;
    _bounceCCtrl.reset();

    _completePulseCtrl.stop();
    _completePulseCtrl.reset();
    _enterCtrl.forward(from: 0);

    // Animate first item in
    _itemEnterCtrl.forward(from: 0);
  }

  // ── Drop logic ─────────────────────────────────────────────────────────────

  Future<void> _dropOnBasket(String basketObject) async {
    if (_roundComplete) return;
    if (_currentItemIndex >= _itemQueue.length) return;

    final currentItem = _itemQueue[_currentItemIndex];
    final isCorrect = currentItem == basketObject;

    if (isCorrect) {
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));

      showRoxieReaction(RoxieState.correct);

      setState(() {
        if (basketObject == _basketObjectA) {
          _placedA++;
          _bounceACtrl.forward(from: 0);
        } else if (basketObject == _basketObjectB) {
          _placedB++;
          _bounceBCtrl.forward(from: 0);
        } else {
          _placedC++;
          _bounceCCtrl.forward(from: 0);
        }
        _currentItemIndex++;
        _itemHeld = false;
      });

      // Check round complete
      if (_currentItemIndex >= _itemQueue.length) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _roundComplete = true);
        _completePulseCtrl.repeat(reverse: true);
        _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
        await Future.delayed(const Duration(milliseconds: 1400));

        if (_round >= _kTotalRounds) {
          await _sfxPlayer.stop();

          final completer = Completer<void>();
          final sub = _completePlayer.onPlayerComplete.listen((_) {
            if (!completer.isCompleted) completer.complete();
          });
          await _completePlayer.play(
            AssetSource(_audioComplete.replaceFirst('assets/', '')),
          );
          await completer.future.timeout(const Duration(seconds: 10));
          await sub.cancel();

          await PuzzleProgressService.instance.markLevelComplete(13);

          if (mounted) setState(() => _showWinDialog = true);
        } else {
          await _enterCtrl.reverse();
          if (mounted) {
            setState(() {
              _round++;
              _startRound();
            });
          }
        }
      } else {
        // Animate next item in
        _itemEnterCtrl.forward(from: 0);
      }
    } else {
      // Wrong basket
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));

      showRoxieReaction(RoxieState.wrong);

      setState(() {
        _itemHeld = false;
        if (basketObject == _basketObjectA) {
          _flashA = true;
        } else if (basketObject == _basketObjectB) {
          _flashB = true;
        } else {
          _flashC = true;
        }
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _flashA = false;
          _flashB = false;
          _flashC = false;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                Image.asset(
                  _bgImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Container(color: Colors.black.withValues(alpha: 0.15)),
              ],
            ),
          ),
          SafeArea(
            child: _screenPhase == _ScreenPhase.intro
                ? _buildIntroContent()
                : Stack(
                    children: [
                      FadeTransition(
                        opacity: _gameFade,
                        child: _buildGameContent(),
                      ),
                      buildRoxie(context),
                    ],
                  ),
          ),
          if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIntroContent() {
    return Stack(
      children: [
        Positioned(top: 8, left: 12, child: PuzzleBackButton()),
        Positioned.fill(
          top: 48,
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildIntroRoxie()),
              Expanded(flex: 6, child: _buildIntroDancingItems()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroRoxie() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final roxieH = h * 0.95;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _roxieFloatCtrl, curve: Curves.easeInOut),
        );
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _roxieSlide,
              child: FadeTransition(
                opacity: _roxieFade,
                child: AnimatedBuilder(
                  animation: _roxieFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, floatY),
                    child: child,
                  ),
                  child: Image.asset(
                    _characterImage,
                    height: roxieH,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Text('🐰', style: TextStyle(fontSize: roxieH * 0.5)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroDancingItems() {
    // Show a couple of sample objects dancing to hint at the game
    final sampleObjects = ['star', 'compass', 'jar', 'telescope'];

    return AnimatedBuilder(
      animation: _itemDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: List.generate(sampleObjects.length, (i) {
              final angle = _itemDance.value * ((i % 2 == 0) ? 1 : -1);
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: JarColorTheme.darkdesaturatedblue.withValues(
                        alpha: 0.25,
                      ),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/objects/puzzle/${sampleObjects[i]}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🧺', style: TextStyle(fontSize: 28)),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameContent() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildGameHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildGameArea()),
          _buildProgressDots(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildGameHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Basket Sort',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 22,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Basket A
              _buildBasket(
                objectName: _basketObjectA,
                placedCount: _placedA,
                isFlashing: _flashA,
                bounceAnim: _bounceAAnim,
                bounceCtrl: _bounceACtrl,
              ),

              const SizedBox(width: 24),

              _buildCenterItem(),

              const SizedBox(width: 24),
              // Basket B
              _buildBasket(
                objectName: _basketObjectB,
                placedCount: _placedB,
                isFlashing: _flashB,
                bounceAnim: _bounceBAnim,
                bounceCtrl: _bounceBCtrl,
              ),

              const SizedBox(width: 24),
              // Basket C
              _buildBasket(
                objectName: _basketObjectC,
                placedCount: _placedC,
                isFlashing: _flashC,
                bounceAnim: _bounceCAnim,
                bounceCtrl: _bounceCCtrl,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Current item in center ─────────────────────────────────────────────────

  Widget _buildCenterItem() {
    if (_roundComplete) {
      return ScaleTransition(
        scale: _completePulseAnim,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: JarColorTheme.goldenyellow.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(color: JarColorTheme.sunnyhue, width: 3),
          ),
          child: const Center(child: Text('⭐', style: TextStyle(fontSize: 40))),
        ),
      );
    }

    if (_currentItemIndex >= _itemQueue.length) {
      return const SizedBox(width: 90);
    }

    final currentObject = _itemQueue[_currentItemIndex];
    final remaining = _itemQueue.length - _currentItemIndex;

    final itemWidget = AnimatedBuilder(
      animation: _itemEnterCtrl,
      builder: (_, child) {
        return FadeTransition(
          opacity: _itemEnterFade,
          child: Transform.translate(
            offset: Offset(0, _itemEnterAnim.value),
            child: child,
          ),
        );
      },
      child: Draggable<String>(
        data: currentObject,
        onDragStarted: () => setState(() => _itemHeld = true),
        onDraggableCanceled: (_, __) => setState(() => _itemHeld = false),
        onDragCompleted: () => setState(() => _itemHeld = false),
        feedback: Material(
          color: Colors.transparent,
          child: _buildItemTile(currentObject, size: 82, isDragging: true),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: _buildItemTile(currentObject, size: 80),
        ),
        child: GestureDetector(
          // Tap to select, then tap a basket to place
          onTap: () => setState(() => _itemHeld = !_itemHeld),
          child: _buildItemTile(currentObject, size: 80, isHeld: _itemHeld),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        itemWidget,
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$remaining left',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 14,
              color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(
    String objectName, {
    double size = 80,
    bool isHeld = false,
    bool isDragging = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isHeld || isDragging
            ? JarColorTheme.goldenyellow.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isHeld || isDragging
              ? JarColorTheme.sunnyhue
              : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
          width: isHeld || isDragging ? 3 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isHeld || isDragging
                ? JarColorTheme.sunnyhue.withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: isHeld || isDragging ? 14 : 8,
            spreadRadius: isHeld || isDragging ? 2 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Image.asset(
        'assets/images/objects/puzzle/$objectName.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Text('🧺', style: TextStyle(fontSize: 28)),
      ),
    );
  }

  // ── Basket ─────────────────────────────────────────────────────────────────

  Widget _buildBasket({
    required String objectName,
    required int placedCount,
    required bool isFlashing,
    required Animation<double> bounceAnim,
    required AnimationController bounceCtrl,
  }) {
    final hasItem = _currentItemIndex < _itemQueue.length && !_roundComplete;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _dropOnBasket(objectName),
      builder: (context, candidateData, _) {
        return GestureDetector(
          onTap: hasItem ? () => _dropOnBasket(objectName) : null,
          child: ScaleTransition(
            scale: bounceAnim,
            child: SizedBox(
              width: 220,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Object label image
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/objects/puzzle/basket.png',
                        width: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Text('🧺', style: TextStyle(fontSize: 40)),
                      ),
                      // Small label badge at top
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: JarColorTheme.darkdesaturatedblue
                                  .withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/images/objects/puzzle/$objectName.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('?', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ),
                      // Placed items shown inside basket
                      if (placedCount > 0)
                        Positioned(
                          bottom: 18,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 2,
                            children: List.generate(
                              placedCount,
                              (_) => Image.asset(
                                'assets/images/objects/puzzle/$objectName.png',
                                width: 50,
                                height: 50,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                      // Full checkmark
                      if (placedCount >= 3)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kTotalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? JarColorTheme.darkdesaturatedblue
                : current
                ? JarColorTheme.sunnyhue
                : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: JarColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.pop(context, const Lvl14SizeSort2Screen());
      },
      onRestart: () {
        Navigator.pop(context, const Lvl13BasketSort2Screen());
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
