import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'number1to5_match_snowglobe.dart';

class Number1to5FillIglooScreen extends StatefulWidget {
  final int level;

  const Number1to5FillIglooScreen({super.key,required this.level});

  @override
  State<Number1to5FillIglooScreen> createState() =>
      _Number1to5FillIglooScreenState();
}

class _Number1to5FillIglooScreenState extends State<Number1to5FillIglooScreen>
    with TickerProviderStateMixin, DomaReactionMixin {
  @override
  AudioPlayer get domaPlayer => _player;

  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const int _maxNumber = 5;
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _iceAsset = 'assets/images/objects/arctic/ice_1.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/level19/intro.wav';
  static const String _audioBuild = 'assets/audio/arctic_numberland/level19/build.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;

  late int _targetCount; // how many ice blocks to place (0–5)
  late List<int?> _slotContents; // null = empty, int = block id placed
  late List<bool> _slotHighlighted; // slot highlight when dragging over
  late List<_IceBlockData> _sourceBlocks; // blocks in the pile
  late List<bool> _blockPlaced; // which source blocks have been placed

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
  late Animation<double> _instructionBounce;
  late AnimationController _slotsEnterCtrl;
  late Animation<double> _slotsEnter;
  late AnimationController _blocksEnterCtrl;
  late Animation<double> _blocksEnter;
  late AnimationController _correctPulseCtrl;
  late Animation<double> _correctPulse;
  late AnimationController _iglooShakeCtrl;
  late Animation<double> _iglooShake;

  // Intro dance
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  // Slot fill animations (one per slot, max 5)
  late List<AnimationController> _slotFillCtrls;
  late List<Animation<double>> _slotFillAnims;

  // ── Igloo slot layout (relative positions inside igloo widget) ─────────────
  // Slots are arranged like igloo bricks: bottom row then top row
  static const List<_SlotLayout> _slotLayouts = [
    // bottom row
    _SlotLayout(rowFracX: 0.30, rowFracY: 0.66),
    _SlotLayout(rowFracX: 0.50, rowFracY: 0.66),
    _SlotLayout(rowFracX: 0.70, rowFracY: 0.66),

    // top row
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
    _startIntroFlow();
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
    await Future.delayed(const Duration(milliseconds: 300));
    await _playAudio(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _setupRound();
  }

  void _setupRound() {
    if (_roundPool.isEmpty) {
      _roundPool = List.generate(_maxNumber, (i) => i + 1)..shuffle();
    }


    _targetCount = _roundPool.removeLast();

    // Reset slots (always 5 visual slots, only _targetCount are "active")
    _slotContents = List.filled(_targetCount, null);
    _slotHighlighted = List.filled(_targetCount, false);
    _placedCount = 0;
    _roundComplete = false;
    _roundAdvancing = false;
    _draggingBlockIndex = null;

    // Reset slot fill animations
    for (final c in _slotFillCtrls) {
      c.reset();
    }

    // Generate source blocks in a pile (6 blocks always, player places exactly _targetCount)
    final rng = Random();
    _sourceBlocks = List.generate(6, (i) {
      return _IceBlockData(
        id: i,
        pileOffsetX: (rng.nextDouble() - 0.5) * 1.0,
        pileOffsetY: (rng.nextDouble() - 0.5) * 0.8,
        rotation: (rng.nextDouble() - 0.5) * 0.4,
      );
    });
    _blockPlaced = List.filled(6, false);

    _slotsEnterCtrl.forward(from: 0);
    _blocksEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
  }

  // ── Drag Logic ─────────────────────────────────────────────────────────────
  void _onDragStart(int blockIndex, Offset globalPos) {
    if (_blockPlaced[blockIndex] || _roundComplete) return;
    setState(() {
      _draggingBlockIndex = blockIndex;
      _dragPosition = globalPos;
    });
  }

  void _onDragUpdate(Offset globalPos) {
    if (_draggingBlockIndex == null) return;
    setState(() {
      _dragPosition = globalPos;
      // Highlight slots on hover
      for (int i = 0; i < _targetCount; i++) {
        _slotHighlighted[i] =
            _isOverSlot(i, globalPos) && _slotContents[i] == null;
      }
    });
  }

  Future<void> _onDragEnd(Offset globalPos) async {
    if (_draggingBlockIndex == null) return;

    int? hitSlot;
    for (int i = 0; i < _targetCount; i++) {
      if (_isOverSlot(i, globalPos) && _slotContents[i] == null) {
        hitSlot = i;
        break;
      }
    }

    if (hitSlot != null) {
      if (_roundAdvancing) return;

      final blockId = _draggingBlockIndex!;
      setState(() {
        _slotContents[hitSlot!] = blockId;
        _blockPlaced[blockId] = true;
        _slotHighlighted[hitSlot] = false;
        _draggingBlockIndex = null;
        _placedCount++;
      });

      _slotFillCtrls[hitSlot].forward(from: 0);
      await _playAudio('assets/audio/arctic_numberland/$_placedCount.wav');

      if (_placedCount == _targetCount && !_roundAdvancing) {
        _roundAdvancing = true;
        await Future.delayed(const Duration(milliseconds: 300));
        await _playAudio(_audioBuild);
        if (!mounted) return;
        setState(() => _roundComplete = true);
        _correctPulseCtrl.forward(from: 0);
        showDomaReaction(DomaState.correct);
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        if (_currentRound + 1 >= _totalRounds) {
          await ArcticProgressService.instance.markLevelComplete(16);
          setState(() => _showWinDialog = true);
        } else {
          setState(() => _currentRound++);
          _setupRound();
        }
      }
    } else {
      // Return to pile
      setState(() {
        _draggingBlockIndex = null;
        for (int i = 0; i < _targetCount; i++) {
          _slotHighlighted[i] = false;
        }
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
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  @override
  void dispose() {
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
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
          _introPlaying ? _buildIntroLayer() : _buildGameContent(),

          if (!_introPlaying) buildDoma(context),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Intro ──────────────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    return Stack(
      children: [
        Positioned(top: 25, left: 20, child: ArcticBackButton()),
        Positioned(top: 25, right: 20, child: ArcticLevelBadge(level: widget.level)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
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

                // ── SCENE ───────────────────────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT: Doma + ice block pile
                      Expanded(flex: 4, child: _buildBlockPileArea(h, w)),

                      // RIGHT: Igloo with slots
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

            // Dragging ghost block
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

  // ── Instruction Banner ─────────────────────────────────────────────────────
  Widget _buildInstructionBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Put',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
            // Show the target number prominently
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                '$_targetCount',
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
            Text(
              'block/s into the igloo!',
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
          ],
        ),
      ),
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
            // Source ice blocks (pile)
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
                // Igloo outline
                Positioned.fill(child: _buildIglooOutline(areaW, areaH)),

                // Slots inside igloo
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
        Navigator.pop(context, Number1to5MatchSnowglobesScreen(level: widget.level + 1));
      },
      onRestart: () {
        Navigator.pop(context, Number1to5FillIglooScreen(level: widget.level));
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
  final double pileOffsetX; // -0.5 to 0.5
  final double pileOffsetY;
  final double rotation; // radians

  const _IceBlockData({
    required this.id,
    required this.pileOffsetX,
    required this.pileOffsetY,
    required this.rotation,
  });
}

class _SlotLayout {
  final double rowFracX; // fraction of igloo widget width
  final double rowFracY; // fraction of igloo widget height

  const _SlotLayout({required this.rowFracX, required this.rowFracY});
}
