import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class Sorry2Screen extends StatefulWidget {
  const Sorry2Screen({super.key});

  @override
  State<Sorry2Screen> createState() => _Sorry2ScreenState();
}

class _Sorry2ScreenState extends State<Sorry2Screen>
    with TickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;

  // --- Animation Variables (based on respect_5.dart reference) ---
  late final AnimationController _walkController;
  final Duration _walkDuration = const Duration(milliseconds: 1800);
  final Duration _stepDuration = const Duration(milliseconds: 260);
  final double _bounceHeightFraction = 0.045;

  // Track whether the bear has finished walking to swap the image
  bool _isBearSadWithTears = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Setup the walking animation controller
    _walkController = AnimationController(vsync: this, duration: _walkDuration);

    // Lock to landscape orientation
    _setupLandscapeOrientation();

    // Start the sequential audio and animation sequence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSceneSequence();
    });
  }

  void _setupLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Handles the timing: narration -> bear walking -> sorry audio & crying image
  Future<void> _startSceneSequence() async {
    try {
      // 1. Play the owl's narration audio
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_narration_2.wav'),
      );

      // Wait until the first narration completely finishes playing
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // 2. Start the bear's walking animation
      await _walkController.forward(from: 0);
      if (!mounted) return;

      // 3. When walking stops, change the bear image to show tears
      setState(() {
        _isBearSadWithTears = true;
      });

      // 4. Play the bear's sorry audio
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_1.wav'),
      );
    } catch (e) {
      debugPrint('Error playing sequence: $e');
    }
  }

  @override
  void dispose() {
    // Reset orientations when exiting
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _walkController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final baseCharacterHeight = MediaQuery.of(context).size.height * 1.18;

    // Scale the bear proportionally to the base character height
    final bearHeight = baseCharacterHeight * 0.70;

    // Animation Math for the Bear walking from the right (exact match to respect_5.dart)
    final double startX = sw; // Start off-screen right
    final int stepCount =
        (_walkDuration.inMilliseconds / _stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);
    final double bounceHeightPx = bearHeight * _bounceHeightFraction;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Layer
          Image.asset(
            'assets/images/backgrounds/bg_lumi_classroom.png',
            fit: BoxFit.cover,
          ),

          // 2. Dr. Woo Layer (Left Side - Standing with no visible feet)
          // Pushing the bottom to -(baseCharacterHeight * 0.15) clips the feet off screen
          Positioned(
            left: sw * 0.10,
            bottom: -(baseCharacterHeight * 0.15),
            child: SizedBox(
              height: baseCharacterHeight * 0.80,
              child: Image.asset(
                'assets/images/characters/dr.woo_the_owl.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 3. Animated Bear Layer
          AnimatedBuilder(
            animation: _walkController,
            builder: (context, child) {
              final double t = _walkController.value;
              final double easedT = Curves.easeOutCubic.transform(t);

              // Horizontal movement calculation
              final double dx = startX * (1 - easedT);

              // Vertical bouncing calculation while moving
              final double bounce = t < 1.0
                  ? (math.sin(t * stepCount * math.pi)).abs() * bounceHeightPx
                  : 0.0;

              return Positioned(
                right: (sw * 0.10) - dx, // Slides into view from the right
                bottom: -(baseCharacterHeight * 0.15) + bounce,
                child: SizedBox(
                  height: bearHeight,
                  child: Image.asset(
                    _isBearSadWithTears
                        ? 'assets/images/characters/littlebear_sad_tears.png'
                        : 'assets/images/characters/bear_sad.png',
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
