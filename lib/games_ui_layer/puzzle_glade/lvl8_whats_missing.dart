import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_level.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl9_pattern_match2.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ── Game phases ────────────────────────────────────────────────────────────
enum _GamePhase { showing, guessing, correct, wrong }

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
  'water_bottle',
];

const int _kTotalRounds = 5;
const int _kShowSeconds = 4;
const int _kObjectCount = 1; // objects shown per round

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Lvl8WhatsMissingScreen extends StatefulWidget {
  const Lvl8WhatsMissingScreen({super.key});

  @override
  State<Lvl8WhatsMissingScreen> createState() =>
      _Lvl8WhatsMissingScreenState();
}

class _Lvl8WhatsMissingScreenState extends State<Lvl8WhatsMissingScreen>
    with TickerProviderStateMixin {
  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage =
      'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/level8/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level8/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level8/instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/level8/complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  _GamePhase _gamePhase = _GamePhase.showing;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;

  /// The 3 objects shown this round
  late List<String> _shownObjects;

  /// The object that was removed
  late String _missingObject;

  /// 2 choices: one correct, one wrong
  late List<String> _choices;

  /// Countdown timer value
  int _countdown = _kShowSeconds;
  Timer? _countdownTimer;

  bool _showWinDialog = false;

  /// Which choice was tapped (for feedback highlight)
  String? _tappedChoice;

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

  // Missing slot pulse
  late AnimationController _missingPulseCtrl;
  late Animation<double> _missingPulseAnim;

  // Countdown ring
  late AnimationController _countdownRingCtrl;

  // Choice feedback bounce
  late AnimationController _correctBounceCtrl;
  late Animation<double> _correctBounceAnim;

  // Round complete pulse
  late AnimationController _completePulseCtrl;

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
    _countdownTimer?.cancel();
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _itemDanceCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _missingPulseCtrl.dispose();
    _countdownRingCtrl.dispose();
    _correctBounceCtrl.dispose();
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
    _roxieSlide =
        Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero).animate(
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
    _itemDance = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _itemDanceCtrl, curve: Curves.easeInOut),
    );

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

    _missingPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _missingPulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _missingPulseCtrl, curve: Curves.easeInOut),
    );

    _countdownRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _kShowSeconds),
    );

    _correctBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _correctBounceAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _correctBounceCtrl, curve: Curves.elasticOut),
    );

    _completePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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

    // Pick 3 objects to show
    _shownObjects = shuffled.sublist(0, _kObjectCount);

    // Pick one to be missing
    _missingObject = _shownObjects[rng.nextInt(_kObjectCount)];

    // 2 choices: correct + 1 wrong distractor from remaining objects
    final distractors = shuffled.sublist(_kObjectCount);
    final wrongChoice = distractors[rng.nextInt(distractors.length)];
    _choices = [_missingObject, wrongChoice]..shuffle(rng);

    _tappedChoice = null;
    _countdown = _kShowSeconds;
    _gamePhase = _GamePhase.showing;

    _missingPulseCtrl.stop();
    _missingPulseCtrl.reset();
    _correctBounceCtrl.reset();
    _completePulseCtrl.stop();
    _completePulseCtrl.reset();
    _enterCtrl.forward(from: 0);

    // Start countdown ring animation
    _countdownRingCtrl.forward(from: 0);

    // Start countdown timer
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _revealMissing();
      }
    });
  }

  void _revealMissing() {
    if (!mounted) return;
    setState(() => _gamePhase = _GamePhase.guessing);
    _missingPulseCtrl.repeat(reverse: true);
  }

  // ── Guess logic ────────────────────────────────────────────────────────────

  Future<void> _onChoiceTapped(String choice) async {
    if (_gamePhase != _GamePhase.guessing) return;

    final isCorrect = choice == _missingObject;
    setState(() {
      _tappedChoice = choice;
      _gamePhase = isCorrect ? _GamePhase.correct : _GamePhase.wrong;
    });

    if (isCorrect) {
      _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
      _correctBounceCtrl.forward(from: 0);
      _missingPulseCtrl.stop();

      await Future.delayed(const Duration(milliseconds: 1000));

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
        if (mounted) setState(() => _showWinDialog = true);
      } else {
        await _enterCtrl.reverse();
        if (mounted) {
          setState(() => _round++);
          _startRound();
        }
      }
    } else {
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        setState(() {
          _tappedChoice = null;
          _gamePhase = _GamePhase.guessing;
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
                : FadeTransition(
              opacity: _gameFade,
              child: _buildGameContent(),
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
        final roxieH = h * 1.05;
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
    final sampleObjects = ['compass', 'star', 'telescope'];

    return AnimatedBuilder(
      animation: _itemDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(sampleObjects.length, (i) {
              final angle = _itemDance.value * ((i % 2 == 0) ? 1 : -1);
              // middle one shown as question mark to hint the game
              final isMiddle = i == 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: isMiddle
                          ? JarColorTheme.goldenyellow.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isMiddle
                            ? JarColorTheme.sunnyhue
                            : JarColorTheme.darkdesaturatedblue
                            .withValues(alpha: 0.25),
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
                    child: isMiddle
                        ? Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: JarColorTheme.sunnyhue,
                        ),
                      ),
                    )
                        : Image.asset(
                      'assets/images/objects/puzzle/${sampleObjects[i]}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        '🔭',
                        style: TextStyle(fontSize: 28),
                      ),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                'What\'s Missing?',
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
    return Row(
      children: [
        // LEFT: object display area
        Expanded(
          flex: 6,
          child: Center(child: _buildObjectDisplay()),
        ),
        // RIGHT: choices or countdown
        Expanded(
          flex: 4,
          child: Center(child: _buildRightPanel()),
        ),
      ],
    );
  }

  // ── Object display ─────────────────────────────────────────────────────────

  Widget _buildObjectDisplay() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phase label
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _gamePhase == _GamePhase.showing
                ? JarColorTheme.sunnyhue.withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _gamePhase == _GamePhase.showing
                ? 'Remember this!'
                : 'What\'s missing?',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _gamePhase == _GamePhase.showing
                  ? Colors.white
                  : JarColorTheme.darkdesaturatedblue,
            ),
          ),
        ),
        // Object tiles row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_kObjectCount, (i) {
            final obj = _shownObjects[i];
            final isMissing =
                _gamePhase != _GamePhase.showing && obj == _missingObject;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: isMissing
                  ? _buildMissingSlot()
                  : _buildObjectTile(obj),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildObjectTile(String objectName) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Image.asset(
        'assets/images/objects/puzzle/$objectName.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
        const Text('📦', style: TextStyle(fontSize: 28)),
      ),
    );
  }

  Widget _buildMissingSlot() {
    return ScaleTransition(
      scale: _missingPulseAnim,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: JarColorTheme.goldenyellow.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: JarColorTheme.sunnyhue,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: JarColorTheme.sunnyhue.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '?',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: JarColorTheme.sunnyhue,
            ),
          ),
        ),
      ),
    );
  }

  // ── Right panel: countdown or choices ─────────────────────────────────────

  Widget _buildRightPanel() {
    if (_gamePhase == _GamePhase.showing) {
      return _buildCountdown();
    }
    return _buildChoices();
  }

  Widget _buildCountdown() {
    // Pick color based on urgency
    final Color ringColor = _countdown <= 1
        ? const Color(0xFFE05A5A)
        : _countdown <= 2
        ? JarColorTheme.sunnyhue
        : JarColorTheme.darkdesaturatedblue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: AnimatedBuilder(
            animation: _countdownRingCtrl,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: 1.0 - _countdownRingCtrl.value,
                      strokeWidth: 7,
                      backgroundColor:
                      JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: JarAppTextStyles.fredoka,
                      fontSize: _countdown <= 1 ? 42 : 36,
                      fontWeight: FontWeight.bold,
                      color: ringColor,
                    ),
                    child: Text('$_countdown'),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Get ready!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildChoices() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pick the missing one!',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.90),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        ..._choices.map((choice) => _buildChoiceTile(choice)),
      ],
    );
  }

  Widget _buildChoiceTile(String objectName) {
    final isCorrect = objectName == _missingObject;
    final isTapped = _tappedChoice == objectName;
    final isWrongTap = isTapped && !isCorrect;
    final isCorrectTap = isTapped && isCorrect;

    Color borderColor = JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.28);
    Color bgColor = Colors.white.withValues(alpha: 0.90);

    if (isWrongTap) {
      borderColor = const Color(0xFFE05A5A);
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.12);
    } else if (isCorrectTap) {
      borderColor = Colors.green;
      bgColor = Colors.green.withValues(alpha: 0.12);
    }

    Widget tile = GestureDetector(
      onTap: () => _onChoiceTapped(objectName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 130,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Image.asset(
                'assets/images/objects/puzzle/$objectName.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                const Text('📦', style: TextStyle(fontSize: 24)),
              ),
            ),
            // Feedback icon
            if (isWrongTap) ...[
              const SizedBox(width: 6),
              const Icon(Icons.close_rounded,
                  color: Color(0xFFE05A5A), size: 22),
            ] else if (isCorrectTap) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_rounded, color: Colors.green, size: 22),
            ],
          ],
        ),
      ),
    );

    if (isCorrectTap) {
      return ScaleTransition(scale: _correctBounceAnim, child: tile);
    }
    return tile;
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
                : JarColorTheme.darkdesaturatedblue
                .withValues(alpha: 0.20),
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Lvl9PatternMatch2Screen()),
        );      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Lvl8WhatsMissingScreen()),
        );
      },
      onBack: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PuzzleLevelScreen()),
        );
      },
    );
  }
}