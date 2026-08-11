import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'arctic_game_ui.dart';
import 'goodjob_doma_prompt.dart';
import 'minigame_ice_path.dart';
import 'minigame_number_tap.dart';
import 'minigame_snowflakes.dart';
import 'number_tracing_widget.dart';

// ═════════════════════════════════════════════════════════════════════════
// CONFIG
// ═════════════════════════════════════════════════════════════════════════

/// Data every mini-game needs to know what "correct" looks like for this
/// number — pop, sort, match, drag, whatever you build later all read from
/// the same struct instead of getting a hand-wired constructor call.
class NumberObjectSet {
  final String correctObjectAsset;
  final String correctObjectEmoji;
  final List<String> decoyObjectAssets;
  final String decoyObjectEmoji;
  final int targetCount;
  final int decoyCount;
  final String instructionText;
  final String instructionAudio;

  const NumberObjectSet({
    required this.correctObjectAsset,
    required this.correctObjectEmoji,
    required this.decoyObjectAssets,
    required this.decoyObjectEmoji,
    required this.targetCount,
    this.decoyCount = 0,
    required this.instructionText,
    this.instructionAudio = '',
  });
}

/// The shape every number mini-game widget builder must match.
typedef NumberMiniGameBuilder =
Widget Function({
required int number,
required String numberWord,
required NumberObjectSet objects,
required AudioPlayer player,
required VoidCallback onComplete,
required int level,
});

/// Cycles through mini-games in shuffled order, no repeats until the set
/// is exhausted — same trick AlphabetTraceScreen uses with _miniGameQueue.
class _MiniGameRotator {
  final int count;
  final Random _random = Random();
  List<int> _queue = [];
  int _index = 0;

  _MiniGameRotator(this.count);

  int next() {
    if (count == 0) return -1;
    if (_queue.isEmpty || _index >= _queue.length) {
      _queue = List.generate(count, (i) => i)..shuffle(_random);
      _index = 0;
    }
    return _queue[_index++];
  }
}

final List<NumberMiniGameBuilder> kNumberMiniGames = [
      ({required number, required numberWord, required objects, required player, required onComplete, required level}) =>
      TapObjectMiniGame(
        instructionText: objects.instructionText,
        instructionAudio: objects.instructionAudio,
        correctObjectAsset: objects.correctObjectAsset,
        correctObjectEmoji: objects.correctObjectEmoji,
        decoyObjectAssets: objects.decoyObjectAssets,
        decoyObjectEmoji: objects.decoyObjectEmoji,
        targetCount: objects.targetCount,
        decoyCount: objects.decoyCount,
        player: player,
        onComplete: onComplete,
        level: level
      ),

      ({required number, required numberWord, required objects, required player, required onComplete, required level}) =>
      PenguinSnowflakesMiniGame(
        number: number,
        player: player,
        onComplete: onComplete,
        instructionAudio: objects.instructionAudio,
        level: level
      ),

      ({required number, required numberWord, required objects, required player, required onComplete, required level}) =>
      IceNumberPathGame(
        minNumber: 1,
        maxNumber: number,
        player: player,
        onComplete: onComplete,
        instructionAudio: objects.instructionAudio,
        level: level,
      ),
];

class NumberLevelConfig {
  final int number;
  final String numberWord;
  final int levelId;

  final String introAudio;
  final String numberRevealAudio;
  final String writeAudio;
  final String correctTapAudio; // level-completion voice line, kept here

  /// null = skip the mini-game entirely after tracing (e.g. zero).
  final NumberObjectSet? objects;

  const NumberLevelConfig({
    required this.number,
    required this.numberWord,
    required this.levelId,
    required this.introAudio,
    required this.numberRevealAudio,
    required this.writeAudio,
    required this.correctTapAudio,
    this.objects,
  });
}

final Map<int, NumberLevelConfig> kNumberLevels = {
  0: const NumberLevelConfig(
    number: 0,
    numberWord: 'ZERO',
    levelId: 1,
    introAudio: 'assets/audio/arctic_numberland/zero_intro.wav',
    numberRevealAudio: 'assets/audio/arctic_numberland/zero_know.wav',
    writeAudio: 'assets/audio/arctic_numberland/zero_write.wav',
    correctTapAudio: 'assets/audio/arctic_numberland/0.wav',
  ),
  1: NumberLevelConfig(
    number: 1,
    numberWord: 'ONE',
    levelId: 2,
    introAudio: 'assets/audio/arctic_numberland/one_intro.wav',
    numberRevealAudio: 'assets/audio/arctic_numberland/one_know.wav',
    writeAudio: 'assets/audio/arctic_numberland/one_write.wav',
    correctTapAudio: 'assets/audio/arctic_numberland/1.wav',
    objects: const NumberObjectSet(
      instructionText: 'Tap ONE Snowman!',
      instructionAudio: 'assets/audio/arctic_numberland/one_click_snowman.wav',
      correctObjectAsset: 'assets/images/objects/arctic/snowman.png',
      correctObjectEmoji: '⛄',
      decoyObjectAssets: ['assets/images/objects/arctic/icecream.png'],
      decoyObjectEmoji: '🍦',
      targetCount: 1,
    ),
  ),
  2: NumberLevelConfig(
    number: 2,
    numberWord: 'TWO',
    levelId: 3,
    introAudio: 'assets/audio/arctic_numberland/two_intro.wav',
    numberRevealAudio: 'assets/audio/arctic_numberland/two_know.wav',
    writeAudio: 'assets/audio/arctic_numberland/two_write.wav',
    correctTapAudio: 'assets/audio/arctic_numberland/2.wav',
    objects: const NumberObjectSet(
      instructionText: 'Tap TWO Ice Cream!',
      instructionAudio: 'assets/audio/arctic_numberland/two_click_icecream.wav',
      correctObjectAsset: 'assets/images/objects/arctic/icecream.png',
      correctObjectEmoji: '🍦',
      decoyObjectAssets: ['assets/images/objects/arctic/snowman.png'],
      decoyObjectEmoji: '⛄',
      targetCount: 2,
      decoyCount: 2,
    ),
  ),
  3: NumberLevelConfig(
    number: 3,
    numberWord: 'THREE',
    levelId: 4,
    introAudio: 'assets/audio/arctic_numberland/three_intro.wav',
    numberRevealAudio: 'assets/audio/arctic_numberland/three_know.wav',
    writeAudio: 'assets/audio/arctic_numberland/three_write.wav',
    correctTapAudio: 'assets/audio/arctic_numberland/3.wav',
    objects: const NumberObjectSet(
      instructionText: 'Tap THREE Trees!',
      instructionAudio: '',
      correctObjectAsset: 'assets/images/objects/arctic/snowy_tree.png',
      correctObjectEmoji: '🌲',
      decoyObjectAssets: ['assets/images/objects/arctic/sled.png'],
      decoyObjectEmoji: '🛷',
      targetCount: 3,
      decoyCount: 3,
    ),
  ),
  4: NumberLevelConfig(
    number: 4,
    numberWord: 'FOUR',
    levelId: 5,
    introAudio: 'assets/audio/arctic_numberland/four_intro.wav',
    numberRevealAudio: 'assets/audio/arctic_numberland/four_know.wav',
    writeAudio: 'assets/audio/arctic_numberland/four_write.wav',
    correctTapAudio: 'assets/audio/arctic_numberland/4.wav',
    objects: const NumberObjectSet(
      instructionText: 'Tap FOUR Snowballs!',
      instructionAudio: '',
      correctObjectAsset: 'assets/images/objects/arctic/snowball.png',
      correctObjectEmoji: '⚪️',
      decoyObjectAssets: ['assets/images/objects/arctic/ice_1.png'],
      decoyObjectEmoji: '🧊',
      targetCount: 4,
      decoyCount: 4,
    ),
  ),
  5: NumberLevelConfig(
    number: 5,
    numberWord: 'FIVE',
    levelId: 6,
    introAudio: 'assets/audio/arctic_numberland/five_intro.wav',
    numberRevealAudio: 'assets/audio/arctic_numberland/five_know.wav',
    writeAudio: 'assets/audio/arctic_numberland/five_write.wav',
    correctTapAudio: 'assets/audio/arctic_numberland/5.wav',
    objects: const NumberObjectSet(
      instructionText: 'Tap FIVE Hats!',
      instructionAudio: '',
      correctObjectAsset: 'assets/images/objects/arctic/winter_hat.png',
      correctObjectEmoji: '⚪️',
      decoyObjectAssets: ['assets/images/objects/arctic/candy_cane.png'],
      decoyObjectEmoji: '🍬',
      targetCount: 5,
      decoyCount: 5,
    ),
  ),
};

// ═════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════

enum _ScreenPhase { intro, miniGame }

enum _IntroPhase {
  domaEntering,
  playingIntro,
  playingReveal,
  listening,
  celebrating,
}

enum _MiniGamePhase { tracing, tapping }

class NumberIntroductionScreen extends StatefulWidget {
  final List<NumberLevelConfig> configs;
  final Widget? nextScreen;
  final int level;

  const NumberIntroductionScreen({super.key, required this.configs, required this.level, this.nextScreen});

  factory NumberIntroductionScreen.forNumber(int number, {required int level}) {
    final config = kNumberLevels[number];
    assert(config != null, 'No NumberLevelConfig registered for $number');
    return NumberIntroductionScreen(configs: [config!], level: level);
  }

  factory NumberIntroductionScreen.forSequence(List<int> numbers, {required int level, Widget? nextScreen}) {
    final configs = numbers.map((n) {
      final c = kNumberLevels[n];
      assert(c != null, 'No NumberLevelConfig registered for $n');
      return c!;
    }).toList();
    return NumberIntroductionScreen(configs: configs, nextScreen: nextScreen, level: level);
  }

  @override
  State<NumberIntroductionScreen> createState() =>
      _NumberIntroductionScreenState();
}

class _NumberIntroductionScreenState extends State<NumberIntroductionScreen>
    with TickerProviderStateMixin {
  int _configIndex = 0;
  NumberLevelConfig get _config => widget.configs[_configIndex];
  bool get _isLastInSequence => _configIndex == widget.configs.length - 1;

  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  _IntroPhase _introPhase = _IntroPhase.domaEntering;
  _MiniGamePhase _miniGamePhase = _MiniGamePhase.tracing;

  final AudioPlayer _player = AudioPlayer();

  // Rotates through kNumberMiniGames so consecutive numbers don't repeat
  // the same mini-game, same pattern as AlphabetTraceScreen's queue.
  static final _miniGameRotator = _MiniGameRotator(kNumberMiniGames.length);

  // Tap mini-game state
  bool _showWinDialog = false;
  bool _isCompletingLevel = false;

  late AnimationController _domaFloatCtrl;
  late AnimationController _domaSlideCtrl;
  late Animation<Offset> _domaSlide;
  late Animation<double> _domaFade;
  late AnimationController _celebrateCtrl;
  late Animation<double> _celebrateScale;
  late AnimationController _numberPopCtrl;
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;
  late Animation<double> _numberPop;
  late AnimationController _mgTransitionCtrl;
  late Animation<double> _mgFade;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
  }

  void _initAnimations() {
    _domaFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _domaSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _domaSlide = Tween<Offset>(begin: const Offset(0, 1.6), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _domaSlideCtrl, curve: Curves.elasticOut),
    );
    _domaFade = CurvedAnimation(
      parent: _domaSlideCtrl,
      curve: const Interval(0, 0.4),
    );

    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebrateScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.08), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _celebrateCtrl, curve: Curves.easeOut));

    _numberPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _numberPop = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _numberPopCtrl, curve: Curves.easeOut));

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    _mgTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _mgFade = CurvedAnimation(parent: _mgTransitionCtrl, curve: Curves.easeIn);
  }

  // ── Intro flow ────────────────────────────────────────────────────────
  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _domaSlideCtrl.forward(from: 0);

    _setIntroPhase(_IntroPhase.playingIntro);
    await _playAudio(_config.introAudio);
    if (!mounted) return;

    _setIntroPhase(_IntroPhase.playingReveal);
    _numberPopCtrl.forward(from: 0);
    _numberDanceCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await _playAudio(_config.numberRevealAudio);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _setIntroPhase(_IntroPhase.listening);
    _numberDanceCtrl.stop();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _goToTracing();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _playAudio(_config.writeAudio);
  }

  Future<void> _completeLevel() async {
    if (_isCompletingLevel) return;
    _isCompletingLevel = true;

    await Future.delayed(const Duration(milliseconds: 200));

    if (_isLastInSequence) {
      await ArcticProgressService.instance.markLevelComplete(_config.levelId);
      if (!mounted) return;
      setState(() => _showWinDialog = true);
    } else {
      _advanceToNextInSequence();
    }
  }

  void _advanceToNextInSequence() {
    setState(() {
      _configIndex++;
      _screenPhase = _ScreenPhase.intro;
      _introPhase = _IntroPhase.domaEntering;
      _miniGamePhase = _MiniGamePhase.tracing;
      _isCompletingLevel = false;
    });
    _startIntroFlow();
  }

  Future<void> _playAudio(String asset) async {
    if (!mounted) return;
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
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _setIntroPhase(_IntroPhase p) {
    if (!mounted) return;
    setState(() => _introPhase = p);
  }

  Future<void> _goToTracing() async {
    if (!mounted) return;
    setState(() => _screenPhase = _ScreenPhase.miniGame);
    _mgTransitionCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _player.dispose();
    for (final c in [
      _domaFloatCtrl,
      _domaSlideCtrl,
      _celebrateCtrl,
      _numberPopCtrl,
      _mgTransitionCtrl,
      _numberDanceCtrl,
    ]) {
      c.dispose();
    }
    OrientationService.setLandscape();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_arctic.png',
              fit: BoxFit.cover,
            ),
          ),
          if (_screenPhase == _ScreenPhase.intro)
            Column(
              children: [
                // ── HEADER ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Align(alignment: Alignment.centerLeft, child: ArcticBackButton()),
                      Align(alignment: Alignment.centerRight, child: ArcticLevelBadge(level: widget.level)),
                      Center(child: _buildInstructionBanner()),
                    ],
                  ),
                ),
                // ── CONTENT ──────────────────────────────
                Expanded(child: _buildIntroContent()),
              ],
            ),
          if (_screenPhase == _ScreenPhase.miniGame)
            Positioned.fill(
              child: FadeTransition(opacity: _mgFade, child: _buildMiniGame()),
            ),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Instruction Banner ────────────────────────────────────────────────
  Widget _buildInstructionBanner() {
    String text;
    if (_screenPhase == _ScreenPhase.intro) {
      return const SizedBox.shrink(); // Doma is talking; no banner needed yet
    } else if (_miniGamePhase == _MiniGamePhase.tracing) {
      text = 'Trace the number!';
    } else {
      text = _config.objects?.instructionText ?? 'Let\'s play!';
    }

    return Container(
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
        text,
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
        ),
      ),
    );
  }

  // ── Intro content ─────────────────────────────────────────────────────
  Widget _buildIntroContent() {
    return Positioned.fill(
      top: 50,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.38,
                child: _buildIntroDoma(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildIntroNumber(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroDoma() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final domaH = h * 1.1;
        final floatY = Tween<double>(begin: -8, end: 8).evaluate(
          CurvedAnimation(parent: _domaFloatCtrl, curve: Curves.easeInOut),
        );

        return ClipRect(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SlideTransition(
              position: _domaSlide,
              child: FadeTransition(
                opacity: _domaFade,
                child: AnimatedBuilder(
                  animation: _domaFloatCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      0,
                      _introPhase == _IntroPhase.celebrating ? 0 : floatY,
                    ),
                    child: child,
                  ),
                  child: ScaleTransition(
                    scale: _introPhase == _IntroPhase.celebrating
                        ? _celebrateScale
                        : const AlwaysStoppedAnimation(1.0),
                    child: Image.asset(
                      'assets/images/characters/doma_the_penguin.png',
                      height: domaH,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Text('🐧', style: TextStyle(fontSize: domaH * 0.7)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroNumber() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final cardSize = (h * 0.5).clamp(100.0, 160.0);
        final revealed =
            _introPhase != _IntroPhase.domaEntering &&
                _introPhase != _IntroPhase.playingIntro;

        return Align(
          alignment: Alignment.center,
          child: revealed
              ? AnimatedBuilder(
            animation: _numberDanceCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _numberDance.value,
              child: ScaleTransition(scale: _numberPop, child: child),
            ),
            child: _NumberCard(
              number: _config.number,
              word: _config.numberWord,
              size: cardSize,
            ),
          )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  // ── Mini game ─────────────────────────────────────────────────────────
  Widget _buildMiniGame() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              if (_miniGamePhase == _MiniGamePhase.tracing)
                NumberTracingWidget(
                  number: _config.number,
                  player: _player,
                  onComplete: () {
                    if (_config.objects != null) {
                      setState(() => _miniGamePhase = _MiniGamePhase.tapping);
                    } else {
                      _completeLevel(); // ← this fires for 0, since objects is null
                    }
                  },
                  level: widget.level,
                )
              else ...[
                Positioned(
                  left: w * 0.08,
                  top: h * 0.5 - (h * 0.30) / 2,
                  child: _NumberCard(
                    number: _config.number,
                    word: _config.numberWord,
                    size: h * 0.3,
                  ),
                ),
                kNumberMiniGames[_miniGameRotator.next()](
                  number: _config.number,
                  numberWord: _config.numberWord,
                  objects: _config.objects!,
                  player: _player,
                  onComplete: _completeLevel,
                  level: widget.level,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Win dialog ────────────────────────────────────────────────────────
  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        if (widget.nextScreen != null) {
          Navigator.pop(context, widget.nextScreen);
        } else {
          Navigator.pop(context);
        }
      },
      onRestart: () {
        Navigator.pop(
          context,
          NumberIntroductionScreen(configs: widget.configs, nextScreen: widget.nextScreen, level: widget.level),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Number Card
// ─────────────────────────────────────────────────────────────────────────
class _NumberCard extends StatelessWidget {
  final int number;
  final String word;
  final double size;

  const _NumberCard({
    required this.number,
    required this.word,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/fonts/game_numbers/$number.png',
            width: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              '$number',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: size * 0.75,
                fontWeight: FontWeight.bold,
                color: ArcticColorTheme.pictonblue,
              ),
            ),
          ),
          SizedBox(height: size * 0.05),
          Text(
            word,
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: size * 0.26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}