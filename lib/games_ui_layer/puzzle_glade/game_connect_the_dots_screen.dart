import 'dart:async';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
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
import 'game_copy_pattern.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Puzzle model
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectDotsPuzzle {
  final String name;
  final List<Offset> dots; // normalized 0.0–1.0 positions, in connect order
  final String completedImage;

  const _ConnectDotsPuzzle({
    required this.name,
    required this.dots,
    required this.completedImage,
  });

  int get connectionCount => dots.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Puzzle definitions (one per round, dot count ramps 4 → 8)
// ─────────────────────────────────────────────────────────────────────────────

// Round 1 — 4 dots, kite / diamond outline.
const _ConnectDotsPuzzle _kPuzzleKite = _ConnectDotsPuzzle(
  name: 'kite',
  dots: [
    Offset(0.50, 0.15), // 1 — top
    Offset(0.78, 0.50), // 2 — right
    Offset(0.50, 0.85), // 3 — bottom
    Offset(0.22, 0.50), // 4 — left
  ],
  completedImage: 'assets/images/objects/puzzle/connect_the_dots_kite.png',
);

// Round 2 — 5 dots, one-stroke star traversal.
const _ConnectDotsPuzzle _kPuzzleStar = _ConnectDotsPuzzle(
  name: 'star',
  dots: [
    Offset(0.50, 0.15), // 1 — top point
    Offset(0.68, 0.68), // 2 — bottom-right point
    Offset(0.20, 0.36), // 3 — mid-left point
    Offset(0.80, 0.36), // 4 — mid-right point
    Offset(0.32, 0.68), // 5 — bottom-left point
  ],
  completedImage: 'assets/images/objects/puzzle/star.png',
);

// Round 3 — 6 dots, house outline.
const _ConnectDotsPuzzle _kPuzzleHouse = _ConnectDotsPuzzle(
  name: 'house',
  dots: [
    Offset(0.25, 0.85), // 1 — bottom-left
    Offset(0.25, 0.50), // 2 — wall top-left / roof base-left
    Offset(0.50, 0.20), // 3 — roof peak
    Offset(0.75, 0.50), // 4 — wall top-right / roof base-right
    Offset(0.75, 0.85), // 5 — bottom-right
    Offset(0.50, 0.85), // 6 — bottom-middle
  ],
  completedImage: 'assets/images/objects/puzzle/house.png',
);

// Round 4 — 7 dots, fish outline.
const _ConnectDotsPuzzle _kPuzzleFish = _ConnectDotsPuzzle(
  name: 'fish',
  dots: [
    Offset(0.12, 0.50), // 1 — nose
    Offset(0.32, 0.28), // 2 — top-front body
    Offset(0.58, 0.26), // 3 — top-back body
    Offset(0.88, 0.14), // 4 — tail tip, top
    Offset(0.66, 0.50), // 5 — tail notch
    Offset(0.88, 0.86), // 6 — tail tip, bottom
    Offset(0.32, 0.72), // 7 — bottom-back body
  ],
  completedImage: 'assets/images/objects/puzzle/fish.png',
);

// Round 5 — 8 dots, rocket outline.
const _ConnectDotsPuzzle _kPuzzleRocket = _ConnectDotsPuzzle(
  name: 'rocket',
  dots: [
    Offset(0.50, 0.08), // 1 — nose tip
    Offset(0.64, 0.32), // 2 — right upper body
    Offset(0.64, 0.68), // 3 — right lower body
    Offset(0.84, 0.90), // 4 — right fin
    Offset(0.50, 0.72), // 5 — bottom center
    Offset(0.16, 0.90), // 6 — left fin
    Offset(0.36, 0.68), // 7 — left lower body
    Offset(0.36, 0.32), // 8 — left upper body
  ],
  completedImage: 'assets/images/objects/puzzle/rocket.png',
);

const int _kTotalRounds = 5;

const List<_ConnectDotsPuzzle> _kPuzzles = [
  _kPuzzleKite,
  _kPuzzleStar,
  _kPuzzleHouse,
  _kPuzzleFish,
  _kPuzzleRocket,
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ConnectTheDotsScreen extends StatefulWidget {
  final int level;

  const ConnectTheDotsScreen({super.key, required this.level});

  @override
  State<ConnectTheDotsScreen> createState() => _ConnectTheDotsScreenState();
}

class _ConnectTheDotsScreenState extends State<ConnectTheDotsScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<ConnectTheDotsScreen>, GameLoadingMixin {
  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/connect_the_dots_intro.wav';
  static const String _audioInstruction = 'assets/audio/puzzle_glade/connect_the_dots_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/connect_the_dots_complete.wav';

  // Shared pop/tap sfx reused from existing Puzzle Glade assets. If this
  // filename doesn't exist in the project, the try/catch in _playPopSfx
  // silently no-ops — swap in the real shared asset name if different.
  static const String _audioPop = 'audio/puzzle_glade/sfx_pop.mp3';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round / puzzle state ──────────────────────────────────────────────────
  int _round = 1;
  _ConnectDotsPuzzle get _puzzle => _kPuzzles[_round - 1];

  int _activeDotIndex = 0;
  int _completedConnections = 0;

  Offset? _dragPosition;
  bool _isDragging = false;

  bool _interactionDisabled = true;
  bool _roundComplete = false;
  bool _showCompletedPicture = false;
  bool _showWinDialog = false;
  bool _instructionPlayed = false;

  int? _wrongDotIndex;
  int? _bounceDotIndex;

  Size _puzzleBoxSize = Size.zero;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _popPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _roxiePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _introPreviewCtrl;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round
  late AnimationController _puzzleEnterCtrl;
  late Animation<double> _puzzleFade;
  late Animation<double> _puzzleScale;
  late AnimationController _activePulseCtrl;
  late Animation<double> _activePulse;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _pictureRevealCtrl;
  late Animation<double> _pictureFade;
  late Animation<double> _pictureScale;

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
    _bgPlayer.stop();
    _popPlayer.stop();
    _completePlayer.stop();
    _roxiePlayer.stop();

    _bgPlayer.dispose();
    _popPlayer.dispose();
    _completePlayer.dispose();
    _roxiePlayer.dispose();

    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _introPreviewCtrl.dispose();
    _gameEnterCtrl.dispose();
    _puzzleEnterCtrl.dispose();
    _activePulseCtrl.dispose();
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    _pictureRevealCtrl.dispose();

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
        .animate(CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut));
    _roxieFade = CurvedAnimation(parent: _roxieSlideCtrl, curve: const Interval(0, 0.4));

    _introPreviewCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _puzzleEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _puzzleFade = CurvedAnimation(parent: _puzzleEnterCtrl, curve: Curves.easeOut);
    _puzzleScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _puzzleEnterCtrl, curve: Curves.easeOut),
    );

    _activePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _activePulse = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _activePulseCtrl, curve: Curves.easeInOut),
    );

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: -5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _pictureRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pictureFade = CurvedAnimation(parent: _pictureRevealCtrl, curve: Curves.easeIn);
    _pictureScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pictureRevealCtrl, curve: Curves.easeOut),
    );
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    _roxieSlideCtrl.forward();

    await _playNarration(_audioIntro);

    if (!mounted) return;

    _gameEnterCtrl.forward();

    _startRound();

    if (!mounted) return;

    setState(() {
      _screenPhase = _ScreenPhase.game;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;

    await _playInstructionAudio();
  }

  Future<void> _playNarration(String asset) async {
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

  /// Plays once, the first time gameplay is reached. Rounds 2–5 begin
  /// immediately after their entrance animation with no repeated narration.
  Future<void> _playInstructionAudio() async {
    if (!mounted || _instructionPlayed) return;
    _instructionPlayed = true;

    if (mounted) {
      setState(() {
        _interactionDisabled = true;
      });
    }

    await _playNarration(_audioInstruction);

    if (!mounted) return;

    if (!_roundComplete) {
      setState(() {
        _interactionDisabled = false;
      });
    }
  }

  Future<void> _playPopSfx() async {
    try {
      await _popPlayer.play(AssetSource(_audioPop));
    } catch (_) {
      // Pop sfx is a nice-to-have; ignore failures silently.
    }
  }

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    if (!mounted) return;

    _activeDotIndex = 0;
    _completedConnections = 0;
    _dragPosition = null;
    _isDragging = false;
    _wrongDotIndex = null;
    _bounceDotIndex = null;
    _roundComplete = false;
    _showCompletedPicture = false;
    _interactionDisabled = !_instructionPlayed;

    _bounceCtrl.reset();
    _shakeCtrl.reset();
    _pictureRevealCtrl.reset();
    _puzzleEnterCtrl.forward(from: 0);
  }

  // ── Coordinate helpers ────────────────────────────────────────────────────

  static const double _dotInset = 30.0;
  static const double _dotHitRadius = 48.0;

  Offset _dotToPixel(Offset normalized, Size boxSize) {
    final w = boxSize.width - _dotInset * 2;
    final h = boxSize.height - _dotInset * 2;
    return Offset(
      _dotInset + normalized.dx * w,
      _dotInset + normalized.dy * h,
    );
  }

  List<Offset> get _dotPixelPositions {
    if (_puzzleBoxSize == Size.zero) return const [];
    return _puzzle.dots.map((d) => _dotToPixel(d, _puzzleBoxSize)).toList();
  }

  // ── Gesture handling ──────────────────────────────────────────────────────

  void _handlePanStart(DragStartDetails details) {
    if (_interactionDisabled ||
        _roundComplete ||
        _isDragging) {
      return;
    }

    final positions = _dotPixelPositions;

    if (positions.isEmpty ||
        _activeDotIndex >= positions.length) {
      return;
    }

    final distanceFromActive =
        (positions[_activeDotIndex] -
            details.localPosition)
            .distance;

    if (distanceFromActive > _dotHitRadius) {
      return;
    }

    setState(() {
      _isDragging = true;
      _dragPosition = positions[_activeDotIndex];
    });
  }

  Future<void> _handlePanUpdate(DragUpdateDetails details) async {
    if (!_isDragging ||
        _interactionDisabled ||
        _roundComplete) {
      return;
    }

    final position = details.localPosition;
    final positions = _dotPixelPositions;

    if (positions.isEmpty) return;

    setState(() {
      _dragPosition = position;
    });

    // Normally:
    // 1 → 2
    // 2 → 3
    // 3 → 4
    //
    // But when we're on the LAST dot:
    // 4 → 1
    final int requiredNextIndex =
    _activeDotIndex == positions.length - 1
        ? 0
        : _activeDotIndex + 1;

    final distance =
        (positions[requiredNextIndex] - position).distance;

    if (distance <= _dotHitRadius) {
      await _handleCorrectConnection(requiredNextIndex);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    setState(() {
      _isDragging = false;
      _dragPosition = null;
    });
  }

  // ── Connection handling ───────────────────────────────────────────────────

  Future<void> _handleCorrectConnection(int newDotIndex) async {
    if (_roundComplete || _interactionDisabled) return;

    final newConnectionCount = _completedConnections + 1;

    setState(() {
      _completedConnections = newConnectionCount;
      _activeDotIndex = newDotIndex;
      _bounceDotIndex = newDotIndex;

    });

    if (mounted) {
      _bounceCtrl.forward(from: 0);
    }

    unawaited(_playPopSfx());

    if (_completedConnections >= _puzzle.connectionCount) {
      setState(() {
        _isDragging = false;
        _dragPosition = null;
      });

      await _handleRoundComplete();
    }
  }

  // ── Round / game completion ───────────────────────────────────────────────

  Future<void> _handleRoundComplete() async {
    setState(() {
      _roundComplete = true;
      _interactionDisabled = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _showCompletedPicture = true;
    });
    _pictureRevealCtrl.forward(from: 0);

    unawaited(showRoxieReaction(RoxieState.correct));

    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    if (_round >= _kTotalRounds) {
      await _completeGame();
    } else {
      await _puzzleEnterCtrl.reverse();

      if (!mounted) return;

      setState(() {
        _round++;
      });

      _startRound();
    }
  }

  Future<void> _completeGame() async {
    await _bgPlayer.stop();

    if (!mounted) return;

    final completer = Completer<void>();
    final sub = _completePlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await _completePlayer.play(
        AssetSource(_audioComplete.replaceFirst('assets/', '')),
      );
      await completer.future.timeout(const Duration(seconds: 10));
    } finally {
      await sub.cancel();
    }

    if (!mounted) return;

    await PuzzleProgressService.instance.markLevelComplete(widget.level);

    if (!mounted) return;

    setState(() => _showWinDialog = true);
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
                        child: _buildGameArea(),
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Looping 3-dot "1 → 2 → 3" animation. Purely decorative — the child
  /// does not interact with this preview.
  Widget _buildIntroPreview() {
    const previewDots = [
      Offset(0.15, 0.75),
      Offset(0.50, 0.20),
      Offset(0.85, 0.75),
    ];

    return Center(
      child: Container(
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
            width: 2.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: _introPreviewCtrl,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _IntroPreviewPainter(
                dots: previewDots,
                progress: _introPreviewCtrl.value,
                lineColor: PuzzleColorTheme.sunnyhue,
                dotColor: PuzzleColorTheme.darkdesaturatedblue,
              ),
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameArea() {
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
        Expanded(child: _buildPuzzleArea()),
        Padding(
          padding: const EdgeInsets.only(bottom: 15, top: 6),
          child: PuzzleProgressDots(
            currentRound: _round,
            totalRounds: _kTotalRounds,
          ),
        ),
      ],
    );
  }

  Widget _buildPuzzleArea() {
    return Center(
      child: FadeTransition(
        opacity: _puzzleFade,
        child: ScaleTransition(
          scale: _puzzleScale,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boxSize = Size(
                constraints.maxWidth.clamp(0, 520),
                constraints.maxHeight.clamp(0, 340),
              );
              _puzzleBoxSize = boxSize;

              return SizedBox(
                width: boxSize.width,
                height: boxSize.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _handlePanStart,
                  onPanUpdate: _handlePanUpdate,
                  onPanEnd: _handlePanEnd,
                  onPanCancel: () {
                    if (!_isDragging) return;

                    setState(() {
                      _isDragging = false;
                      _dragPosition = null;
                    });
                  },
                  child: Stack(
                    children: [
                      // Completed picture
                      if (_showCompletedPicture)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: FadeTransition(
                              opacity: _pictureFade,
                              child: ScaleTransition(
                                scale: _pictureScale,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Image.asset(
                                    _puzzle.completedImage,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Connection lines
                      Positioned.fill(
                        child: IgnorePointer(
                          child: FadeTransition(
                            // Lines fade OUT while completed picture fades IN.
                            opacity: ReverseAnimation(_pictureFade),
                            child: CustomPaint(
                              painter: _ConnectDotsPainter(
                                dotPositions: _dotPixelPositions,
                                completedConnections: _completedConnections,
                                dragPosition: _isDragging ? _dragPosition : null,
                                activeDotIndex: _activeDotIndex,
                                lineColor: PuzzleColorTheme.sunnyhue,
                                dragLineColor: PuzzleColorTheme.darkdesaturatedblue
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Numbered dots
                      ..._buildDotWidgets(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDotWidgets() {
    final positions = _dotPixelPositions;
    if (positions.isEmpty) return const [];

    return List.generate(positions.length, (index) {
      final isActive = index == _activeDotIndex && !_roundComplete;
      final isWrong = _wrongDotIndex == index;
      final isBouncing = _bounceDotIndex == index;
      final isCompleted = index < _activeDotIndex || (index == _activeDotIndex && _roundComplete);

      Widget dot = _ConnectDotMarker(
        number: index + 1,
        isActive: isActive,
        isCompleted: isCompleted,
        isWrong: isWrong,
      );

      if (isActive) {
        dot = ScaleTransition(scale: _activePulse, child: dot);
      }
      if (isBouncing) {
        dot = ScaleTransition(scale: _bounceAnim, child: dot);
      }
      if (isWrong) {
        dot = AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0),
            child: child,
          ),
          child: dot,
        );
      }

      return Positioned(
        left: positions[index].dx - 26,
        top: positions[index].dy - 26,
        child: FadeTransition(
          opacity: ReverseAnimation(_pictureFade),
          child: dot,
        ),
      );
    });
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CopyPatternScreen(level: widget.level),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectTheDotsScreen(level: widget.level),
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
// Dot marker widget
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectDotMarker extends StatelessWidget {
  final int number;
  final bool isActive;
  final bool isCompleted;
  final bool isWrong;

  const _ConnectDotMarker({
    required this.number,
    required this.isActive,
    required this.isCompleted,
    required this.isWrong,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.white.withValues(alpha: 0.92);
    Color borderColor = PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.35);
    Color textColor = PuzzleColorTheme.darkdesaturatedblue;

    if (isCompleted) {
      bgColor = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.55);
      borderColor = PuzzleColorTheme.sunnyhue;
    }
    if (isActive) {
      bgColor = PuzzleColorTheme.sunnyhue.withValues(alpha: 0.85);
      borderColor = PuzzleColorTheme.sunnyhue;
      textColor = Colors.white;
    }
    if (isWrong) {
      bgColor = const Color(0xFFE05A5A).withValues(alpha: 0.20);
      borderColor = const Color(0xFFE05A5A);
    }

    return Container(
      // Visual circle is smaller than the actual touch target — the touch
      // tolerance radius used for hit detection is defined separately in
      // _dotHitRadius, generously larger than this 52px visual size.
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter — permanent connection lines + live drag line
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectDotsPainter extends CustomPainter {
  final List<Offset> dotPositions;
  final int completedConnections;
  final Offset? dragPosition;
  final int activeDotIndex;
  final Color lineColor;
  final Color dragLineColor;

  _ConnectDotsPainter({
    required this.dotPositions,
    required this.completedConnections,
    required this.dragPosition,
    required this.activeDotIndex,
    required this.lineColor,
    required this.dragLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dotPositions.isEmpty) return;

    final completedPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < completedConnections; i++) {
      if (dotPositions.isEmpty) break;

      final startIndex = i;

      final endIndex =
          (i + 1) % dotPositions.length;

      if (startIndex >= dotPositions.length) {
        break;
      }

      canvas.drawLine(
        dotPositions[startIndex],
        dotPositions[endIndex],
        completedPaint,
      );
    }

    // Draw the live drag line from the active dot to the current pointer.
    if (dragPosition != null && activeDotIndex < dotPositions.length) {
      final dragPaint = Paint()
        ..color = dragLineColor
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(dotPositions[activeDotIndex], dragPosition!, dragPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectDotsPainter oldDelegate) {
    return oldDelegate.completedConnections != completedConnections ||
        oldDelegate.dragPosition != dragPosition ||
        oldDelegate.activeDotIndex != activeDotIndex ||
        oldDelegate.dotPositions != dotPositions;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter — small looping intro preview (1 → 2 → 3)
// ─────────────────────────────────────────────────────────────────────────────

class _IntroPreviewPainter extends CustomPainter {
  final List<Offset> dots; // normalized 0.0–1.0
  final double progress; // 0.0–1.0, loops
  final Color lineColor;
  final Color dotColor;

  _IntroPreviewPainter({
    required this.dots,
    required this.progress,
    required this.lineColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dots.isEmpty) return;

    final pixelDots = dots.map((d) => Offset(d.dx * size.width, d.dy * size.height)).toList();

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = dotColor;

    // progress 0.0–0.5 draws segment 1→2, 0.5–1.0 draws segment 2→3, then
    // loops back to the start (repeat()).
    if (progress < 0.5) {
      final t = (progress / 0.5).clamp(0.0, 1.0);
      final end = Offset.lerp(pixelDots[0], pixelDots[1], t)!;
      canvas.drawLine(pixelDots[0], end, linePaint);
    } else {
      canvas.drawLine(pixelDots[0], pixelDots[1], linePaint);
      final t = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
      final end = Offset.lerp(pixelDots[1], pixelDots[2], t)!;
      canvas.drawLine(pixelDots[1], end, linePaint);
    }

    for (int i = 0; i < pixelDots.length; i++) {
      canvas.drawCircle(pixelDots[i], 10, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntroPreviewPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
