import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_stars_screen.dart';
import 'package:StarSight/ui_layer/lumi_town/town_level.dart';
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
  bool _showGoodJobOverlay = false;
  bool _showTryAgainButton = false;
  bool _showTutorial = true;
  bool _secondFoxCanceled = false;
  String _currentMood = 'normal';

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
    'dog': 'assets/images/characters/tofi_the_dog.png',
  };

  static const Map<String, String> charactersSmiling = {
    'bunny': 'assets/images/characters/roxie_try_again.png',
    'cat': 'assets/images/characters/kiki_smiling.png',
    'fox': 'assets/images/characters/jack_smiling.png',
    'penguin': 'assets/images/characters/doma_smiling.png',
    'owl': 'assets/images/characters/dr.woo_smiling.png',
    'dog': 'assets/images/characters/tofi_smiling.png',
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

  String get currentCharacterImage {
    String charKey = _sequence[_charIndex];

    if (_currentMood == 'smiling') {
      return charactersSmiling[charKey] ?? characters[charKey]!;
    } else if (_currentMood == 'sad' && charKey == 'fox') {
      // Make sure this path points to your sad fox image
      return 'assets/images/characters/jack_sad.png';
    }

    return characters[charKey] ?? characters['bunny']!;
  }

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

      // 1. Make the character smile!
      setState(() {
        _currentMood = 'smiling';
      });

      String audioPath =
          characterVoiceovers[currentCharKey] ??
          'audio/lumi_town/level5/share_yes.wav';

      _audioPlayer.play(AssetSource(audioPath));

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        if (_charIndex < _sequence.length - 1) {
          // Normal progression to the next character
          setState(() {
            _readyForEntrance = false;
            _charIndex++;
            _hasGivenPancake = false;
            _hasGivenWater = false;
            _currentMood = 'normal'; // Reset mood for next character
          });

          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            setState(() {
              _readyForEntrance = true;
            });
          });
        } else {
          // End of the sequence reached (Dog was just fed).
          setState(() {
            _readyForEntrance = false;
          });

          // Check if we saved enough food by denying the 2nd fox
          if (_secondFoxCanceled) {
            // SUCCESS! Everyone gets a share.
            setState(() {
              _showAllCharactersSuccessUI = true;
            });
            _audioPlayer.play(
              AssetSource('audio/lumi_town/level5/success_narration.wav'),
            );
            Future.delayed(const Duration(seconds: 2), () {
              if (!mounted) return;
              setState(() {
                _showGoodJobOverlay = true;
              });
            });
          } else {
            // FAILURE! We fed the 2nd fox, so the bear gets nothing.
            setState(() {
              _showSadBearFailedUI = true;
            });
            _audioPlayer.play(
              AssetSource('audio/lumi_town/level5/sharing_wrong.wav'),
            );
            Future.delayed(const Duration(seconds: 12), () {
              if (!mounted) return;
              setState(() {
                _showTryAgainButton = true;
              });
            });
          }
        }
      });
    }
  }

  // Called when the cancel button is tapped
  void _handleCancel() {
    // 1. If it's NOT the 2nd Fox (index 5), playing the cancel button is wrong!
    if (_charIndex != 5) {
      _audioPlayer.play(AssetSource('audio/lumi_town/level5/cancel_wrong.wav'));
      return; // Stop here! Do not reset items or trigger character retry.
    }

    // 2. User correctly canceled the 2nd Fox!
    if (_charIndex == 5) {
      setState(() {
        _secondFoxCanceled = true; // Mark as successfully bypassed
        _currentMood = 'sad'; // Make the fox sad

        // --- NEW FIX ---
        // Restore items to the table if they were accidentally dragged
        if (_hasGivenPancake) _pancakesLeft++;
        if (_hasGivenWater) _waterLeft++;

        // Remove the items from the Fox's hands immediately
        _hasGivenPancake = false;
        _hasGivenWater = false;
        // ---------------
      });

      // Wait a moment so the user sees the sad fox, then move to the dog
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          _readyForEntrance = false;
          _charIndex++; // Move to the dog
          _currentMood = 'normal'; // Reset mood for the dog
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() {
            _readyForEntrance = true; // Bring the dog in
          });
        });
      });
      return; // Stop the standard retry logic
    }
  }

  // Back-row character slot (dog / cat): positioned by horizontal fraction
  // of the stack's width, filling the FULL height of the stack (top:0,
  // bottom:0) so that FractionallySizedBox has a real height to size
  // against. Bottom-anchored just like the front row, so it shares the same
  // "ground" line — the only difference is it's taller and painted
  // *underneath* the front row (declared earlier in the Stack), so the
  // front-row characters naturally cover its lower body, exactly like the
  // reference photo where the dog/cat peek in from behind the group instead
  // of floating alone above a gap.

  /*
  Widget _backCharacterSlot(
    String imagePath, {
    required double leftFraction,
    required double widthFraction,
    required double heightFraction,
    required double sw,
    required int delayMs,
  }) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: sw * leftFraction,
      width: sw * widthFraction,
      child: FractionallySizedBox(
        heightFactor: heightFraction,
        alignment: Alignment.bottomCenter,
        child: Image.asset(imagePath, fit: BoxFit.contain)
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
              delay: Duration(milliseconds: delayMs),
            )
            .moveY(
              begin: 0,
              end: -14,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
            ),
      ),
    );
  }

  // Front-row character slot: an Expanded column sized to heightFraction of
  // the available row height, bottom-anchored, so characters line up like a
  // real group photo with the bear standing tallest in the center.
  Widget _frontCharacterSlot(
    String imagePath, {
    required double heightFraction,
    required int delayMs,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FractionallySizedBox(
          heightFactor: heightFraction,
          alignment: Alignment.bottomCenter,
          child: Image.asset(imagePath, fit: BoxFit.contain)
              .animate(
                onPlay: (c) => c.repeat(reverse: true),
                delay: Duration(milliseconds: delayMs),
              )
              .moveY(
                begin: 0,
                end: -16,
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
              ),
        ),
      ),
    );
  }
*/
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
            end: -14, // Subtle bobbing animation
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
          ),
    );
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
                                _secondFoxCanceled = false;
                                _currentMood = 'normal';
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
              child: Stack(
                children: [
                  // Layer 1: Background and the Cropped Group Photo
                  Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                          'assets/images/backgrounds/bg_lumi_park.png',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      alignment: Alignment.bottomCenter,
                      children: [
                        // ── Back Row ──
                        _positionedCharacter(
                          charactersSmiling['dog']!,
                          left: -sw * 0.02,
                          bottom: -sh * 0.15,
                          width: sw * 0.38,
                          delayMs: 0,
                        ),
                        _positionedCharacter(
                          charactersSmiling['cat']!,
                          left: sw * 0.62,
                          bottom: -sh * 0.12,
                          width: sw * 0.40,
                          delayMs: 150,
                        ),

                        // ── Mid/Front Row ──
                        _positionedCharacter(
                          charactersSmiling['bunny']!,
                          left: -sw * 0.01,
                          bottom: -sh * 0.22,
                          width: sw * 0.26,
                          delayMs: 300,
                        ),
                        _positionedCharacter(
                          charactersSmiling['penguin']!,
                          left: sw * 0.18,
                          bottom: -sh * 0.20,
                          width: sw * 0.26,
                          delayMs: 450,
                        ),
                        _positionedCharacter(
                          charactersSmiling['owl']!,
                          left: sw * 0.55,
                          bottom: -sh * 0.18,
                          width: sw * 0.28,
                          delayMs: 750,
                        ),
                        _positionedCharacter(
                          charactersSmiling['fox']!,
                          left: sw * 0.74,
                          bottom: -sh * 0.20,
                          width: sw * 0.28,
                          delayMs: 900,
                        ),

                        // ── Front Center ──
                        _positionedCharacter(
                          'assets/images/characters/little_bear_uniform.png',
                          left: sw * 0.33,
                          bottom: -sh * 0.28,
                          width: sw * 0.35,
                          delayMs: 600,
                        ),
                      ],
                    ),
                  ),

                  // Layer 2: The Good Job Overlay (Delayed)
                  if (_showGoodJobOverlay)
                    GoodJobOverlay(
                      characterImage:
                          'assets/images/characters/dr.woo_smiling.png',
                      closeButtonColor: const Color(0xFF266589),
                      onNext: () async {
                        await TownProgressService.instance.markLevelComplete(5);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const EmotionStarsScreen(),
                          ),
                        );
                      },
                      onRestart: () {
                        setState(() {
                          _showAllCharactersSuccessUI = false;
                          _showGoodJobOverlay = false; // Reset this too!
                          _charIndex = 0;
                          _pancakesLeft = 7;
                          _waterLeft = 7;
                          _hasGivenPancake = false;
                          _hasGivenWater = false;
                          _readyForEntrance = true;
                          _secondFoxCanceled = false;
                          _currentMood = 'normal';
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
                ],
              ),
            ),
        ], // <-- This closes the main Stack's children array
      ), // <-- This closes the main Stack
    ); // <-- This closes the Scaffold
  }
}
