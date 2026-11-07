import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'dart:math';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_minigame_pop.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_minigame_puzzle.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_minigame_hunt.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_minigame_fall.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_minigame_find.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../ui_layer/loading_screen.dart';
import '../games_audio_helper.dart';
import 'alphabet_game_ui.dart';
import 'forest_flow.dart';

enum IntroPhase { entering, playingIntro, showingLetter, done }

class AlphabetIntroScreen extends StatefulWidget {
  final List<String> letters;

  const AlphabetIntroScreen({super.key, required this.letters});

  @override
  State<AlphabetIntroScreen> createState() => _AlphabetIntroScreenState();
}

class _AlphabetIntroScreenState extends State<AlphabetIntroScreen>
    with
        TickerProviderStateMixin,
        TofiReactionMixin,
        AppAudioLifecycleMixin<AlphabetIntroScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _tofiPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _tofiPlayer];

  @override
  AudioPlayer get tofiPlayer => _tofiPlayer;

  late AnimationController _floatCtrl;
  late Animation<double> _float;
  IntroPhase _introPhase = IntroPhase.entering;

  bool _isLoadingAssets = true;
  final DateTime _loadStart = DateTime.now();

  // --- ANIMATION CONTROLLERS ---
  late AnimationController _charSlideCtrl;

  late AnimationController _letterPopCtrl;
  late Animation<double> _letterPop;

  late AnimationController _letterDanceCtrl;
  late Animation<double> _letterDance;

  static final Random _random = Random();
  static List<int> _miniGameQueue = [];
  static int _miniGameIndex = 0;

  int _nextMiniGame() {
    if (_miniGameQueue.isEmpty || _miniGameIndex >= _miniGameQueue.length) {
      _miniGameQueue = List.generate(5, (i) => i)..shuffle(_random);
      _miniGameIndex = 0;
    }
    return _miniGameQueue[_miniGameIndex++];
  }

  int _letterIndex = 0;

  bool _tofiIntro = false;

  String get _currentLetter => widget.letters[_letterIndex];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();

    final letter = widget.letters.first.toUpperCase();
    const introLoadingLetters = {'A', 'D', 'G', 'J', 'M', 'P', 'S', 'V', 'Y'};

    if (introLoadingLetters.contains(letter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prepareAssets();
      });
    } else {
      _isLoadingAssets = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startIntroFlow();
      });
    }
  }

  Future<void> _prepareAssets() async {
    final elapsed = DateTime.now().difference(_loadStart);
    // Loading time
    final remaining = const Duration(milliseconds: 1500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;

    setState(() => _isLoadingAssets = false);
    _startIntroFlow(); // start the magic only once everything's ready
  }

  void _initAnimations() {
    _charSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _letterPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _letterPop = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _letterPopCtrl, curve: Curves.easeOut));

    _letterDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _letterDance = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _letterDanceCtrl, curve: Curves.easeInOut),
    );
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _float = Tween<double>(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _floatCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _charSlideCtrl.dispose();
    _letterPopCtrl.dispose();
    _letterDanceCtrl.dispose();
    _audioPlayer.dispose();
    _tofiPlayer.dispose();
    _floatCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _startIntroFlow() async {
    if (ForestFlow.levelOf(widget.letters) == 1) { 
      await _playTofiIntro(); 
      if (!mounted) return; 
    } 
    await _charSlideCtrl.forward();
    if (!mounted) return;

    for (var i = 0; i < widget.letters.length; i++) {
      if (!mounted) return;
      setState(() {
        _letterIndex = i;
        _introPhase = IntroPhase.playingIntro;
      });
      _letterPopCtrl.reset();
      _letterDanceCtrl.stop();

      await _playLetterIntro();
    }

    if (!mounted) return;
    setState(() => _introPhase = IntroPhase.done);
  }

  Future<void> _playTofiIntro() async {
    setState(() => _tofiIntro = true);

    final done = Completer<void>();
    final sub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });

    await playAssetAudio(
      _audioPlayer,
      'assets/audio/alphabet_forest/forest_tofi_intro.wav',
    );
    await done.future;
    await sub.cancel();
    if (!mounted) return;

    setState(() => _tofiIntro = false);
  }

  Future<void> _playLetterIntro() async {
    final audioFinished = Completer<void>();
    final sub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!audioFinished.isCompleted) audioFinished.complete();
    });

    final audioFile =
        'assets/audio/alphabet_forest/intro_${_currentLetter.toLowerCase()}.wav';
    await playAssetAudio(_audioPlayer, audioFile);

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _introPhase = IntroPhase.showingLetter);
    _letterPopCtrl.forward();
    _letterDanceCtrl.repeat(reverse: true);

    await audioFinished.future;
    await sub.cancel();
    if (!mounted) return;

    await showTofiReaction(TofiState.correct);
  }

  Widget _buildAnimatedGif() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_introPhase == IntroPhase.entering ||
            _introPhase == IntroPhase.playingIntro) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_letterPopCtrl, _letterDanceCtrl]),
          builder: (_, child) => Transform.rotate(
            angle: _letterDance.value,
            child: ScaleTransition(scale: _letterPop, child: child),
          ),
          child: Image.asset(
            'assets/fonts/game_letters/intro_${_currentLetter.toLowerCase()}.png',
            height: MediaQuery.of(context).size.height * 0.50,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(
              _currentLetter,
              style: const TextStyle(
                fontSize: 100,
                color: ForestColorTheme.seagreen,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAssets) {
      return Scaffold(body: LoadingScreen.alphabetForest());
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_forest.png',
              fit: BoxFit.cover,
            ),
          ),

          const Positioned(top: 25, left: 25, child: ForestXButton()),

          Positioned(
            top: 25,
            right: 20,
            child: ForestLevelBadge(level: ForestFlow.levelOf(widget.letters)),
          ),

          if (!_tofiIntro) buildTofi(context),

          if (_tofiIntro)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.17,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _float,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _float.value),
                  child: child,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/characters/tofi_standing.png',
                    height: MediaQuery.of(context).size.height * 1.1,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 50),

                if (_introPhase != IntroPhase.entering &&
                    _introPhase != IntroPhase.playingIntro)
                  AnimatedBuilder(
                    animation: _float,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _float.value),
                      child: child,
                    ),
                    child: Image.asset(
                      _getObjectImage(_currentLetter),
                      height: MediaQuery.of(context).size.height * 0.40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                const SizedBox(width: 16),

                _buildAnimatedGif(),
              ],
            ),
          ),

          if (_introPhase == IntroPhase.done)
            Positioned(
              bottom: 25,
              right: 25,
              child: ForestNextButton(
                onTap: () {
                  _audioPlayer.stop();
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 400),
                      pageBuilder: (_, __, ___) => _buildMinigame(),
                      transitionsBuilder: (_, animation, __, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMinigame() {
    final builders = <Widget Function()>[
      () => AlphabetPopScreen(letters: widget.letters),
      () => AlphabetPuzzleScreen(letters: widget.letters),
      () => AlphabetHuntScreen(letters: widget.letters),
      () => AlphabetFallScreen(letters: widget.letters),
      () => AlphabetFindScreen(letters: widget.letters),
    ];

    return builders[_nextMiniGame()]();
  }

  String _getObjectImage(String letter) {
    const Map<String, String> objectMap = {
      'A': 'apple',
      'B': 'ball',
      'C': 'car',
      'D': 'duck',
      'E': 'egg',
      'F': 'feet',
      'G': 'glass',
      'H': 'hat',
      'I': 'igloo',
      'J': 'jar',
      'K': 'key',
      'L': 'lamp',
      'M': 'milk',
      'N': 'nose',
      'O': 'oil',
      'P': 'pan',
      'Q': 'queen',
      'R': 'rain',
      'S': 'sun',
      'T': 'tree',
      'U': 'umbrella',
      'V': 'vase',
      'W': 'window',
      'X': 'xylophone',
      'Y': 'yarn',
      'Z': 'zero',
    };
    final name = objectMap[letter.toUpperCase()] ?? letter.toLowerCase();
    return 'assets/images/objects/forest/$name.png';
  }
}
