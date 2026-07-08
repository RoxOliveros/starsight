import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';

class Emotion2 extends StatefulWidget {
  const Emotion2({super.key});

  @override
  State<Emotion2> createState() => _Emotion2State();
}

class _Emotion2State extends State<Emotion2>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _opacityAnimation;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();

    // Initialize the audio player
    _audioPlayer = AudioPlayer();

    // Force the app into Landscape mode for this screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Total duration for the flickering and fading sequence
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );

    // TweenSequence for the 3 flickers and the final fade to a dim state
    _opacityAnimation = TweenSequence<double>([
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
      // Final fade out to a dim state (0.20 opacity)
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.20,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
    ]).animate(_fadeController);

    // Listen to the animation status to play audio when it finishes
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _playAudio();
      }
    });

    // Start the animation timeline
    _fadeController.forward();
  }

  Future<void> _playAudio() async {
    await _audioPlayer.play(
      AssetSource('audio/lumi_town/level6/emotion_intro.wav'),
    );
  }

  @override
  void dispose() {
    // Release the landscape lock when navigating away
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Dynamic constraints ensure universal fit across all device screens
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;

          // Responsive sizing for the stars based on screen real estate
          final double elementSize = (screenWidth * 0.18 < screenHeight * 0.28)
              ? screenWidth * 0.25
              : screenHeight * 0.35;

          return Stack(
            children: [
              // 1. Full-Screen Responsive Background
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_game_emotion.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Proportionally Placed and Tilted Stars
              _buildResponsiveStar(
                'assets/images/objects/lumi/scared.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.15,
                y: 0.65,
                tiltDegrees: -8,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/happy.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.25,
                y: 0.25,
                tiltDegrees: 8,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/disgust.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.42,
                y: 0.72,
                tiltDegrees: -8,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/sad.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.56,
                y: 0.36,
                tiltDegrees: -8,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/wow.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.75,
                y: 0.70,
                tiltDegrees: 12,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/angry.png',
                elementSize,
                screenWidth,
                screenHeight,
                x: 0.80,
                y: 0.30,
                tiltDegrees: -5,
              ),

              // 3. UI Layer (Top Left Exit Button)
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0, left: 24.0),
                    child: SizedBox(
                      width: 55,
                      height: 55,
                      child: Image.asset('assets/images/ui/x_yellow.png'),
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

  // Universal Helper for responsive positioning and sizing
  Widget _buildResponsiveStar(
    String imagePath,
    double size,
    double totalWidth,
    double totalHeight, {
    required double x,
    required double y,
    required double tiltDegrees,
  }) {
    // Calculates exact on-screen position using fractions of total width/height
    final double leftPosition = x * totalWidth - (size / 2);
    final double topPosition = y * totalHeight - (size / 2);
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
