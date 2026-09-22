import 'dart:async';
import 'dart:math';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../business_layer/town_progress_service.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../ui_layer/lumi_town/lumi_theme.dart';
import '../goodjob_prompt.dart';

// ============================================================================
// ASSETS
// ============================================================================

const String _playgroundBg = 'assets/images/backgrounds/bg_playground.png';
const String _trWooImage = 'assets/images/characters/tr.woo_the_owl.png';
const String _trWooSmileImage = 'assets/images/characters/tr.woo_smiling.png';

const String _objectBase = 'assets/images/objects/lumi/';

const String _audioBase = 'assets/audio/lumi_town/';
const String _introAudio = '${_audioBase}safe_or_not_intro.wav';
const String _instructionAudio = '${_audioBase}safe_or_not_instruction.wav';
const String _winAudio = '${_audioBase}safe_or_not_win.wav';

// ============================================================================
// MODEL
// ============================================================================

class SafeObject {
  final String name;
  final String image;
  final bool isSafe;

  const SafeObject({
    required this.name,
    required this.image,
    required this.isSafe,
  });
}

// Data-driven round list — add/remove objects here without touching game logic.
const List<SafeObject> _allObjects = [
  SafeObject(name: 'pillow', image: '${_objectBase}pillow_wb.png', isSafe: true),
  SafeObject(name: 'airplane', image: '${_objectBase}airplane_wb.png', isSafe: true),
  SafeObject(name: 'teddy_bear', image: '${_objectBase}teddybear_wb.png', isSafe: true),
  SafeObject(name: 'fire', image: '${_objectBase}fire_wb.png', isSafe: false),
  SafeObject(name: 'outlet', image: '${_objectBase}outlet_wb.png', isSafe: false),
  SafeObject(name: 'knife', image: '${_objectBase}knife_wb.png', isSafe: false),
];

enum _GamePhase { intro, instruction, playing, feedback, complete }

// ============================================================================
// SCREEN
// ============================================================================

class SafeOrNotGameScreen extends StatefulWidget {
  final int level;

  const SafeOrNotGameScreen({super.key, required this.level});

  @override
  State<SafeOrNotGameScreen> createState() => _SafeOrNotGameScreenState();
}

class _SafeOrNotGameScreenState extends State<SafeOrNotGameScreen>
    with TrWooReactionMixin {
  @override
  AudioPlayer get trWooPlayer => _narrationPlayer;

  final DateTime _loadStart = DateTime.now();

  // --- Audio ----------------------------------------------------------
  final AudioPlayer _narrationPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // --- Game state -------------------------------------------------------
  late List<SafeObject> _objects;
  int _currentRound = 0;
  int _secondsRemaining = 5;

  bool _roundActive = false;
  bool _answerLocked = false;

  Timer? _countdownTimer;

  bool _isLoading = true;
  _GamePhase _phase = _GamePhase.intro;
  bool _gameComplete = false;

  SafeObject get _currentObject => _objects[_currentRound];

  static const int _roundSeconds = 5;
  static const Duration _betweenRoundsDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    // Gameplay starts directly from initState — do not gate on any
    // face-detection/camera callback, per established StarSight pattern.
    OrientationService.setLandscape();
    _objects = _buildShuffledObjects();
    _initializeGame();
  }

  List<SafeObject> _buildShuffledObjects() {
    final shuffled = List<SafeObject>.from(_allObjects)..shuffle(Random());
    return shuffled;
  }

  Future<void> _initializeGame() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final elapsed = DateTime.now().difference(_loadStart);
    final remaining = const Duration(milliseconds: 1500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;

    setState(() => _isLoading = false);

    await _startIntroFlow();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _narrationPlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  // --- Intro / instruction flow --------------------------------------------

  Future<void> _startIntroFlow() async {
    if (!mounted) return;

    setState(() => _phase = _GamePhase.intro);
    await _playAndWait(_narrationPlayer, _introAudio);
    if (!mounted) return;

    setState(() => _phase = _GamePhase.instruction);
    await _playAndWait(_narrationPlayer, _instructionAudio);
    if (!mounted) return;

    _startRound();
  }

  Future<void> _playAndWait(AudioPlayer player, String asset) async {
    final completer = Completer<void>();
    late final StreamSubscription<void> sub;

    sub = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await player.stop();
      // AssetSource must not receive a path that already includes the
      // 'assets/' prefix, or the path gets doubled.
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future;
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    } finally {
      await sub.cancel();
    }
  }

  // --- Round lifecycle -------------------------------------------------

  void _startRound() {
    if (!mounted) return;

    // Always cancel any prior timer before starting a new one — the
    // previous round's timer must never keep ticking into the next round.
    _countdownTimer?.cancel();

    setState(() {
      _secondsRemaining = _roundSeconds;
      _roundActive = true;
      _answerLocked = false;
      _phase = _GamePhase.playing;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    if (!mounted || !_roundActive || _answerLocked) {
      timer.cancel();
      return;
    }

    final next = _secondsRemaining - 1;
    if (next <= 0) {
      timer.cancel();
      setState(() => _secondsRemaining = 0);
      _onTimerExpired();
    } else {
      setState(() => _secondsRemaining = next);
    }
  }

  void _handleObjectTap() {
    if (!_roundActive || _answerLocked || _phase != _GamePhase.playing) {
      return;
    }

    _countdownTimer?.cancel();

    final correct = _currentObject.isSafe;
    _evaluateRound(correct: correct);
  }

  void _onTimerExpired() {
    if (_answerLocked || !mounted) return;

    final correct = !_currentObject.isSafe;
    _evaluateRound(correct: correct);
  }

  Future<void> _evaluateRound({required bool correct}) async {
    if (_answerLocked || !mounted) return;

    _countdownTimer?.cancel();

    setState(() {
      _answerLocked = true;
      _roundActive = false;
      _phase = _GamePhase.feedback;
    });

    if (correct) {
      unawaited(showTrWooReaction(TrWooState.correct));
      await Future.delayed(const Duration(milliseconds: 1500));
    } else {
      await showTrWooReaction(TrWooState.wrong);
    }
    if (!mounted) return;

    await _advanceRound();
  }

  Future<void> _advanceRound() async {
    if (!mounted) return;

    if (_currentRound + 1 >= _objects.length) {
      await _completeGame();
      return;
    }

    setState(() => _currentRound += 1);

    await Future.delayed(_betweenRoundsDelay);
    if (!mounted) return;

    _startRound();
  }

  // --- Completion / restart -------------------------------------------------

  Future<void> _completeGame() async {
    if (!mounted) return;

    _countdownTimer?.cancel();
    setState(() {
      _phase = _GamePhase.complete;
      _roundActive = false;
    });

    TownProgressService.instance.markLevelComplete(widget.level);

    await _playAndWait(_narrationPlayer, _winAudio);
    if (!mounted) return;

    setState(() => _gameComplete = true);
  }

  Future<void> _restartGame() async {
    if (!mounted) return;

    _countdownTimer?.cancel();
    setState(() {
      _objects = _buildShuffledObjects();
      _currentRound = 0;
      _secondsRemaining = _roundSeconds;
      _roundActive = false;
      _answerLocked = false;
      _gameComplete = false;
      _phase = _GamePhase.intro;
    });

    await _startIntroFlow();
  }

  Future<void> _goBack() async {
    _countdownTimer?.cancel();
    await _narrationPlayer.stop();
    await _sfxPlayer.stop();
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: LoadingScreen.lumiTown());
    }

    final showIntroScene =
        _phase == _GamePhase.intro || _phase == _GamePhase.instruction;
    final showGameplayScene = !showIntroScene && _phase != _GamePhase.complete;
    final showWinScene = _phase == _GamePhase.complete && !_gameComplete;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(_playgroundBg, fit: BoxFit.cover),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // INTRO / INSTRUCTION — Tr. Woo introduces the game.
                  if (showIntroScene)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          _trWooImage,
                          width: width * 0.30,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                  // WIN SCENE
                  if (showWinScene)
                    Positioned(
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

                  // GAMEPLAY
                  if (showGameplayScene) ...[
                    // Countdown — large, but kept clear of the object itself.
                    Positioned(
                      right: 15,
                      bottom: 15,
                      child: Center(
                        child: _CountdownBadge(seconds: _secondsRemaining),
                      ),
                    ),

                    // Progress indicator.
                    Positioned(
                      bottom: 15,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _RoundDots(
                          current: _currentRound,
                          total: _objects.length,
                        ),
                      ),
                    ),

                    // The object — the tap target IS the answer, no buttons.
                    Center(
                      child: GestureDetector(
                        onTap: _handleObjectTap,
                        child: SizedBox(
                          width: width * 0.32,
                          height: width * 0.32,
                          child: Image.asset(
                            _currentObject.image,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    buildTrWoo(context),
                  ],
                ],
              );
            },
          ),

          // Back button.
          Positioned(top: 25, left: 25, child: LumiXButton()),

          // Completion overlay.
          if (_gameComplete)
            GoodJobOverlay(
              characterImage: _trWooImage,
              onNext: () async {
                // TODO: point this at whatever Lumi Town level follows.
                // Navigator.of(context).pushReplacement(
                //   MaterialPageRoute(
                //     builder: (_) => (level: widget.level + 1),
                //   ),
                // );
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
// SUPPORTING WIDGETS
// ============================================================================

class _CountdownBadge extends StatelessWidget {
  final int seconds;

  const _CountdownBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Container(
        key: ValueKey(seconds),
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LumiColorTheme.rust.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: LumiColorTheme.rust, width: 4),
        ),
        child: Text(
          '$seconds',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RoundDots extends StatelessWidget {
  final int total;
  final int current;

  const _RoundDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        final done = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? Colors.greenAccent.withValues(alpha: 0.9)
                : active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}