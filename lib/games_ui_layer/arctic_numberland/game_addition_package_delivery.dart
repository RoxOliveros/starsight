import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/arctic_numberland/game_subtraction_melting_ice_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/arctic_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class AdditionPackageDeliveryGame extends StatefulWidget {
  final int level;

  const AdditionPackageDeliveryGame({super.key, required this.level});

  @override
  State<AdditionPackageDeliveryGame> createState() =>
      _AdditionPackageDeliveryGameState();
}

class _AdditionPackageDeliveryGameState
    extends State<AdditionPackageDeliveryGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<AdditionPackageDeliveryGame>,
        GameLoadingMixin<AdditionPackageDeliveryGame>,
        AiCameraMixin<AdditionPackageDeliveryGame>,
        AppAudioLifecycleMixin<AdditionPackageDeliveryGame>,
        IdleHintMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _domaPlayer= AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _domaPlayer];

  @override
  AudioPlayer get domaPlayer => _domaPlayer;

  // ── Asset paths (swap to match your project) ────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _miniPackageAsset = 'assets/images/objects/arctic/package.png';
  static const String _sledAsset = 'assets/images/objects/arctic/sled.png';
  static const String _houseAsset = 'assets/images/objects/arctic/house.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/package_delivery_intro.wav';
  static const String _audioWin = '$_audioBase/package_delivery_win.wav';

  static final Animation<double> _kZeroAnim = AlwaysStoppedAnimation<double>(
    0.0,
  );

  // ── Game constants ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const double _maxTiltRadians = 0.26;

  static const List<List<int>> _factPool = [
    [1, 1],
    [1, 2],
    [2, 1],
    [1, 3],
    [2, 2],
    [1, 4],
    [2, 3],
    [3, 2],
    [3, 1],
  ];

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

  late List<int> _packagePool;
  late List<bool> _packageUsed;
  late List<int> _sledLoad;

  bool _resolvingRound = false;

  final GameTapTracker _tapTracker = GameTapTracker();
  final GlobalKey _hintChipKey = GlobalKey();
  final GlobalKey _hintSledKey = GlobalKey();

  int get _hintChipIndex => _packageUsed.indexWhere((u) => !u);

  Alignment? _alignmentOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    if (box == null || root == null || !box.hasSize) return null;

    final center = box.localToGlobal(box.size.center(Offset.zero), ancestor: root);
    return Alignment(
      center.dx / root.size.width * 2 - 1,
      center.dy / root.size.height * 2 - 1,
    );
  }

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  Future<void> _saveGameResult() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;

    final finalEmotions = stopAiCamera();
    ArcticDatabaseService.saveGameData(
      gameId: 'arctic_numberland_${widget.level}',
      mistakes: _tapTracker.mistakeCount,
      emotions: finalEmotions,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });
  }

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
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

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    // Lighting card can reappear later if the face is lost again mid-play.
    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

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
    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioIntro);
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

    cancelIdleTimer();
    showHowToPlay = false;
    startIdleTimer();

    setState(() {});
  }

  List<int> _buildPackagePool(int addendA, int addendB, int target) {
    final rng = Random();
    final pool = <int>[addendA, addendB, target];
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
    await GamesSfxPlayer.instance.play(GameSfx.thump);

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
    GamesSfxPlayer.instance.play(GameSfx.thump);
  }

  Future<void> _onDelivered() async {
    cancelIdleTimer();
    _tapTracker.recordCorrectTap();
    setState(() => _resolvingRound = true);
    HapticFeedback.mediumImpact();
    _deliveredPulseCtrl.forward(from: 0);

    HapticFeedback.selectionClick();
    GamesSfxPlayer.instance.play(GameSfx.thump);

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
      await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioWin);
      await _saveGameResult();
      ArcticProgressService.instance.markLevelComplete(widget.level).catchError(
        (e) {
          debugPrint("Database Error marking level complete: $e");
        },
      );
      if (!mounted) return;
      setState(() => _showWinDialog = true);
    } else {
      setState(() => _currentRound++);
      _setupRound();
    }
  }

  Future<void> _onTooMany() async {
    cancelIdleTimer();
    _tapTracker.recordMistake();
    setState(() {
      _resolvingRound = true;
      _tipping = true;
    });
    HapticFeedback.heavyImpact();
    _tipCtrl.forward(from: 0);
    GamesSfxPlayer.instance.play(GameSfx.bubblePop);
    showDomaReaction(DomaState.wrong);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _packageUsed = List.filled(_packagePool.length, false);
      _sledLoad = [];
      _resolvingRound = false;
      _tipping = false;
    });
    startIdleTimer();
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _audioPlayer.dispose();
    _domaPlayer.dispose();
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
    final needsLightingPrompt = hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard;

    return Listener(
      onPointerDown: (_) {
        _tapTracker.recordGenericTap();
        if (!_introPlaying && !_showWinDialog && !_resolvingRound) {
          resetIdleTimer();
        }
      },
      child: Scaffold(
        body: buildWithLoading(
          loadingScreen: LoadingScreen.arctic(),
          gameBuilder: () {
            final gameContent = Stack(
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
                  child: _introPlaying
                      ? _buildIntroLayer()
                      : _buildGameContent(),
                ),
                if (showHowToPlay &&
                    !_introPlaying &&
                    !_showWinDialog &&
                    !_resolvingRound &&
                    !_tipping &&
                    _hintChipIndex != -1)
                  Positioned.fill(child: _buildHowToPlayOverlay()),
                if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
              ],
            );
            return needsLightingPrompt
                ? Stack(
                    children: [
                      Positioned.fill(child: gameContent),
                      Positioned.fill(
                        child: LightingPromptCard(
                          onClose: () {
                            setState(() => _hideLightingCard = true);
                            releaseFaceGate();
                          },
                        ),
                      ),
                    ],
                  )
                : gameContent;
          },
        ),
      ),
    );
  }

  Widget _buildHowToPlayOverlay() {
    final start = _alignmentOf(_hintChipKey);
    final end = _alignmentOf(_hintSledKey);
    if (start == null || end == null) return const SizedBox.shrink();

    return HowToPlayOverlay(
      handAlignment: start,
      handEndAlignment: end,
      handOffset: const Offset(0.16, 0.48),
      onDismiss: resetIdleTimer,
      previewChild: Stack(
        children: [
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: _buildGameContent(preview: true),
          ),
        ],
      ),
    );
  }

  // ── Intro / story setup ──────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(top: 25, left: 25, child: ArcticXButton()),
        Positioned(
          top: 25,
          right: 25,
          child: ArcticLevelBadge(level: widget.level),
        ),
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
  Widget _buildGameContent({bool preview = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ArcticXButton(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ArcticLevelBadge(level: widget.level),
                      ),
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
                          child: _buildPackageTray(h, preview),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: ScaleTransition(
                          scale: _sceneEnter,
                          child: _buildDeliveryScene(w, h, preview),
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
            _buildTravelingSled(w, h, preview),
          ],
        );
      },
    );
  }

  Widget _buildDeliveryScene(double w, double h, bool preview) {
    if (!_showEquation || preview) return const SizedBox.shrink();

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

  Widget _buildTravelingSled(double w, double h, bool preview) {
    final equationSize = h * 0.35;
    final sledWidth = (w / 3) * 0.95;
    final sledHeight = equationSize * 1.3;
    final houseSize = h * 0.75;

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
                final angle = _tipping ? _tipShake.value : (preview ? 0.0 : _tiltAngle);
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
                    bottom: sledHeight * 0.35,
                    left: sledHeight * 0.16,
                    right: 0,
                    child: _buildSledCargo(equationSize, preview),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSledCargo(double size, bool preview) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
      !_resolvingRound && !_packageUsed[details.data],
      onAcceptWithDetails: (details) => _onPackageDropped(details.data),
      builder: (context, candidateData, rejectedData) {
        return SizedBox(
          key: preview ? null : _hintSledKey,
          width: size * 1.4,
          height: size * 0.8,
          child: (_sledLoad.isEmpty || preview)
              ? const SizedBox.shrink()
              : FittedBox(
            // ...unchanged
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _sledLoad.map((idx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => _onPackageRemoved(idx),
                    child: _packageChipVisual(_packagePool[idx], size * 0.70),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
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

  Widget _packageChipVisual(int value, double size, {bool preview = false}) {
    final shown = preview ? 1 : value;
    final iconSize = shown <= 2 ? size * 0.48 : size * 0.38;

    return Container(
      constraints: BoxConstraints(
        minWidth: size,
        maxWidth: size * 1.45,
        minHeight: size * 0.80,
      ),
      padding: EdgeInsets.all(size * 0.06),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Wrap(
              spacing: size * 0.03,
              runSpacing: size * 0.03,
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              children: List.generate(shown, (_) => _miniPackage(iconSize)),
            ),
          ),
          if (!preview)
            Positioned(
              right: -4,
              top: -4,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ArcticColorTheme.pictonblue,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageTray(double h, bool preview) {
    final chipSize = (h * 0.23);
    final hintIndex = _hintChipIndex;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_packagePool.length, (i) {
          final used = !preview && _packageUsed[i];
          final chip = _packageChipVisual(_packagePool[i], chipSize, preview: preview);

          final Widget choice = preview
              ? chip
              : used
              ? Opacity(opacity: 0.25, child: chip)
              : Draggable<int>(
            key: i == hintIndex ? _hintChipKey : null,
            data: i,
            feedback: Material(
              color: Colors.transparent,
              child: _packageChipVisual(_packagePool[i], chipSize * 1.15),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: chip),
            child: chip,
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: i < _packagePool.length - 1 ? 10 : 0,
            ),
            child: choice,
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SubtractionMeltingIceGame(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdditionPackageDeliveryGame(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
