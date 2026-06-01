import 'dart:math';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_fall.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_match.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_background.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AlphabetHuntScreen extends StatefulWidget {
  final String targetLetter;

  const AlphabetHuntScreen({super.key, required this.targetLetter});

  @override
  State<AlphabetHuntScreen> createState() => _AlphabetHuntScreenState();
}

class _AlphabetHuntScreenState extends State<AlphabetHuntScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _random = Random();

  late List<String> _letterPool;
  List<HuntObject> _activeObjects = [];

  int _correctCount = 0;
  final int _winCondition = 4;

  // Lists to track the exact screen positions for our tap effects!
  List<Map<String, double>> _wrongEffects = [];
  List<Map<String, double>> _correctEffects = [];
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // 1. Figure out which 3-letter group we are hunting in
    _letterPool = _getPoolForLetter(widget.targetLetter);

    // 2. Generate the scattered objects
    _generateHuntField();
  }

  // --- THE DYNAMIC 3-LETTER POOL ---
  List<String> _getPoolForLetter(String target) {
    String upperTarget = target.toUpperCase();
    if (['A', 'B', 'C'].contains(upperTarget)) return ['A', 'B', 'C'];
    if (['D', 'E', 'F'].contains(upperTarget)) return ['D', 'E', 'F'];
    if (['G', 'H', 'I'].contains(upperTarget)) return ['G', 'H', 'I'];
    // Add more groups here later! (J,K,L etc.)
    return ['A', 'B', 'C'];
  }

  void _generateHuntField() {
    _activeObjects.clear();

    for (int i = 0; i < _winCondition; i++) {
      _activeObjects.add(_createHuntObject(widget.targetLetter.toUpperCase()));
    }

    List<String> distractors = _letterPool
        .where((l) => l != widget.targetLetter.toUpperCase())
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
    };
    final name = objectMap[letter.toUpperCase()] ?? 'apple';
    return 'assets/images/objects/forest/$name.png';
  }

  void _onObjectTap(HuntObject obj, GlobalKey key) async {
    RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Get the exact pixel position of the object they tapped
    Offset position = box.localToGlobal(Offset.zero);

    if (obj.letter == widget.targetLetter.toUpperCase()) {
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
      String audioFile =
          'audio/alphabet_forest/sound_effects/sound_${widget.targetLetter.toLowerCase()}.wav';
      await _audioPlayer.play(AssetSource(audioFile));

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

            String current = widget.targetLetter.toUpperCase();

            if (current == 'G') {
              // If they just finished G, send them to Level 8 (Match Game!)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlphabetMatchScreen(),
                ),
              );
            } else if (current == 'N') {
              // If they just finished N, send them to Level 16 (Fall Game!)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AlphabetFallScreen(startingLetter: 'H'),
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
                        AlphabetIntroScreen(startingLetter: nextLetter),
                  ),
                );
              } else {
                Navigator.pop(context); // Return to Map
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
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double objSize = (screenSize.height * 0.22).clamp(80.0, 150.0);
    final double letterFontSize = objSize * 0.55;

    return Scaffold(
      body: ForestBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // 1. TOP HEADER
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: screenSize.height * 0.02),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Find all the letters:",
                        style: TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: screenSize.height * 0.06,
                          color: Color.fromARGB(255, 71, 70, 70),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.targetLetter.toUpperCase(),
                        style: TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: screenSize.height * 0.12,
                          fontWeight: FontWeight.w900,
                          color: ForestColorTheme.seagreen,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        "$_correctCount / $_winCondition",
                        style: TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: screenSize.height * 0.05,
                          color: ForestColorTheme.darkseagreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: screenSize.height * 0.35,
                bottom: 0,
                left: 40,
                right: 40,
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

              const Positioned(top: 10, left: 10, child: ForestBackButton()),
            ],
          ),
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
