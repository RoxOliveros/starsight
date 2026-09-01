import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_woodpecker_letter_listen.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'alphabet_game_ui.dart';
import 'forest_game_acorn_basket.dart';
import 'forest_game_berry_bush_harvest.dart';
import 'forest_game_butterfly_flower.dart';
import 'forest_game_letter_match.dart';
import 'forest_game_mushroom_hidenseek.dart';
import 'forest_game_paw_print.dart';
import 'forest_game_stick_letter_builder.dart';
import 'forest_game_yak_zebra_race.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlphabetFindScreen extends StatefulWidget {
  final String letter;

  const AlphabetFindScreen({super.key, required this.letter});

  @override
  State<AlphabetFindScreen> createState() => _AlphabetFindScreenState();
}

class _AlphabetFindScreenState extends State<AlphabetFindScreen>
    with TickerProviderStateMixin, TofiReactionMixin, AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => _player;

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _promptPlayer = AudioPlayer();

  final GameTapTracker _tapTracker = GameTapTracker();

  final Random _random = Random();

  static const String _vaseAsset = 'assets/images/objects/forest/vase.png';

  static const int _totalRounds = 3;
  int _completedRounds = 0;

  List<String> _vaseLetters = [];
  int _correctIndex = 0;
  int? _revealedIndex;
  int? _shakingIndex;
  bool _choicesLocked = false;

  late AnimationController _wiggleCtrl; // ADD
  late Animation<double> _wiggle; // ADD

  bool _isPlayingJarSequence = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    startAiCamera();
    _tapTracker.startSession();
    _wiggleCtrl = AnimationController(
      // ADD
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _wiggle = TweenSequence([
      // ADD
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.12), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.12), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _wiggleCtrl, curve: Curves.easeInOut));
    _loadRound();

    onFirstFaceDetected = () {
      _playVaseSounds();
    };
    if (isFaceDetected) {
      onFirstFaceDetected?.call();
      onFirstFaceDetected = null;
    }
  }

  void _loadRound() {
    final String target = widget.letter.toUpperCase();
    final int targetCode = target.codeUnitAt(0);

    // Decoys pulled from letters BEFORE the target (already-learned letters).
    final List<String> previousLetters = [
      for (int c = 65; c < targetCode; c++) String.fromCharCode(c),
    ];
    previousLetters.shuffle(_random);
    final List<String> decoys = previousLetters.take(2).toList();

    // Fallback for early letters (A/B) that don't have 2 previous letters yet.
    while (decoys.length < 2) {
      final candidate = String.fromCharCode(65 + _random.nextInt(26));
      if (candidate != target && !decoys.contains(candidate)) {
        decoys.add(candidate);
      }
    }

    final correctIndex = _random.nextInt(3);

    final letters = List<String>.filled(3, '');

    int decoyIndex = 0;
    for (int i = 0; i < 3; i++) {
      if (i == correctIndex) {
        letters[i] = target;
      } else {
        letters[i] = decoys[decoyIndex++];
      }
    }

    setState(() {
      _vaseLetters = letters;
      _correctIndex = correctIndex;
      _revealedIndex = null;
      _shakingIndex = null;
      _choicesLocked = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isFaceDetected) {
        _playVaseSounds();
      }
    });
  }

  Future<void> _playVaseSounds() async {
    if (_isPlayingJarSequence) return;

    _isPlayingJarSequence = true;

    for (int i = 0; i < _vaseLetters.length; i++) {
      if (!mounted) break;

      setState(() => _shakingIndex = i);

      _wiggleCtrl.repeat(reverse: true);

      await _playLetterSound(_vaseLetters[i]);

      if (!mounted) break;

      _wiggleCtrl.stop();
      _wiggleCtrl.reset();

      setState(() => _shakingIndex = null);

      await Future.delayed(const Duration(milliseconds: 1500));
    }

    _isPlayingJarSequence = false;
  }

  Future<void> _playLetterSound(String letter) async {
    final String lower = letter.toLowerCase();
    StreamSubscription? sub; // ADD
    try {
      final completer = Completer<void>(); // ADD
      sub = _promptPlayer.onPlayerComplete.listen((_) {
        // ADD
        if (!completer.isCompleted) completer.complete();
      });
      await _promptPlayer.play(
        AssetSource('audio/alphabet_forest/sound_effects/sound_$lower.wav'),
      );
      await completer.future.timeout(
        const Duration(seconds: 5),
      ); // ADD — actually waits for playback to finish
    } catch (e) {
      debugPrint("Error playing sound for $lower: $e");
    } finally {
      await sub?.cancel(); // ADD
    }
  }

  Future<void> _onVaseTapped(int index) async {
    if (_choicesLocked) return;

    if (index == _correctIndex) {
      _tapTracker.recordCorrectTap();
      _choicesLocked = true;
      setState(() => _revealedIndex = index);
      await showTofiReaction(TofiState.correct);
      setState(() => _completedRounds++);

      if (_completedRounds >= _totalRounds) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _saveDataAndShowApplause();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _loadRound();
        });
      }
    } else {
      _tapTracker.recordMistake();
      setState(() {
        _shakingIndex = index;
        _revealedIndex = index; // Reveal the chosen wrong vase
      });

      _wiggleCtrl.forward(from: 0);
      showTofiReaction(TofiState.wrong);

      await Future.delayed(const Duration(milliseconds: 3600));

      if (!mounted) return;

      setState(() {
        _shakingIndex = null;
        _revealedIndex = null; // Hide it again so they can keep guessing
      });
    }
  }

  // --- FLEXIBLE NAVIGATION ---
  // Same "what comes next" pattern used by hunt/fall/match/paint.
  void _goToNext() {
    final String current = widget.letter.toUpperCase();
    int charCode = current.codeUnitAt(0);

    if (charCode >= 65 && charCode < 90) {
      String nextLetter = String.fromCharCode(charCode + 1);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlphabetIntroScreen(letter: nextLetter),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ForestLevelScreen()),
      );
    }
  }

  Future<void> _saveDataAndShowApplause() async {
    // 1. Stop the camera and get the emotions
    List<String> finalEmotions = stopAiCamera();

    // 2. Save raw data silently
    try {
      String parentUid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('category_progress')
          .doc('alphabet_forest')
          .collection('games_played')
          .doc(
            'letter_find_${widget.letter.toLowerCase()}',
          ) // e.g., 'letter_find_a'
          .set({
            'activityName': "Alphabet Find (${widget.letter.toUpperCase()})",
            'emotions': finalEmotions,
            'totalTaps': _tapTracker.totalTaps,
            'mistakes': _tapTracker.mistakeCount,
            'timePlayedSeconds': _tapTracker.formattedDuration,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint("Database Error saving Find metrics: $e");
    }

    // 3. Now show the normal win dialog
    _showApplause();
  }

  void _showApplause() {
    final String currentLetter = widget.letter.toUpperCase();

    const skipGoodJobLetters = {
      'A',
      'B',
      'D',
      'E',
      'G',
      'H',
      'J',
      'K',
      'M',
      'N',
      'P',
      'Q',
      'S',
      'T',
      'V',
      'W',
      'Y',
      'Z',
    };

    if (skipGoodJobLetters.contains(currentLetter)) {
      String nextLetter = String.fromCharCode(currentLetter.codeUnitAt(0) + 1);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlphabetIntroScreen(letter: nextLetter),
        ),
      );
      return;
    }

    // mark level complete for some letters
    const completeLevelsLetters = {'C', 'F', 'I', 'L', 'O', 'R', 'U', 'X', 'Z'};

    if (completeLevelsLetters.contains(currentLetter)) {
      final completedLevel = ForestProgressService.levelNumberForLetter(
        currentLetter,
      );

      if (completedLevel != null) {
        ForestProgressService.instance.markLevelComplete(completedLevel);
      }
    }

    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: 'assets/images/characters/dog.png',
          closeButtonColor: ForestColorTheme.seagreen,
          onNext: () {
            Navigator.pop(context);
            if (currentLetter == 'C') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const WoodpeckerLetterListenGame(level: 2),
                ),
              );
            } else if (currentLetter == 'F') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcornBasketGame(level: 4),
                ),
              );
            } else if (currentLetter == 'I') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ButterflyFlowerGardenGame(level: 6),
                ),
              );
            } else if (currentLetter == 'L') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ButterflyLetterMatchGame(level: 8),
                ),
              );
            } else if (currentLetter == 'O') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const MushroomHideAndSeekGame(level: 10),
                ),
              );
            } else if (currentLetter == 'R') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BerryBushHarvestGame(level: 12),
                ),
              );
            } else if (currentLetter == 'U') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowThePawPrintsGame(level: 14),
                ),
              );
            } else if (currentLetter == 'X') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const FallenStickLetterBuilderGame(level: 16),
                ),
              );
            } else if (currentLetter == 'Z') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const YakZebraRaceGame(level: 18),
                ),
              );
            } else {
              _goToNext();
            }
          },
          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _completedRounds = 0;
              _loadRound();
            });
          },
          onBack: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ForestLevelScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    _wiggleCtrl.dispose(); // ADD
    _promptPlayer.dispose();
    _player.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        // <-- Main Stack added here
        children: [
          // 1. Your original game UI
          ForestBackground(
            child: Stack(
              children: [
                const Positioned(top: 25, left: 20, child: ForestBackButton()),

                Positioned(
                  top: 25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ForestInstructionBanner(
                      text: 'Where is the letter ${widget.letter}?',
                    ),
                  ),
                ),

                Positioned(
                  top: 25,
                  right: 20,
                  child: ForestLevelBadge(
                    level:
                        ForestProgressService.levelNumberForLetter(
                          widget.letter.toUpperCase(),
                        ) ??
                        1,
                  ),
                ),

                buildTofi(context),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_vaseLetters.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildVase(i),
                        );
                      }),
                    ),
                  ),
                ),

                // --- REPLAY SOUND BUTTON ---
                Positioned(
                  bottom: 0,
                  right: 20,
                  child: GestureDetector(
                    onTap: _playVaseSounds,
                    child: Image.asset(
                      'assets/images/icons/speaker.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. The Lighting Prompt Card Overlay
          if (!isFaceDetected)
            LightingPromptCard(
              onClose: () {
                setState(() {
                  isFaceDetected = true;
                });
                // Manually trigger the start if they tap X
                onFirstFaceDetected?.call();
                onFirstFaceDetected = null;
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVase(int index) {
    final letter = _vaseLetters[index];
    final revealed = _revealedIndex == index;
    final shaking = _shakingIndex == index;

    return GestureDetector(
      onTap: () => _onVaseTapped(index),
      child: AnimatedBuilder(
        animation: _wiggle,
        builder: (_, child) =>
            Transform.rotate(angle: shaking ? _wiggle.value : 0, child: child),
        child: SizedBox(
          width: 120,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Letter sits behind the vase, revealed once opened.
              AnimatedOpacity(
                opacity: revealed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: ForestColorTheme.darkseagreen,
                      width: 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Center(
                    child: Text(
                      letter,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: ForestAppTextStyles.fredoka,
                        fontSize: 50,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3C5729),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: revealed ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Image.asset(
                  _vaseAsset,
                  width: 120,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4DEB3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ForestColorTheme.darkseagreen,
                        width: 4,
                      ),
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      size: 40,
                      color: Color(0xFF3C5729),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
