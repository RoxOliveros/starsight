import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'game_match_snowglobe.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class BuildIglooScreen extends StatefulWidget {
  final int level;

  const BuildIglooScreen({super.key, required this.level});

  @override
  State<BuildIglooScreen> createState() => _BuildIglooScreenState();
}

class _BuildIglooScreenState extends State<BuildIglooScreen>
    with TickerProviderStateMixin, DomaReactionMixin, GameLoadingMixin, AiCameraMixin {
  @override
  AudioPlayer get domaPlayer => _player;

  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const int _maxNumber = 5;
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _iceAsset = 'assets/images/objects/arctic/ice.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/building_igloo_intro.wav';
  static const String _audioInstruction = 'assets/audio/arctic_numberland/building_igloo_instruction.wav';
  static const String _audioBuild = 'assets/audio/sound_effects/build.wav';

  // ── Tracking Variables ─────────────────────────────────────────────────────
  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _loadingScreenElapsed = false;
  Timer? _minLoadTimer;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  bool _canInteract = false;
  bool _instructionPlayed = false;
  int _currentRound = 0;

  late int _targetCount; 
  late List<int?> _slotContents;
  late List<bool> _slotHighlighted; 
  late List<_IceBlockData> _sourceBlocks; 
  late List<bool> _blockPlaced;

  int _placedCount = 0;
  bool _roundComplete = false;
  bool _roundAdvancing = false;
  bool _showWinDialog = false;
  late List<int> _roundPool;

  // Drag state
  int? _draggingBlockIndex;
  Offset _dragPosition = Offset.zero;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _slotsEnterCtrl;
  late Animation<double> _slotsEnter;
  late AnimationController _blocksEnterCtrl;
  late Animation<double> _blocksEnter;
  late AnimationController _correctPulseCtrl;
  late Animation<double> _correctPulse;
  late AnimationController _iglooShakeCtrl;
  late Animation<double> _iglooShake;
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;
  late List<AnimationController> _slotFillCtrls;
  late List<Animation<double>> _slotFillAnims;

  static const List<_SlotLayout> _slotLayouts = [
    _SlotLayout(rowFracX: 0.30, rowFracY: 0.66),
    _SlotLayout(rowFracX: 0.50, rowFracY: 0.66),
    _SlotLayout(rowFracX: 0.70, rowFracY: 0.66),
    _SlotLayout(rowFracX: 0.40, rowFracY: 0.38),
    _SlotLayout(rowFracX: 0.60, rowFracY: 0.38),
  ];

  // ── Global keys for hit-testing slots ─────────────────────────────────────
  final List<GlobalKey> _slotKeys = List.generate(5, (_) => GlobalKey());
  final GlobalKey _iglooAreaKey = GlobalKey();

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _roundPool = List.generate(_maxNumber, (i) => i + 1)..shuffle();
    _initAnimations();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
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

    _slotsEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slotsEnter = CurvedAnimation(
      parent: _slotsEnterCtrl,
      curve: Curves.elasticOut,
    );

    _blocksEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _blocksEnter = CurvedAnimation(
      parent: _blocksEnterCtrl,
      curve: Curves.easeOutBack,
    );

    _correctPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _correctPulse =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.18, end: 0.92), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _correctPulseCtrl, curve: Curves.easeOut),
        );

    _iglooShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _iglooShake =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _iglooShakeCtrl, curve: Curves.easeInOut),
        );

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    _slotFillCtrls = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
    );
    _slotFillAnims = _slotFillCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.elasticOut))
        .toList();
  }

  // ── Flow ───────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    await _playAudio(_audioIntro);

    if (!mounted) return;

    setState(() {
      _introPlaying = false;
      _canInteract = false;
    });

    _setupRound();

    await Future.delayed(
      const Duration(milliseconds: 400),
    );

    if (!_instructionPlayed) {
      await _playAudio(_audioInstruction);

      if (!mounted) return;

      setState(() {
        _instructionPlayed = true;
        _canInteract = true;
      });
    }
  }

  void _setupRound() {
    if (_roundPool.isEmpty) {
      _roundPool =
      List.generate(_maxNumber, (i) => i + 1)
        ..shuffle();
    }

    _targetCount = _roundPool.removeLast();

    _slotContents =
        List.filled(_targetCount, null);

    _slotHighlighted =
        List.filled(_targetCount, false);

    _placedCount = 0;
    _roundComplete = false;
    _roundAdvancing = false;
    _draggingBlockIndex = null;

    for (final c in _slotFillCtrls) {
      c.reset();
    }

    final rng = Random();

    _sourceBlocks = List.generate(6, (i) {
      return _IceBlockData(
        id: i,
        pileOffsetX:
        (rng.nextDouble() - 0.5) * 1.0,
        pileOffsetY:
        (rng.nextDouble() - 0.5) * 0.8,
        rotation:
        (rng.nextDouble() - 0.5) * 0.4,
      );
    });

    _blockPlaced = List.filled(6, false);

    _slotsEnterCtrl.forward(from: 0);
    _blocksEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (_instructionPlayed) {
      _canInteract = true;
    }
  }

  // ── Drag Logic ─────────────────────────────────────────────────────────────
  void _onDragStart(
      int blockIndex,
      Offset globalPos,
      ) {
    if (!_canInteract ||
        _blockPlaced[blockIndex] ||
        _roundComplete ||
        _roundAdvancing) {
      return;
    }

    setState(() {
      _draggingBlockIndex = blockIndex;
      _dragPosition = globalPos;
    });
  }

  void _onDragUpdate(Offset globalPos) {
    if (!_canInteract ||
        _draggingBlockIndex == null) {
      return;
    }

    setState(() {
      _dragPosition = globalPos;

      for (int i = 0;
      i < _targetCount;
      i++) {
        _slotHighlighted[i] =
            _isOverSlot(i, globalPos) &&
                _slotContents[i] == null;
      }
    });
  }

  Future<void> _onDragEnd(Offset globalPos) async {
    // No active block being dragged
    if (_draggingBlockIndex == null) return;

    // Do not allow another action while audio/round is processing
    if (!_canInteract || _roundAdvancing) {
      return;
    }

    int? hitSlot;

    // Check which slot the block was dropped on
    for (int i = 0; i < _targetCount; i++) {
      if (_isOverSlot(i, globalPos) &&
          _slotContents[i] == null) {
        hitSlot = i;
        break;
      }
    }

    // ─────────────────────────────────────────
    // VALID DROP
    // ─────────────────────────────────────────
    if (hitSlot != null) {
      _canInteract = false;
      _tapTracker.recordCorrectTap();

      final blockId = _draggingBlockIndex!;

      setState(() {
        _slotContents[hitSlot!] = blockId;
        _blockPlaced[blockId] = true;
        _slotHighlighted[hitSlot] = false;
        _draggingBlockIndex = null;

        _placedCount++;
      });

      _slotFillCtrls[hitSlot].forward(from: 0);

      await _playAudio('assets/audio/arctic_numberland/$_placedCount.wav',);
      if (!mounted) return;

      if (_placedCount == _targetCount) {
        _roundAdvancing = true;

        await Future.delayed(const Duration(milliseconds: 300),);
        if (!mounted) return;

        await _playAudio(_audioBuild);
        if (!mounted) return;

        setState(() {
          _roundComplete = true;
        });

        _correctPulseCtrl.forward(from: 0);

        showDomaReaction(DomaState.correct,);
        await Future.delayed(const Duration(milliseconds: 700),);
        if (!mounted) return;

        if (_currentRound + 1 >= _totalRounds) {
          final List<String> finalEmotions = stopAiCamera();

          try {
            ArcticDatabaseService.saveGameData(
              gameId: 'arctic_numberland_${widget.level}',
              mistakes: _tapTracker.mistakeCount,
              emotions: finalEmotions,
            );
          } catch (e) {
            debugPrint(
              'Database Error saving Arctic metrics: $e',
            );
          }

          ArcticProgressService.instance.markLevelComplete(widget.level);
          if (!mounted) return;

          setState(() {
            _showWinDialog = true;
          });
        } else {
          setState(() {
            _currentRound++;
          });

          _setupRound();
        }
      } else {
        if (!mounted) return;

        setState(() {
          _canInteract = true;
        });
      }
    } else {
      _tapTracker.recordMistake();

      if (!mounted) return;

      setState(() {
        _draggingBlockIndex = null;

        for (int i = 0; i < _targetCount; i++) {
          _slotHighlighted[i] = false;
        }
        _canInteract = true;
      });
    }
  }

  bool _isOverSlot(int slotIndex, Offset globalPos) {
    final key = _slotKeys[slotIndex];
    final ctx = key.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    return rect.inflate(18).contains(globalPos);
  }

  // ── Audio ──────────────────────────────────────────────────────────────────
  Future<void> _playAudio(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  @override
  void dispose() {
    disposeAiCamera(); 
    _minLoadTimer?.cancel();
    _player.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _slotsEnterCtrl.dispose();
    _blocksEnterCtrl.dispose();
    _correctPulseCtrl.dispose();
    _iglooShakeCtrl.dispose();
    _numberDanceCtrl.dispose();
    for (final c in _slotFillCtrls) {
      c.dispose();
    }
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        _introPlaying ? _buildIntroLayer() : _buildGameContent(),

        if (!_introPlaying) buildDoma(context),
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

  // ── Intro ──────────────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    return Stack(
      children: [
        Positioned(top: 25, left: 25, child: ArcticXButton()),
        Positioned(
          top: 25,
          right: 25,
          child: ArcticLevelBadge(level: widget.level),
        ),
        Positioned.fill(
          top: 48,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: Image.asset(
                    _characterImage,
                    height: MediaQuery.of(context).size.height * 0.62,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🐧', style: TextStyle(fontSize: 60)),
                  ),
                ),
              ),
              // Ice blocks 0–5 dancing
              Expanded(
                flex: 6,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _numberDanceCtrl,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(5, (i) {
                          final num = i + 1;
                          final angle =
                              _numberDance.value * ((i % 2 == 0) ? 1 : -1);
                          final blockH =
                              MediaQuery.of(context).size.height * 0.12 +
                              (i * 6.0);
                          return Transform.rotate(
                            angle: angle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    _iceAsset,
                                    height: blockH,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Text(
                                      '🧊',
                                      style: TextStyle(fontSize: 32),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ArcticColorTheme.cadetblue,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$num',
                                      style: TextStyle(
                                        fontFamily: ArcticAppTextStyles.fredoka,
                                        fontSize: blockH * 0.28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Game ───────────────────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return Stack(
          children: [
            Column(
              children: [
                // ── HEADER ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 25,
                  ),
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

                // ── SCENE ───────────────────────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 120),
                      Expanded(flex: 4, child: _buildBlockPileArea(h, w)),

                      Expanded(
                        flex: 6,
                        child: ScaleTransition(
                          scale: _slotsEnter,
                          child: _buildIglooArea(h),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── PROGRESS ────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildRoundIndicator(),
                ),
              ],
            ),

            if (_draggingBlockIndex != null)
              Positioned(
                left: _dragPosition.dx - 36,
                top: _dragPosition.dy - 36,
                child: IgnorePointer(
                  child: _buildIceBlockWidget(72, opacity: 0.9, elevated: true),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Block Pile (left side) ─────────────────────────────────────────────────
  Widget _buildBlockPileArea(double h, double w) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = constraints.maxWidth;
        final areaH = constraints.maxHeight;
        final pileX = areaW * 0.55;
        final pileY = areaH * 0.52;
        final blockSize = (areaH * 0.18).clamp(44.0, 78.0);

        return Stack(
          children: [
            ...List.generate(6, (i) {
              if (_blockPlaced[i]) return const SizedBox.shrink();

              final block = _sourceBlocks[i];
              final bx = pileX + block.pileOffsetX * blockSize * 3;
              final by = pileY + block.pileOffsetY * blockSize * 3;

              return Positioned(
                left: bx - blockSize / 2,
                top: by - blockSize / 2,
                child: ScaleTransition(
                  scale: _blocksEnter,
                  child: GestureDetector(
                    onPanStart: (d) => _onDragStart(i, d.globalPosition),
                    onPanUpdate: (d) => _onDragUpdate(d.globalPosition),
                    onPanEnd: (d) => _onDragEnd(d.globalPosition),
                    child: Transform.rotate(
                      angle: block.rotation,
                      child: _buildIceBlockWidget(
                        blockSize,
                        isDragging: _draggingBlockIndex == i,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ── Ice block widget ───────────────────────────────────────────────────────
  Widget _buildIceBlockWidget(
    double size, {
    double opacity = 1.0,
    bool elevated = false,
    bool isDragging = false,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isDragging ? 0.3 : opacity,
      child: Container(
        width: size + 3,
        height: size + 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            _iceAsset,
            fit: BoxFit.fitWidth,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFADE8F4), const Color(0xFF48CAE4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('🧊', style: TextStyle(fontSize: size * 0.55)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Igloo Area (right side) ────────────────────────────────────────────────
  Widget _buildIglooArea(double h) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = constraints.maxWidth;
        final areaH = constraints.maxHeight;

        return AnimatedBuilder(
          animation: _iglooShakeCtrl,
          builder: (_, child) => Transform.translate(
            offset: Offset(_iglooShake.value, 0),
            child: child,
          ),
          child: ScaleTransition(
            scale: _roundComplete
                ? _correctPulse
                : const AlwaysStoppedAnimation(1.0),
            child: Stack(
              key: _iglooAreaKey,
              children: [
                Positioned.fill(child: _buildIglooOutline(areaW, areaH)),

                ...List.generate(_targetCount, (i) {
                  final layout = _slotLayouts[i];
                  final slotSize = (areaH * 0.22).clamp(52.0, 90.0);
                  final left = areaW * layout.rowFracX - slotSize / 2;
                  final top = areaH * layout.rowFracY - slotSize / 2;

                  final isFilled = _slotContents[i] != null;
                  final isHighlighted = _slotHighlighted[i];

                  return Positioned(
                    left: left,
                    top: top,
                    child: SizedBox(
                      key: _slotKeys[i],
                      width: slotSize,
                      height: slotSize,
                      child: ScaleTransition(
                        scale: isFilled
                            ? _slotFillAnims[i]
                            : const AlwaysStoppedAnimation(1.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isFilled
                                ? Colors.transparent
                                : Colors.blue.withValues(alpha: 0.85),

                            borderRadius: BorderRadius.circular(15),

                            border: Border.all(
                              color: isFilled
                                  ? Colors.transparent
                                  : Colors.white,

                              width: 2.5,
                            ),
                          ),
                          child: _roundComplete
                              ? const SizedBox.shrink()
                              : isFilled
                              ? _buildIceBlockWidget(slotSize)
                              : Center(
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.white.withValues(
                                      alpha: isHighlighted ? 0.9 : 0.4,
                                    ),
                                    size: slotSize * 0.38,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Igloo Outline (custom painted) ─────────────────────────────────────────
  Widget _buildIglooOutline(double w, double h) {
    final bool built = _roundComplete;

    return OverflowBox(
      maxWidth: w * 1.4,
      maxHeight: h * 1.4,
      child: Image.asset(
        built
            ? 'assets/images/objects/arctic/igloo.png'
            : 'assets/images/objects/arctic/broken_igloo.png',
        fit: BoxFit.contain,
        width: w * 1.4,
        height: h * 1.4,
        errorBuilder: (_, __, ___) => const SizedBox(),
      ),
    );
  }

  // ── Progress ───────────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _currentRound;
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

  // ── Win Overlay ────────────────────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                Number1to5MatchSnowglobesScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pop(context, BuildIglooScreen(level: widget.level));
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ── Data Models ────────────────────────────────────────────────────────────────
class _IceBlockData {
  final int id;
  final double pileOffsetX;
  final double pileOffsetY;
  final double rotation;

  const _IceBlockData({
    required this.id,
    required this.pileOffsetX,
    required this.pileOffsetY,
    required this.rotation,
  });
}

class _SlotLayout {
  final double rowFracX;
  final double rowFracY;

  const _SlotLayout({required this.rowFracX, required this.rowFracY});
}
