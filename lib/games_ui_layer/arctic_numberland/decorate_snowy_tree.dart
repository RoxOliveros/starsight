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


enum _OrnamentColor { red, blue, green, yellow, purple }

extension on _OrnamentColor {
  Color get swatch {
    switch (this) {
      case _OrnamentColor.red:
        return const Color(0xFFE84855);
      case _OrnamentColor.blue:
        return const Color(0xFF4CB8E4);
      case _OrnamentColor.green:
        return const Color(0xFF3B873B);
      case _OrnamentColor.yellow:
        return const Color(0xFFF9D552);
      case _OrnamentColor.purple:
        return const Color(0xFF8E6BC4);
    }
  }

  String get audioAsset {
    const base = 'assets/audio/arctic_numberland';
    switch (this) {
      case _OrnamentColor.red:
        return '$base/color_red.wav';
      case _OrnamentColor.blue:
        return '$base/color_blue.wav';
      case _OrnamentColor.green:
        return '$base/color_green.wav';
      case _OrnamentColor.yellow:
        return '$base/color_yellow.wav';
      case _OrnamentColor.purple:
        return '$base/color_purple.wav';
    }
  }
}

class _OrnamentSpot {
  final String id;
  final _OrnamentColor correctColor;
  final double anchorX;
  final double anchorY;
  final int trayChoices;

  const _OrnamentSpot({
    required this.id,
    required this.correctColor,
    required this.anchorX,
    required this.anchorY,
    this.trayChoices = 2,
  });
}

class _RoundSpec {
  final List<_OrnamentSpot> spots;
  const _RoundSpec(this.spots);
}

class DecorateSnowyTreeGame extends StatefulWidget {
  const DecorateSnowyTreeGame({super.key});

  @override
  State<DecorateSnowyTreeGame> createState() => _DecorateSnowyTreeGameState();
}

class _DecorateSnowyTreeGameState extends State<DecorateSnowyTreeGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<DecorateSnowyTreeGame>,
        GameLoadingMixin<DecorateSnowyTreeGame>,
        ArcticAudioMixin<DecorateSnowyTreeGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _treeAsset = 'assets/images/objects/arctic/snowy_tree.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/decorate_tree_intro.wav';
  static const String _audioInstruction = '$_audioBase/decorate_tree_instruction.wav';
  static const String _audioWin = '$_audioBase/decorate_tree_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  // Ramp: 1 spot -> 2 -> 3 -> 4 -> 5, introducing more colors as tray
  // choices grow from 2 up to 4.
  static const List<_RoundSpec> _rounds = [
    _RoundSpec([
      _OrnamentSpot(id: 'top', correctColor: _OrnamentColor.red, anchorX: 0.5, anchorY: 0.18, trayChoices: 2),
    ]),
    _RoundSpec([
      _OrnamentSpot(id: 'top', correctColor: _OrnamentColor.red, anchorX: 0.5, anchorY: 0.18, trayChoices: 2),
      _OrnamentSpot(id: 'left1', correctColor: _OrnamentColor.blue, anchorX: 0.32, anchorY: 0.38, trayChoices: 2),
    ]),
    _RoundSpec([
      _OrnamentSpot(id: 'top', correctColor: _OrnamentColor.yellow, anchorX: 0.5, anchorY: 0.18, trayChoices: 3),
      _OrnamentSpot(id: 'left1', correctColor: _OrnamentColor.blue, anchorX: 0.32, anchorY: 0.38, trayChoices: 3),
      _OrnamentSpot(id: 'right1', correctColor: _OrnamentColor.green, anchorX: 0.68, anchorY: 0.42, trayChoices: 3),
    ]),
    _RoundSpec([
      _OrnamentSpot(id: 'top', correctColor: _OrnamentColor.purple, anchorX: 0.5, anchorY: 0.18, trayChoices: 3),
      _OrnamentSpot(id: 'left1', correctColor: _OrnamentColor.blue, anchorX: 0.32, anchorY: 0.38, trayChoices: 3),
      _OrnamentSpot(id: 'right1', correctColor: _OrnamentColor.green, anchorX: 0.68, anchorY: 0.42, trayChoices: 3),
      _OrnamentSpot(id: 'left2', correctColor: _OrnamentColor.red, anchorX: 0.51, anchorY: 0.32, trayChoices: 3),
    ]),
    _RoundSpec([
      _OrnamentSpot(id: 'top', correctColor: _OrnamentColor.red, anchorX: 0.5, anchorY: 0.16, trayChoices: 4),
      _OrnamentSpot(id: 'left1', correctColor: _OrnamentColor.blue, anchorX: 0.32, anchorY: 0.36, trayChoices: 4),
      _OrnamentSpot(id: 'right1', correctColor: _OrnamentColor.green, anchorX: 0.68, anchorY: 0.4, trayChoices: 4),
      _OrnamentSpot(id: 'left2', correctColor: _OrnamentColor.yellow, anchorX: 0.51, anchorY: 0.32, trayChoices: 4),
      _OrnamentSpot(id: 'right2', correctColor: _OrnamentColor.purple, anchorX: 0.64, anchorY: 0.24, trayChoices: 4),
    ]),
  ];

  static final int _totalRounds = _rounds.length;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  bool _showWinDialog = false;

  late _RoundSpec _round;
  Set<String> _filledSpotIds = {};

  String? _activeSpotId;
  List<_OrnamentColor> _trayOptions = [];
  bool _trayWrong = false;
  bool _treeWiggling = false;

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
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) playVoice(_audioInstruction);
  }

  void _setupRound({bool playInstruction = true}) {
    _round = _rounds[_currentRound];
    _filledSpotIds = {};
    _activeSpotId = null;
    _trayOptions = [];
    _trayWrong = false;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) playVoice(_audioInstruction);
      });
    }

    setState(() {});
  }

  // ── Spot interaction ─────────────────────────────────────────────────────
  void _activateSpot(_OrnamentSpot spot) {
    if (_filledSpotIds.contains(spot.id) || _activeSpotId == spot.id) return;
    final rng = Random();
    final distractors = _OrnamentColor.values.where((c) => c != spot.correctColor).toList()..shuffle(rng);
    final options = [spot.correctColor, ...distractors.take(spot.trayChoices - 1)]..shuffle(rng);
    setState(() {
      _activeSpotId = spot.id;
      _trayOptions = options;
      _trayWrong = false;
    });
  }

  Future<void> _onColorDropped(_OrnamentSpot spot, _OrnamentColor dropped) async {
    if (_filledSpotIds.contains(spot.id)) return;

    if (dropped == spot.correctColor) {
      HapticFeedback.mediumImpact();
      setState(() {
        _filledSpotIds.add(spot.id);
        _activeSpotId = null;
        _trayOptions = [];
      });
      await playSfx(dropped.audioAsset);
      showDomaReaction(DomaState.correct);

      if (_round.spots.every((s) => _filledSpotIds.contains(s.id))) {
        await Future.delayed(const Duration(milliseconds: 800));
        await _onRoundComplete();
      }
    } else {
      showDomaReaction(DomaState.wrong);
      HapticFeedback.heavyImpact();
      setState(() => _trayWrong = true);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _trayWrong = false);
    }
  }

  Future<void> _onRoundComplete() async {
    setState(() => _treeWiggling = true);
    await _wiggleCtrl.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _treeWiggling = false;
      _solvedRounds++;
    });

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
              _treeAsset,
              height: screenH * 0.75,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('🎄', style: TextStyle(fontSize: 90)),
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

        return Stack(
          children: [
            Column(
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
                    child: _buildTreeScene(w, h),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 0, bottom: 5),
                  child: _buildRoundIndicator(),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: h * 0.1,
              child: _buildAnswerTrayPanel(w, h),
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
            'Tap a spot, then drag the matching color!',
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

  // ── Tree scene ───────────────────────────────────────────────────────────
  Widget _buildTreeScene(double w, double h) {
    const double treeAspectRatio = 0.62;

    final maxBoardWidth = w * 0.6;
    final maxBoardHeight = h * 1.3;

    double boardHeight = maxBoardHeight;
    double boardWidth = boardHeight * treeAspectRatio;
    if (boardWidth > maxBoardWidth) {
      boardWidth = maxBoardWidth;
      boardHeight = boardWidth / treeAspectRatio;
    }

    return Center(
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _wiggle,
              builder: (_, child) => Transform.rotate(
                angle: _treeWiggling ? _wiggle.value : 0,
                child: child,
              ),
              child: Image.asset(
                _treeAsset,
                width: boardWidth,
                height: boardHeight,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text('🎄', style: TextStyle(fontSize: boardHeight * 0.5)),
                ),
              ),
            ),
            ..._round.spots.map((spot) => _buildSpot(spot, boardWidth, boardHeight)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpot(_OrnamentSpot spot, double boardWidth, double boardHeight) {
    final size = boardWidth * 0.18;
    final left = boardWidth * spot.anchorX - size / 2;
    final top = boardHeight * spot.anchorY - size / 2;
    final filled = _filledSpotIds.contains(spot.id);

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: DragTarget<_OrnamentColor>(
        onWillAcceptWithDetails: (details) => !filled,
        onAcceptWithDetails: (details) => _onColorDropped(spot, details.data),
        builder: (context, candidateData, rejectedData) {
          final highlight = candidateData.isNotEmpty;

          if (filled) {
            return _ornamentVisual(spot.correctColor, size);
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
                      ? spot.correctColor.swatch.withValues(alpha: 0.45)
                      : spot.correctColor.swatch.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: highlight ? ArcticColorTheme.pictonblue : spot.correctColor.swatch,
                    width: 2.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.help_outline, size: size * 0.5, color: spot.correctColor.swatch),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Fixed answer tray docked in the lower-right corner — replaces the
  /// floating popup used in earlier games. Shows a placeholder prompt
  /// until a spot is tapped, then shows draggable color choices for it.
  Widget _buildAnswerTrayPanel(double w, double h) {
    final panelWidth = (w * 0.22).clamp(160.0, 240.0);
    final tileSize = (h * 0.12).clamp(46.0, 66.0);

    return Container(
      width: panelWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ArcticColorTheme.pictonblue, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: _activeSpotId == null
          ? Text(
              'Tap an empty\nspot on the tree!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: (h * 0.032).clamp(12.0, 15.0),
                fontWeight: FontWeight.w600,
                color: ArcticColorTheme.slateblue.withValues(alpha: 0.7),
              ),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _trayOptions.map((color) {
                final tile = _ornamentVisual(color, tileSize, wrong: _trayWrong);
                return Draggable<_OrnamentColor>(
                  data: color,
                  feedback: Material(color: Colors.transparent, child: tile),
                  childWhenDragging: Opacity(opacity: 0.3, child: tile),
                  child: tile,
                );
              }).toList(),
            ),
    );
  }

  /// A simple colored bauble — circle body plus a small cap/loop on top,
  /// drawn rather than image-based so it's easy to reskin later.
  Widget _ornamentVisual(_OrnamentColor color, double size, {bool wrong = false}) {
    final bodyColor = wrong ? Colors.red.shade300 : color.swatch;

    return SizedBox(
      width: size,
      height: size * 1.15,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: size * 0.22,
              height: size * 0.16,
              decoration: BoxDecoration(
                color: ArcticColorTheme.cadetblue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: size * 0.14,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bodyColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: bodyColor.withValues(alpha: 0.45), blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
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
