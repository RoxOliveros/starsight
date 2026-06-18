import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_fall.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_match.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
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

  int _unlockedLevel = 1;
  bool _isLoadingProgress = true;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
  }

  Future<void> _openLevel(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<int>(
        stream: ForestProgressService.instance.streamUnlockedLevel(),
        builder: (context, snapshot) {
          // Default to level 1 if data hasn't loaded yet
          final _unlockedLevel = snapshot.data ?? 1;

          // Show the loading screen while Firebase is connecting
          final _isLoadingProgress =
              snapshot.connectionState == ConnectionState.waiting;

          return Stack(
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
                      border: Border.all(
                        color: ColorTheme.olivegreen,
                        width: 5,
                      ),
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
                          border: Border.all(
                            color: ColorTheme.darkbrown,
                            width: 8,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- PAGE 0: LEVELS 1-8 ---
                            if (_currentPage == 0) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _LevelTile(
                                    level: 1,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 2,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 3,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 4,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _LevelTile(
                                    level: 5,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 6,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 7,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 8,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                ],
                              ),
                            ],

                            // --- PAGE 1: LEVELS 9-16 ---
                            if (_currentPage == 1) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _LevelTile(
                                    level: 9,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 10,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 11,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 12,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _LevelTile(
                                    level: 13,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 14,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 15,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 16,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                ],
                              ),
                            ],
                            // --- PAGE 2: LEVELS 17-24 ---
                            if (_currentPage == 2) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _LevelTile(
                                    level: 17,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 18,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 19,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 20,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _LevelTile(
                                    level: 21,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 22,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 23,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
                                  _LevelTile(
                                    level: 24,
                                    unlockedLevel: _unlockedLevel,
                                    onOpenLevel: _openLevel,
                                  ),
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
                bottom: 15,
                right: 15,
                child: Lottie.asset(
                  'assets/animations/movie_clapperboard.json',
                  width: 60,
                  height: 60,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

              if (_isLoadingProgress)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: ColorTheme.flaxengold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final int unlockedLevel;
  final Future<void> Function(Widget screen) onOpenLevel;

  const _LevelTile({
    required this.level,
    required this.unlockedLevel,
    required this.onOpenLevel,
  });

  Widget? _screenForLevel() {
    switch (level) {
      case 1:
        return const AlphabetIntroScreen(startingLetter: 'A');
      case 2:
        return const AlphabetIntroScreen(startingLetter: 'B');
      case 3:
        return const AlphabetIntroScreen(startingLetter: 'C');
      case 4:
        return const AlphabetIntroScreen(startingLetter: 'D');
      case 5:
        return const AlphabetIntroScreen(startingLetter: 'E');
      case 6:
        return const AlphabetIntroScreen(startingLetter: 'F');
      case 7:
        return const AlphabetIntroScreen(startingLetter: 'G');
      case 8:
        return const AlphabetMatchScreen();
      case 9:
        return const AlphabetIntroScreen(startingLetter: 'H');
      case 10:
        return const AlphabetIntroScreen(startingLetter: 'I');
      case 11:
        return const AlphabetIntroScreen(startingLetter: 'J');
      case 12:
        return const AlphabetIntroScreen(startingLetter: 'K');
      case 13:
        return const AlphabetIntroScreen(startingLetter: 'L');
      case 14:
        return const AlphabetIntroScreen(startingLetter: 'M');
      case 15:
        return const AlphabetIntroScreen(startingLetter: 'N');
      case 16:
        return const AlphabetFallScreen();
      case 17:
        return const AlphabetIntroScreen(startingLetter: 'O');
      case 18:
        return const AlphabetIntroScreen(startingLetter: 'P');
      case 19:
        return const AlphabetIntroScreen(startingLetter: 'Q');
      case 20:
        return const AlphabetIntroScreen(startingLetter: 'R');
      case 21:
        return const AlphabetIntroScreen(startingLetter: 'S');
      case 22:
        return const AlphabetIntroScreen(startingLetter: 'T');
      case 23:
        return const AlphabetIntroScreen(startingLetter: 'U');
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocked = level > unlockedLevel;

    if (isLocked) {
      return const _LockedTile();
    }

    return GestureDetector(
      onTap: () {
        final screen = _screenForLevel();
        if (screen == null) {
          print("Level $level is not linked up yet!");
          return;
        }
        onOpenLevel(screen);
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
