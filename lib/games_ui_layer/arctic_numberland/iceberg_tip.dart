import 'dart:math';
import 'package:StarSight/games_ui_layer/arctic_numberland/snowglobe_shake_count.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/arctic_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_audio_helper.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';

class IcebergTipGame extends StatefulWidget {
  final int level;

  const IcebergTipGame({super.key, required this.level});

  @override
  State<IcebergTipGame> createState() => _IcebergTipGameState();
}

class _IcebergTipGameState extends State<IcebergTipGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin<IcebergTipGame>,
        GameLoadingMixin<IcebergTipGame>,
        ArcticAudioMixin<IcebergTipGame> {
  @override
  AudioPlayer get domaPlayer => audio.voicePlayer;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic_sea.png';
  static const String _characterImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _icebergAsset = 'assets/images/objects/arctic/iceberg.png';

  static const String _audioBase = 'assets/audio/arctic_numberland';
  static const String _audioIntro = '$_audioBase/iceberg_tip_intro.wav';
  static const String _audioInstruction = '$_audioBase/iceberg_tip_instruction.wav';
  static const String _audioWin = '$_audioBase/iceberg_tip_win.wav';

  // ── Game structure ───────────────────────────────────────────────────────
  static const int _totalRounds = 5;

  // ── State ────────────────────────────────────────────────────────────────
  bool _introPlaying = true;
  int _currentRound = 0;
  int _solvedRounds = 0;
  bool _showWinDialog = false;

  late int _numberA;
  late int _numberB;
  late List<int> _numberPool;
  bool _revealed = false;
  int? _tappedIndex; // 0 = left, 1 = right
  bool _resolving = false;
  bool _wrongShake = false;

  late AnimationController _domaFloatCtrl;
  late AnimationController _instructionCtrl;
  late Animation<double> _instructionBounce;
  late AnimationController _sceneEnterCtrl;
  late Animation<double> _sceneEnter;

  final _rng = Random();

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();
    _initAnimations();
    _setupRound(playInstruction: false);
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
  }

  // ── Flow ─────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await playVoice(_audioIntro);
    if (!mounted) return;
    setState(() => _introPlaying = false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) playVoice(_audioInstruction);
  }

  void _setupRound({bool playInstruction = true}) {
    // Refill the pool at the start of a fresh game (or if it ever runs low).
    if (_currentRound == 0 || _numberPool.length < 2) {
      _numberPool = List.generate(10, (i) => i + 1)..shuffle(_rng);
    }

    _numberA = _numberPool.removeLast();
    _numberB = _numberPool.removeLast();

    _revealed = false;
    _tappedIndex = null;
    _resolving = false;
    _wrongShake = false;

    _sceneEnterCtrl.forward(from: 0);

    if (playInstruction) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) playVoice(_audioInstruction);
      });
    }

    setState(() {});
  }

  // ── Tap handling ─────────────────────────────────────────────────────────
  Future<void> _onIcebergTapped(int index) async {
    if (_resolving) return;
    _resolving = true;

    HapticFeedback.selectionClick();
    setState(() {
      _revealed = true;
      _tappedIndex = index;
    });

    // Let the underwater reveal animation play out before judging.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final biggerIsA = _numberA > _numberB;
    final correctIndex = biggerIsA ? 0 : 1;

    if (index == correctIndex) {
      HapticFeedback.mediumImpact();
      await playSfx('$_audioBase/${max(_numberA, _numberB)}.wav');
      showDomaReaction(DomaState.correct);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await _onRoundComplete();
    } else {
      HapticFeedback.heavyImpact();
      await playSfx('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);
      setState(() => _wrongShake = true);
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      setState(() {
        _wrongShake = false;
        _revealed = false;
        _tappedIndex = null;
        _resolving = false;
      });
    }
  }

  Future<void> _onRoundComplete() async {
    setState(() => _solvedRounds++);

    if (_currentRound + 1 >= _totalRounds) {
      await playVoice(_audioWin);
      await ArcticProgressService.instance.markLevelComplete(widget.level);
      if (!mounted) return;
      setState(() => _showWinDialog = true);
    } else {
      setState(() => _currentRound++);
      _setupRound(playInstruction: false);
    }
  }

  @override
  void dispose() {
    _domaFloatCtrl.dispose();
    _instructionCtrl.dispose();
    _sceneEnterCtrl.dispose();
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

  // ── Intro layer ──────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(top: 25, left: 20, child: ArcticBackButton()),
        Positioned(top: 25, right: 20, child: ArcticLevelBadge(level: widget.level)),
        Center(
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

              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Spacer(),
                  Image.asset(
                    _characterImage,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
                  ),
                  Spacer(),
                  Image.asset(
                    _icebergAsset,
                    height: screenH * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('🐧', style: TextStyle(fontSize: 70)),
                  ),
                  Spacer(),
                ],
              )
          ),
        )
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
              child: ScaleTransition(
                scale: _sceneEnter,
                child: _buildIcebergScene(w, h),
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
        onTap: () => playVoice(_audioInstruction),
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
            'Tap the BIGGER iceberg/number!',
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

  // ── Iceberg scene ────────────────────────────────────────────────────────
  Widget _buildIcebergScene(double w, double h) {
    final icebergWidth = (w * 0.25).clamp(120.0, 220.0);
    final maxTotalHeight = h * 0.82;

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildIceberg(0, _numberA, icebergWidth, maxTotalHeight),
          _buildIceberg(1, _numberB, icebergWidth, maxTotalHeight),
        ],
      ),
    );
  }

  Widget _buildIceberg(int index, int number, double width, double maxTotalHeight) {
    final iceHeight = (number / 10.0) * maxTotalHeight;
    final aboveWater = iceHeight * 0.39;

    final tapped = _tappedIndex == index;
    final shakeThis = _wrongShake && tapped;

    Widget iceberg = GestureDetector(
      onTap: () => _onIcebergTapped(index),
      child: SizedBox(
        width: width,
        height: maxTotalHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [

            // Iceberg image, progressively "cut open" from the tip downward
            // to reveal the submerged base — genuinely hidden, not just
            // tinted by a water overlay.
            Positioned(
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: aboveWater,
                  end: _revealed ? iceHeight : aboveWater,
                ),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, visibleHeight, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRect(
                        clipper: _TopRevealClipper(visibleHeight: visibleHeight),
                        child: child,
                      ),
                      // Marks the current "cut" boundary while mid-reveal.
                      if (visibleHeight < iceHeight - 1)
                        Positioned(
                          top: visibleHeight - 2,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              boxShadow: [
                                BoxShadow(
                                  color: ArcticColorTheme.pictonblue.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
                child: Image.asset(
                  _icebergAsset,
                  width: width,
                  height: iceHeight,
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) =>
                  const Text('🧊', style: TextStyle(fontSize: 60)),
                ),
              ),
            ),

            // Number badge on the tip
            Positioned(
              bottom: iceHeight - aboveWater * 0.01,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tapped
                      ? ArcticColorTheme.pictonblue
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tapped
                        ? Colors.white
                        : ArcticColorTheme.slateblue.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.10,
                    color: tapped ? Colors.white : ArcticColorTheme.slateblue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (shakeThis) {
      iceberg = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (_, t, child) {
          final dx = sin(t * pi * 6) * 6 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: iceberg,
      );
    }

    return iceberg;
  }

  // ── Progress dots ────────────────────────────────────────────────────────
  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _solvedRounds;
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
                ? ArcticColorTheme.cotton
                : ArcticColorTheme.cotton.withValues(alpha: 0.35),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SnowglobeShakeGame(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        setState(() {
          _showWinDialog = false;
          _currentRound = 0;
          _solvedRounds = 0;
          _setupRound();
        });
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
/// Clips the iceberg image from the top down to [visibleHeight], so the
/// submerged portion is genuinely hidden (cut away) instead of tinted.
class _TopRevealClipper extends CustomClipper<Rect> {
  final double visibleHeight;
  const _TopRevealClipper({required this.visibleHeight});

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, visibleHeight.clamp(0, size.height));

  @override
  bool shouldReclip(covariant _TopRevealClipper oldClipper) => oldClipper.visibleHeight != visibleHeight;
}