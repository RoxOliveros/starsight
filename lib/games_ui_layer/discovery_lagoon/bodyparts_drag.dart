import 'dart:math' as math;
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/bodyparts_intro.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_background.dart';
import 'package:flutter/material.dart';

// --- DISCOVERY LAGOON THEME ---
abstract class LagoonTheme {
  static const Color wasteland = Color(0xFF5F5630);
  static const Color pastelorange = Color(0xFFFBEACA);
  static const Color gunmetalgreen = Color(0xFF6B6A41);
  static const Color ferngreen = Color(0xFF82AD61);
  static const Color peach = Color(0xFFFBEBC6);
  static const Color darkbrown = Color(0xFF4E360D);
  static const Color sagegreen = Color(0xFF98BC62);

  static const List<Color> canvaColors = [
    Color(0xFF6FD3E3),
    Color(0xFFEC8A20),
    Color(0xFFFBD354),
  ];
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

// --- DATA MODEL FOR BODY PARTS ---
class BodyPart {
  final String word;
  final String imagePath;

  BodyPart({required this.word, required this.imagePath});
}

// --- LEVEL -> BODY PART LOOKUP ---
// Mirrors the routing table in LagoonLevelScreen's _LevelTile.
// Odd levels are always Intro screens, so this only needs to map
// the odd "next level" numbers to their body part identifier.
const Map<int, String> _introBodyPartForLevel = {
  1: 'feet',
  3: 'knee',
  5: 'shoulder',
  7: 'head',
  9: 'lips',
  11: 'nose',
  13: 'eye',
  15: 'ear',
  17: 'eyebrows',
  19: 'hair',
  21: 'hand',
};

class BodyPartsDragScreen extends StatefulWidget {
  final String bodyPart;
  final int level;

  const BodyPartsDragScreen({
    super.key,
    required this.bodyPart,
    required this.level,
  });

  @override
  State<BodyPartsDragScreen> createState() => _BodyPartsDragScreenState();
}

class _BodyPartsDragScreenState extends State<BodyPartsDragScreen>
    with SingleTickerProviderStateMixin {
  late BodyPart _currentPart;
  late final AnimationController _floatingController;

  List<bool> _filledTargets = [];
  List<bool> _usedDraggables = [];
  List<int> _shuffledDraggableIndices = [];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Set up the exact part based on what was passed to the screen
    _setupBodyPart();
    _initLevel();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _setupBodyPart() {
    switch (widget.bodyPart.toLowerCase()) {
      case 'feet':
        _currentPart = BodyPart(
          word: 'Paa',
          imagePath: 'assets/images/objects/forest/feet.png',
        );
        break;
      case 'knee':
        _currentPart = BodyPart(
          word: 'Tuhod',
          imagePath: 'assets/images/objects/lagoon/knee.png',
        );
        break;
      case 'shoulder':
        _currentPart = BodyPart(
          word: 'Balikat',
          imagePath: 'assets/images/objects/lagoon/shoulder.png',
        );
        break;
      case 'head':
        _currentPart = BodyPart(
          word: 'Ulo',
          imagePath: 'assets/images/objects/lagoon/head.png',
        );
        break;
      case 'lips':
        _currentPart = BodyPart(
          word: 'Labi',
          imagePath: 'assets/images/objects/lagoon/lips.png',
        );
        break;
      case 'nose':
        _currentPart = BodyPart(
          word: 'Ilong',
          imagePath: 'assets/images/objects/lagoon/nose.png',
        );
        break;
      case 'eye':
        _currentPart = BodyPart(
          word: 'Mata',
          imagePath: 'assets/images/objects/lagoon/eye.png',
        );
        break;
      case 'ear':
        _currentPart = BodyPart(
          word: 'tenga',
          imagePath: 'assets/images/objects/lagoon/ear.png',
        );
        break;
      case 'eyebrows':
        _currentPart = BodyPart(
          word: 'Kilay',
          imagePath: 'assets/images/objects/lagoon/eyebrows.png',
        );
        break;
      case 'hair':
        _currentPart = BodyPart(
          word: 'Buhok',
          imagePath: 'assets/images/objects/lagoon/hair.png',
        );
        break;
      case 'hand':
        _currentPart = BodyPart(
          word: 'Kamay',
          imagePath: 'assets/images/icons/hand.png',
        );
        break;
    }
  }

  void _initLevel() {
    int wordLength = _currentPart.word.length;
    _filledTargets = List.filled(wordLength, false);
    _usedDraggables = List.filled(wordLength, false);
    _shuffledDraggableIndices = List.generate(wordLength, (i) => i)..shuffle();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Color _getLetterColor(int index) {
    return LagoonTheme.canvaColors[index % LagoonTheme.canvaColors.length];
  }

  // --- 3. THE GOOD JOB OVERLAY ---
  void _showSuccessDialog() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (context) => GoodJobOverlay(
        characterImage: 'assets/images/characters/cat_holding_fishbone.png',
        closeButtonColor: LagoonTheme.wasteland,
        onNext: () {
          Navigator.pop(context); // Close the overlay
          _goToNextLevel();
        },
        onRestart: () {
          Navigator.pop(context); // Close the overlay
          setState(() {
            _initLevel(); // Resets the floating letters to try again!
          });
        },
        onBack: () {
          Navigator.pop(context); // Close the overlay
          Navigator.pop(context); // Exit the game back to the map
        },
      ),
    );
  }

  void _goToNextLevel() {
    final int nextLevel = widget.level + 1;
    final String? nextBodyPart = _introBodyPartForLevel[nextLevel];

    if (nextBodyPart == null) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BodyPartsIntroScreen(bodyPart: nextBodyPart, level: nextLevel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String targetWord = _currentPart.word.toUpperCase();
    final Size screenSize = MediaQuery.of(context).size;

    final double imageSize = screenSize.height * 0.25;
    final double maxBoxWidth = (screenSize.width - 48) / targetWord.length - 8;
    final double letterBoxSize = math
        .min(maxBoxWidth, screenSize.height * 0.18)
        .clamp(35.0, 70.0);
    final double letterFontSize = letterBoxSize * 0.6;

    return Scaffold(
      body: LagoonBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),

              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: LagoonTheme.wasteland,
                          size: 32,
                        ),
                        onPressed: () =>
                            Navigator.pop(context), // Safely exit back to map
                      ),
                    ),
                    const Text(
                      'Body Parts',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: LagoonTheme.wasteland,
                      ),
                    ),
                  ],
                ),
              ),

              // --- GAME AREA ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 1. THE IMAGE TO IDENTIFY
                      Container(
                        height: imageSize,
                        width: imageSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: LagoonTheme.gunmetalgreen,
                            width: 6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.asset(
                            _currentPart.imagePath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      SizedBox(height: screenSize.height * 0.05),

                      // 2. THE TARGET BOXES (WITH GHOST LETTERS!)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(targetWord.length, (
                          targetIndex,
                        ) {
                          String expectedLetter = targetWord[targetIndex];
                          Color letterColor = _getLetterColor(targetIndex);

                          return DragTarget<int>(
                            onWillAcceptWithDetails: (details) {
                              int draggedIndex = details.data;
                              String draggedLetter = targetWord[draggedIndex];
                              return draggedLetter == expectedLetter &&
                                  !_filledTargets[targetIndex];
                            },
                            onAcceptWithDetails: (details) {
                              setState(() {
                                _filledTargets[targetIndex] = true;
                                _usedDraggables[details.data] = true;
                              });

                              if (_filledTargets.every(
                                (isFilled) => isFilled,
                              )) {
                                Future.delayed(
                                  const Duration(milliseconds: 400),
                                  _showSuccessDialog,
                                );
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              bool isHovering = candidateData.isNotEmpty;

                              return Container(
                                width: letterBoxSize,
                                height: letterBoxSize,
                                decoration: BoxDecoration(
                                  color: isHovering
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : LagoonTheme.pastelorange,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _filledTargets[targetIndex]
                                        ? letterColor
                                        : LagoonTheme.darkbrown.withValues(
                                            alpha: 0.2,
                                          ),
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: _filledTargets[targetIndex]
                                      ? _LetterWidget(
                                          letter: expectedLetter,
                                          color: letterColor,
                                          fontSize: letterFontSize,
                                        )
                                      : _LetterWidget(
                                          letter: expectedLetter,
                                          color: letterColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          fontSize: letterFontSize,
                                        ),
                                ),
                              );
                            },
                          );
                        }),
                      ),

                      SizedBox(height: screenSize.height * 0.05),

                      // 3. THE FLOATING DRAGGABLE LETTERS
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: _shuffledDraggableIndices.map((dragIndex) {
                          if (_usedDraggables[dragIndex]) {
                            return SizedBox(
                              width: letterBoxSize,
                              height: letterBoxSize,
                            );
                          }

                          String letterStr = targetWord[dragIndex];
                          Color letterColor = _getLetterColor(dragIndex);

                          return AnimatedBuilder(
                            animation: _floatingController,
                            builder: (context, child) {
                              final double floatOffset =
                                  math.sin(
                                    _floatingController.value * 2 * math.pi +
                                        dragIndex,
                                  ) *
                                  8;
                              return Transform.translate(
                                offset: Offset(0, floatOffset),
                                child: child,
                              );
                            },
                            child: Draggable<int>(
                              data: dragIndex,
                              feedback: _LetterWidget(
                                letter: letterStr,
                                color: letterColor,
                                fontSize: letterFontSize * 1.2,
                                isDragging: true,
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.0,
                                child: Container(
                                  width: letterBoxSize,
                                  height: letterBoxSize,
                                ),
                              ),
                              child: Container(
                                width: letterBoxSize,
                                height: letterBoxSize,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: letterColor,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _LetterWidget(
                                    letter: letterStr,
                                    color: letterColor,
                                    fontSize: letterFontSize,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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

class _LetterWidget extends StatelessWidget {
  final String letter;
  final Color color;
  final bool isDragging;
  final double fontSize;

  const _LetterWidget({
    required this.letter,
    required this.color,
    required this.fontSize,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: AppTextStyles.fredoka,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          height: 1.0,
          shadows: [
            if (isDragging)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 10),
              ),
          ],
        ),
      ),
    );
  }
}
