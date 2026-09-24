import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/arctic_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'game_addition_package_delivery.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class AdditionRescueBridgeGame extends StatefulWidget {
  final int level;

  const AdditionRescueBridgeGame({super.key, required this.level});

  @override
  State<AdditionRescueBridgeGame> createState() =>
      _AdditionRescueBridgeGameState();
}

class _AdditionRescueBridgeGameState extends State<AdditionRescueBridgeGame>
    with TickerProviderStateMixin, DomaReactionMixin<AdditionRescueBridgeGame>, GameLoadingMixin<AdditionRescueBridgeGame>, AiCameraMixin<AdditionRescueBridgeGame> {
  @override
  AudioPlayer get domaPlayer => _voicePlayer;

  // ── Asset paths (swap to match your project) ────────────────────────────
  static const String _iceAsset = 'assets/images/objects/arctic/ice.png';
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

  static const List<List<double>> _pupScatter = [
    [0.18, 0.08, 1.10],
    [0.65, 0.12, 0.85],
    [0.38, 0.38, 1.00],
    [0.15, 0.68, 0.80],
    [0.62, 0.62, 1.05],
  ];

  // ── Tracking Variables ─────────────────────────────────────────────────────
  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _loadingScreenElapsed = false;
  Timer? _minLoadTimer;

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

  bool _resolvingRound =
      false; // locks input while balanced/overloaded plays out

  // ── Audio ────────────────────────────────────────────────────────────────
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _balancePulseCtrl;
  late Animation<double> _balancePulse;
  late AnimationController _campPupCtrl;

  final List<GlobalKey> _pupKeys = List.generate(
    _totalRounds,
    (_) => GlobalKey(),
  );
  final GlobalKey _campAnchorKey = GlobalKey();
  final GlobalKey _crossingLayerKey = GlobalKey();
  final GlobalKey _beamKey = GlobalKey();
  int? _crossingIndex;
  Offset? _crossingStart;
  Offset? _crossingMid;
  Offset? _crossingEnd;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _roundPool = [..._factPool]..shuffle();
    _initAnimations();

    // --- START AI AND TRACKERS ---
    startAiCamera();
    _tapTracker.startSession();

    _minLoadTimer = Timer(minLoadTime, () {
      if (mounted) setState(() => _loadingScreenElapsed = true);
    });

    if (widget.level == 1) {
      onFirstFaceDetected = () {
        finishLoading(_startIntroFlow);
      };
      if (isFaceDetected) {
        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;
      }
    } else {
      finishLoading(_startIntroFlow);
    }

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) {
        setState(() => _hideLightingCard = false);
      }
    };
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
    while (pool.length < 3) {
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
    _tapTracker.recordCorrectTap();

    setState(() => _resolvingRound = true);
    HapticFeedback.mediumImpact();
    _balancePulseCtrl.forward(from: 0);
    showDomaReaction(DomaState.correct);
    if (!mounted) return;

    final crossingIndex = _rescuedCount;

    Offset? start;
    Offset? mid;
    Offset? end;
    final layerBox =
        _crossingLayerKey.currentContext?.findRenderObject() as RenderBox?;
    final pupBox =
        _pupKeys[crossingIndex].currentContext?.findRenderObject()
            as RenderBox?;
    final campBox =
        _campAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    final beamBox = _beamKey.currentContext?.findRenderObject() as RenderBox?;
    if (layerBox != null && pupBox != null && campBox != null) {
      final pupCenter = pupBox.localToGlobal(
        Offset(pupBox.size.width / 2, pupBox.size.height / 2),
      );
      final campCenter = campBox.localToGlobal(
        Offset(campBox.size.width / 2, campBox.size.height / 2),
      );
      start = layerBox.globalToLocal(pupCenter);
      end = layerBox.globalToLocal(campCenter);

      if (beamBox != null) {
        final beamCenter = beamBox.localToGlobal(
          Offset(beamBox.size.width / 2, beamBox.size.height / 2),
        );
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

      // --- AI STOP & DATABASE SAVE ---
      List<String> finalEmotions = stopAiCamera();

      try {
        ArcticDatabaseService.saveGameData(
          gameId: 'arctic_numberland_${widget.level}',
          mistakes: _tapTracker.mistakeCount,
          emotions: finalEmotions,
        );
      } catch (e) {
        debugPrint("Database Error saving Arctic metrics: $e");
      }

      ArcticProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;
      setState(() => _showWinDialog = true);
    } else {
      setState(() => _currentRound++);
      _setupRound();
    }
  }

  Future<void> _onTooHeavy() async {
    _tapTracker.recordMistake();

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
    disposeAiCamera();
    _minLoadTimer?.cancel();
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
    final gateNeedsLightingPrompt = widget.level == 1 && !isFaceDetected;

    final reactiveNeedsLightingPrompt =
        hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard;

    Widget gateLightingCard() => LightingPromptCard(
      onClose: () {
        setState(() => isFaceDetected = true);
        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;
      },
    );

    Widget reactiveLightingCard() => LightingPromptCard(
      onClose: () => setState(() => _hideLightingCard = true),
    );

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
          child: _introPlaying ? _buildIntroLayer() : _buildGameContent(),
        ),
        // X button
        Positioned(
          top: 25,
          left: 25,
          child: ArcticXButton(),
        ),

        // Level badge
        Positioned(
          top: 25,
          right: 25,
          child: ArcticLevelBadge(level: widget.level),
        ),
        if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
      ],
    );

    final contentWithOverlay = reactiveNeedsLightingPrompt
        ? Stack(
            children: [
              Positioned.fill(child: gameContent),
              Positioned.fill(child: reactiveLightingCard()),
            ],
          )
        : gameContent;

    final loadingSlot = (_loadingScreenElapsed && gateNeedsLightingPrompt)
        ? gateLightingCard()
        : LoadingScreen.arctic();

    return Listener(
      // <-- ADDED LISTENER FOR GENERIC TAPS
      onPointerDown: (_) => _tapTracker.recordGenericTap(),
      child: Scaffold(
        body: buildWithLoading(
          loadingScreen: loadingSlot,
          gameBuilder: () => gateNeedsLightingPrompt
              ? Stack(
                  children: [
                    Positioned.fill(child: gameContent),
                    Positioned.fill(child: gateLightingCard()),
                  ],
                )
              : contentWithOverlay,
        ),
      ),
    );
  }

  // ── Intro / story setup ──────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // Doma
        Positioned(
          left: screenW * 0.08,
          top: screenH * 0.18,
          child: AnimatedBuilder(
            animation: _domaFloatCtrl,
            builder: (_, child) {
              final floatY = Tween<double>(
                begin: -6,
                end: 6,
              ).evaluate(
                CurvedAnimation(
                  parent: _domaFloatCtrl,
                  curve: Curves.easeInOut,
                ),
              );

              return Transform.translate(
                offset: Offset(0, floatY),
                child: child,
              );
            },
            child: Image.asset(
              _characterImage,
              height: screenH * 0.65,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                '🐧',
                style: TextStyle(fontSize: 70),
              ),
            ),
          ),
        ),

        // Baby fox
        Positioned(
          right: screenW * 0.10,
          top: screenH * 0.28,
          child: Image.asset(
            _babyFoxAsset,
            height: screenH * 0.38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              '🦊',
              style: TextStyle(fontSize: 70),
            ),
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
                // MAIN GAME AREA
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildIceFloe(h),
                      ),

                      Expanded(
                        flex: 5,
                        child: ScaleTransition(
                          scale: _sceneEnter,
                          child: LayoutBuilder(
                            builder: (context, sceneConstraints) {
                              return _buildScaleScene(
                                sceneConstraints.maxWidth,
                                h,
                              );
                            },
                          ),
                        ),
                      ),

                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: h * 0.08,
                              right: 20,
                            ),
                            child: _buildSafeCamp(h),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(
                    left: 60,
                    right: 60,
                  ),
                  child: _buildWeightTray(h),
                ),

                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 15,
                  ),
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

  Widget _buildPupCrossing(double w, double h) {
    if (!_pupCrossing) return const SizedBox.shrink();

    final pupSize = (h * 0.18);
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
        errorBuilder: (_, __, ___) =>
            Text('🦭', style: TextStyle(fontSize: pupSize * 0.7)),
      ),
    );
  }

  // ── Ice floe with waiting pups ───────────────────────────────────────────
  Widget _buildIceFloe(double h) {
    final baseSize = h * 0.18;

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = constraints.maxWidth;
        final areaH = constraints.maxHeight;

        return Padding(
          padding: const EdgeInsets.only(
            top: 80,
            left: 30,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(_totalRounds, (i) {
              final hidden =
                  i < _rescuedCount || i == _crossingIndex;

              final scatter =
              _pupScatter[i % _pupScatter.length];

              final pupSize = baseSize * scatter[2];

              final left =
                  (areaW * scatter[0]) - (pupSize / 2);

              final top =
                  (areaH * scatter[1]) - (pupSize / 2);

              return Positioned(
                left: left,
                top: top,
                child: AnimatedOpacity(
                  key: _pupKeys[i],
                  opacity: hidden ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Image.asset(
                    _babyFoxAsset,
                    height: pupSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      '🦊',
                      style: TextStyle(
                        fontSize: pupSize * 0.7,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ── Balance scale scene ──────────────────────────────────────────────────
  Widget _buildScaleScene(double w, double h) {
    if (!_showEquation) return const SizedBox.shrink();

    final rawPanSize = (h * 0.36);
    final maxPanSizeForWidth = w / 4.4;
    final panSize = rawPanSize < maxPanSizeForWidth ? rawPanSize : maxPanSizeForWidth;
    const double beamLengthFactor = 1.3;
    final beamWidth = ((w - panSize) * beamLengthFactor).clamp(150.0, w - 8);
    final balanced = _currentTotal == _target;

    return Align(
      alignment: Alignment.bottomCenter,
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
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
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
                              Positioned(
                                left: 0,
                                top: -panSize * 0.35,
                                child: _buildLeftPan(panSize),
                              ),
                              Positioned(
                                right: 0,
                                top: -panSize * 0.35,
                                child: _buildRightPan(panSize),
                              ),
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

  Widget _buildLeftPan(double size) {
    return Container(
      constraints: BoxConstraints(
        minWidth: size * 1.6,
        minHeight: size * 0.95,
        maxWidth: size * 2.8,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.10,
        vertical: size * 0.10,
      ),
      decoration: BoxDecoration(
        color: ArcticColorTheme.cotton.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.001),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _addendGroup(_addendA, size),

          SizedBox(width: size * 0.12),

          Text(
            '+',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: size * 0.28,
              fontWeight: FontWeight.bold,
              color: ArcticColorTheme.cadetblue,
              shadows: const [
                Shadow(
                  color: Colors.white,
                  blurRadius: 4,
                ),
              ],
            ),
          ),

          SizedBox(width: size * 0.12),

          _addendGroup(_addendB, size),
        ],
      ),
    );
  }

  Widget _addendGroup(int count, double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: size * 0.04,
          runSpacing: size * 0.04,
          alignment: WrapAlignment.center,
          children: List.generate(
            count,
                (_) => _miniCrystal(
              size * 0.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPan(double size) {
    final panWidth = size * 1.8;
    final panHeight = size * 0.95;

    return SizedBox(
      width: panWidth,
      height: panHeight,
      child: DragTarget<int>(
        hitTestBehavior: HitTestBehavior.opaque,

        onWillAcceptWithDetails: (details) =>
        !_resolvingRound &&
            !_weightUsed[details.data],

        onAcceptWithDetails: (details) =>
            _onWeightDropped(details.data),

        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),

            width: panWidth,
            height: panHeight,

            alignment: Alignment.center,

            decoration: BoxDecoration(
              color: ArcticColorTheme.cotton.withValues(
                alpha: isHovering ? 0.95 : 0.8,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ArcticColorTheme.slateblue.withValues(
                  alpha: isHovering ? 0.7 : 0.35,
                ),
                width: isHovering ? 3 : 2,
              ),
            ),

            child: _panLoad.isEmpty
                ? const SizedBox.shrink()
                : SizedBox.expand(
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, size * 0.07),
                  child: Wrap(
                    spacing: size * 0.08,
                    runSpacing: size * 0.08,
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: _panLoad.map((idx) {
                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _onWeightRemoved(idx),
                        child: _panWeightVisual(
                          _weightPool[idx],
                          size * 0.92,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _panWeightVisual(int value, double size) {
    final crystalSize = size * 0.38;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ice group
        Wrap(
          spacing: size * 0.04,
          runSpacing: size * 0.04,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: List.generate(
            value,
                (_) => Image.asset(
              _iceAsset,
              width: crystalSize,
              height: crystalSize,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Number badge
        Positioned(
          right: -size * 0.08,
          top: -size * 0.08,
          child: Container(
            width: size * 0.32,
            height: size * 0.32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ArcticColorTheme.pictonblue,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniCrystal(double size) {
    return Image.asset(
      _iceAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        '🧊',
        style: TextStyle(fontSize: size),
      ),
    );
  }

  Widget _weightChipVisual(int value, double size) {
    final crystalSize = value <= 2
        ? size * 0.48
        : size * 0.38;

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
              children: List.generate(
                value,
                    (_) => Image.asset(
                  _iceAsset,
                  width: crystalSize,
                  height: crystalSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    '🧊',
                    style: TextStyle(
                      fontSize: crystalSize,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Number indicator
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ArcticColorTheme.pictonblue,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ArcticColorTheme.pictonblue
                        .withValues(alpha: 0.4),
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
                  fontSize: size * 0.20,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemGap = 8.0;

        final availableWidth = constraints.maxWidth - (itemGap * (_weightPool.length - 1));
        final maxChipFromWidth = availableWidth / (_weightPool.length * 1.45);
        final chipSize = min(h * 0.25, maxChipFromWidth,);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_weightPool.length, (i) {
            final used = _weightUsed[i];

            final chip = _weightChipVisual(
              _weightPool[i],
              chipSize,
            );

            final choice = used
                ? Opacity(
              opacity: 0.25,
              child: chip,
            )
                : Draggable<int>(
              data: i,
              feedback: Material(
                color: Colors.transparent,
                child: _weightChipVisual(
                  _weightPool[i],
                  chipSize * 1.10,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: chip,
              ),
              child: chip,
            );

            return Padding(
              padding: EdgeInsets.only(
                right: i < _weightPool.length - 1
                    ? itemGap
                    : 0,
              ),
              child: choice,
            );
          }),
        );
      },
    );
  }

  // ── Safe camp (rescued pups) ─────────────────────────────────────────────
  Widget _buildSafeCamp(double h) {
    final pupSize = h * 0.14;

    return SizedBox(
      key: _campAnchorKey,
      width: h * 0.50,
      height: h * 0.34,
      child: Center(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: List.generate(_rescuedCount, (i) {
            final isNewest = i == _rescuedCount - 1;

            return ScaleTransition(
              scale: isNewest
                  ? CurvedAnimation(
                parent: _campPupCtrl,
                curve: Curves.elasticOut,
              )
                  : const AlwaysStoppedAnimation(1.0),
              child: Image.asset(
                _babyFoxAsset,
                height: pupSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  '🦊',
                  style: TextStyle(
                    fontSize: pupSize * 0.7,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AdditionPackageDeliveryGame(level: widget.level + 1),
          ),
        );
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
