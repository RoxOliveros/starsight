import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../goodjob_prompt.dart';
import 'lvl16_0to5_building_igloo.dart';

class Number0to5CountingTreesScreen extends StatefulWidget {
  const Number0to5CountingTreesScreen({super.key});

  @override
  State<Number0to5CountingTreesScreen> createState() =>
      _Number0to5CountingTreesScreenState();
}

class _Number0to5CountingTreesScreenState
    extends State<Number0to5CountingTreesScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage =
      'assets/images/characters/doma_the_penguin.png';
  static const String _treeAsset =
      'assets/images/objects/arctic/snowy_tree.png';

  static const String _audioIntro =
      'assets/audio/arctic_numberland/level18/intro.wav';
  static const String _audioCorrect =
      'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioQuestion =
      'assets/audio/arctic_numberland/level18/how_many.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;

  late int _treeCount; // how many trees this round (0–5)
  late List<_TreeData> _trees; // scattered tree positions & sizes
  late List<int> _choices; // 3 number choices
  int? _tappedIndex; // which choice was tapped
  bool _showWinDialog = false;
  late List<int> _roundPool;
  late List<int?> _treeTapOrder;

  // Trees get highlighted when tapped for counting help
  late List<bool> _treeTapped;
  int _tappedTreeCount = 0;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;

  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;

  late AnimationController _treesEnterCtrl;
  late Animation<double> _treesEnter;

  late AnimationController _choicesEnterCtrl;
  late Animation<double> _choicesEnter;

  late AnimationController _correctPulseCtrl;
  late Animation<double> _correctPulse;

  // Intro number dance
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _roundPool = [0, 1, 2, 3, 4, 5]..shuffle();

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

    _treesEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _treesEnter = CurvedAnimation(
      parent: _treesEnterCtrl,
      curve: Curves.elasticOut,
    );

    _choicesEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _choicesEnter = CurvedAnimation(
      parent: _choicesEnterCtrl,
      curve: Curves.easeOutBack,
    );

    _correctPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _correctPulse =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _correctPulseCtrl, curve: Curves.easeOut),
        );

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );
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
    final rng = Random();

    if (_roundPool.isEmpty) {
      _roundPool = [0, 1, 2, 3, 4, 5]..shuffle();
    }

    _treeCount = _roundPool.removeLast();

    _trees = _generateTreePositions(_treeCount, rng);

    _treeTapped = List.filled(_treeCount, false);
    _treeTapOrder = List.filled(_treeCount, null);
    _tappedTreeCount = 0;

    final allNums = List.generate(6, (i) => i);

    final distractors = [...allNums]..remove(_treeCount);

    distractors.shuffle(rng);

    _choices = [...distractors.take(2), _treeCount]..shuffle(rng);

    _tappedIndex = null;

    _treesEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _playAudio(_audioQuestion);
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _choicesEnterCtrl.forward(from: 0);
    });
  }

  List<_TreeData> _generateTreePositions(int count, Random rng) {
    // Scene area roughly 500×240 logical units (scaled at build time)
    // Avoid bottom 20% (ground) and left 15% (Doma's space)
    const minX = 0.15;
    const maxX = 0.88;
    const minY = 0.05;
    const maxY = 0.72;
    const minDist = 0.18; // min distance between trees

    final List<_TreeData> placed = [];
    int attempts = 0;

    while (placed.length < count && attempts < 200) {
      attempts++;
      final x = minX + rng.nextDouble() * (maxX - minX);
      final y = minY + rng.nextDouble() * (maxY - minY);

      // Check no overlap
      bool ok = true;
      for (final t in placed) {
        final dx = t.x - x;
        final dy = t.y - y;
        if (sqrt(dx * dx + dy * dy) < minDist) {
          ok = false;
          break;
        }
      }

      if (ok) {
        // Slight size variation for depth effect: trees higher up = smaller
        final scale = 0.72 + (1.0 - y) * 0.36 + rng.nextDouble() * 0.12;
        placed.add(_TreeData(x: x, y: y, scale: scale.clamp(0.70, 1.15)));
      }
    }

    return placed;
  }

  // ── Choice Tap ─────────────────────────────────────────────────────────────
  Future<void> _onChoiceTap(int index) async {
    if (_tappedIndex != null) return;
    setState(() => _tappedIndex = index);

    final isCorrect = _choices[index] == _treeCount;

    if (isCorrect) {
      _correctPulseCtrl.forward(from: 0);
      await _playAudio('assets/audio/arctic_numberland/$_treeCount.wav');
    }

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    if (_currentRound + 1 >= _totalRounds) {
      await ArcticProgressService.instance.markLevelComplete(15);
      setState(() => _showWinDialog = true);
    } else {
      setState(() => _currentRound++);
      _setupRound();
    }
  }

  // ── Tree Tap (counting helper) ─────────────────────────────────────────────
  void _onTreeTap(int treeIndex) {
    if (_treeTapped[treeIndex]) return;

    setState(() {
      _treeTapped[treeIndex] = true;

      _tappedTreeCount++;

      _treeTapOrder[treeIndex] = _tappedTreeCount;
    });

    _playAudio('assets/audio/arctic_numberland/$_tappedTreeCount.wav');
  }

  // ── Audio ──────────────────────────────────────────────────────────────────
  Future<void> _playAudio(String asset) async {
    StreamSubscription? sub;

    try {
      final completer = Completer<void>();

      sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
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
    _treesEnterCtrl.dispose();
    _choicesEnterCtrl.dispose();
    _correctPulseCtrl.dispose();
    _numberDanceCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Choice Colors ──────────────────────────────────────────────────────────
  Color _choiceColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.pictonblue;
    if (_choices[index] == _treeCount) return Colors.green;
    if (_tappedIndex == index) return Colors.red;
    return ArcticColorTheme.pictonblue;
  }

  Color _choiceBorderColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.slateblue;
    if (_choices[index] == _treeCount) return Colors.green.shade700;
    if (_tappedIndex == index) return Colors.red.shade700;
    return ArcticColorTheme.slateblue;
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
                    height: MediaQuery.of(context).size.height * 0.62,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🐧', style: TextStyle(fontSize: 60)),
                  ),
                ),
              ),
              // Snowy trees dancing (0 to 5)
              Expanded(
                flex: 6,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _numberDanceCtrl,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(6, (i) {
                          final angle =
                              _numberDance.value * ((i % 2 == 0) ? 1 : -1);
                          final treeH =
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
                                  if (i != 0)
                                    Image.asset(
                                      _treeAsset,
                                      height: treeH,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Text(
                                        '🌲',
                                        style: TextStyle(fontSize: 32),
                                      ),
                                    ),

                                  if (i != 0) const SizedBox(height: 6),
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
                                      '$i',
                                      style: TextStyle(
                                        fontFamily: ArcticAppTextStyles.fredoka,
                                        fontSize: treeH * 0.28,
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

        return Column(
          children: [
            // ── HEADER ──────────────────────────────
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

            // ── SCENE + CHOICES ─────────────────────
            Expanded(
              child: Row(
                children: [
                  // LEFT: Arctic scene with scattered trees
                  Expanded(
                    flex: 6,
                    child: ScaleTransition(
                      scale: _treesEnter,
                      child: _buildTreeScene(w, h),
                    ),
                  ),

                  // RIGHT: Number choices
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: ScaleTransition(
                      scale: _choicesEnter,
                      child: _buildChoicesColumn(h),
                    ),
                  ),
                ],
              ),
            ),

            // ── PROGRESS DOTS ───────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildRoundIndicator(),
            ),
          ],
        );
      },
    );
  }

  // ── Banner ─────────────────────────────────────────────────────────────────
  Widget _buildInstructionBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => _playAudio(_audioQuestion),
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
              Image.asset(
                _treeAsset,
                height: (h * 0.08).clamp(24.0, 38.0),
                errorBuilder: (_, __, ___) =>
                    const Text('🌲', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Text(
                'How many trees are there?  🔊',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: (h * 0.075).clamp(14.0, 23.0),
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
      ),
    );
  }

  // ── Tree Scene ─────────────────────────────────────────────────────────────
  Widget _buildTreeScene(double w, double h) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sw = constraints.maxWidth;
        final sh = constraints.maxHeight;

        return Stack(
          children: [
            // Doma bottom left
            Positioned(left: 0, bottom: 0, child: _buildDoma(sh * 0.68)),

            // Counter badge (shows how many trees tapped)
            if (_tappedTreeCount > 0 && _tappedIndex == null)
              Positioned(
                top: 8,
                right: 12,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ArcticColorTheme.cadetblue.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$_tappedTreeCount / $_treeCount',
                    style: const TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Trees scattered
            ...List.generate(_trees.length, (i) {
              final tree = _trees[i];
              final treeH = (sh * 0.30 * tree.scale).clamp(50.0, 130.0);
              final px = tree.x * sw;
              final py = tree.y * sh;
              final isTapped = _treeTapped[i];

              return Positioned(
                left: px - treeH * 0.3,
                top: py,
                child: GestureDetector(
                  onTap: () => _onTreeTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Glow when tapped
                        if (isTapped)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.yellowAccent.withValues(
                                      alpha: 0.6,
                                    ),
                                    blurRadius: 18,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Tree image with tint when tapped
                        ColorFiltered(
                          colorFilter: isTapped
                              ? const ColorFilter.matrix([
                                  0.6,
                                  0,
                                  0,
                                  0,
                                  80,
                                  0,
                                  0.9,
                                  0,
                                  0,
                                  80,
                                  0,
                                  0,
                                  0.4,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ])
                              : const ColorFilter.matrix([
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                          child: Image.asset(
                            _treeAsset,
                            height: treeH,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Text(
                              '🌲',
                              style: TextStyle(fontSize: treeH * 0.6),
                            ),
                          ),
                        ),

                        // Number badge on tapped tree
                        if (isTapped)
                          Positioned(
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ArcticColorTheme.cadetblue,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${_treeTapOrder[i] ?? ''}',
                                style: const TextStyle(
                                  fontFamily: ArcticAppTextStyles.fredoka,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
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

  // ── Choices Column ─────────────────────────────────────────────────────────
  Widget _buildChoicesColumn(double h) {
    final btnSize = (h * 0.16).clamp(58.0, 90.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_choices.length, (index) {
        final isCorrect = _choices[index] == _treeCount;
        final isTappedCorrect = _tappedIndex == index && isCorrect;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: GestureDetector(
            onTap: _tappedIndex == null ? () => _onChoiceTap(index) : null,
            child: ScaleTransition(
              scale: isTappedCorrect
                  ? _correctPulse
                  : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: btnSize * 1.1,
                height: btnSize,
                decoration: BoxDecoration(
                  color: _choiceColor(index),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _choiceBorderColor(index),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _choiceColor(index).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/fonts/game_numbers/${_choices[index]}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        '${_choices[index]}',
                        style: const TextStyle(
                          fontFamily: ArcticAppTextStyles.fredoka,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Doma ───────────────────────────────────────────────────────────────────
  Widget _buildDoma(double h) {
    final domaH = h.clamp(90.0, 175.0);
    return AnimatedBuilder(
      animation: _domaFloatCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          0,
          Tween<double>(begin: -6, end: 6).evaluate(
            CurvedAnimation(parent: _domaFloatCtrl, curve: Curves.easeInOut),
          ),
        ),
        child: child,
      ),
      child: Image.asset(
        _characterImage,
        height: domaH,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Text('🐧', style: TextStyle(fontSize: domaH * 0.5)),
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
    return GoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number0to5FillIglooScreen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const Number0to5CountingTreesScreen(),
          ),
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

// ── Tree Data Model ────────────────────────────────────────────────────────────
class _TreeData {
  final double x; // 0.0 – 1.0 of scene width
  final double y; // 0.0 – 1.0 of scene height
  final double scale; // size multiplier for depth illusion

  const _TreeData({required this.x, required this.y, required this.scale});
}
