import 'package:StarSight/games_ui_layer/lumi_town/dr.woo_reaction.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_ending.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class Emotion8Screen extends StatefulWidget {
  const Emotion8Screen({super.key});

  @override
  State<Emotion8Screen> createState() => _Emotion8ScreenState();
}

class _Emotion8ScreenState extends State<Emotion8Screen>
    with DrWooReactionMixin {
  // Player for Dr. Woo's SFX (Required by Mixin)
  late final AudioPlayer _audioPlayer;

  // NEW: Dedicated player for the Filipino narration
  late final AudioPlayer _narratorPlayer;

  // Tracks if the correct star was dropped
  bool _isCorrectlyAnswered = false;
  // Controls the fade-in/fade-out of the sparkle overlay
  bool _showSparkles = false;

  // NEW: Controls the visibility of the draggable stars
  bool _showStars = false;

  bool _isSuccessAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    _audioPlayer = AudioPlayer();
    _narratorPlayer = AudioPlayer();

    // Start the intro sequence
    _playIntroAudio();
  }

  /// Plays the initial story audio and shows stars when finished
  Future<void> _playIntroAudio() async {
    // UPDATED: The listener now handles both the intro finishing AND the success finishing
    _narratorPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        if (_isSuccessAudioPlaying) {
          // If the success audio just finished, go to the next screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const EmotionEndingScreen(), // Next Screen!
            ),
          );
        } else {
          // If the intro audio just finished, show the stars
          setState(() {
            _showStars = true;
          });
        }
      }
    });

    // Play the audio (AssetSource automatically looks inside the 'assets/' folder)
    // IMPORTANT: Update this path if you placed the audio in a different folder!
    await _narratorPlayer.play(
      AssetSource('audio/lumi_town/level6/emotion_p6.wav'),
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
    _audioPlayer.dispose();
    _narratorPlayer
        .dispose(); // Always clean up the new player to prevent memory leaks
    super.dispose();
  }

  @override
  Widget buildDrWoo(BuildContext context) {
    return Positioned(
      left: -40,
      bottom: 0,
      child: FractionalTranslation(
        translation: const Offset(0, 0.02),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.70,
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
  AudioPlayer get drWooPlayer => _audioPlayer;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    final double centerImageWidth = screenWidth * 0.60;
    final double centerImageHeight = screenHeight * 0.75;
    final double closeButtonSize = screenHeight * 0.12;
    final double starButtonSize = screenHeight * 0.28;
    final double paddingEdge = screenWidth * 0.04;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgrounds/bg_game_emotion.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // 1. Center Image as a DragTarget (The Drop Zone)
              Center(
                child: Container(
                  width: centerImageWidth,
                  height: centerImageHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE5D5BA),
                      width: screenHeight * 0.015,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    // DragTarget listens for Draggable widgets carrying a DrWooState
                    child: DragTarget<DrWooState>(
                      onAcceptWithDetails: (details) async {
                        final droppedState = details.data;

                        // 1. Always trigger Dr. Woo's reaction on drop immediately
                        showDrWooReaction(droppedState);

                        // 2. If it is the correct answer, run the sequence
                        if (droppedState == DrWooState.correct &&
                            !_isCorrectlyAnswered) {
                          // Lock the answer so it can't be triggered twice
                          _isCorrectlyAnswered = true;

                          _isSuccessAudioPlaying = true;

                          // Optional: Wait half a second so Dr. Woo's "ding" SFX
                          // finishes before the narrator starts talking
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );

                          // Safely stop the player just in case it was hanging
                          await _narratorPlayer.stop();

                          // Play the narrative success sound
                          await _narratorPlayer.play(
                            AssetSource(
                              'audio/lumi_town/level6/emotion_p6_rc.wav',
                            ),
                          );

                          // Show sparkles
                          setState(() => _showSparkles = true);

                          // Wait for 1 second while sparkles are covering the image
                          await Future.delayed(const Duration(seconds: 1));

                          if (mounted) {
                            // Swap the base image and hide sparkles
                            setState(() {
                              _showSparkles = false;
                            });
                          }
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Stack(
                          alignment: Alignment.center,
                          fit: StackFit.expand,
                          children: [
                            // Base Scenario Image
                            Image.asset(
                              _isCorrectlyAnswered
                                  ? 'assets/images/objects/lumi/e6_right.png'
                                  : 'assets/images/objects/lumi/e6_wrong.png',
                              fit: BoxFit.cover,
                            ),

                            // Sparkle Overlay with a smooth fade animation
                            AnimatedOpacity(
                              opacity: _showSparkles ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 400),
                              child: Container(
                                color: Colors.white.withOpacity(0.4),
                                child: Image.asset(
                                  'assets/images/objects/lumi/sparkle.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 2. Top Left Close Button
              Positioned(
                top: paddingEdge,
                left: paddingEdge,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Image.asset(
                    'assets/images/buttons/x_yellow.png',
                    width: closeButtonSize,
                    height: closeButtonSize,
                  ),
                ),
              ),

              // 3. Right Side Star Draggables (Now animated to fade in!)
              Positioned(
                right: paddingEdge,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  // Prevent users from clicking invisible stars before they fade in
                  ignoring: !_showStars,
                  child: AnimatedOpacity(
                    opacity: _showStars ? 1.0 : 0.0,
                    duration: const Duration(
                      milliseconds: 800,
                    ), // Smooth 0.8s fade
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildReactionDraggable(
                          'assets/images/objects/lumi/wow_wb.png',
                          DrWooState.correct,
                          starButtonSize,
                        ),
                        SizedBox(height: screenHeight * 0.03),
                        _buildReactionDraggable(
                          'assets/images/objects/lumi/disgust_wb.png',
                          DrWooState.wrong,
                          starButtonSize,
                        ),
                        SizedBox(height: screenHeight * 0.03),
                        _buildReactionDraggable(
                          'assets/images/objects/lumi/sad_wb.png',
                          DrWooState.wrong,
                          starButtonSize,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Dr. Woo Owl Character
              buildDrWoo(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper widget to build the draggable star buttons
  Widget _buildReactionDraggable(
    String assetPath,
    DrWooState stateToTrigger,
    double size,
  ) {
    return Draggable<DrWooState>(
      data: stateToTrigger,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(assetPath, width: size, height: size),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Image.asset(assetPath, width: size, height: size),
      ),
      child: Image.asset(assetPath, width: size, height: size),
    );
  }
}
