import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class Sorry4Screen extends StatefulWidget {
  const Sorry4Screen({super.key});

  @override
  State<Sorry4Screen> createState() => _Sorry4ScreenState();
}

class _Sorry4ScreenState extends State<Sorry4Screen>
    with TickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;

  // --- Animation Variables (Exact math from previous screens) ---
  late final AnimationController _walkController;
  final Duration _walkDuration = const Duration(milliseconds: 1800);
  final Duration _stepDuration = const Duration(milliseconds: 260);
  final double _bounceHeightFraction = 0.045;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _walkController = AnimationController(vsync: this, duration: _walkDuration);

    _setupLandscapeOrientation();

    // Start walking animation and play audio after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _walkController.forward(from: 0);
      _playSceneAudio();
    });
  }

  void _setupLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _playSceneAudio() async {
    try {
      // Tweak this asset path to whatever narration audio belongs to this scene!
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_narration_3.wav'),
      );
    } catch (e) {
      debugPrint('Error playing audio for sorry_4: $e');
    }
  }

  @override
  void dispose() {
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

    // Both characters scale proportionally to the classroom
    final characterHeight = baseCharacterHeight * 0.70;

    // Animation math for Jack walking from the right
    final double startX = sw; // Starts off-screen right
    final int stepCount =
        (_walkDuration.inMilliseconds / _stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);
    final double bounceHeightPx = characterHeight * _bounceHeightFraction;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Layer
          Image.asset(
            'assets/images/backgrounds/bg_lumi_classroom.png',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => const Center(
              child: Text(
                'Background could not be loaded.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),

          // 2. Left Character Layer: Little Bear (Waiting on the left)
          Positioned(
            left: sw * 0.12,
            bottom: -(baseCharacterHeight * 0.15),
            child: SizedBox(
              height: characterHeight,
              child: Image.asset(
                'assets/images/characters/littlebear_sad_tears.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 3. Right Animated Layer: Jack holding the Car walking in
          AnimatedBuilder(
            animation: _walkController,
            builder: (context, child) {
              final double t = _walkController.value;
              final double easedT = Curves.easeOutCubic.transform(t);

              // Horizontal sliding calculation
              final double dx = startX * (1 - easedT);

              // Vertical bouncing calculation
              final double bounce = t < 1.0
                  ? (math.sin(t * stepCount * math.pi)).abs() * bounceHeightPx
                  : 0.0;

              return Positioned(
                right: (sw * 0.12) - dx, // Slides into position on the right
                bottom: -(baseCharacterHeight * 0.12) + bounce,
                child: SizedBox(
                  height: characterHeight,
                  // We use a width roughly equivalent to his aspect ratio
                  // so we can properly align the toy car over his body
                  width: characterHeight * 0.85,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Layer A: Jack the Fox
                      Image.asset(
                        'assets/images/characters/jack_sad.png',
                        height: characterHeight,
                        fit: BoxFit.contain,
                      ),

                      // Layer B: The Toy Car (Positioned over his arm/paw)
                      Positioned(
                        bottom: characterHeight * 0.12, // Height near his paw
                        left:
                            characterHeight *
                            0.08, // Shifted toward his front arm
                        child: Image.asset(
                          'assets/images/objects/lumi/car.png',
                          // Car is scaled to be about 35% of Jack's height
                          width: characterHeight * 0.35,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 4. Close Button (Top Left)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Image.asset(
                    'assets/images/buttons/x_blue.png',
                    width: 50,
                    height: 50,
                    errorBuilder: (ctx, err, st) => Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF266589),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
