import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../business_layer/puzzle_progress_service.dart';
import '../../games_ui_layer/puzzle_glade/lvl10_memory_match2.dart';
import '../../games_ui_layer/puzzle_glade/lvl11_shadow_match2.dart';
import '../../games_ui_layer/puzzle_glade/lvl12_jigsaw_puzzle2.dart';
import '../../games_ui_layer/puzzle_glade/lvl13_basket_sort2.dart';
import '../../games_ui_layer/puzzle_glade/lvl14_size_sort2.dart';
import '../../games_ui_layer/puzzle_glade/lvl15_whats_missing2.dart';
import '../../games_ui_layer/puzzle_glade/lvl16_copy_the_pattern.dart';
import '../../games_ui_layer/puzzle_glade/lvl17_spot_the_difference.dart';
import '../../games_ui_layer/puzzle_glade/lvl18_star_color_sort2.dart';
import '../../games_ui_layer/puzzle_glade/lvl19_memory_match3.dart';
import '../../games_ui_layer/puzzle_glade/lvl1_star_color_sort.dart';
import '../../games_ui_layer/puzzle_glade/lvl20_copy_the_pattern2.dart';
import '../../games_ui_layer/puzzle_glade/lvl2_pattern_match.dart';
import '../../games_ui_layer/puzzle_glade/lvl3_memory_match.dart';
import '../../games_ui_layer/puzzle_glade/lvl4_shadow_match.dart';
import '../../games_ui_layer/puzzle_glade/lvl5_jigsaw_puzzle.dart';
import '../../games_ui_layer/puzzle_glade/lvl6_basket_sort.dart';
import '../../games_ui_layer/puzzle_glade/lvl7_size_sort.dart';
import '../../games_ui_layer/puzzle_glade/lvl8_whats_missing.dart';
import '../../games_ui_layer/puzzle_glade/lvl9_pattern_match2.dart';
import '../loading_screen.dart';
import 'puzzle_buttons.dart';
import 'Puzzle_theme.dart';

class PuzzleLevelScreen extends StatefulWidget {
  const PuzzleLevelScreen({super.key});

  @override
  State<PuzzleLevelScreen> createState() => _PuzzleLevelScreenState();
}

class _PuzzleLevelScreenState extends State<PuzzleLevelScreen> {
  int _page = 0;
  int _unlockedLevel = 1;
  bool _isLoadingProgress = true;
  final DateTime _loadStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _loadInitialProgress();
  }

  Future<void> _loadInitialProgress() async {
    final unlocked = await PuzzleProgressService.instance.getUnlockedLevel();

    final elapsed = DateTime.now().difference(_loadStart);
    //Loading time
    final remaining = const Duration(milliseconds: 1500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    setState(() {
      _unlockedLevel = unlocked;
      _isLoadingProgress = false;
    });
  }

  Future<void> _refreshProgress() async {
    final unlocked = await PuzzleProgressService.instance.getUnlockedLevel();
    if (!mounted) return;
    setState(() => _unlockedLevel = unlocked);
  }

  Future<void> _openLevel(Widget screen) async {
    final nextScreen = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (!mounted) return;

    await _refreshProgress();

    if (nextScreen is Widget) {
      _openLevel(nextScreen);
    }
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProgress) {
      return Scaffold(
        body: LoadingScreen.puzzleGlade(),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 🌳 Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_puzzle.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
          Positioned(top: 25, left: 25, child: PuzzleBackButton()),

          // 🌿 Content
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                final screenH = constraints.maxHeight;

                final cardWidth = (screenW * 0.75).clamp(320.0, 700.0);
                final cardHeight = (screenH * 0.80).clamp(220.0, 320.0);
                final tileSize = (cardWidth / 4 - 24).clamp(48.0, 90.0);

                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: cardWidth,
                        height: cardHeight,
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                        decoration: BoxDecoration(
                          color: JarColorTheme.vandecane,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: JarColorTheme.darkbrown,
                            width: 8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = _page * 8 + i + 1;
                                return _LevelTile(
                                  level: level,
                                  unlockedLevel: _unlockedLevel,
                                  onOpenLevel: _openLevel,
                                  size: tileSize,
                                );
                              }),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = _page * 8 + i + 5;
                                return _LevelTile(
                                  level: level,
                                  unlockedLevel: _unlockedLevel,
                                  onOpenLevel: _openLevel,
                                  size: tileSize,
                                );
                              }),
                            ),
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
                                color: JarColorTheme.darkdesaturatedblue,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: JarColorTheme.verydarkdesaturatedblue,
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
                                  fontFamily: JarAppTextStyles.fredoka,
                                  fontSize: 25,
                                  color: JarColorTheme.peach,
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
                      // Left arrow
                      Positioned(
                        left: -35,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (_page > 0) {
                              setState(() => _page--);
                            }
                          },
                          child: Opacity(
                            opacity: _page > 0 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_jar_arrow_left.png',
                              width: 70,
                            ),
                          ),
                        ),
                      ),
                      // Right arrow
                      Positioned(
                        right: -35,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (_page < 2) {
                              setState(() => _page++);
                            }
                          },
                          child: Opacity(
                            opacity: _page < 2 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_jar_arrow_right.png',
                              width: 70,
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
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final int unlockedLevel;
  final double size;
  final Future<void> Function(Widget screen) onOpenLevel;

  const _LevelTile({
    required this.level,
    required this.unlockedLevel,
    required this.onOpenLevel,
    required this.size,
  });

  Widget? _screenForLevel() {
    switch (level) {
      case 1:
        return const Lvl1JarColorSortScreen();
      case 2:
        return const Lvl2PatternMatchScreen();
      case 3:
        return const Lvl3JarMemoryMatchScreen();
      case 4:
        return const Lvl4ShadowMatchScreen();
      case 5:
        return const Lvl5JigsawPuzzleScreen();
      case 6:
        return const Lvl6BasketSortScreen();
      case 7:
        return const Lvl7SizeSortScreen();
      case 8:
        return const Lvl8WhatsMissingScreen();
      case 9:
        return const Lvl9PatternMatch2Screen();
      case 10:
        return const Lvl10JarMemoryMatch2Screen();
      case 11:
        return const Lvl11ShadowMatch2Screen();
      case 12:
        return const Lvl12JigsawPuzzle2Screen();
      case 13:
        return const Lvl13BasketSort2Screen();
      case 14:
        return const Lvl14SizeSort2Screen();
      case 15:
        return const Lvl15WhatsMissing2Screen();
      case 16:
        return const Lvl16CopyPatternScreen();
      case 17:
        return const Lvl17SpotDifferenceScreen();
      case 18:
        return const Lvl18JarColorSort2Screen();
      case 19:
        return const Lvl19JarMemoryMatch3Screen();
      case 20:
        return const Lvl20CopyPattern2Screen();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (level > 20) {
      return SizedBox(width: size, height: size);
    }
    final bool isLocked = level > unlockedLevel;
    if (isLocked) {
      return _LockedTile(size: size);
    }

    return GestureDetector(
      onTap: () {
        final screen = _screenForLevel();
        if (screen == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
          return;
        }
        onOpenLevel(screen);
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: JarColorTheme.goldenyellow,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: JarColorTheme.darkdesaturatedblue,
                width: 5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: JarAppTextStyles.fredoka,
                fontSize: size * 0.5,
                color: JarColorTheme.darkdesaturatedblue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
