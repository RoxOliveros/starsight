import 'dart:async';

import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_fall.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_match.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
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
  int _currentPage = 0;
  int _unlockedLevel = 1;
  bool _isLoadingProgress = true;
  StreamSubscription<int>? _progressSub;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _listenToProgress();
  }

  void _listenToProgress() {
    _progressSub = ForestProgressService.instance.streamUnlockedLevel().listen((
      level,
    ) {
      if (!mounted) return;
      setState(() {
        _unlockedLevel = level;
        _isLoadingProgress = false;
      });
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _openLevel(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  List<Widget> _buildLevelRows(double tileSize) {
    final pages = [
      [1, 2, 3, 4, 5, 6, 7, 8],
      [9, 10, 11, 12, 13, 14, 15, 16],
      [17, 18, 19, 20, 21, 22, 23, 24],
    ];
    final levels = pages[_currentPage];

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: levels
            .sublist(0, 4)
            .map(
              (lvl) => _LevelTile(
                level: lvl,
                unlockedLevel: _unlockedLevel,
                onOpenLevel: _openLevel,
                size: tileSize,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: levels
            .sublist(4, 8)
            .map(
              (lvl) => _LevelTile(
                level: lvl,
                unlockedLevel: _unlockedLevel,
                onOpenLevel: _openLevel,
                size: tileSize,
              ),
            )
            .toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_forest.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 20, left: 20, child: ForestBackButton()),

          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = MediaQuery.of(context).size.width;
                final screenH = MediaQuery.of(context).size.height;

                final cardWidth = (screenW * 0.75).clamp(320.0, 700.0);
                final cardHeight = (screenH * 0.80).clamp(220.0, 320.0);
                final tileSize = (cardWidth / 4 - 24).clamp(48.0, 90.0);
                final arrowSize = (tileSize * 0.85).clamp(40.0, 70.0);

                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: cardWidth,
                        height: cardHeight,
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _buildLevelRows(tileSize),
                        ),
                      ),

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

                      Positioned(
                        left: -arrowSize * 0.5,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (_currentPage > 0) {
                              setState(() => _currentPage--);
                            }
                          },
                          child: Opacity(
                            opacity: _currentPage > 0 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_forest_arrow_left.png',
                              width: arrowSize,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        right: -arrowSize * 0.5,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (_currentPage < 2) {
                              setState(() => _currentPage++);
                            }
                          },
                          child: Opacity(
                            opacity: _currentPage < 2 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_forest_arrow_right.png',
                              width: arrowSize,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Positioned(
          //   bottom: 15,
          //   right: 15,
          //   child: Lottie.asset(
          //     'assets/animations/movie_clapperboard.json',
          //     width: 60,
          //     height: 60,
          //     errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          //   ),
          // ),

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
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final int unlockedLevel;
  final Future<void> Function(Widget screen) onOpenLevel;
  final double size;

  const _LevelTile({
    required this.level,
    required this.unlockedLevel,
    required this.onOpenLevel,
    required this.size,
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
      return _LockedTile(size: size);
    }

    return GestureDetector(
      onTap: () {
        final screen = _screenForLevel();
        if (screen == null) {
          debugPrint("Level $level is not linked up yet!");
          return;
        }
        onOpenLevel(screen);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ColorTheme.forestgreen,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: ColorTheme.darkgreen, width: 5),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level',
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: size * 0.5,
            color: ColorTheme.darkgreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  final double size;

  const _LockedTile({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size - 1,
      height: size - 1,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(17),
        color: Colors.grey.shade400,
        strokeWidth: 5,
        dashPattern: const [6, 3],
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Center(
            child: Image.asset(
              'assets/images/icons/lock.png',
              width: size * 0.5,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
