import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_buttons.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'alphabet_game_ui.dart';
import 'alphabet_intro.dart';
import 'forest_audio_helper.dart';
import 'tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

// ═════════════════════════════════════════════════════════════════════════
// MODELS
// ═════════════════════════════════════════════════════════════════════════

/// One draggable letter piece in this round's choice set.
class _ForestLetterData {
  final String letter;
  bool wrong; // currently shaking from a wrong drop
  bool dragging; // currently being panned by the child
  bool consumed; // true once correctly placed on the plank

  _ForestLetterData({
    required this.letter,
    this.wrong = false,
    this.dragging = false,
    this.consumed = false,
  });
}

/// Per-round difficulty: how many letter choices are on screen.
class _RoundConfig {
  final int choiceCount;
  const _RoundConfig({required this.choiceCount});
}

// ═════════════════════════════════════════════════════════════════════════
// GAME
// ═════════════════════════════════════════════════════════════════════════

/// "Letter Treehouse" — the child helps build a treehouse by dragging the
/// letter matching the one shown above a wooden plank onto that plank.
/// Five rounds, one correct letter per round among a few distractors.
class LetterTreehouseGame extends StatefulWidget {
  final int level;

  /// Letters this level draws its target + distractors from — same
  /// letter-pool philosophy as AlphabetFishingGame.
  final List<String> letterPool;

  const LetterTreehouseGame({
    super.key,
    required this.level,
    this.letterPool = const [
      'A', 'B', 'C', 'D', 'E', 'F',
      'G', 'H', 'I', 'J', 'K', 'L',
      'M', 'N', 'O', 'P', 'Q', 'R',
      'S', 'T', 'U', 'V', 'W', 'X',
      'Y', 'Z',
    ],
  });

  @override
  State<LetterTreehouseGame> createState() => _LetterTreehouseGameState();
}

class _LetterTreehouseGameState extends State<LetterTreehouseGame>
    with
        TickerProviderStateMixin,
        // ASSUMPTION: I don't have Number1to5FillIglooScreen's source, so I
        // can't confirm it uses GameLoadingMixin/LoadingScreen — I've kept
        // them here for consistency with the rest of the Alphabet Forest
        // module. Drop this mixin (and the buildWithLoading() wrapper in
        // BUILD below) if FillIgloo actually loads differently.
        GameLoadingMixin<LetterTreehouseGame>,
        ForestAudioMixin<LetterTreehouseGame>,
        TofiReactionMixin<LetterTreehouseGame> {
  @override
  AudioPlayer get tofiPlayer => audio.voicePlayer;

  // ═════════════════════════════════════════════════════════════════════
  // ASSETS
  // ═════════════════════════════════════════════════════════════════════

  static const String _bgImage = 'assets/images/backgrounds/bg_game_forest_zoom_out.png';
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _plankImage = 'assets/images/objects/forest/plank.png';
  static const String _treeHouseImage = 'assets/images/objects/forest/treehouse.png';
  static const String _treeHouseBrokenImage = 'assets/images/objects/forest/treehouse_broken.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _sfxBase = ForestAudioAssets.sfxBase;

  static const String _audioIntro = '$_audioBase/letter_treehouse_intro.wav';
  static const String _audioWin = '$_audioBase/letter_treehouse_win.wav';
  static const String _sfxBuild = '$_sfxBase/build.wav';

  // ═════════════════════════════════════════════════════════════════════
  // GAME STRUCTURE
  // ═════════════════════════════════════════════════════════════════════

  static const List<_RoundConfig> _roundConfigs = [
    _RoundConfig(choiceCount: 3),
    _RoundConfig(choiceCount: 3),
    _RoundConfig(choiceCount: 3),
    _RoundConfig(choiceCount: 3),
    _RoundConfig(choiceCount: 3),
  ];
  static int get _totalRounds => _roundConfigs.length;
  static const int _maxChoices = 3;

  // ═════════════════════════════════════════════════════════════════════
  // STATE
  // ═════════════════════════════════════════════════════════════════════

  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  bool _interactionLocked = false; // true right after a correct drop, and during win sequence

  String _targetLetter = 'A';
  late List<_ForestLetterData> _pieces;
  bool _plankFilled = false;

  // Live drag tracking, in GLOBAL (screen) coordinates.
  _ForestLetterData? _draggedPiece;
  Offset? _dragGlobalPos;

  final GlobalKey _gameAreaKey = GlobalKey(); // for global → local conversion of the ghost
  final GlobalKey _plankKey = GlobalKey(); // for global drop-zone hit testing

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _tofiFloatCtrl; // dog idle float
  late AnimationController _targetBounceCtrl; // gentle bounce on the target letter
  late Animation<double> _targetBounce;
  late AnimationController _instructionCtrl; // banner bounce on round start
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _piecesEntranceCtrl; // letter pieces entrance
  late Animation<double> _piecesEntrance;

  late AnimationController _plankPulseCtrl; // plank pulse + letter pop on correct
  late List<AnimationController> _shakeCtrls; // one wrong-answer shake per piece slot
  late List<Animation<double>> _shakeAnims;

  // ═════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRound(isFirstRound: true);
    finishLoading(_startIntroFlow);
  }

  void _initAnimations() {
    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _targetBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _targetBounce = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _targetBounceCtrl, curve: Curves.easeInOut),
    );

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

    _piecesEntranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _piecesEntrance = CurvedAnimation(parent: _piecesEntranceCtrl, curve: Curves.easeOutBack);

    _plankPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _shakeCtrls = List.generate(
      _maxChoices,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400)),
    );
    _shakeAnims = _shakeCtrls
        .map(
          (c) => TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.1), weight: 25),
            TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 50),
            TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 25),
          ]).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    _piecesEntranceCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _announceInstruction();
  }

  // ═════════════════════════════════════════════════════════════════════
  // ROUND SETUP
  // ═════════════════════════════════════════════════════════════════════

  void _setupRound({bool isFirstRound = false}) {
    _interactionLocked = false;
    _plankFilled = false;
    _draggedPiece = null;
    _dragGlobalPos = null;

    _plankPulseCtrl.reset();
    for (final ctrl in _shakeCtrls) {
      ctrl.reset();
    }

    final config = _roundConfigs[_currentRound];
    final rng = Random();

    _targetLetter = widget.letterPool[rng.nextInt(widget.letterPool.length)];
    final distractorPool = widget.letterPool.where((l) => l != _targetLetter).toList()
      ..shuffle(rng);
    final distractorCount = min(config.choiceCount - 1, distractorPool.length);
    final distractors = distractorPool.take(distractorCount).toList();

    final letters = [_targetLetter, ...distractors]..shuffle(rng);
    _pieces = letters.map((l) => _ForestLetterData(letter: l)).toList();

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);
    _piecesEntranceCtrl.forward(from: 0);

    setState(() {});

    if (!isFirstRound) {
      _announceInstruction();
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // DRAG LOGIC
  // ═════════════════════════════════════════════════════════════════════

  void _onDragStart(_ForestLetterData piece, DragStartDetails details) {
    if (_interactionLocked || piece.consumed) return;
    setState(() {
      piece.dragging = true;
      _draggedPiece = piece;
      _dragGlobalPos = details.globalPosition;
    });
  }

  void _onDragUpdate(_ForestLetterData piece, DragUpdateDetails details) {
    if (_draggedPiece != piece) return;
    setState(() => _dragGlobalPos = details.globalPosition);
  }

  void _onDragEnd(_ForestLetterData piece, DragEndDetails details) {
    if (_draggedPiece != piece || _dragGlobalPos == null) return;

    final droppedOnPlank = _isOverPlank(_dragGlobalPos!);
    final dropLetter = piece.letter;

    setState(() {
      piece.dragging = false;
      _draggedPiece = null;
      _dragGlobalPos = null;
    });

    if (droppedOnPlank) {
      _onLetterDropped(dropLetter, piece);
    }
    // If released elsewhere: nothing else to do — the piece's base widget
    // never moved from its grid slot, so it's already "back" in place.
  }

  /// Global-position hit test: is [globalPos] currently over the plank?
  bool _isOverPlank(Offset globalPos) {
    final plankBox = _plankKey.currentContext?.findRenderObject() as RenderBox?;
    if (plankBox == null || !plankBox.attached) return false;
    final topLeft = plankBox.localToGlobal(Offset.zero);
    final rect = topLeft & plankBox.size;
    return rect.contains(globalPos);
  }

  Future<void> _announceInstruction() async {
    await playVoice(ForestAudioAssets.forLetter(_targetLetter));
  }

  Future<void> _onLetterDropped(String letter, _ForestLetterData piece) async {
    if (_interactionLocked || _plankFilled) return;

    if (letter == _targetLetter) {
      await _handleCorrectAnswer(piece);
    } else {
      await _handleWrongAnswer(piece);
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // CORRECT ANSWER
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _handleCorrectAnswer(_ForestLetterData piece) async {
    if (_interactionLocked) return; // guard against double-fires
    _interactionLocked = true;
    HapticFeedback.mediumImpact();

    setState(() {
      piece.consumed = true;
    });

    await playSfx(_sfxBuild);
    if (!mounted) return;

    setState(() {
      _plankFilled = true;
    });

    _plankPulseCtrl.forward(from: 0);
    showTofiReaction(TofiState.correct);
    if (!mounted) return;

    _solvedRounds++;
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    await _advanceRound();
  }

  // ═════════════════════════════════════════════════════════════════════
  // WRONG ANSWER
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _handleWrongAnswer(_ForestLetterData piece) async {
    HapticFeedback.heavyImpact();

    final index = _pieces.indexOf(piece).clamp(0, _maxChoices - 1);
    setState(() => piece.wrong = true);
    _shakeCtrls[index].forward(from: 0);

    await showTofiReaction(TofiState.wrong);
    if (!mounted) return;
    setState(() => piece.wrong = false);
    // Round stays active; the letter remains available, per spec.
  }

  // ═════════════════════════════════════════════════════════════════════
  // ROUND PROGRESSION
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _advanceRound() async {
    if (_currentRound >= _totalRounds - 1) {
      await playVoice(_audioWin);
      if (!mounted) return;

      await ForestProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;

      _showGoodJob();
      return;
    }

    _currentRound++;
    _setupRound();
  }

  // ═════════════════════════════════════════════════════════════════════
  // GOOD JOB
  // ═════════════════════════════════════════════════════════════════════

  void _showGoodJob() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: _dogImage,
          
          onNext: () {
            Navigator.of(context).pop();
            // TODO: @Tin fix nav after ending game
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlphabetIntroScreen(letter: 'A'),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LetterTreehouseGame(
                  level: widget.level,
                  letterPool: widget.letterPool,
                ),
              ),
            );
          },
          onBack: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _tofiFloatCtrl.dispose();
    _targetBounceCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _piecesEntranceCtrl.dispose();
    _plankPulseCtrl.dispose();
    for (final ctrl in _shakeCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.alphabetForest(),
        gameBuilder: () => Stack(
          key: _gameAreaKey,
          children: [
            if (_introPlaying) _buildIntroLayer() else _buildGameContent(),
            if (!_introPlaying) buildTofi(context),
            if (_draggedPiece != null) _buildDragGhost(),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // INTRO
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        const Positioned(top: 25, left: 25, child: ForestXButton()),
        Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _tofiFloatCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    0,
                    Tween<double>(begin: -6, end: 6).evaluate(
                      CurvedAnimation(parent: _tofiFloatCtrl, curve: Curves.easeInOut),
                    ),
                  ),
                  child: child,
                ),
                child: Image.asset(
                  _dogImage,
                  height: screenH * 0.72,
                  errorBuilder: (_, __, ___) => const Text('🐶', style: TextStyle(fontSize: 80)),
                ),
              ),
              const SizedBox(width: 120),
              Image.asset(
                _treeHouseBrokenImage,
                height: screenH * 0.72,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // GAME CONTENT
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildGameContent() {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        _buildMainLayout(),
      ],
    );
  }

  Widget _buildMainLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScaleTransition(
          scale: _sceneEnter,
          child: Stack(
            children: [
              const Positioned(top: 25, left: 25, child: ForestXButton()),
              Positioned(top: 25, right: 20, child: ForestLevelBadge(level: widget.level)),

              Padding(
                padding: const EdgeInsets.only(top: 95, bottom: 60),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Empty space on the left reserved for Tofi's reaction overlay.
                    const Expanded(flex: 3, child: SizedBox.shrink()),

                    // Letter choices, stacked top to bottom.
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildLetterPiecesArea(),
                      ),
                    ),

                    // RIGHT SIDE — treehouse, now also the drop target.
                    Expanded(
                      flex: 7,
                      child: LayoutBuilder(
                        builder: (context, inner) =>
                            _buildTreehouseArea(inner.maxWidth, inner.maxHeight),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: _buildProgressDots(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // LETTER PIECES
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildLetterPiecesArea() {
    return ScaleTransition(
      scale: _piecesEntrance,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _pieces.length; i++) ...[
            _buildDraggableLetterPiece(_pieces[i], i),
            if (i != _pieces.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildDraggableLetterPiece(_ForestLetterData piece, int index) {
    const size = 78.0;
    const pieceWidth = size * 1.5;
    const pieceHeight = size * 0.8;

    if (piece.consumed) {
      // Already placed on the plank — leave an empty gap in the tray.
      return const SizedBox(width: pieceWidth, height: pieceHeight);
    }

    return AnimatedBuilder(
      animation: _shakeCtrls[index],
      builder: (_, child) {
        final angle = piece.wrong ? _shakeAnims[index].value : 0.0;
        return Transform.rotate(angle: angle, child: child);
      },
      child: GestureDetector(
        onPanStart: (details) => _onDragStart(piece, details),
        onPanUpdate: (details) => _onDragUpdate(piece, details),
        onPanEnd: (details) => _onDragEnd(piece, details),
        child: Opacity(
          opacity: piece.dragging ? 0.3 : 1.0,
          child: _buildLetterPiece(piece.letter, size, wrong: piece.wrong),
        ),
      ),
    );
  }

  Widget _buildLetterPiece(String letter, double size, {required bool wrong}) {
    final pieceWidth = size * 1.5;
    final pieceHeight = size * 0.8;

    return Container(
      width: pieceWidth,
      height: pieceHeight,
      decoration: wrong
          ? BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade400, width: 3),
      )
          : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            _plankImage,
            width: pieceWidth,
            height: pieceHeight,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => Container(
              width: pieceWidth,
              height: pieceHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFC68B59),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8B5A2B), width: 4),
              ),
            ),
          ),
          _outlinedLetter(
            letter,
            fontSize: size * 0.42,
            fillColor: wrong ? Colors.red.shade600 : ForestColorTheme.darkseagreen,
          ),
        ],
      ),
    );
  }

  Widget _buildDragGhost() {
    final piece = _draggedPiece;
    final globalPos = _dragGlobalPos;
    if (piece == null || globalPos == null) return const SizedBox.shrink();

    final areaBox = _gameAreaKey.currentContext?.findRenderObject() as RenderBox?;
    final localPos = areaBox != null && areaBox.attached
        ? areaBox.globalToLocal(globalPos)
        : globalPos;

    const ghostSize = 92.0; // slightly larger than the resting piece

    return Positioned(
      left: localPos.dx - ghostSize / 2,
      top: localPos.dy - ghostSize / 2,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1.1,
          child: _buildLetterPiece(piece.letter, ghostSize, wrong: false),
        ),
      ),
    );
  }

  Widget _buildTreehouseArea(double w, double h) {
    return AnimatedBuilder(
      animation: _plankPulseCtrl,
      builder: (_, child) {
        final scale = 1.0 + (sin(_plankPulseCtrl.value.clamp(0.0, 1.0) * pi) * 0.06);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        key: _plankKey,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Image.asset(
            _plankFilled ? _treeHouseImage : _treeHouseBrokenImage,
            key: ValueKey(_plankFilled),
            width: w * 1.2,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => SizedBox(
              width: w * 0.95,
              height: h * 0.8,
              child: Center(
                child: Text(
                  _plankFilled ? '🏠' : '🏚️',
                  style: const TextStyle(fontSize: 90),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlinedLetter(String letter, {required double fontSize, required Color fillColor}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.09
              ..color = Colors.white,
          ),
        ),
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            color: fillColor,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // PROGRESS
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedRounds;
        final current = i == _currentRound;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ForestColorTheme.mediumseagreen
                : current
                    ? ForestColorTheme.seagreen
                    : ForestColorTheme.seagreen.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
