import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'number345_odd_one_out.dart';

enum _ScreenPhase { intro, miniGame }

class Number345CountingObjectsScreen extends StatefulWidget {
  final int level;

  const Number345CountingObjectsScreen({super.key, required this.level});

  @override
  State<Number345CountingObjectsScreen> createState() =>
      _Number345CountingObjectsScreenState();
}

class _Number345CountingObjectsScreenState extends State<Number345CountingObjectsScreen>
    with TickerProviderStateMixin, DomaReactionMixin {
  @override
  AudioPlayer get domaPlayer => _player;

  // ── Constants ──────────────────────────────────────────────────────────────
  static const int _totalRounds = 5;
  static const List<int> _numbers = [3, 4, 5];

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _characterImage =
      'assets/images/characters/doma_the_penguin.png';

  static const String _audioIntro =
      'assets/audio/arctic_numberland/level14/intro.wav';

  // ── Objects pool (all arctic_numberland assets) ──────────────────────────────────────
  static const List<Map<String, String>> _objects = [
    {
      'name': 'Candy Cane',
      'asset': 'assets/images/objects/arctic/candy_cane.png',
    },
    {'name': 'Earmuffs', 'asset': 'assets/images/objects/arctic/earmuffs.png'},
    {'name': 'Ice', 'asset': 'assets/images/objects/arctic/ice_1.png'},
    {
      'name': 'Ice Skates',
      'asset': 'assets/images/objects/arctic/ice_skates.png',
    },
    {'name': 'Ice Cream', 'asset': 'assets/images/objects/arctic/icecream.png'},
    {'name': 'Igloo', 'asset': 'assets/images/objects/arctic/igloo.png'},
    {'name': 'Sled', 'asset': 'assets/images/objects/arctic/sled.png'},
    {'name': 'Snowball', 'asset': 'assets/images/objects/arctic/snowball.png'},
    {
      'name': 'Snow Globe',
      'asset': 'assets/images/objects/arctic/snowglobe.png',
    },
    {'name': 'Snowman', 'asset': 'assets/images/objects/arctic/snowman.png'},
    {
      'name': 'Snowy Sign',
      'asset': 'assets/images/objects/arctic/snowy_signboard.png',
    },
    {
      'name': 'Snowy Tree',
      'asset': 'assets/images/objects/arctic/snowy_tree.png',
    },
    {
      'name': 'Winter Hat',
      'asset': 'assets/images/objects/arctic/winter_hat.png',
    },
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  bool _showWinDialog = false;

  int _round = 1;
  late int _correctCount;
  late List<int> _choices;
  late String _currentObjectAsset;
  int? _tappedIndex;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  late AnimationController _domaFloatCtrl;

  late AnimationController _objectsEnterCtrl;
  late Animation<double> _objectsEnter;

  late AnimationController _choicesEnterCtrl;
  late Animation<double> _choicesEnter;

  late AnimationController _correctPulseCtrl;
  late Animation<double> _correctPulse;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _generateRound();
    _startIntroFlow();
  }

  void _initAnimations() {
    // Intro: numbers dance
    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    // Doma floating
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Objects display box entrance
    _objectsEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _objectsEnter = CurvedAnimation(
      parent: _objectsEnterCtrl,
      curve: Curves.elasticOut,
    );

    // Choices entrance
    _choicesEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _choicesEnter = CurvedAnimation(
      parent: _choicesEnterCtrl,
      curve: Curves.easeOutBack,
    );

    // Correct answer pulse
    _correctPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _correctPulse =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _correctPulseCtrl, curve: Curves.easeOut),
        );
  }

  // ── Round Logic ─────────────────────────────────────────────────────────────
  void _generateRound() {
    final rng = Random();

    _correctCount = _numbers[rng.nextInt(_numbers.length)];

    final others = _numbers.where((n) => n != _correctCount).toList()
      ..shuffle(rng);
    final wrongChoices = [...others];

    _choices = [...wrongChoices.take(2), _correctCount]..shuffle(rng);

    // Pick a random object
    final obj = List.from(_objects)..shuffle(rng);
    _currentObjectAsset = (obj.first as Map<String, String>)['asset']!;

    _tappedIndex = null;
  }

  // ── Flow ───────────────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _playAudio(_audioIntro);
    if (!mounted) return;
    setState(() => _screenPhase = _ScreenPhase.miniGame);
    _animateRoundIn();
  }

  void _animateRoundIn() {
    _objectsEnterCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _choicesEnterCtrl.forward(from: 0);
    });
  }

  Future<void> _onChoiceTap(int index) async {
    if (_tappedIndex != null) return;
    setState(() => _tappedIndex = index);

    final isCorrect = _choices[index] == _correctCount;

    if (isCorrect) {
      _correctPulseCtrl.forward(from: 0);
      await _playAudio('assets/audio/arctic_numberland/$_correctCount.wav');
      showDomaReaction(DomaState.correct);

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      if (_round >= _totalRounds) {
        await ArcticProgressService.instance.markLevelComplete(12);
        setState(() => _showWinDialog = true);
      } else {
        setState(() {
          _round++;
          _generateRound();
        });
        _animateRoundIn();
      }
    } else {
      await _playAudio('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _tappedIndex = null);
    }
  }

  // ── Audio ──────────────────────────────────────────────────────────────────
  Future<void> _playAudio(String asset) async {
    try {
      final completer = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future;
      await sub.cancel();
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _numberDanceCtrl.dispose();
    _domaFloatCtrl.dispose();
    _objectsEnterCtrl.dispose();
    _choicesEnterCtrl.dispose();
    _correctPulseCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Choice Colors ──────────────────────────────────────────────────────────
  Color _choiceColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.pictonblue;
    if (_choices[index] == _correctCount) return Colors.green;
    if (_tappedIndex == index) return Colors.red;
    return ArcticColorTheme.pictonblue;
  }

  Color _choiceBorderColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.slateblue;
    if (_choices[index] == _correctCount) return ArcticColorTheme.pictonblue;
    if (_tappedIndex == index) return Colors.red.shade700;
    return ArcticColorTheme.slateblue;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),

          if (_screenPhase == _ScreenPhase.intro)
            _buildIntroLayer()
          else
            SafeArea(child: _buildGameContent()),

          if (_screenPhase == _ScreenPhase.miniGame) buildDoma(context),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Intro ──────────────────────────────────────────────────────────────────
  Widget _buildIntroLayer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Stack(
          children: [
            Positioned(top: 8, left: 12, child: ArcticBackButton()),
            Positioned(top: 8, right: 12, child: ArcticLevelBadge(level: widget.level)),
            Positioned.fill(
              top: 40,
              child: Row(
                children: [
                  // Doma
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        _characterImage,
                        height: MediaQuery.of(context).size.height * 0.65,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Text('🐧', style: TextStyle(fontSize: 60)),
                      ),
                    ),
                  ),
                  // Dancing numbers 3, 4, 5
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
      ),
    );
  }

  Widget _buildIntroNumberCard(int i) {
    final number = _numbers[i]; // 3, 4, 5
    final size = MediaQuery.of(context).size.height * 0.28;
    const words = ['THREE', 'FOUR', 'FIVE'];
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
        const SizedBox(height: 6),
        Text(
          words[i],
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
            shadows: const [
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

  // ── Game Content ───────────────────────────────────────────────────────────
  Widget _buildGameContent() {
    return Column(
      children: [
        const SizedBox(height: 12),

        // ── HEADER ──────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: ArcticBackButton()
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ArcticLevelBadge(level: widget.level),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
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
                  'How many are there?',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── MAIN ROW ────────────────────────────
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 6,
                child: ScaleTransition(
                  scale: _objectsEnter,
                  child: _buildObjectsBox(),
                ),
              ),
              Expanded(
                flex: 3,
                child: ScaleTransition(
                  scale: _choicesEnter,
                  child: _buildChoicesGrid(),
                ),
              ),
            ],
          ),
        ),

        // ── PROGRESS DOTS ───────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildProgressDots(),
        ),
      ],
    );
  }

  Widget _buildObjectsBox() {
    return Container(
      height: double.infinity,
      margin: const EdgeInsets.only(bottom: 16, left: 12),
      decoration: BoxDecoration(
        color: ArcticColorTheme.cotton,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ArcticColorTheme.pictonblue, width: 4),
        boxShadow: [
          BoxShadow(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildObjectGrid(),
      ),
    );
  }

  Widget _buildObjectGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final objSize = (constraints.maxHeight * 0.50).clamp(50.0, 105.0);
        return Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_correctCount, (i) {
            return Image.asset(
              _currentObjectAsset,
              width: objSize,
              height: objSize,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text('❄️', style: TextStyle(fontSize: 48)),
            );
          }),
        );
      },
    );
  }

  Widget _buildChoicesGrid() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.4, // ← changed from 1.3
        ),
        itemCount: _choices.length,
        itemBuilder: (context, index) {
          final isCorrect = _choices[index] == _correctCount;
          final isTappedCorrect = _tappedIndex == index && isCorrect;

          return GestureDetector(
            onTap: () => _onChoiceTap(index),
            child: ScaleTransition(
              scale: isTappedCorrect
                  ? _correctPulse
                  : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: _choiceColor(index),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _choiceBorderColor(index),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _choiceColor(index).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/fonts/game_numbers/${_choices[index]}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        '${_choices[index]}',
                        style: const TextStyle(
                          fontFamily: ArcticAppTextStyles.fredoka,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: ArcticColorTheme.cotton,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : current
                ? ArcticColorTheme.slateblue
                : ArcticColorTheme.slateblue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: _characterImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pop(context, Number345OddOneOutScreen(level: widget.level));
      },
      onRestart: () {
        Navigator.pop(context, Number345CountingObjectsScreen(level: widget.level));
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}
