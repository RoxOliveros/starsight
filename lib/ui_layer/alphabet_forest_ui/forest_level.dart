import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_fall.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_match.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_memory_match.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_puzzle.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_trace.dart';
import 'package:lottie/lottie.dart';

abstract class ColorTheme {
  static const Color darkbrown = Color(0xFF4E360D);
  static const Color darkgreen = Color(0xFF3C5729);
  static const Color olivegreen = Color(0xFF5D6F2F);
  static const Color forestgreen = Color(0xFF9DA92A);
  static const Color flaxengold = Color(0xFFCAB781);
  static const Color peach = Color(0xFFFBEBC6);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class ForestLevelScreen extends StatefulWidget {
  const ForestLevelScreen({super.key});

  @override
  State<ForestLevelScreen> createState() => _ForestLevelScreenState();
}

class _ForestLevelScreenState extends State<ForestLevelScreen> {
  // 0 is equal to levels 1-8
  // 1 is equal to levels 9-16
  // 2 is equal to levels 17-24
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌳 Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_forest.png',
              fit: BoxFit.cover,
            ),
          ),

          // back button
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ColorTheme.flaxengold,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: ColorTheme.olivegreen, width: 5),
                ),
                child: const Text(
                  'back',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 18,
                    color: ColorTheme.olivegreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // 🌿 Content
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 650,
                    height: 280,
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4EFE6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ColorTheme.darkbrown, width: 8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- PAGE 0: LEVELS 1-8 ---
                        if (_currentPage == 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              _LevelTile(level: 1),
                              _LevelTile(level: 2),
                              _LevelTile(level: 3),
                              _LevelTile(level: 4),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              _LevelTile(level: 5),
                              _LevelTile(level: 6),
                              _LevelTile(level: 7),
                              _LevelTile(level: 8),
                            ],
                          ),
                        ],

                        // --- PAGE 1: LEVELS 9-16 ---
                        if (_currentPage == 1) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              _LevelTile(level: 9),
                              _LevelTile(level: 10),
                              _LevelTile(level: 11),
                              _LevelTile(level: 12),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              _LevelTile(level: 13),
                              _LevelTile(level: 14),
                              _LevelTile(level: 15),
                              _LevelTile(level: 16),
                            ],
                          ),
                        ],
                        // --- PAGE 2: LEVELS 17-24 ---
                        if (_currentPage == 2) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              _LevelTile(level: 17),
                              _LevelTile(level: 18),
                              _LevelTile(level: 19),
                              _LevelTile(level: 20),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              _LockedTile(), // Level 21 (locked)
                              _LockedTile(), // Level 22 (locked)
                              _LockedTile(), // Level 23 (locked)
                              _LockedTile(), // Level 24 (locked)
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // SELECT LEVEL badge on top border
                  Positioned(
                    top: -32,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ColorTheme.forestgreen,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: ColorTheme.darkgreen,
                              width: 5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                offset: const Offset(0, 6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Text(
                            ' SELECT LEVEL ',
                            style: TextStyle(
                              fontFamily: AppTextStyles.fredoka,
                              fontSize: 25,
                              color: ColorTheme.peach,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        // Left star
                        Positioned(
                          top: -4,
                          left: -35,
                          child: Transform.rotate(
                            angle: -0.2,
                            child: Image.asset(
                              'assets/images/night_star.png',
                              width: 70,
                            ),
                          ),
                        ),
                        // Right star
                        Positioned(
                          top: -4,
                          right: -35,
                          child: Transform.rotate(
                            angle: 0.2,
                            child: Image.asset(
                              'assets/images/night_star.png',
                              width: 70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_currentPage >
                      0) // Only shows if it passes the first page
                    Positioned(
                      left: -35,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentPage--;
                          });
                        },
                        child: Image.asset(
                          'assets/images/arrows/bttn_forest_arrow_left.png',
                          width: 70,
                        ),
                      ),
                    ),

                  if (_currentPage < 2) // Hides when hit the final page
                    Positioned(
                      right: -35,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentPage++;
                          });
                        },
                        child: Image.asset(
                          'assets/images/arrows/bttn_forest_arrow_right.png',
                          width: 70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Lottie.asset(
                'assets/animations/movie_clapperboard.json',
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;

  const _LevelTile({required this.level});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        switch (level) {
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'A'),
              ),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'A'),
              ),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'B'),
              ),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'B'),
              ),
            );
            break;
          case 5:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'C'),
              ),
            );
            break;
          case 6:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'C'),
              ),
            );
            break;
          case 7:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'D'),
              ),
            );
            break;
          case 8:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'D'),
              ),
            );
            break;
          case 9:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'E'),
              ),
            );
            break;
          case 10:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'E'),
              ),
            );
            break;
          case 11:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'F'),
              ),
            );
            break;
          case 12:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'F'),
              ),
            );
            break;
          case 13:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'G'),
              ),
            );
            break;
          case 14:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'G'),
              ),
            );
            break;
          case 15:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'H'),
              ),
            );
            break;
          case 16:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'H'),
              ),
            );
            break;
          case 17:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'I'),
              ),
            );
            break;
          case 18:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'I'),
              ),
            );
            break;
          case 19:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetIntroScreen(startingLetter: 'J'),
              ),
            );
            break;
          case 20:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const AlphabetPuzzleScreen(startingLetter: 'J'),
              ),
            );
            break;
          // This stops the app from crashing
          default:
            print("Level $level is not linked up yet!");
            break;
        }
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: ColorTheme.forestgreen,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: ColorTheme.darkgreen, width: 5),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level',
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 40,
            color: ColorTheme.darkgreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  const _LockedTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 79,
      height: 79,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(17),
        color: Colors.grey.shade400,
        strokeWidth: 5,
        dashPattern: const [6, 3],
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Center(
            child: Image.asset(
              'assets/images/icons/lock.png',
              width: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
