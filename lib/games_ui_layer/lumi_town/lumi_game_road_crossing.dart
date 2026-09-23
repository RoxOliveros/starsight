import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/ui_layer/loading_screen.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_buttons.dart';
import '../goodjob_prompt.dart';
import '../tryagain_prompt.dart';

// ============================================================
// ASSET PATHS
// ============================================================

const String _bgRedLight = 'assets/images/backgrounds/bg_crossing_redlight.png';
const String _bgGreenLight = 'assets/images/backgrounds/bg_crossing_greenlight.png';
const String _carPassingBy = 'assets/animations/lumi_town/crossing_redlight_car_passingby.webp';
const String _redBump = 'assets/animations/lumi_town/crossing_redlight_bump.webp';
const String _redGoodJob = 'assets/animations/lumi_town/crossing_redlight_goodjob.webp';
const String _greenRoxieWalk = 'assets/animations/lumi_town/crossing_greenlight_roxiewalk.webp';
const String _thumbsUp = 'assets/images/buttons/thumbs_up.png';
const String _thumbsDown = 'assets/images/buttons/thumbs_down.png';
const String _trWooImage = 'assets/images/characters/tr.woo_the_owl.png';
const String _trWooSmileImage = 'assets/images/characters/tr.woo_smiling.png';
const String _roxieImage = 'assets/images/characters/roxie_the_rabbit.png';
const String _roxieSmileImage = 'assets/images/characters/roxie_happy.png';

// Audio
const String _audioIntro = 'assets/audio/lumi_town/crossing_game_intro.wav';
const String _audioInstruction = 'assets/audio/lumi_town/crossing_game_instruction.wav';
const String _audioRedLight = 'assets/audio/lumi_town/crossing_game_redlight.wav';
const String _audioRedLightCorrect = 'assets/audio/lumi_town/crossing_game_redlight_correct.wav';
const String _audioRedLightWrong = 'assets/audio/lumi_town/crossing_game_redlight_wrong.wav';
const String _audioGreenLight = 'assets/audio/lumi_town/crossing_game_greenlight.wav';
const String _audioGreenLightCorrect = 'assets/audio/lumi_town/crossing_game_greenlight_correct.wav';
const String _audioGreenLightWrong = 'assets/audio/lumi_town/crossing_game_greenlight_wrong.wav';
const String _audioWin = 'assets/audio/lumi_town/crossing_game_win.wav';

enum _Phase {
  intro,
  instruction,
  round1Narration,
  round1Answer,
  round1Correct,
  round1Wrong,
  round2Narration,
  round2Answer,
  round2Correct,
  round2Wrong,
  completed,
}

class CrossingGameScreen extends StatefulWidget {
  final int level;

  const CrossingGameScreen({super.key, required this.level});

  @override
  State<CrossingGameScreen> createState() => _CrossingGameScreenState();
}

class _CrossingGameScreenState extends State<CrossingGameScreen>
    with TrWooReactionMixin {
  // Audio players
  final AudioPlayer _narrationPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _trWooAudioPlayer = AudioPlayer();

  @override
  AudioPlayer get trWooPlayer => _trWooAudioPlayer;

  // Loading
  bool _isLoading = true;
  late final DateTime _loadStart;
  static const _minLoadTime = Duration(milliseconds: 1500);

  // Flow state
  _Phase _phase = _Phase.intro;

  // Input safety
  bool _inputEnabled = false;
  bool _isProcessing = false;

  // Instruction glow
  bool _thumbsUpGlow = false;
  bool _thumbsDownGlow = false;
  Timer? _glowUpTimer;
  Timer? _glowUpOffTimer;
  Timer? _glowDownTimer;
  Timer? _glowDownOffTimer;

  // Wrong-answer "Try Again" gating
  bool _showTryAgain = false;

  // Completion
  bool _playingWin = false;
  bool _gameComplete = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _loadStart = DateTime.now();
    _init();
  }

  Future<void> _init() async {
    final elapsed = DateTime.now().difference(_loadStart);
    final remaining = _minLoadTime - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    await _startIntroFlow();
  }

  // ------------------------------------------------------------
  // Audio helper
  // ------------------------------------------------------------

  Future<void> _playAndWait(AudioPlayer player, String assetPath) async {
    try {
      await player.stop();
      final completer = Completer<void>();
      late final StreamSubscription sub;
      sub = player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      });
      await player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
      await completer.future;
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // Intro / Instruction
  // ------------------------------------------------------------

  Future<void> _startIntroFlow() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.intro);
    await _playAndWait(_narrationPlayer, _audioIntro);
    if (!mounted) return;
    await _startInstruction();
  }

  Future<void> _startInstruction() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.instruction);
    _scheduleGlowTimers();
    await _playAndWait(_narrationPlayer, _audioInstruction);
    _cancelGlowTimers();
    if (!mounted) return;
    await _startRound1Narration();
  }

  void _scheduleGlowTimers() {
    _glowUpTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _thumbsUpGlow = true);
      _glowUpOffTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _thumbsUpGlow = false);
      });
    });
    _glowDownTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() => _thumbsDownGlow = true);
      _glowDownOffTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _thumbsDownGlow = false);
      });
    });
  }

  void _cancelGlowTimers() {
    _glowUpTimer?.cancel();
    _glowUpOffTimer?.cancel();
    _glowDownTimer?.cancel();
    _glowDownOffTimer?.cancel();
    _thumbsUpGlow = false;
    _thumbsDownGlow = false;
  }

  Future<void> _waitForWebp() async {
    await Future.delayed(const Duration(milliseconds: 3000));
  }

  // ------------------------------------------------------------
  // Round 1 — Red Light (correct answer: DON'T CROSS / thumbs down)
  // ------------------------------------------------------------

  Future<void> _startRound1Narration() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.round1Narration;
      _inputEnabled = false;
      _showTryAgain = false;
    });
    await _playAndWait(_narrationPlayer, _audioRedLight);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.round1Answer;
      _inputEnabled = true;
      _isProcessing = false;
    });
  }

  Future<void> _handleRound1Answer(bool choseCross) async {
    if (!_inputEnabled || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _inputEnabled = false;
    });

    if (!choseCross) {
      // Correct: DON'T CROSS on red.
      setState(() => _phase = _Phase.round1Correct);

      // Let the WebP play/be visible first.
      await _waitForWebp();

      if (!mounted) return;

      // Then play the explanation.
      await _playAndWait(
        _narrationPlayer,
        _audioRedLightCorrect,
      );

      if (!mounted) return;

      // Then continue to Round 2.
      await _startRound2Narration();
    } else {
      // Wrong: chose CROSS on red.
      setState(() => _phase = _Phase.round1Wrong);

      await _waitForWebp();

      if (!mounted) return;

      await _playAndWait(
        _narrationPlayer,
        _audioRedLightWrong,
      );

      if (!mounted) return;

      setState(() => _showTryAgain = true);
    }
  }

  Future<void> _retryRound1() async {
    setState(() {
      _showTryAgain = false;
      _isProcessing = false;
    });
    await _startRound1Narration();
  }

  // ------------------------------------------------------------
  // Round 2 — Green Light (correct answer: CROSS / thumbs up)
  // ------------------------------------------------------------

  Future<void> _startRound2Narration() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.round2Narration;
      _inputEnabled = false;
      _showTryAgain = false;
    });
    await _playAndWait(_narrationPlayer, _audioGreenLight);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.round2Answer;
      _inputEnabled = true;
      _isProcessing = false;
    });
  }

  Future<void> _handleRound2Answer(bool choseCross) async {
    if (!_inputEnabled || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _inputEnabled = false;
    });

    if (choseCross) {
      // Correct: CROSS on green.
      setState(() => _phase = _Phase.round2Correct);

      showTrWooReaction(TrWooState.correct);

      await _waitForWebp();

      if (!mounted) return;

      // AFTER
      await _playAndWait(
        _narrationPlayer,
        _audioGreenLightCorrect,
      );

      if (!mounted) return;

      setState(() => _playingWin = true);

      await _playAndWait(
        _completePlayer,
        _audioWin,
      );

      if (!mounted) return;

      setState(() => _playingWin = false);

      setState(() {
        _phase = _Phase.completed;
        _gameComplete = true;
      });
    } else {
      setState(() => _phase = _Phase.round2Wrong);

      await _waitForWebp();

      if (!mounted) return;

      await _playAndWait(
        _narrationPlayer,
        _audioGreenLightWrong,
      );

      if (!mounted) return;

      setState(() => _showTryAgain = true);
    }
  }

  Future<void> _retryRound2() async {
    setState(() {
      _showTryAgain = false;
      _isProcessing = false;
    });
    await _startRound2Narration();
  }

  // ------------------------------------------------------------
  // Completion overlay callbacks
  // ------------------------------------------------------------

  void _onRestart() {
    _cancelGlowTimers();
    setState(() {
      _gameComplete = false;
      _showTryAgain = false;
      _isProcessing = false;
      _inputEnabled = false;
    });
    _startRound1Narration();
  }

  Future<void> _goBack() async {
    await _narrationPlayer.stop();
    await _completePlayer.stop();
    await _trWooAudioPlayer.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _cancelGlowTimers();
    _narrationPlayer.dispose();
    _completePlayer.dispose();
    _trWooAudioPlayer.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Helpers for what to render
  // ------------------------------------------------------------

  bool get _buttonsVisible =>
      _phase == _Phase.instruction ||
      _phase == _Phase.round1Answer ||
      _phase == _Phase.round2Answer;

  bool get _buttonsInteractive =>
      (_phase == _Phase.round1Answer || _phase == _Phase.round2Answer) &&
      _inputEnabled &&
      !_isProcessing;

  String get _backgroundAsset {
    if (_playingWin || _gameComplete) return _bgGreenLight;

    switch (_phase) {
      case _Phase.intro:
        return _carPassingBy;
      case _Phase.instruction:
      case _Phase.round1Narration:
      case _Phase.round1Answer:
        return _bgRedLight;
      case _Phase.round1Correct:
        return _redGoodJob;
      case _Phase.round1Wrong:
        return _redBump;
      case _Phase.round2Narration:
      case _Phase.round2Answer:
        return _bgGreenLight;
      case _Phase.round2Correct:
        return _greenRoxieWalk;
      case _Phase.round2Wrong:
        return _carPassingBy;
      case _Phase.completed:
        return _bgGreenLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: LoadingScreen.lumiTown(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: Image.asset(
                    _backgroundAsset,
                    key: ValueKey(_backgroundAsset),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),

              if (_playingWin || _gameComplete)
                  Positioned(
                  top: 75,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      height: h * 0.5,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Image.asset(_roxieSmileImage, fit: BoxFit.contain),
                          const SizedBox(width: 16),
                          Image.asset(_trWooSmileImage, fit: BoxFit.contain),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_backgroundAsset == _bgRedLight || _backgroundAsset == _bgGreenLight)
                Positioned(
                  top: 75,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      height: h * 0.5,
                      child: Image.asset(
                        _roxieImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

              // Decision buttons
              if (_buttonsVisible) ...[
                Positioned(
                  left: w * 0.04,
                  bottom: h * 0.06,
                  child: _DecisionButton(
                    assetPath: _thumbsDown,
                    size: w * 0.16,
                    glowing: _thumbsDownGlow,
                    enabled: _buttonsInteractive,
                    onTap: () {
                      if (_phase == _Phase.round1Answer) {
                        _handleRound1Answer(false);
                      } else if (_phase == _Phase.round2Answer) {
                        _handleRound2Answer(false);
                      }
                    },
                  ),
                ),
                Positioned(
                  right: w * 0.04,
                  bottom: h * 0.06,
                  child: _DecisionButton(
                    assetPath: _thumbsUp,
                    size: w * 0.16,
                    glowing: _thumbsUpGlow,
                    enabled: _buttonsInteractive,
                    onTap: () {
                      if (_phase == _Phase.round1Answer) {
                        _handleRound1Answer(true);
                      } else if (_phase == _Phase.round2Answer) {
                        _handleRound2Answer(true);
                      }
                    },
                  ),
                ),
              ],

              // Back button
              Positioned(
                top: 25,
                left: 25,
                child: LumiXButton(onTap: _goBack),
              ),

              // Try Again prompt after a wrong-answer explanation finishes
              if (_showTryAgain)
                TryJobOverlay(
                  characterImage: _trWooImage,
                  onRestart: () {
                    if (_phase == _Phase.round1Wrong) {
                      _retryRound1();
                    } else if (_phase == _Phase.round2Wrong) {
                      _retryRound2();
                    }
                  },
                  onBack: _goBack,
                ),

              // Completion overlay
              if (_gameComplete)
                GoodJobOverlay(
                  characterImage: _trWooImage,
                  onRestart: _onRestart,
                  onBack: _goBack,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ==================================================================
// Decision button — large, child-friendly tap target with pulse glow
// ==================================================================

class _DecisionButton extends StatelessWidget {
  final String assetPath;
  final double size;
  final bool glowing;
  final bool enabled;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.assetPath,
    required this.size,
    required this.glowing,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: glowing ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: glowing
                ? [
                    BoxShadow(
                      color: Colors.yellowAccent.withValues(alpha: 0.85),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ]
                : [],
          ),
          child: Opacity(
            opacity: enabled || glowing ? 1.0 : 0.6,
            child: Image.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
