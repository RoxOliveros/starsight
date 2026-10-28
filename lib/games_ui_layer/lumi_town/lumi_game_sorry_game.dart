import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/business_layer/gesture_camera_view.dart';
import 'package:StarSight/business_layer/town_database_service.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lumi_game_picking_trash_game.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/game_loading_mixin.dart';
import '../../../ui_layer/loading_screen.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../ui_layer/lumi_town/town_level.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'lumi_game_ui_layer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _lumi = 'assets/images/objects/lumi';
const _chars = 'assets/images/characters';
const _audio9 = 'assets/audio/lumi_town/level9';

/// The story, in order. Each stage was its own screen (sorry_1 … sorry_8).
enum _SorryStage {
  intro, // sorry_1: narration over scene 1
  meetBear, // sorry_2: owl + bear walks in and cries
  thumbs, // sorry_3: thumbs up / thumbs down question
  jackArrives, // sorry_4: Jack walks in with the car
  puzzleSorry, // sorry_5: "I'M SORRY LITTLE BEAR" puzzle
  jackSad, // sorry_6: short narration scene
  puzzleRules, // sorry_7: two-row sentence puzzle
  reconcile, // sorry_8: Jack gives the car back + good job
}

enum _CameraGestureState { checking, granted, denied }

class _Piece {
  final String id;
  final String slotAsset; // empty slot art (empty for distractors)
  final String pieceAsset; // art for the draggable piece and the filled slot

  const _Piece(this.id, this.slotAsset, this.pieceAsset);
}

const _pIm = _Piece('IM', '$_lumi/im_placeholder.png', '$_lumi/im_rp.png');
const _pSorry = _Piece(
  'SORRY',
  '$_lumi/sorry_placeholder.png',
  '$_lumi/sorry_rp.png',
);
const _pLittleBear = _Piece(
  'LITTLE_BEAR',
  '$_lumi/littlebear_placeholder.png',
  '$_lumi/littlebear_rp.png',
);
const _pKinuhaKo = _Piece(
  'KINUHA_KO',
  '$_lumi/kinuhako_placeholder.png',
  '$_lumi/kinuhako_rp.png',
);
const _pAng = _Piece('ANG', '$_lumi/ang_placeholder.png', '$_lumi/ang_rp.png');
const _pLaruanMo = _Piece(
  'LARUAN_MO',
  '$_lumi/laruanmo_placeholder.png',
  '$_lumi/laruanmo_rp.png',
);
const _pHindi = _Piece(
  'HINDI',
  '$_lumi/hindi_placeholder.png',
  '$_lumi/hindi_rp.png',
);
const _pKoNa = _Piece(
  'KO_NA',
  '$_lumi/kona_placeholder.png',
  '$_lumi/kona_rp.png',
);
const _pUulitin = _Piece(
  'UULITIN',
  '$_lumi/uulitin_placeholder.png',
  '$_lumi/uulitin_rp.png',
);
const _pPangitKa = _Piece('PANGIT_KA', '', '$_lumi/pangitka_wp.png');
const _pIbabalik = _Piece('IBABALIK', '', '$_lumi/ibabalik_wp.png');

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SorryGameScreen extends StatefulWidget {
  final int level;

  const SorryGameScreen({super.key, required this.level});

  @override
  State<SorryGameScreen> createState() => _SorryGameScreenState();
}

/// Keeps old call sites (`Sorry1Screen(level: ...)`) working.
typedef Sorry1Screen = SorryGameScreen;

class _SorryGameScreenState extends State<SorryGameScreen>
    with
        TickerProviderStateMixin,
        AiCameraMixin<SorryGameScreen>,
        GameLoadingMixin,
        AppAudioLifecycleMixin<SorryGameScreen>,
        TrWooReactionMixin,
        IdleHintMixin {
  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _trWooPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _trWooPlayer];

  @override
  AudioPlayer get trWooPlayer => _trWooPlayer;

  // ── Shared state ───────────────────────────────────────────────────────────
  final GameTapTracker _tapTracker = GameTapTracker();

  _SorryStage _stage = _SorryStage.intro;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _showGoodJob = false;

  // ── Animations ─────────────────────────────────────────────────────────────
  static const Duration _enterDuration = Duration(milliseconds: 1800);
  static const Duration _stepDuration = Duration(milliseconds: 260);
  static const double _bounceHeightFraction = 0.045;

  /// Used by both "walks in from the right" scenes (bear, then Jack).
  late final AnimationController _enterController;
  late final AnimationController _meetController;
  late final AnimationController _carSlideController;
  late final AnimationController _jumpController;

  // ── meetBear ───────────────────────────────────────────────────────────────
  bool _bearCrying = false;

  // ── thumbs ─────────────────────────────────────────────────────────────────
  static const Duration _noHandsTimeout = Duration(seconds: 8);
  StreamSubscription<Duration>? _positionSub;
  Timer? _noHandsTimer;
  _CameraGestureState _cameraState = _CameraGestureState.checking;
  bool _showScene4 = false;
  bool _introFinished = false;
  bool _actionTaken = false;
  bool _showButtons = false;
  final Completer<void> _promptDone = Completer<void>();
  final Completer<void> _thumbsDone = Completer<void>();

  // ── puzzles ────────────────────────────────────────────────────────────────
  final Set<String> _placed = {};
  bool _canDrag = false;
  int _rulesPhase = 1;

  Completer<void>? _placementWait;
  Set<String> _placementTarget = {};

  // ── how to play ────────────────────────────────────────────────────────────
  List<String> _hintIds = const [];
  final Map<String, GlobalKey> _pieceKeys = {};
  final Map<String, GlobalKey> _slotKeys = {};

  // ── reconcile ──────────────────────────────────────────────────────────────
  bool _isCarWithJack = true;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _enterController = AnimationController(vsync: this, duration: _enterDuration);
    _meetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _carSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    finishLoading(_runStory);
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _noHandsTimer?.cancel();
    _positionSub?.cancel();
    _enterController.dispose();
    _meetController.dispose();
    _carSlideController.dispose();
    _jumpController.dispose();
    _audioPlayer.dispose();
    _trWooPlayer.dispose();
    super.dispose();
  }

  // ── Story script ───────────────────────────────────────────────────────────
  Future<void> _runStory() async {
    try {
      await _stageIntro();
      if (!mounted) return;
      await _stageMeetBear();
      if (!mounted) return;
      await _stageThumbs();
      if (!mounted) return;
      await _stageJackArrives();
      if (!mounted) return;
      await _stagePuzzleSorry();
      if (!mounted) return;
      await _stageJackSad();
      if (!mounted) return;
      await _stagePuzzleRules();
      if (!mounted) return;
      await _stageReconcile();
    } catch (e, stackTrace) {
      debugPrint('[Sorry] ERROR in story: $e');
      debugPrint('[Sorry] Stack trace: $stackTrace');
    }
  }

  void _enter(_SorryStage stage) {
    if (!mounted) return;
    cancelIdleTimer();
    setState(() {
      _stage = stage;
      showHowToPlay = false;
    });
  }

  /// Plays a voice line. Errors are logged and the story keeps going.
  Future<void> _say(String asset) async {
    try {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, asset);
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  /// Restart the hint countdown. Call whenever the child can start acting.
  void _armHint() {
    if (!mounted) return;
    setState(() => showHowToPlay = false);
    startIdleTimer();
  }

  // ── Stage 1: intro ─────────────────────────────────────────────────────────
  Future<void> _stageIntro() async {
    _enter(_SorryStage.intro);
    await _say('$_audio9/sorry_narration_1.wav');
  }

  // ── Stage 2: meet the bear ─────────────────────────────────────────────────
  Future<void> _stageMeetBear() async {
    _enterController.value = 0;
    _enter(_SorryStage.meetBear);

    await _say('$_audio9/sorry_narration_2.wav');
    if (!mounted) return;

    await _enterController.forward(from: 0);
    if (!mounted) return;

    setState(() => _bearCrying = true);
    await _say('$_audio9/sorry_1.wav');
  }

  // ── Stage 3: thumbs up / thumbs down ───────────────────────────────────────
  Future<void> _stageThumbs() async {
    _enter(_SorryStage.thumbs);
    _requestCameraPermission();

    try {
      _positionSub = _audioPlayer.onPositionChanged.listen((position) {
        if (position >= const Duration(seconds: 4) && !_showScene4) {
          if (mounted) setState(() => _showScene4 = true);
          _positionSub?.cancel();
        }
      });

      await _say('$_audio9/sorry_2.wav');
      _positionSub?.cancel();
      if (!mounted) return;

      if (!_showScene4) setState(() => _showScene4 = true);

      await _say('$_audio9/sorry_3.wav');
      if (!mounted) return;

      setState(() => _introFinished = true);
      await _playThumbsPrompt();
    } catch (e) {
      debugPrint('Error in thumbs stage: $e');
      if (mounted) setState(() => _introFinished = true);
      if (!_promptDone.isCompleted) _promptDone.complete();
    }

    await _thumbsDone.future;
    _noHandsTimer?.cancel();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _cameraState = status.isGranted
          ? _CameraGestureState.granted
          : _CameraGestureState.denied;
    });
  }

  Future<void> _playThumbsPrompt() async {
    try {
      final done = _audioPlayer.onPlayerComplete.first;
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        'assets/audio/lumi_town/thumbsup_thumbsdown.wav',
      );
      await done;
    } catch (e) {
      debugPrint('Error playing thumbsup_thumbsdown.wav: $e');
    } finally {
      if (!_promptDone.isCompleted) _promptDone.complete();
      _startNoHandsTimer();
      _armHint();
    }
  }

  void _startNoHandsTimer() {
    _noHandsTimer?.cancel();
    if (_showButtons || !mounted || !_promptDone.isCompleted) return;
    _noHandsTimer = Timer(_noHandsTimeout, () {
      if (!mounted) return;
      setState(() {
        _showButtons = true;
        showHowToPlay = false;
      });
      startIdleTimer(); // hint shows 5s after the buttons appear
    });
  }

  Future<void> _handleThumbsUp() async {
    if (_actionTaken) return;
    _actionTaken = true;

    await _promptDone.future;
    if (!mounted) return;

    _tapTracker.recordCorrectTap();
    _noHandsTimer?.cancel();
    _noHandsTimer = null;
    cancelIdleTimer();
    if (showHowToPlay) setState(() => showHowToPlay = false);

    await _stopAudio();
    await _say('$_audio9/sorry_4.wav');
    if (!mounted) return;

    if (!_thumbsDone.isCompleted) _thumbsDone.complete();
  }

  Future<void> _handleThumbsDown() async {
    if (_actionTaken) return;
    _actionTaken = true;

    await _promptDone.future;
    if (!mounted) return;

    _tapTracker.recordMistake();
    _noHandsTimer?.cancel();
    _noHandsTimer = null;
    cancelIdleTimer();
    if (showHowToPlay) setState(() => showHowToPlay = false);

    await _stopAudio();
    await _say('assets/audio/lumi_town/dr.woo_tryagain.wav');
    if (!mounted) return;

    setState(() => _actionTaken = false);
    _startNoHandsTimer();
    _armHint();
  }

  // ── Stage 4: Jack arrives ──────────────────────────────────────────────────
  Future<void> _stageJackArrives() async {
    _enterController.value = 0;
    _enter(_SorryStage.jackArrives);
    await _enterController.forward(from: 0);
  }

  // ── Stage 5: "I'M SORRY LITTLE BEAR" puzzle ────────────────────────────────
  Future<void> _stagePuzzleSorry() async {
    _canDrag = false;
    _hintIds = const ['IM', 'SORRY', 'LITTLE_BEAR'];
    _enter(_SorryStage.puzzleSorry);

    await _say('$_audio9/sorry_5.wav');
    if (!mounted) return;

    setState(() => _canDrag = true);
    _armHint();

    await _waitUntilPlaced({'IM', 'SORRY', 'LITTLE_BEAR'});
    if (!mounted) return;

    debugPrint('Puzzle Complete!');
    await _stopAudio();
    await GamesSfxPlayer.instance.play(GameSfx.shine);
    if (!mounted) return;

    await _say('$_audio9/sorry_6.wav');
  }

  // ── Stage 6: Jack, sad ─────────────────────────────────────────────────────
  Future<void> _stageJackSad() async {
    _enter(_SorryStage.jackSad);
    await _say('$_audio9/sorry_7.wav');
  }

  // ── Stage 7: two-row sentence puzzle ───────────────────────────────────────
  Future<void> _stagePuzzleRules() async {
    _rulesPhase = 1;
    _canDrag = true;
    _hintIds = const ['KINUHA_KO', 'ANG', 'LARUAN_MO'];
    _enter(_SorryStage.puzzleRules);
    _armHint();

    // Row 1: KINUHA KO ANG LARUAN MO
    await _waitUntilPlaced({'KINUHA_KO', 'ANG', 'LARUAN_MO'});
    if (!mounted) return;

    setState(() => _canDrag = false);
    await _stopAudio();
    await GamesSfxPlayer.instance.play(GameSfx.shine);
    if (!mounted) return;

    setState(() {
      _rulesPhase = 2;
      _canDrag = true;
    });
    _hintIds = const ['HINDI', 'KO_NA', 'UULITIN'];
    _armHint();

    // Row 2: HINDI KO NA UULITIN
    await _waitUntilPlaced({'HINDI', 'KO_NA', 'UULITIN'});
    if (!mounted) return;

    setState(() => _canDrag = false);
    await _stopAudio();
    await GamesSfxPlayer.instance.play(GameSfx.shine);
    if (!mounted) return;

    await _say('$_audio9/sorry_8.wav');
  }

  // ── Stage 8: reconcile ─────────────────────────────────────────────────────
  Future<void> _stageReconcile() async {
    _enter(_SorryStage.reconcile);

    await _say('$_audio9/sorry_9.wav');
    if (!mounted) return;

    await _meetController.forward(from: 0);
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    setState(() => _isCarWithJack = false);
    await _carSlideController.forward(from: 0);
    if (!mounted) return;

    await _jumpController.forward(from: 0);
    if (!mounted) return;

    await _say('$_audio9/sorry_ending.wav');
    if (!mounted) return;

    await _saveDataAndShowGoodJob();
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;

    final finalEmotions = stopAiCamera();

    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_sorry',
      activityName: 'Sorry Game',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint('Database Error saving metrics: $e');
    });

    TownProgressService.instance.markLevelComplete(widget.level).catchError((e) {
      debugPrint('Database Error marking level complete: $e');
    });

    if (mounted) setState(() => _showGoodJob = true);
  }

  // ── Puzzle helpers ─────────────────────────────────────────────────────────
  Future<void> _waitUntilPlaced(Set<String> ids) {
    _placementTarget = ids;
    final c = _placementWait = Completer<void>();
    _checkPlacement();
    return c.future;
  }

  void _checkPlacement() {
    final c = _placementWait;
    if (c != null && !c.isCompleted && _placed.containsAll(_placementTarget)) {
      c.complete();
    }
  }

  GlobalKey _pieceKey(String id) => _pieceKeys.putIfAbsent(id, () => GlobalKey());
  GlobalKey _slotKey(String id) => _slotKeys.putIfAbsent(id, () => GlobalKey());

  // ── How to play ────────────────────────────────────────────────────────────
  String? get _hintPieceId {
    for (final id in _hintIds) {
      if (!_placed.contains(id)) return id;
    }
    return null;
  }

  /// True while the child could be stuck and a hint makes sense.
  bool get _hintActive {
    if (_showGoodJob) return false;
    switch (_stage) {
      case _SorryStage.thumbs:
        return _introFinished &&
            _promptDone.isCompleted &&
            !_actionTaken &&
            (_showButtons || _cameraState == _CameraGestureState.denied);
      case _SorryStage.puzzleSorry:
      case _SorryStage.puzzleRules:
        return _canDrag && _hintPieceId != null;
      default:
        return false;
    }
  }

  bool get _hintAllowed => showHowToPlay && _hintActive;

  Alignment _alignmentOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    if (box == null || root == null || !box.hasSize) return Alignment.center;

    final center = box.localToGlobal(
      box.size.center(Offset.zero),
      ancestor: root,
    );
    return Alignment(
      center.dx / root.size.width * 2 - 1,
      center.dy / root.size.height * 2 - 1,
    );
  }

  Widget _buildHowToPlay() {
    final size = MediaQuery.of(context).size;

    // Thumbs: tap the space between the two buttons, so it shows
    // "tap one of these" without choosing the answer.
    if (_stage == _SorryStage.thumbs) {
      final btn = size.width * 0.135;
      final centerY = size.height - size.height * 0.10 - btn / 2;
      return HowToPlayOverlay(
        handAlignment: Alignment(0.0, centerY / size.height * 2 - 1),
        handOffset: const Offset(0.15, 0.55),
        onDismiss: resetIdleTimer,
        previewChild: _buildScene(preview: true),
      );
    }

    // Puzzles: drag the next piece from the tray into its slot.
    final id = _hintPieceId!;
    return HowToPlayOverlay(
      handAlignment: _alignmentOf(_pieceKey(id)),
      handEndAlignment: _alignmentOf(_slotKey(id)),
      handOffset: const Offset(0.15, 0.55),
      onDismiss: resetIdleTimer,
      previewChild: _buildScene(preview: true),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: Container(
          color: Colors.white,
          child: LoadingScreen.lumiTown(),
        ),
        gameBuilder: _buildGame,
      ),
    );
  }

  Widget _buildGame() {
    return Listener(
      onPointerDown: (_) {
        _tapTracker.recordGenericTap();
        if (!_hintActive) return;
        cancelIdleTimer();
        if (showHowToPlay) setState(() => showHowToPlay = false);
      },
      onPointerUp: (_) {
        if (_hintActive) startIdleTimer();
      },
      onPointerCancel: (_) {
        if (_hintActive) startIdleTimer();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildScene(),

          if (_hintAllowed) Positioned.fill(child: _buildHowToPlay()),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (_showGoodJob)
            GoodJobOverlay(
              characterImage: '$_chars/tr.woo_smiling.png',
              onNext: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => PickingTrashGame(level: widget.level + 1),
                  ),
                );
              },
              onRestart: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => SorryGameScreen(level: widget.level),
                  ),
                );
              },
              onBack: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => LumiLevelScreen()),
                );
              },
            ),
        ],
      ),
    );
  }

  /// The visible scene for the current stage. `preview: true` is used by the
  /// how-to-play overlay: it builds a second copy, so it must not reuse any
  /// GlobalKey and must not be interactive.
  Widget _buildScene({bool preview = false}) {
    final Widget content = switch (_stage) {
      _SorryStage.intro => _introScene(),
      _SorryStage.meetBear => _meetBearScene(),
      _SorryStage.thumbs => _thumbsScene(preview: preview),
      _SorryStage.jackArrives => _jackArrivesScene(),
      _SorryStage.puzzleSorry => _puzzleSorryScene(preview: preview),
      _SorryStage.jackSad => _jackSadScene(),
      _SorryStage.puzzleRules => _puzzleRulesScene(preview: preview),
      _SorryStage.reconcile => _reconcileScene(),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned(top: 25, left: 25, child: LumiXButton()),
        Positioned(
          top: 25,
          right: 25,
          child: LumiLevelBadge(level: widget.level),
        ),
      ],
    );
  }

  // ── Shared scene pieces ────────────────────────────────────────────────────
  Size get _size => MediaQuery.of(context).size;
  double get _baseCharH => _size.height * 1.18;
  double get _charH => _baseCharH * 0.70;

  Widget _classroomBg() {
    return Image.asset(
      'assets/images/backgrounds/bg_lumi_classroom.png',
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, st) => const Center(
        child: Text(
          'Background could not be loaded.',
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _puzzleBg() {
    return Image.asset(
      'assets/images/backgrounds/bg_lumi_puzzle.jpg',
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, st) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFBE4C3),
              Color(0xFFFBE4C3),
              Color(0xFFECA352),
              Color(0xFFECA352),
            ],
            stops: [0.0, 0.60, 0.60, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _jackWithCar(double charH) {
    return SizedBox(
      height: charH,
      width: charH * 0.85,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            '$_chars/jack_sad.png',
            height: charH,
            fit: BoxFit.contain,
          ),
          Positioned(
            bottom: charH * 0.12,
            left: charH * 0.08,
            child: Image.asset(
              '$_lumi/car.png',
              width: charH * 0.35,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  int get _stepCount =>
      (_enterDuration.inMilliseconds / _stepDuration.inMilliseconds)
          .round()
          .clamp(2, 10);

  // ── Scene: intro ───────────────────────────────────────────────────────────
  Widget _introScene() {
    return SizedBox.expand(
      child: Image.asset(
        '$_lumi/lvl9_scene1.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'Scene asset could not be loaded.',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      ),
    );
  }

  // ── Scene: owl + bear walks in ─────────────────────────────────────────────
  Widget _meetBearScene() {
    final sw = _size.width;
    final base = _baseCharH;
    final bearHeight = _charH;
    final bounceHeightPx = bearHeight * _bounceHeightFraction;

    return Stack(
      fit: StackFit.expand,
      children: [
        _classroomBg(),
        Positioned(
          left: sw * 0.10,
          bottom: -(base * 0.15),
          child: SizedBox(
            height: base * 0.80,
            child: Image.asset(
              '$_chars/tr.woo_the_owl.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _enterController,
          builder: (context, child) {
            final t = _enterController.value;
            final easedT = Curves.easeOutCubic.transform(t);
            final dx = sw * (1 - easedT);
            final bounce = t < 1.0
                ? (math.sin(t * _stepCount * math.pi)).abs() * bounceHeightPx
                : 0.0;

            return Positioned(
              right: (sw * 0.10) - dx,
              bottom: -(base * 0.15) + bounce,
              child: SizedBox(
                height: bearHeight,
                child: Image.asset(
                  _bearCrying
                      ? '$_chars/littlebear_sad_tears.png'
                      : '$_chars/bear_sad.png',
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Scene: thumbs up / down ────────────────────────────────────────────────
  Widget _thumbsScene({bool preview = false}) {
    final sw = _size.width;
    final sh = _size.height;

    final showButtons =
        preview ||
        (_introFinished &&
            (_showButtons || _cameraState == _CameraGestureState.denied));

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _showScene4 ? '$_lumi/lvl9_scene4.png' : '$_lumi/lvl9_scene3.png',
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => const Center(
            child: Text(
              'Scene asset could not be loaded.',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),

        if (!preview &&
            _introFinished &&
            _cameraState == _CameraGestureState.granted)
          _HiddenGestureDetector(
            onGesture: (result) {
              _startNoHandsTimer();
              if (result.isThumbsUp) {
                _handleThumbsUp();
              } else if (result.isThumbsDown) {
                _handleThumbsDown();
              }
            },
            onMounted: _startNoHandsTimer,
          ),

        if (showButtons) _thumbsButtons(sw, sh),
      ],
    );
  }

  Widget _thumbsButtons(double sw, double sh) {
    final thumbSize = sw * 0.11;
    final thumbBtnSize = sw * 0.135;

    return Positioned(
      bottom: sh * 0.10,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                GamesSfxPlayer.instance.play(GameSfx.bubbleClick);
                _handleThumbsUp();
              },
              child: _ThumbButton(
                imagePath: '$_lumi/thumbs_up.png',
                backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                size: thumbBtnSize,
                iconSize: thumbSize,
                animDelay: Duration.zero,
              ),
            ),
            SizedBox(width: sw * 0.04),
            GestureDetector(
              onTap: () {
                GamesSfxPlayer.instance.play(GameSfx.bubbleClick);
                _handleThumbsDown();
              },
              child: _ThumbButton(
                imagePath: '$_lumi/thumbs_down.png',
                backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                size: thumbBtnSize,
                iconSize: thumbSize,
                animDelay: const Duration(milliseconds: 400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Scene: Jack walks in ───────────────────────────────────────────────────
  Widget _jackArrivesScene() {
    final sw = _size.width;
    final base = _baseCharH;
    final charH = _charH;
    final bounceHeightPx = charH * _bounceHeightFraction;

    return Stack(
      fit: StackFit.expand,
      children: [
        _classroomBg(),
        Positioned(
          left: sw * 0.12,
          bottom: -(base * 0.15),
          child: SizedBox(
            height: charH,
            child: Image.asset(
              '$_chars/littlebear_sad_tears.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _enterController,
          builder: (context, child) {
            final t = _enterController.value;
            final easedT = Curves.easeOutCubic.transform(t);
            final dx = sw * (1 - easedT);
            final bounce = t < 1.0
                ? (math.sin(t * _stepCount * math.pi)).abs() * bounceHeightPx
                : 0.0;

            return Positioned(
              right: (sw * 0.12) - dx,
              bottom: -(base * 0.12) + bounce,
              child: _jackWithCar(charH),
            );
          },
        ),
      ],
    );
  }

  // ── Scene: Jack sad (static) ───────────────────────────────────────────────
  Widget _jackSadScene() {
    final sw = _size.width;
    final base = _baseCharH;
    final charH = _charH;

    return Stack(
      fit: StackFit.expand,
      children: [
        _classroomBg(),
        Positioned(
          left: sw * 0.12,
          bottom: -(base * 0.15),
          child: SizedBox(
            height: charH,
            child: Image.asset(
              '$_chars/littlebear_sad_tears.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          right: sw * 0.12,
          bottom: -(base * 0.15),
          child: _jackWithCar(charH),
        ),
      ],
    );
  }

  // ── Scene: puzzle 1 ("I'M SORRY LITTLE BEAR") ──────────────────────────────
  Widget _puzzleSorryScene({bool preview = false}) {
    final sw = _size.width;
    final sh = _size.height;

    final pieceW = sw * 0.18;
    final pieceH = pieceW;
    final overlap = pieceW * 0.26;
    final step = pieceW - overlap;
    final totalW = pieceW + step * 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        _puzzleBg(),

        Positioned(
          top: sh * 0.15,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: totalW,
              height: pieceH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _dragTarget(_pIm, pieceW, pieceH, preview: preview),
                  ),
                  Positioned(
                    left: step,
                    top: 0,
                    child: _dragTarget(
                      _pSorry,
                      pieceW,
                      pieceH,
                      preview: preview,
                    ),
                  ),
                  Positioned(
                    left: (step * 2) - (pieceW * 0.05),
                    top: 0,
                    child: _dragTarget(
                      _pLittleBear,
                      pieceW,
                      pieceH,
                      preview: preview,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: sh * 0.08,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _draggablePiece(_pIm, pieceW, pieceH, preview: preview),
                SizedBox(width: pieceW * 0.35),
                _draggablePiece(_pSorry, pieceW, pieceH, preview: preview),
                SizedBox(width: pieceW * 0.35),
                _draggablePiece(_pLittleBear, pieceW, pieceH, preview: preview),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Scene: puzzle 2 (two-row sentence) ─────────────────────────────────────
  Widget _puzzleRulesScene({bool preview = false}) {
    final sw = _size.width;
    final sh = _size.height;

    final pieceW = sw * 0.16;
    final pieceH = pieceW;

    final row2Expansion = pieceW * 0.08;
    final row2PieceW = pieceW + row2Expansion;

    final puzzleTop = _rulesPhase == 1 ? sh * 0.18 : sh * 0.05;

    final verticalOverlap = pieceH * 0.52;
    final row2TopOffset = pieceH - verticalOverlap;

    final horizontalOverlap = pieceW * 0.42;
    final step = pieceW - horizontalOverlap;
    final totalW = pieceW + step * 2;
    final totalH = pieceH + row2TopOffset;

    return Stack(
      fit: StackFit.expand,
      children: [
        _puzzleBg(),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutBack,
          top: puzzleTop,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: totalW,
              height: totalH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Row 1
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      width: totalW,
                      height: pieceH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0 - (pieceW * 0.03),
                            top: 0,
                            child: _dragTarget(
                              _pKinuhaKo,
                              pieceW,
                              pieceH,
                              preview: preview,
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned(
                            left: (step * 2) + (pieceW * 0.03),
                            top: 0,
                            child: _dragTarget(
                              _pLaruanMo,
                              pieceW,
                              pieceH,
                              preview: preview,
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned(
                            left: step,
                            top: 0,
                            child: _dragTarget(
                              _pAng,
                              pieceW,
                              pieceH,
                              preview: preview,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Row 2
                  Positioned(
                    top: row2TopOffset,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 450),
                      opacity: _rulesPhase == 2 ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: _rulesPhase == 1,
                        child: SizedBox(
                          width: totalW,
                          height: pieceH,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 0 - (pieceW * 0.025),
                                top: -1,
                                child: _dragTarget(
                                  _pHindi,
                                  row2PieceW,
                                  pieceH,
                                  preview: preview,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Positioned(
                                left:
                                    ((step * 2) + (pieceW * 0.015)) -
                                    row2Expansion,
                                top: 0,
                                child: _dragTarget(
                                  _pUulitin,
                                  row2PieceW,
                                  pieceH,
                                  preview: preview,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Positioned(
                                left: step - (row2Expansion / 2),
                                top: 0,
                                child: _dragTarget(
                                  _pKoNa,
                                  row2PieceW,
                                  pieceH,
                                  preview: preview,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Tray
        Positioned(
          bottom: sh * 0.05,
          left: 0,
          right: 0,
          child: Center(
            child: _rulesPhase == 1
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _draggablePiece(
                        _pLaruanMo,
                        pieceW,
                        pieceH,
                        preview: preview,
                        fit: BoxFit.fill,
                      ),
                      SizedBox(width: pieceW * 0.15),
                      _draggablePiece(
                        _pKinuhaKo,
                        pieceW,
                        pieceH,
                        preview: preview,
                        fit: BoxFit.fill,
                      ),
                      SizedBox(width: pieceW * 0.15),
                      _draggablePiece(
                        _pAng,
                        pieceW,
                        pieceH,
                        preview: preview,
                        fit: BoxFit.fill,
                      ),
                      SizedBox(width: pieceW * 0.15),
                      _draggablePiece(
                        _pPangitKa,
                        pieceW,
                        pieceH,
                        preview: preview,
                        fit: BoxFit.fill,
                      ),
                    ],
                  )
                : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _draggablePiece(
                            _pKoNa,
                            row2PieceW,
                            pieceH,
                            preview: preview,
                            fit: BoxFit.fill,
                          ),
                          SizedBox(width: pieceW * 0.10),
                          _draggablePiece(
                            _pIbabalik,
                            row2PieceW,
                            pieceH,
                            preview: preview,
                            fit: BoxFit.fill,
                          ),
                          SizedBox(width: pieceW * 0.10),
                          _draggablePiece(
                            _pUulitin,
                            row2PieceW,
                            pieceH,
                            preview: preview,
                            fit: BoxFit.fill,
                          ),
                          SizedBox(width: pieceW * 0.10),
                          _draggablePiece(
                            _pHindi,
                            row2PieceW,
                            pieceH,
                            preview: preview,
                            fit: BoxFit.fill,
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 450))
                      .slideY(begin: 0.3, end: 0.0),
          ),
        ),
      ],
    );
  }

  // ── Puzzle widgets (shared by both puzzles) ────────────────────────────────
  Widget _dragTarget(
    _Piece piece,
    double width,
    double height, {
    required bool preview,
    BoxFit fit = BoxFit.contain,
  }) {
    final isPlaced = _placed.contains(piece.id);

    return DragTarget<String>(
      key: preview ? null : _slotKey(piece.id),
      onWillAcceptWithDetails: (details) => !isPlaced,
      onAcceptWithDetails: (details) async {
        if (details.data == piece.id) {
          _tapTracker.recordCorrectTap();
          unawaited(_trWooPlayer.stop());
          await GamesSfxPlayer.instance.play(GameSfx.shine);
          if (!mounted) return;
          setState(() => _placed.add(piece.id));
          _checkPlacement();
        } else {
          _tapTracker.recordMistake();
          GamesSfxPlayer.instance.play(GameSfx.bubblePop);
          showTrWooReaction(TrWooState.wrong);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Image.asset(
            isPlaced ? piece.pieceAsset : piece.slotAsset,
            fit: fit,
            errorBuilder: (ctx, err, st) => Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isPlaced
                    ? Colors.orange
                    : Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  isPlaced ? piece.id : '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _draggablePiece(
    _Piece piece,
    double width,
    double height, {
    required bool preview,
    BoxFit fit = BoxFit.contain,
  }) {
    if (_placed.contains(piece.id)) {
      return SizedBox(width: width, height: height);
    }

    final Widget pieceImage = Image.asset(
      piece.pieceAsset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (ctx, err, st) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: (piece.id == 'PANGIT_KA' || piece.id == 'IBABALIK')
              ? Colors.redAccent
              : Colors.blueAccent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            piece.id.replaceAll('_', ' '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );

    final Widget result;
    if (!_canDrag) {
      result = Opacity(opacity: 0.65, child: pieceImage);
    } else {
      result = Draggable<String>(
        data: piece.id,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.10, child: pieceImage),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: pieceImage),
        child: pieceImage
            .animate(target: _canDrag ? 1 : 0)
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.0, 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
            ),
      );
    }

    // The preview copy must not reuse the key the hint hand points at.
    return preview
        ? result
        : KeyedSubtree(key: _pieceKey(piece.id), child: result);
  }

  // ── Scene: reconcile ───────────────────────────────────────────────────────
  Widget _reconcileScene() {
    final sw = _size.width;
    final base = _baseCharH;
    final charH = _charH;
    final baseBottomOffset = -(base * 0.15);

    final bearLeft = sw * 0.12;
    final bearHandX = bearLeft + (charH * 0.45);

    final jackRight = sw * 0.12;
    final jackStartLeft = sw - jackRight - (charH * 0.85);
    final jackMeetingLeft = bearLeft + (charH * 0.85);

    final handY = baseBottomOffset + (charH * 0.12);

    return Stack(
      fit: StackFit.expand,
      children: [
        _classroomBg(),
        AnimatedBuilder(
          animation: Listenable.merge([
            _meetController,
            _carSlideController,
            _jumpController,
          ]),
          builder: (context, child) {
            final walkT = Curves.easeInOut.transform(_meetController.value);
            final jackCurrentLeft =
                jackStartLeft + (jackMeetingLeft - jackStartLeft) * walkT;
            final jackHandX = jackCurrentLeft + (charH * 0.08);

            final t = _jumpController.value;
            final bounce = (math.sin(t * math.pi * 2)).abs() * (charH * 0.08);

            final slideT = Curves.easeInOutCubic.transform(
              _carSlideController.value,
            );
            final carLeft = _isCarWithJack
                ? jackHandX
                : jackHandX + (bearHandX - jackHandX) * slideT;

            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: bearLeft,
                  bottom: baseBottomOffset + bounce,
                  child: SizedBox(
                    height: charH,
                    child: Image.asset(
                      '$_chars/little_bear_uniform.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: jackCurrentLeft,
                  bottom: baseBottomOffset + bounce,
                  child: SizedBox(
                    height: charH,
                    width: charH * 0.85,
                    child: Image.asset(
                      '$_chars/jack_smiling.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  bottom: handY + bounce,
                  left: carLeft,
                  child: Image.asset(
                    '$_lumi/car.png',
                    width: charH * 0.35,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbs helpers
// ─────────────────────────────────────────────────────────────────────────────

class _HiddenGestureDetector extends StatefulWidget {
  final void Function(GestureResult result) onGesture;
  final VoidCallback onMounted;

  const _HiddenGestureDetector({
    required this.onGesture,
    required this.onMounted,
  });

  @override
  State<_HiddenGestureDetector> createState() => _HiddenGestureDetectorState();
}

class _HiddenGestureDetectorState extends State<_HiddenGestureDetector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMounted());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.0,
          child: SizedBox(
            width: 4,
            height: 4,
            child: GestureCameraView(onGesture: widget.onGesture),
          ),
        ),
      ),
    );
  }
}

class _ThumbButton extends StatelessWidget {
  final String imagePath;
  final Color backgroundColor;
  final double size;
  final double iconSize;
  final Duration animDelay;

  const _ThumbButton({
    required this.imagePath,
    required this.backgroundColor,
    required this.size,
    required this.iconSize,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(size * 0.10),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) => Icon(
              imagePath.contains('up') ? Icons.thumb_up : Icons.thumb_down,
              color: Colors.white,
              size: iconSize * 0.7,
            ),
          ),
        )
        .animate(delay: animDelay, onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.06, 1.06),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
  }
}
