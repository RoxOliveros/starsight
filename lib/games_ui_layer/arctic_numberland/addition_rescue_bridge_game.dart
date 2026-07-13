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

class AdditionRescueBridgeGame extends StatefulWidget {
  final int level;

  const AdditionRescueBridgeGame({super.key, required this.level});

  @override
  State<AdditionRescueBridgeGame> createState() => _AdditionRescueBridgeGameState();
}

class _AdditionRescueBridgeGameState extends State<AdditionRescueBridgeGame>
    with TickerProviderStateMixin, DomaReactionMixin<AdditionRescueBridgeGame>, GameLoadingMixin<AdditionRescueBridgeGame> {  // ADD GameLoadingMixin
  @override
  AudioPlayer get domaPlayer => _voicePlayer;

  // ── Asset paths (swap to match your project) ────────────────────────────
  static const String _iceAssetBase = 'assets/images/objects/arctic/ice_';
  static const String _iceAsset = 'assets/images/objects/arctic/ice_1.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic_river.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _babyFoxAsset = 'assets/images/characters/baby_arctic_fox.png';
  static const String _beamAsset = 'assets/images/objects/arctic/beam.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/rescue_bridge_intro.wav';
  static const String _audioInstructionPrompt = '$_audioBase/rescue_bridge_instruction.wav';
  static const String _audioWeightAddRemove = 'assets/audio/sound_effects/clack.wav';
  static const String _audioWin = '$_audioBase/rescue_bridge_win.wav';

  // ── Game constants ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const double _maxTiltRadians = 0.30;

  /// Addition facts kept to sums of 5 or less, matching the visual/counting
  /// range of the rest of Arctic Numberland.
  static const List<List<int>> _factPool = [
    [1, 1], // 1+1=2
    [1, 2], // 1+2=3
    [2, 1], // 2+1=3
    [1, 3], // 1+3=4
    [2, 2], // 2+2=4
    [1, 4], // 1+4=5
    [2, 3], // 2+3=5
    [3, 2], // 3+2=5
    [3, 1], // 3+1=4
  ];

  static const List<List<double>> _pupScatter = [
    [-26, 0, 1.15],
    [140, 50, 0.85],
    [0, 60, 1.0],
    [80, 118, 0.75],
    [60, 50, 1.05],
  ];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  bool _showWinDialog = false;
  int _rescuedCount = 0;
  bool _pupCrossing = false;
  bool _showEquation = true;

  late List<List<int>> _roundPool;
  late int _addendA;
  late int _addendB;
  late int _target;

  /// Chips available in the tray this round.
  late List<int> _weightPool;

  /// Parallel to _weightPool — true once that chip has been placed on the pan.
  late List<bool> _weightUsed;

  /// Indices (into _weightPool) currently sitting on the pan, in drop order.
  late List<int> _panLoad;

  bool _resolvingRound = false; // locks input while balanced/overloaded plays out

  // ── Audio ────────────────────────────────────────────────────────────────
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _balancePulseCtrl;
  late Animation<double> _balancePulse;
  late AnimationController _campPupCtrl;

  final List<GlobalKey> _pupKeys = List.generate(_totalRounds, (_) => GlobalKey());
  final GlobalKey _campAnchorKey = GlobalKey();
  final GlobalKey _crossingLayerKey = GlobalKey();
  final GlobalKey _beamKey = GlobalKey();
  int? _crossingIndex;
  Offset? _crossingStart;
  Offset? _crossingMid;
  Offset? _crossingEnd;

  String _crystalAssetForValue(int value) {
    final clamped = value.clamp(1, 5);
    return '$_iceAssetBase$clamped.png';
  }

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

    _balancePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _balancePulse =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _balancePulseCtrl, curve: Curves.easeOut),
        );

    _campPupCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
    _addendA = fact[0];
    _addendB = fact[1];
    _target = _addendA + _addendB;

    _weightPool = _buildWeightPool(_addendA, _addendB, _target);
    _weightUsed = List.filled(_weightPool.length, false);
    _panLoad = [];
    _resolvingRound = false;
    _showEquation = true;
    _crossingIndex = null;
    _crossingMid = null;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _currentRound == 0) _playVoice(_audioInstructionPrompt);
    });

    setState(() {});
  }

  List<int> _buildWeightPool(int addendA, int addendB, int target) {
    final rng = Random();
    final pool = <int>[addendA, addendB, target];
    while (pool.length < 6) {
      pool.add(rng.nextInt(5) + 1);
    }
    pool.shuffle(rng);
    return pool;
  }

  int get _currentTotal =>
      _panLoad.fold(0, (sum, idx) => sum + _weightPool[idx]);

  double get _tiltAngle {
    if (_target == 0) return 0;
    final diff = (_currentTotal - _target) / _target;
    return diff.clamp(-1.0, 1.0) * _maxTiltRadians;
  }

  // ── Drag handlers ────────────────────────────────────────────────────────
  void _onWeightDropped(int poolIndex) async {
    if (_resolvingRound || _weightUsed[poolIndex]) return;

    setState(() {
      _weightUsed[poolIndex] = true;
      _panLoad.add(poolIndex);
    });

    HapticFeedback.selectionClick();
    await _playSfxAndWait(_audioWeightAddRemove);

    final total = _currentTotal;
    if (total == _target) {
      _onBalanced();
    } else if (total > _target) {
      _onTooHeavy();
    }
  }

  void _onWeightRemoved(int poolIndex) {
    if (_resolvingRound) return;
    setState(() {
      _weightUsed[poolIndex] = false;
      _panLoad.remove(poolIndex);
    });
    _playSfx(_audioWeightAddRemove);
  }

  Future<void> _onBalanced() async {
    setState(() => _resolvingRound = true);
    HapticFeedback.mediumImpact();
    _balancePulseCtrl.forward(from: 0);
    showDomaReaction(DomaState.correct);
    if (!mounted) return;

    final crossingIndex = _rescuedCount;

    Offset? start;
    Offset? mid;
    Offset? end;
    final layerBox = _crossingLayerKey.currentContext?.findRenderObject() as RenderBox?;
    final pupBox = _pupKeys[crossingIndex].currentContext?.findRenderObject() as RenderBox?;
    final campBox = _campAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    final beamBox = _beamKey.currentContext?.findRenderObject() as RenderBox?;
    if (layerBox != null && pupBox != null && campBox != null) {
      final pupCenter = pupBox.localToGlobal(Offset(pupBox.size.width / 2, pupBox.size.height / 2));
      final campCenter = campBox.localToGlobal(Offset(campBox.size.width / 2, campBox.size.height / 2));
      start = layerBox.globalToLocal(pupCenter);
      end = layerBox.globalToLocal(campCenter);

      if (beamBox != null) {
        final beamCenter = beamBox.localToGlobal(Offset(beamBox.size.width / 2, beamBox.size.height / 2));
        mid = layerBox.globalToLocal(beamCenter);
      }
    }

    setState(() {
      _pupCrossing = true;
      _crossingIndex = crossingIndex;
      _crossingStart = start;
      _crossingMid = mid;
      _crossingEnd = end;
    });

    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    setState(() {
      _pupCrossing = false;
      _crossingIndex = null;
      _rescuedCount++;
    });
    _campPupCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (_currentRound + 1 >= _totalRounds) {
      setState(() {
        _panLoad = [];
        _showEquation = false;
      });
      await _playVoice(_audioWin);
      if (!mounted) return;
      setState(() => _showWinDialog = true);
    } else {
      setState(() => _currentRound++);
      _setupRound();
    }
  }

  Future<void> _onTooHeavy() async {
    setState(() => _resolvingRound = true);
    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _weightUsed = List.filled(_weightPool.length, false);
      _panLoad = [];
      _resolvingRound = false;
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
      await completer.future.timeout(const Duration(seconds: 10));
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

  Future<void> _playSfxAndWait(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _sfxPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _sfxPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('SFX audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  @override
  void dispose() {
    _voicePlayer.dispose();
    _sfxPlayer.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _balancePulseCtrl.dispose();
    _campPupCtrl.dispose();
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

  // ── Intro / story setup ──────────────────────────────────────────────────
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
                      _babyFoxAsset,
                      height: screenH * 0.4,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                      const Text('🦭', style: TextStyle(fontSize: 70)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

  }

  // ── Main game layout ─────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return Stack(
          key: _crossingLayerKey,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ArcticBackButton(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ArcticLevelBadge(level: widget.level),
                      ),
                      Center(child: _buildInstructionBanner(h)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 3, child: _buildIceFloe(h)),
                      Expanded(
                        flex: 5,
                        child: ScaleTransition(
                          scale: _sceneEnter,
                          child: _buildScaleScene(w, h),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 70),
                            _buildSafeCamp(h),
                            const Spacer(),
                            _buildWeightTray(h),
                          ],
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
            ),
            _buildPupCrossing(w, h),
          ],
        );
      },
    );
  }

  /// Full-width overlay: animates the rescued pup walking from the ice floe
  Widget _buildPupCrossing(double w, double h) {
    if (!_pupCrossing) return const SizedBox.shrink();

    final pupSize = (h * 0.13).clamp(32.0, 52.0);
    final start = _crossingStart ?? Offset(w * (1.5 / 11), h * 0.42);
    final end = _crossingEnd ?? Offset(w * (9.5 / 11), h * 0.42);
    final mid = _crossingMid != null
        ? _crossingMid! + const Offset(0, -25)
        : Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2400),
      curve: Curves.linear,
      builder: (_, t, child) {
        Offset pos;
        if (t < 0.5) {
          final segT = t / 0.5;
          pos = Offset.lerp(start, mid, segT)!;
        } else {
          final segT = (t - 0.5) / 0.5;
          pos = Offset.lerp(mid, end, segT)!;
        }

        final bounce = sin(t * pi * 10) * 14;
        return Positioned(
          left: pos.dx - pupSize / 2,
          top: pos.dy - pupSize / 2 - bounce.abs(),
          child: child!,
        );
      },
      child: Image.asset(
        _babyFoxAsset,
        height: pupSize,
        errorBuilder: (_, __, ___) => Text('🦭', style: TextStyle(fontSize: pupSize * 0.7)),
      ),
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
            'Add up, then load the scale to match!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 20,
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

  // ── Ice floe with waiting pups ───────────────────────────────────────────
  Widget _buildIceFloe(double h) {
    final baseSize = (h * 0.13).clamp(32.0, 52.0);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        SizedBox(
          height: h * 0.9,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(_totalRounds, (i) {
              final hidden = i < _rescuedCount || i == _crossingIndex;
              final scatter = _pupScatter[i % _pupScatter.length];
              final pupSize = baseSize * scatter[2];

              return Positioned(
                left: (h * 0.22) + scatter[0] - pupSize / 2,
                top: scatter[1],
                child: AnimatedOpacity(
                  key: _pupKeys[i],
                  opacity: hidden ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Image.asset(
                    _babyFoxAsset,
                    height: pupSize,
                    errorBuilder: (_, __, ___) =>
                        Text('🦭', style: TextStyle(fontSize: pupSize * 0.7)),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Balance scale scene ──────────────────────────────────────────────────
  Widget _buildScaleScene(double w, double h) {
    if (!_showEquation) return const SizedBox.shrink();

    final panSize = (h * 0.3).clamp(70.0, 120.0);
    final beamWidth = (w * 0.9).clamp(230.0, 370.0);
    final balanced = _currentTotal == _target;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: balanced ? _balancePulse : const AlwaysStoppedAnimation(1.0),
            child: AnimatedOpacity(
              opacity: balanced ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
              ),
            ),
          ),

          // beam
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: beamWidth + panSize,
                height: panSize * 2.3,
                child: Stack(
                  clipBehavior: Clip.none,          // ← add this
                  alignment: Alignment.bottomCenter,
                  children: [
                    // rotating beam with pans
                    Positioned(
                      bottom: panSize * 0.4,
                      child: AnimatedRotation(
                        turns: _tiltAngle / (2 * pi),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOut,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: beamWidth,
                          height: panSize * 1.4,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                _beamAsset,
                                key: _beamKey,
                                width: beamWidth,
                                height: 30,
                                fit: BoxFit.fill,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 6,
                                  width: beamWidth,
                                  color: ArcticColorTheme.slateblue,
                                ),
                              ),
                              Positioned(left: 0, top: -panSize * 0.22, child: _buildLeftPan(panSize)),
                              Positioned(right: 0, top: -panSize * 0.22, child: _buildRightPan(panSize)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Fixed "target load" area showing the addition problem.
  Widget _buildLeftPan(double size) {
    return Container(
      width: size * 1.9,
      height: size * 0.8,
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.12,
        vertical: size * 0.04,
      ),
      decoration: BoxDecoration(
        color: ArcticColorTheme.cotton.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.001),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _addendGroup(_addendA, size),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '+',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.bold,
                  color: ArcticColorTheme.cadetblue,
                  shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
                ),
              ),
            ),
            _addendGroup(_addendB, size),
          ],
        ),
      ),
    );
  }

  /// A cluster of ice crystals with its count shown underneath.
  Widget _addendGroup(int count, double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 2,
          runSpacing: 2,
          alignment: WrapAlignment.center,
          children: List.generate(count, (_) => _miniCrystal(size * 0.26)),
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.22,
            fontWeight: FontWeight.bold,
            color: ArcticColorTheme.cadetblue,
            shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  /// Drop target area where the player loads numbered weights.
  Widget _buildRightPan(double size) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
      !_resolvingRound && !_weightUsed[details.data],
      onAcceptWithDetails: (details) => _onWeightDropped(details.data),
      builder: (context, candidateData, rejectedData) {
        return SizedBox(
          width: size * 1.2,
          height: size * 0.8,
          child: _panLoad.isEmpty
              ? Container(
            width: size * 1.6,
            height: size * 0.8,
            decoration: BoxDecoration(
              color: ArcticColorTheme.cotton.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ArcticColorTheme.slateblue.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                'Drop\nweights',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: size * 0.12,
                  color: ArcticColorTheme.slateblue.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
              : Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, size * 0.10),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: _panLoad.map((idx) {
                  return GestureDetector(
                    onTap: () => _onWeightRemoved(idx),
                    child: _weightChipVisual(_weightPool[idx], size * 0.48),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniCrystal(double size) {
    return Image.asset(
      _iceAsset,
      width: size,
      height: size,
      errorBuilder: (_, __, ___) =>
          Text('🧊', style: TextStyle(fontSize: size)),
    );
  }

  Widget _weightChipVisual(int value, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              _crystalAssetForValue(value),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEAF8FD), Color(0xFF9FDCEF), Color(0xFF48CAE4)],
                    stops: [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    color: ArcticColorTheme.cadetblue,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ArcticColorTheme.pictonblue,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: ArcticColorTheme.pictonblue.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Weight tray ───────────────────────────────────────────────────────────
  Widget _buildWeightTray(double h) {
    final chipSize = (h * 0.16).clamp(46.0, 72.0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: List.generate(_weightPool.length, (i) {
          final used = _weightUsed[i];
          final chip = _weightChipVisual(_weightPool[i], chipSize);

          if (used) {
            return Opacity(opacity: 0.25, child: chip);
          }

          return Draggable<int>(
            data: i,
            feedback: Material(
              color: Colors.transparent,
              child: _weightChipVisual(_weightPool[i], chipSize * 1.15),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: chip),
            child: chip,
          );
        }),
      ),
    );
  }

  // ── Safe camp (rescued pups) ─────────────────────────────────────────────
  Widget _buildSafeCamp(double h) {
    final pupSize = (h * 0.1).clamp(24.0, 40.0);

    return Column(
      key: _campAnchorKey,          // ← add
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: List.generate(_rescuedCount, (i) {
            final isNewest = i == _rescuedCount - 1;
            return ScaleTransition(
              scale: isNewest
                  ? CurvedAnimation(parent: _campPupCtrl, curve: Curves.elasticOut)
                  : const AlwaysStoppedAnimation(1.0),
              child: Image.asset(
                _babyFoxAsset,
                height: pupSize,
                errorBuilder: (_, __, ___) =>
                    Text('🦭', style: TextStyle(fontSize: pupSize * 0.7)),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _rescuedCount;
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
          _rescuedCount = 0;
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
