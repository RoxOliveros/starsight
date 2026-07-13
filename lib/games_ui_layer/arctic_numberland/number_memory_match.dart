import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_audio_helper.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'iceberg_tip.dart';

enum _TileKind { numeral, quantity }

class _MemoryTile {
  final int id;
  final int pairValue;
  final _TileKind kind;
  bool revealed = false;
  bool matched = false;

  _MemoryTile({
    required this.id,
    required this.pairValue,
    required this.kind,
  });
}

class NumberMemoryMatchGame extends StatefulWidget {
  final int level;
  final int pairCount;

  const NumberMemoryMatchGame({super.key, this.pairCount = 5, required this.level});

  @override
  State<NumberMemoryMatchGame> createState() => _NumberMemoryMatchGameState();
}

class _NumberMemoryMatchGameState extends State<NumberMemoryMatchGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<NumberMemoryMatchGame>,
        GameLoadingMixin<NumberMemoryMatchGame>,
        ArcticAudioMixin<NumberMemoryMatchGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _quantityIconAsset = 'assets/images/objects/arctic/snowflake.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/number_memory_match_intro.wav';
  static const String _audioInstruction = '$_audioBase/number_memory_match_instruction.wav';
  static const String _audioWin = '$_audioBase/number_memory_match_win.wav';

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<_MemoryTile> _tiles;
  final List<int> _flipped = []; // ids currently face-up, awaiting resolution
  final Set<int> _hiddenIds = {}; // matched tiles that have finished melting away
  bool _resolving = false;
  int _matchedPairs = 0;
  bool _showWinDialog = false;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;

  int get _pairCount => widget.pairCount;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _tiles = _buildTiles();
    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  List<_MemoryTile> _buildTiles() {
    final tiles = <_MemoryTile>[];
    int nextId = 0;

    final pool = List<int>.generate(10, (i) => i + 1)..shuffle(); // ADD — numbers 1-10, shuffled
    final chosenValues = pool.take(_pairCount).toList();          // ADD — pick however many pairs you need

    for (final v in chosenValues) {                               // CHANGED — loop over chosenValues instead of 1..pairCount
      tiles.add(_MemoryTile(id: nextId++, pairValue: v, kind: _TileKind.numeral));
      tiles.add(_MemoryTile(id: nextId++, pairValue: v, kind: _TileKind.quantity));
    }
    tiles.shuffle(Random());
    return tiles;
  }

  void _initAnimations() {
    _domaFloatCtrl = AnimationController(
      vsync: this,
      //card flip time
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _instructionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _instructionBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut));

    _sceneEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sceneEnter = CurvedAnimation(parent: _sceneEnterCtrl, curve: Curves.elasticOut);
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) playVoice(_audioInstruction);
  }

  // ── Tile interaction ─────────────────────────────────────────────────────
  Future<void> _onTileTapped(_MemoryTile tile) async {
    if (_resolving || tile.matched || tile.revealed || _flipped.length >= 2) return;

    HapticFeedback.selectionClick();
    setState(() {
      tile.revealed = true;
      _flipped.add(tile.id);
    });

    if (_flipped.length < 2) return;

    _resolving = true;
    final a = _tiles.firstWhere((t) => t.id == _flipped[0]);
    final b = _tiles.firstWhere((t) => t.id == _flipped[1]);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (a.pairValue == b.pairValue) {
      HapticFeedback.mediumImpact();
      await playSfx('$_audioBase/${a.pairValue}.wav'); // CHANGED — removed await, fire-and-forget
      showDomaReaction(DomaState.correct);
      setState(() {
        a.matched = true;
        b.matched = true;
        _matchedPairs++;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _hiddenIds.addAll([a.id, b.id]));
    } else {
      HapticFeedback.heavyImpact();
      await playSfx('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        a.revealed = false;
        b.revealed = false;
      });
    }

    setState(() {
      _flipped.clear();
      _resolving = false;
    });

    if (_matchedPairs >= _pairCount) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _onAllMatched();
    }
  }

  Future<void> _onAllMatched() async {
    await playVoice(_audioWin);
    if (!mounted) return;
    setState(() {
      _showWinDialog = true;
    });
  }

  @override
  void dispose() {
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.arctic(),
        gameBuilder: () => Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _bgImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFFDCEFFA)),
              ),
            ),
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _introPlaying ? _buildIntroLayer() : _buildGameContent(),
              ),
            if (!_introPlaying) buildDoma(context),
            if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
          ],
        ),
      ),
    );
  }

  // ── Intro layer ──────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(top: 25, left: 20, child: ArcticBackButton()),
        Positioned(top: 25, right: 20, child: ArcticLevelBadge(level: widget.level)),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) =>
                      Transform.translate(
                        offset: Offset(
                          0,
                          Tween<double>(begin: -6, end: 6).evaluate(
                            CurvedAnimation(
                                parent: _domaFloatCtrl, curve: Curves.easeInOut),
                          ),
                        ),
                        child: child,
                      ),
                  child: Image.asset(
                    _characterImage,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                    const Text('🐧', style: TextStyle(fontSize: 70)),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIntroSampleCard(screenH * 0.4, isNumeral: true),
                    SizedBox(width: screenH * 0.03),
                    _buildIntroSampleCard(screenH * 0.4, isNumeral: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroSampleCard(double size, {required bool isNumeral}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNumeral ? ArcticColorTheme.pictonblue : ArcticColorTheme.cadetblue,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: isNumeral
          ? Text(
        '3',
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
          color: ArcticColorTheme.slateblue,
        ),
      )
          : LayoutBuilder(
        builder: (context, constraints) => _quantityIcons(3, constraints.maxWidth, constraints.maxHeight),
      ),
    );
  }

  // ── Main game layout ─────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        return ScaleTransition(
          scale: _sceneEnter,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: ArcticBackButton()),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ArcticLevelBadge(level: widget.level),
                    ),
                    Center(child: _buildPromptBanner(h)),
                  ],
                ),
              ),
              Expanded(child: _buildGrid()),
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: _buildProgressDots(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromptBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => playVoice(_audioInstruction),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          child: Text(
            'Match the numbers to the objects!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        const gridPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 6);
        final maxW = constraints.maxWidth - gridPadding.horizontal;
        final maxH = constraints.maxHeight - gridPadding.vertical;
        final total = _tiles.length;

        double bestTileSize = 0;
        for (int cols = 1; cols <= total; cols++) {
          final rows = (total / cols).ceil();
          final tileW = (maxW - spacing * (cols - 1)) / cols;
          final tileH = (maxH - spacing * (rows - 1)) / rows;
          final size = min(tileW, tileH);
          if (size > bestTileSize) {
            bestTileSize = size;
          }
        }

        final tileSize = (bestTileSize * 0.9).clamp(30.0, 160.0); // CHANGED — this is now actually used

        return Padding(                                            // CHANGED — replaces GridView.builder entirely
          padding: gridPadding,
          child: Center(
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: _tiles
                  .map((tile) => SizedBox(
                width: tileSize,
                height: tileSize,
                child: _buildTileWidget(tile),
              ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTileWidget(_MemoryTile tile) {
    final hidden = _hiddenIds.contains(tile.id);
    return AnimatedOpacity(
      opacity: hidden ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 350),
      child: IgnorePointer(
        ignoring: hidden || tile.matched,
        child: GestureDetector(
          onTap: () => _onTileTapped(tile),
          child: _buildFlipTile(tile),
        ),
      ),
    );
  }

  Widget _buildFlipTile(_MemoryTile tile) {
    final target = (tile.revealed || tile.matched) ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: target, end: target),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      builder: (context, _, __) => _AnimatedFlip(target: target, front: _tileFront(tile), back: _tileBack()),
    );
  }

  Widget _tileFront(_MemoryTile tile) {
    final isNumeral = tile.kind == _TileKind.numeral;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNumeral ? ArcticColorTheme.pictonblue : ArcticColorTheme.cadetblue,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: isNumeral
          ? Text(
        '${tile.pairValue}',
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontWeight: FontWeight.bold,
          fontSize: 34,
          color: ArcticColorTheme.slateblue,
        ),
      )
          : LayoutBuilder(                                    // ADD: wrap in LayoutBuilder
        builder: (context, constraints) => _quantityIcons(
          tile.pairValue,
          constraints.maxWidth,                          // ADD: pass available width
          constraints.maxHeight,                         // ADD: pass available height
        ),
      ),
    );
  }

  Widget _quantityIcons(int count, double maxWidth, double maxHeight) {
    final columns = sqrt(count).ceil();                        // ADD: roughly-square grid of icons
    final rows = (count / columns).ceil();
    final iconSize = min(maxWidth / columns, maxHeight / rows) * 0.8; // ADD: fit within both dimensions

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 3,
        runSpacing: 3,
        children: List.generate(
          count,
              (_) => Image.asset(
            _quantityIconAsset,
            width: iconSize,                                    // CHANGED from hardcoded 40
            height: iconSize,                                    // CHANGED from hardcoded 40
            errorBuilder: (_, __, ___) => Text('❄️', style: TextStyle(fontSize: iconSize * 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _tileBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 3),
        gradient: LinearGradient(
          colors: [
            ArcticColorTheme.pictonblue,
            ArcticColorTheme.lightblue
          ],
        ),
      ),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pairCount, (i) {
        final done = i < _matchedPairs;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: done ? ArcticColorTheme.cadetblue : ArcticColorTheme.slateblue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }

  // ── Win / celebration overlay ────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pop(context, IcebergTipGame(level: widget.level + 1));
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _tiles = _buildTiles();
          _flipped.clear();
          _hiddenIds.clear();
          _resolving = false;
          _matchedPairs = 0;
        });
        _sceneEnterCtrl.forward(from: 0);
        _instructionCtrl.forward(from: 0);
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

/// Simple 3D-style card flip: rotates from [back] to [front] around the Y
/// axis, swapping faces at the halfway point so the front isn't mirrored.
class _AnimatedFlip extends StatelessWidget {
  final double target; // 0 = back, 1 = front
  final Widget front;
  final Widget back;

  const _AnimatedFlip({required this.target, required this.front, required this.back});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        final angle = value * pi;
        final showFront = angle > pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showFront
              ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(pi),
            child: front,
          )
              : back,
        );
      },
    );
  }
}