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
  import 'game_hidden_object.dart';

  // ── Screen phases ──────────────────────────────────────────────────────────
  enum _ScreenPhase { intro, game }

  // ── Maze cell ──────────────────────────────────────────────────────────────
  // (row, col) record used as a lightweight, value-comparable grid coordinate.
  typedef Cell = (int row, int col);

  // ─────────────────────────────────────────────────────────────────────────────
  // Constants
  // ─────────────────────────────────────────────────────────────────────────────

  const int _kTotalRounds = 5;

  // ─────────────────────────────────────────────────────────────────────────────
  // Screen
  // ─────────────────────────────────────────────────────────────────────────────

  class MazePathScreen extends StatefulWidget {
    final int level;

    const MazePathScreen({super.key, required this.level});

    @override
    State<MazePathScreen> createState() => _MazePathScreenState();
  }

  class _MazePathScreenState extends State<MazePathScreen>
      with TickerProviderStateMixin, RoxieReactionMixin<MazePathScreen>, GameLoadingMixin, PuzzleAudioMixin {
    @override
    AudioPlayer get roxiePlayer => _roxieSfxPlayer;

    // ── Asset config ───────────────────────────────────────────────────────────
    static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
    static const String _chickenImage = 'assets/images/characters/chicken.png';
    static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
    static const String _flagImage = 'assets/images/objects/puzzle/flag.png';
    static const String _starImage = 'assets/images/objects/puzzle/star.png';

    static const String _audioIntro = 'assets/audio/puzzle_glade/maze_path_intro.wav';
    static const String _audioInstructions = 'assets/audio/puzzle_glade/maze_path_instruction.wav';
    static const String _audioComplete = 'assets/audio/puzzle_glade/maze_path_complete.wav';

    // ── Phase ──────────────────────────────────────────────────────────────────
    _ScreenPhase _screenPhase = _ScreenPhase.intro;

    // ── Round / maze state ────────────────────────────────────────────────────
    int _round = 1;
    int _rows = 2;
    int _cols = 3;
    late Cell _start;
    late Cell _goal;
    Set<String> _openEdges = {};
    Cell _currentCell = (0, 0);
    List<Cell> _trail = [(0, 0)];
    bool _wrongBump = false;
    bool _isCompleting = false;
    DateTime? _lastWrongFeedback;
    bool _showWinDialog = false;

    final GlobalKey _mazeAreaKey = GlobalKey();

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
    late AnimationController _hopCtrl;
    late Animation<double> _hop;
    late AnimationController _speechBubbleCtrl;

    // Game transition
    late AnimationController _gameEnterCtrl;
    late Animation<double> _gameFade;

    // Round
    late AnimationController _enterCtrl;
    late Animation<double> _enterAnim;

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
      _hopCtrl.dispose();
      _speechBubbleCtrl.dispose();
      _gameEnterCtrl.dispose();
      _enterCtrl.dispose();
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

      _hopCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      )..repeat(reverse: true);
      _hop = CurvedAnimation(parent: _hopCtrl, curve: Curves.easeInOut);

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
    }

    // ── Intro flow ─────────────────────────────────────────────────────────────

    Future<void> _startIntroFlow() async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _roxieSlideCtrl.forward();

      _speechBubbleCtrl.forward(from: 0);
      await _playBgAudio(_audioIntro);
      if (!mounted) return;

      _speechBubbleCtrl.forward(from: 0);
      _gameEnterCtrl.forward();
      _startRound();
      setState(() => _screenPhase = _ScreenPhase.game);
      await _playBgAudio(_audioInstructions);
    }

    Future<void> _playBgAudio(String asset) async {
      if (!mounted) return;
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

    // ── Difficulty ─────────────────────────────────────────────────────────────

    // (rows, cols, deadEndBranches) per round — grid grows and picks up simple
    // dead-end offshoots as the rounds progress.
    (int, int, int) _mazeConfigForRound(int round) {
      switch (round) {
        case 1:
          return (2, 3, 0);
        case 2:
          return (3, 3, 0);
        case 3:
          return (3, 4, 1);
        case 4:
          return (4, 4, 2);
        default:
          return (4, 5, 3);
      }
    }

    // ── Round setup ────────────────────────────────────────────────────────────

    void _startRound() {
      if (!mounted) return;
      final rng = Random();
      final (rows, cols, deadEnds) = _mazeConfigForRound(_round);

      _rows = rows;
      _cols = cols;
      _start = (0, 0);
      _goal = (rows - 1, cols - 1);

      final mainPath = _generateMainPath(rows, cols, _start, _goal, rng);
      final openEdges = <String>{};
      for (int i = 0; i < mainPath.length - 1; i++) {
        openEdges.add(_edgeKey(mainPath[i], mainPath[i + 1]));
      }

      final allCells = mainPath.toSet();
      if (deadEnds > 0) {
        _addDeadEnds(mainPath, allCells, openEdges, rows, cols, deadEnds, rng);
      }

      _openEdges = openEdges;
      _currentCell = _start;
      _trail = [_start];
      _wrongBump = false;
      _isCompleting = false;

      _enterCtrl.forward(from: 0);
    }

    // ── Movement handling ──────────────────────────────────────────────────────

    Cell? _cellAtLocalOffset(Offset local, double cellSize) {
      final col = (local.dx / cellSize).floor();
      final row = (local.dy / cellSize).floor();
      if (row < 0 || row >= _rows || col < 0 || col >= _cols) return null;
      return (row, col);
    }

    void _handlePanUpdate(Offset globalPosition, double cellSize) {
      final box = _mazeAreaKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final local = box.globalToLocal(globalPosition);
      final cell = _cellAtLocalOffset(local, cellSize);
      if (cell == null) return;
      _attemptMove(cell);
    }

    bool _isAdjacent(Cell a, Cell b) {
      final dr = (a.$1 - b.$1).abs();
      final dc = (a.$2 - b.$2).abs();
      return (dr + dc) == 1;
    }

    Future<void> _attemptMove(Cell target) async {
      if (_isCompleting || target == _currentCell) return;

      // Stepping back onto the previous trail cell is always allowed —
      // this lets kids self-correct without penalty.
      if (_trail.length >= 2 && target == _trail[_trail.length - 2]) {
        setState(() {
          _trail.removeLast();
          _currentCell = target;
        });
        return;
      }

      if (!_isAdjacent(_currentCell, target)) return;

      final key = _edgeKey(_currentCell, target);
      if (!_openEdges.contains(key)) {
        _handleWrongMove();
        return;
      }

      setState(() {
        _currentCell = target;
        _trail.add(target);
      });

      if (target == _goal) {
        await _onGoalReached();
      }
    }

    void _handleWrongMove() {
      final now = DateTime.now();
      if (_lastWrongFeedback != null &&
          now.difference(_lastWrongFeedback!) < const Duration(milliseconds: 700)) {
        return; // debounce so a finger resting on a wall doesn't spam feedback
      }
      _lastWrongFeedback = now;

      unawaited(showRoxieReaction(RoxieState.wrong));
      setState(() => _wrongBump = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _wrongBump = false);
      });
    }

    Future<void> _onGoalReached() async {
      _isCompleting = true;
      unawaited(showRoxieReaction(RoxieState.correct));
      await Future.delayed(const Duration(milliseconds: 900));
      await _advanceRound();
    }

    Future<void> _advanceRound() async {
      if (_round >= _kTotalRounds) {
        await _completeRound();
        return;
      }

      await _enterCtrl.reverse();
      if (!mounted) return;
      setState(() {
        _round++;
        _startRound();
      });
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
                Expanded(flex: 6, child: _buildIntroMazePreview()),
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

    // Small two-tile preview: Roxie hops back and forth along an open path,
    // teasing the maze-walking mechanic before the round starts.
    Widget _buildIntroMazePreview() {
      return AnimatedBuilder(
        animation: _hop,
        builder: (_, __) {
          final hopX = Tween<double>(begin: -34, end: 34).evaluate(_hop);
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPreviewTile(),
                    Container(
                      width: 26,
                      height: 78,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    _buildPreviewTile(),
                  ],
                ),
                Transform.translate(
                  offset: Offset(hopX, 0),
                  child: Image.asset(
                    _chickenImage,
                    width: 46,
                    height: 46,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('🐰', style: TextStyle(fontSize: 30)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget _buildPreviewTile() {
      return Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
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
      );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // GAME
    // ══════════════════════════════════════════════════════════════════════════

    Widget _buildGameLayer() {
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
                  Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
                ],
              ),
            ),
            Expanded(child: Center(child: _buildMazeArea())),
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

    Widget _buildMazeArea() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth * 0.9;
          final maxH = constraints.maxHeight * 0.9;
          final cellSize = min(maxW / _cols, maxH / _rows);
          final mazeWidth = cellSize * _cols;
          final mazeHeight = cellSize * _rows;

          return GestureDetector(
            onPanUpdate: (details) => _handlePanUpdate(details.globalPosition, cellSize),
            child: Container(
              key: _mazeAreaKey,
              width: mazeWidth,
              height: mazeHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(mazeWidth, mazeHeight),
                      painter: _MazePainter(
                        rows: _rows,
                        cols: _cols,
                        cellSize: cellSize,
                        openEdges: _openEdges,
                        trail: _trail,
                        start: _start,
                        goal: _goal,
                        wrongCell: _wrongBump ? _currentCell : null,
                      ),
                    ),
                    _buildMazeIcon(_start, cellSize, _flagImage, show: _currentCell != _start),
                    _buildMazeIcon(_goal, cellSize, _starImage),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      left: _currentCell.$2 * cellSize + cellSize * 0.12,
                      top: _currentCell.$1 * cellSize + cellSize * 0.12,
                      width: cellSize * 0.76,
                      height: cellSize * 0.76,
                      child: AnimatedScale(
                        scale: _wrongBump ? 0.85 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Image.asset(
                          _chickenImage,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                          const Text('🐰', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    Widget _buildMazeIcon(Cell cell, double cellSize, String assetPath, {bool show = true}) {
      if (!show) return const SizedBox.shrink();
      return Positioned(
        left: cell.$2 * cellSize,
        top: cell.$1 * cellSize,
        width: cellSize,
        height: cellSize,
        child: Center(
          child: Image.asset(
            assetPath,
            width: cellSize * 0.6,
            height: cellSize * 0.6,
            fit: BoxFit.contain,
          ),
        ),
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
              builder: (context) => HiddenObjectScreen(level: widget.level + 1),
            ),
          );
        },
        onRestart: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MazePathScreen(level: widget.level),
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
  // Maze generation
  // ─────────────────────────────────────────────────────────────────────────────

  String _edgeKey(Cell a, Cell b) {
    final cells = [a, b]..sort((x, y) {
      if (x.$1 != y.$1) return x.$1.compareTo(y.$1);
      return x.$2.compareTo(y.$2);
    });
    return '${cells[0].$1},${cells[0].$2}-${cells[1].$1},${cells[1].$2}';
  }

  List<Cell> _neighbors(Cell c, int rows, int cols) {
    final (r, col) = c;
    final result = <Cell>[];
    if (r > 0) result.add((r - 1, col));
    if (r < rows - 1) result.add((r + 1, col));
    if (col > 0) result.add((r, col - 1));
    if (col < cols - 1) result.add((r, col + 1));
    return result;
  }

  /// Randomized DFS that carves a single winding, self-avoiding corridor from
  /// [start] to [goal]. Because it's a simple path (no branches), there is
  /// exactly one route through it — easy for young children to reason about.
  List<Cell> _generateMainPath(int rows, int cols, Cell start, Cell goal, Random rng) {
    final path = <Cell>[start];
    final visited = <Cell>{start};

    bool dfs(Cell current) {
      if (current == goal) return true;
      final neighbors = _neighbors(current, rows, cols)..shuffle(rng);
      for (final next in neighbors) {
        if (visited.contains(next)) continue;
        visited.add(next);
        path.add(next);
        if (dfs(next)) return true;
        path.removeLast();
      }
      return false;
    }

    dfs(start);
    return path;
  }

  /// Carves short (1-cell) dead-end offshoots from random points along the
  /// main path, giving higher rounds a couple of "wrong turns" to reason past.
  void _addDeadEnds(
      List<Cell> mainPath,
      Set<Cell> occupiedCells,
      Set<String> openEdges,
      int rows,
      int cols,
      int count,
      Random rng,
      ) {
    if (mainPath.length <= 2) return;
    final candidates = mainPath.sublist(1, mainPath.length - 1)..shuffle(rng);

    int added = 0;
    for (final cell in candidates) {
      if (added >= count) break;
      final neighbors = _neighbors(cell, rows, cols)..shuffle(rng);
      for (final next in neighbors) {
        if (occupiedCells.contains(next)) continue;
        openEdges.add(_edgeKey(cell, next));
        occupiedCells.add(next);
        added++;
        break;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Painter
  // ─────────────────────────────────────────────────────────────────────────────

  class _MazePainter extends CustomPainter {
    final int rows;
    final int cols;
    final double cellSize;
    final Set<String> openEdges;
    final List<Cell> trail;
    final Cell start;
    final Cell goal;
    final Cell? wrongCell;

    _MazePainter({
      required this.rows,
      required this.cols,
      required this.cellSize,
      required this.openEdges,
      required this.trail,
      required this.start,
      required this.goal,
      required this.wrongCell,
    });

    @override
    void paint(Canvas canvas, Size size) {
      final trailSet = trail.toSet();

      final floorPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
      final trailPaint = Paint()..color = PuzzleColorTheme.goldenyellow.withValues(alpha: 0.45);
      final startPaint = Paint()..color = PuzzleColorTheme.sunnyhue.withValues(alpha: 0.30);
      final goalPaint = Paint()..color = PuzzleColorTheme.sunnyhue.withValues(alpha: 0.30);
      final wrongPaint = Paint()..color = const Color(0xFFE05A5A).withValues(alpha: 0.30);

      // Cell floors
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final cell = (r, c);
          final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
          Paint fill = floorPaint;
          if (cell == wrongCell) {
            fill = wrongPaint;
          } else if (cell == start) {
            fill = startPaint;
          } else if (cell == goal) {
            fill = goalPaint;
          } else if (trailSet.contains(cell)) {
            fill = trailPaint;
          }
          canvas.drawRect(rect, fill);
        }
      }

      // Walls
      final wallPaint = Paint()
        ..color = PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.75)
        ..strokeWidth = cellSize * 0.09
        ..strokeCap = StrokeCap.round;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final cell = (r, c);
          final x = c * cellSize;
          final y = r * cellSize;

          // Right wall
          if (c == cols - 1 || !openEdges.contains(_edgeKey(cell, (r, c + 1)))) {
            canvas.drawLine(Offset(x + cellSize, y), Offset(x + cellSize, y + cellSize), wallPaint);
          }
          // Bottom wall
          if (r == rows - 1 || !openEdges.contains(_edgeKey(cell, (r + 1, c)))) {
            canvas.drawLine(Offset(x, y + cellSize), Offset(x + cellSize, y + cellSize), wallPaint);
          }
          // Left wall (only needed for the leftmost column; interior duplicates
          // are covered by the neighbor's right wall)
          if (c == 0) {
            canvas.drawLine(Offset(x, y), Offset(x, y + cellSize), wallPaint);
          }
          // Top wall (only needed for the topmost row)
          if (r == 0) {
            canvas.drawLine(Offset(x, y), Offset(x + cellSize, y), wallPaint);
          }
        }
      }
    }

    @override
    bool shouldRepaint(covariant _MazePainter oldDelegate) {
      return oldDelegate.rows != rows ||
          oldDelegate.cols != cols ||
          oldDelegate.cellSize != cellSize ||
          oldDelegate.openEdges != openEdges ||
          oldDelegate.trail.length != trail.length ||
          oldDelegate.wrongCell != wrongCell;
    }
  }