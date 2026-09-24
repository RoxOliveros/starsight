import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../business_layer/town_progress_service.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/lumi_town/lumi_buttons.dart';
import '../goodjob_prompt.dart';
import '../tryagain_prompt.dart';
import 'lumi_game_safe_or_not.dart';

const String _playgroundBg = 'assets/images/backgrounds/bg_playground.png';
const String _bearPlayingImage = 'assets/images/objects/lumi/playground_bear_playing.png';
const String _littleBearImage = 'assets/images/characters/little_bear_uniform.png';
const String _littleBearSmileImage = 'assets/images/characters/little_bear_happy.png';
const String _roxieImage = 'assets/images/characters/roxie_the_rabbit.png';
const String _roxieSmileImage = 'assets/images/characters/roxie_happy.png';
const String _mamaBearImage = 'assets/images/characters/mom_bear.png';
const String _mamaBearSmileImage = 'assets/images/characters/mom_bear_happy.png';
const String _jackImage = 'assets/images/characters/jack_the_fox.png';
const String _jackSmileImage = 'assets/images/characters/jack_happy.png';
const String _trWooImage = 'assets/images/characters/tr.woo_the_owl.png';
const String _trWooSmileImage = 'assets/images/characters/tr.woo_smiling.png';

const String _smirkWolfImage = 'assets/images/characters/smirk_wolf.png';
const String _wolfImage = 'assets/images/characters/wolf.png';
const String _shockWolfImage = 'assets/images/characters/shock_wolf.png';

const String _talkButton = 'assets/images/buttons/bear_talk.png';
const String _cancelButton = 'assets/images/objects/lumi/cancel_btn.png';

const String _audioBase = 'assets/audio/lumi_town/';
const String _introAudio = '${_audioBase}stranger_intro.wav';
const String _instructionAudio = '${_audioBase}stranger_instruction.wav';
const String _roxieEnterAudio = '${_audioBase}stranger_roxie_enter.wav';
const String _roxieTalkAudio = '${_audioBase}stranger_roxie_talk.wav';
const String _mamaBearEnterAudio = '${_audioBase}stranger_mama_bear_enter.wav';
const String _mamaBearTalkAudio = '${_audioBase}stranger_mama_bear_talk.wav';
const String _jackEnterAudio = '${_audioBase}stranger_jack_enter.wav';
const String _jackTalkAudio = '${_audioBase}stranger_jack_talk.wav';
const String _wolfEnterAudio = '${_audioBase}stranger_wolf_enter.wav';
const String _wolfTalkAudio = '${_audioBase}stranger_wolf_talk.wav';
const String _littleBearNoAudio = '${_audioBase}stranger_little_bear_no.wav';
const String _teacherWooWarningAudio = '${_audioBase}stranger_teacher_woo_warning.wav';
const String _safetyLessonAudio = '${_audioBase}stranger_lesson.wav';
const String _winAudio = '${_audioBase}stranger_win.wav';
const String _bubblePopAudio = 'assets/audio/sound_effects/bubble_pop.wav';

// ============================================================================
// MODEL
// ============================================================================

class StrangerInteraction {
  final String id;
  final String characterAsset;
  final String smileAsset;
  final String? talkAudio;
  final String? enterAudio;
  final bool isStranger;

  const StrangerInteraction({
    required this.id,
    required this.characterAsset,
    required this.smileAsset,
    required this.talkAudio,
    required this.enterAudio,
    this.isStranger = false,
  });
}

const StrangerInteraction _roxieScenario = StrangerInteraction(
  id: 'roxie',
  characterAsset: _roxieImage,
  smileAsset: _roxieSmileImage,
  talkAudio: _roxieTalkAudio,
  enterAudio: _roxieEnterAudio,
);

const StrangerInteraction _mamaBearScenario = StrangerInteraction(
  id: 'mama_bear',
  characterAsset: _mamaBearImage,
  smileAsset: _mamaBearSmileImage,
  talkAudio: _mamaBearTalkAudio,
  enterAudio: _mamaBearEnterAudio,
);

const StrangerInteraction _jackScenario = StrangerInteraction(
  id: 'jack',
  characterAsset: _jackImage,
  smileAsset: _jackSmileImage,
  talkAudio: _jackTalkAudio,
  enterAudio: _jackEnterAudio,
);

const StrangerInteraction _wolfScenario = StrangerInteraction(
  id: 'wolf',
  characterAsset: _wolfImage,
  smileAsset: _wolfImage,
  talkAudio: _wolfTalkAudio,
  enterAudio: _wolfEnterAudio,
  isStranger: true,
);

enum WolfVisualState { approaching, talking, shocked }

enum _GamePhase {
  intro,
  instruction,
  characterEntering,
  choosing,
  conversation,
  characterLeaving,
  wolfApproaching,
  wolfTalking,
  wolfRetreatingHalfway,
  teacherWooEntering,
  teacherWooSpeaking,
  wolfLeaving,
  safetyLesson,
  complete,
}

// ============================================================================
// SCREEN
// ============================================================================

class DontTalkToStrangersGame extends StatefulWidget {
  final int level;

  const DontTalkToStrangersGame({super.key, required this.level});

  @override
  State<DontTalkToStrangersGame> createState() =>
      _DontTalkToStrangersGameState();
}

class _DontTalkToStrangersGameState extends State<DontTalkToStrangersGame> {
  final DateTime _loadStart = DateTime.now();

  // --- Audio ----------------------------------------------------------
  final AudioPlayer _narrationPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _wolfPlayer = AudioPlayer();
  final AudioPlayer _teacherWooPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // --- Game state -------------------------------------------------------
  late List<StrangerInteraction> _interactions;
  int _currentIndex = 0;

  bool _isLoading = true;
  bool _inputEnabled = false;
  bool _busy = false;
  bool _characterVisible = false;
  bool _teacherWooVisible = false;
  bool _playgroundBgActive = false;
  bool _wolfTalkBranch = false;
  bool _showDemoButtons = false;
  bool _glowTalkButton = false;
  bool _glowCancelButton = false;
  Timer? _talkGlowTimer;
  Timer? _cancelGlowTimer;
  Timer? _cancelGlowOffTimer;
  WolfVisualState _wolfVisualState = WolfVisualState.approaching;
  _GamePhase _phase = _GamePhase.intro;
  final bool _isLoadingDelayDone = true;
  bool _gameComplete = false;
  bool _showTryAgain = false;

  StrangerInteraction get _current => _interactions[_currentIndex];

  bool get _onWolf => _current.isStranger;
  bool get _showPlaygroundBg => _playgroundBgActive && _phase != _GamePhase.characterLeaving;

  double get _characterVisibleFraction {
    if (!_characterVisible) return 0.0;
    const heldPhases = {
      _GamePhase.wolfRetreatingHalfway,
      _GamePhase.teacherWooEntering,
      _GamePhase.teacherWooSpeaking,
    };
    return heldPhases.contains(_phase) ? 0.9 : 1.0;
  }

  String get _currentDisplayAsset {
    if (_onWolf) return _wolfAsset;
    return _phase == _GamePhase.conversation
        ? _current.smileAsset
        : _current.characterAsset;
  }
  String get _teacherWooDisplayAsset {
    return _phase == _GamePhase.safetyLesson
        ? _trWooSmileImage
        : _trWooImage;
  }
  String get _littleBearDisplayAsset => _phase == _GamePhase.conversation ? _littleBearSmileImage : _littleBearImage;
  double get _littleBearLeftFactor => _phase == _GamePhase.wolfRetreatingHalfway ? 0.25 : 0.40;
  double get _littleBearVisibleFraction => _wolfTalkBranch ? 1.0 : _characterVisibleFraction;

  static const Duration _betweenCharactersDelay = Duration(milliseconds: 1500);
  static const double _wolfHeightFactor = 0.41;

  String get _wolfAsset {
    switch (_wolfVisualState) {
      case WolfVisualState.approaching:
        return _smirkWolfImage;
      case WolfVisualState.talking:
        return _wolfImage;
      case WolfVisualState.shocked:
        return _shockWolfImage;
    }
  }

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _interactions = _buildShuffledInteractions();
    _initializeGame();
  }

  List<StrangerInteraction> _buildShuffledInteractions() {
    final shuffledFirst = [_roxieScenario, _jackScenario]..shuffle(Random());
    return [...shuffledFirst, _mamaBearScenario, _wolfScenario];
  }

  Future<void> _initializeGame() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    if (_isLoadingDelayDone) {
      final elapsed = DateTime.now().difference(_loadStart);
      final remaining = const Duration(milliseconds: 1500) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      if (!mounted) return;
    }

    setState(() => _isLoading = false);

    await _startIntroFlow();
  }

  @override
  void dispose() {
    _talkGlowTimer?.cancel();
    _cancelGlowTimer?.cancel();
    _cancelGlowOffTimer?.cancel();
    _narrationPlayer.dispose();
    _completePlayer.dispose();
    _wolfPlayer.dispose();
    _teacherWooPlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  // --- Intro / instruction flow --------------------------------------------

  Future<void> _startIntroFlow() async {
    if (!mounted) return;

    setState(() {
      _phase = _GamePhase.intro;
      _inputEnabled = false;
    });

    await _playAndWait(_narrationPlayer, _introAudio);
    if (!mounted) return;

    setState(() {
      _phase = _GamePhase.instruction;
      _showDemoButtons = true;
      _glowTalkButton = false;
      _glowCancelButton = false;
    });

    _talkGlowTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _glowTalkButton = true);
    });
    _cancelGlowTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() {
        _glowTalkButton = false;
        _glowCancelButton = true;
      });

      _cancelGlowOffTimer = Timer(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        setState(() => _glowCancelButton = false);
      });
    });

    await _playAndWait(_narrationPlayer, _instructionAudio);
    if (!mounted) return;

    _talkGlowTimer?.cancel();
    _cancelGlowTimer?.cancel();
    _cancelGlowOffTimer?.cancel();

    setState(() {
      _playgroundBgActive = true;
      _showDemoButtons = false;
      _glowTalkButton = false;
      _glowCancelButton = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    await _enterCurrentCharacter();
  }

  Future<void> _playAndWait(AudioPlayer player, String asset) async {
    final completer = Completer<void>();
    late final StreamSubscription<void> sub;

    sub = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await player.stop();
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future;
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _playBubblePop() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(
        AssetSource(
          _bubblePopAudio.replaceFirst('assets/', ''),
        ),
      );
    } catch (_) {}
  }

  // --- Character entrance ---------------------------------------------------

  Future<void> _enterCurrentCharacter() async {
    if (!mounted) return;

    if (_onWolf) {
      setState(() {
        _phase = _GamePhase.wolfApproaching;
        _wolfVisualState = WolfVisualState.approaching;
        _characterVisible = false;
        _inputEnabled = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() => _characterVisible = true);

      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() => _wolfVisualState = WolfVisualState.talking);

      await _playAndWait(_wolfPlayer, _current.enterAudio!);
      if (!mounted) return;

      setState(() {
        _phase = _GamePhase.choosing;
        _inputEnabled = true;
      });
    } else {
      setState(() {
        _phase = _GamePhase.characterEntering;
        _characterVisible = false;
        _inputEnabled = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() => _characterVisible = true);

      await _playAndWait(_narrationPlayer, _current.enterAudio!);
      if (!mounted) return;

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() {
        _phase = _GamePhase.choosing;
        _inputEnabled = true;
      });
    }
  }

  // --- Familiar character choices (Roxie / Mama Bear / Jack) ----------------

  Future<void> _onFamiliarTalk() async {
    if (_onWolf || !_inputEnabled || _busy || !mounted) return;

    _playBubblePop();

    setState(() {
      _busy = true;
      _inputEnabled = false;
      _phase = _GamePhase.conversation;
    });

    await _playAndWait(_narrationPlayer, _current.talkAudio!);
    if (!mounted) return;

    await _leaveCurrentCharacterAndAdvance();
  }

  Future<void> _onFamiliarCancel() async {
    if (_onWolf || !_inputEnabled || _busy || !mounted) return;

    _playBubblePop();

    setState(() {
      _busy = true;
      _inputEnabled = false;
    });

    await _leaveCurrentCharacterAndAdvance();
  }

  Future<void> _leaveCurrentCharacterAndAdvance() async {
    if (!mounted) return;

    setState(() {
      _phase = _GamePhase.characterLeaving;
      _characterVisible = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;

    setState(() {
      _currentIndex += 1;
      _busy = false;
    });

    await Future<void>.delayed(_betweenCharactersDelay);
    if (!mounted) return;

    await _enterCurrentCharacter();
  }

  // --- Wolf choices -----------------------------------------------------

  Future<void> _onWolfCancel() async {
    if (!_onWolf || !_inputEnabled || _busy || !mounted) return;

    setState(() {
      _busy = true;
      _inputEnabled = false;
      _wolfVisualState = WolfVisualState.shocked;
    });

    await _playAndWait(_narrationPlayer, _littleBearNoAudio);
    if (!mounted) return;

    await _finishWolfSequence();
  }

  Future<void> _onWolfTalk() async {
    if (!_onWolf || !_inputEnabled || _busy || !mounted) return;

    setState(() {
      _busy = true;
      _inputEnabled = false;
      _phase = _GamePhase.wolfTalking;
      _wolfVisualState = WolfVisualState.talking;
      _wolfTalkBranch = true;
    });

    await _playAndWait(_wolfPlayer, _wolfTalkAudio);
    if (!mounted) return;

    setState(() => _phase = _GamePhase.wolfRetreatingHalfway);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _phase = _GamePhase.teacherWooEntering;
      _teacherWooVisible = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _phase = _GamePhase.teacherWooSpeaking;
      _wolfVisualState = WolfVisualState.shocked;
    });

    await _playAndWait(_teacherWooPlayer, _teacherWooWarningAudio);
    if (!mounted) return;

    setState(() => _wolfVisualState = WolfVisualState.shocked);

    await _finishWolfSequence();
  }

  Future<void> _finishWolfSequence() async {
    if (!mounted) return;

    // Wolf flips and leaves.
    setState(() {
      _phase = _GamePhase.wolfLeaving;
      _characterVisible = false;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 600),
    );
    if (!mounted) return;

    if (_wolfTalkBranch) {
      setState(() {
        _phase = _GamePhase.safetyLesson;
      });

      await _playAndWait(
        _narrationPlayer,
        _safetyLessonAudio,
      );
      if (!mounted) return;

      setState(() {
        _teacherWooVisible = false;
        _phase = _GamePhase.complete;
        _showTryAgain = true;
      });
      return;
    }

    // Both branches go to the centered Tr. Woo win scene.
    await _completeGame();
  }

  // --- Completion / restart -------------------------------------------------

  Future<void> _completeGame({bool playWinAudio = true}) async {
    if (!mounted) return;

    setState(() => _phase = _GamePhase.complete);

    TownProgressService.instance.markLevelComplete(widget.level);

    if (playWinAudio) {
      await _playAndWait(_completePlayer, _winAudio);
      if (!mounted) return;
    }

    setState(() {
      _gameComplete = true;
      _busy = false;
    });
  }

  Future<void> _restartGame() async {
    if (!mounted) return;

    setState(() {
      _interactions = _buildShuffledInteractions();
      _currentIndex = 0;
      _busy = false;
      _gameComplete = false;
      _showTryAgain = false;
      _teacherWooVisible = false;
      _wolfVisualState = WolfVisualState.approaching;
      _characterVisible = false;
      _inputEnabled = false;
      _playgroundBgActive = true;
      _wolfTalkBranch = false;
    });

    await _enterCurrentCharacter();
  }

  Future<void> _goBack() async {
    await _narrationPlayer.stop();
    await _completePlayer.stop();
    await _wolfPlayer.stop();
    await _teacherWooPlayer.stop();
    if (!mounted) return;

    setState(() {
      _playgroundBgActive = false;
      _characterVisible = false;
      _teacherWooVisible = false;
      _inputEnabled = false;
    });

    Navigator.of(context).pop();
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: LoadingScreen.lumiTown());
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: SizedBox.expand(
                key: ValueKey(_showPlaygroundBg),
                child: Image.asset(
                  _showPlaygroundBg ? _playgroundBg : _bearPlayingImage,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // WIN SCENE
                  if (_phase == _GamePhase.complete && !_gameComplete && !_showTryAgain)                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          _trWooSmileImage,
                          width: width * 0.30,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                  // NORMAL GAME SCENE
                  if (_phase != _GamePhase.complete) ...[
                    // CURRENT CHARACTER
                    _HoppingCharacter(
                      visibleFraction: _characterVisibleFraction,
                      fromLeft: true,
                      onScreenX: width * 0.10,
                      offScreenX: -width * 0.40,
                      bottom: 5,
                      height: width * (_onWolf ? _wolfHeightFactor : 0.35),
                      hopHeight: height * 0.09,
                      hops: 3,
                      duration: const Duration(milliseconds: 1200),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scaleByDouble(
                            _onWolf && _phase == _GamePhase.wolfLeaving ? -1.0 : 1.0,
                            1.0,
                            1.0,
                            1.0,
                          ),
                        child: Image.asset(
                          _currentDisplayAsset,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // LITTLE BEAR
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.linear,
                      left: width * _littleBearLeftFactor,
                      bottom: 5,
                      width: width * 0.28,
                      height: width * 0.33,
                      child: AnimatedOpacity(
                        opacity: _littleBearVisibleFraction,
                        duration: const Duration(milliseconds: 450),
                        child: Image.asset(
                          _littleBearDisplayAsset,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // TEACHER WOO
                    _HoppingCharacter(
                      visibleFraction: _teacherWooVisible ? 1.0 : 0.0,
                      fromLeft: false,
                      onScreenX: width * 0.03,
                      offScreenX: -width * 0.40,
                      bottom: -10,
                      height: width * 0.35,
                      hopHeight: height * 0.08,
                      hops: 2,
                      duration: const Duration(milliseconds: 1200),
                      child: Image.asset(
                        _teacherWooDisplayAsset,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // TALK / CANCEL BUTTONS
                    if ((_inputEnabled && !_busy) || _showDemoButtons)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ResponseButton(
                              asset: _talkButton,
                              glow: _glowTalkButton,
                              onTap: _showDemoButtons
                                  ? null
                                  : (_onWolf ? _onWolfTalk : _onFamiliarTalk),
                            ),
                            SizedBox(height: width * 0.03),
                            _ResponseButton(
                              asset: _cancelButton,
                              glow: _glowCancelButton,
                              onTap: _showDemoButtons
                                  ? null
                                  : (_onWolf ? _onWolfCancel : _onFamiliarCancel),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              );
              },
          ),

          // Back button.
          Positioned(top: 25, left: 25, child: LumiXButton()),

          // Completion overlay.
          if (_showTryAgain)
            TryJobOverlay(
              characterImage: _trWooImage,
              onRestart: _restartGame,
              onBack: _goBack,
            )
          else if (_gameComplete)
            GoodJobOverlay(
              characterImage: _trWooImage,
              onNext: () async {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => SafeOrNotGameScreen(level: widget.level + 1),
                  ),
                );
              },
              onRestart: _restartGame,
              onBack: _goBack,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// RESPONSE BUTTON — talk.png / cancel_btn.png, real assets (no generic Flutter
// buttons), large child-friendly tap target.
// ============================================================================

class _ResponseButton extends StatelessWidget {
  final String asset;
  final VoidCallback? onTap;
  final bool glow;

  const _ResponseButton({required this.asset, required this.onTap, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: glow
              ? [
            BoxShadow(
              color: Colors.yellowAccent.withValues(alpha: 0.9),
              blurRadius: 24,
              spreadRadius: 6,
            ),
          ]
              : [],
        ),
        child: Image.asset(asset, width: 110, height: 110, fit: BoxFit.contain),
      ),
    );
  }
}

// ============================================================================
// HOPPING CHARACTER — travels horizontally while arcing up and down, so the
// character looks like it's hopping on and off screen instead of gliding.
// ============================================================================

class _HoppingCharacter extends StatefulWidget {
  final double visibleFraction;
  final bool fromLeft;
  final double onScreenX;
  final double offScreenX;
  final double bottom;
  final double height;
  final double hopHeight;
  final int hops;
  final Duration duration;
  final Widget child;

  const _HoppingCharacter({
    required this.visibleFraction,
    required this.fromLeft,
    required this.onScreenX,
    required this.offScreenX,
    required this.bottom,
    required this.height,
    required this.child,
    this.hopHeight = 40,
    this.hops = 3,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<_HoppingCharacter> createState() => _HoppingCharacterState();
}

class _HoppingCharacterState extends State<_HoppingCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.visibleFraction,
  );

  @override
  void didUpdateWidget(covariant _HoppingCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visibleFraction != oldWidget.visibleFraction) {
      _c.animateTo(widget.visibleFraction);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;

        final x =
            widget.offScreenX + (widget.onScreenX - widget.offScreenX) * t;

        final phase = (t * widget.hops) % 1.0;
        final hopIndex = (t * widget.hops).floor();
        final damp = 1.0 - (0.22 * hopIndex).clamp(0.0, 0.6);
        final lift = sin(phase * pi) * widget.hopHeight * damp;

        final squash = 1.0 + (lift / widget.hopHeight) * 0.06;

        return Positioned(
          left: widget.fromLeft ? x : null,
          right: widget.fromLeft ? null : x,
          bottom: widget.bottom + lift,
          height: widget.height,
          child: Transform.scale(
            scaleY: squash,
            scaleX: 2 - squash,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
