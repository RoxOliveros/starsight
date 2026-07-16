import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class Sorry6Screen extends StatefulWidget {
  const Sorry6Screen({super.key});

  @override
  State<Sorry6Screen> createState() => _Sorry6ScreenState();
}

class _Sorry6ScreenState extends State<Sorry6Screen> {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupLandscapeOrientation();

    // Trigger sorry_7.wav right after the scene loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playSceneAudio();
    });
  }

  void _setupLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Plays sorry_7.wav while the characters stand together in the classroom
  Future<void> _playSceneAudio() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_7.wav'),
      );

      // Wait for sorry_7.wav to finish playing
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // TODO: Add your next screen transition here once sorry_7 finishes!
      debugPrint('sorry_7.wav finished playing!');
    } catch (e) {
      debugPrint('Error playing audio for sorry_6 screen: $e');
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
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final baseCharacterHeight = MediaQuery.of(context).size.height * 1.18;

    // Both characters scale proportionally to the classroom
    final characterHeight = baseCharacterHeight * 0.70;

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

          // 2. Left Character: Little Bear (Standing statically on the left)
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

          // 3. Right Character: Jack holding the Car (Standing statically on the right)
          Positioned(
            right:
                sw *
                0.12, // Placed directly on the right side without animation offsets
            bottom: -(baseCharacterHeight * 0.15),
            child: SizedBox(
              height: characterHeight,
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

                  // Layer B: The Toy Car (Held near his front paw)
                  Positioned(
                    bottom: characterHeight * 0.12,
                    left: characterHeight * 0.08,
                    child: Image.asset(
                      'assets/images/objects/lumi/car.png',
                      width: characterHeight * 0.35,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
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
