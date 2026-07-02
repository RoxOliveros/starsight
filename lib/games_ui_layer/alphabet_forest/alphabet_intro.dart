import 'dart:async';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_trace.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../ui_layer/loading_screen.dart';

enum ScreenPhase { intro, tracing }

enum IntroPhase { entering, playingIntro, showingLetter, done }

class AlphabetIntroScreen extends StatefulWidget {
  final String startingLetter;

  const AlphabetIntroScreen({super.key, required this.startingLetter});

  @override
  State<AlphabetIntroScreen> createState() => _AlphabetIntroScreenState();
}

class _AlphabetIntroScreenState extends State<AlphabetIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _float;
  IntroPhase _introPhase = IntroPhase.entering;

  bool _isLoadingAssets = true;
  final DateTime _loadStart = DateTime.now();

  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- ANIMATION CONTROLLERS ---
  late AnimationController _charSlideCtrl;
  late Animation<Offset> _charSlide;

  late AnimationController _letterPopCtrl;
  late Animation<double> _letterPop;

  late AnimationController _letterDanceCtrl;
  late Animation<double> _letterDance;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareAssets());
  }

  Future<void> _prepareAssets() async {
    await Future.wait([
      precacheImage(
        const AssetImage('assets/images/characters/dog.png'),
        context,
      ),
      precacheImage(
        AssetImage(
          'assets/fonts/game_letters/intro_${widget.startingLetter.toLowerCase()}.png',
        ),
        context,
      ),
      precacheImage(
        AssetImage(_getObjectImage(widget.startingLetter)),
        context,
      ),
    ]);

    final elapsed = DateTime.now().difference(_loadStart);
    final remaining = const Duration(seconds: 2) - elapsed;
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
    _charSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _charSlideCtrl, curve: Curves.elasticOut),
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
    _floatCtrl.dispose();

    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _startIntroFlow() async {
    await _charSlideCtrl.forward();
    if (!mounted) return;
    setState(() => _introPhase = IntroPhase.playingIntro);

    Completer<void> audioFinished = Completer<void>();
    final sub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!audioFinished.isCompleted) audioFinished.complete();
    });

    String audioFile =
        'audio/alphabet_forest/intro_${widget.startingLetter.toLowerCase()}.wav';
    await _audioPlayer.play(AssetSource(audioFile));

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _introPhase = IntroPhase.showingLetter);
    _letterPopCtrl.forward();
    _letterDanceCtrl.repeat(reverse: true);

    await audioFinished.future;
    await sub.cancel();
    if (!mounted) return;

    setState(() => _introPhase = IntroPhase.done);
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
            'assets/fonts/game_letters/intro_${widget.startingLetter.toLowerCase()}.png',
            width: 1000,
            height: 1000,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(
              widget.startingLetter,
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
      return Scaffold(
        body: LoadingScreen.alphabetForest(),
      );
    }

    final Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      body: ForestBackground(
        child: Stack(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: ForestBackButton(),
              ),
            ),

            Positioned(
              left: 40,
              bottom: 0,
              child: SlideTransition(
                position: _charSlide,
                child: Image.asset(
                  'assets/images/characters/dog.png',
                  height: screenSize.height * 0.4,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT: Floating object
                  if (_introPhase != IntroPhase.entering &&
                      _introPhase != IntroPhase.playingIntro)
                    AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, _float.value),
                        child: child,
                      ),
                      child: Image.asset(
                        _getObjectImage(widget.startingLetter),
                        height: 150,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),

                  const SizedBox(width: 16),

                  // RIGHT: GIF (bigger)
                  SizedBox(
                    height: screenSize.height * 0.80,
                    width: screenSize.width * 0.50,
                    child: _buildAnimatedGif(),
                  ),
                ],
              ),
            ),

            if (_introPhase == IntroPhase.done)
              Positioned(
                bottom: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    _audioPlayer.stop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlphabetTraceScreen(
                          startingLetter: widget.startingLetter,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ForestColorTheme.seagreen,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Next!",
                          style: TextStyle(
                            fontFamily: ForestAppTextStyles.fredoka,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
    };
    final name = objectMap[letter.toUpperCase()] ?? letter.toLowerCase();
    return 'assets/images/objects/forest/$name.png';
  }
}
