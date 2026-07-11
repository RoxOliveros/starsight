import 'dart:math' as math;
import 'package:StarSight/games_ui_layer/lumi_town/lvl5/sharing_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

class Sharing1 extends StatefulWidget {
  const Sharing1({super.key});

  @override
  State<Sharing1> createState() => _Sharing1State();
}

class _Sharing1State extends State<Sharing1> {
  // Initialize a localized AudioPlayer for this specific screen
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    // Play the audio intro as soon as the screen initializes
    _audioPlayer.play(AssetSource('audio/lumi_town/level5/intro.wav'));
  }

  @override
  void dispose() {
    // Stop and dispose of the player to free up resources when exiting
    _audioPlayer.dispose();

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
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    // ── Layout constants ──────────────────────────────────────────────────
    final double bearHeight = sh * 0.95;
    const double bearBottom = 0.0;
    final double tableBottom = -sh * 0.60;
    final double tableWidth = sw;

    // ── Pancake stack math ───────────────────────────────────────────────
    final double plateWidth = sw * 0.26;
    final double pancakeWidth = sw * 0.20;
    final double stackBaseOffset = sh * 0.055;
    final double pancakeThickness = sh * 0.055;
    const int plainPancakeCount = 6;

    final rng = math.Random(7);
    final List<double> jitterDx = List.generate(
      plainPancakeCount + 1,
      (_) => (rng.nextDouble() - 0.5) * pancakeWidth * 0.18,
    );

    // ── Thumb button size ────────────────────────────────────────────────
    final double thumbSize = sw * 0.11;
    final double thumbBtnSize = sw * 0.135;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background ────────────────────────────────────────────
          Image.asset(
            'assets/images/backgrounds/bg_game_kitchen.png',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF3C8), Color(0xFFE8C97A)],
                ),
              ),
            ),
          ),

          // ── 2. Bear (behind table) ───────────────────────────────────
          Positioned(
            bottom: bearBottom,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/characters/little_bear_uniform.png',
                height: bearHeight,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => const SizedBox(),
              ),
            ),
          ),

          // ── 3. Table (in front of bear) ──────────────────────────────
          Positioned(
            bottom: tableBottom,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/objects/lumi/table.png',
              width: tableWidth,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) =>
                  Container(height: sh * 0.22, color: const Color(0xFFCD853F)),
            ),
          ),

          // ── 4. Pancake stack (right side, on table surface) ──────────
          Positioned(
            bottom: stackBaseOffset,
            right: sw * 0.04,
            child: SizedBox(
              width: plateWidth,
              height: sh * 1.1,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Plate
                  Positioned(
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/objects/lumi/plate.png',
                      width: plateWidth,
                      errorBuilder: (ctx, err, st) => Container(
                        width: plateWidth,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),

                  // Plain pancakes
                  ...List.generate(plainPancakeCount, (index) {
                    final dx = jitterDx[index];
                    return Positioned(
                      bottom: stackBaseOffset + (index * pancakeThickness),
                      left: plateWidth / 2 - pancakeWidth / 2 + dx,
                      child: Image.asset(
                        'assets/images/objects/lumi/pancake.png',
                        width: pancakeWidth,
                        errorBuilder: (ctx, err, st) => Container(
                          width: pancakeWidth,
                          height: pancakeThickness * 0.55,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8A037),
                            borderRadius: BorderRadius.circular(
                              pancakeWidth / 2,
                            ),
                            border: Border.all(
                              color: const Color(0xFFB8641A),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Top pancake — butter & syrup
                  Positioned(
                    bottom:
                        stackBaseOffset +
                        (plainPancakeCount * pancakeThickness),
                    left:
                        plateWidth / 2 -
                        pancakeWidth / 2 +
                        jitterDx[plainPancakeCount],
                    child: Image.asset(
                      'assets/images/objects/lumi/pancke_maple_syrup_butter.png',
                      width: pancakeWidth,
                      errorBuilder: (ctx, err, st) => Container(
                        width: pancakeWidth,
                        height: pancakeThickness * 0.55,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4843A),
                          borderRadius: BorderRadius.circular(pancakeWidth / 2),
                          border: Border.all(
                            color: const Color(0xFFB8641A),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
          ),

          // ── 5. Thumbs Up / Down buttons (center-bottom, on table) ────
          Positioned(
            bottom: sh * 0.10,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbs Up
                  GestureDetector(
                    onTap: () async {
                      debugPrint('Thumbs Up Tapped!');
                      // Stop the intro audio before playing the success track
                      await _audioPlayer.stop();

                      // Start playing the success track
                      await _audioPlayer.play(
                        AssetSource('audio/lumi_town/level5/share_yes.wav'),
                      );

                      // --- PERFECT TIMING NAVIGATION ---
                      // Wait exactly until this specific audio file finishes playing
                      await _audioPlayer.onPlayerComplete.first;

                      // Ensure the widget is still on screen before navigating
                      if (!mounted) return;

                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const Sharing2(),
                        ),
                      );
                      // ---------------------------------
                    },
                    child: _ThumbButton(
                      imagePath: 'assets/images/objects/lumi/thumbs_up.png',
                      backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                      size: thumbBtnSize,
                      iconSize: thumbSize,
                      animDelay: Duration.zero,
                    ),
                  ),
                  SizedBox(width: sw * 0.04),
                  // Thumbs Down
                  GestureDetector(
                    onTap: () async {
                      debugPrint('Thumbs Down Tapped!');
                      // Stop the intro audio before playing the gentle correction track
                      await _audioPlayer.stop();
                      await _audioPlayer.play(
                        AssetSource('audio/lumi_town/level5/share_no.wav'),
                      );
                    },
                    child: _ThumbButton(
                      imagePath: 'assets/images/objects/lumi/thumbs_down.png',
                      backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                      size: thumbBtnSize,
                      iconSize: thumbSize,
                      animDelay: const Duration(milliseconds: 400),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 7. Close button (Top Left) ────────────────────────────────
          Positioned(
            top: sh * 0.05,
            left: sw * 0.03,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Image.asset(
                'assets/images/buttons/x_blue.png', // <-- Update this path to where you saved x_blue.png!
                width: sw * 0.065,
                fit: BoxFit.contain,
                // Keeps the old made-up button as a safe fallback just in case the asset path is mistyped:
                errorBuilder: (ctx, err, st) => Container(
                  width: sw * 0.065,
                  height: sw * 0.065,
                  decoration: const BoxDecoration(
                    color: Color(0xFF266589),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: sw * 0.04,
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

class _ThumbButton extends StatelessWidget {
  final String imagePath;
  final Color backgroundColor;
  final double size;
  final double iconSize;
  final Duration animDelay;

  const _ThumbButton({
    required this.imagePath,
    required this.backgroundColor,
    required this.size,
    required this.iconSize,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(size * 0.10),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) => Icon(
              imagePath.contains('up') ? Icons.thumb_up : Icons.thumb_down,
              color: Colors.white,
              size: iconSize * 0.7,
            ),
          ),
        )
        .animate(delay: animDelay, onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.06, 1.06),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
  }
}
