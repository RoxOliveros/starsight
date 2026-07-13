import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_audio_helper.dart';
import 'build_snowman.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';

class _IglooOption {
  final String id;
  final int quantity;
  const _IglooOption({required this.id, required this.quantity});
}

class _RoundSpec {
  final int targetNumber;
  final List<_IglooOption> options;
  const _RoundSpec({required this.targetNumber, required this.options});
}

class IglooPeekabooGame extends StatefulWidget {
  final int level;

  const IglooPeekabooGame({super.key, required this.level});

  @override
  State<IglooPeekabooGame> createState() => _IglooPeekabooGameState();
}

class _IglooPeekabooGameState extends State<IglooPeekabooGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<IglooPeekabooGame>,
        GameLoadingMixin<IglooPeekabooGame>,
        ArcticAudioMixin<IglooPeekabooGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _iglooAsset = 'assets/images/objects/arctic/igloo.png';
  static const String _brokenIglooAsset = 'assets/images/objects/arctic/broken_igloo.png';
  static const String _babyPenguinAsset = 'assets/images/characters/baby_penguin.png';
  static const String _snowballAsset = 'assets/images/objects/arctic/snowball.png';
  static const String _tagAsset = 'assets/images/objects/arctic/tag.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/igloo_peekaboo_intro.wav';
  static const String _audioInstruction = '$_audioBase/igloo_peekaboo_instruction.wav';
  static const String _audioWin = '$_audioBase/igloo_peekaboo_win.wav';

  // Ramp: 2 choices for the first two rounds, 3 for the middle stretch,
  // 4 once numbers get bigger and there's more to compare.
  static const List<int> _optionCounts = [2, 2, 3, 3, 3];
  static const int _totalRounds = 5;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  late List<_RoundSpec> _rounds;
  int _currentRound = 0;
  int _solvedRounds = 0;
  bool _roundResolving = false;
  String? _correctSpotId; // set once the round's correct igloo is revealed
  String? _wrongSpotId; // set briefly when the wrong igloo is tapped
  bool _showWinDialog = false;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;
  late AnimationController _revealCtrl;
  late Animation<double> _reveal;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _rounds = _buildRounds();
    _initAnimations();
    finishLoading(_startIntroFlow);
  }

  List<_RoundSpec> _buildRounds() {
    final rng = Random();
    final targets = List.generate(8, (n) => n + 1)..shuffle(rng);
    final chosenTargets = targets.take(_totalRounds).toList();

    return List.generate(_totalRounds, (i) {
      final target = chosenTargets[i];
      final count = _optionCounts[i];
      final possible = List.generate(8, (n) => n + 1)..remove(target);
      possible.shuffle(rng);
      final distractors = possible.take(count - 1).toList();
      final quantities = [target, ...distractors]..shuffle(rng);
      final options = List.generate(
        count,
            (idx) => _IglooOption(id: 'r$i-o$idx', quantity: quantities[idx]),
      );
      return _RoundSpec(targetNumber: target, options: options);
    });
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
    _instructionBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _instructionCtrl, curve: Curves.easeOut));

    _sceneEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sceneEnter = CurvedAnimation(parent: _sceneEnterCtrl, curve: Curves.elasticOut);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _reveal = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic); // was elasticOut — no bounce/overshoot
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
    if (mounted) _announceRound();
  }

  Future<void> _announceRound() async {
    final target = _rounds[_currentRound].targetNumber;
    if (_currentRound == 0) {
      await playVoice(_audioInstruction);
    }
    if (mounted) await playSfx('$_audioBase/$target.wav');
  }

  // ── Igloo interaction ─────────────────────────────────────────────────────
  Future<void> _onIglooTapped(_IglooOption option) async {
    if (_roundResolving || _correctSpotId != null) return;
    final round = _rounds[_currentRound];

    if (option.quantity == round.targetNumber) {
      _roundResolving = true;
      HapticFeedback.mediumImpact();

      setState(() => _correctSpotId = option.id);
      _revealCtrl.forward(from: 0);
      await playSfx('$_audioBase/${option.quantity}.wav');
      showDomaReaction(DomaState.correct);

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      await _advanceRound();
    } else {
      HapticFeedback.heavyImpact();
      await playSfx('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);

      setState(() => _wrongSpotId = option.id);
      _shakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _wrongSpotId = null);
    }
  }

  Future<void> _advanceRound() async {
    setState(() => _solvedRounds++);

    if (_currentRound + 1 >= _totalRounds) {
      await playVoice(_audioWin);
      if (!mounted) return;
      setState(() => _showWinDialog = true);
      return;
    }

    setState(() {
      _currentRound++;
      _correctSpotId = null;
      _wrongSpotId = null;
      _roundResolving = false;
    });
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) await _announceRound();
  }

  @override
  void dispose() {
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _shakeCtrl.dispose();
    _revealCtrl.dispose();
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
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFFDCEFFA)),
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

  // ── Intro layer ──────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(top: 25, left: 20, child: ArcticBackButton()),
        Positioned(top: 25, right: 20, child: ArcticLevelBadge(level: widget.level)),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) =>
                      Transform.translate(
                        offset: Offset(
                          0,
                          Tween<double>(begin: -6, end: 6).evaluate(
                            CurvedAnimation(parent: _domaFloatCtrl,
                                curve: Curves.easeInOut),
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
                child: SizedBox(
                  height: screenH * 0.7,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        bottom: screenH * 0.5,
                        right: screenH * 0.5,
                        child: _buildPeekaboo(screenH * 0.5),
                      ),
                      Image.asset(
                        _iglooAsset,
                        height: screenH * 0.7,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                        const Text('🧊', style: TextStyle(fontSize: 90)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  // ── Main game layout ─────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return ScaleTransition(
          scale: _sceneEnter,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: ArcticBackButton()),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ArcticLevelBadge(level: widget.level),
                    ),
                    Center(child: _buildPromptBanner(h)),
                  ],
                ),
              ),
              _buildTargetBadge(h * 0.22),
              Expanded(child: _buildIglooRow(w, h)),
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: _buildProgressDots(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromptBanner(double h) {
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: _announceRound,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          child: Text(
            'Find the igloo with this many snowballs!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],            ),
          ),
        ),
      ),
    );
  }

  /// Target number shown on a tag, with that many mini snowballs beside it
  /// so the numeral and the quantity are always taught together.
  Widget _buildTargetBadge(double size) {
    final target = _rounds[_currentRound].targetNumber;
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
                  offset: Offset(0, tagSize * 0.08), // ← increase/decrease to move it down more or less
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

  // ── Igloo row ─────────────────────────────────────────────────────────────
  Widget _buildIglooRow(double w, double h) {
    final round = _rounds[_currentRound];
    final iglooSize = (h * 0.38);

    return Align(
      alignment: const Alignment(0, -1.5), // move toward -1.0 to go higher
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 15,
        runSpacing: 18,
        children: round.options.map((o) => _buildIglooSpot(o, iglooSize)).toList(),
      ),
    );
  }

  Widget _buildIglooSpot(_IglooOption option, double size) {
    final isCorrectRevealed = _correctSpotId == option.id;
    final isWrong = _wrongSpotId == option.id;

    return GestureDetector(
      onTap: () => _onIglooTapped(option),
      child: AnimatedBuilder(
        animation: _shakeCtrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(isWrong ? _shake.value : 0, 0),
          child: child,
        ),
        child: SizedBox(
          width: size,
          height: size * 1.15,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              if (isCorrectRevealed)
                Positioned(
                  top: size * 0.05,
                  left: size * 0.2,
                  child: AnimatedBuilder(
                    animation: _reveal,
                    builder: (_, child) {
                      final t = _reveal.value.clamp(0.0, 1.0);
                      return Opacity(
                        // fades in fast during the first 20% of the animation, then stays fully visible
                        // so it looks like it's sliding out from behind, not materializing
                        opacity: (t / 0.2).clamp(0.0, 1.0),
                        child: Transform.translate(
                          // starts well below/centered, tucked behind the igloo body,
                          // then slowly slides up and over to the upper-right peek spot
                          offset: Offset(
                            size * 0.05 * (1 - t),
                            size * 0.55 * (1 - t),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: _buildPeekaboo(size),
                  ),
                ),
              Image.asset(
                isWrong ? _brokenIglooAsset : _iglooAsset,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text('🧊', style: TextStyle(fontSize: size * 0.6)),
              ),
              // NEW: snowballs always visible under the igloo
              Positioned(
                bottom: -size * 0.1,
                child: _buildSnowballRow(option.quantity, size),
              ),
            ],
          ),
        ),
      ),
    );
  }

// NEW helper — snowball cluster shown under each igloo at all times
  Widget _buildSnowballRow(int quantity, double iglooSize) {
    final ballSize = iglooSize * 0.16;
    return SizedBox(
      width: iglooSize,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 3,
        runSpacing: 3,
        children: List.generate(
          quantity,
              (_) => Image.asset(
            _snowballAsset,
            width: ballSize,
            height: ballSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.circle, size: ballSize, color: ArcticColorTheme.pictonblue),
          ),
        ),
      ),
    );
  }

  /// Baby penguin peeking out of the igloo window, holding its cluster of
  /// snowballs so the child sees the number *and* the counted quantity.
  Widget _buildPeekaboo(double iglooSize) {
    final penguinSize = iglooSize * 0.42; // was 0.5, slightly smaller for the corner peek
    return Image.asset(
      _babyPenguinAsset,
      width: penguinSize,
      height: penguinSize,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text('🐧', style: TextStyle(fontSize: penguinSize * 0.8)),
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
        Navigator.pop(context, BuildSnowmanGame(level: widget.level + 1));
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedRounds = 0;
          _correctSpotId = null;
          _wrongSpotId = null;
          _roundResolving = false;
          _rounds = _buildRounds();
        });
        _sceneEnterCtrl.forward(from: 0);
        _instructionCtrl.forward(from: 0);
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}