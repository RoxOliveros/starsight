import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class Sorry1Screen extends StatefulWidget {
  const Sorry1Screen({super.key});

  @override
  State<Sorry1Screen> createState() => _Sorry1ScreenState();
}

class _Sorry1ScreenState extends State<Sorry1Screen> {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _setupLandscapeOrientation();
    _initAndPlayAudio();
  }

  /// Locks the device to landscape mode for an immersive story scene
  void _setupLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Initializes the audio engine and triggers the narration
  Future<void> _initAndPlayAudio() async {
    _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_narration_1.wav'),
      );

      // Wait for audio to finish
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // Navigate to Scene 2
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Sorry2Screen()),
      );
    } catch (e) {
      debugPrint('Error playing narration audio: $e');
    }
  }

  @override
  void dispose() {
    // Free up system memory and stop audio when leaving the screen
    _audioPlayer.dispose();

    // Optional: Reset orientation back to standard if exiting to a portrait screen
    // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/objects/lumi/lvl9_scene1.png',
          // BoxFit.cover ensures the image fills the entire screen on any device
          // while maintaining its aspect ratio without stretching
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Text(
                'Scene asset could not be loaded.',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          },
        ),
      ),
    );
  }
}
