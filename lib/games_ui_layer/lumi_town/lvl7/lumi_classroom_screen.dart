import 'package:StarSight/games_ui_layer/lumi_town/dr.woo_reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class LumiClassroomScreen extends StatefulWidget {
  const LumiClassroomScreen({Key? key}) : super(key: key);

  @override
  State<LumiClassroomScreen> createState() => _LumiClassroomScreenState();
}

class _LumiClassroomScreenState extends State<LumiClassroomScreen>
    with DrWooReactionMixin {
  late final AudioPlayer _audioPlayer;

  // NEW: State variable to control button visibility
  bool _showButtons = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Lock to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playIntroAudio();
    });
  }

  @override
  void dispose() {
    // Reset orientations
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
  AudioPlayer get drWooPlayer => _audioPlayer;

  // ---------------------------------------------------------------------------
  // Custom visual-only reaction to prevent interrupting tutorial audio
  // ---------------------------------------------------------------------------
  Future<void> showDrWooReactionQuietly(DrWooState state) async {
    if (!mounted) return;
    setState(() => drWooState = state);

    // Wait 2 seconds, then revert to normal without playing any mixin audio
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => drWooState = DrWooState.normal);
  }

  Future<void> _playIntroAudio() async {
    try {
      // 1. Play the intro audio first
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level7/respect_intro.wav'),
      );

      // Tell Flutter to wait right here until the intro finishes playing
      await _audioPlayer.onPlayerComplete.first;

      // Make sure the user hasn't closed the screen while we were waiting
      if (!mounted) return;

      // 2. Now play the tutorial audio
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level7/respect_tutorial.wav'),
      );

      // 3. Wait 6 seconds into the tutorial, then trigger Dr. Woo and show the buttons
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() {
            _showButtons = true;
          });
          showDrWooReactionQuietly(DrWooState.correct);
        }
      });
    } catch (e) {
      debugPrint('Error playing audio sequence: $e');
    }
  }

  @override
  Widget buildDrWoo(BuildContext context) {
    // 1.18 is based on your previous code size adjustment
    final owlHeight = MediaQuery.of(context).size.height * 1.18;

    return Positioned(
      left: 0,
      right: 0, // Stretching across the width
      bottom: -(owlHeight * 0.15),
      child: Align(
        alignment: Alignment.bottomCenter, // Centering the owl
        child: SizedBox(
          height: owlHeight,
          child: switch (drWooState) {
            DrWooState.correct => Image.asset(
              'assets/animations/characters/dr.woo_thumbsup.webp',
              fit: BoxFit.contain,
            ),
            DrWooState.wrong => Image.asset(
              'assets/images/characters/dr.woo_tryagain.png',
              fit: BoxFit.contain,
            ),
            DrWooState.normal => Image.asset(
              'assets/images/characters/dr.woo_standing.png',
              fit: BoxFit.contain,
            ),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/images/backgrounds/bg_lumi_classroom.png',
            fit: BoxFit.cover,
          ),

          // Dr. Woo Layer
          buildDrWoo(context),

          // NEW: Only render the buttons if _showButtons is true
          if (_showButtons) ...[
            // Thumbs Up Button (Now on the Left Side)
            Positioned(
              left: 40,
              bottom: 40,
              child: GestureDetector(
                onTap: () {
                  showDrWooReactionQuietly(DrWooState.correct);
                },
                child: Image.asset(
                  'assets/images/objects/lumi/thumbs_up.png',
                  width: 100,
                  height: 100,
                ),
              ),
            ),

            // Thumbs Down Button (Now on the Right Side)
            Positioned(
              right: 40,
              bottom: 40,
              child: GestureDetector(
                onTap: () {
                  showDrWooReactionQuietly(DrWooState.wrong);
                },
                child: Image.asset(
                  'assets/images/objects/lumi/thumbs_down.png',
                  width: 100,
                  height: 100,
                ),
              ),
            ),
          ],

          // Close Button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Image.asset(
                    'assets/images/buttons/x_blue.png',
                    width: 50,
                    height: 50,
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
