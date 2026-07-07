import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart'; // Import the audio player

class EmotionStarsScreen extends StatefulWidget {
  const EmotionStarsScreen({super.key});

  @override
  State<EmotionStarsScreen> createState() => _EmotionStarsScreenState();
}

class _EmotionStarsScreenState extends State<EmotionStarsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _opacityAnimation;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();

    // Initialize the audio player
    _audioPlayer = AudioPlayer();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Set a total duration for the entire animation (3 flickers + final fade)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );

    // TweenSequence allows us to build a specific timeline of animations
    _opacityAnimation = TweenSequence<double>([
      // Flicker 1 (Weight 1 = 1 portion of the total time)
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.35,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),

      // Flicker 2
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.35,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),

      // Flicker 3
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.35,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),

      // Final fade out to a dim state to indicate the problem (stays at 0.2 opacity)
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.20,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
    ]).animate(_fadeController);

    // Listen to the animation status so we know exactly when it finishes
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _playAudio();
      }
    });

    // Start the animation timeline once
    _fadeController.forward();
  }

  Future<void> _playAudio() async {
    // Plays the audio indicating the stars are losing their light
    await _audioPlayer.play(
      AssetSource('audio/lumi_town/level6/emotion_intro.wav'),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _fadeController.dispose();
    _audioPlayer
        .dispose(); // Always dispose of the audio player to free up memory
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;

          // Your adjusted size multipliers[cite: 2]
          final double elementSize = (screenWidth * 0.18 < screenHeight * 0.28)
              ? screenWidth * 0.25
              : screenHeight * 0.35;

          return Stack(
            children: [
              // 1. Background Layer[cite: 2]
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_game_emotion.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Tilted Animated Stars Layer matched to the Canva sequence[cite: 2]
              // Scared (Purple) - Bottom Left[cite: 2]
              _buildResponsiveStar(
                'assets/images/objects/lumi/scared.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.15,
                y: 0.65,
                tiltDegrees: -8,
              ),

              // Happy (Yellow) - Top Mid-Left[cite: 2]
              _buildResponsiveStar(
                'assets/images/objects/lumi/happy.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.25,
                y: 0.25,
                tiltDegrees: 8,
              ),

              // Disgust (Green) - Bottom Center[cite: 2]
              _buildResponsiveStar(
                'assets/images/objects/lumi/disgust.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.42,
                y: 0.72,
                tiltDegrees: -8,
              ),

              // Sad (Blue) - Center Right[cite: 2]
              _buildResponsiveStar(
                'assets/images/objects/lumi/sad.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.56,
                y: 0.36,
                tiltDegrees: -8,
              ),

              // Wow (Orange) - Bottom Right[cite: 2]
              _buildResponsiveStar(
                'assets/images/objects/lumi/wow.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.75,
                y: 0.70,
                tiltDegrees: 12,
              ),

              // Angry (Red) - Top Right[cite: 2]
              _buildResponsiveStar(
                'assets/images/objects/lumi/angry.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.80,
                y: 0.30,
                tiltDegrees: -5,
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0, left: 24.0),
                    child: SizedBox(
                      width:
                          55, // Adjust this to make the button bigger/smaller
                      height: 55,
                      child: Image.asset('assets/images/buttons/x_yellow.png'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper widget to handle positioning, scaling, and the sequenced fading/tilting[cite: 2]
  Widget _buildResponsiveStar(
    String imagePath,
    double size,
    double totalWidth,
    double totalHeight, {
    required double x,
    required double y,
    required double tiltDegrees,
  }) {
    final double leftPosition = x * totalWidth - (size / 2);
    final double topPosition = y * totalHeight - (size / 2);

    // Flutter's Transform.rotate requires radians, so we convert the degrees[cite: 2]
    final double tiltRadians = tiltDegrees * math.pi / 180;

    return Positioned(
      left: leftPosition,
      top: topPosition,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Transform.rotate(
          angle: tiltRadians,
          child: SizedBox(
            width: size,
            height: size,
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
