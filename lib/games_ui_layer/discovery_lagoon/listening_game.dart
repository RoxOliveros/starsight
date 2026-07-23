import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

enum GamePhase { intro, listening, choosing, answered }

class ListeningGame extends StatefulWidget {
  const ListeningGame({super.key});

  @override
  State<ListeningGame> createState() => _ListeningGameState();
}

class _ListeningGameState extends State<ListeningGame> {
  late final AudioPlayer _audioPlayer;
  GamePhase _currentPhase = GamePhase.intro;

  @override
  void initState() {
    super.initState();
    // 1. FORCE LANDSCAPE ORIENTATION
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 2. ENABLE TRUE IMMERSIVE FULLSCREEN (Hides system status & navigation bars)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _audioPlayer = AudioPlayer();
    _playIntroAudio();
  }

  /// Plays the intro voiceover automatically when the screen loads.
  Future<void> _playIntroAudio() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/listening_intro.wav'),
      );

      // Listen for when the intro audio completes
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          _startListeningPhase();
        }
      });
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
    }
  }

  /// Shows speaker.gif and plays the target animal sound
  Future<void> _startListeningPhase() async {
    setState(() {
      _currentPhase = GamePhase.listening;
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/listening_chicken.wav'),
      );

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() {
            _currentPhase = GamePhase.choosing;
          });
        }
      });
    } catch (e) {
      debugPrint("Error playing chicken audio: $e");
    }
  }

  /// Helper method to play Kiki's feedback audio
  Future<void> _playKikiAudio(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing audio ($assetPath): $e");
    }
  }

  /// Handles when the user taps on an animal
  void _onAnimalTapped(String animalName) {
    if (_currentPhase != GamePhase.choosing) return;

    if (animalName == 'chicken') {
      setState(() {
        _currentPhase = GamePhase.answered;
      });

      // Play shine sound effect first, then play correct audio after it finishes
      _playKikiAudio('audio/sound_effects/shine.wav');
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          _playKikiAudio('audio/discovery_lagoon/listening_rc.wav');
        }
      });
    } else {
      // Play try again audio if the wrong animal is chosen
      _playKikiAudio('audio/discovery_lagoon/kiki_tryagain.wav');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // 3. RESTORE ORIENTATION & SYSTEM UI WHEN LEAVING THE GAME
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    // Only HEIGHT is set here — width is left to follow Kiki's natural
    // aspect ratio via BoxFit.contain, exactly like PerfumeGame does.
    // Tune this single number to make her bigger/smaller (0.85 = 85% of
    // screen height, matching PerfumeGame's catHeight).
    final double catHeight = sh * 1.0;
    final double catBottom = sh * -0.25;

    return Scaffold(
      // No SafeArea or AspectRatio wrappers, ensuring edge-to-edge fullscreen
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A. BACKGROUND LAYER (Expands to cover 100% of any device screen)
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_lagoon.png',
            fit: BoxFit.cover,
          ),

          // B. FOREGROUND CHARACTER LAYER (Kiki, sized by height only —
          // same pattern as PerfumeGame's cat character)
          // Kiki will now disappear during the listening AND choosing phases!
          if (_currentPhase == GamePhase.intro ||
              _currentPhase == GamePhase.answered)
            Positioned(
              bottom: catBottom,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/characters/kiki_the_cat.png',
                  height: catHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // C. SPEAKER GIF LAYER (Appears during listening phase, centered and big)
          if (_currentPhase == GamePhase.listening)
            Center(
              child: Image.asset(
                'assets/images/objects/lagoon/speaker.gif',
                height: sh * 0.60, // Made much bigger (60% of screen height)
                fit: BoxFit.contain,
              ),
            ),

          // D. ANIMAL CHOICES LAYER (Appears after speaker vanishes)
          if (_currentPhase == GamePhase.choosing ||
              _currentPhase == GamePhase.answered)
            Positioned(
              bottom: sh * 0.05,
              left: sw * 0.05,
              right: sw * 0.05,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAnimalChoice(
                    'assets/images/objects/lagoon/chicken.png',
                    'chicken',
                    sh,
                  ),
                  _buildAnimalChoice(
                    'assets/images/characters/doma_the_penguin2.png',
                    'penguin',
                    sh,
                  ),
                  _buildAnimalChoice(
                    'assets/images/characters/tofi_smiling.png',
                    'dog',
                    sh,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Helper widget to build interactive animal buttons with smooth bounce formatting
  Widget _buildAnimalChoice(
    String imagePath,
    String animalId,
    double screenHeight,
  ) {
    return GestureDetector(
      onTap: () => _onAnimalTapped(animalId),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            imagePath,
            height: screenHeight * 0.45,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
