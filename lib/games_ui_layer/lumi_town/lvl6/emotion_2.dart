import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_3.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class Emotion2 extends StatefulWidget {
  const Emotion2({super.key});

  @override
  State<Emotion2> createState() => _Emotion2State();
}

class _Emotion2State extends State<Emotion2> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  Timer? _carouselAppearanceTimer;

  // Audio configuration
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _audioCompleteSubscription;

  // State to control when the images appear
  bool _showCarousel = false;

  // List of your 6 scenario images
  final List<String> _scenarioImages = [
    'assets/images/objects/lumi/e1_wrong.png',
    'assets/images/objects/lumi/e2_wrong.png',
    'assets/images/objects/lumi/e3_wrong.png',
    'assets/images/objects/lumi/e4_wrong.png',
    'assets/images/objects/lumi/e5_wrong.png',
    'assets/images/objects/lumi/e6_wrong.png',
  ];

  @override
  void initState() {
    super.initState();

    // Lock to landscape universally for this screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize our audio and timing sequence
    _initAudioAndSequence();
  }

  void _initAudioAndSequence() async {
    bool isTutorialPlaying = true;

    // 1. Listen for when the audio finishes
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((
      _,
    ) async {
      if (isTutorialPlaying) {
        // The first audio (tutorial) finished. Play the second one.
        isTutorialPlaying = false;
        await _audioPlayer.play(
          AssetSource('audio/lumi_town/level6/emotion_start.wav'),
        );
      } else {
        // The second audio (start) finished! Navigate to Emotion3!
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Emotion3Screen()),
          );
        }
      }
    });

    // 2. Start playing the tutorial audio immediately
    await _audioPlayer.play(
      AssetSource('audio/lumi_town/level6/emotion_tutorial.wav'),
    );

    // 3. Set a timer to show the carousel after 6 seconds
    _carouselAppearanceTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showCarousel = true;
        });

        // Give the widget tree a moment to build the now-visible carousel, then scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startAutoScroll();
        });
      }
    });
  }

  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients) {
        double currentPosition = _scrollController.position.pixels;
        _scrollController.jumpTo(currentPosition + 1.5);
      }
    });
  }

  @override
  void dispose() {
    // Always cancel timers and streams to prevent memory leaks
    _scrollTimer?.cancel();
    _carouselAppearanceTimer?.cancel();
    _audioCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _scrollController.dispose();

    // Reset orientations when leaving the screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;

          return Stack(
            children: [
              // 1. Universal Background
              Positioned.fill(
                child: Image.asset(
                  'assets/images/backgrounds/bg_lumi_park_night.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Dr. Woo (The Owl)
              Positioned(
                left: screenWidth * 0.15,
                bottom: -55,
                child: SizedBox(
                  width: screenWidth * 0.35,
                  child: Image.asset(
                    'assets/images/characters/dr.woo_the_owl.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // 3. The Automatic Upward Carousel - Delayed Appearance
              Positioned(
                right: screenWidth * 0.08,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: screenWidth * 0.25,
                  // AnimatedOpacity creates a smooth fade-in effect when _showCarousel turns true
                  child: AnimatedOpacity(
                    opacity: _showCarousel ? 1.0 : 0.0,
                    duration: const Duration(seconds: 1),
                    child: _buildCarousel(),
                  ),
                ),
              ),

              // 4. UI Layer: Exit Button
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
            ],
          );
        },
      ),
    );
  }

  // The Carousel Widget
  Widget _buildCarousel() {
    return ListView.builder(
      controller: _scrollController,
      // physics: const NeverScrollableScrollPhysics(), // Uncomment to prevent manual scrolling
      itemBuilder: (context, index) {
        final String imagePath =
            _scenarioImages[index % _scenarioImages.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: const Color(0xFFE8D5B5), width: 5.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15.0),
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}
