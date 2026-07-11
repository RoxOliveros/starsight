import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl7/lumi_classroom_screen.dart';
import 'package:StarSight/ui_layer/lumi_town/town_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

// Make sure to import your GoodJobOverlay file here
// import 'goodjob_prompt.dart';

class EmotionEndingScreen extends StatefulWidget {
  const EmotionEndingScreen({super.key});

  @override
  State<EmotionEndingScreen> createState() => _EmotionEndingScreenState();
}

class _EmotionEndingScreenState extends State<EmotionEndingScreen>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;

  // Animation controller for the continuous flicker effect
  late AnimationController _flickerController;
  late Animation<double> _flickerAnimation;

  // State variables for interactivity
  bool _isAudioFinished = false;
  String? _selectedStarPath;
  bool _showGoodJobOverlay = false; // Added state for the overlay

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Set up the continuous flicker animation
    _flickerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _flickerAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _flickerController, curve: Curves.easeInOut),
    );

    _audioPlayer = AudioPlayer();
    _playEndingAudio();
  }

  Future<void> _playEndingAudio() async {
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isAudioFinished = true; // Unlock tapping
        });
      }
    });

    await _audioPlayer.play(
      AssetSource('audio/lumi_town/level6/emotion_ending.wav'),
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

    _flickerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;

          // Original base size calculation
          final double baseElementSize =
              (screenWidth * 0.18 < screenHeight * 0.28)
              ? screenWidth * 0.25
              : screenHeight * 0.35;

          return Stack(
            children: [
              // 1. Background Layer
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_game_emotion.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Animated Stars Layer
              _buildResponsiveStar(
                'assets/images/objects/lumi/scared.png',
                baseElementSize,
                screenWidth,
                screenHeight,
                x: 0.15,
                y: 0.65,
                tiltDegrees: -8,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/happy.png',
                baseElementSize,
                screenWidth,
                screenHeight,
                x: 0.25,
                y: 0.25,
                tiltDegrees: 8,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/disgust.png',
                baseElementSize,
                screenWidth,
                screenHeight,
                x: 0.42,
                y: 0.72,
                tiltDegrees: -8,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/sad.png',
                baseElementSize,
                screenWidth,
                screenHeight,
                x: 0.56,
                y: 0.36,
                tiltDegrees: -8,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/wow.png',
                baseElementSize,
                screenWidth,
                screenHeight,
                x: 0.75,
                y: 0.70,
                tiltDegrees: 12,
              ),
              _buildResponsiveStar(
                'assets/images/objects/lumi/angry.png',
                baseElementSize,
                screenWidth,
                screenHeight,
                x: 0.80,
                y: 0.30,
                tiltDegrees: -5,
              ),

              // 3. UI Element: Exit Button
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0, left: 24.0),
                    child: SizedBox(
                      width: 55,
                      height: 55,
                      child: Image.asset('assets/images/buttons/x_yellow.png'),
                    ),
                  ),
                ),
              ),

              // 4. Good Job Overlay (Renders on top of everything if activated)
              if (_showGoodJobOverlay && _selectedStarPath != null)
                Positioned.fill(
                  child: GoodJobOverlay(
                    // Pass the tapped emotion image to the overlay character!
                    characterImage: _selectedStarPath!,
                    closeButtonColor: Colors.orange,
                    onNext: () async {
                      await TownProgressService.instance.markLevelComplete(5);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const LumiClassroomScreen(),
                        ),
                      );
                    },
                    onRestart: () {
                      // Reset the selection so they can pick again
                      setState(() {
                        _selectedStarPath = null;
                        _showGoodJobOverlay = false;
                      });
                    },
                    onBack: () async {
                      await TownProgressService.instance.markLevelComplete(5);
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LumiLevelScreen(),
                          ),
                          (route) => route.isFirst,
                        );
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Interactive Helper Widget
  Widget _buildResponsiveStar(
    String imagePath,
    double baseSize,
    double totalWidth,
    double totalHeight, {
    required double x,
    required double y,
    required double tiltDegrees,
  }) {
    final bool isSelected = _selectedStarPath == imagePath;
    final double currentSize = isSelected ? baseSize * 2.2 : baseSize;

    final double leftPosition = isSelected
        ? (totalWidth / 2) - (currentSize / 2)
        : (x * totalWidth) - (currentSize / 2);

    final double topPosition = isSelected
        ? (totalHeight / 2) - (currentSize / 2)
        : (y * totalHeight) - (currentSize / 2);

    final double targetRotation = isSelected ? 0.0 : (tiltDegrees / 360.0);

    final double baseOpacity = (_selectedStarPath == null || isSelected)
        ? 1.0
        : 0.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.fastOutSlowIn,
      left: leftPosition,
      top: topPosition,
      width: currentSize,
      height: currentSize,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: baseOpacity,
        child: AnimatedBuilder(
          animation: _flickerAnimation,
          builder: (context, child) {
            final double currentFlickerOpacity = (_selectedStarPath != null)
                ? 1.0
                : _flickerAnimation.value;

            return Opacity(opacity: currentFlickerOpacity, child: child);
          },
          child: GestureDetector(
            onTap: () {
              // Lock tapping if audio isn't finished or overlay is already up
              if (_isAudioFinished && !_showGoodJobOverlay) {
                setState(() {
                  _selectedStarPath = isSelected ? null : imagePath;
                });

                // Trigger GoodJobOverlay after the star finishes zooming to the center
                if (!isSelected) {
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted && _selectedStarPath == imagePath) {
                      setState(() {
                        _showGoodJobOverlay = true;
                      });
                    }
                  });
                }
              }
            },
            child: AnimatedRotation(
              turns: targetRotation,
              duration: const Duration(milliseconds: 800),
              curve: Curves.fastOutSlowIn,
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
