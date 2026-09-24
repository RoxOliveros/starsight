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
import 'arctic_audio_helper.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'number_introduction_screen.dart';
import 'game_memory_match.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class BuildSnowmanGame extends StatefulWidget {
  final int level;

  const BuildSnowmanGame({super.key, required this.level});

  @override
  State<BuildSnowmanGame> createState() => _BuildSnowmanGameState();
}

class _BuildSnowmanGameState extends State<BuildSnowmanGame>
    with TickerProviderStateMixin, DomaReactionMixin, GameLoadingMixin, ArcticAudioMixin, AiCameraMixin{
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _domaImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _snowballAsset = 'assets/images/objects/arctic/snowball_clean.png';
  static const String _snowmanAsset = 'assets/images/objects/arctic/snowman.png';
  static const String _snowmanHatFaceAsset = 'assets/images/objects/arctic/snowman_hat_face.png';
  static const String _tagAsset = 'assets/images/objects/arctic/tag.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/build_snowman_intro.wav';
  static const String _audioInstruction = '$_audioBase/build_snowman_instruction.wav';
  static const String _audioWin = '$_audioBase/build_snowman_win.wav';

  static const int _totalRounds = 5;

  // ── Tracking Variables ─────────────────────────────────────────────────────
  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _loadingScreenElapsed = false;
  Timer? _minLoadTimer;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<int> _targets;
  int _currentRound = 0;
  int _solvedRounds = 0;
  int _stackCount = 0;
  bool _roundResolving = false;
  bool _showWinDialog = false;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _popCtrl;
  late Animation<double> _pop;
  late AnimationController _tumbleCtrl;
  late Animation<double> _tumble;
  late AnimationController _completeCtrl;
  late Animation<double> _complete;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _targets = _buildTargets();
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

  List<int> _buildTargets() {
    final rng = Random();
    final targets = List.generate(5, (n) => n + 1)..shuffle(rng);
    return targets.take(_totalRounds).toList();
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

    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _pop = CurvedAnimation(parent: _popCtrl, curve: Curves.easeOutBack);

    _tumbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tumble = CurvedAnimation(parent: _tumbleCtrl, curve: Curves.easeIn);

    _completeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _complete = CurvedAnimation(
      parent: _completeCtrl,
      curve: Curves.elasticOut,
    );
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await _announceRound();
  }

  Future<void> _announceRound() async {
    final target = _targets[_currentRound];
    if (_currentRound == 0) {
      await playVoice(_audioInstruction);
    }
    if (mounted) await playSfx('$_audioBase/$target.wav');
  }

  // ── Snow pile interaction ───────────────────────────────────────────────
  Future<void> _onSnowballDropped() async {
    if (_roundResolving) return;

    _tapTracker.recordCorrectTap();

    final target = _targets[_currentRound];
    final next = _stackCount + 1;

    HapticFeedback.selectionClick();
    setState(() => _stackCount = next);
    _popCtrl.forward(from: 0);
    await playSfx('$_audioBase/$next.wav');

    if (next == target) {
      _roundResolving = true;
      HapticFeedback.mediumImpact();
      showDomaReaction(DomaState.correct);
      _completeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      await _advanceRound();
    }
  }

  Future<void> _advanceRound() async {
    setState(() => _solvedRounds++);

    if (_currentRound + 1 >= _totalRounds) {
      await playVoice(_audioWin);

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
      return;
    }

    setState(() {
      _currentRound++;
      _stackCount = 0;
      _roundResolving = false;
    });
    _completeCtrl.reset();
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) await _announceRound();
  }

  @override
  void dispose() {
    disposeAiCamera();
    _minLoadTimer?.cancel();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _popCtrl.dispose();
    _tumbleCtrl.dispose();
    _completeCtrl.dispose();
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

  // ── Intro layer ──────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(top: 25, left: 25, child: ArcticXButton()),
        Positioned(
          top: 25,
          right: 25,
          child: ArcticLevelBadge(level: widget.level),
        ),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      0,
                      Tween<double>(begin: -6, end: 6).evaluate(
                        CurvedAnimation(
                          parent: _domaFloatCtrl,
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                    child: child,
                  ),
                  child: Image.asset(
                    _domaImage,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🐧', style: TextStyle(fontSize: 70)),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Image.asset(
                  _snowmanAsset,
                  height: screenH * 0.5,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('⛄', style: TextStyle(fontSize: 90)),
                ),
              ),
            ],
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
          children: [
            ScaleTransition(
              scale: _sceneEnter,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 25,
                      right: 25,
                      top: 25,
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
                  Expanded(child: _buildStackArea(w, h)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildProgressDots(),
                  ),
                ],
              ),
            ),
            Positioned(right: 35, top: 100, child: _buildTargetBadge(h * 0.22)),
            Positioned(
              right: 20,
              bottom: 16,
              child: _buildSnowballSource((h * 0.30)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSnowballSource(double size) {
    final target = _targets[_currentRound];
    final disabled = _roundResolving || _stackCount >= target;

    final ball = Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: Image.asset(
        _snowballAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.circle, size: size, color: Colors.white),
      ),
    );

    if (disabled) return ball;

    return Draggable<int>(
      data: 1,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(
          _snowballAsset,
          width: size * 1.15,
          fit: BoxFit.contain,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: ball),
      onDragStarted: () => HapticFeedback.selectionClick(),
      onDraggableCanceled: (_, __) =>
          _tapTracker.recordMistake(), // <-- TRACK MISTAKE
      child: ball,
    );
  }

  Widget _buildTargetBadge(double size) {
    final target = _targets[_currentRound];
    final tagSize = size.clamp(60.0, 96.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: tagSize,
            height: tagSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  _tagAsset,
                  width: tagSize,
                  height: tagSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      color: ArcticColorTheme.pictonblue,
                      borderRadius: BorderRadius.circular(tagSize * 0.2),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, tagSize * 0.08),
                  child: Text(
                    '$target',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontWeight: FontWeight.bold,
                      fontSize: tagSize * 0.5,
                      color: ArcticColorTheme.cotton,
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

  // ── Stack area ───────────────────────────────────────────────────────────
  Widget _buildStackArea(double w, double h) {
    final ballSize = h * 0.30;
    final target = _targets[_currentRound];
    final isComplete = _stackCount == target && _roundResolving;
    final scales = List<double>.generate(_stackCount, (i) => 1.0 - (i * 0.1));
    const overlapFraction = 0.45;
    final bottoms = <double>[];
    double cumulative = 0;
    for (int i = 0; i < _stackCount; i++) {bottoms.add(cumulative);cumulative += ballSize * scales[i] * overlapFraction;}
    final topHeight = _stackCount == 0 ? ballSize : ballSize * scales.last;
    final stackHeight = cumulative + topHeight + ballSize * 0.9;
    final topBallScale = _stackCount > 0 ? scales.last : 1.0;
    final topBallSize = ballSize * topBallScale;
    final topBallBottom = _stackCount > 0 ? bottoms.last : 0.0;

    return Center(
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) =>
            !_roundResolving && _stackCount < target,
        onAcceptWithDetails: (_) => _onSnowballDropped(),
        builder: (context, candidateData, rejectedData) {
          final hovering = candidateData.isNotEmpty;
          return AnimatedScale(
            scale: hovering ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedBuilder(
              animation: _tumbleCtrl,
              builder: (_, child) {
                final t = _tumble.value;
                return Transform.rotate(
                  angle: t * 0.35 * (_stackCount.isEven ? 1 : -1),
                  child: Transform.translate(
                    offset: Offset(0, t * h * 0.15),
                    child: Opacity(opacity: 1 - t * 0.6, child: child),
                  ),
                );
              },
              child: SizedBox(
                width: ballSize * 1.6,
                height: stackHeight,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    if (_stackCount == 0)
                      Container(
                        width: ballSize,
                        height: ballSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.25),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 3,
                          ),
                        ),
                      ),

                    ...List.generate(_stackCount, (i) {
                      final scale = scales[i];
                      final isNewest = i == _stackCount - 1;
                      return Positioned(
                        bottom: bottoms[i],
                        child: AnimatedBuilder(
                          animation: _popCtrl,
                          builder: (_, child) => Transform.scale(
                            scale: isNewest
                                ? (0.3 + 0.7 * _pop.value) * scale
                                : scale,
                            child: child,
                          ),
                          child: Image.asset(
                            _snowballAsset,
                            width: ballSize * scale,
                            height: ballSize * scale,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.circle,
                              size: ballSize * scale,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),

                    if (_stackCount > 0)
                      Positioned(
                        bottom: topBallBottom + (topBallSize * 0.3),
                        child: AnimatedBuilder(
                          animation: _completeCtrl,
                          builder: (_, child) {
                            return Transform.scale(
                              scale: isComplete
                                  ? _complete.value
                                  : 0.0,
                              child: child,
                            );
                          },
                          child: IgnorePointer(
                            child: Image.asset(
                              _snowmanHatFaceAsset,
                              width: topBallSize * 0.9,
                              height: topBallSize * 0.9,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Text(
                                '🎩',
                                style: TextStyle(
                                  fontSize: topBallSize * 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedRounds;
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
            builder: (_) => NumberIntroductionScreen.forSequence(
              [9, 10],
              level: 16,
              nextScreen: const NumberMemoryMatchGame(level: 17),
            ),
          ),
        );
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedRounds = 0;
          _stackCount = 0;
          _roundResolving = false;
          _targets = _buildTargets();
        });
        _completeCtrl.reset();
        _sceneEnterCtrl.forward(from: 0);
        _instructionCtrl.forward(from: 0);
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
