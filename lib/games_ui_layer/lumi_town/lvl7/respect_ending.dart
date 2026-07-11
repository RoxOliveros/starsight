import 'dart:async';
import 'package:StarSight/ui_layer/lumi_town/town_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

// TODO: Update these imports to match your project structure if needed
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
// import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_stars_screen.dart';

class RespectEnding extends StatefulWidget {
  const RespectEnding({super.key});

  @override
  State<RespectEnding> createState() => _RespectEndingState();
}

class _RespectEndingState extends State<RespectEnding> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Controls the delayed appearance of the Good Job prompt
  bool _showGoodJobOverlay = false;

  static const Map<String, String> charactersSmiling = {
    'bunny': 'assets/images/characters/roxie_try_again.png',
    'cat': 'assets/images/characters/kiki_smiling.png',
    'fox': 'assets/images/characters/jack_smiling.png',
    'penguin': 'assets/images/characters/doma_smiling.png',
    'owl': 'assets/images/characters/dr.woo_smiling.png',
    'dog': 'assets/images/characters/tofi_smiling.png',
    'bear': 'assets/images/characters/little_bear_uniform.png',
  };

  @override
  void initState() {
    super.initState();
    _lockOrientation();
    _startEndingSequence();
  }

  Future<void> _lockOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  void _startEndingSequence() {
    // Optional: Play a success narration audio here if you have one for Respect
    _audioPlayer.play(
      AssetSource('audio/lumi_town/level7/respect_success.wav'),
    );

    // Wait 20 seconds so the player can admire the group photo, then show the overlay
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() {
          _showGoodJobOverlay = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // Exact animation and positioning logic from Sharing 2[cite: 1]
  Widget _positionedCharacter(
    String imagePath, {
    required double left,
    required double bottom,
    required double width,
    required int delayMs,
  }) {
    return Positioned(
      left: left,
      bottom: bottom,
      width: width,
      child: Image.asset(imagePath, fit: BoxFit.contain)
          .animate(
            onPlay: (c) => c.repeat(reverse: true),
            delay: Duration(milliseconds: delayMs),
          )
          .moveY(
            begin: 0,
            end: -14, // Subtle bobbing animation[cite: 1]
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: Background and the Cropped Group Photo[cite: 1]
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                // ── CHANGE THIS TO YOUR RESPECT BACKGROUND ──
                image: AssetImage(
                  'assets/images/backgrounds/bg_lumi_classroom.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.bottomCenter,
              children: [
                // ── Back Row ──[cite: 1]
                _positionedCharacter(
                  charactersSmiling['dog']!,
                  left: -sw * -0.05,
                  bottom: -sh * 0.02,
                  width: sw * 0.35,
                  delayMs: 0,
                ),
                _positionedCharacter(
                  charactersSmiling['cat']!,
                  left: sw * 0.62,
                  bottom: -sh * 0.02,
                  width: sw * 0.35,
                  delayMs: 150,
                ),

                // ── Mid/Front Row ──[cite: 1]
                _positionedCharacter(
                  charactersSmiling['bunny']!,
                  left: -sw * 0.01,
                  bottom: -sh * 0.22,
                  width: sw * 0.30,
                  delayMs: 300,
                ),
                _positionedCharacter(
                  charactersSmiling['penguin']!,
                  left: sw * 0.15,
                  bottom: -sh * 0.20,
                  width: sw * 0.30,
                  delayMs: 450,
                ),
                _positionedCharacter(
                  charactersSmiling['bear']!,
                  left: sw * 0.60,
                  bottom: -sh * 0.28,
                  width: sw * 0.25,
                  delayMs: 750,
                ),
                _positionedCharacter(
                  charactersSmiling['fox']!,
                  left: sw * 0.74,
                  bottom: -sh * 0.20,
                  width: sw * 0.30,
                  delayMs: 900,
                ),

                // ── Front Center ──[cite: 1]
                _positionedCharacter(
                  charactersSmiling['owl']!,
                  left: sw * 0.33,
                  bottom: -sh * 0.18,
                  width: sw * 0.35,
                  delayMs: 600,
                ),
              ],
            ),
          ),

          // Layer 2: The Good Job Overlay (Delayed)[cite: 1]
          if (_showGoodJobOverlay)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/dr.woo_smiling.png',
              closeButtonColor: const Color(0xFF266589),
              onNext: () async {
                // TODO: Mark respect level complete and navigate to the next screen
                await TownProgressService.instance.markLevelComplete(6);
                // Navigator.of(context).pushReplacement(...);
              },
              onRestart: () {
                // Reset the overlay timer if they want to replay the ending scene
                setState(() {
                  _showGoodJobOverlay = false;
                });
                _startEndingSequence();
              },
              onBack: () async {
                await TownProgressService.instance.markLevelComplete(6);

                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
                    (route) => route.isFirst,
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
