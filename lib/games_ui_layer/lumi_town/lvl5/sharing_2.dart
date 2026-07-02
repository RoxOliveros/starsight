import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

import 'character_entrance.dart';
import 'sharing_tutorial_prompt.dart';

class Sharing2 extends StatefulWidget {
  const Sharing2({super.key});

  @override
  State<Sharing2> createState() => _Sharing2State();
}

class _Sharing2State extends State<Sharing2> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── State Variables ──────────────────────────────────────────────────
  bool _showCancelBtn = false;
  Timer? _cancelBtnTimer;
  bool _readyForEntrance = false;
  bool _showSadBearFailedUI = false;
  bool _showAllCharactersSuccessUI = false;
  bool _showTryAgainButton = false;

  // Whether the "How to Play" tutorial overlay is currently showing.
  // Starts true so new players see it before the round begins.
  bool _showTutorial = true;

  // Inventory state
  int _pancakesLeft = 7;
  int _waterLeft = 7;

  // Turn state
  bool _hasGivenPancake = false;
  bool _hasGivenWater = false;

  // Character sequence tracking
  int _charIndex = 0;
  int _retryCount = 0;

  static const Map<String, String> characters = {
    'bunny': 'assets/images/characters/roxie_the_rabbit.png',
    'cat': 'assets/images/characters/kiki_the_cat.png',
    'fox': 'assets/images/characters/jack_the_fox.png',
    'penguin': 'assets/images/characters/doma_the_penguin2.png',
    'owl': 'assets/images/characters/dr.woo_the_owl.png',
    'dog': 'assets/images/characters/doby_the_dog.png',
  };

  static const Map<String, String> characterVoiceovers = {
    'bunny': 'audio/lumi_town/level5/bunny_thankyou.wav',
    'cat': 'audio/lumi_town/level5/cat_thankyou.wav',
    'fox': 'audio/lumi_town/level5/fox_thankyou.wav',
    'penguin': 'audio/lumi_town/level5/penguin_thankyou.wav',
    'owl': 'audio/lumi_town/level5/owl_thankyou.wav',
    'dog': 'audio/lumi_town/level5/dog_thankyou.wav',
  };

  // The exact sequence requested
  final List<String> _sequence = [
    'bunny',
    'cat',
    'fox',
    'penguin',
    'owl',
    'fox',
    'dog',
  ];

  String get currentCharacterImage =>
      characters[_sequence[_charIndex]] ?? characters['bunny']!;

  @override
  void initState() {
    super.initState();
    _lockOrientationThenStartEntrance();

    // If the tutorial is showing, hold off on the game's own audio and the
    // cancel-button reveal timer until the player dismisses it — otherwise
    // the tutorial narration and the game's "sharing.wav" would overlap.
    if (!_showTutorial) {
      _startRoundAudioAndTimers();
    }
  }

  void _startRoundAudioAndTimers() {
    _cancelBtnTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showCancelBtn = true;
        });
      }
    });

    // Note: the round's narration audio ('sharing.wav') is now played by
    // SharingTutorialPrompt itself, as soon as it appears — not here.
  }

  void _handleTutorialClose() {
    setState(() {
      _showTutorial = false;
    });
    _startRoundAudioAndTimers();
  }

  Future<void> _lockOrientationThenStartEntrance() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

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

  void _checkNextCharacter() {
    if (_hasGivenPancake && _hasGivenWater) {
      String currentCharKey = _sequence[_charIndex];

      String audioPath =
          characterVoiceovers[currentCharKey] ??
          'audio/lumi_town/level5/share_yes.wav';

      _audioPlayer.play(AssetSource(audioPath));

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        if (_charIndex < _sequence.length - 1) {
          // Normal progression to the next character (e.g., to the Dog)
          setState(() {
            _readyForEntrance = false;
            _charIndex++;
            _hasGivenPancake = false;
            _hasGivenWater = false;
          });

          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            setState(() {
              _readyForEntrance = true;
            });
          });
        } else {
          // End of the sequence reached (Dog was fed).
          // If they are here, they didn't cancel the Fox, so Bear gets nothing!
          setState(() {
            _readyForEntrance = false;
            _showSadBearFailedUI = true;
          });

          // Play the sad bear narration
          _audioPlayer.play(
            AssetSource('audio/lumi_town/level5/sharing_wrong.wav'),
          );

          // Wait 12 seconds for the audio to finish before showing the button
          Future.delayed(const Duration(seconds: 12), () {
            if (!mounted) return;
            setState(() {
              _showTryAgainButton = true;
            });
          });
        }
      });
    }
  }

  // Called when the cancel button is tapped
  void _handleCancel() {
    _audioPlayer.play(AssetSource('audio/lumi_town/level5/share_no.wav'));

    // NEW: User correctly canceled the 2nd Fox!
    if (_charIndex == 5) {
      setState(() {
        _readyForEntrance = false;
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _showAllCharactersSuccessUI = true; // Show all characters
        });
        // Play the success audio
        _audioPlayer.play(
          AssetSource('audio/lumi_town/level5/success_narration.wav'),
        );
      });
      return; // Stop the standard retry logic
    }

    // Standard cancel logic for other characters
    setState(() {
      _readyForEntrance = false; // Triggers exit

      if (_hasGivenPancake) _pancakesLeft++;
      if (_hasGivenWater) _waterLeft++;

      _hasGivenPancake = false;
      _hasGivenWater = false;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _readyForEntrance = true;
        _retryCount++;
      });
    });
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

    // Seeded random for consistent jitter across state rebuilds
    final rng = math.Random(7);
    final List<double> jitterDx = List.generate(
      10, // Max capacity
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

          // ── 2. Drag Target & Character Entrance ──────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                if (details.data == 'pancake' && !_hasGivenPancake) return true;
                if (details.data == 'water' && !_hasGivenWater) return true;
                return false;
              },
              onAcceptWithDetails: (details) {
                if (details.data == 'pancake') {
                  setState(() {
                    _pancakesLeft--;
                    _hasGivenPancake = true;
                  });
                } else if (details.data == 'water') {
                  setState(() {
                    _waterLeft--;
                    _hasGivenWater = true;
                  });
                }
                _checkNextCharacter();
              },
              builder: (context, candidateData, rejectedData) {
                return Center(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // The Character — carries the plate (pancake) on its
                      // right arm (screen-left, user's POV) and the water
                      // glass on its left arm (screen-right, user's POV).
                      if (_readyForEntrance)
                        CharacterEntrance(
                          key: ValueKey('$_charIndex-$_retryCount'),
                          characterImagePath: currentCharacterImage,
                          characterHeightFraction: 0.95,
                          plateWidthFraction: 0.18,
                          plateHeightFraction:
                              0.24, // arm height, not cheek height
                          plateOffsetXFraction:
                              -0.55, // right arm — screen-left
                          primaryItemOverlayImagePath: _hasGivenPancake
                              ? 'assets/images/objects/lumi/pancke_maple_syrup_butter.png'
                              : null,
                          secondaryItemImagePath: _hasGivenWater
                              ? 'assets/images/objects/lumi/water_glass.png'
                              : null,
                          secondaryItemWidthFraction: 0.10,
                          // secondaryItemOffsetXFraction is left unset, so it
                          secondaryItemOffsetXFraction: 0.40,
                          // defaults to the mirror of plateOffsetXFraction:
                          // left arm — screen-right.
                          from: AxisDirection.right,
                          walkDuration: const Duration(milliseconds: 3000),
                          stepDuration: const Duration(milliseconds: 380),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── 3. Table ───────────────────────────────────────────────
          Positioned(
            bottom: tableBottom,
            left: 0,
            right: 0,
            child: IgnorePointer(
              // IgnorePointer allows drops to pass through to the DragTarget
              child: Image.asset(
                'assets/images/objects/lumi/table.png',
                width: tableWidth,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => Container(
                  height: sh * 0.22,
                  color: const Color(0xFFCD853F),
                ),
              ),
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
                        decoration: BoxDecoration(color: Colors.white),
                      ),
                    ),
                  ),

                  // Dynamic Pancake Stack
                  ...List.generate(_pancakesLeft, (index) {
                    final dx = jitterDx[index];
                    final isTop =
                        index ==
                        _pancakesLeft -
                            1; // Ensures butter/syrup is always on top

                    final pancakeWidget = Image.asset(
                      isTop
                          ? 'assets/images/objects/lumi/pancke_maple_syrup_butter.png'
                          : 'assets/images/objects/lumi/pancake.png',
                      width: pancakeWidth,
                    );

                    final positionedPancake = Positioned(
                      bottom: stackBaseOffset + (index * pancakeThickness),
                      left: plateWidth / 2 - pancakeWidth / 2 + dx,
                      child: isTop
                          ? Draggable<String>(
                              data: 'pancake',
                              feedback: Material(
                                color: Colors.transparent,
                                child: pancakeWidget,
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: pancakeWidget,
                              ),
                              child: pancakeWidget,
                            )
                          : pancakeWidget,
                    );
                    return positionedPancake;
                  }),
                ],
              ),
            ),
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
                  ...List.generate(7, (index) {
                    // Hide glasses dynamically as they are given away
                    if (index >= _waterLeft) return const SizedBox.shrink();

                    bool isFrontRow = index >= 4;
                    int rowIdx = isFrontRow ? index - 4 : index;
                    double bottom = isFrontRow
                        ? glassFrontRowOffset
                        : glassBackRowOffset;
                    double left = isFrontRow
                        ? (glassSpacing / 2) + (rowIdx * glassSpacing)
                        : rowIdx * glassSpacing;

                    final glassWidget = Image.asset(
                      'assets/images/objects/lumi/water_glass.png',
                      width: glassWidth,
                    );

                    return Positioned(
                      bottom: bottom,
                      left: left,
                      child: Draggable<String>(
                        data: 'water',
                        feedback: Material(
                          color: Colors.transparent,
                          child: glassWidget,
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: glassWidget,
                        ),
                        child: glassWidget,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── 6. Cancel Button ─────────────────────────────────────────
          if (_showCancelBtn)
            Positioned(
              bottom: sh * 0.05,
              right: sw * 0.02,
              child: GestureDetector(
                onTap: _handleCancel,
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

          // ── 8. "How to Play" Tutorial Overlay ─────────────────────────
          // Sits above everything else so it's the first thing the player
          // sees; closing it starts the round's own audio/timers.
          if (_showTutorial)
            Positioned.fill(
              child: SharingTutorialPrompt(onClose: _handleTutorialClose),
            ),
          // ── 9. Sad Bear Failure UI (Ran out of food) ─────────────────
          if (_showSadBearFailedUI)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Background Park
                  Image.asset(
                    'assets/images/backgrounds/bg_lumi_park.png',
                    fit: BoxFit.cover,
                  ),

                  // 2. Sad Bear — big and close, same "half body" framing as
                  // the bear in Sharing1 (tall image, bottom-anchored, so
                  // the top of the screen crops him instead of shrinking him).
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        'assets/images/characters/bear_sad.png', // Change to .jpg if needed
                        height: sh * 0.95,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // 3. Table in the foreground
                  Positioned(
                    bottom: tableBottom,
                    left: 0,
                    right: 0,
                    child: Image.asset(
                      'assets/images/objects/lumi/table.png',
                      width: tableWidth,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // 4. Empty Plate centered on the table
                  Positioned(
                    bottom: stackBaseOffset,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        'assets/images/objects/lumi/plate.png',
                        width: plateWidth,
                      ),
                    ),
                  ),

                  // 5. Try Again Button (Appears ONLY after audio finishes)
                  if (_showTryAgainButton)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45, // Slight dim to pop the button
                        child: Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8A037),
                              padding: EdgeInsets.symmetric(
                                horizontal: sw * 0.06,
                                vertical: sh * 0.04,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              // Reset the game completely
                              setState(() {
                                _showSadBearFailedUI = false;
                                _showTryAgainButton = false;
                                _charIndex = 0;
                                _pancakesLeft = 7;
                                _waterLeft = 7;
                                _hasGivenPancake = false;
                                _hasGivenWater = false;
                                _readyForEntrance = true;
                              });
                            },
                            child: const Text(
                              'Subukan Ulit', // Try Again
                              style: TextStyle(
                                fontSize: 32,
                                fontFamily: 'Fredoka',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── 10. Success UI (Canceled the 2nd Fox) ──────────────────────
          if (_showAllCharactersSuccessUI)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      'assets/images/backgrounds/bg_lumi_park.png',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Lahat ay pantay-pantay!',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black54,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Display every character in a row — each one gets an
                    // equal Expanded slot and fills all the vertical space
                    // between the title and the button, so they read as
                    // "big" while still all fitting side-by-side.
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: characters.values.map((imagePath) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: sw * 0.005,
                              ),
                              child: Image.asset(imagePath, fit: BoxFit.contain)
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .moveY(
                                    begin: 0,
                                    end: -20,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                  ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF90D060),
                        padding: EdgeInsets.symmetric(
                          horizontal: sw * 0.05,
                          vertical: sh * 0.03,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text(
                        'Next Level',
                        style: TextStyle(
                          fontSize: 24,
                          fontFamily: 'Fredoka',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ], // <-- This closes the main Stack's children array
      ), // <-- This closes the main Stack
    ); // <-- This closes the Scaffold
  }
}
