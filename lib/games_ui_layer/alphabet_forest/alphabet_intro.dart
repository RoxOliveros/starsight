import 'dart:async';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_puzzle.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:StarSight/business_layer/orientation_service.dart';

enum ScreenPhase { intro, tracing }

enum IntroPhase { entering, playingIntro, showingLetter, listening, done }

class AlphabetIntroScreen extends StatefulWidget {
  final String startingLetter;

  const AlphabetIntroScreen({super.key, required this.startingLetter});

  @override
  State<AlphabetIntroScreen> createState() => _AlphabetIntroScreenState();
}

class _AlphabetIntroScreenState extends State<AlphabetIntroScreen>
    with TickerProviderStateMixin {
  ScreenPhase _screenPhase = ScreenPhase.intro;
  IntroPhase _introPhase = IntroPhase.entering;

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
    _startIntroFlow(); // Start the magic!
  }

  void _initAnimations() {
    // 1. Character sliding in from the bottom
    _charSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _charSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _charSlideCtrl, curve: Curves.elasticOut),
        );

    // 2. The GIF popping up
    _letterPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _letterPop = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _letterPopCtrl, curve: Curves.easeOut));

    // 3. The GIF wiggling
    _letterDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _letterDance = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _letterDanceCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _charSlideCtrl.dispose();
    _letterPopCtrl.dispose();
    _letterDanceCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // --- THE MASTER DIRECTOR ---
  Future<void> _startIntroFlow() async {
    await _charSlideCtrl.forward();

    // Play the intro audio (e.g., "A is for Apple!")
    if (mounted) setState(() => _introPhase = IntroPhase.playingIntro);

    // TODO (FUTURE): await _audioPlayer.play(AssetSource('audio/intro_a.wav'));
    // For now, we just fake the wait time:
    await Future.delayed(const Duration(seconds: 2));

    // 3. Pop the custom GIF onto the screen and make it dance
    if (mounted) setState(() => _introPhase = IntroPhase.showingLetter);
    _letterPopCtrl.forward();
    _letterDanceCtrl.repeat(reverse: true);

    // 4. Prompt the child to speak (e.g., "Can you say A?")
    // TODO (FUTURE): await _audioPlayer.play(AssetSource('audio/say_a.wav'));
    await Future.delayed(const Duration(seconds: 2));

    // 5. Show the Microphone UI and "listen"
    if (mounted) setState(() => _introPhase = IntroPhase.listening);

    // TODO (FUTURE): Start actual speech recognition here!
    // For now, we simulate listening for 3 seconds before succeeding
    await Future.delayed(const Duration(seconds: 3));

    // 6. Success! Show the Next button
    if (mounted) setState(() => _introPhase = IntroPhase.done);
    _letterDanceCtrl.stop(); // Stop the wiggle when they finish
  }

  Widget _buildAnimatedGif() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gifSize = (constraints.maxHeight * 0.45).clamp(100.0, 250.0);

        // Hide it if we are still sliding the character in
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
            'assets/gifs/letters/intro_${widget.startingLetter.toLowerCase()}.gif',
            width: 500,
            height: 500,
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
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: ForestColorTheme.lightgrayishgreen,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. BACK BUTTON
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: ForestBackButton(),
              ),
            ),

            // 2. THE CHARACTER (Sliding in)
            Positioned(
              left: 40,
              bottom: 0,
              child: SlideTransition(
                position: _charSlide,
                child: Image.asset(
                  'assets/images/characters/dog.png',
                  height: screenSize.height * 0.5,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 3. THE CENTER CONTENT (GIF & MIC)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The Animated Custom GIF
                  SizedBox(
                    height: screenSize.height * 0.45,
                    child: _buildAnimatedGif(),
                  ),

                  const SizedBox(height: 20),

                  // Unfinished Voice recognition
                  if (_introPhase == IntroPhase.listening) ...[
                    const Text(
                      "Say the letter!",
                      style: TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ForestColorTheme.darkseagreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (_introPhase == IntroPhase.done)
              Positioned(
                bottom: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlphabetPuzzleScreen(
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
                          "Let's Play!",
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
} // End of State class
