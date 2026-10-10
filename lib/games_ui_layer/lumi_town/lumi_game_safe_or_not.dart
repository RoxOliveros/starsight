import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../business_layer/orientation_service.dart';
import '../../business_layer/town_progress_service.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../ui_layer/lumi_town/lumi_theme.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import 'lumi_game_road_crossing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';
import 'lumi_game_ui_layer.dart';

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

const List<SafeObject> _allObjects = [
  SafeObject(
    name: 'pillow',
    image: '${_objectBase}pillow_wb.png',
    isSafe: true,
  ),
  SafeObject(
    name: 'airplane',
    image: '${_objectBase}airplane_wb.png',
    isSafe: true,
  ),
  SafeObject(
    name: 'teddy_bear',
    image: '${_objectBase}teddybear_wb.png',
    isSafe: true,
  ),
  SafeObject(name: 'fire', image: '${_objectBase}fire_wb.png', isSafe: false),
  SafeObject(
    name: 'outlet',
    image: '${_objectBase}outlet_wb.png',
    isSafe: false,
  ),
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
    with
        TrWooReactionMixin,
        AiCameraMixin<SafeOrNotGameScreen>,
        AppAudioLifecycleMixin<SafeOrNotGameScreen> {

  final DateTime _loadStart = DateTime.now();

  // --- Audio ----------------------------------------------------------
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _trWooPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _trWooPlayer];

  @override
  AudioPlayer get trWooPlayer => _trWooPlayer;

  // --- Tracker State --------------------------------------------------
  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

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
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

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
    disposeAiCamera();
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    _trWooPlayer.dispose();
    super.dispose();
  }

  // --- Intro / instruction flow --------------------------------------------

  Future<void> _startIntroFlow() async {
    if (!mounted) return;

    setState(() => _phase = _GamePhase.intro);
    await playAssetAudio(_audioPlayer, _introAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    setState(() => _phase = _GamePhase.instruction);
    await playAssetAudio(_audioPlayer, _instructionAudio);
    await waitForAudio(_audioPlayer);
    if (!mounted) return;

    _startRound();
  }

  // --- Round lifecycle -------------------------------------------------

  void _startRound() {
    if (!mounted) return;

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

    if (correct) {
      _tapTracker.recordCorrectTap();
    } else {
      _tapTracker.recordMistake();
    }

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
      unawaited(_trWooPlayer.stop());
      showTrWooReaction(TrWooState.correct);
      await Future.delayed(const Duration(milliseconds: 1500));
    } else {
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTrWooReaction(TrWooState.wrong);
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

    if (!_hasSavedResult) {
      _hasSavedResult = true;
      List<String> finalEmotions = stopAiCamera();

      TownDatabaseService.saveGameData(
        gameId: 'lumi_town_safe_or_not',
        activityName: 'Safe Or Not',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      ).catchError((e) {
        debugPrint("Database Error saving metrics: $e");
      });
    }

    TownProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
    });

    await playAssetAudio(_audioPlayer, _winAudio);
    await waitForAudio(_audioPlayer);
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
      _hasSavedResult = false;
      _tapTracker.startSession();
    });

    await _startIntroFlow();
  }

  Future<void> _goBack() async {
    _countdownTimer?.cancel();
    await _audioPlayer.stop();
    await _trWooPlayer.stop();
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
      body: Listener(
        onPointerDown: (_) => _tapTracker.recordGenericTap(),
        child: Stack(
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

                    if (showGameplayScene) ...[
                      Positioned(
                        right: 15,
                        bottom: 15,
                        child: Center(
                          child: _CountdownBadge(seconds: _secondsRemaining),
                        ),
                      ),

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

                      Center(
                        child: SizedBox(
                          width: width * 0.32,
                          height: width * 0.32,
                          child: AlphaHitImage(
                            asset: _currentObject.image,
                            onTap: _handleObjectTap,
                          ),
                        ),
                      ),

                      buildTrWoo(context),
                    ],
                  ],
                );
              },
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LumiLevelBadge(level: widget.level),
            ),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_gameComplete)
              GoodJobOverlay(
                characterImage: _trWooImage,
                onNext: () async {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          CrossingGameScreen(level: widget.level + 1),
                    ),
                  );
                },
                onRestart: _restartGame,
                onBack: _goBack,
              ),
          ],
        ),
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

class _PixelData {
  final int w, h;
  final ByteData bytes;
  _PixelData(this.w, this.h, this.bytes);
}

/// Image that only reports taps on non-transparent pixels.
class AlphaHitImage extends StatefulWidget {
  final String asset;
  final VoidCallback onTap;
  final int alphaThreshold; // 0-255, pixel counts as "solid" above this
  final int tolerancePx; // forgiveness around edges, in decoded-image pixels

  const AlphaHitImage({
    super.key,
    required this.asset,
    required this.onTap,
    this.alphaThreshold = 40,
    this.tolerancePx = 6,
  });

  @override
  State<AlphaHitImage> createState() => _AlphaHitImageState();
}

class _AlphaHitImageState extends State<AlphaHitImage> {
  static final Map<String, _PixelData> _cache = {};
  _PixelData? _data;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AlphaHitImage old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) _resolve();
  }

  void _resolve() {
    final cached = _cache[widget.asset];
    if (cached != null) {
      _data = cached;
      return;
    }
    _data = null;
    _load(widget.asset);
  }

  Future<void> _load(String asset) async {
    try {
      final raw = await rootBundle.load(asset);
      // Downscale: we only need alpha, not full resolution
      final codec = await ui.instantiateImageCodec(
        raw.buffer.asUint8List(),
        targetWidth: 256,
      );
      final img = (await codec.getNextFrame()).image;
      final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return;
      final data = _PixelData(img.width, img.height, bytes);
      _cache[asset] = data;
      if (mounted && widget.asset == asset) setState(() => _data = data);
    } catch (e) {
      debugPrint('AlphaHitImage load error ($asset): $e');
    }
  }

  bool _isSolid(Offset p, Size box) {
    final d = _data;
    if (d == null) return false;

    // Map the tap through BoxFit.contain
    final scale = min(box.width / d.w, box.height / d.h);
    final ox = (box.width - d.w * scale) / 2;
    final oy = (box.height - d.h * scale) / 2;
    final cx = ((p.dx - ox) / scale).round();
    final cy = ((p.dy - oy) / scale).round();

    final t = widget.tolerancePx;
    for (int dy = -t; dy <= t; dy += 2) {
      for (int dx = -t; dx <= t; dx += 2) {
        if (dx * dx + dy * dy > t * t) continue; // circular tolerance
        final x = cx + dx, y = cy + dy;
        if (x < 0 || y < 0 || x >= d.w || y >= d.h) continue;
        final alpha = d.bytes.getUint8((y * d.w + x) * 4 + 3);
        if (alpha > widget.alphaThreshold) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (_isSolid(details.localPosition, box)) widget.onTap();
          },
          child: Image.asset(widget.asset, fit: BoxFit.contain),
        );
      },
    );
  }
}
