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

class AdditionPackageDeliveryGame extends StatefulWidget {
  final int level;

  const AdditionPackageDeliveryGame({super.key, required this.level});

  @override
  State<AdditionPackageDeliveryGame> createState() => _AdditionPackageDeliveryGameState();
}

class _AdditionPackageDeliveryGameState extends State<AdditionPackageDeliveryGame>
    with TickerProviderStateMixin, DomaReactionMixin<AdditionPackageDeliveryGame>, GameLoadingMixin<AdditionPackageDeliveryGame> {
  @override
  AudioPlayer get domaPlayer => _voicePlayer;

  // ── Asset paths (swap to match your project) ────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _packageAssetBase = 'assets/images/objects/arctic/package_';
  static const String _miniPackageAsset = 'assets/images/objects/arctic/package_1.png';
  static const String _sledAsset = 'assets/images/objects/arctic/sled.png';
  static const String _houseAsset = 'assets/images/objects/arctic/house.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/package_delivery_intro.wav';
  static const String _audioPackageAddRemove = 'assets/audio/sound_effects/thump.wav';
  static const String _audioWin = '$_audioBase/package_delivery_win.wav';

  static final Animation<double> _kZeroAnim = AlwaysStoppedAnimation<double>(
    0.0,
  );

  // ── Game constants ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const double _maxTiltRadians = 0.26;

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

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  bool _showWinDialog = false;
  int _deliveredCount = 0;
  bool _tipping = false;
  bool _showEquation = true;

  late List<List<int>> _roundPool;
  late int _addendA;
  late int _addendB;
  late int _target;

  /// Package chips available in the tray this round.
  late List<int> _packagePool;

  /// Parallel to _packagePool — true once that chip has been loaded on the sled.
  late List<bool> _packageUsed;

  /// Indices (into _packagePool) currently sitting on the sled, in drop order.
  late List<int> _sledLoad;

  bool _resolvingRound =
      false; // locks input while delivered/overloaded plays out

  // ── Audio ────────────────────────────────────────────────────────────────
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _deliveredPulseCtrl;
  late Animation<double> _deliveredPulse;
  late AnimationController _houseStampCtrl;
  late AnimationController _tipCtrl;
  late Animation<double> _tipShake;
  late AnimationController _sledTravelCtrl;
  late Animation<double> _sledTravel;

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

    _deliveredPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _deliveredPulse =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _deliveredPulseCtrl, curve: Curves.easeOut),
        );

    _houseStampCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1.0,
    );

    _tipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tipShake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.12), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.10), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.10, end: -0.08), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _tipCtrl, curve: Curves.easeOut));

    _sledTravelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _sledTravel = CurvedAnimation(
      parent: _sledTravelCtrl,
      curve: Curves.easeInOut,
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

    _packagePool = _buildPackagePool(_addendA, _addendB, _target);
    _packageUsed = List.filled(_packagePool.length, false);
    _sledLoad = [];
    _resolvingRound = false;
    _showEquation = true;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    setState(() {});
  }

  List<int> _buildPackagePool(int addendA, int addendB, int target) {
    final rng = Random();
    final pool = <int>[addendA, addendB, target];
    while (pool.length < 6) {
      pool.add(rng.nextInt(5) + 1);
    }
    pool.shuffle(rng);
    return pool;
  }

  int get _currentTotal =>
      _sledLoad.fold(0, (sum, idx) => sum + _packagePool[idx]);

  double get _tiltAngle {
    if (_target == 0) return 0;
    final diff = (_currentTotal - _target) / _target;
    return diff.clamp(-1.0, 1.0) * _maxTiltRadians;
  }

  // ── Drag handlers ────────────────────────────────────────────────────────
  void _onPackageDropped(int poolIndex) async {
    if (_resolvingRound || _packageUsed[poolIndex]) return;

    setState(() {
      _packageUsed[poolIndex] = true;
      _sledLoad.add(poolIndex);
    });

    HapticFeedback.selectionClick();
    await _playSfxAndWait(_audioPackageAddRemove);

    final total = _currentTotal;
    if (total == _target) {
      _onDelivered();
    } else if (total > _target) {
      _onTooMany();
    }
  }

  void _onPackageRemoved(int poolIndex) {
    if (_resolvingRound) return;
    setState(() {
      _packageUsed[poolIndex] = false;
      _sledLoad.remove(poolIndex);
    });
    _playVoice(_audioPackageAddRemove);
  }

  Future<void> _onDelivered() async {
    setState(() => _resolvingRound = true);
    HapticFeedback.mediumImpact();
    _deliveredPulseCtrl.forward(from: 0);

    HapticFeedback.selectionClick();
    _playSfx(_audioPackageAddRemove);

    showDomaReaction(DomaState.correct);
    if (!mounted) return;

    // slide the loaded sled over to the house to deliver
    await _sledTravelCtrl.forward(from: 0);
    if (!mounted) return;

    setState(() => _deliveredCount++);
    _houseStampCtrl.forward(from: 0);
    _sledTravelCtrl.reset(); // snap back to start for the next round

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (_currentRound + 1 >= _totalRounds) {
      setState(() {
        _sledLoad = [];
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

  Future<void> _onTooMany() async {
    setState(() {
      _resolvingRound = true;
      _tipping = true;
    });
    HapticFeedback.heavyImpact();
    _tipCtrl.forward(from: 0);
    showDomaReaction(DomaState.wrong);
    if (!mounted) return;
    setState(() {
      _packageUsed = List.filled(_packagePool.length, false);
      _sledLoad = [];
      _resolvingRound = false;
      _tipping = false;
    });
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
      await completer.future.timeout(const Duration(seconds: 18));
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
    _deliveredPulseCtrl.dispose();
    _houseStampCtrl.dispose();
    _tipCtrl.dispose();
    _sledTravelCtrl.dispose();
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
                      _miniPackageAsset,
                      height: screenH * 0.4,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                      const Text('📋', style: TextStyle(fontSize: 70)),
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
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: _buildPackageTray(h),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: ScaleTransition(
                          scale: _sceneEnter,
                          child: _buildDeliveryScene(w, h),
                        ),
                      ),
                      Expanded(flex: 3, child: _buildDestinationHouse(h)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: _buildRoundIndicator(),
                ),
              ],
            ),
            _buildTravelingSled(w, h),
          ],
        );
      },
    );
  }

  Widget _buildInstructionBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
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
            'Add up, then load the sled to match!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],            ),
          ),
        ),
      ),
    );
  }

  // ── Delivery scene: signboard + sled ─────────────────────────────────────
  Widget _buildDeliveryScene(double w, double h) {
    if (!_showEquation) return const SizedBox.shrink();

    final equationSize = (h * 0.35);
    final delivered = _currentTotal == _target;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: h * 0.02),
        child: ScaleTransition(
          scale: delivered
              ? _deliveredPulse
              : const AlwaysStoppedAnimation(1.0),
          child: _buildEquationDisplay(equationSize),
        ),
      ),
    );
  }

  Widget _buildTravelingSled(double w, double h) {
    final equationSize = h * 0.35;
    final sledWidth = (w / 3) * 0.95;
    final sledHeight = equationSize * 1.3;
    final houseSize = h * 0.75;

    // Lane boundaries, matching the flex:3/3/3 columns in the Row above.
    final sceneLeft = w / 3;
    final sceneCenter = sceneLeft + (w / 3) / 2;
    final houseLeft = (w / 3) * 2;
    final houseCenter = houseLeft + (w / 3) / 2;

    final restLeft = sceneCenter - sledWidth / 2;
    final targetLeft = houseCenter - houseSize / 2 - sledWidth / 2 - 12;
    final travelDistance = targetLeft - restLeft;

    final rowTop = h * 0.5;

    return AnimatedBuilder(
      animation: _sledTravel,
      builder: (_, child) {
        final left = restLeft + _sledTravel.value * travelDistance;
        return Positioned(top: rowTop, left: left, child: child!);
      },
      child: SizedBox(
        width: sledWidth,
        height: sledHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedBuilder(
              animation: _tipping ? _tipShake : _kZeroAnim,
              builder: (_, child) {
                final angle = _tipping ? _tipShake.value : _tiltAngle;
                return Transform.rotate(angle: angle, child: child);
              },
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Image.asset(
                    _sledAsset,
                    width: sledWidth,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 40,
                      width: sledWidth,
                      decoration: BoxDecoration(
                        color: ArcticColorTheme.slateblue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: sledHeight * 0.24,
                    left: sledHeight * 0.16,
                    right: 0,
                    child: _buildSledCargo(equationSize),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Signboard showing the addition problem for this house's order.
  Widget _buildEquationDisplay(double size) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.25,
        vertical: size * 0.05,
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
    );
  }

  /// A cluster of package icons with its count shown underneath.
  Widget _addendGroup(int count, double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 2,
          runSpacing: 2,
          alignment: WrapAlignment.center,
          children: List.generate(count, (_) => _miniPackage(size * 0.24)),
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.2,
            fontWeight: FontWeight.bold,
            color: ArcticColorTheme.cadetblue,
            shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  /// Drop target area on the sled where the player loads packages.
  Widget _buildSledCargo(double size) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
          !_resolvingRound && !_packageUsed[details.data],
      onAcceptWithDetails: (details) => _onPackageDropped(details.data),
      builder: (context, candidateData, rejectedData) {
        return SizedBox(
          width: size * 1.4,
          height: size * 0.8,
          child: _sledLoad.isEmpty
              ? SizedBox(width: size * 1.4, height: size * 0.8)
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: _sledLoad.map((idx) {
                    return GestureDetector(
                      onTap: () => _onPackageRemoved(idx),
                      child: _packageChipVisual(_packagePool[idx], size * 0.44),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  /// Maps a chip's numeric value (1-5) to its package_N.png artwork.
  String _packageAssetForValue(int value) {
    final clamped = value.clamp(1, 5);
    return '$_packageAssetBase$clamped.png';
  }

  Widget _miniPackage(double size) {
    return Image.asset(
      _miniPackageAsset,
      width: size,
      height: size,
      errorBuilder: (_, __, ___) =>
          Text('📦', style: TextStyle(fontSize: size)),
    );
  }

  /// The draggable/loadable package chip — uses the matching package_N.png
  /// artwork (which already visually encodes the value) plus a small number
  /// badge so the count stays easy to read at a glance.
  Widget _packageChipVisual(int value, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              _packageAssetForValue(value),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF4F4),
                      Color(0xFFFFC2C2),
                      Color(0xFFE84855),
                    ],
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

  // ── Package tray ─────────────────────────────────────────────────────────
  Widget _buildPackageTray(double h) {
    final chipSize = (h * 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: List.generate(_packagePool.length, (i) {
          final used = _packageUsed[i];
          final chip = _packageChipVisual(_packagePool[i], chipSize);

          if (used) {
            return Opacity(opacity: 0.25, child: chip);
          }

          return Draggable<int>(
            data: i,
            feedback: Material(
              color: Colors.transparent,
              child: _packageChipVisual(_packagePool[i], chipSize * 1.15),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: chip),
            child: chip,
          );
        }),
      ),
    );
  }

  // ── Delivered houses board ───────────────────────────────────────────────
  Widget _buildDestinationHouse(double h) {
    final houseSize = (h * 0.70);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: CurvedAnimation(
            parent: _houseStampCtrl,
            curve: Curves.elasticOut,
          ),
          child: Image.asset(
            _houseAsset,
            height: houseSize,
            errorBuilder: (_, __, ___) =>
                Text('🏠', style: TextStyle(fontSize: houseSize * 0.7)),
          ),
        ),
      ],
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _deliveredCount;
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
          _deliveredCount = 0;
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
