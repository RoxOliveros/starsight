import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';

enum _ShapeType { circle, square, triangle, star }

class _ShapeSpot {
  final String id;
  final _ShapeType correctShape;
  final double anchorX; // fractional position within the snowman bounding box
  final double anchorY;
  final int trayChoices;

  const _ShapeSpot({
    required this.id,
    required this.correctShape,
    required this.anchorX,
    required this.anchorY,
    this.trayChoices = 3,
  });
}

class _SnowmanSpec {
  final List<_ShapeSpot> spots;
  const _SnowmanSpec(this.spots);
}

class _RoundSpec {
  final List<_SnowmanSpec> snowmen;
  const _RoundSpec(this.snowmen);
}

class SnowmanShapeHuntGame extends StatefulWidget {
  const SnowmanShapeHuntGame({super.key});

  @override
  State<SnowmanShapeHuntGame> createState() => _SnowmanShapeHuntGameState();
}

class _SnowmanShapeHuntGameState extends State<SnowmanShapeHuntGame>
    with TickerProviderStateMixin, DomaReactionMixin<SnowmanShapeHuntGame>, GameLoadingMixin<SnowmanShapeHuntGame> {
  @override
  AudioPlayer get domaPlayer => _voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _snowmanAsset = 'assets/images/objects/arctic/snowman_shape_outline.png';
  static const String _tagAsset = 'assets/images/objects/arctic/tag.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/snowman_intro.wav';
  static const String _audioInstruction = '$_audioBase/snowman_instruction.wav';
  static const String _audioSnowmanComplete = '$_audioBase/snowman_complete.wav';
  static const String _audioWin = '$_audioBase/snowman_win.wav';
  static const String _audioPlace = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  // Difficulty ramps: 2 spots/2 tray choices -> 3 spots -> discrimination
  // spot (hat/star) -> two snowmen at once -> full 5-spot build using every
  // shape type.
  static final List<_RoundSpec> _rounds = [
    const _RoundSpec([
      _SnowmanSpec([
        _ShapeSpot(id: 'nose', correctShape: _ShapeType.triangle, anchorX: 0.5, anchorY: 0.265, trayChoices: 2),
        _ShapeSpot(id: 'button1', correctShape: _ShapeType.circle, anchorX: 0.481, anchorY: 0.47, trayChoices: 2),
      ]),
    ]),
    const _RoundSpec([
      _SnowmanSpec([
        _ShapeSpot(id: 'nose', correctShape: _ShapeType.triangle, anchorX: 0.5, anchorY: 0.265),
        _ShapeSpot(id: 'button1', correctShape: _ShapeType.circle, anchorX: 0.481, anchorY: 0.47),
        _ShapeSpot(id: 'button2', correctShape: _ShapeType.square, anchorX: 0.48155, anchorY: 0.555),
      ]),
    ]),
    const _RoundSpec([
      _SnowmanSpec([
        _ShapeSpot(id: 'hat', correctShape: _ShapeType.star, anchorX: 0.5, anchorY: 0.09),
        _ShapeSpot(id: 'nose', correctShape: _ShapeType.triangle, anchorX: 0.5, anchorY: 0.265),
        _ShapeSpot(id: 'button1', correctShape: _ShapeType.circle, anchorX: 0.481, anchorY: 0.47),
      ]),
    ]),
    const _RoundSpec([
      _SnowmanSpec([
        _ShapeSpot(id: 'nose', correctShape: _ShapeType.triangle, anchorX: 0.5, anchorY: 0.265),
        _ShapeSpot(id: 'button1', correctShape: _ShapeType.circle, anchorX: 0.481, anchorY: 0.47),
        _ShapeSpot(id: 'hat', correctShape: _ShapeType.star, anchorX: 0.5, anchorY: 0.09),
      ]),
    ]),
    const _RoundSpec([
      _SnowmanSpec([
        _ShapeSpot(id: 'hat', correctShape: _ShapeType.star, anchorX: 0.5, anchorY: 0.09),
        _ShapeSpot(id: 'nose', correctShape: _ShapeType.triangle, anchorX: 0.5, anchorY: 0.265),
        _ShapeSpot(id: 'button1', correctShape: _ShapeType.circle, anchorX: 0.481, anchorY: 0.47),
        _ShapeSpot(id: 'button2', correctShape: _ShapeType.square, anchorX: 0.48155, anchorY: 0.555),
        _ShapeSpot(id: 'button3', correctShape: _ShapeType.triangle, anchorX: 0.48155, anchorY: 0.635),
      ]),
    ]),
  ];

  static final int _totalRounds = _rounds.length;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  int _currentSnowmanIndex = 0;
  int _solvedRounds = 0;
  bool _showWinDialog = false;

  late _RoundSpec _round;
  late _SnowmanSpec _snowman;
  Set<String> _filledSpotIds = {};

  String? _activeSpotId;
  List<_ShapeType> _trayOptions = [];
  bool _trayWrong = false;
  bool _snowmanWiggling = false;

  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _spotPulseCtrl;
  late Animation<double> _spotPulse;
  late AnimationController _wiggleCtrl;
  late Animation<double> _wiggle;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRound();
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

    _spotPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _spotPulse = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _spotPulseCtrl, curve: Curves.easeInOut));

    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _wiggle = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.06), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.06), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _wiggleCtrl, curve: Curves.easeInOut));
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
  }

  void _setupRound() {
    _round = _rounds[_currentRound];
    _currentSnowmanIndex = 0;
    _loadSnowman(_round.snowmen[0]);

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _playVoice(_audioInstruction);
    });

    setState(() {});
  }

  void _loadSnowman(_SnowmanSpec spec) {
    _snowman = spec;
    _filledSpotIds = {};
    _activeSpotId = null;
    _trayOptions = [];
    _trayWrong = false;
  }

  // ── Spot interaction ─────────────────────────────────────────────────────
  void _activateSpot(_ShapeSpot spot) {
    if (_filledSpotIds.contains(spot.id) || _activeSpotId == spot.id) return;
    final rng = Random();
    final distractors = _ShapeType.values.where((s) => s != spot.correctShape).toList()..shuffle(rng);
    final options = [spot.correctShape, ...distractors.take(spot.trayChoices - 1)]..shuffle(rng);
    setState(() {
      _activeSpotId = spot.id;
      _trayOptions = options;
      _trayWrong = false;
    });
  }

  void _dismissTray() {
    if (_activeSpotId == null) return;
    setState(() {
      _activeSpotId = null;
      _trayOptions = [];
      _trayWrong = false;
    });
  }

  Future<void> _onShapeDropped(_ShapeSpot spot, _ShapeType dropped) async {
    if (_filledSpotIds.contains(spot.id)) return;

    if (dropped == spot.correctShape) {
      HapticFeedback.mediumImpact();
      _playSfx(_audioPlace);
      showDomaReaction(DomaState.correct);
      setState(() {
        _filledSpotIds.add(spot.id);
        _activeSpotId = null;
        _trayOptions = [];
      });

      if (_snowman.spots.every((s) => _filledSpotIds.contains(s.id))) {
        await _onSnowmanComplete();
      }
    } else {
      HapticFeedback.heavyImpact();
      showDomaReaction(DomaState.wrong);
      setState(() => _trayWrong = true);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _trayWrong = false);
    }
  }

  Future<void> _onSnowmanComplete() async {
    setState(() => _snowmanWiggling = true);
    _wiggleCtrl.forward(from: 0);
    await _playVoice(_audioSnowmanComplete);
    if (!mounted) return;
    setState(() => _snowmanWiggling = false);

    final nextIndex = _currentSnowmanIndex + 1;
    if (nextIndex < _round.snowmen.length) {
      setState(() => _currentSnowmanIndex = nextIndex);
      _loadSnowman(_round.snowmen[nextIndex]);
      _sceneEnterCtrl.forward(from: 0);
      setState(() {});
      return;
    }

    setState(() => _solvedRounds++);

    if (_currentRound + 1 >= _totalRounds) {
      await _playVoice(_audioWin);
      if (!mounted) return;
      setState(() => _showWinDialog = true);
    } else {
      setState(() => _currentRound++);
      _setupRound();
    }
  }

  // ── Audio ────────────────────────────────────────────────────────────────
  Future<void> _playVoice(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _voicePlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _voicePlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Voice audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  void _playSfx(String asset) {
    _sfxPlayer.play(AssetSource(asset.replaceFirst('assets/', ''))).catchError((e) {
      debugPrint('SFX audio error ($asset): $e');
    });
  }

  @override
  void dispose() {
    _voicePlayer.dispose();
    _sfxPlayer.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _spotPulseCtrl.dispose();
    _wiggleCtrl.dispose();
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
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
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
              child: Image.asset(
                _characterImage,
                height: screenH * 0.7,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Image.asset(
              _snowmanAsset,
              height: screenH * 0.75,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('⛄', style: TextStyle(fontSize: 90)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main game layout ─────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return Column(
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
            Expanded(
              child: ScaleTransition(
                scale: _sceneEnter,
                child: _buildSnowmanScene(w, h),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 5),
              child: _buildRoundIndicator(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => _playVoice(_audioInstruction),
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
            'Tap a spot, then drag the matching shape!',
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

  // ── Snowman scene with popup tray ───────────────────────────────────────
  Widget _buildSnowmanScene(double w, double h) {
    const double snowmanAspectRatio = 0.6;

    final maxBoardWidth = w * 0.42;
    final maxBoardHeight = h * 1;

    double boardHeight = maxBoardHeight;
    double boardWidth = boardHeight * snowmanAspectRatio;
    if (boardWidth > maxBoardWidth) {
      boardWidth = maxBoardWidth;
      boardHeight = boardWidth / snowmanAspectRatio;
    }

    final activeSpot =
    _activeSpotId == null ? null : _snowman.spots.firstWhere((s) => s.id == _activeSpotId);

    return Center(
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Tapping anywhere outside the tray dismisses it.
            if (activeSpot != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _dismissTray,
                ),
              ),
            AnimatedBuilder(
              animation: _wiggle,
              builder: (_, child) => Transform.rotate(
                angle: _snowmanWiggling ? _wiggle.value : 0,
                child: child,
              ),
              child: Image.asset(
                _snowmanAsset,
                width: boardWidth,
                height: boardHeight,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text('⛄', style: TextStyle(fontSize: boardHeight * 0.5)),
                ),
              ),
            ),
            ..._snowman.spots.map((spot) => _buildSpot(spot, boardWidth, boardHeight)),
            if (activeSpot != null) _buildTrayPopup(activeSpot, boardWidth, boardHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildSpot(_ShapeSpot spot, double boardWidth, double boardHeight) {
    final size = boardWidth * 0.25;
    final left = boardWidth * spot.anchorX - size / 2;
    final top = boardHeight * spot.anchorY - size / 2;
    final filled = _filledSpotIds.contains(spot.id);

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: DragTarget<_ShapeType>(
        onWillAcceptWithDetails: (details) => !filled,
        onAcceptWithDetails: (details) => _onShapeDropped(spot, details.data),
        builder: (context, candidateData, rejectedData) {
          final highlight = candidateData.isNotEmpty;

          if (filled) {
            return _shapeIcon(spot.correctShape, size, color: ArcticColorTheme.cadetblue);
          }

          return GestureDetector(
            onTap: () => _activateSpot(spot),
            child: AnimatedBuilder(
              animation: _spotPulse,
              builder: (_, child) => Transform.scale(
                scale: _activeSpotId == spot.id ? 1.0 : _spotPulse.value,
                child: child,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: highlight
                      ? ArcticColorTheme.pictonblue.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: highlight ? ArcticColorTheme.pictonblue : ArcticColorTheme.slateblue.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.help_outline, size: size * 0.5, color: ArcticColorTheme.slateblue),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Small tray of draggable shape tiles anchored near the tapped spot,
  /// flipping above the spot when there isn't room below (e.g. low buttons).
  Widget _buildTrayPopup(_ShapeSpot spot, double boardWidth, double boardHeight) {
    final tileSize = boardWidth * 0.25;
    final trayWidth = tileSize * _trayOptions.length + 12.0 * (_trayOptions.length - 1) + 20;
    final flipAbove = spot.anchorY > 0.6;
    final spotSize = boardWidth * 0.16;

    final centerX = boardWidth * spot.anchorX;
    final left = (centerX - trayWidth / 2).clamp(0.0, max(0.0, boardWidth - trayWidth)).toDouble();

    final rawTop = flipAbove
        ? boardHeight * spot.anchorY - spotSize / 2 - tileSize - 24
        : boardHeight * spot.anchorY + spotSize / 2 + 12;
    final top = rawTop.clamp(0.0, max(0.0, boardHeight - tileSize - 20)).toDouble();

    return Positioned(
      left: left,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ArcticColorTheme.pictonblue, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _trayOptions.map((shape) {
            final tile = _shapeTile(shape, tileSize, wrong: _trayWrong);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Draggable<_ShapeType>(
                data: shape,
                feedback: Material(color: Colors.transparent, child: tile),
                childWhenDragging: Opacity(opacity: 0.3, child: tile),
                child: tile,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Draggable tag-backed tile shown in the tray.
  Widget _shapeTile(_ShapeType shape, double size, {required bool wrong}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            _tagAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: wrong ? Colors.red.shade300 : null,
            colorBlendMode: wrong ? BlendMode.modulate : null,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                color: wrong ? Colors.red.shade300 : ArcticColorTheme.pictonblue,
                borderRadius: BorderRadius.circular(size * 0.22),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, size * 0.08), // ← tweak this to move it up/down
            child: _shapeGlyph(shape, size * 0.5, color: wrong ? Colors.red.shade100 : ArcticColorTheme.cotton),
          ),
        ],
      ),
    );
  }

  /// Icon shown once a spot has been correctly filled.
  Widget _shapeIcon(_ShapeType shape, double size, {required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white54,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: _shapeGlyph(shape, size * 0.65, color: color),
    );
  }

  Widget _shapeGlyph(_ShapeType shape, double size, {required Color color}) {
    switch (shape) {
      case _ShapeType.circle:
        return Icon(Icons.circle, size: size, color: color);
      case _ShapeType.square:
        return Icon(Icons.square_rounded, size: size, color: color);
      case _ShapeType.triangle:
        return Icon(Icons.change_history_rounded, size: size, color: color);
      case _ShapeType.star:
        return Icon(Icons.star_rounded, size: size, color: color);
    }
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
