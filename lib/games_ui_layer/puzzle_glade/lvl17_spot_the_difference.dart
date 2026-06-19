import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/Puzzle_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl18_star_color_sort2.dart';

// ── Screen phases ──────────────────────────────────────────────────────────
enum _ScreenPhase { intro, playing }

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
const int _kGridSize = 4; // 2x2 grid = 4 objects per scene

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a round
// ─────────────────────────────────────────────────────────────────────────────

class _RoundData {
  /// Objects shown on the LEFT (original) panel — 4 items, 2x2
  final List<String> leftObjects;

  /// Objects shown on the RIGHT (modified) panel — same except one slot differs
  final List<String> rightObjects;

  /// Index (0–3) of the slot that is different
  final int diffIndex;

  const _RoundData({
    required this.leftObjects,
    required this.rightObjects,
    required this.diffIndex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Lvl17SpotDifferenceScreen extends StatefulWidget {
  const Lvl17SpotDifferenceScreen({super.key});

  @override
  State<Lvl17SpotDifferenceScreen> createState() =>
      _Lvl17SpotDifferenceScreenState();
}

class _Lvl17SpotDifferenceScreenState extends State<Lvl17SpotDifferenceScreen>
    with TickerProviderStateMixin, RoxieReactionMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/level17/intro.wav';
  static const String _audioWelcome =
      'assets/audio/puzzle_glade/level17/welcome.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/level17/instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/level17/complete.wav';

  static const String _audioSuccess = 'assets/audio/sound_effects/shine.wav';
  static const String _audioBubblePop =
      'assets/audio/sound_effects/bubble_pop.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  _ScreenPhase _phase = _ScreenPhase.intro;
  int _round = 1;
  late _RoundData _currentRound;

  /// Which cell is highlighted as correct (null = none yet)
  int? _highlightedCorrectIndex;

  /// Which cell was tapped wrong (null = none) — triggers shake
  int? _wrongTappedIndex;

  bool _showWinDialog = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _roxieFloatCtrl;
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;
  late AnimationController _roundEnterCtrl;
  late Animation<double> _roundFade;
  late AnimationController _correctGlowCtrl;

  // Per-cell shake for wrong tap (8 cells total: 4 left + 4 right)
  late List<AnimationController> _cellShakeCtrl;
  late List<Animation<double>> _cellShakeAnim;

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
    _gameEnterCtrl.dispose();
    _roundEnterCtrl.dispose();
    _correctGlowCtrl.dispose();
    for (final c in _cellShakeCtrl) {
      c.dispose();
    }
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

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _roundEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _roundFade = CurvedAnimation(
      parent: _roundEnterCtrl,
      curve: Curves.easeOut,
    );

    _correctGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // 8 shake controllers: index 0–3 = left panel cells, 4–7 = right panel cells
    _cellShakeCtrl = List.generate(
      8,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _cellShakeAnim = _cellShakeCtrl
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: 1,
          ).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut)),
        )
        .toList();
  }

  // ── Intro flow ─────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _roxieSlideCtrl.forward();
    await _playAudio(_audioIntro);
    await _playAudio(_audioWelcome);
    await Future.delayed(const Duration(milliseconds: 400));
    _gameEnterCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    _buildRound();
    setState(() => _phase = _ScreenPhase.playing);
    _roundEnterCtrl.forward(from: 0);
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

  void _buildRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);

    // Pick 4 objects for the base scene
    final base = shuffled.take(_kGridSize).toList();

    // Pick the diff index (0–3) and replacement object
    final diffIndex = rng.nextInt(_kGridSize);
    final replacement = shuffled
        .skip(_kGridSize)
        .firstWhere((o) => !base.contains(o), orElse: () => shuffled.last);

    final right = List<String>.from(base);
    right[diffIndex] = replacement;

    _currentRound = _RoundData(
      leftObjects: base,
      rightObjects: right,
      diffIndex: diffIndex,
    );

    _highlightedCorrectIndex = null;
    _wrongTappedIndex = null;

    for (final c in _cellShakeCtrl) {
      c.reset();
    }
    _correctGlowCtrl.stop();
    _correctGlowCtrl.reset();
  }

  // ── Tap logic ──────────────────────────────────────────────────────────────

  /// [panel] 0 = left, 1 = right; [cellIndex] 0–3
  void _onCellTapped(int panel, int cellIndex) async {
    if (_phase != _ScreenPhase.playing) return;
    if (_highlightedCorrectIndex != null) return; // already answered

    final isCorrect = cellIndex == _currentRound.diffIndex;

    if (isCorrect) {
      // Play success sound
      _sfxPlayer.play(AssetSource(_audioSuccess.replaceFirst('assets/', '')));

      showRoxieReaction(RoxieState.correct);

      setState(() => _highlightedCorrectIndex = cellIndex);
      _correctGlowCtrl.repeat(reverse: true);

      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _correctGlowCtrl.stop();
      _correctGlowCtrl.reset();

      if (_round >= _kTotalRounds) {
        // All rounds done
        final completer = Completer<void>();
        final sub = _completePlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        await _completePlayer.play(
          AssetSource(_audioComplete.replaceFirst('assets/', '')),
        );
        await completer.future.timeout(const Duration(seconds: 15));
        await sub.cancel();
        await PuzzleProgressService.instance.markLevelComplete(17);
        if (mounted) setState(() => _showWinDialog = true);
      } else {
        // Next round
        await _roundEnterCtrl.reverse();
        if (!mounted) return;
        setState(() {
          _round++;
          _buildRound();
          _phase = _ScreenPhase.playing;
        });
        _roundEnterCtrl.forward(from: 0);
      }
    } else {
      // Wrong tap — shake that specific cell
      _sfxPlayer.play(AssetSource(_audioBubblePop.replaceFirst('assets/', '')));

      showRoxieReaction(RoxieState.wrong);

      // shakeIndex: panel 0 → indices 0–3, panel 1 → indices 4–7
      final shakeIndex = panel * _kGridSize + cellIndex;
      setState(() => _wrongTappedIndex = cellIndex);
      _cellShakeCtrl[shakeIndex].forward(from: 0).then((_) {
        if (mounted) setState(() => _wrongTappedIndex = null);
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
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
            child: _phase == _ScreenPhase.intro
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
              Expanded(flex: 6, child: _buildIntroPreview()),
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

  Widget _buildIntroPreview() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPreviewPanel(label: 'Scene 1', showMark: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.search_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          _buildPreviewPanel(label: 'Scene 2', showMark: true),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel({required String label, required bool showMark}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: JarColorTheme.darkdesaturatedblue,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(2, (row) {
              return Row(
                children: List.generate(2, (col) {
                  final isMarkCell = showMark && row == 0 && col == 1;
                  return Container(
                    margin: const EdgeInsets.all(3),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isMarkCell
                          ? Colors.amber.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMarkCell
                            ? Colors.amber
                            : JarColorTheme.darkdesaturatedblue.withValues(
                                alpha: 0.2,
                              ),
                        width: isMarkCell ? 2 : 1,
                      ),
                    ),
                    child: isMarkCell
                        ? const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 22,
                          )
                        : Icon(
                            Icons.image_outlined,
                            color: JarColorTheme.darkdesaturatedblue.withValues(
                              alpha: 0.3,
                            ),
                            size: 20,
                          ),
                  );
                }),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGameContent() {
    return FadeTransition(
      opacity: _roundFade,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildGameHeader(),
          const SizedBox(height: 6),
          Expanded(
            child: Row(children: [Expanded(child: _buildMainArea())]),
          ),
          _buildProgressDots(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGameHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 48,
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
              ),
              child: Text(
                'Spot the Difference',
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 20,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Round $_round / $_kTotalRounds',
                  style: TextStyle(
                    fontFamily: JarAppTextStyles.fredoka,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Instruction label
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            _highlightedCorrectIndex != null
                ? '🌟 Nakita mo!'
                : 'Hanapin ang pagkakaiba!',
            style: TextStyle(
              fontFamily: JarAppTextStyles.fredoka,
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Two panels side by side
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPanel(panelIndex: 0, objects: _currentRound.leftObjects),
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'VS',
                    style: TextStyle(
                      fontFamily: JarAppTextStyles.fredoka,
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _buildPanel(panelIndex: 1, objects: _currentRound.rightObjects),
          ],
        ),
      ],
    );
  }

  // ── Panel (2x2 grid) ───────────────────────────────────────────────────────

  Widget _buildPanel({required int panelIndex, required List<String> objects}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(2, (row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(2, (col) {
              final cellIndex = row * 2 + col;
              return _buildCell(
                panelIndex: panelIndex,
                cellIndex: cellIndex,
                objectName: objects[cellIndex],
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildCell({
    required int panelIndex,
    required int cellIndex,
    required String objectName,
  }) {
    final isTheDiff = cellIndex == _currentRound.diffIndex;
    final isHighlighted = _highlightedCorrectIndex != null && isTheDiff;
    final isWrongFlash = _wrongTappedIndex == cellIndex;

    // shake index: left panel 0–3, right panel 4–7
    final shakeIndex = panelIndex * _kGridSize + cellIndex;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _cellShakeAnim[shakeIndex],
        _correctGlowCtrl,
      ]),
      builder: (_, child) {
        final shake = sin(_cellShakeAnim[shakeIndex].value * pi * 6) * 6;
        final glowValue = isHighlighted ? _correctGlowCtrl.value : 0.0;

        return Transform.translate(
          offset: Offset(shake, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(5),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Color.lerp(
                      Colors.green.withValues(alpha: 0.25),
                      Colors.green.withValues(alpha: 0.55),
                      glowValue,
                    )
                  : isWrongFlash
                  ? Colors.red.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHighlighted
                    ? Colors.green
                    : isWrongFlash
                    ? Colors.red
                    : JarColorTheme.darkdesaturatedblue.withValues(alpha: 0.25),
                width: isHighlighted || isWrongFlash ? 3 : 2,
              ),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(
                          alpha: 0.3 + glowValue * 0.3,
                        ),
                        blurRadius: 10 + glowValue * 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _onCellTapped(panelIndex, cellIndex),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/objects/puzzle/$objectName.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                objectName[0].toUpperCase(),
                style: TextStyle(
                  fontFamily: JarAppTextStyles.fredoka,
                  fontSize: 28,
                  color: JarColorTheme.darkdesaturatedblue,
                ),
              ),
            ),
            // Checkmark badge when correct
            if (isHighlighted)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
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
        Navigator.pop(context, const Lvl18JarColorSort2Screen());
      },
      onRestart: () {
        Navigator.pop(context, const Lvl17SpotDifferenceScreen());
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
