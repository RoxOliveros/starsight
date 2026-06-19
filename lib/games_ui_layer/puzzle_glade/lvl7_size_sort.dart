import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_level.dart';
import '../../ui_layer/puzzle_glade/Puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl8_whats_missing.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, game }

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAllObjects = [
  'compass',
  'jar',
  'lamp',
  'magnifying_glass',
  'map',
  'pen',
  'notebook',
  'puzzle_piece',
  'star',
  'telescope',
];

const int _kTotalRounds = 5;

// Size definitions: index 0 = small, 1 = medium, 2 = large
const _kSizes = [40.0, 60.0, 82.0];
const _kSizeLabels = ['Small', 'Medium', 'Large'];
const _kSlotSizes = [64.0, 88.0, 116.0]; // slot visual sizes

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _SizeItem {
  final String objectName;
  final int sizeIndex; // 0=small, 1=medium, 2=large
  final double displaySize;

  const _SizeItem({
    required this.objectName,
    required this.sizeIndex,
    required this.displaySize,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Lvl7SizeSortScreen extends StatefulWidget {
  const Lvl7SizeSortScreen({super.key});

  @override
  State<Lvl7SizeSortScreen> createState() => _Lvl7SizeSortScreenState();
}

class _Lvl7SizeSortScreenState extends State<Lvl7SizeSortScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<Lvl7SizeSortScreen> {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/level7/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level7/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level7/instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/level7/complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;

  /// The object used this round
  late String _currentObject;

  /// The 3 size items shuffled for the pool
  late List<_SizeItem> _poolItems;

  /// Slots: index 0=small slot, 1=medium slot, 2=large slot
  /// null means empty
  final List<_SizeItem?> _slots = [null, null, null];

  /// Flash state per slot (wrong drop)
  final List<bool> _flashSlot = [false, false, false];

  bool _roundComplete = false;
  bool _showWinDialog = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────

  // Shared float
  late AnimationController _roxieFloatCtrl;

  // Intro
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _itemDanceCtrl;
  late Animation<double> _itemDance;

  // Game transition
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;

  // Round fade
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  // Slot bounce controllers (one per slot)
  late List<AnimationController> _slotBounceCtrl;
  late List<Animation<double>> _slotBounceAnim;

  // Round complete pulse
  late AnimationController _completePulseCtrl;
  late Animation<double> _completePulseAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    _completePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _itemDanceCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    for (final c in _slotBounceCtrl) {
      c.dispose();
    }
    _completePulseCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Animation init ─────────────────────────────────────────────────────────

  void _initAnimations() {
    _roxieFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _roxieSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _roxieSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _roxieSlideCtrl, curve: Curves.elasticOut),
        );
    _roxieFade = CurvedAnimation(
      parent: _roxieSlideCtrl,
      curve: const Interval(0, 0.4),
    );

    _itemDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _itemDance = Tween<double>(
      begin: -0.06,
      end: 0.06,
    ).animate(CurvedAnimation(parent: _itemDanceCtrl, curve: Curves.easeInOut));

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _slotBounceCtrl = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      ),
    );
    _slotBounceAnim = _slotBounceCtrl
        .map(
          (c) => Tween<double>(
            begin: 1.0,
            end: 1.15,
          ).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut)),
        )
        .toList();

    _completePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _completePulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _completePulseCtrl, curve: Curves.easeInOut),
    );
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();

    await _playAudio(_audioIntro);
    await _playAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));

    _gameEnterCtrl.forward();
    _startRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
    await _playAudio(_audioInstructions);
  }

  Future<void> _playAudio(String asset) async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      final completer = Completer<void>();
      final sub = player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 20));
      await sub.cancel();
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    } finally {
      await player.stop();
      await player.dispose();
    }
  }

  // ── Round setup ────────────────────────────────────────────────────────────

  void _startRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);
    _currentObject = shuffled[0];

    // Create 3 size items (small=0, medium=1, large=2)
    _poolItems = List.generate(
      3,
      (i) => _SizeItem(
        objectName: _currentObject,
        sizeIndex: i,
        displaySize: _kSizes[i],
      ),
    )..shuffle(rng);

    _slots[0] = null;
    _slots[1] = null;
    _slots[2] = null;
    _flashSlot[0] = false;
    _flashSlot[1] = false;
    _flashSlot[2] = false;
    _roundComplete = false;

    for (final c in _slotBounceCtrl) {
      c.reset();
    }
    _completePulseCtrl.stop();
    _completePulseCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Drop logic ─────────────────────────────────────────────────────────────

  Future<void> _dropOnSlot(int slotIndex, _SizeItem item) async {
    if (_roundComplete) return;

    final isCorrect = item.sizeIndex == slotIndex;

    if (isCorrect) {
      final previousItem = _slots[slotIndex];
      setState(() {
        // If slot had an item, return it to pool
        if (previousItem != null) {
          _poolItems.add(previousItem);
        }
        // Place new item
        _poolItems.remove(item);
        _slots[slotIndex] = item;
        _slotBounceCtrl[slotIndex].forward(from: 0);
      });
      _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));

      showRoxieReaction(RoxieState.correct);

      // Check round complete — all 3 slots filled correctly
      if (_slots[0] != null && _slots[1] != null && _slots[2] != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _roundComplete = true);
        _completePulseCtrl.repeat(reverse: true);
        _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
        await Future.delayed(const Duration(milliseconds: 1400));

        if (_round >= _kTotalRounds) {
          await _sfxPlayer.stop();
          final completer = Completer<void>();
          final sub = _completePlayer.onPlayerComplete.listen((_) {
            if (!completer.isCompleted) completer.complete();
          });
          await _completePlayer.play(
            AssetSource(_audioComplete.replaceFirst('assets/', '')),
          );
          await completer.future.timeout(const Duration(seconds: 10));
          await sub.cancel();
          await PuzzleProgressService.instance.markLevelComplete(7);
          if (mounted) setState(() => _showWinDialog = true);
        } else {
          await _enterCtrl.reverse();
          if (mounted) {
            setState(() {
              _round++;
              _startRound();
            });
          }
        }
      }
    } else {
      // Wrong slot
      _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      setState(() => _flashSlot[slotIndex] = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _flashSlot[0] = false;
          _flashSlot[1] = false;
          _flashSlot[2] = false;
        });
      }
      showRoxieReaction(RoxieState.wrong);
    }
  }

  /// Pick up an item already placed in a slot (swap support)
  void _pickUpFromSlot(int slotIndex) {
    if (_roundComplete) return;
    final item = _slots[slotIndex];
    if (item == null) return;
    setState(() {
      _slots[slotIndex] = null;
      _poolItems.add(item);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                Image.asset(
                  _bgImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Container(color: Colors.black.withValues(alpha: 0.15)),
              ],
            ),
          ),
          SafeArea(
            child: _screenPhase == _ScreenPhase.intro
                ? _buildIntroContent()
                : Stack(
                    children: [
                      FadeTransition(
                        opacity: _gameFade,
                        child: _buildGameContent(),
                      ),
                      buildRoxie(context),
                    ],
                  ),
          ),
          if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIntroContent() {
    return Stack(
      children: [
        Positioned(top: 8, left: 12, child: PuzzleBackButton()),
        Positioned.fill(
          top: 48,
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildIntroRoxie()),
              Expanded(flex: 6, child: _buildIntroDancingItems()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroRoxie() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final roxieH = h * 1.05;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _roxieFloatCtrl, curve: Curves.easeInOut),
        );
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _roxieSlide,
              child: FadeTransition(
                opacity: _roxieFade,
                child: AnimatedBuilder(
                  animation: _roxieFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, floatY),
                    child: child,
                  ),
                  child: Image.asset(
                    _characterImage,
                    height: roxieH,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Text('🐰', style: TextStyle(fontSize: roxieH * 0.5)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroDancingItems() {
    // Show the same object in 3 different sizes dancing
    const previewObject = 'star';

    return AnimatedBuilder(
      animation: _itemDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final angle = _itemDance.value * ((i % 2 == 0) ? 1 : -1);
              final size = _kSizes[i] + 10;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(size * 0.25),
                      border: Border.all(
                        color: JarColorTheme.darkdesaturatedblue.withValues(
                          alpha: 0.25,
                        ),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/objects/puzzle/$previewObject.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Text('⭐', style: TextStyle(fontSize: size * 0.5)),
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

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameContent() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildGameHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildGameArea()),
          _buildProgressDots(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildGameHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Fix the Size',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 22,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // LEFT: choices
            Expanded(flex: 4, child: Center(child: _buildItemPool())),

            // RIGHT: shelf
            Expanded(flex: 6, child: Center(child: _buildShelfColumn())),
          ],
        );
      },
    );
  }

  // ── Shelf row ──────────────────────────────────────────────────────────────

  Widget _buildShelfRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / 3.5;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return SizedBox(width: slotWidth, child: _buildSlot(i));
              }),
            ),

            Container(
              width: constraints.maxWidth * 0.75,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFB5845A),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShelfColumn() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [_buildShelfRow()],
    );
  }

  Widget _buildSlot(int slotIndex) {
    final slotSize = _kSlotSizes[slotIndex];
    final label = _kSizeLabels[slotIndex];
    final placedItem = _slots[slotIndex];
    final isFlashing = _flashSlot[slotIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Size hint label
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: JarColorTheme.darkdesaturatedblue.withValues(
                  alpha: 0.25,
                ),
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: JarAppTextStyles.fredoka,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: JarColorTheme.darkdesaturatedblue.withValues(
                  alpha: 0.75,
                ),
              ),
            ),
          ),
          // Drop target
          ScaleTransition(
            scale: _slotBounceAnim[slotIndex],
            child: DragTarget<_SizeItem>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) =>
                  _dropOnSlot(slotIndex, details.data),
              builder: (context, candidateData, _) {
                final isDragOver = candidateData.isNotEmpty;
                return GestureDetector(
                  // Tap placed item to pick it back up
                  onTap: placedItem != null
                      ? () => _pickUpFromSlot(slotIndex)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: slotSize,
                    height: slotSize,
                    decoration: BoxDecoration(
                      color: isFlashing
                          ? const Color(0xFFE05A5A).withValues(alpha: 0.18)
                          : placedItem != null
                          ? JarColorTheme.goldenyellow.withValues(alpha: 0.20)
                          : isDragOver
                          ? JarColorTheme.goldenyellow.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFlashing
                            ? const Color(0xFFE05A5A)
                            : placedItem != null
                            ? JarColorTheme.sunnyhue
                            : isDragOver
                            ? JarColorTheme.sunnyhue
                            : JarColorTheme.darkdesaturatedblue.withValues(
                                alpha: 0.30,
                              ),
                        width: isFlashing || isDragOver || placedItem != null
                            ? 2.5
                            : 2,
                        style: placedItem == null && !isDragOver && !isFlashing
                            ? BorderStyle.solid
                            : BorderStyle.solid,
                      ),
                      boxShadow: placedItem != null
                          ? [
                              BoxShadow(
                                color: JarColorTheme.sunnyhue.withValues(
                                  alpha: 0.20,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: placedItem != null
                        ? Image.asset(
                            'assets/images/objects/puzzle/${placedItem.objectName}.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text(
                              '📦',
                              style: TextStyle(fontSize: 24),
                            ),
                          )
                        : isDragOver
                        ? Icon(
                            Icons.arrow_downward_rounded,
                            color: JarColorTheme.sunnyhue,
                            size: slotSize * 0.4,
                          )
                        : Icon(
                            Icons.add_rounded,
                            color: JarColorTheme.darkdesaturatedblue.withValues(
                              alpha: 0.20,
                            ),
                            size: slotSize * 0.4,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Item pool ──────────────────────────────────────────────────────────────

  Widget _buildItemPool() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: JarColorTheme.vandecane,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.55),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: JarColorTheme.goldenyellow.withValues(alpha: 0.20),
            blurRadius: 0,
            spreadRadius: 3,
            offset: Offset.zero,
          ),
        ],
      ),
      child: _poolItems.isEmpty
          ? _roundComplete
                ? ScaleTransition(
                    scale: _completePulseAnim,
                    child: const Center(
                      child: Text('⭐', style: TextStyle(fontSize: 44)),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 44,
                      color: JarColorTheme.sunnyhue,
                    ),
                  )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _poolItems
                  .map((item) => _buildDraggableItem(item))
                  .toList(),
            ),
    );
  }

  Widget _buildDraggableItem(_SizeItem item) {
    final size = item.displaySize;
    final tileSize = size + 8;

    Widget tile({bool isDragging = false}) => AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: tileSize,
      height: tileSize,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDragging
            ? JarColorTheme.goldenyellow.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragging
              ? JarColorTheme.sunnyhue
              : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.28),
          width: isDragging ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDragging
                ? JarColorTheme.sunnyhue.withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: isDragging ? 14 : 8,
            spreadRadius: isDragging ? 2 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        'assets/images/objects/puzzle/${item.objectName}.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Text('📦', style: TextStyle(fontSize: size * 0.6)),
      ),
    );

    return Draggable<_SizeItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: tile(isDragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: tile()),
      child: tile(),
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kTotalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? JarColorTheme.darkdesaturatedblue
                : current
                ? JarColorTheme.sunnyhue
                : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: JarColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Lvl8WhatsMissingScreen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Lvl7SizeSortScreen()),
        );
      },
      onBack: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PuzzleLevelScreen()),
        );
      },
    );
  }
}
