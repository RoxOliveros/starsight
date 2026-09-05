  import 'dart:async';
  import 'dart:math';
  import 'package:StarSight/business_layer/puzzle_progress_service.dart';
  import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_audio_helper.dart';
  import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
  import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
  import 'package:flutter/material.dart';
  import 'package:audioplayers/audioplayers.dart';
  import 'package:StarSight/business_layer/orientation_service.dart';
  import '../../ui_layer/game_loading_mixin.dart';
  import '../../ui_layer/loading_screen.dart';
  import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
  import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
  import '../goodjob_prompt.dart';
import 'game_what_goes_together_screen.dart';

  // ── Screen phases ──────────────────────────────────────────────────────────
  enum _ScreenPhase { intro, game }

  // ─────────────────────────────────────────────────────────────────────────────
  // Constants
  // ─────────────────────────────────────────────────────────────────────────────

  const int _kTotalRounds = 5;

  // ─────────────────────────────────────────────────────────────────────────────
  // Object pool
  // ─────────────────────────────────────────────────────────────────────────────

  class _RotateObjectItem {
    final String id;
    final String name;
    final String asset;
    final String emoji; // fallback if the asset can't be loaded

    const _RotateObjectItem({
      required this.id,
      required this.name,
      required this.asset,
      required this.emoji,
    });
  }

  const List<_RotateObjectItem> _objectPool = [
    _RotateObjectItem(id: 'compass', name: 'Compass', asset: 'assets/images/objects/puzzle/compass.png', emoji: '🧭'),
    _RotateObjectItem(id: 'map', name: 'Map', asset: 'assets/images/objects/puzzle/map.png', emoji: '🗺️'),
    _RotateObjectItem(id: 'notebook', name: 'Notebook', asset: 'assets/images/objects/puzzle/notebook.png', emoji: '📓'),
    _RotateObjectItem(id: 'flag', name: 'Flag', asset: 'assets/images/objects/puzzle/flag.png', emoji: '🚩'),
    _RotateObjectItem(id: 'pen', name: 'Pen', asset: 'assets/images/objects/puzzle/pen.png', emoji: '🖊️'),
    _RotateObjectItem(id: 'jar', name: 'Jar', asset: 'assets/images/objects/puzzle/jar.png', emoji: '🏺'),
    _RotateObjectItem(id: 'puzzle_piece', name: 'Puzzle Piece', asset: 'assets/images/objects/puzzle/puzzle_piece.png', emoji: '🧩'),
    _RotateObjectItem(id: 'lamp', name: 'Lamp', asset: 'assets/images/objects/puzzle/lamp.png', emoji: '🏮'),
    _RotateObjectItem(id: 'magnifying_glass', name: 'Magnifying Glass', asset: 'assets/images/objects/puzzle/magnifying_glass.png', emoji: '🔍'),
    _RotateObjectItem(id: 'telescope', name: 'Telescope', asset: 'assets/images/objects/puzzle/telescope.png', emoji: '🔭'),
  ];

  // ─────────────────────────────────────────────────────────────────────────────
  // Difficulty
  // ─────────────────────────────────────────────────────────────────────────────

  // (snapDegrees, startTurns) — snapDegrees is the finest angle the drag
  // gesture snaps to on release; startTurns is how many of those turns away
  // from the target the puzzle copy begins (random direction). Both ramp up
  // with round number so later rounds need finer, more deliberate rotation.
  (double, int) _configForRound(int round) {
    switch (round) {
      case 1:
        return (90, 1);
      case 2:
        return (90, 1);
      case 3:
        return (90, 2);
      case 4:
        return (60, 2);
      default:
        return (45, 3);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Screen
  // ─────────────────────────────────────────────────────────────────────────────

  class RotateTheShapeScreen extends StatefulWidget {
    final int level;

    const RotateTheShapeScreen({super.key, required this.level});

    @override
    State<RotateTheShapeScreen> createState() => _RotateTheShapeScreenState();
  }

  class _RotateTheShapeScreenState extends State<RotateTheShapeScreen>
      with TickerProviderStateMixin, RoxieReactionMixin<RotateTheShapeScreen>, GameLoadingMixin, PuzzleAudioMixin {
    @override
    AudioPlayer get roxiePlayer => _roxieSfxPlayer;

    // ── Asset config ───────────────────────────────────────────────────────────
    static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
    static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

    static const String _audioIntro = 'assets/audio/puzzle_glade/rotate_shape_intro.wav';
    static const String _audioInstructions = 'assets/audio/puzzle_glade/rotate_shape_instruction.wav';
    static const String _audioComplete = 'assets/audio/puzzle_glade/rotate_shape_complete.wav';

    // ── Phase ──────────────────────────────────────────────────────────────────
    _ScreenPhase _screenPhase = _ScreenPhase.intro;

    // ── Round / puzzle state ──────────────────────────────────────────────────
    int _round = 1;
    final Set<String> _usedItemIds = {};
    _RotateObjectItem? _targetItem;
    late double _snapDeg;
    double _currentRotation = 0; // radians; target is always canonical 0
    bool _isWrongFlash = false;
    bool _isCompleting = false;
    DateTime? _lastWrongFeedback;
    bool _showWinDialog = false;

    // ── Drag tracking ──────────────────────────────────────────────────────────
    double _dragStartRotation = 0;
    double _dragStartAngle = 0;
    final GlobalKey _objectKey = GlobalKey();

    // ── Audio ──────────────────────────────────────────────────────────────────
    final AudioPlayer _bgPlayer = AudioPlayer();
    final AudioPlayer _sfxPlayer = AudioPlayer();
    final AudioPlayer _completePlayer = AudioPlayer();
    final AudioPlayer _roxieSfxPlayer = AudioPlayer(); // dedicated player for RoxieReactionMixin

    // ── Animations ─────────────────────────────────────────────────────────────

    // Shared
    late AnimationController _roxieFloatCtrl;

    // Intro
    late AnimationController _roxieSlideCtrl;
    late Animation<Offset> _roxieSlide;
    late Animation<double> _roxieFade;
    late AnimationController _demoRotateCtrl;
    late AnimationController _speechBubbleCtrl;

    // Game transition
    late AnimationController _gameEnterCtrl;
    late Animation<double> _gameFade;

    // Round
    late AnimationController _enterCtrl;
    late Animation<double> _enterAnim;

    // Rotation mechanics
    late AnimationController _snapCtrl; // animates settling to a snapped angle
    Animation<double>? _snapAnim;
    late AnimationController _wiggleCtrl; // gentle "not quite" feedback
    late AnimationController _celebrateCtrl; // success bounce + star burst
    bool _isRotating = false; // true while snapping/celebrating, blocks input

    // ── Lifecycle ──────────────────────────────────────────────────────────────

    @override
    void initState() {
      super.initState();
      OrientationService.setLandscape();
      _initAnimations();
      finishLoading(_startIntroFlow);
    }

    @override
    void dispose() {
      _bgPlayer.dispose();
      _sfxPlayer.dispose();
      _completePlayer.dispose();
      _roxieSfxPlayer.dispose();
      _roxieFloatCtrl.dispose();
      _roxieSlideCtrl.dispose();
      _demoRotateCtrl.dispose();
      _speechBubbleCtrl.dispose();
      _gameEnterCtrl.dispose();
      _enterCtrl.dispose();
      _snapCtrl.dispose();
      _wiggleCtrl.dispose();
      _celebrateCtrl.dispose();
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

      _demoRotateCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat();

      _speechBubbleCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
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

      _snapCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
      )..addListener(() {
        if (_snapAnim != null) {
          setState(() => _currentRotation = _snapAnim!.value);
        }
      });

      _wiggleCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      );

      _celebrateCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
    }

    // ── Intro flow ─────────────────────────────────────────────────────────────

    Future<void> _startIntroFlow() async {
      await Future.delayed(const Duration(milliseconds: 300));
      _roxieSlideCtrl.forward();

      _speechBubbleCtrl.forward(from: 0);
      await _playBgAudio(_audioIntro);

      _speechBubbleCtrl.forward(from: 0);

      _gameEnterCtrl.forward();
      _startRound();
      if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
      await _playBgAudio(_audioInstructions);
    }

    Future<void> _playBgAudio(String asset) async {
      StreamSubscription? sub;
      try {
        final completer = Completer<void>();
        sub = _bgPlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        await _bgPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
        await completer.future.timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('Audio error ($asset): $e');
      } finally {
        await sub?.cancel();
      }
    }

    // ── Round setup ────────────────────────────────────────────────────────────

    void _startRound() {
      final rng = Random();
      final (snapDeg, startTurns) = _configForRound(_round);
      final snapRad = snapDeg * pi / 180;
      final direction = rng.nextBool() ? 1 : -1;
      final startOffset = snapRad * startTurns * direction;

      var choices = _objectPool.where((o) => !_usedItemIds.contains(o.id)).toList();
      if (choices.isEmpty) {
        _usedItemIds.clear();
        choices = _objectPool;
      }
      final nextItem = choices[rng.nextInt(choices.length)];
      _usedItemIds.add(nextItem.id);

      setState(() {
        _targetItem = nextItem;
        _snapDeg = snapDeg;
        _currentRotation = startOffset;
        _isWrongFlash = false;
        _isCompleting = false;
        _isRotating = false;
      });

      _enterCtrl.forward(from: 0);
    }

    double get _snapRad => _snapDeg * pi / 180;

    // ── Rotation handling (drag only) ───────────────────────────────────────────

    void _onPanStart(DragStartDetails details) {
      if (_isRotating || _isCompleting) return;
      final box = _objectKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final center = box.size.center(Offset.zero);
      final local = box.globalToLocal(details.globalPosition);
      _dragStartAngle = atan2(local.dy - center.dy, local.dx - center.dx);
      _dragStartRotation = _currentRotation;
    }

    void _onPanUpdate(DragUpdateDetails details) {
      if (_isRotating || _isCompleting) return;
      final box = _objectKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final center = box.size.center(Offset.zero);
      final local = box.globalToLocal(details.globalPosition);
      final angle = atan2(local.dy - center.dy, local.dx - center.dx);
      setState(() {
        _currentRotation = _dragStartRotation + (angle - _dragStartAngle);
      });
    }

    void _onPanEnd(DragEndDetails details) {
      if (_isRotating || _isCompleting) return;
      final nearest = (_currentRotation / _snapRad).round() * _snapRad;
      _animateSnapTo(nearest);
    }

    void _animateSnapTo(double target) {
      setState(() => _isRotating = true);
      _snapAnim = Tween<double>(begin: _currentRotation, end: target).animate(
        CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutBack),
      );
      _snapCtrl.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() => _isRotating = false);
        _checkMatch();
      });
    }

    void _checkMatch() {
      const epsilon = 0.05;
      final normalized = _currentRotation % (2 * pi);
      final dist = min(normalized.abs(), (2 * pi - normalized.abs()));
      if (dist < epsilon) {
        _handleCorrectRotation();
      } else {
        _handleWrongRotation();
      }
    }

    void _handleWrongRotation() {
      final now = DateTime.now();
      if (_lastWrongFeedback != null &&
          now.difference(_lastWrongFeedback!) < const Duration(milliseconds: 500)) {
        return; // debounce rapid attempts
      }
      _lastWrongFeedback = now;

      unawaited(showRoxieReaction(RoxieState.wrong));
      setState(() => _isWrongFlash = true);
      _wiggleCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _isWrongFlash = false);
      });
    }

    Future<void> _handleCorrectRotation() async {
      setState(() => _isCompleting = true);
      unawaited(showRoxieReaction(RoxieState.correct));
      await _celebrateCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 300));
      await _advanceRound();
    }

    Future<void> _advanceRound() async {
      if (_round >= _kTotalRounds) {
        await _completeRound();
        return;
      }

      await _enterCtrl.reverse();
      if (!mounted) return;
      setState(() => _round++);
      _startRound();
    }

    Future<void> _completeRound() async {
      await _bgPlayer.stop();
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

      await PuzzleProgressService.instance.markLevelComplete(widget.level);

      if (mounted) setState(() => _showWinDialog = true);
    }

    // ── Build ──────────────────────────────────────────────────────────────────

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: buildWithLoading(
          loadingScreen: LoadingScreen.puzzleGlade(),
          gameBuilder: () => Stack(
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
              _screenPhase == _ScreenPhase.intro
                  ? _buildIntroLayer()
                  : Stack(
                children: [
                  FadeTransition(
                    opacity: _gameFade,
                    child: _buildGameLayer(),
                  ),
                  buildRoxie(context),
                ],
              ),
              if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
            ],
          ),
        ),
      );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // INTRO
    // ══════════════════════════════════════════════════════════════════════════

    Widget _buildIntroLayer() {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
                Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 4, child: _buildIntroRoxie()),
                Expanded(flex: 6, child: _buildIntroPreview()),
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

    // Small preview: the compass continuously spinning next to a static
    // upright copy, teasing the "drag it to match" mechanic before the round
    // starts — a compass is a natural fit for demonstrating rotation.
    Widget _buildIntroPreview() {
      const demoItem = _RotateObjectItem(
        id: 'compass',
        name: 'Compass',
        asset: 'assets/images/objects/puzzle/compass.png',
        emoji: '🧭',
      );
      return AnimatedBuilder(
        animation: _demoRotateCtrl,
        builder: (_, __) {
          final angle = _demoRotateCtrl.value * 2 * pi;
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.30),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ObjectImage(item: demoItem, size: 70, rotation: 0, faded: true),
                  const SizedBox(width: 18),
                  const Icon(Icons.touch_app_rounded, size: 28, color: PuzzleColorTheme.darkdesaturatedblue),
                  const SizedBox(width: 18),
                  _ObjectImage(item: demoItem, size: 70, rotation: angle),
                ],
              ),
            ),
          );
        },
      );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // GAME
    // ══════════════════════════════════════════════════════════════════════════

    Widget _buildGameLayer() {
      final target = _targetItem;
      if (target == null) return const SizedBox.shrink();

      return FadeTransition(
        opacity: _enterAnim,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
                  Align(
                    alignment: Alignment.center,
                    child: _buildRotateInstruction(target),
                  ),
                  Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
                ],
              ),
            ),
            Expanded(child: Center(child: _buildGameArea(target))),
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: PuzzleProgressDots(
                currentRound: _round,
                totalRounds: _kTotalRounds,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildRotateInstruction(_RotateObjectItem target) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: PuzzleColorTheme.lightgrayishyellow,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: PuzzleColorTheme.sunnyhue, width: 5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rotate the',
              style: TextStyle(
                fontFamily: PuzzleAppTextStyles.fredoka,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: PuzzleColorTheme.sunnyhue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              target.name,
              style: const TextStyle(
                fontFamily: PuzzleAppTextStyles.fredoka,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: PuzzleColorTheme.darkdesaturatedblue,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'to match!',
              style: TextStyle(
                fontFamily: PuzzleAppTextStyles.fredoka,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: PuzzleColorTheme.sunnyhue,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildGameArea(_RotateObjectItem target) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth * 0.92;
          final maxH = constraints.maxHeight * 0.92;

          return Container(
            width: maxW,
            height: maxH,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.25),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: _buildTargetObject(target)),
                Expanded(child: _buildPuzzleObject(target)),
              ],
            ),
          );
        },
      );
    }

    Widget _buildTargetObject(_RotateObjectItem target) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ObjectImage(item: target, size: 140, rotation: 0, faded: true),
          ],
        ),
      );
    }

    Widget _buildPuzzleObject(_RotateObjectItem target) {
      return Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_celebrateCtrl, _wiggleCtrl]),
          builder: (context, child) {
            final wiggle = _isWrongFlash
                ? sin(_wiggleCtrl.value * pi * 6) * 8 * (1 - _wiggleCtrl.value)
                : 0.0;
            final bounce = _celebrateCtrl.isAnimating
                ? 1.0 + (sin(_celebrateCtrl.value * pi) * 0.25)
                : 1.0;
            return Transform.translate(
              offset: Offset(wiggle, 0),
              child: Transform.scale(
                scale: bounce,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_celebrateCtrl.isAnimating) _buildStarBurst(),
                    child!,
                  ],
                ),
              ),
            );
          },
          child: GestureDetector(
            key: _objectKey,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            behavior: HitTestBehavior.opaque,
            child: _ObjectImage(
              item: target,
              size: 170,
              rotation: _currentRotation,
            ),
          ),
        ),
      );
    }

    Widget _buildStarBurst() {
      const count = 8;
      const colors = [
        PuzzleColorTheme.goldenyellow,
        PuzzleColorTheme.sunnyhue,
        PuzzleColorTheme.darkdesaturatedblue,
      ];
      return AnimatedBuilder(
        animation: _celebrateCtrl,
        builder: (_, __) {
          final progress = _celebrateCtrl.value;
          return Stack(
            alignment: Alignment.center,
            children: List.generate(count, (i) {
              final angle = (2 * pi / count) * i;
              final dist = 90 * progress;
              final opacity = (1 - progress).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(cos(angle) * dist, sin(angle) * dist),
                child: Opacity(
                  opacity: opacity,
                  child: Icon(
                    Icons.star_rounded,
                    color: colors[i % colors.length],
                    size: 26,
                  ),
                ),
              );
            }),
          );
        },
      );
    }

    // ── Win overlay ────────────────────────────────────────────────────────────

    Widget _buildWinOverlay() {
      return GoodJobOverlay(
        characterImage: _characterImage,
        
        onNext: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WhatGoesTogetherScreen(level: widget.level + 1),
            ),
          );
        },
        onRestart: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RotateTheShapeScreen(level: widget.level),
            ),
          );
        },
        onBack: () {
          Navigator.pop(context);
        },
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Object image widget
  // ─────────────────────────────────────────────────────────────────────────────

  class _ObjectImage extends StatelessWidget {
    final _RotateObjectItem item;
    final double size;
    final double rotation; // radians
    final bool elevated;
    final bool faded;

    const _ObjectImage({
      required this.item,
      required this.size,
      required this.rotation,
      this.elevated = false,
      this.faded = false,
    });

    @override
    Widget build(BuildContext context) {
      return Transform.rotate(
        angle: rotation,
        child: Container(
          width: size,
          height: size,
          decoration: elevated
              ? BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          )
              : null,
          child: Opacity(
            opacity: faded ? 0.55 : 1.0,
            child: Image.asset(
              item.asset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Text(item.emoji, style: TextStyle(fontSize: size * 0.7)),
              ),
            ),
          ),
        ),
      );
    }
  }