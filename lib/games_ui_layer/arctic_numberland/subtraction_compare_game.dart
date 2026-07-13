import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';

class SubtractionCompareGame extends StatefulWidget {
  final int level;

  const SubtractionCompareGame({super.key, required this.level});

  @override
  State<SubtractionCompareGame> createState() =>
      _SubtractionCompareGameState();
}

class _SubtractionCompareGameState extends State<SubtractionCompareGame>
    with TickerProviderStateMixin, DomaReactionMixin<SubtractionCompareGame>, GameLoadingMixin<SubtractionCompareGame> {
  @override
  AudioPlayer get domaPlayer => _voicePlayer;

  // ── Asset paths (swap to match your project) ────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _candyCaneAsset = 'assets/images/objects/arctic/candy_cane.png';
  static const String _iceCreamAsset = 'assets/images/objects/arctic/icecream.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/treat_compare_intro.wav';
  static const String _audioInstruction = '$_audioBase/treat_compare_instruction.wav';
  static const String _audioTreatPlaceRemove = 'assets/audio/sound_effects/bubble_pop.wav';
  static const String _audioWin = '$_audioBase/mahusay.wav';

  // ── Game constants ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  /// [bigger, smaller] pairs — candy canes (fixed row) vs. ice cream cups
  /// (draggable). Difference kept to 4 or less, matching the visual/
  /// counting range of the rest of Arctic Numberland.
  static const List<List<int>> _factPool = [
    [2, 1], // leftover 1
    [3, 1], // leftover 2
    [3, 2], // leftover 1
    [4, 1], // leftover 3
    [4, 2], // leftover 2
    [4, 3], // leftover 1
    [5, 1], // leftover 4
    [5, 2], // leftover 3
    [5, 3], // leftover 2
    [5, 4], // leftover 1
  ];

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  bool _showWinDialog = false;
  int _solvedCount = 0;
  bool _resolvingRound = false;

  late List<List<int>> _roundPool;
  late int _biggerCount;   // candy canes shown, fixed
  late int _smallerCount;  // ice cream cups available to place
  late int _target;        // leftover = biggerCount - smallerCount

  /// One slot per candy cane. Holds the tray index of the ice cream cup
  /// stacked under it, or null if that candy cane has no partner yet.
  late List<int?> _pairedSlot;

  /// Parallel to the ice cream tray — true once that cup has been placed.
  late List<bool> _trayUsed;

  /// Confirmation number choices, shown once every cup has been placed.
  late List<int> _choices;
  int? _tappedChoiceIndex;

  bool get _readyForConfirm =>
      !_resolvingRound && _trayUsed.every((used) => used);

  // ── Audio ────────────────────────────────────────────────────────────────
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;
  late AnimationController _leftoverPulseCtrl;
  late Animation<double> _leftoverPulse;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _roundPool = [..._factPool]..shuffle();
    _initAnimations();
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

    _leftoverPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _leftoverPulse = Tween(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _leftoverPulseCtrl, curve: Curves.easeInOut));
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    _setupRound();
  }

  void _setupRound() {
    if (_roundPool.isEmpty) {
      _roundPool = [..._factPool]..shuffle();
    }
    final fact = _roundPool.removeLast();
    _biggerCount = fact[0];
    _smallerCount = fact[1];
    _target = _biggerCount - _smallerCount;

    _pairedSlot = List.filled(_biggerCount, null);
    _trayUsed = List.filled(_smallerCount, false);
    _choices = _buildChoices(_target);
    _tappedChoiceIndex = null;
    _resolvingRound = false;

    _sceneEnterCtrl.forward(from: 0);
    _instructionCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _playVoice(_audioInstruction);
    });

    setState(() {});
  }

  List<int> _buildChoices(int target) {
    final rng = Random();
    final allNums = List.generate(5, (i) => i + 1);
    final distractors = [...allNums]..remove(target);
    distractors.shuffle(rng);
    return [...distractors.take(2), target]..shuffle(rng);
  }

  // ── Drag handlers ────────────────────────────────────────────────────────
  void _onCupDropped(int slotIndex, int trayIndex) {
    if (_resolvingRound || _pairedSlot[slotIndex] != null || _trayUsed[trayIndex]) {
      return;
    }

    HapticFeedback.selectionClick();
    _playSfx(_audioTreatPlaceRemove);

    setState(() {
      _pairedSlot[slotIndex] = trayIndex;
      _trayUsed[trayIndex] = true;
    });
  }

  void _onCupRemoved(int slotIndex) {
    if (_resolvingRound || _pairedSlot[slotIndex] == null) return;
    final trayIndex = _pairedSlot[slotIndex]!;
    _playVoice(_audioTreatPlaceRemove);
    setState(() {
      _pairedSlot[slotIndex] = null;
      _trayUsed[trayIndex] = false;
      _tappedChoiceIndex = null;
    });
  }

  // ── Confirmation tap ─────────────────────────────────────────────────────
  Future<void> _onChoiceTap(int index) async {
    if (!_readyForConfirm || _tappedChoiceIndex != null) return;
    setState(() => _tappedChoiceIndex = index);

    final isCorrect = _choices[index] == _target;

    if (isCorrect) {
      setState(() => _resolvingRound = true);
      HapticFeedback.mediumImpact();
      showDomaReaction(DomaState.correct);
      if (!mounted) return;

      setState(() => _solvedCount++);

      await Future.delayed(const Duration(milliseconds: 600));
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
      showDomaReaction(DomaState.wrong);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _tappedChoiceIndex = null);
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

  @override
  void dispose() {
    _voicePlayer.dispose();
    _sfxPlayer.dispose();
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
    _leftoverPulseCtrl.dispose();
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
                      _candyCaneAsset,
                      height: screenH * 0.25,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text('🍬', style: TextStyle(fontSize: 70)),
                    ),
                    Image.asset(
                      _iceCreamAsset,
                      height: screenH * 0.25,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text('🍧', style: TextStyle(fontSize: 70)),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: (w * 0.18).clamp(90.0, 140.0)),
                        Expanded(
                          flex: 7,
                          child: ScaleTransition(
                            scale: _sceneEnter,
                            child: _buildCompareScene(w, h),
                          ),
                        ),
                        SizedBox(
                          width: (w * 0.18).clamp(90.0, 140.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _readyForConfirm
                                ? _buildConfirmRow(h, key: const ValueKey('confirm'))
                                : const SizedBox(key: ValueKey('empty')),
                          ),
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
    return ScaleTransition(
      scale: _instructionBounce,
      child: GestureDetector(
        onTap: () => _playVoice(_audioInstruction),
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
            'How many candy canes are left without a treat?',
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

  // ── Comparison scene: candy cane row + stacked cup slots + tray ─────────
  Widget _buildCompareScene(double w, double h) {
    final slotWidth = (w * 0.85 / _biggerCount).clamp(50.0, 100.0);
    final caneSize = (slotWidth * 0.8).clamp(40.0, 76.0);
    final cupSize = caneSize * 0.85;

    return Center(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: h * 0.03),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_biggerCount, (i) {
                    return SizedBox(
                      width: slotWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            _candyCaneAsset,
                            height: caneSize,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                Text('🍬', style: TextStyle(fontSize: caneSize * 0.7)),
                          ),
                          const SizedBox(height: 6),
                          _buildCupSlot(i, cupSize),
                        ],
                      ),
                    );
                  }),
                ),
                SizedBox(height: h * 0.03),
                _buildCupTray(cupSize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A single drop slot under a candy cane. Highlights (pulses) once the
  /// tray has run out and this slot never got a partner.
  Widget _buildCupSlot(int slotIndex, double size) {
    final filledTrayIndex = _pairedSlot[slotIndex];
    final isLeftover = _readyForConfirm && filledTrayIndex == null;

    Widget slot = DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
      !_resolvingRound && _pairedSlot[slotIndex] == null && !_trayUsed[details.data],
      onAcceptWithDetails: (details) => _onCupDropped(slotIndex, details.data),
      builder: (context, candidateData, rejectedData) {
        final highlight = candidateData.isNotEmpty;
        if (filledTrayIndex != null) {
          return GestureDetector(
            onTap: () => _onCupRemoved(slotIndex),
            child: Image.asset(
              _iceCreamAsset,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text('🍦', style: TextStyle(fontSize: size * 0.7)),
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: highlight
                ? ArcticColorTheme.pictonblue.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight ? ArcticColorTheme.pictonblue : Colors.white,
              width: 2,
            ),
          ),
        );
      },
    );

    if (isLeftover) {
      slot = ScaleTransition(scale: _leftoverPulse, child: slot);
    }

    return slot;
  }

  /// Draggable ice cream cups the player pairs up with candy canes.
  Widget _buildCupTray(double size) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List.generate(_smallerCount, (i) {
        final used = _trayUsed[i];
        final cup = Image.asset(
          _iceCreamAsset,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text('🍦', style: TextStyle(fontSize: size * 0.7)),
        );

        if (used) {
          return SizedBox(width: size, height: size);
        }

        return Draggable<int>(
          data: i,
          feedback: Material(color: Colors.transparent, child: cup),
          childWhenDragging: Opacity(opacity: 0.25, child: cup),
          child: cup,
        );
      }),
    );
  }

  // ── Confirmation row ─────────────────────────────────────────────────────
  Widget _buildConfirmRow(double h, {Key? key}) {
    final btnSize = (h * 0.11).clamp(46.0, 66.0);

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_choices.length, (index) {
          final isCorrect = _choices[index] == _target;
          final isTapped = _tappedChoiceIndex == index;
          Color bg = ArcticColorTheme.pictonblue;
          if (_tappedChoiceIndex != null) {
            if (isCorrect) {
              bg = Colors.green;
            } else if (isTapped) {
              bg = Colors.red;
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: GestureDetector(
              onTap: _tappedChoiceIndex == null ? () => _onChoiceTap(index) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.4), blurRadius: 8)],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${_choices[index]}',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: btnSize * 0.42,
                  ),
                ),
              ),
            ),
          );
        }),
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
        // TODO @Tin navigate to next games
        // Navigator.pop(context, const ());
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedCount = 0;
          _roundPool = [..._factPool]..shuffle();
          _setupRound();
        });
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}