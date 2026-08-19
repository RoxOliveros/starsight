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
import 'game_rotate_shape.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const int _kTotalRounds = 5;

// ─────────────────────────────────────────────────────────────────────────────
// Object pool
// ─────────────────────────────────────────────────────────────────────────────

// Each item carries a "colorFamily"/"shapeFamily" tag so harder rounds can
// pick visually-similar distractors (e.g. ball/balloon/apple all round+red)
// to make the target less obvious.
class _HiddenObjectItem {
  final String id;
  final String name;
  final String asset;
  final String emoji; // fallback if the asset can't be loaded
  final String colorFamily;
  final String shapeFamily;

  const _HiddenObjectItem({
    required this.id,
    required this.name,
    required this.asset,
    required this.emoji,
    required this.colorFamily,
    required this.shapeFamily,
  });
}

const List<_HiddenObjectItem> _objectPool = [
  _HiddenObjectItem(id: 'compass', name: 'Compass', asset: 'assets/images/objects/puzzle/compass.png', emoji: '🧭', colorFamily: 'brass', shapeFamily: 'round'),
  _HiddenObjectItem(id: 'map', name: 'Map', asset: 'assets/images/objects/puzzle/map.png', emoji: '🗺️', colorFamily: 'tan', shapeFamily: 'rectangle'),
  _HiddenObjectItem(id: 'notebook', name: 'Notebook', asset: 'assets/images/objects/puzzle/notebook.png', emoji: '📓', colorFamily: 'brown', shapeFamily: 'rectangle'),
  _HiddenObjectItem(id: 'flag', name: 'Flag', asset: 'assets/images/objects/puzzle/flag.png', emoji: '🚩', colorFamily: 'red', shapeFamily: 'long'),
  _HiddenObjectItem(id: 'pen', name: 'Pen', asset: 'assets/images/objects/puzzle/pen.png', emoji: '🖊️', colorFamily: 'brown', shapeFamily: 'long'),
  _HiddenObjectItem(id: 'jar', name: 'Jar', asset: 'assets/images/objects/puzzle/jar.png', emoji: '🏺', colorFamily: 'tan', shapeFamily: 'round'),
  _HiddenObjectItem(id: 'puzzle_piece', name: 'Puzzle Piece', asset: 'assets/images/objects/puzzle/puzzle_piece.png', emoji: '🧩', colorFamily: 'blue', shapeFamily: 'diamond'),
  _HiddenObjectItem(id: 'star', name: 'Star', asset: 'assets/images/objects/puzzle/star.png', emoji: '⭐', colorFamily: 'yellow', shapeFamily: 'star'),
  _HiddenObjectItem(id: 'lamp', name: 'Lamp', asset: 'assets/images/objects/puzzle/lamp.png', emoji: '🏮', colorFamily: 'brass', shapeFamily: 'round'),
  _HiddenObjectItem(id: 'magnifying_glass', name: 'Magnifying Glass', asset: 'assets/images/objects/puzzle/magnifying_glass.png', emoji: '🔍', colorFamily: 'brass', shapeFamily: 'round'),
  _HiddenObjectItem(id: 'telescope', name: 'Telescope', asset: 'assets/images/objects/puzzle/telescope.png', emoji: '🔭', colorFamily: 'brass', shapeFamily: 'long'),
];

// A pool item placed somewhere in the scene for the current round.
class _PlacedObject {
  final _HiddenObjectItem item;
  final Offset topLeft; // within the scene's local coordinate space
  final double size;
  final double rotation; // small cosmetic tilt

  const _PlacedObject({
    required this.item,
    required this.topLeft,
    required this.size,
    required this.rotation,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class HiddenObjectScreen extends StatefulWidget {
  final int level;

  const HiddenObjectScreen({super.key, required this.level});

  @override
  State<HiddenObjectScreen> createState() => _HiddenObjectScreenState();
}

class _HiddenObjectScreenState extends State<HiddenObjectScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<HiddenObjectScreen>, GameLoadingMixin, PuzzleAudioMixin {
  @override
  AudioPlayer get roxiePlayer => _roxieSfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/hidden_object/intro.wav';
  static const String _audioWelcome = 'assets/audio/puzzle_glade/hidden_object/welcome.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/hidden_object/hidden_object_instruction.wav';
  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/hidden_object/complete.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round / scene state ───────────────────────────────────────────────────
  int _round = 1;
  late _HiddenObjectItem _targetItem;
  List<_PlacedObject> _sceneObjects = [];
  String? _wrongObjectId;
  String? _foundObjectId;
  bool _isCompleting = false;
  DateTime? _lastWrongFeedback;
  bool _showWinDialog = false;

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
  late AnimationController _magnifierCtrl;
  late Animation<double> _magnifier;
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
    _magnifierCtrl.dispose();
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

    _magnifierCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _magnifier = CurvedAnimation(parent: _magnifierCtrl, curve: Curves.easeInOut);

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
    _roxieSlideCtrl.forward();

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioIntro);

    _speechBubbleCtrl.forward(from: 0);
    await _playBgAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));

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

  // ── Difficulty ─────────────────────────────────────────────────────────────

  // (objectCount, similarDistractorCount, targetSizeFactor) per round —
  // more objects, more look-alike distractors, and a smaller target as
  // rounds progress.
  (int, int, double) _sceneConfigForRound(int round) {
    switch (round) {
      case 1:
        return (6, 0, 1.0);
      case 2:
        return (8, 1, 0.95);
      case 3:
        return (10, 2, 0.9);
      case 4:
        return (12, 3, 0.82);
      default:
        return (14, 4, 0.75);
    }
  }

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    final rng = Random();
    final (objectCount, similarCount, targetSizeFactor) = _sceneConfigForRound(_round);

    final pool = List<_HiddenObjectItem>.from(_objectPool)..shuffle(rng);
    final target = pool.first;

    final similar = _objectPool
        .where((o) => o.id != target.id && (o.colorFamily == target.colorFamily || o.shapeFamily == target.shapeFamily))
        .toList()
      ..shuffle(rng);
    final chosenSimilar = similar.take(similarCount).toList();

    final remainingSlots = (objectCount - 1 - chosenSimilar.length).clamp(0, _objectPool.length);
    final usedIds = {target.id, ...chosenSimilar.map((o) => o.id)};
    final fillers = _objectPool.where((o) => !usedIds.contains(o.id)).toList()
      ..shuffle(rng);
    final chosenFillers = fillers.take(remainingSlots).toList();

    final sceneItems = [target, ...chosenSimilar, ...chosenFillers]..shuffle(rng);

    setState(() {
      _targetItem = target;
      // Positions are assigned in the LayoutBuilder at build time (needs
      // the scene's real pixel size), so stash the un-placed list for now
      // and let _layoutScene fill in offsets.
      _sceneObjects = _layoutScene(sceneItems, targetSizeFactor, target.id, rng);
      _wrongObjectId = null;
      _foundObjectId = null;
      _isCompleting = false;
    });

    _enterCtrl.forward(from: 0);
  }

  // Places items on a jittered grid sized to fit exactly `items.length`
  // cells, so objects never overlap however many there are.
  List<_PlacedObject> _layoutScene(
      List<_HiddenObjectItem> items,
      double targetSizeFactor,
      String targetId,
      Random rng,
      ) {
    const sceneWidth = 1000.0; // normalized space, rescaled to real pixels at paint time
    const sceneHeight = 600.0;
    final aspect = sceneWidth / sceneHeight;

    final gridCols = sqrt(items.length * aspect * 0.75).ceil().clamp(1, 999);
    final gridRows = (items.length / gridCols).ceil().clamp(1, 999);
    final cellW = sceneWidth / gridCols;
    final cellH = sceneHeight / gridRows;
    final baseSize = min(cellW, cellH) * 0.78;

    final cellIndices = List<int>.generate(gridCols * gridRows, (i) => i)..shuffle(rng);
    // more cells needed than exist once density is reduced — allow repeats so
    // items double up on the same cell and stack/overlap
    final chosenCells = List<int>.generate(
      items.length,
          (i) => cellIndices[i % cellIndices.length],
    );

    final placed = <_PlacedObject>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final size = item.id == targetId ? baseSize * targetSizeFactor : baseSize;
      final cell = chosenCells[i];
      final row = cell ~/ gridCols;
      final col = cell % gridCols;
      // jitter range extended beyond the cell itself so neighboring/same-cell
      // objects overlap instead of sitting in neat isolated slots
      final maxJitterX = max(0.0, cellW * 1.4 - size);
      final maxJitterY = max(0.0, cellH * 1.4 - size);
      final x = (col * cellW - cellW * 0.2 + rng.nextDouble() * maxJitterX).clamp(0.0, sceneWidth - size);
      final y = (row * cellH - cellH * 0.2 + rng.nextDouble() * maxJitterY).clamp(0.0, sceneHeight - size);
      final rotation = (rng.nextDouble() - 0.5) * 0.35;

      placed.add(_PlacedObject(item: item, topLeft: Offset(x, y), size: size, rotation: rotation));
    }
    return placed;
  }

  // ── Tap handling ───────────────────────────────────────────────────────────

  void _handleObjectTap(_PlacedObject obj) {
    if (_isCompleting) return;
    if (obj.item.id == _targetItem.id) {
      _handleCorrectTap(obj);
    } else {
      _handleWrongTap(obj);
    }
  }

  void _handleWrongTap(_PlacedObject obj) {
    final now = DateTime.now();
    if (_lastWrongFeedback != null &&
        now.difference(_lastWrongFeedback!) < const Duration(milliseconds: 500)) {
      return; // debounce rapid mis-taps
    }
    _lastWrongFeedback = now;

    _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
    unawaited(showRoxieReaction(RoxieState.wrong));
    setState(() => _wrongObjectId = obj.item.id);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _wrongObjectId = null);
    });
  }

  Future<void> _handleCorrectTap(_PlacedObject obj) async {
    setState(() {
      _isCompleting = true;
      _foundObjectId = obj.item.id;
    });
    _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
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
              Align(alignment: Alignment.center, child: PuzzleGameHeader(title: 'Hidden Object')),
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

  // Small preview: a handful of faint objects with a magnifying glass
  // sweeping over them, teasing the search mechanic before the round starts.
  Widget _buildIntroPreview() {
    const previewItems = ['🧭', '🗺️', '🧩', '🔭', '🖊️'];
    return AnimatedBuilder(
      animation: _magnifier,
      builder: (_, __) {
        final sweepX = Tween<double>(begin: -70, end: 70).evaluate(_magnifier);
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
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
                  children: previewItems
                      .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(e, style: const TextStyle(fontSize: 30)),
                  ))
                      .toList(),
                ),
              ),
              Transform.translate(
                offset: Offset(sweepX, 0),
                child: const Text('🔍', style: TextStyle(fontSize: 54)),
              ),
            ],
          ),
        );
      },
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
                Align(
                  alignment: Alignment.center,
                  child: _buildFindInstruction(),
                ),
                Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
              ],
            ),
          ),
          Expanded(child: Center(child: _buildSceneArea())),
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

  Widget _buildFindInstruction() {
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
          Text(
            'Find the',
            style: const TextStyle(
              fontFamily: PuzzleAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: PuzzleColorTheme.sunnyhue,
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            _targetItem.asset,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(_targetItem.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 6),
          Text(
            _targetItem.name,
            style: const TextStyle(
              fontFamily: PuzzleAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: PuzzleColorTheme.darkdesaturatedblue,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'in the picture!',
            style: const TextStyle(
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

  Widget _buildSceneArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth * 0.92;
        final maxH = constraints.maxHeight * 0.92;
        // Keep the same 1000x600 aspect ratio the layout used when placing objects.
        const sceneAspect = 1000.0 / 600.0;
        double sceneWidth = maxW;
        double sceneHeight = sceneWidth / sceneAspect;
        if (sceneHeight > maxH) {
          sceneHeight = maxH;
          sceneWidth = sceneHeight * sceneAspect;
        }
        final scale = sceneWidth / 1000.0;

        return Container(
          width: sceneWidth,
          height: sceneHeight,
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: _sceneObjects
                  .map((obj) => _buildSceneObject(obj, scale))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSceneObject(_PlacedObject obj, double scale) {
    final isWrong = _wrongObjectId == obj.item.id;
    final isFound = _foundObjectId == obj.item.id;

    return Positioned(
      left: obj.topLeft.dx * scale,
      top: obj.topLeft.dy * scale,
      width: obj.size * scale,
      height: obj.size * scale,
      child: GestureDetector(
        onTap: () => _handleObjectTap(obj),
        behavior: HitTestBehavior.opaque,
        child: Transform.rotate(
          angle: obj.rotation,
          child: AnimatedScale(
            scale: isWrong ? 0.82 : (isFound ? 1.15 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Container(
              decoration: isFound
                  ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PuzzleColorTheme.goldenyellow.withValues(alpha: 0.8),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ],
              )
                  : null,
              child: Image.asset(
                obj.item.asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    obj.item.emoji,
                    style: TextStyle(fontSize: obj.size * scale * 0.7),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
            builder: (context) => RotateTheShapeScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HiddenObjectScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}