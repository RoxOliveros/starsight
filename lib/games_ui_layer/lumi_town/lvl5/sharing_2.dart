import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

import 'character_entrance.dart';

class Sharing2 extends StatefulWidget {
  const Sharing2({super.key});

  @override
  State<Sharing2> createState() => _Sharing2State();
}

class _Sharing2State extends State<Sharing2> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Key used to re-trigger the same character's walk-in animation later
  // (e.g. the fox walking in a second time).
  final GlobalKey<CharacterEntranceState> _entranceKey =
      GlobalKey<CharacterEntranceState>();

  // ── State Variables ──────────────────────────────────────────────────
  bool _showCancelBtn = false;
  Timer? _cancelBtnTimer;

  // The forced landscape rotation is heavy enough to skip frames for a
  // moment. If the character's walk-in animation starts at the same time,
  // it gets "eaten" by that jank and only the final frame is ever shown.
  // We gate building CharacterEntrance behind this so its entrance
  // animation only starts once the rotation has actually settled.
  bool _readyForEntrance = false;

  // All 6 characters that can appear in this scene. Swap which one shows
  // by changing `currentCharacter` below to any key from this map.
  static const Map<String, String> characters = {
    'roxie': 'assets/images/characters/roxie_standing.png',
    'cat': 'assets/images/characters/kiki_smiling.png',
    'fox': 'assets/images/characters/jack_smilling.png',
    'penguin': 'assets/images/characters/doma_the_penguin.png',
    'owl': 'assets/images/characters/dr.woo_the_owl.png',
    'dog': 'assets/images/characters/doby_standing_armsonhips.png',
  };

  // Change this to swap which character appears in the scene.
  String currentCharacterKey = 'fox';

  String get currentCharacterImage =>
      characters[currentCharacterKey] ?? characters['roxie']!;

  @override
  void initState() {
    super.initState();
    _lockOrientationThenStartEntrance();

    // Start a 7-second countdown before showing the cancel button
    _cancelBtnTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        setState(() {
          _showCancelBtn = true;
        });
      }
    });

    // Play the sharing audio as soon as the screen loads
    _audioPlayer.play(AssetSource('audio/lumi_town/level5/sharing.wav'));
  }

  Future<void> _lockOrientationThenStartEntrance() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    // The orientation change can still cause a few janky frames after the
    // platform reports it's done. Wait one extra frame + a short buffer so
    // the layout has actually settled before we start the walk-in — this
    // is what prevents the entrance animation from being "skipped".
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 250));

    if (mounted) {
      setState(() {
        _readyForEntrance = true;
      });
    }
  }

  @override
  void dispose() {
    _cancelBtnTimer?.cancel();
    _audioPlayer.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  /// Re-plays the current character's walk-in entrance from off-screen.
  /// Call this for e.g. the fox walking back in a second time:
  ///   `_replayEntrance()`
  void _replayEntrance() {
    _entranceKey.currentState?.replay();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    // ── Layout constants ──────────────────────────────────────────────────
    final double tableBottom = -sh * 0.60;
    final double tableWidth = sw;

    // ── Pancake stack math (Left Side) ───────────────────────────────────
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

    // ── Water glasses math (Right Side) ──────────────────────────────────
    final double glassWidth = sw * 0.075;
    final double glassSpacing = sw * 0.085;
    final double glassFrontRowOffset = sh * 0.04;
    final double glassBackRowOffset = sh * 0.12;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background ────────────────────────────────────────────
          Image.asset(
            'assets/images/backgrounds/bg_lumi_park.png',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                Container(color: const Color(0xFF90D060)),
          ),

          // ── 2. Character Entrance (walks in from the right, holding a
          //       plate, behind the table). Reusable for all 6 characters
          //       by just changing currentCharacterKey above.
          Positioned(
            bottom:
                0, // Same anchor as the bear in Sharing1 — table crops the lower half
            left: 0,
            right: 0,
            child: Center(
              child: _readyForEntrance
                  ? CharacterEntrance(
                      key: _entranceKey,
                      characterImagePath: currentCharacterImage,
                      characterHeightFraction:
                          0.95, // matches bear's height in Sharing1
                      plateWidthFraction: 0.12,
                      plateHeightFraction: 0.42,
                      plateOffsetXFraction: -0.07,
                      from: AxisDirection.right,
                      walkDuration: const Duration(milliseconds: 3000),
                      stepDuration: const Duration(milliseconds: 380),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // ── 3. Table ───────────────────────────────────────────────
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

          // ── 4. Pancake stack (Left side) ───────────────────────────
          Positioned(
            bottom: stackBaseOffset,
            left: sw * 0.08,
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

          // ── 5. Water Glasses Cluster (Right side) ──────────────────
          Positioned(
            bottom: 0,
            right: sw * 0.05,
            child: SizedBox(
              width: sw * 0.40,
              height: sh * 0.45,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Back Row (4 Glasses)
                  ...List.generate(4, (index) {
                    return Positioned(
                      bottom: glassBackRowOffset,
                      left: index * glassSpacing,
                      child: Image.asset(
                        'assets/images/objects/lumi/water_glass.png',
                        width: glassWidth,
                        errorBuilder: (ctx, err, st) => Container(
                          width: glassWidth,
                          height: glassWidth * 1.2,
                          color: Colors.lightBlueAccent.withOpacity(0.5),
                        ),
                      ),
                    );
                  }),

                  // Front Row (3 Glasses, staggered)
                  ...List.generate(3, (index) {
                    return Positioned(
                      bottom: glassFrontRowOffset,
                      left: (glassSpacing / 2) + (index * glassSpacing),
                      child: Image.asset(
                        'assets/images/objects/lumi/water_glass.png',
                        width: glassWidth,
                        errorBuilder: (ctx, err, st) => Container(
                          width: glassWidth,
                          height: glassWidth * 1.2,
                          color: Colors.lightBlueAccent.withOpacity(0.8),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: const Duration(milliseconds: 700)),
          ),

          // ── 6. Cancel Button (Appears after 7 seconds) ───────────────────
          if (_showCancelBtn)
            Positioned(
              bottom: sh * 0.05,
              right: sw * 0.02,
              child: GestureDetector(
                onTap: () {
                  debugPrint("Cancel Tapped!");
                  // Add rejection logic here.
                  // If the design calls for the character to walk back in
                  // again after a cancel (e.g. the fox retrying), call:
                  //   _replayEntrance();
                },
                child:
                    Image.asset(
                          'assets/images/objects/lumi/cancel_btn.png',
                          width: sw * 0.10,
                          errorBuilder: (ctx, err, st) => Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: sw * 0.10,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.06, 1.06),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                        )
                        .animate()
                        .scale(
                          begin: const Offset(0.0, 0.0),
                          end: const Offset(1.0, 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                        ),
              ),
            ),

          // ── 7. Close button (Top Left) ────────────────────────────────
          Positioned(
            top: sh * 0.05,
            left: sw * 0.03,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: sw * 0.065,
                height: sw * 0.065,
                decoration: const BoxDecoration(
                  color: Color(0xFF266589),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: sw * 0.04),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
