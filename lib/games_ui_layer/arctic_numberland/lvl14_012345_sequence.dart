import 'dart:async';
import 'package:StarSight/games_ui_layer/arctic_numberland/lvl15_0to5_counting_trees.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../goodjob_prompt.dart';

class Number012345SequenceScreen extends StatefulWidget {
  const Number012345SequenceScreen({super.key});

  @override
  State<Number012345SequenceScreen> createState() =>
      _Number012345SequenceScreenState();
}

class _Number012345SequenceScreenState extends State<Number012345SequenceScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 3;
  static const List<int> _allNumbers = [0, 1, 2, 3, 4, 5];

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage =
      'assets/images/characters/doma_the_penguin.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/level17/intro.wav';
  static const String _audioSlotCorrect = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioWin = 'assets/audio/sound_effects/shine.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;

  // The shuffled tiles the player drags from
  late List<int?> _tileNumbers; // null means already placed

  // The slots — null means empty, int means placed number
  late List<int?> _slots;

  // Track which slot indices are locked (correctly placed)
  late List<bool> _slotLocked;

  // Track wrong flash per slot
  late List<bool> _slotWrong;

  // ignore: unused_field
  bool _roundComplete = false;
  bool _showWinDialog = false;

  // ignore: unused_field
  int? _draggingNumber;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;

  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;

  late AnimationController _tilesEnterCtrl;
  late Animation<double> _tilesEnter;

  // Number dance for intro
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  // Per-slot correct pulse controllers (6 slots)
  late List<AnimationController> _slotPulseCtrlList;
  late List<Animation<double>> _slotPulseList;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
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

    _tilesEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tilesEnter = CurvedAnimation(
      parent: _tilesEnterCtrl,
      curve: Curves.elasticOut,
    );

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    // 6 slot pulse controllers
    _slotPulseCtrlList = List.generate(
      6,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _slotPulseList = _slotPulseCtrlList.map((ctrl) {
      return TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }).toList();
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
    // Start with complete sequence
    _slots = [..._allNumbers];

    // Randomly choose 2 or 3 slots to hide
    final hiddenCount = (_currentRound == 0) ? 2 : 3;

    final indices = List.generate(6, (i) => i)..shuffle();
    final hiddenIndices = indices.take(hiddenCount).toList();

    // Tiles player can drag
    _tileNumbers = [];

    // Setup slots
    _slotLocked = List.filled(6, true);
    _slotWrong = List.filled(6, false);

    for (final i in hiddenIndices) {
      // Add missing number to draggable tiles
      _tileNumbers.add(_slots[i]);

      // Empty the slot
      _slots[i] = null;

      // Unlock this slot
      _slotLocked[i] = false;
    }

    // Shuffle draggable choices
    _tileNumbers.shuffle();

    _roundComplete = false;
    _draggingNumber = null;

    _tilesEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    // Reset slot pulse animations
    for (final c in _slotPulseCtrlList) {
      c.reset();
    }
  }

  // ── Drag & Drop Logic ──────────────────────────────────────────────────────
  Future<void> _onDropToSlot(int slotIndex, int number) async {
    if (_slotLocked[slotIndex]) return;

    final correctNumber = slotIndex;

    // Remove dragged tile from choices immediately
    final tileIdx = _tileNumbers.indexOf(number);

    if (tileIdx != -1) {
      setState(() {
        _tileNumbers[tileIdx] = null;
      });
    }

    if (number == correctNumber) {
      // CORRECT
      setState(() {
        _slots[slotIndex] = number;
        _slotLocked[slotIndex] = true;
      });

      _slotPulseCtrlList[slotIndex].forward(from: 0);

      await _playAudio(_audioSlotCorrect);

      // Check if all missing slots are solved
      if (_slotLocked.every((l) => l)) {
        setState(() => _roundComplete = true);

        await Future.delayed(const Duration(milliseconds: 300));
        await _playAudio(_audioWin);

        if (!mounted) return;

        if (_currentRound + 1 >= _totalRounds) {
          setState(() => _showWinDialog = true);
        } else {
          setState(() => _currentRound++);
          _setupRound();
        }
      }
    } else {
      // WRONG
      setState(() {
        _slots[slotIndex] = number;
        _slotWrong[slotIndex] = true;
      });

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      // Return tile back
      final emptyIdx = _tileNumbers.indexWhere((e) => e == null);

      setState(() {
        if (emptyIdx != -1) {
          _tileNumbers[emptyIdx] = number;
        }

        _slots[slotIndex] = null;
        _slotWrong[slotIndex] = false;
      });
    }
  }

  // ── Audio ──────────────────────────────────────────────────────────────────
  Future<void> _playAudio(String asset) async {
    try {
      final completer = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future;
      await sub.cancel();
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _tilesEnterCtrl.dispose();
    _numberDanceCtrl.dispose();
    for (final c in _slotPulseCtrlList) {
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

          SafeArea(
            child: _introPlaying ? _buildIntroLayer() : _buildGameContent(),
          ),

          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Intro ──────────────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    return Stack(
      children: [
        Positioned(top: 8, left: 12, child: ArcticBackButton()),
        Positioned.fill(
          top: 48,
          child: Row(
            children: [
              // Doma
              Expanded(
                flex: 4,
                child: Center(
                  child: Image.asset(
                    _characterImage,
                    height: MediaQuery.of(context).size.height * 0.65,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🐧', style: TextStyle(fontSize: 60)),
                  ),
                ),
              ),
              // Dancing numbers 0–5
              Expanded(
                flex: 6,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _numberDanceCtrl,
                    builder: (_, __) {
                      return Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(6, (i) {
                          final angle =
                              _numberDance.value * ((i % 2 == 0) ? 1 : -1);
                          return Transform.rotate(
                            angle: angle,
                            child: _buildIntroNumberCard(i),
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

  Widget _buildIntroNumberCard(int number) {
    final size = MediaQuery.of(context).size.height * 0.20;
    const words = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Image.asset(
              'assets/fonts/game_numbers/$number.png',
              width: size * 0.60,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                '$number',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Text(
          words[number],
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 2),
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

        return Column(
          children: [
            // ── HEADER ─────────────────────────────
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

            const SizedBox(height: 12),

            // ── SLOTS ROW ──────────────────────────
            ScaleTransition(scale: _tilesEnter, child: _buildSlotsRow(w, h)),

            const SizedBox(height: 10),

            // ── TILES TRAY ─────────────────────────
            Expanded(
              child: Stack(children: [Center(child: _buildTilesTray(w, h))]),
            ),

            // ── PROGRESS DOTS ──────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildRoundIndicator(),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
            const SizedBox(width: 10),
            Text(
              'Arrange the numbers in order!',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: (h * 0.075).clamp(15.0, 24.0),
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

  // ── Slots Row ──────────────────────────────────────────────────────────────
  Widget _buildSlotsRow(double w, double h) {
    final slotSize = (w * 0.105).clamp(58.0, 90.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: _buildSlot(i, slotSize),
        );
      }),
    );
  }

  Widget _buildSlot(int slotIndex, double size) {
    final isLocked = _slotLocked[slotIndex];
    final isWrong = _slotWrong[slotIndex];
    final placedNumber = _slots[slotIndex];
    final isEmpty = placedNumber == null;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => !isLocked,
      onAcceptWithDetails: (details) {
        _onDropToSlot(slotIndex, details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return ScaleTransition(
          scale: isLocked
              ? _slotPulseList[slotIndex]
              : const AlwaysStoppedAnimation(1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isLocked
                  ? Colors.green.shade100
                  : isWrong
                  ? Colors.red.shade100
                  : isHovered
                  ? ArcticColorTheme.pictonblue.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLocked
                    ? Colors.green
                    : isWrong
                    ? Colors.red
                    : isHovered
                    ? ArcticColorTheme.pictonblue
                    : Colors.white.withValues(alpha: 0.6),
                width: isLocked || isHovered ? 3.5 : 2.5,
              ),
              boxShadow: isLocked
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.5),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Slot index hint (faint, shown when empty)
                if (isEmpty && !isHovered)
                  Text(
                    '$slotIndex',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: size * 0.38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),

                // Placed number image
                if (!isEmpty)
                  Padding(
                    padding: EdgeInsets.all(size * 0.10),
                    child: Image.asset(
                      'assets/fonts/game_numbers/$placedNumber.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(
                        '$placedNumber',
                        style: TextStyle(
                          fontFamily: ArcticAppTextStyles.fredoka,
                          fontSize: size * 0.45,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ),

                // Lock checkmark
                if (isLocked)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: size * 0.28,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tiles Tray ─────────────────────────────────────────────────────────────
  Widget _buildTilesTray(double w, double h) {
    final tileSize = (w * 0.108).clamp(62.0, 95.0);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: _tileNumbers.asMap().entries.map((entry) {
        final tileNumber = entry.value;
        if (tileNumber == null) {
          // Invisible placeholder to keep layout stable
          return SizedBox(width: tileSize, height: tileSize);
        }
        return _buildDraggableTile(tileNumber, tileSize);
      }).toList(),
    );
  }

  Widget _buildDraggableTile(int number, double size) {
    return Draggable<int>(
      data: number,
      feedback: Material(
        color: Colors.transparent,
        child: _buildTileWidget(number, size, isDragging: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildTileWidget(number, size),
      ),
      onDragStarted: () => setState(() => _draggingNumber = number),
      onDragEnd: (_) => setState(() => _draggingNumber = null),
      child: _buildTileWidget(number, size),
    );
  }

  Widget _buildTileWidget(int number, double size, {bool isDragging = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: isDragging ? size * 1.1 : size,
      height: isDragging ? size * 1.1 : size,
      decoration: BoxDecoration(
        color: isDragging
            ? ArcticColorTheme.cadetblue
            : ArcticColorTheme.pictonblue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: isDragging
                ? ArcticColorTheme.cadetblue.withValues(alpha: 0.7)
                : ArcticColorTheme.pictonblue.withValues(alpha: 0.4),
            blurRadius: isDragging ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.10),
        child: Image.asset(
          'assets/fonts/game_numbers/$number.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: size * 0.45,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Progress ───────────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _currentRound;
        final current = i == _currentRound;
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
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const Number0to5CountingTreesScreen(),
          ),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number012345SequenceScreen()),
        );
      },
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ArcticLevelScreen()),
          (route) => route.isFirst,
        );
      },
    );
  }
}
