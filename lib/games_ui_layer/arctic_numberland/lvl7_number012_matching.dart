import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../goodjob_prompt.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import 'lvl8_number012_counttap.dart';

enum _ScreenPhase { intro, miniGame }

class Number012MatchingScreen extends StatefulWidget {
  const Number012MatchingScreen({super.key});

  @override
  State<Number012MatchingScreen> createState() =>
      _Number012MatchingScreenState();
}

class _Number012MatchingScreenState extends State<Number012MatchingScreen>
    with TickerProviderStateMixin {
  // Numbers used in this round (3 pairs)
  late List<int> _roundNumbers;

  // Stable shuffled orders — locked per round so setState doesn't re-shuffle
  late List<int> _numberCardOrder;
  late List<int> _dotCardOrder;

  // Tracks which values have been correctly matched
  final Set<int> _matchedNumbers = {};

  // Wrong-flash state
  int? _wrongFlashNumber;
  int? _wrongFlashDots;

  // Score tracking
  int _round = 1;
  static const int _totalRounds = 5;

  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  bool _showWinDialog = false;
  final AudioPlayer _player = AudioPlayer();

  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    _startIntroFlow();
    _startRound();
  }

  @override
  void dispose() {
    _numberDanceCtrl.dispose();
    _player.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Round logic ───────────────────────────────────────────────────────────

  void _startRound() {
    final all = [0, 1, 2]..shuffle();
    _roundNumbers = all.take(3).toList();
    _numberCardOrder = List<int>.from(_roundNumbers)..shuffle();
    _dotCardOrder = List<int>.from(_roundNumbers)..shuffle();
    _matchedNumbers.clear();
    _wrongFlashNumber = null;
    _wrongFlashDots = null;
  }

  Future<void> _onDropped(int droppedValue, int targetValue) async {
    if (_matchedNumbers.contains(droppedValue)) return;

    if (droppedValue == targetValue) {
      _playAudio('assets/audio/bubble_pop.wav');
      setState(() => _matchedNumbers.add(droppedValue));

      if (_matchedNumbers.length == _roundNumbers.length) {
        await Future.delayed(const Duration(milliseconds: 700));

        if (_round >= _totalRounds) {
          setState(() => _showWinDialog = true);
        } else {
          setState(() {
            _round++;
            _startRound();
          });
        }
      }
    } else {
      // ❌ Wrong match — flash both cards
      setState(() {
        _wrongFlashNumber = droppedValue;
        _wrongFlashDots = targetValue;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _wrongFlashNumber = null;
        _wrongFlashDots = null;
      });
    }
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _playAudio(
      'assets/audio/arctic/level7/012_matching.wav',
    ); // update path
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _screenPhase = _ScreenPhase.miniGame);
  }

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
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // ── Color helpers ─────────────────────────────────────────────────────────

  // Number card (draggable): default → pictonblue | matched → lightblue | wrong → cadetblue
  Color _numberCardColor(int value) {
    if (_matchedNumbers.contains(value)) return ArcticColorTheme.lightblue;
    if (_wrongFlashNumber == value) return ArcticColorTheme.cadetblue;
    return ArcticColorTheme.pictonblue;
  }

  Color _numberCardBorderColor(int value) {
    if (_matchedNumbers.contains(value)) return ArcticColorTheme.pictonblue;
    if (_wrongFlashNumber == value) return ArcticColorTheme.slateblue;
    return ArcticColorTheme.slateblue;
  }

  // Dot card (target): default fill → cotton | matched → green | wrong → red
  Color _dotCardFillColor(int value) {
    if (_matchedNumbers.contains(value)) return Colors.green;
    if (_wrongFlashDots == value) return Colors.red;
    return ArcticColorTheme.cotton;
  }

  Color _dotCardBorderColor(int value) {
    if (_matchedNumbers.contains(value)) return ArcticColorTheme.pictonblue;
    if (_wrongFlashDots == value) return ArcticColorTheme.slateblue;
    return ArcticColorTheme.pictonblue;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcticColorTheme.lightgrayishcyan,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_arctic.png',
              fit: BoxFit.cover,
            ),
          ),
          if (_screenPhase == _ScreenPhase.intro)
            _buildIntroContent()
          else
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // --- HEADER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ArcticBackButton(),
                        ),
                        const Text(
                          'Number Matching',
                          style: TextStyle(
                            fontFamily: ArcticAppTextStyles.fredoka,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: ArcticColorTheme.cadetblue,
                            shadows: [Shadow(color: Colors.white, blurRadius: 8, offset: Offset(0, 2))],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 3),

                  // --- PROMPT ---
                  const Text(
                    'Drag the number to its matching dots!',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: 20,
                      color: ArcticColorTheme.slateblue,
                      shadows: [Shadow(color: Colors.white, blurRadius: 8, offset: Offset(0, 2))],
                    ),
                  ),

                  const SizedBox(height: 5),

                  // --- MAIN GAME AREA ---
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // LEFT — Draggable number cards
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _numberCardOrder
                              .map(_buildDraggableNumberCard)
                              .toList(),
                        ),

                        // Center arrow hint
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: ArcticColorTheme.slateblue,
                          size: 32,
                        ),

                        // RIGHT — DragTarget dot cards
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _dotCardOrder.map(_buildDotTarget).toList(),
                        ),
                      ],
                    ),
                  ),

                  _buildProgressDots(),
                ],
              ),
            ),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Draggable Number Card ─────────────────────────────────────────────────

  Widget _buildDraggableNumberCard(int value) {
    final isMatched = _matchedNumbers.contains(value);
    final bgColor = _numberCardColor(value);
    final borderColor = _numberCardBorderColor(value);

    final cardChild = Padding(
      padding: const EdgeInsets.all(10),
      child: Image.asset(
        'assets/fonts/game_numbers/$value.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            '$value',
            style: const TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: ArcticColorTheme.cotton,
            ),
          ),
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 85,
      height: 72,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isMatched
          ? cardChild
          : Draggable<int>(
              data: value,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 100,
                  height: 90,
                  decoration: BoxDecoration(
                    color: ArcticColorTheme.pictonblue,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/fonts/game_numbers/$value.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          '$value',
                          style: const TextStyle(
                            fontFamily: ArcticAppTextStyles.fredoka,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: ArcticColorTheme.cotton,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: Container(
                  width: 85,
                  height: 72,
                  decoration: BoxDecoration(
                    color: ArcticColorTheme.pictonblue,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: ArcticColorTheme.slateblue,
                      width: 3,
                    ),
                  ),
                  child: cardChild,
                ),
              ),
              child: cardChild,
            ),
    );
  }

  // ── Dot Target Card ───────────────────────────────────────────────────────

  Widget _buildDotTarget(int value) {
    final isMatched = _matchedNumbers.contains(value);

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
          !isMatched && !_matchedNumbers.contains(details.data),
      onAcceptWithDetails: (details) => _onDropped(details.data, value),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final bgColor = isMatched
            ? ArcticColorTheme.lightblue
            : isHovering
            ? ArcticColorTheme.pictonblue.withValues(alpha: 0.2)
            : _dotCardFillColor(value);
        final borderColor = isHovering
            ? ArcticColorTheme.pictonblue
            : _dotCardBorderColor(value);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 110,
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isHovering ? 3.5 : 3),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 5,
              runSpacing: 5,
              children: List.generate(
                value,
                (_) => Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isMatched
                        ? ArcticColorTheme.cotton
                        : ArcticColorTheme.slateblue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : current
                ? ArcticColorTheme.pictonblue
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildGoodJobOverlay() {
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number012TapCountScreen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number012MatchingScreen()),
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

  Widget _buildIntroContent() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(top: 8, left: 12, child: ArcticBackButton()),
          Positioned.fill(
            top: 50,
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/characters/doma_the_penguin.png',
                      height: MediaQuery.of(context).size.height * 0.65,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Text('🐧', style: TextStyle(fontSize: 60)),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _numberDanceCtrl,
                      builder: (_, __) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final angle =
                                _numberDance.value * ((i % 2 == 0) ? 1 : -1);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Transform.rotate(
                                angle: angle,
                                child: _buildIntroNumberCard(i),
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
      ),
    );
  }

  Widget _buildIntroNumberCard(int number) {
    final size = MediaQuery.of(context).size.height * 0.28;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Image.asset(
              'assets/fonts/game_numbers/$number.png',
              width: size * 0.64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                '$number',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ['ZERO', 'ONE', 'TWO'][number],
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
