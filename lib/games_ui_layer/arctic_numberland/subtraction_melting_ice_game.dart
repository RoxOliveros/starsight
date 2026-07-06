import 'dart:async';
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

class SubtractionMeltingIceGame extends StatefulWidget {
  const SubtractionMeltingIceGame({super.key});

  @override
  State<SubtractionMeltingIceGame> createState() =>
      _SubtractionMeltingIceGameState();
}

class _SubtractionMeltingIceGameState extends State<SubtractionMeltingIceGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<SubtractionMeltingIceGame>,
        GameLoadingMixin<SubtractionMeltingIceGame> {
  // ADD GameLoadingMixin
  @override
  AudioPlayer get domaPlayer => _voicePlayer;

  // ── Asset paths (swap to match your project) ────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _iceAsset = 'assets/images/objects/arctic/ice_1.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/melting_ice_intro.wav';
  static const String _audioInstructionPrompt = '$_audioBase/melting_ice_instruction.wav';
  static const String _audioMeltRefreeze = 'assets/audio/sound_effects/plip.wav';

  // ── Game constants ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  /// Subtraction facts kept to a minuend of 5 or less, matching the
  /// visual/counting range of the rest of Arctic Numberland.
  static const List<List<int>> _factPool = [
    [2, 1], // 2-1=1
    [3, 1], // 3-1=2
    [3, 2], // 3-2=1
    [4, 1], // 4-1=3
    [4, 2], // 4-2=2
    [4, 3], // 4-3=1
    [5, 1], // 5-1=4
    [5, 2], // 5-2=3
    [5, 3], // 5-3=2
    [5, 4], // 5-4=1
  ];

  /// Slight length variation so the ice don't look mechanically uniform.
  static const List<double> _iceLengthScale = [1.0, 1.25, 0.9, 1.15, 1.05];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  bool _showWinDialog = false;
  int _solvedCount = 0;
  bool _resolvingRound = false;
  bool _shattering = false;

  late List<List<int>> _roundPool;
  late int _minuend;
  late int _subtrahend;
  late int _target;

  /// One entry per ice in this round — true once melted away.
  late List<bool> _popped;

  Timer? _solveTimer;

  // ── Audio ────────────────────────────────────────────────────────────────
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _correctPulseCtrl;
  late Animation<double> _correctPulse;
  late AnimationController _shatterCtrl;
  late Animation<double> _shatterShake;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _roundPool = [..._factPool]..shuffle();
    _initAnimations();
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
    _instructionBounce = TweenSequence(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
      ],
    ).animate(CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut));

    _sceneEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sceneEnter = CurvedAnimation(
      parent: _sceneEnterCtrl,
      curve: Curves.elasticOut,
    );

    _correctPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _correctPulse =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.95), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _correctPulseCtrl, curve: Curves.easeOut),
        );

    _shatterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shatterShake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.04), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.03), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _shatterCtrl, curve: Curves.easeOut));
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _setupRound();
  }

  void _setupRound() {
    if (_roundPool.isEmpty) {
      _roundPool = [..._factPool]..shuffle();
    }
    final fact = _roundPool.removeLast();
    _minuend = fact[0];
    _subtrahend = fact[1];
    _target = _minuend - _subtrahend;

    _popped = List.filled(_minuend, false);
    _resolvingRound = false;
    _shattering = false;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (_currentRound == 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _playVoice(_audioInstructionPrompt);
        }
      });
    }

    setState(() {});
  }

  int get _poppedCount => _popped.where((p) => p).length;

  // ── Tap handler ──────────────────────────────────────────────────────────
  void _onIceTap(int index) {
    if (_resolvingRound) return;

    final wasPopped = _popped[index];
    HapticFeedback.selectionClick();
    _playSfx(wasPopped ? _audioMeltRefreeze : _audioMeltRefreeze);

    setState(() => _popped[index] = !wasPopped);
    _solveTimer?.cancel();

    final poppedCount = _poppedCount;
    if (poppedCount > _subtrahend) {
      _onTooManyMelted();
    } else if (poppedCount == _subtrahend) {
      _correctPulseCtrl.forward(from: 0);
      _solveTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && !_resolvingRound) _onSolved();
      });
    }
  }

  Future<void> _onSolved() async {
    setState(() => _resolvingRound = true);
    HapticFeedback.mediumImpact();
    showDomaReaction(DomaState.correct);
    if (!mounted) return;

    setState(() => _solvedCount++);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (_currentRound + 1 >= _totalRounds) {
      if (!mounted) return;
      setState(() => _showWinDialog = true);
    } else {
      setState(() => _currentRound++);
      _setupRound();
    }
  }

  Future<void> _onTooManyMelted() async {
    setState(() {
      _resolvingRound = true;
      _shattering = true;
    });
    HapticFeedback.heavyImpact();
    _shatterCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _popped = List.filled(_minuend, false);
      _resolvingRound = false;
      _shattering = false;
    });
    showDomaReaction(DomaState.wrong);
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
      await completer.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Voice audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  void _playSfx(String asset) {
    _sfxPlayer.play(AssetSource(asset.replaceFirst('assets/', ''))).catchError((
      e,
    ) {
      debugPrint('SFX audio error ($asset): $e');
    });
  }

  @override
  void dispose() {
    _solveTimer?.cancel();
    _voicePlayer.dispose();
    _sfxPlayer.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _correctPulseCtrl.dispose();
    _shatterCtrl.dispose();
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
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFDCEFFA)),
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

  // ── Intro / story setup ──────────────────────────────────────────────────
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
                    CurvedAnimation(
                      parent: _domaFloatCtrl,
                      curve: Curves.easeInOut,
                    ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _iceAsset,
                  height: screenH * 0.3,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('🧊', style: TextStyle(fontSize: 70)),
                ),
              ],
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ArcticBackButton(),
                  ),
                  Center(child: _buildInstructionBanner(h)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: ScaleTransition(
                      scale: _sceneEnter,
                      child: _buildIceScene(w, h),
                    ),
                  ),
                ],
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
        onTap: () => _playVoice(_audioInstructionPrompt),
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
            'Tap the ice to melt away the right amount!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: (h * 0.07).clamp(14.0, 20.0),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0x55003366),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Ice scene: equation + beam + tappable ice ─────────────────────
  Widget _buildIceScene(double w, double h) {
    final beamWidth = (w * 0.85).clamp(220.0, 380.0);
    final equationSize = (h * 0.3).clamp(70.0, 110.0);
    final iceAreaHeight = h * 0.4;
    final waitingForConfirm = !_resolvingRound && _poppedCount == _subtrahend;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEquationDisplay(equationSize),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _shattering ? _shatterShake : _kZeroAnim,
            builder: (_, child) => Transform.rotate(
              angle: _shattering ? _shatterShake.value : 0,
              child: child,
            ),
            child: ScaleTransition(
              scale: waitingForConfirm
                  ? _correctPulse
                  : const AlwaysStoppedAnimation(1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: beamWidth,
                    height: iceAreaHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(_minuend, (i) {
                        return _buildIce(i, iceAreaHeight);
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static final Animation<double> _kZeroAnim = AlwaysStoppedAnimation<double>(
    0.0,
  );

  Widget _buildEquationDisplay(double size) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.25,
        vertical: size * 0.08,
      ),
      decoration: BoxDecoration(
        color: ArcticColorTheme.cotton.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$_minuend − $_subtrahend = ?',
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontSize: size * 0.24,
          fontWeight: FontWeight.bold,
          color: ArcticColorTheme.cadetblue,
          shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
        ),
      ),
    );
  }

  /// A single hanging, tappable ice. Melted ice shrink, drip down,
  /// and fade out; tapping a melted ice re-freezes it.
  Widget _buildIce(int index, double areaHeight) {
    final popped = _popped[index];
    final lengthScale = _iceLengthScale[index % _iceLengthScale.length];
    final baseHeight = areaHeight * 0.85 * lengthScale;
    final width = baseHeight * 0.34;

    return GestureDetector(
      onTap: () => _onIceTap(index),
      child: AnimatedOpacity(
        opacity: popped ? 0.15 : 1.0,
        duration: const Duration(milliseconds: 350),
        child: AnimatedScale(
          scale: popped ? 0.35 : 1.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
          child: AnimatedSlide(
            offset: popped ? const Offset(0, 0.4) : Offset.zero,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
            child: Image.asset(
              _iceAsset,
              width: width,
              height: baseHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.water_drop,
                size: width,
                color: ArcticColorTheme.pictonblue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedCount;
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
        // TODO @Tin navigate to next games
        // Navigator.pop(context, const ());
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedCount = 0;
          _roundPool = [..._factPool]..shuffle();
          _setupRound();
        });
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
