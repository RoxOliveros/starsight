import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/woodpecker_letter_ladder_game.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'alphabet_game_ui.dart';

class AlphabetHuntScreen extends StatefulWidget {
  final String letter;

  const AlphabetHuntScreen({super.key, required this.letter});

  @override
  State<AlphabetHuntScreen> createState() => _AlphabetHuntScreenState();
}

class _AlphabetHuntScreenState extends State<AlphabetHuntScreen>
  with TofiReactionMixin {
  @override
  AudioPlayer get tofiPlayer => _audioPlayer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  late List<String> _letterPool;
  final List<HuntObject> _activeObjects = [];

  int _correctCount = 0;
  final int _winCondition = 4;

  // Lists to track the exact screen positions for our tap effects!
  final List<Map<String, double>> _wrongEffects = [];
  final List<Map<String, double>> _correctEffects = [];
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // 1. Figure out which 3-letter group we are hunting in
    _letterPool = _getPoolForLetter(widget.letter);

    // 2. Generate the scattered objects
    _generateHuntField();
  }

  // --- THE DYNAMIC 3-LETTER POOL ---
  List<String> _getPoolForLetter(String target) {
    String upperTarget = target.toUpperCase();

    if (['A', 'B', 'C'].contains(upperTarget)) return ['A', 'B', 'C'];
    if (['D', 'E', 'F'].contains(upperTarget)) return ['D', 'E', 'F'];
    if (['G', 'H', 'I'].contains(upperTarget)) return ['G', 'H', 'I'];
    if (['J', 'K', 'L'].contains(upperTarget)) return ['J', 'K', 'L'];
    if (['M', 'N', 'O'].contains(upperTarget)) return ['M', 'N', 'O'];
    if (['P', 'Q', 'R'].contains(upperTarget)) return ['P', 'Q', 'R'];
    if (['S', 'T', 'U'].contains(upperTarget)) return ['S', 'T', 'U'];
    if (['V', 'W', 'X'].contains(upperTarget)) return ['V', 'W', 'X'];
    if (['X', 'Y', 'Z'].contains(upperTarget)) return ['X', 'Y', 'Z'];

    return ['A', 'B', 'C'];
  }

  void _generateHuntField() {
    _activeObjects.clear();

    for (int i = 0; i < _winCondition; i++) {
      _activeObjects.add(_createHuntObject(widget.letter.toUpperCase()));
    }

    List<String> distractors = _letterPool
        .where((l) => l != widget.letter.toUpperCase())
        .toList();

    for (String distractorLetter in distractors) {
      // Add 3 of each distractor
      for (int i = 0; i < 2; i++) {
        _activeObjects.add(_createHuntObject(distractorLetter));
      }
    }

    // Shuffle them so the target is hidden randomly among the distractors!
    _activeObjects.shuffle();
  }

  HuntObject _createHuntObject(String letter) {
    // --- EVEN LAYOUT FIX ---
    // We set rotation and offsets to 0.0 so they sit in a perfectly neat grid!
    return HuntObject(
      id: UniqueKey().toString(),
      letter: letter,
      imagePath: _getObjectImage(letter),
      rotation: 0.0,
      offsetX: 0.0,
      offsetY: 0.0,
    );
  }

  String _getObjectImage(String letter) {
    const Map<String, String> objectMap = {
      'A': 'apple',
      'B': 'ball',
      'C': 'car',
      'D': 'duck',
      'E': 'egg',
      'F': 'feet',
      'G': 'glass',
      'H': 'hat',
      'I': 'igloo',
      'J': 'jar',
      'K': 'key',
      'L': 'lamp',
      'M': 'milk',
      'N': 'nose',
      'O': 'oil',
      'P': 'pan',
      'Q': 'queen',
      'R': 'rain',
      'S': 'sun',
      'T': 'tree',
      'U': 'umbrella',
      'V': 'vase',
      'W': 'window',
      'X': 'xylophone',
      'Y': 'yarn',
      'Z': 'zero',
    };
    final name = objectMap[letter.toUpperCase()] ?? 'apple';
    return 'assets/images/objects/forest/$name.png';
  }

  void _onObjectTap(HuntObject obj, GlobalKey key) async {
    RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Get the exact pixel position of the object they tapped
    Offset position = box.localToGlobal(Offset.zero);

    if (obj.letter == widget.letter.toUpperCase()) {
      setState(() {
        _correctEffects.add({'x': position.dx, 'y': position.dy});
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _correctEffects.removeWhere(
              (effect) =>
                  effect['x'] == position.dx && effect['y'] == position.dy,
            );
          });
        }
      });

      // 3. Play Sound & Remove Object
      String audioFile = 'audio/alphabet_forest/sound_effects/sound_${widget.letter.toLowerCase()}.wav';
      await _audioPlayer.play(AssetSource(audioFile));
      await _audioPlayer.onPlayerComplete.first;

      showTofiReaction(TofiState.correct);

      setState(() {
        _correctCount++;
        _activeObjects.removeWhere((item) => item.id == obj.id);

        if (_correctCount >= _winCondition) {
          _showApplause();
        }
      });
    } else {
      // --- WRONG MATCH ---
      // Show the Red X Effect
      showTofiReaction(TofiState.wrong);

      setState(() {
        _wrongEffects.add({'x': position.dx, 'y': position.dy});
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _wrongEffects.removeWhere(
              (effect) =>
                  effect['x'] == position.dx && effect['y'] == position.dy,
            );
          });
        }
      });
    }
  }

  void _showApplause() {
    final String currentLetter = widget.letter.toUpperCase();

    const skipGoodJobLetters = {
      'A', 'B',
      'D', 'E',
      'G', 'H',
      'J', 'K',
      'M', 'N',
      'P', 'Q',
      'S', 'T',
      'V', 'W',
      'Y', 'Z',
    };

    if (skipGoodJobLetters.contains(currentLetter)) {
      String nextLetter =
      String.fromCharCode(currentLetter.codeUnitAt(0) + 1);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AlphabetIntroScreen(letter: nextLetter),
        ),
      );
      return;
    }

    // mark level complete for some letters
    const completeLevelsLetters = {
      'C',
      'F',
      'I',
      'L',
      'O',
      'R',
      'U',
      'X',
      'Z',
    };

    if (completeLevelsLetters.contains(currentLetter)) {
      final completedLevel =
      ForestProgressService.levelNumberForLetter(currentLetter);

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
            Navigator.pop(context); // Close the prompt

            String current = widget.letter.toUpperCase();

            if (currentLetter == 'C'){
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const WoodpeckerLetterLadderGame(level: 2),
                ),
              );
            } else {
              // Otherwise, just go to the next normal Intro screen!
              int charCode = current.codeUnitAt(0);
              if (charCode >= 65 && charCode < 90) {
                String nextLetter = String.fromCharCode(charCode + 1);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetIntroScreen(letter: nextLetter),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForestLevelScreen(),
                  ),
                );
              }
            }
          },
          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _correctCount = 0;
              _generateHuntField();
            });
          },
          onBack: () {
            Navigator.pop(context); // Close the prompt
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
    OrientationService.setLandscape();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double objSize = (screenSize.height * 0.22).clamp(80.0, 150.0);

    return Scaffold(
      body: ForestBackground(
        child: Stack(
            children: [
              buildTofi(context),

              // ── Back button ──
              const Positioned(top: 25, left: 20, child: ForestBackButton()),

              // ── Title ──
              Positioned(
                top: 25,
                left: 0,
                right: 0,
                child: Center(child: ForestInstructionBanner(text: 'Find all the letters: ${widget.letter.toUpperCase()}')),
              ),

              // Level Badge
              Positioned(
                top: 25,
                right: 20,
                child: ForestLevelBadge(
                  level: ForestProgressService.levelNumberForLetter(
                    widget.letter.toUpperCase(),
                  ) ??
                      1,
                ),
              ),

              Positioned(
                top: 80,
                bottom: 20,
                left: 180,
                right: 20,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate item size to fit exactly 4 columns and 3 rows
                    final double itemWidth =
                        (constraints.maxWidth - (3 * 12)) / 4;
                    final double itemHeight =
                        (constraints.maxHeight - (2 * 12)) / 2;
                    final double itemSize = itemWidth < itemHeight
                        ? itemWidth
                        : itemHeight;
                    final double letterFontSize = itemSize * 0.45;

                    return GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: itemWidth / itemHeight,
                      children: _activeObjects.map((obj) {
                        final GlobalKey objKey = GlobalKey();

                        return GestureDetector(
                          key: objKey,
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _onObjectTap(obj, objKey),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(obj.imagePath, fit: BoxFit.contain),
                              Text(
                                obj.letter,
                                style: TextStyle(
                                  fontFamily: ForestAppTextStyles.fredoka,
                                  fontSize: letterFontSize,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 6,
                                      color: Colors.black87,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              ..._wrongEffects.map((effect) {
                return Positioned(
                  left: effect['x']! - 20,
                  top: effect['y']! - 20,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.redAccent,
                    size: objSize * 0.8,
                    shadows: const [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                );
              }),
              ..._correctEffects.map((effect) {
                return Positioned(
                  left: effect['x']! - 20,
                  top: effect['y']! - 20,
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.greenAccent.shade700,
                    size: objSize * 0.8,
                    shadows: const [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
  }
}

class HuntObject {
  final String id;
  final String letter;
  final String imagePath;
  final double rotation;
  final double offsetX;
  final double offsetY;

  HuntObject({
    required this.id,
    required this.letter,
    required this.imagePath,
    required this.rotation,
    required this.offsetX,
    required this.offsetY,
  });
}
