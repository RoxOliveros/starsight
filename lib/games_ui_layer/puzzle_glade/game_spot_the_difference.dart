import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/puzzle_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/game_pattern_match.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../goodjob_prompt.dart';

enum _ScreenPhase { intro, playing }

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
const int _kGridSize = 4;

class _RoundData {
  final List<String> leftObjects;
  final List<String> rightObjects;
  final int diffIndex;

  const _RoundData({
    required this.leftObjects,
    required this.rightObjects,
    required this.diffIndex,
  });
}

class SpotDifferenceScreen extends StatefulWidget {
  final int level;

  const SpotDifferenceScreen({super.key, required this.level});

  @override
  State<SpotDifferenceScreen> createState() => _SpotDifferenceScreenState();
}

class _SpotDifferenceScreenState extends State<SpotDifferenceScreen>
    with
        TickerProviderStateMixin,
        RoxieReactionMixin,
        GameLoadingMixin,
        AiCameraMixin {
  @override
  AudioPlayer get roxiePlayer => _sfxPlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage =
      'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';

  static const String _audioIntro =
      'assets/audio/puzzle_glade/spot_the_difference_intro.wav';
  static const String _audioInstructions =
      'assets/audio/puzzle_glade/spot_the_difference_instruction.wav';
  static const String _audioComplete =
      'assets/audio/puzzle_glade/spot_the_difference_complete.wav';

  // ── State ──────────────────────────────────────────────────────────────────
  _ScreenPhase _phase = _ScreenPhase.intro;
  int _round = 1;
  late _RoundData _currentRound;

  int? _highlightedCorrectIndex;
  int? _wrongTappedIndex;

  bool _showWinDialog = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

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

  late List<AnimationController> _cellShakeCtrl;
  late List<Animation<double>> _cellShakeAnim;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  @override
  void dispose() {
    disposeAiCamera();
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

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _roxieSlideCtrl.forward();
    await _playAudio(_audioIntro);
    if (!mounted) return;

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
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  void _buildRound() {
    final rng = Random();
    final shuffled = List<String>.from(_kAllObjects)..shuffle(rng);

    final base = shuffled.take(_kGridSize).toList();

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

  void _onCellTapped(int panel, int cellIndex) async {
    if (_phase != _ScreenPhase.playing) return;
    if (_highlightedCorrectIndex != null) return;

    final isCorrect = cellIndex == _currentRound.diffIndex;

    if (isCorrect) {
      _tapTracker.recordCorrectTap();
      showRoxieReaction(RoxieState.correct);

      setState(() => _highlightedCorrectIndex = cellIndex);
      _correctGlowCtrl.repeat(reverse: true);

      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _correctGlowCtrl.stop();
      _correctGlowCtrl.reset();

      if (_round >= _kTotalRounds) {
        await _sfxPlayer.stop();
        final completer = Completer<void>();
        final sub = _completePlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        await _completePlayer.play(
          AssetSource(_audioComplete.replaceFirst('assets/', '')),
        );
        await completer.future.timeout(const Duration(seconds: 15));
        await sub.cancel();

        PuzzleProgressService.instance
            .markLevelComplete(widget.level)
            .catchError((e) {
              debugPrint("Database Error marking level complete: $e");
            });
        await _saveDataAndShowWinDialog();
      } else {
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
      _tapTracker.recordMistake();
      showRoxieReaction(RoxieState.wrong);

      final shakeIndex = panel * _kGridSize + cellIndex;
      setState(() => _wrongTappedIndex = cellIndex);
      _cellShakeCtrl[shakeIndex].forward(from: 0).then((_) {
        if (mounted) setState(() => _wrongTappedIndex = null);
      });
    }
  }

  Future<void> _saveDataAndShowWinDialog() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    PuzzleDatabaseService.saveGameData(
      gameId: 'puzzle_spot_the_difference',
      activityName: 'Spot The Difference',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    if (mounted) {
      setState(() => _showWinDialog = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.puzzleGlade(),
        gameBuilder: () => Stack(
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
            _phase == _ScreenPhase.intro
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

            Positioned(top: 25, left: 25, child: PuzzleXButton()),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_showWinDialog) Positioned.fill(child: _buildWinOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroLayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: PuzzleLevelBadge(level: widget.level),
              ),
            ],
          ),
        ),
        Expanded(
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
              fontFamily: PuzzleAppTextStyles.fredoka,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PuzzleColorTheme.darkdesaturatedblue,
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
              color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                alpha: 0.3,
              ),
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
                            : PuzzleColorTheme.darkdesaturatedblue.withValues(
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
                            color: PuzzleColorTheme.darkdesaturatedblue
                                .withValues(alpha: 0.3),
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

  Widget _buildGameLayer() {
    return FadeTransition(
      opacity: _roundFade,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: PuzzleLevelBadge(level: widget.level),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(children: [Expanded(child: _buildMainArea())]),
          ),
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

  Widget _buildMainArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            _highlightedCorrectIndex != null
                ? '🌟 Nakita mo!'
                : 'Hanapin ang pagkakaiba!',
            style: TextStyle(
              fontFamily: PuzzleAppTextStyles.fredoka,
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPanel(panelIndex: 0, objects: _currentRound.leftObjects),
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
                      fontFamily: PuzzleAppTextStyles.fredoka,
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
                    : PuzzleColorTheme.darkdesaturatedblue.withValues(
                        alpha: 0.25,
                      ),
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
                  fontFamily: PuzzleAppTextStyles.fredoka,
                  fontSize: 28,
                  color: PuzzleColorTheme.darkdesaturatedblue,
                ),
              ),
            ),
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

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,

      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PatternMatchScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SpotDifferenceScreen(level: widget.level),
          ),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
