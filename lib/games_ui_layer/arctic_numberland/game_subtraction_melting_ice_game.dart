import 'dart:async';
import 'package:StarSight/games_ui_layer/arctic_numberland/game_subtraction_compare_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/arctic_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';

class SubtractionMeltingIceGame extends StatefulWidget {
  final int level;

  const SubtractionMeltingIceGame({super.key,required this.level});

  @override
  State<SubtractionMeltingIceGame> createState() => _SubtractionMeltingIceGameState();
}

class _SubtractionMeltingIceGameState extends State<SubtractionMeltingIceGame>
    with TickerProviderStateMixin, DomaReactionMixin, GameLoadingMixin {
  @override
  AudioPlayer get domaPlayer => _voicePlayer;

  // ── Asset paths (swap to match your project) ────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _iceAsset = 'assets/images/objects/arctic/ice.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/melting_ice_intro.wav';
  static const String _audioInstructionPrompt = '$_audioBase/melting_ice_instruction.wav';
  static const String _audioQuestion = '$_audioBase/melting_ice_question.wav';
  static const String _audioMeltRefreeze = 'assets/audio/sound_effects/plip.wav';

  // ── Game constants ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  static const List<List<int>> _factPool = [
    [2, 1],
    [3, 1],
    [3, 2],
    [4, 1],
    [4, 2],
    [4, 3],
    [5, 1],
    [5, 2],
    [5, 3],
    [5, 4],
  ];

  static const List<double> _iceLengthScale = [1.0, 1.25, 0.9, 1.15, 1.05];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  bool _showWinDialog = false;
  int _solvedCount = 0;
  bool _resolvingRound = false;
  bool _shattering = false;
  bool _showAnswerChoices = false;
  bool _awaitingAnswer = false;
  bool _hideSubtractNumber = false;
  bool _canTapIce = false;
  bool _canTapAnswers = false;

  late List<int> _answerChoices;
  late List<List<int>> _roundPool;
  late int _minuend;
  late int _subtrahend;

  late List<bool> _popped;

  Timer? _solveTimer;

  // ── Audio ────────────────────────────────────────────────────────────────
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _correctPulseCtrl;
  late AnimationController _shatterCtrl;
  late Animation<double> _shatterShake;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _roundPool = [..._factPool]..shuffle();
    _initAnimations();
    finishLoading(_startIntroFlow);
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

    _correctPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _shatterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shatterShake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.04), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.03), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _shatterCtrl, curve: Curves.easeOut));
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _setupRound();
  }

  void _setupRound() {
    if (_roundPool.isEmpty) {
      _roundPool = [..._factPool]..shuffle();
    }

    final fact = _roundPool.removeLast();

    _minuend = fact[0];
    _subtrahend = fact[1];

    _popped = List.filled(_minuend, false);

    _resolvingRound = false;
    _shattering = false;

    _showAnswerChoices = false;
    _awaitingAnswer = false;
    _hideSubtractNumber = false;

    _canTapAnswers = false;
    _canTapIce = _currentRound != 0;

    final correctAnswer = _minuend - _subtrahend;

    final otherAnswers = [0, 1, 2, 3, 4, 5]
      ..remove(correctAnswer)
      ..shuffle();

    _answerChoices = [
      correctAnswer,
      otherAnswers[0],
      otherAnswers[1],
    ]..shuffle();

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (_currentRound == 0) {
      Future.delayed(
        const Duration(milliseconds: 500),
            () async {
          if (!mounted) return;

          await _playVoice(_audioInstructionPrompt);

          if (!mounted) return;

          setState(() {
            _canTapIce = true;
          });
        },
      );
    }

    setState(() {});
  }

  int get _poppedCount => _popped.where((p) => p).length;

  // ── Tap handler ──────────────────────────────────────────────────────────
  void _onIceTap(int index) {
    if (_resolvingRound ||
        _awaitingAnswer ||
        !_canTapIce) {
      return;
    }

    final wasPopped = _popped[index];

    HapticFeedback.selectionClick();
    _playSfx(_audioMeltRefreeze);

    setState(() {
      _popped[index] = !wasPopped;
    });

    final poppedCount = _poppedCount;

    if (poppedCount > _subtrahend) {
      _onTooManyMelted();
    } else if (poppedCount == _subtrahend) {
      _startAnswerQuestion();
    }
  }

  Future<void> _startAnswerQuestion() async {
    if (_awaitingAnswer) return;

    setState(() {
      _awaitingAnswer = true;
      _canTapIce = false;
      _canTapAnswers = false;
    });

    HapticFeedback.mediumImpact();
    _correctPulseCtrl.forward(from: 0);

    await Future.delayed(
      const Duration(milliseconds: 1000),
    );

    if (!mounted) return;

    setState(() {
      _hideSubtractNumber = true;
      _showAnswerChoices = true;
    });

    await _playVoice(_audioQuestion);

    if (!mounted) return;

    setState(() {
      _canTapAnswers = true;
    });
  }

  Future<void> _onAnswerTap(int answer) async {
    if (!_awaitingAnswer ||
        _resolvingRound ||
        !_canTapAnswers) {
      return;
    }

    final correctAnswer = _minuend - _subtrahend;

    if (answer != correctAnswer) {
      HapticFeedback.heavyImpact();
      showDomaReaction(DomaState.wrong);
      return;
    }

    setState(() {
      _resolvingRound = true;
      _awaitingAnswer = false;
      _showAnswerChoices = false;
    });

    HapticFeedback.mediumImpact();
    showDomaReaction(DomaState.correct);

    setState(() {
      _solvedCount++;
    });

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    if (_currentRound + 1 >= _totalRounds) {
      ArcticProgressService.instance
          .markLevelComplete(widget.level);

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
  }

  Future<void> _onTooManyMelted() async {
    setState(() {
      _resolvingRound = true;
      _shattering = true;
    });
    HapticFeedback.heavyImpact();
    _shatterCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _popped = List.filled(_minuend, false);
      _resolvingRound = false;
      _shattering = false;
    });
    showDomaReaction(DomaState.wrong);
  }

  // ── Audio ────────────────────────────────────────────────────────────────
  Future<void> _playVoice(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _voicePlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _voicePlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Voice audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  void _playSfx(String asset) {
    _sfxPlayer.play(AssetSource(asset.replaceFirst('assets/', ''))).catchError((
      e,
    ) {
      debugPrint('SFX audio error ($asset): $e');
    });
  }

  @override
  void dispose() {
    _solveTimer?.cancel();
    _voicePlayer.dispose();
    _sfxPlayer.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _correctPulseCtrl.dispose();
    _shatterCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.arctic(),
        gameBuilder: () => Stack(
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
        ),
      ),
    );
  }

  // ── Intro / story setup ──────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(top: 25, left: 25, child: ArcticXButton()),
        Positioned(top: 25, right: 25, child: ArcticLevelBadge(level: widget.level)),
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
                    _characterImage,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                    const Text('🐧', style: TextStyle(fontSize: 70)),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _iceAsset,
                      height: screenH * 0.3,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                      const Text('🧊', style: TextStyle(fontSize: 70)),
                    ),
                  ],
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

        final choicesWidth =
        (w * 0.18).clamp(150.0, 220.0);

        return Column(
          children: [
            // TOP BAR
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
                    child: ArcticLevelBadge(
                      level: widget.level,
                    ),
                  ),
                ],
              ),
            ),

            // GAME AREA
            Expanded(
              child: Stack(
                children: [
                  // MAIN GAME — centered using full available width
                  Positioned.fill(
                    child: Center(
                      child: ScaleTransition(
                        scale: _sceneEnter,
                        child: _buildIceScene(
                          w,
                          h,
                        ),
                      ),
                    ),
                  ),

                  // ANSWER CHOICES — overlay on right
                  Positioned(
                    right: 25,
                    top: 0,
                    bottom: 0,
                    width: choicesWidth,
                    child: Center(
                      child: IgnorePointer(
                        ignoring: !_showAnswerChoices || !_canTapAnswers,
                        child: AnimatedOpacity(
                          opacity:
                          _showAnswerChoices ? 1.0 : 0.0,
                          duration:
                          const Duration(milliseconds: 300),
                          child: _buildAnswerChoices(h),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ROUND INDICATOR
            Padding(
              padding: const EdgeInsets.only(
                bottom: 15,
              ),
              child: _buildRoundIndicator(),
            ),
          ],
        );
      },
    );
  }

  // ── Ice scene: equation + beam + tappable ice ─────────────────────
  Widget _buildIceScene(double w, double h) {
    final beamWidth =
    (w * 0.85).clamp(220.0, 380.0);

    final numberSize =
    (h * 0.3).clamp(70.0, 110.0);

    final iceAreaHeight = h * 0.4;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: !_hideSubtractNumber,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _buildSubtractNumber(numberSize),
          ),

          const SizedBox(height: 14),

          // Ice
          AnimatedBuilder(
            animation:
            _shattering
                ? _shatterShake
                : _kZeroAnim,
            builder: (_, child) {
              return Transform.rotate(
                angle:
                _shattering
                    ? _shatterShake.value
                    : 0,
                child: child,
              );
            },
            child: SizedBox(
              width: beamWidth,
              height: iceAreaHeight,
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: List.generate(
                  _minuend,
                      (i) => _buildIce(
                    i,
                    iceAreaHeight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static final Animation<double> _kZeroAnim = AlwaysStoppedAnimation<double>(
    0.0,
  );

  Widget _buildSubtractNumber(double size) {
    return Container(
      width: size * 0.75,
      height: size * 0.75,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ArcticColorTheme.cotton.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(
              alpha: 0.3,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$_subtrahend',
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: ArcticColorTheme.cadetblue,
        ),
      ),
    );
  }

  Widget _buildIce(int index, double areaHeight) {
    final popped = _popped[index];
    final lengthScale = _iceLengthScale[index % _iceLengthScale.length];
    final baseHeight = areaHeight * 0.85 * lengthScale;
    final width = baseHeight * 0.34;

    return GestureDetector(
      onTap: () => _onIceTap(index),
      child: AnimatedOpacity(
        opacity: popped ? 0.15 : 1.0,
        duration: const Duration(milliseconds: 350),
        child: AnimatedScale(
          scale: popped ? 0.35 : 1.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
          child: AnimatedSlide(
            offset: popped ? const Offset(0, 0.4) : Offset.zero,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
            child: Image.asset(
              _iceAsset,
              width: width,
              height: baseHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.water_drop,
                size: width,
                color: ArcticColorTheme.pictonblue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerChoices(double h) {
    final buttonSize =
    (h * 0.13).clamp(65.0, 90.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: _answerChoices.map((answer) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onAnswerTap(answer),
            child: Container(
              width: buttonSize,
              height: buttonSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ArcticColorTheme.cotton,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ArcticColorTheme.pictonblue,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.15,
                    ),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                '$answer',
                style: TextStyle(
                  fontFamily:
                  ArcticAppTextStyles.fredoka,
                  fontSize: buttonSize * 0.48,
                  fontWeight: FontWeight.bold,
                  color: ArcticColorTheme.cadetblue,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedCount;
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
            builder: (_) => SubtractionCompareGame(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedCount = 0;
          _roundPool = [..._factPool]..shuffle();
          _setupRound();
        });
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
