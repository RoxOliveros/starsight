import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'game_345_counting.dart';
import 'number_introduction_screen.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

enum _ScreenPhase { intro, miniGame }

class Number012TapCountScreen extends StatefulWidget {
  final int level;

  const Number012TapCountScreen({super.key, required this.level});

  @override
  State<Number012TapCountScreen> createState() =>
      _Number012TapCountScreenState();
}

class _Number012TapCountScreenState extends State<Number012TapCountScreen>
    with
        TickerProviderStateMixin,
        DomaReactionMixin,
        GameLoadingMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<Number012TapCountScreen>,
        IdleHintMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _domaPlayer= AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _domaPlayer];

  @override
  AudioPlayer get domaPlayer => _domaPlayer;

  // ── Constants ──────────────────────────────────────────────────────────────

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _domaImage = 'assets/images/characters/doma_the_penguin.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/level8/012_countandtap.wav';

  static const int _totalRounds = 5;
  static const int _poolSize = 5;

  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  bool _showWinDialog = false;
  bool _countAudioPlaying = false;

  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  final GameTapTracker _tapTracker = GameTapTracker();

  final GlobalKey _tileKey = GlobalKey();
  final GlobalKey _checkKey = GlobalKey();

  int get _hintTileIndex {
    final i = _selected.indexWhere((s) => !s);
    return i == -1 ? 0 : i;
  }

  bool _hideLightingCard = false;
  bool _loadingScreenElapsed = false;
  Timer? _minLoadTimer;

  static const _themes = [
    _RoundTheme(
      asset: 'assets/images/objects/arctic/snowball.png',
      label: 'Snowball',
      color: Color(0xFF4FC3F7),
    ),
    _RoundTheme(
      asset: 'assets/images/objects/arctic/candy_cane.png',
      label: 'Candy Cane',
      color: Color(0xFFFFC857),
    ),
    _RoundTheme(
      asset: 'assets/images/objects/arctic/igloo.png',
      label: 'Igloo',
      color: Color(0xFF81C784),
    ), // index 2
  ];

  // ── State ──────────────────────────────────────────────────────────────────

  int _round = 0;
  late List<int> _roundOrder;

  int get _targetNumber => _roundOrder[_round];

  _RoundTheme get _theme => _themes[_targetNumber];

  late List<bool> _selected;

  bool _locked = false;

  // Animations
  late AnimationController _numberBounce;
  late Animation<double> _numberBounceAnim;

  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  late AnimationController _celebrationCtrl;

  late AnimationController _wrongShakeCtrl;

  // Object scale animations (one per object)
  late List<AnimationController> _objScaleCtrls;
  late List<Animation<double>> _objScaleAnims;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    final random = Random();

    _roundOrder = [1, 2];
    while (_roundOrder.length < _totalRounds) {
      _roundOrder.add(random.nextBool() ? 1 : 2);
    }
    _roundOrder.shuffle(random);

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
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

    _numberBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _numberBounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _numberBounce, curve: Curves.easeOut));

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _wrongShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _initObjectAnimations();
    _startRound();
  }

  void _initObjectAnimations() {
    _objScaleCtrls = List.generate(
      _poolSize,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      ),
    );
    _objScaleAnims = _objScaleCtrls.map((ctrl) {
      return TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 60),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }).toList();
  }

  void _restartGame() {
    final random = Random();

    _roundOrder = [1, 2];

    while (_roundOrder.length < _totalRounds) {
      _roundOrder.add(random.nextBool() ? 1 : 2);
    }

    _roundOrder.shuffle(random);

    setState(() {
      _round = 0;
      _showWinDialog = false;
      _locked = false;
      _countAudioPlaying = false;
      _selected = List.filled(_poolSize, false);
      _screenPhase = _ScreenPhase.miniGame;
    });

    _celebrationCtrl.reset();
    _wrongShakeCtrl.reset();

    _enterCtrl.reset();
    _enterCtrl.forward();

    _numberBounce.reset();
    _numberBounce.forward();

    for (final controller in _objScaleCtrls) {
      controller.reset();
    }

    _tapTracker.startSession();

    startAiCamera();
    startIdleTimer();
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _minLoadTimer?.cancel();
    _numberDanceCtrl.dispose();
    _audioPlayer.dispose();
    _domaPlayer.dispose();
    OrientationService.setLandscape();
    _numberBounce.dispose();
    _enterCtrl.dispose();
    _celebrationCtrl.dispose();
    _wrongShakeCtrl.dispose();
    for (final c in _objScaleCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Round logic ────────────────────────────────────────────────────────────

  void _startRound() {
    _selected = List.filled(_poolSize, false);
    _locked = false;
    _countAudioPlaying = false;
    _celebrationCtrl.reset();
    _enterCtrl.forward(from: 0);
    _numberBounce.forward(from: 0);
  }

  int get _selectedCount => _selected.where((s) => s).length;

  Future<void> _onObjectTap(int index) async {
    if (_locked || _countAudioPlaying) return;
    cancelIdleTimer();

    setState(() {
      _selected[index] = !_selected[index];
    });
    _objScaleCtrls[index].forward(from: 0);

    if (_selected[index]) {
      final count = _selectedCount;
      _countAudioPlaying = true;
      try {
        await playVoiceRestartingOnFaceLoss(
          _audioPlayer,
          'assets/audio/arctic_numberland/$count.wav',
        );
      } catch (_) {
      } finally {
        _countAudioPlaying = false;
      }
    }
    if (mounted) startIdleTimer();
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioIntro);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _screenPhase = _ScreenPhase.miniGame);
      startIdleTimer();
    }
  }

  Future<void> _onSubmit() async {
    if (_locked) return;
    _locked = true;
    cancelIdleTimer();

    if (_selectedCount == _targetNumber) {
      _tapTracker.recordCorrectTap();

      showDomaReaction(DomaState.correct);
      _celebrationCtrl.forward(from: 0);
      _numberBounce.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1000));

      if (_round + 1 >= _totalRounds) {
        // --- ADDED AI STOP & DATABASE SAVE ---
        List<String> finalEmotions = stopAiCamera();

        ArcticDatabaseService.saveGameData(
          gameId: 'arctic_numberland_${widget.level}',
          mistakes: _tapTracker.mistakeCount,
          emotions: finalEmotions,
        ).catchError((e) {
          debugPrint("Database Error saving metrics: $e");
        });

        ArcticProgressService.instance
            .markLevelComplete(widget.level)
            .catchError((e) {
              debugPrint("Database Error marking level complete: $e");
            });
        cancelIdleTimer();
        setState(() => _showWinDialog = true);
      } else {
        await _enterCtrl.reverse();
        if (!mounted) return;
        setState(() {
          _round++;
          _startRound();
        });
        startIdleTimer();
      }
    } else {
      _tapTracker.recordMistake();

      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showDomaReaction(DomaState.wrong);
      _wrongShakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 2000));
      _wrongShakeCtrl.reset();
      if (!mounted) return;
      setState(() {
        _locked = false;
      });
      startIdleTimer();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),

        if (_screenPhase == _ScreenPhase.intro)
          _buildIntrolayer()
        else
          _buildMiniGameContent(),

        // Progress dots
        if (_screenPhase == _ScreenPhase.miniGame)
          Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(child: _buildProgressDots()),
          ),

        // Doma
        if (_screenPhase == _ScreenPhase.miniGame) buildDoma(context),

        if (_screenPhase == _ScreenPhase.miniGame && !_showWinDialog)
          Positioned(right: 25, bottom: 25, child: _buildCheckButton()),

        if (showHowToPlay &&
            _screenPhase == _ScreenPhase.miniGame &&
            !_locked &&
            !_countAudioPlaying &&
            !_showWinDialog)
          Positioned.fill(
            child: HowToPlayOverlay(
              previewChild: _buildHintPreview(),
              handAlignment: _alignmentOf(_tileKey),
              handEndAlignment: _alignmentOf(_checkKey),
              tapSequence: true,
              handOffset: const Offset(0.15, 0.46),
              onDismiss: resetIdleTimer,
            ),
          ),

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
      onPointerDown: (_) {
        _tapTracker.recordGenericTap();
        if (_screenPhase == _ScreenPhase.miniGame &&
            !_locked &&
            !_countAudioPlaying) {
          resetIdleTimer();
        }
      },
      child: Scaffold(
        backgroundColor: ArcticColorTheme.lightgrayishcyan,
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

  Alignment _alignmentOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    if (box == null || root == null || !box.hasSize) return Alignment.center;

    final center = box.localToGlobal(box.size.center(Offset.zero), ancestor: root);
    return Alignment(
      center.dx / root.size.width * 2 - 1,
      center.dy / root.size.height * 2 - 1,
    );
  }

  Widget _buildHintPreview() {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        _buildMiniGameContent(preview: true),
        Positioned(
          left: 0,
          right: 0,
          bottom: 15,
          child: Center(child: _buildProgressDots()),
        ),
        Positioned(right: 25, bottom: 25, child: _buildCheckButton(preview: true)),
      ],
    );
  }

  Widget _buildMiniGameContent({bool preview = false}) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 25,
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

        // Main game
        Expanded(
          child: FadeTransition(
            opacity: _enterAnim,
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -70),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildNumberCard(preview: preview),

                      const SizedBox(width: 20),

                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: ArcticColorTheme.slateblue,
                        size: 34,
                      ),

                      const SizedBox(width: 20),

                      _buildObjectArea(preview: preview),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Number card (left) ─────────────────────────────────────────────────────

  Widget _buildNumberCard({bool preview = false}) {
    final s = MediaQuery.of(context).size;
    final cardSize = (s.height * 0.32).clamp(80.0, 130.0);
    return ScaleTransition(
      scale: _numberBounceAnim,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          color: ArcticColorTheme.cotton,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ArcticColorTheme.slateblue, width: 3),
          boxShadow: [
            BoxShadow(
              color: ArcticColorTheme.pictonblue.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: preview
              ? const SizedBox.shrink()
              : Image.asset(
            'assets/fonts/game_numbers/$_targetNumber.png',
            width: cardSize * 0.6,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              '$_targetNumber',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: cardSize * 0.6,
                fontWeight: FontWeight.bold,
                color: ArcticColorTheme.cotton,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildObjectArea({bool preview = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _poolSize,
            (i) => _buildObjectTile(i, preview: preview),
      ),
    );
  }

  Widget _buildCheckButton({bool preview = false}) {
    return GestureDetector(
      key: preview ? null : _checkKey,
      onTap: _locked ? null : _onSubmit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _locked
              ? ArcticColorTheme.cadetblue.withValues(alpha: 0.5)
              : ArcticColorTheme.cadetblue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ArcticColorTheme.cadetblue.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 40,
          color: ArcticColorTheme.cotton,
        ),
      ),
    );
  }

  Widget _buildObjectTile(int index, {bool preview = false}) {
    final tileSize = (MediaQuery.of(context).size.height * 0.18).clamp(
      52.0,
      80.0,
    );
    final isSelected = !preview && _selected[index];

    return Padding(
      key: (!preview && index == _hintTileIndex) ? _tileKey : null,
      padding: EdgeInsets.symmetric(horizontal: tileSize * 0.08),
      child: GestureDetector(
        onTap: () => _onObjectTap(index),
        child: ScaleTransition(
          scale: _objScaleAnims[index],
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: isSelected ? _theme.color : ArcticColorTheme.cotton,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? _theme.color : ArcticColorTheme.pictonblue,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? _theme.color.withValues(alpha: 0.45)
                      : ArcticColorTheme.pictonblue.withValues(alpha: 0.15),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(tileSize * 0.13),
                  child: Image.asset(
                    _theme.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.star_rounded,
                      color: isSelected ? Colors.white : _theme.color,
                      size: tileSize * 0.5,
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: tileSize * 0.26,
                      height: tileSize * 0.26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: tileSize * 0.18,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Progress dots ──────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _round;
        final current = i == _round;
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
    return DomaGoodJobOverlay(
      characterImage: _domaImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NumberIntroductionScreen.forSequence(
              [3, 4, 5],
              level: 5,
              nextScreen: Number345CountingObjectsScreen(
                level: widget.level + 1,
              ),
            ),
          ),
        );
      },
      onRestart: _restartGame,
      onBack: () {
        Navigator.pop(context);
      },
    );
  }

  Widget _buildIntrolayer() {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Stack(
        children: [
          Positioned(top: 25, left: 25, child: ArcticXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: ArcticLevelBadge(level: widget.level),
          ),
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

// ─────────────────────────────────────────────────────────────────────────────

class _RoundTheme {
  final String asset;
  final String label;
  final Color color;

  const _RoundTheme({
    required this.asset,
    required this.label,
    required this.color,
  });
}
