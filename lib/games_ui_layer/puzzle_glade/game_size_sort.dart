import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'game_whats_missing.dart';

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

const _kSizes3 = [40.0, 60.0, 82.0];
const _kSizeLabels3 = ['Small', 'Medium', 'Large'];

const _kSizes4 = [36.0, 52.0, 68.0, 88.0];
const _kSizeLabels4 = ['Tiny', 'Small', 'Medium', 'Large'];

const double _kSlotSize = 120.0;

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

class SizeSortScreen extends StatefulWidget {
  final int level;

  const SizeSortScreen({super.key, required this.level});

  @override
  State<SizeSortScreen> createState() => _SizeSortScreenState();
}

class _SizeSortScreenState extends State<SizeSortScreen>
    with TickerProviderStateMixin, RoxieReactionMixin<SizeSortScreen>, GameLoadingMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/level7/intro.wav';
  static const String _audioWelcome = 'assets/audio/puzzle_glade/level7/welcome.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/level7/instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/level7/complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';

  // ── Phase ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Round state ────────────────────────────────────────────────────────────
  int _round = 1;

  int _itemCountForRound(int round) => round >= 4 ? 4 : 3;
  List<double> get _sizesForRound => _itemCountForRound(_round) == 4 ? _kSizes4 : _kSizes3;
  List<String> get _labelsForRound => _itemCountForRound(_round) == 4 ? _kSizeLabels4 : _kSizeLabels3;

  /// The object used this round
  late String _currentObject;

  List<_SizeItem?> _slots = [null, null, null];
  List<bool> _flashSlot = [false, false, false];

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

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    finishLoading(_startIntroFlow);
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
      4,
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
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return; 
    _roxieSlideCtrl.forward();

    await _playAudio(_audioIntro);
    if (!mounted) return; 
    await _playAudio(_audioWelcome);
    if (!mounted) return; 
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return; 

    _gameEnterCtrl.forward();
    _startRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
    if (!mounted) return; 
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

    final itemCount = _itemCountForRound(_round);
    final sizes = _sizesForRound;

    List<_SizeItem> items;
    do {
      items = List.generate(
        itemCount,
            (i) => _SizeItem(
          objectName: _currentObject,
          sizeIndex: i,
          displaySize: sizes[i],
        ),
      )..shuffle(rng);
    } while (List.generate(itemCount, (i) => items[i].sizeIndex == i).every((b) => b));

    _slots = List.generate(itemCount, (i) => items[i]);
    _flashSlot = List.filled(itemCount, false);
    _roundComplete = false;

    for (final c in _slotBounceCtrl) {
      c.reset();
    }
    _completePulseCtrl.stop();
    _completePulseCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  // ── Drop logic ─────────────────────────────────────────────────────────────

  void _onDragAccepted(int toSlot, int fromSlot) async {
    if (_roundComplete) return;
    if (fromSlot == toSlot) return;

    setState(() {
      final temp = _slots[fromSlot];
      _slots[fromSlot] = _slots[toSlot];
      _slots[toSlot] = temp;
      _slotBounceCtrl[toSlot].forward(from: 0);
      _slotBounceCtrl[fromSlot].forward(from: 0);
    });

    _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));

    final sorted = List.generate(
      _slots.length,
          (i) => _slots[i]?.sizeIndex == i,
    ).every((b) => b);
    if (sorted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return; 
      setState(() => _roundComplete = true);
      _completePulseCtrl.repeat(reverse: true);
      _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));
      showRoxieReaction(RoxieState.correct);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return; 

      if (_round >= _kTotalRounds) {
        await _sfxPlayer.stop();
        if (!mounted) return; 
        final completer = Completer<void>();
        final sub = _completePlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        await _completePlayer.play(
          AssetSource(_audioComplete.replaceFirst('assets/', '')),
        );
        await completer.future.timeout(const Duration(seconds: 10));
        await sub.cancel();
        if (!mounted) return; 
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
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.puzzleGlade(), gameBuilder: () =>
          Stack(
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
              _screenPhase == _ScreenPhase.intro
                  ? _buildIntroLayer()
                  : Stack(
                children: [
                  FadeTransition(
                    opacity: _gameFade,
                    child: _buildGameLayer(),
                  ),
                  buildRoxie(context),
                ],
              ),
              if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
            ],
          ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIntroLayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
          child:Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
              Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
            ],
          ),
        ),
        Expanded(
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
        final roxieH = h * 0.95;
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
              final size = _kSizes3[i] + 10;
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
                        color: PuzzleColorTheme.darkdesaturatedblue.withValues(
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

  Widget _buildGameLayer() {
    return FadeTransition(
      opacity: _enterAnim,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
            child:
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(alignment: Alignment.centerLeft, child: PuzzleBackButton()),
                Align(alignment: Alignment.centerRight, child: PuzzleLevelBadge(level: widget.level)),
              ],
            ),
          ),
          Expanded(child: _buildGameArea()),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: PuzzleProgressDots(
              currentRound: _round,
              totalRounds: _kTotalRounds,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return Center(child: _buildShelfRow());
  }

  // ── Shelf row ──────────────────────────────────────────────────────────────

  Widget _buildShelfRow() {
    final itemCount = _itemCountForRound(_round); 
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(itemCount, (i) => _buildSlot(i)), // CHANGED — was 3
        ),
        Container(
          width: itemCount == 4 ? 500 : 400, // CHANGED — was fixed 400
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFFB5845A),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildSlot(int slotIndex) {
    final slotSize = _kSlotSize; // CHANGED — was _kSlotSizes[slotIndex]
    final label = _labelsForRound[slotIndex]; // CHANGED — was _kSizeLabels[slotIndex]
    final placedItem = _slots[slotIndex];
    final sizes = _sizesForRound; 

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                  alpha: 0.25,
                ),
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: PuzzleAppTextStyles.fredoka,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                  alpha: 0.75,
                ),
              ),
            ),
          ),
          ScaleTransition(
            scale: slotIndex < _slotBounceAnim.length
                ? _slotBounceAnim[slotIndex]
                : const AlwaysStoppedAnimation(1.0),
            child: DragTarget<int>(
              onAcceptWithDetails: (details) =>
                  _onDragAccepted(slotIndex, details.data),
              builder: (context, candidateData, _) {
                final isHovered = candidateData.isNotEmpty;
                return Draggable<int>(
                  data: slotIndex,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: 0.85,
                      child: Container(
                        width: slotSize,
                        height: slotSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PuzzleColorTheme.sunnyhue,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: placedItem != null
                            ? Center(
                                child: Image.asset(
                                  'assets/images/objects/puzzle/${placedItem.objectName}.png',
                                  width: sizes[placedItem.sizeIndex],
                                  height: sizes[placedItem.sizeIndex],
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  childWhenDragging: Container(
                    width: slotSize,
                    height: slotSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                          alpha: 0.20,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: slotSize,
                    height: slotSize,
                    decoration: BoxDecoration(
                      color: isHovered
                          ? PuzzleColorTheme.sunnyhue.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isHovered
                            ? PuzzleColorTheme.sunnyhue
                            : PuzzleColorTheme.darkdesaturatedblue.withValues(
                                alpha: 0.30,
                              ),
                        width: isHovered ? 3 : 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: placedItem != null
                        ? Center(
                      child: Image.asset(
                        'assets/images/objects/puzzle/${placedItem.objectName}.png',
                        width: sizes[placedItem.sizeIndex],
                        height: sizes[placedItem.sizeIndex],
                        fit: BoxFit.contain,
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Win overlay ────────────────────────────────────────────────────────────

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: PuzzleColorTheme.darkdesaturatedblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WhatsMissingScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SizeSortScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
