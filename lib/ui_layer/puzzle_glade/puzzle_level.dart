import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/puzzle_glade/lvl1_star_color_sort.dart';
import '../../games_ui_layer/puzzle_glade/lvl2_pattern_match.dart';
import '../../games_ui_layer/puzzle_glade/lvl3_memory_match.dart';
import '../../games_ui_layer/puzzle_glade/lvl4_shadow_match.dart';
import '../../games_ui_layer/puzzle_glade/lvl5_jigsaw_puzzle.dart';
import '../../games_ui_layer/puzzle_glade/lvl6_basket_sort.dart';
import '../../games_ui_layer/puzzle_glade/lvl7_size_sort.dart';
import '../../games_ui_layer/puzzle_glade/lvl8_whats_missing.dart';
import 'puzzle_buttons.dart';
import 'Puzzle_theme.dart';

class PuzzleLevelScreen extends StatefulWidget {
  const PuzzleLevelScreen({super.key});

  @override
  State<PuzzleLevelScreen> createState() => _PuzzleLevelScreenState();
}

class _PuzzleLevelScreenState extends State<PuzzleLevelScreen> {
  int _page = 0;

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
              'assets/images/backgrounds/bg_puzzle.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
          Positioned(top: 25, left: 25, child: PuzzleBackButton()),

          // 🌿 Content
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  SizedBox(height: 20),
                  Container(
                    width: 650,
                    height: 280,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (i) {
                            final level = _page * 8 + i + 1;

                            if (level <= 7) {
                              return _LevelTile(level: level);
                            }

                            return const _LockedTile();
                          }),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (i) {
                            final level = _page * 8 + i + 5;

                            if (level <= 7) {
                              return _LevelTile(level: level);
                            }

                            return const _LockedTile();
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
                        if (_page < 1) {
                          setState(() => _page++);
                        }
                      },
                      child: Opacity(
                        opacity: _page < 1 ? 1.0 : 0.3,
                        child: Image.asset(
                          'assets/images/arrows/bttn_jar_arrow_right.png',
                          width: 70,
                        ),
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
                builder: (context) => const Lvl1JarColorSortScreen(),
              ),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Lvl2PatternMatchScreen(),
              ),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Lvl3JarMemoryMatchScreen(),
              ),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Lvl4ShadowMatchScreen(),
              ),
            );
            break;
          case 5:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Lvl5JigsawPuzzleScreen(),
              ),
            );
            break;
          case 6:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Lvl6BasketSortScreen(),
              ),
            );
            break;
          case 7:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Lvl7SizeSortScreen(),
              ),
            );
            break;
          case 8:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Lvl8WhatsMissingScreen(),
              ),
            );
            break;
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 80,
            height: 80,
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
              style: const TextStyle(
                fontFamily: JarAppTextStyles.fredoka,
                fontSize: 40,
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
              'assets/images/lock.png',
              width: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
