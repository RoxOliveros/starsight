import 'dart:async';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_theme.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/bodyparts_drag.dart';

enum IntroPhase { entering, playingIntro, showingPart, listening, done }

class BodyPartsIntroScreen extends StatefulWidget {
  // Instead of a letter, we pass in the body part name (e.g., 'Head', 'Arm', 'Leg')
  final String bodyPart;

  const BodyPartsIntroScreen({super.key, required this.bodyPart});

  @override
  State<BodyPartsIntroScreen> createState() => _BodyPartsIntroScreenState();
}

class _BodyPartsIntroScreenState extends State<BodyPartsIntroScreen>
    with TickerProviderStateMixin {
  IntroPhase _introPhase = IntroPhase.entering;

  // --- ANIMATION CONTROLLERS ---
  late AnimationController _charSlideCtrl;
  late Animation<Offset> _charSlide;

  late AnimationController _partPopCtrl;
  late Animation<double> _partPop;

  late AnimationController _partDanceCtrl;
  late Animation<double> _partDance;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
  }

  void _initAnimations() {
    // 1. Character sliding in
    _charSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _charSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _charSlideCtrl, curve: Curves.elasticOut),
        );

    // 2. The Body Part GIF popping up
    _partPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _partPop = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _partPopCtrl, curve: Curves.easeOut));

    // 3. The Body Part GIF wiggling
    _partDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _partDance = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(parent: _partDanceCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _charSlideCtrl.dispose();
    _partPopCtrl.dispose();
    _partDanceCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  // --- THE MASTER DIRECTOR ---
  Future<void> _startIntroFlow() async {
    // 1. Slide character in
    await _charSlideCtrl.forward();

    // 2. Play intro audio (e.g., "This is an Arm!")
    if (mounted) setState(() => _introPhase = IntroPhase.playingIntro);
    await Future.delayed(const Duration(seconds: 2));

    // 3. Pop the custom GIF onto the screen and make it dance
    if (mounted) setState(() => _introPhase = IntroPhase.showingPart);
    _partPopCtrl.forward();
    _partDanceCtrl.repeat(reverse: true);

    // 4. Prompt the child to speak (e.g., "Can you say Arm?")
    await Future.delayed(const Duration(seconds: 2));

    // 5. Show the Microphone UI and "listen"
    if (mounted) setState(() => _introPhase = IntroPhase.listening);
    await Future.delayed(const Duration(seconds: 3));

    // 6. Success! Show the Next button
    if (mounted) setState(() => _introPhase = IntroPhase.done);
    _partDanceCtrl.stop();
  }

  Widget _buildAnimatedGif() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gifSize = (constraints.maxHeight * 0.45).clamp(100.0, 250.0);

        if (_introPhase == IntroPhase.entering ||
            _introPhase == IntroPhase.playingIntro) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_partPopCtrl, _partDanceCtrl]),
          builder: (_, child) => Transform.rotate(
            angle: _partDance.value,
            child: ScaleTransition(scale: _partPop, child: child),
          ),
          // LOOKS FOR YOUR LAGOON GIFS!
          // Make sure to create this folder in your project and update pubspec.yaml
          child: Image.asset(
            'assets/gifs/bodyparts/intro_${widget.bodyPart.toLowerCase()}.gif',
            width: gifSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(
              widget.bodyPart,
              style: const TextStyle(
                fontSize: 80,
                color: LagoonColorTheme.wasteland,
                fontWeight: FontWeight.bold,
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
      backgroundColor: LagoonColorTheme.peach, // Uses your Lagoon Theme!
      body: SafeArea(
        child: Stack(
          children: [
            // 1. LAGOON BACK BUTTON
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: LagoonBackButton(), // Uses your new reusable button!
              ),
            ),

            // 2. THE CHARACTER (Sliding in)
            Positioned(
              left: 40,
              bottom: 0,
              child: SlideTransition(
                position: _charSlide,
                child: Image.asset(
                  'assets/images/penguin.png',
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
                  SizedBox(
                    height: screenSize.height * 0.45,
                    child: _buildAnimatedGif(),
                  ),

                  const SizedBox(height: 20),

                  if (_introPhase == IntroPhase.listening) ...[
                    const Text(
                      "Say the word!",
                      style: TextStyle(
                        fontFamily: LagoonAppTextStyles.fredoka,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: LagoonColorTheme.darkbrown,
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

            // 4. "LET'S PLAY" BUTTON
            if (_introPhase == IntroPhase.done)
              Positioned(
                bottom: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    // Links to your Body Parts Drag Screen!
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BodyPartsDragScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: LagoonColorTheme.ferngreen, // Uses Lagoon Green!
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: LagoonColorTheme.gunmetalgreen,
                        width: 4,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Let's Play!",
                          style: TextStyle(
                            fontFamily: LagoonAppTextStyles.fredoka,
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
}
