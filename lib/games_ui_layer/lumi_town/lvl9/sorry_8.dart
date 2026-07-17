import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
// adjust import path to match your project structure

class Sorry8Screen extends StatefulWidget {
  const Sorry8Screen({super.key});

  @override
  State<Sorry8Screen> createState() => _Sorry8ScreenState();
}

class _Sorry8ScreenState extends State<Sorry8Screen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- Animation Controllers ---
  late final AnimationController _walkController; // Jack walking to Little Bear
  late final AnimationController _carSlideController; // Car handoff slide
  late final AnimationController _jumpController; // Celebration jump

  // --- Scene State ---
  bool _isCarWithJack = true;
  bool _showGoodJob = false;

  @override
  void initState() {
    super.initState();
    _setupLandscapeOrientation();

    // Jack's walk over to Little Bear
    _walkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Car sliding from Jack's hand to Little Bear's hand
    _carSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Two quick celebration bounces
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Start the story sequence as soon as the screen renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playStorySequence();
    });
  }

  void _setupLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// 1. Plays audio -> 2. Jack walks over -> 3. Hands over the car ->
  /// 4. Both characters jump!
  Future<void> _playStorySequence() async {
    try {
      debugPrint('[Sorry8] Starting story sequence...');

      // 1. Play the final dialogue audio ("Salamat Jack... Salamat little bear")
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_9.wav'),
      );
      debugPrint(
        '[Sorry8] sorry_9.wav playback started, waiting for completion...',
      );

      // Wait for the dialogue to finish completely
      await _audioPlayer.onPlayerComplete.first;
      debugPrint('[Sorry8] sorry_9.wav COMPLETE');
      if (!mounted) return;

      // 2. Jack walks over to Little Bear (car travels with him, still in his hand)
      await _walkController.forward(from: 0);
      debugPrint('[Sorry8] Walk COMPLETE');
      if (!mounted) return;

      // Small pause so the handoff doesn't feel instant
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      // 3. Hand the car over to Little Bear — slide it across explicitly so
      // it stays perfectly in sync with the bounce animation that follows.
      setState(() {
        _isCarWithJack = false;
      });
      await _carSlideController.forward(from: 0);
      debugPrint('[Sorry8] Car slide COMPLETE');
      if (!mounted) return;

      // 4. Trigger the celebration jump!
      debugPrint('[Sorry8] Starting jump...');
      await _jumpController.forward(from: 0);
      debugPrint('[Sorry8] Jump COMPLETE');
      if (!mounted) return;

      // 5. Once they've stopped jumping, play the ending line...
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_ending.wav'),
      );
      await _audioPlayer.onPlayerComplete.first;
      debugPrint('[Sorry8] sorry_ending.wav COMPLETE');
      if (!mounted) return;

      // ...then reveal the Good Job overlay
      setState(() {
        _showGoodJob = true;
      });
      debugPrint('[Sorry8] Good Job overlay shown');
    } catch (e, stackTrace) {
      debugPrint('[Sorry8] ERROR in story sequence: $e');
      debugPrint('[Sorry8] Stack trace: $stackTrace');
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
    _carSlideController.dispose();
    _jumpController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    // Base scaling logic
    final double baseCharacterHeight = sh * 1.18;
    final double characterHeight = baseCharacterHeight * 0.70;
    final double baseBottomOffset = -(baseCharacterHeight * 0.15);

    // --- Absolute Coordinates ---
    // Little Bear is fixed on the left
    final double bearLeft = sw * 0.12;
    // Little Bear's hand area (roughly 45% across his body)
    final double bearHandX = bearLeft + (characterHeight * 0.45);

    // Jack's STARTING position, on the right
    final double jackRight = sw * 0.12;
    final double jackStartLeft = sw - jackRight - (characterHeight * 0.85);

    // Jack's MEETING position, right next to Little Bear.
    // Tweak the multiplier below to control how close Jack stands to Bear.
    final double jackMeetingLeft = bearLeft + (characterHeight * 0.85);

    // The height where the car sits in their hands
    final double handY = baseBottomOffset + (characterHeight * 0.12);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Layer
          Image.asset(
            'assets/images/backgrounds/bg_lumi_classroom.png',
            fit: BoxFit.cover,
          ),

          // 2. Animated Builder driving both the walk and the jump
          AnimatedBuilder(
            animation: Listenable.merge([
              _walkController,
              _carSlideController,
              _jumpController,
            ]),
            builder: (context, child) {
              // Jack's current horizontal position: interpolates from his
              // starting spot to the meeting spot next to Little Bear.
              final double walkT = Curves.easeInOut.transform(
                _walkController.value,
              );
              final double jackCurrentLeft =
                  jackStartLeft + (jackMeetingLeft - jackStartLeft) * walkT;

              // Jack's hand position follows him as he walks
              final double jackHandX =
                  jackCurrentLeft + (characterHeight * 0.08);

              // Two smooth bounces using math.sin and .abs()
              final double t = _jumpController.value;
              final double bounce =
                  (math.sin(t * math.pi * 2)).abs() * (characterHeight * 0.08);

              // Car's horizontal position: stays glued to Jack's hand while
              // he's holding it, then slides over to Bear's hand. Computed
              // manually (not via AnimatedPositioned) so it updates on the
              // exact same frame as the bounce above — otherwise the car's
              // own implicit animation lags behind the quick jump bounces
              // and looks like it's floating separately from Bear's hand.
              final double slideT = Curves.easeInOutCubic.transform(
                _carSlideController.value,
              );
              final double carLeft = _isCarWithJack
                  ? jackHandX
                  : jackHandX + (bearHandX - jackHandX) * slideT;

              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // --- LITTLE BEAR (Left, stays put, jumps at the end) ---
                  Positioned(
                    left: bearLeft,
                    bottom: baseBottomOffset + bounce,
                    child: SizedBox(
                      height: characterHeight,
                      child: Image.asset(
                        'assets/images/characters/little_bear_uniform.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // --- JACK THE FOX (walks left toward Bear, then jumps) ---
                  Positioned(
                    left: jackCurrentLeft,
                    bottom: baseBottomOffset + bounce,
                    child: SizedBox(
                      height: characterHeight,
                      width: characterHeight * 0.85,
                      child: Image.asset(
                        'assets/images/characters/jack_smiling.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // --- THE TOY CAR (in Jack's hand while he walks, then
                  // slides over to Bear's hand once he arrives — bottom and
                  // left are both driven manually every frame so it never
                  // desyncs from the characters' bounce) ---
                  Positioned(
                    bottom: handY + bounce,
                    left: carLeft,
                    child: Image.asset(
                      'assets/images/objects/lumi/car.png',
                      width: characterHeight * 0.35,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. "Good Job!" overlay — shown after the jump + ending line
          if (_showGoodJob)
            GoodJobOverlay(
              // Swap for whichever character should headline this level's
              // completion screen (Little Bear, Jack, or another asset)
              characterImage: 'assets/images/characters/dr.woo_smiling.png',
              closeButtonColor: const Color(0xFF266589),
              onNext: () {
                // TODO: replace with your actual next-level route
                Navigator.of(context).maybePop();
              },
              onRestart: () {
                // TODO: replace with your actual restart route
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const Sorry8Screen()),
                );
              },
              onBack: () {
                Navigator.of(context).maybePop();
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
