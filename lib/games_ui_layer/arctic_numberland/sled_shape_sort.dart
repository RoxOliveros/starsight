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

enum _ShapeKind { circle, square, triangle, star }

class _ShapeItem {
  final String id;
  final String asset;
  final String emoji;
  final _ShapeKind shape;

  const _ShapeItem({
    required this.id,
    required this.asset,
    required this.emoji,
    required this.shape,
  });
}

class _RoundSpec {
  final List<_ShapeItem> items;
  const _RoundSpec(this.items);
}

class SledShapeSortGame extends StatefulWidget {
  const SledShapeSortGame({super.key});

  @override
  State<SledShapeSortGame> createState() => _SledShapeSortGameState();
}

class _SledShapeSortGameState extends State<SledShapeSortGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<SledShapeSortGame>,
        GameLoadingMixin<SledShapeSortGame>,
        ArcticAudioMixin<SledShapeSortGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _objBase = 'assets/images/objects/arctic';
  static const String _sledAsset = '$_objBase/sled.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/sled_shape_sort_intro.wav';
  static const String _audioInstruction = '$_audioBase/sled_shape_sort_instuction.wav';
  static const String _audioWin = '$_audioBase/sled_shape_sort_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  // Ramp: 2 shapes -> 3 shapes -> 4 shapes, item count growing 3 -> 6.
  static final List<_RoundSpec> _rounds = [
    _RoundSpec([
      _ShapeItem(id: 'orn_blue', asset: '$_objBase/ornament_blue.png', emoji: '🔵', shape: _ShapeKind.circle),
      _ShapeItem(id: 'pkg_1', asset: '$_objBase/package_1.png', emoji: '📦', shape: _ShapeKind.square),
      _ShapeItem(id: 'snowball_1', asset: '$_objBase/snowball.png', emoji: '⚪', shape: _ShapeKind.circle),
    ]),
    _RoundSpec([
      _ShapeItem(id: 'orn_green', asset: '$_objBase/ornament_green.png', emoji: '🟢', shape: _ShapeKind.circle),
      _ShapeItem(id: 'ice_1', asset: '$_objBase/ice_1.png', emoji: '🧊', shape: _ShapeKind.square),
      _ShapeItem(id: 'tree_1', asset: '$_objBase/snowy_tree.png', emoji: '🌲', shape: _ShapeKind.triangle),
      _ShapeItem(id: 'pkg_2', asset: '$_objBase/package_1.png', emoji: '📦', shape: _ShapeKind.square),
    ]),
    _RoundSpec([
      _ShapeItem(id: 'orn_purple', asset: '$_objBase/ornament_purple.png', emoji: '🟣', shape: _ShapeKind.circle),
      _ShapeItem(id: 'iceberg_1', asset: '$_objBase/iceberg.png', emoji: '🏔️', shape: _ShapeKind.triangle),
      _ShapeItem(id: 'star_1', asset: 'assets/images/objects/puzzle/star.png', emoji: '⭐', shape: _ShapeKind.star),
      _ShapeItem(id: 'snowball_2', asset: '$_objBase/snowball.png', emoji: '⚪', shape: _ShapeKind.circle),
      _ShapeItem(id: 'pkg_3', asset: '$_objBase/package_1.png', emoji: '📦', shape: _ShapeKind.square),
    ]),
    _RoundSpec([
      _ShapeItem(id: 'orn_red', asset: '$_objBase/ornament_red.png', emoji: '🔴', shape: _ShapeKind.circle),
      _ShapeItem(id: 'orn_yellow', asset: '$_objBase/ornament_yellow.png', emoji: '🟡', shape: _ShapeKind.circle),
      _ShapeItem(id: 'tree_2', asset: '$_objBase/snowy_tree.png', emoji: '🌲', shape: _ShapeKind.triangle),
      _ShapeItem(id: 'iceberg_2', asset: '$_objBase/iceberg.png', emoji: '🏔️', shape: _ShapeKind.triangle),
      _ShapeItem(id: 'star_2', asset: 'assets/images/objects/puzzle/star.png', emoji: '⭐', shape: _ShapeKind.star),
      _ShapeItem(id: 'ice_2', asset: '$_objBase/ice_1.png', emoji: '🧊', shape: _ShapeKind.square),
    ]),
    _RoundSpec([
      _ShapeItem(id: 'icecream_1', asset: '$_objBase/icecream.png', emoji: '🍦', shape: _ShapeKind.triangle),
      _ShapeItem(id: 'snowglobe_1', asset: '$_objBase/snowglobe.png', emoji: '🔮', shape: _ShapeKind.circle),
      _ShapeItem(id: 'signboard_1', asset: '$_objBase/snowy_signboard_big.png', emoji: '🪧', shape: _ShapeKind.square),
      _ShapeItem(id: 'pkg_4', asset: '$_objBase/package_1.png', emoji: '📦', shape: _ShapeKind.square),
      _ShapeItem(id: 'tree_3', asset: '$_objBase/snowy_tree.png', emoji: '🌲', shape: _ShapeKind.triangle),
      _ShapeItem(id: 'star_3', asset: 'assets/images/objects/puzzle/star.png', emoji: '⭐', shape: _ShapeKind.star),
    ]),
  ];

  static final int _totalRounds = _rounds.length;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  bool _showWinDialog = false;

  late _RoundSpec _round;
  late List<_ShapeKind> _binsForRound;
  late List<_ShapeItem> _staging; // unplaced items
  final Set<String> _placedIds = {};
  String? _wrongItemId;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRound(playInstruction: false);
    finishLoading(_startIntroFlow);
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
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) playVoice(_audioInstruction);
  }

  void _setupRound({bool playInstruction = true}) {
    _round = _rounds[_currentRound];
    _binsForRound = _round.items.map((i) => i.shape).toSet().toList();
    _staging = List<_ShapeItem>.from(_round.items)..shuffle(Random());
    _placedIds.clear();
    _wrongItemId = null;

    _sceneEnterCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) playVoice(_audioInstruction);
      });
    }

    setState(() {});
  }

  // ── Drop handling ─────────────────────────────────────────────────────────
  Future<void> _onItemDropped(_ShapeItem item, _ShapeKind sledShape) async {
    if (_placedIds.contains(item.id)) return;

    if (item.shape == sledShape) {
      HapticFeedback.mediumImpact();
      setState(() => _placedIds.add(item.id));
      await playSfx('$_audioBase/pop.wav');
      showDomaReaction(DomaState.correct);

      if (_placedIds.length >= _round.items.length) {
        await Future.delayed(const Duration(milliseconds: 600));
        await _onRoundComplete();
      }
    } else {
      showDomaReaction(DomaState.wrong);
      HapticFeedback.heavyImpact();
      setState(() => _wrongItemId = item.id);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _wrongItemId = null);
    }
  }

  Future<void> _onRoundComplete() async {
    setState(() => _solvedRounds++);

    if (_currentRound + 1 >= _totalRounds) {
      await playVoice(_audioWin);
      if (!mounted) return;
      setState(() => _showWinDialog = true);
    } else {
      setState(() => _currentRound++);
      _setupRound(playInstruction: false);
    }
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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _introPlaying ? _buildIntroLayer() : _buildGameContent(),
              ),
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
    final badgeSize = screenH * 0.12;

    return Center(
      child: AnimatedBuilder(
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Image.asset(
              _characterImage,
              height: screenH * 0.7,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
            ),
            const Spacer(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  _sledAsset,
                  height: screenH * 0.55,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('🛷', style: TextStyle(fontSize: 70)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _ShapeKind.values.map((shape) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: badgeSize,
                        height: badgeSize,
                        padding: EdgeInsets.all(badgeSize * 0.1),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ArcticColorTheme.pictonblue,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _ShapeOutlinePainter(shape),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: ArcticBackButton()),
                    Center(child: _buildInstructionBanner(h)),
                  ],
                ),
              ),
              Expanded(child: _buildStagingArea(h)),
              _buildSledRow(h * 0.32),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: _buildRoundIndicator(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => playVoice(_audioInstruction),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
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
            'Drag each shape into its sled!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: (h * 0.06).clamp(13.0, 19.0),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }

  // ── Staging tray (draggable objects) ────────────────────────────────────
  Widget _buildStagingArea(double h) {
    final size = (h * 0.24).clamp(56.0, 100.0);
    final visible = _staging.where((i) => !_placedIds.contains(i.id)).toList();

    return Center(
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: visible.map((item) => _buildDraggableItem(item, size)).toList(),
      ),
    );
  }

  Widget _buildDraggableItem(_ShapeItem item, double size) {
    final wrong = _wrongItemId == item.id;
    final tile = _itemVisual(item, size, wrong: wrong);

    return Draggable<_ShapeItem>(
      key: ValueKey(item.id),
      data: item,
      feedback: Material(color: Colors.transparent, child: _itemVisual(item, size * 1.15)),
      childWhenDragging: Opacity(opacity: 0.25, child: tile),
      onDragStarted: () => HapticFeedback.selectionClick(),
      child: tile,
    );
  }

  Widget _itemVisual(_ShapeItem item, double size, {bool wrong = false, bool bare = false}) { // CHANGED — added bare param
    if (bare) {                                             // ADD — plain image, no container decoration
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          item.asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(item.emoji, style: TextStyle(fontSize: size * 0.5)),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: wrong ? Colors.red : Colors.white, width: wrong ? 4 : 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Image.asset(
        item.asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(item.emoji, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }

  // ── Sled row (drop targets) ─────────────────────────────────────────────
  Widget _buildSledRow(double slotSize) {
    return SizedBox(
      height: slotSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _binsForRound.map((shape) => _buildSled(shape, slotSize)).toList(),
      ),
    );
  }

  Widget _buildSled(_ShapeKind shape, double slotSize) {
    final loadedItems = _round.items
        .where((i) => i.shape == shape && _placedIds.contains(i.id))
        .toList();

    final sledWidth = slotSize * 1.3;      // ADD — matches reference's sledWidth naming/proportion
    final sledHeight = slotSize;           // ADD

    return DragTarget<_ShapeItem>(
      onWillAcceptWithDetails: (details) => !_placedIds.contains(details.data.id),
      onAcceptWithDetails: (details) => _onItemDropped(details.data, shape),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        final matchHover = hovering && candidateData.first!.shape == shape;
        final mismatchHover = hovering && candidateData.first!.shape != shape;

        return AnimatedScale(
          scale: matchHover ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            width: sledWidth,
            height: sledHeight,
            child: Stack(
              alignment: Alignment.bottomCenter,          // CHANGED — matches reference's outer Stack alignment
              clipBehavior: Clip.none,
              children: [
                Image.asset(                                // CHANGED — sledWidth-based sizing like the reference's Image.asset(_sledAsset, width: sledWidth, ...)
                  _sledAsset,
                  width: sledWidth,
                  fit: BoxFit.contain,
                  color: mismatchHover ? Colors.red.withValues(alpha: 0.35) : null,
                  colorBlendMode: mismatchHover ? BlendMode.srcATop : null,
                  errorBuilder: (_, __, ___) => Container(
                    height: 40,
                    width: sledWidth,
                    decoration: BoxDecoration(
                      color: ArcticColorTheme.slateblue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                //items
                Positioned(                                 // CHANGED — bottom/left/right like reference's cargo Positioned
                  bottom: sledHeight * 0.54,
                  left: sledHeight * 0.16,
                  right: 0,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: loadedItems
                        .map((item) => _itemVisual(item, slotSize * 0.32, bare: true))
                        .toList(),
                  ),
                ),

                //shape
                Positioned(
                  bottom: -slotSize * 0.1,
                  child: Container(
                    width: slotSize * 0.5,
                    height: slotSize * 0.5,
                    padding: EdgeInsets.all(slotSize * 0.06),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: matchHover
                            ? const Color(0xFF3BC46B)
                            : ArcticColorTheme.pictonblue,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _ShapeOutlinePainter(shape),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedRounds;
        final current = !_showWinDialog && i == _currentRound;
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

  // ── Win / celebration overlay ────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        // TODO: navigate to next game
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedRounds = 0;
          _setupRound();
        });
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ── Shape outline painter for sled icons ──────────────────────────────────
class _ShapeOutlinePainter extends CustomPainter {
  final _ShapeKind shape;
  const _ShapeOutlinePainter(this.shape);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ArcticColorTheme.slateblue.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = min(w, h) * 0.38;

    switch (shape) {
      case _ShapeKind.circle:
        canvas.drawCircle(Offset(cx, cy), r, paint);
        break;
      case _ShapeKind.square:
        final side = r * 1.6;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: side, height: side),
            Radius.circular(side * 0.12),
          ),
          paint,
        );
        break;
      case _ShapeKind.triangle:
        final path = Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx - r, cy + r * 0.8)
          ..lineTo(cx + r, cy + r * 0.8)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case _ShapeKind.star:
        final path = Path();
        const points = 5;
        final outerR = r;
        final innerR = r * 0.42;
        for (int i = 0; i < points * 2; i++) {
          final angle = (pi / points) * i - pi / 2;
          final radius = i.isEven ? outerR : innerR;
          final x = cx + radius * cos(angle);
          final y = cy + radius * sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(_ShapeOutlinePainter old) => old.shape != shape;
}