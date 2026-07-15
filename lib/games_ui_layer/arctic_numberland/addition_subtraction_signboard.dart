import 'dart:async';
import 'dart:math';
import 'package:StarSight/games_ui_layer/arctic_numberland/snowman_shape_hunt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_audio_helper.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';

enum _RoundType { addition, subtraction }

class _RoundSpec {
  final _RoundType type;
  final int a; // addend A (addition) or minuend (subtraction)
  final int b; // addend B (addition) or subtrahend (subtraction)
  const _RoundSpec(this.type, this.a, this.b);
}

class SignboardMathGame extends StatefulWidget {
  final int level;

  const SignboardMathGame({super.key, required this.level});

  @override
  State<SignboardMathGame> createState() => _SignboardMathGameState();
}

class _SignboardMathGameState extends State<SignboardMathGame>
    with TickerProviderStateMixin, DomaReactionMixin<SignboardMathGame>, GameLoadingMixin<SignboardMathGame>, ArcticAudioMixin  {
  @override
  AudioPlayer get domaPlayer => _voicePlayer;

  // ── Asset paths (swap to match your project) ────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _signboardAsset = 'assets/images/objects/arctic/snowy_signboard_big.png';
  static const String _tagAsset = 'assets/images/objects/arctic/tag.png';

  /// Small repeatable icons suitable for picture clusters.
  static const List<String> _clusterAssets = [
    'assets/images/objects/arctic/candy_cane.png',
    'assets/images/objects/arctic/earmuffs.png',
    'assets/images/objects/arctic/ice_1.png',
    'assets/images/objects/arctic/ice_skates.png',
    'assets/images/objects/arctic/icecream.png',
    'assets/images/objects/arctic/igloo.png',
    'assets/images/objects/arctic/snowball.png',
    'assets/images/objects/arctic/snowglobe.png',
    'assets/images/objects/arctic/snowman.png',
    'assets/images/objects/arctic/winter_hat.png',
  ];

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/signboard_intro.wav';
  static const String _audioRoundPromptAdd = '$_audioBase/signboard_add_instruction.wav';
  static const String _audioRoundPromptSub = '$_audioBase/signboard_sub_instruction.wav';
  static const String _audioBury = 'assets/audio/sound_effects/erase.wav';
  static const String _audioPlace = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioWin = '$_audioBase/signboard_win.wav';

  // ── Game constants ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  /// Mixed pool of addition and subtraction round specs, kept to counts of
  /// 5 or less, matching the visual/counting range of the rest of Arctic
  /// Numberland.
  static final List<_RoundSpec> _specPool = [
    const _RoundSpec(_RoundType.addition, 1, 2),
    const _RoundSpec(_RoundType.addition, 2, 1),
    const _RoundSpec(_RoundType.addition, 1, 3),
    const _RoundSpec(_RoundType.addition, 2, 2),
    const _RoundSpec(_RoundType.addition, 1, 4),
    const _RoundSpec(_RoundType.addition, 3, 2),
    const _RoundSpec(_RoundType.subtraction, 3, 1),
    const _RoundSpec(_RoundType.subtraction, 4, 1),
    const _RoundSpec(_RoundType.subtraction, 4, 2),
    const _RoundSpec(_RoundType.subtraction, 5, 2),
    const _RoundSpec(_RoundType.subtraction, 5, 3),
    const _RoundSpec(_RoundType.subtraction, 3, 2),
  ];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  bool _showWinDialog = false;
  int _solvedCount = 0;
  bool _resolvingRound = false;

  late List<_RoundSpec> _roundPool;
  late _RoundSpec _spec;
  late int _target;

  // Addition round assets
  late String _itemAAsset;
  late String _itemBAsset;

  // Subtraction round asset + burial state
  late String _subItemAsset;
  late List<bool> _buried;

  /// Puzzle-piece answer choices for this round.
  late List<int> _choices;
  int? _placedChoiceIndex; // which tray piece currently sits in the slot
  bool _placementWrong = false;

  // ── Audio ────────────────────────────────────────────────────────────────
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _snapPulseCtrl;
  late Animation<double> _snapPulse;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _roundPool = List.of(_specPool, growable: true)..shuffle();
    _initAnimations();
    _setupRound();
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

    _snapPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _snapPulse = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
    ]).animate(CurvedAnimation(parent: _snapPulseCtrl, curve: Curves.easeOut));
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
  }

  void _setupRound() {
    if (_roundPool.isEmpty) {
      _roundPool = List.of(_specPool, growable: true)..shuffle();
    }
    _spec = _roundPool.removeLast();
    final rng = Random();

    if (_spec.type == _RoundType.addition) {
      _target = _spec.a + _spec.b;
      final shuffled = [..._clusterAssets]..shuffle(rng);
      _itemAAsset = shuffled[0];
      _itemBAsset = shuffled[1];
    } else {
      _target = _spec.a - _spec.b;
      _subItemAsset = ([..._clusterAssets]..shuffle(rng)).first;
      _buried = List.filled(_spec.a, false);
    }

    _choices = _buildChoices(_target);
    _placedChoiceIndex = null;
    _placementWrong = false;
    _resolvingRound = false;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    if (!_introPlaying) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _playVoice(_spec.type == _RoundType.addition ? _audioRoundPromptAdd : _audioRoundPromptSub);
        }
      });
    }

    setState(() {});
  }

  List<int> _buildChoices(int target) {
    final rng = Random();
    final allNums = List.generate(5, (i) => i + 1);
    final distractors = [...allNums]..remove(target);
    distractors.shuffle(rng);
    return [...distractors.take(2), target]..shuffle(rng);
  }

  // ── Swipe-to-bury (subtraction rounds) ──────────────────────────────────
  void _handleBuryAt(Offset localPosition, double rowWidth, {required bool isFreshTouch}) {
    if (_resolvingRound || _spec.type != _RoundType.subtraction) return;
    final slotWidth = rowWidth / _spec.a;
    final index = (localPosition.dx / slotWidth).floor().clamp(0, _spec.a - 1);

    if (isFreshTouch && _buried[index]) {
      // tapping an already-buried item un-buries it
      setState(() => _buried[index] = false);
      return;
    }
    if (!_buried[index]) {
      HapticFeedback.selectionClick();
      _playSfx(_audioBury);
      setState(() => _buried[index] = true);
    }
  }

  // ── Puzzle piece drop handler (both round types) ────────────────────────
  Future<void> _onPieceDropped(int choiceIndex) async {
    if (_resolvingRound || _placedChoiceIndex != null) return;

    setState(() => _placedChoiceIndex = choiceIndex);
    final isCorrect = _choices[choiceIndex] == _target;

    if (isCorrect) {
      setState(() => _resolvingRound = true);
      HapticFeedback.mediumImpact();
      await _playSfxAndWait(_audioPlace);
      if (!mounted) return;
      _snapPulseCtrl.forward(from: 0);
      showDomaReaction(DomaState.correct);
      if (!mounted) return;

      setState(() => _solvedCount++);

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      if (_currentRound + 1 >= _totalRounds) {
        await _playVoice(_audioWin);
        if (!mounted) return;
        setState(() => _showWinDialog = true);
      } else {
        setState(() => _currentRound++);
        _setupRound();
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _placementWrong = true);
      await Future.delayed(const Duration(milliseconds: 350));
      await playSfx('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);
      if (!mounted) return;
      setState(() {
        _placedChoiceIndex = null;
        _placementWrong = false;
      });
    }
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
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Voice audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  void _playSfx(String asset) {
    _sfxPlayer.play(AssetSource(asset.replaceFirst('assets/', ''))).catchError((e) {
      debugPrint('SFX audio error ($asset): $e');
    });
  }

  Future<void> _playSfxAndWait(String asset) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      sub = _sfxPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _sfxPlayer.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future.timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('SFX audio error ($asset): $e');
    } finally {
      await sub?.cancel();
    }
  }

  @override
  void dispose() {
    _voicePlayer.dispose();
    _sfxPlayer.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _snapPulseCtrl.dispose();
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

  // ── Intro / story setup ──────────────────────────────────────────────────
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
                flex: 4,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      0,
                      Tween<double>(begin: -6, end: 6).evaluate(
                        CurvedAnimation(parent: _domaFloatCtrl, curve: Curves.easeInOut),
                      ),
                    ),
                    child: child,
                  ),
                  child: Image.asset(
                    _characterImage,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _signboardAsset,
                      height: screenH * 0.75,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text('🪧', style: TextStyle(fontSize: 70)),
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

        return Column(
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
                  Center(child: _buildInstructionBanner(h)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ScaleTransition(
                      scale: _sceneEnter,
                      child: _buildSignboardScene(w, h),
                    ),
                  ),
                  SizedBox(
                    width: w * 0.25,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildPieceTray(h),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _buildRoundIndicator(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionBanner(double h) {
    final label = _spec.type == _RoundType.addition
        ? 'Count them together, then fit the piece!'
        : 'Brush some away, then fit the piece!';

    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => _playVoice(
          _spec.type == _RoundType.addition ? _audioRoundPromptAdd : _audioRoundPromptSub,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
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
            label,
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }

  // ── Signboard scene ──────────────────────────────────────────────────────
  Widget _buildSignboardScene(double w, double h) {
    final boardWidth = (w * 0.60);
    final boardHeight = h * 0.85;
    final itemSize = (h * 0.15);

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                _signboardAsset,
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    color: ArcticColorTheme.cotton.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: boardWidth * 0.08, vertical: boardHeight * 0.2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _spec.type == _RoundType.addition
                        ? _buildAdditionClusters(itemSize)
                        : _buildSubtractionClusterWithBury(boardWidth * 0.7, itemSize),
                  ),
                  _buildTagSlot(itemSize),
                ],
              ),
            ),
            Positioned(
              bottom: boardHeight * 0.30,
              right: boardWidth * 0.06,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  _spec.type == _RoundType.addition
                      ? '${_spec.a} + ${_spec.b} = ?'
                      : '${_spec.a} − ${_spec.b} = ?',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontSize: (boardHeight * 0.09),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionClusters(double itemSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _clusterGroup(_itemAAsset, _spec.a, itemSize),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '+',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: itemSize * 0.55,
              fontWeight: FontWeight.bold,
              color: ArcticColorTheme.cotton,
            ),
          ),
        ),
        _clusterGroup(_itemBAsset, _spec.b, itemSize),
      ],
    );
  }

  Widget _clusterGroup(String asset, int count, double itemSize) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: List.generate(count, (_) {
        return Image.asset(
          asset,
          height: itemSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.star, size: itemSize, color: ArcticColorTheme.pictonblue),
        );
      }),
    );
  }

  /// Subtraction cluster with swipe-to-bury gesture handling.
  Widget _buildSubtractionClusterWithBury(double rowWidth, double itemSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = rowWidth.clamp(0.0, constraints.maxWidth);
        return Center(
          child: SizedBox(
            width: effectiveWidth,
            child: GestureDetector(
              onPanDown: (details) =>
                  _handleBuryAt(details.localPosition, effectiveWidth, isFreshTouch: true),
              onPanUpdate: (details) =>
                  _handleBuryAt(details.localPosition, effectiveWidth, isFreshTouch: false),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_spec.a, (i) {
                  final isBuried = _buried[i];
                  return AnimatedOpacity(
                    opacity: isBuried ? 0.2 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: AnimatedScale(
                      scale: isBuried ? 0.6 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            _subItemAsset,
                            height: itemSize,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.circle, size: itemSize, color: ArcticColorTheme.pictonblue),
                          ),
                          if (isBuried)
                            Icon(Icons.ac_unit, size: itemSize * 0.9, color: Colors.white.withValues(alpha: 0.85)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Tag slot where the correct puzzle piece gets dropped.
  Widget _buildTagSlot(double itemSize) {
    final slotSize = itemSize * 0.95;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => !_resolvingRound && _placedChoiceIndex == null,
      onAcceptWithDetails: (details) => _onPieceDropped(details.data),
      builder: (context, candidateData, rejectedData) {
        final highlight = candidateData.isNotEmpty;
        final filled = _placedChoiceIndex != null;

        if (filled) {
          return SizedBox(
            width: slotSize * 1.3,
            height: slotSize * 1.3,
            child: Center(
              child: ScaleTransition(
                scale: !_placementWrong ? _snapPulse : const AlwaysStoppedAnimation(1.0),
                child: _tagChoices(_choices[_placedChoiceIndex!], slotSize, wrong: _placementWrong),
              ),
            ),
          );
        }

        return Container(
          width: slotSize * 1.3,
          height: slotSize * 1.3,
          decoration: BoxDecoration(
            color: highlight
                ? ArcticColorTheme.pictonblue.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(
              color: highlight ? ArcticColorTheme.pictonblue : ArcticColorTheme.slateblue.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.help_outline,
            size: slotSize * 0.6,
            color: ArcticColorTheme.cotton.withValues(alpha: highlight ? 0.9 : 0.4),
          ),
        );
      },
    );
  }

  /// Draggable puzzle-piece tray with the answer choices.
  Widget _buildPieceTray(double h) {
    final pieceSize = (h * 0.13).clamp(50.0, 78.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_choices.length, (i) {
        final placed = _placedChoiceIndex == i;
        final piece = _tagChoices(_choices[i], pieceSize, wrong: false);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: placed
              ? Opacity(opacity: 0.15, child: piece)
              : Draggable<int>(
            data: i,
            feedback: Material(color: Colors.transparent, child: piece),
            childWhenDragging: Opacity(opacity: 0.3, child: piece),
            child: piece,
          ),
        );
      }),
    );
  }

  /// Tag image with the choice number layered above it.
  Widget _tagChoices(int value, double size, {required bool wrong}) {
    return SizedBox(
      width: size * 1.30,
      height: size * 1.30,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Image.asset(
            _tagAsset,
            width: size * 1.30,
            height: size * 1.30,
            fit: BoxFit.contain,
            color: wrong ? Colors.red.shade300 : null,
            colorBlendMode: wrong ? BlendMode.modulate : null,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: wrong ? Colors.red.shade300 : ArcticColorTheme.pictonblue,
                borderRadius: BorderRadius.circular(size * 0.22),
              ),
            ),
          ),
          Positioned(
            top: size * 0.30,
            bottom: 0,
            child: Text(
              '$value',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                color: wrong ? Colors.red.shade300 : ArcticColorTheme.cotton,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.60,
              ),
            ),
          ),
        ],
      ),
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
        Navigator.pop(context, SnowmanShapeHuntGame(level: widget.level + 1));
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedCount = 0;
          _roundPool = List.of(_specPool, growable: true)..shuffle();
          _setupRound();
        });
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}