import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class Emotion2 extends StatefulWidget {
  const Emotion2({super.key});

  @override
  State<Emotion2> createState() => _Emotion2State();
}

class _Emotion2State extends State<Emotion2> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

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

    // Give the widget tree a moment to build, then start scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    // This timer ticks every 30 milliseconds, pushing the list up by 1.5 pixels
    // Adjust the duration or the pixel amount to make it faster or slower!
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients) {
        double currentPosition = _scrollController.position.pixels;
        _scrollController.jumpTo(currentPosition + 1.5);
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel(); // Always cancel timers to prevent memory leaks
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
          // Grabbing the dynamic screen width and height to ensure universal fit
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

              // 2. Dr. Woo (The Owl) - Scaled based on device width
              Positioned(
                left:
                    screenWidth *
                    0.15, // Stays 15% from the left edge on all devices
                bottom: -55, // Tucked slightly off the bottom edge
                child: SizedBox(
                  width:
                      screenWidth *
                      0.35, // Always takes up 40% of the screen width
                  child: Image.asset(
                    'assets/images/characters/dr.woo_the_owl.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // 3. The Automatic Upward Carousel - Scaled based on device width
              Positioned(
                right: screenWidth * 0.08, // Stays 8% from the right edge
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width:
                      screenWidth *
                      0.25, // Always takes up 25% of the screen width
                  child: _buildCarousel(),
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
        // The modulo operator (%) creates an infinite loop through the 6 images
        final String imagePath =
            _scenarioImages[index % _scenarioImages.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: const Color(0xFFE8D5B5), // Creamy border color
                width: 5.0,
              ),
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
