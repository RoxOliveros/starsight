import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/puzzle_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/puzzle_progress_service.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/puzzle_game_ui.dart';
import 'package:StarSight/games_ui_layer/puzzle_glade/roxie_reaction.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/puzzle_glade/puzzle_buttons.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';
import '../games_audio_helper.dart';
import '../goodjob_prompt.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'game_shape_fit.dart';

enum _ScreenPhase { intro, game }

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

const _kPeekDuration = Duration(milliseconds: 1400);
const _kTotalRounds = 5;

class _CardModel {
  final int id;
  final int pairId;
  final String object;
  bool isFaceUp = false;
  bool isMatched = false;

  _CardModel({required this.id, required this.pairId, required this.object});
}

class MemoryMatchScreen extends StatefulWidget {
  final int level;

  const MemoryMatchScreen({super.key, required this.level});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen>
    with
        TickerProviderStateMixin,
        RoxieReactionMixin,
        GameLoadingMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<MemoryMatchScreen>,
        IdleHintMixin<MemoryMatchScreen> {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _roxiePlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _roxiePlayer];

  @override
  AudioPlayer get roxiePlayer => _roxiePlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  // ── Asset config ───────────────────────────────────────────────────────────
  static const String _characterImage = 'assets/images/characters/roxie_the_rabbit.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_puzzle.png';
  static const String _starImage = 'assets/images/objects/puzzle/star_bnw.png';

  static const String _audioIntro = 'assets/audio/puzzle_glade/memory_match_intro.wav';
  static const String _audioInstructions = 'assets/audio/puzzle_glade/memory_match_instruction.wav';
  static const String _audioComplete = 'assets/audio/puzzle_glade/memory_match_complete.wav';

  // ── How-to-play hint ──────────────────────────────────────────────────────
  // Keys go on the first two LIVE cards only (top row, always present).
  // While the overlay's preview is being built, _previewing is true: the
  // preview shows plain face-down cards with no keys and no gestures.
  final List<GlobalKey> _cardKeys = List.generate(2, (_) => GlobalKey());
  bool _previewing = false;

  // ── Phase state ────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // ── Game state ─────────────────────────────────────────────────────────────
  int _round = 1;
  late List<_CardModel> _cards;
  final List<int> _peekedIds = [];
  bool _locked = false;
  bool _roundComplete = false;
  int _matchesFound = 0;
  bool _showWinDialog = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _inputEnabled = false;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _roxieFloatCtrl;
  late AnimationController _roxieSlideCtrl;
  late Animation<Offset> _roxieSlide;
  late Animation<double> _roxieFade;
  late AnimationController _cardDanceCtrl;
  late Animation<double> _cardDance;
  late AnimationController _speechBubbleCtrl;
  late AnimationController _gameEnterCtrl;
  late Animation<double> _gameFade;
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;
  late AnimationController _celebCtrl;
  late Animation<double> _celebAnim;

  List<AnimationController> _flipCtrls = [];
  List<Animation<double>> _flipAnims = [];

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
    disposeIdleTimer();
    _audioPlayer.dispose();
    _roxiePlayer.dispose();
    _roxieFloatCtrl.dispose();
    _roxieSlideCtrl.dispose();
    _cardDanceCtrl.dispose();
    _speechBubbleCtrl.dispose();
    _gameEnterCtrl.dispose();
    _enterCtrl.dispose();
    _celebCtrl.dispose();
    for (final c in _flipCtrls) {
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

    _cardDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _cardDance = Tween<double>(
      begin: -0.07,
      end: 0.07,
    ).animate(CurvedAnimation(parent: _cardDanceCtrl, curve: Curves.easeInOut));

    _speechBubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _gameEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gameFade = CurvedAnimation(parent: _gameEnterCtrl, curve: Curves.easeIn);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _celebAnim = CurvedAnimation(parent: _celebCtrl, curve: Curves.elasticOut);
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _roxieSlideCtrl.forward();

    _speechBubbleCtrl.forward(from: 0);
    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioIntro);
    if (!mounted) return;

    _speechBubbleCtrl.forward(from: 0);
    _gameEnterCtrl.forward();
    _buildRound();
    if (mounted) setState(() => _screenPhase = _ScreenPhase.game);
    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioInstructions);
    if (!mounted) return;
    setState(() => _inputEnabled = true);
    startIdleTimer(); // hint countdown starts once the child can play
  }

  int _pairsForRound(int round) {
    if (round <= 2) return 2;
    if (round <= 4) return 3;
    return 4;
  }

  void _buildRound() {
    final pairsThisRound = _pairsForRound(_round);
    final rng = Random();
    final pool = List<String>.from(_kAllObjects)..shuffle(rng);
    final chosen = pool.take(pairsThisRound).toList();

    final rawCards = <_CardModel>[];
    for (int i = 0; i < chosen.length; i++) {
      rawCards.add(_CardModel(id: i * 2, pairId: i, object: chosen[i]));
      rawCards.add(_CardModel(id: i * 2 + 1, pairId: i, object: chosen[i]));
    }
    rawCards.shuffle(rng);
    _cards = rawCards;

    for (final c in _flipCtrls) {
      c.dispose();
    }
    _flipCtrls = List.generate(
      _cards.length,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    _flipAnims = _flipCtrls
        .map(
          (ctrl) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut)),
    )
        .toList();

    _peekedIds.clear();
    _locked = false;
    _roundComplete = false;
    _matchesFound = 0;
    _celebCtrl.reset();
    _enterCtrl.forward(from: 0);
  }

  Future<void> _onCardTap(int cardIndex) async {
    if (!_inputEnabled) return;
    if (_locked || _roundComplete) return;

    final card = _cards[cardIndex];
    if (card.isFaceUp || card.isMatched) return;

    GamesSfxPlayer.instance.play(GameSfx.bubbleClick);

    setState(() {
      card.isFaceUp = true;
      _peekedIds.add(cardIndex);
    });
    _flipCtrls[cardIndex].forward();

    if (_peekedIds.length < 2) return;

    _locked = true;
    final idxA = _peekedIds[0];
    final idxB = _peekedIds[1];
    final cardA = _cards[idxA];
    final cardB = _cards[idxB];

    if (cardA.pairId == cardB.pairId) {
      _tapTracker.recordCorrectTap();
      showRoxieReaction(RoxieState.correct);
      setState(() {
        cardA.isMatched = true;
        cardB.isMatched = true;
        _peekedIds.clear();
        _matchesFound++;
        _locked = false;
      });

      if (_matchesFound == _pairsForRound(_round)) {
        cancelIdleTimer(); // round solved: no hint until the next round
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() {
          _roundComplete = true;
          showHowToPlay = false;
        });
        _celebCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;

        if (_round >= _kTotalRounds) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          await _roxiePlayer.stop();

          await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioComplete);

          PuzzleProgressService.instance
              .markLevelComplete(widget.level)
              .catchError((e) {
            debugPrint("Database Error marking level complete: $e");
          });
          await _saveDataAndShowWinDialog();
        } else {
          await _enterCtrl.reverse();
          if (!mounted) return;
          setState(() {
            _round++;
            _buildRound();
          });
          startIdleTimer(); // new round: restart the countdown
        }
      }
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showRoxieReaction(RoxieState.wrong);
      await Future.delayed(_kPeekDuration);
      if (!mounted) return;
      setState(() {
        cardA.isFaceUp = false;
        cardB.isFaceUp = false;
        _peekedIds.clear();
      });
      _flipCtrls[idxA].reverse();
      _flipCtrls[idxB].reverse();
      await Future.delayed(const Duration(milliseconds: 400));
      _locked = false;
    }
  }

  Future<void> _saveDataAndShowWinDialog() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    cancelIdleTimer();
    List<String> finalEmotions = stopAiCamera();

    PuzzleDatabaseService.saveGameData(
      gameId: 'puzzle_memory_match',
      activityName: 'Memory Match',
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

  /// True while the child can actually play.
  bool get _canPlay =>
      _screenPhase == _ScreenPhase.game &&
          _inputEnabled &&
          !_roundComplete &&
          !_showWinDialog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.puzzleGlade(),
        gameBuilder: () => Listener(
          // Finger down: hide the hint and pause the countdown.
          // Finger up: restart the countdown.
          onPointerDown: (_) {
            _tapTracker.recordGenericTap();
            if (showHowToPlay) setState(() => showHowToPlay = false);
            cancelIdleTimer();
          },
          onPointerUp: (_) {
            if (_canPlay) startIdleTimer();
          },
          onPointerCancel: (_) {
            if (_canPlay) startIdleTimer();
          },
          child: Stack(
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
              _screenPhase == _ScreenPhase.intro
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

              if (showHowToPlay && _canPlay)
                Positioned.fill(child: _buildHowToPlay()),

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
      ),
    );
  }

  // ── How to play ───────────────────────────────────────────────────────────
  Widget _buildHowToPlay() {
    // Static copy of the game with every card face down, so the preview
    // never reveals where the pairs are. Keys and gestures are skipped.
    _previewing = true;
    final preview = Stack(
      fit: StackFit.expand,
      children: [
        Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_bgImage, fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.15)),
          ],
        ),
        _buildGameLayer(),
        buildRoxie(context),
      ],
    );
    _previewing = false;

    // The hand taps two cards in turn, which is the whole idea of the game:
    // flip two cards to find a match.
    return HowToPlayOverlay(
      previewChild: preview,
      handAlignment: _alignmentOf(_cardKeys[0]),
      handEndAlignment: _alignmentOf(_cardKeys[1]),
      tapSequence: true,
      handOffset: const Offset(0.15, 0.65),
      onDismiss: resetIdleTimer,
    );
  }

  Alignment _alignmentOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    if (box == null || root == null || !box.hasSize) return Alignment.center;

    final c = box.localToGlobal(box.size.center(Offset.zero), ancestor: root);
    return Alignment(
      c.dx / root.size.width * 2 - 1,
      c.dy / root.size.height * 2 - 1,
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
              Expanded(flex: 6, child: _buildIntroDancingCards()),
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
        return Align(
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroDancingCards() {
    return AnimatedBuilder(
      animation: _cardDanceCtrl,
      builder: (_, __) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: List.generate(4, (i) {
              final angle = _cardDance.value * ((i % 2 == 0) ? 1 : -1);
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: PuzzleColorTheme.vandecane,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PuzzleColorTheme.darkdesaturatedblue.withValues(
                        alpha: 0.35,
                      ),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontFamily: PuzzleAppTextStyles.fredoka,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: PuzzleColorTheme.sunnyhue,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildGameLayer() {
    return FadeTransition(
      opacity: _enterAnim,
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
          Expanded(child: _buildCardGrid()),
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

  Widget _buildCardGrid() {
    final pairsThisRound = _pairsForRound(_round);

    final topIndices = List.generate(pairsThisRound, (i) => i);
    final bottomIndices = List.generate(
      pairsThisRound,
          (i) => pairsThisRound + i,
    );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCardRow(topIndices),
          const SizedBox(height: 16),
          _buildCardRow(bottomIndices),
        ],
      ),
    );
  }

  Widget _buildCardRow(List<int> indices) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < indices.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          _buildCard(indices[i]),
        ],
      ],
    );
  }

  Widget _buildCard(int index) {
    // Hint preview: plain face-down card, same size, no gestures, no key.
    if (_previewing) return _cardBack();

    final card = _cards[index];
    final anim = _flipAnims[index];

    return GestureDetector(
      // Only the first two cards (top row) carry keys for the hand position.
      key: index < 2 ? _cardKeys[index] : null,
      onTap: () => _onCardTap(index),
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          final showFront = anim.value >= 0.5;
          final angle = showFront ? (anim.value - 1.0) * pi : anim.value * pi;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showFront ? _cardFront(card) : _cardBack(),
          );
        },
      ),
    );
  }

  Widget _cardBack() {
    return _cardShell(
      color: PuzzleColorTheme.vandecane,
      borderColor: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.35),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            _starImage,
            width: 44,
            height: 44,
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.12),
            colorBlendMode: BlendMode.modulate,
          ),
          Text(
            '?',
            style: TextStyle(
              fontFamily: PuzzleAppTextStyles.fredoka,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: PuzzleColorTheme.sunnyhue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardFront(_CardModel card) {
    return _cardShell(
      color: card.isMatched
          ? PuzzleColorTheme.goldenyellow.withValues(alpha: 0.30)
          : PuzzleColorTheme.vandecane,
      borderColor: card.isMatched
          ? PuzzleColorTheme.sunnyhue
          : PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.25),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/objects/puzzle/${card.object}.png',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
          if (card.isMatched)
            Positioned(
              top: 6,
              right: 6,
              child: ScaleTransition(scale: _celebAnim),
            ),
        ],
      ),
    );
  }

  Widget _cardShell({
    required Color color,
    required Color borderColor,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: PuzzleColorTheme.darkdesaturatedblue.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildWinOverlay() {
    return GoodJobOverlay(
      characterImage: _characterImage,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ShapeFitScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        setState(() {
          _round = 1;
          _showWinDialog = false;
          _hasSavedResult = false;
          _tapTracker.startSession();
        });
        _buildRound();
        startIdleTimer();
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}