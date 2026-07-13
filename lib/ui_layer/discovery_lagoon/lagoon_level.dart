import 'dart:async';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/bodyparts_intro.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/discovery_lagoon/animal_habitant_match.dart';
import '../../games_ui_layer/discovery_lagoon/bodyparts_assembly.dart';
import '../../games_ui_layer/discovery_lagoon/food_coloring.dart';
import '../../games_ui_layer/discovery_lagoon/season_object_match_screen.dart';
import '../../games_ui_layer/discovery_lagoon/season_scene_tap_screen.dart';
import '../../games_ui_layer/discovery_lagoon/treeparts_assembly.dart';
import '../../games_ui_layer/discovery_lagoon/weather_dress_up_screen.dart';
import '../../games_ui_layer/discovery_lagoon/weather_clothes_match.dart';
import '../../games_ui_layer/discovery_lagoon/weather_scene_builder_screen.dart';
import '../../games_ui_layer/discovery_lagoon/weather_tap_sort_screen.dart';
import '../loading_screen.dart';

abstract class ColorTheme {
  static const Color wasteland = Color(0xFF5F5630);
  static const Color pastelorange = Color(0xFFFBEACA);
  static const Color gunmetalgreen = Color(0xFF6B6A41);
  static const Color ferngreen = Color(0xFF82AD61);
  static const Color peach = Color(0xFFFBEBC6);
  static const Color darkbrown = Color(0xFF4E360D);
  static const Color sagegreen = Color(0xFF98BC62);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class LagoonLevelScreen extends StatefulWidget {
  const LagoonLevelScreen({super.key});

  @override
  State<LagoonLevelScreen> createState() => _LagoonLevelScreenState();
}

class _LagoonLevelScreenState extends State<LagoonLevelScreen> {
  // 0 is equal to levels 1-8
  // 1 is equal to levels 9-16
  // 2 is equal to levels 17-24
  int _currentPage = 0;
  final int _maxPages = 2; // Increase number when adding more pages!

  int _unlockedLevel = 1;
  bool _isLoading = true;
  StreamSubscription<int>? _progressSub;
  final DateTime _loadStart = DateTime.now();

  static const Duration _minLoadingTime = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _listenToProgress();
  }

  void _listenToProgress() {
    _progressSub = LagoonProgressService.instance
        .streamUnlockedLevel()
        .listen((level) async {
      if (!mounted) return;

      if (_isLoading) {
        // only enforce the minimum wait on the very first value
        final elapsed = DateTime.now().difference(_loadStart);
        final remaining = _minLoadingTime - elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
        if (!mounted) return;
      }

      setState(() {
        _unlockedLevel = level;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: LoadingScreen.discoveryLagoon(),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 🌳 Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_lagoon.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
          Positioned(top: 25, left: 20, child: LagoonBackButton()),

          // 🌿 Content
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                final screenH = constraints.maxHeight;

                final cardWidth = (screenW * 0.75).clamp(320.0, 700.0);
                final cardHeight = (screenH * 0.80).clamp(220.0, 320.0);
                final tileSize = (cardWidth / 4 - 24).clamp(48.0, 90.0);

                Widget buildTile(int level) {
                  if (level <= _unlockedLevel) {
                    return _LevelTile(level: level, size: tileSize);
                  } else {
                    return _LockedTile(size: tileSize);
                  }
                }

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
                          color: const Color(0xFFF4EFE6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ColorTheme.darkbrown,
                            width: 8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // --- PAGE 0: LEVELS 1-8 ---
                            if (_currentPage == 0) ...[
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildTile(1),
                                  buildTile(2),
                                  buildTile(3),
                                  buildTile(4),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildTile(5),
                                  buildTile(6),
                                  buildTile(7),
                                  buildTile(8),
                                ],
                              ),
                            ],

                            // --- PAGE 1: LEVELS 9-16 ---
                            if (_currentPage == 1) ...[
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildTile(9),
                                  buildTile(10),
                                  buildTile(11),
                                  buildTile(12),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildTile(13),
                                  buildTile(14),
                                  buildTile(15),
                                  buildTile(16),
                                ],
                              ),
                            ],

                            // --- PAGE 2: LEVELS 17-24 ---
                            if (_currentPage == 2) ...[
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildTile(17),
                                  buildTile(18),
                                  buildTile(19),
                                  buildTile(20),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildTile(21),
                                  buildTile(22),
                                  buildTile(23),
                                  buildTile(24),
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
                                color: ColorTheme.ferngreen,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: ColorTheme.gunmetalgreen,
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

                      Positioned(
                        left: -35,
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
                              'assets/images/arrows/bttn_lagoon_arrow_left.png',
                              width: 70,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        right: -35,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (_currentPage < _maxPages) {
                              setState(() => _currentPage++);
                            }
                          },
                          child: Opacity(
                            opacity: _currentPage < _maxPages ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_lagoon_arrow_right.png',
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
  final double size;

  const _LevelTile({required this.level, required this.size});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // --- THIS IS WHERE THE MAGIC HAPPENS ---
        switch (level) {
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'feet', level: level),
              ),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'knee', level: level),
              ),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'shoulder', level: level),
              ),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'head', level: level),
              ),
            );
            break;
          case 5:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'lips', level: level),
              ),
            );
            break;
          case 6:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'nose', level: level),
              ),
            );
            break;
          case 7:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'eye', level: level),
              ),
            );
            break;
          case 8:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'ear', level: level),
              ),
            );
            break;
          case 9:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'eyebrows', level: level),
              ),
            );
            break;
          case 10:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'hair', level: level),
              ),
            );
            break;
          case 11:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BodyPartsIntroScreen(bodyPart: 'hand', level: level),
              ),
            );
            break;
          case 12:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BodyPartsAssemblyScreen(level: 12),
              ),
            );
            break;
          case 13:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimalHabitatMatchScreen(level: 13),
              ),
            );
            break;
          case 14:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeasonSceneTapScreen(level: 14),
              ),
            );
            break;
          case 15:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeasonObjectMatchScreen(level: 15),
              ),
            );
            break;
          case 16:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeatherSceneBuilderScreen(level: 16),
              ),
            );
            break;
          case 17:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeatherClothesMatchScreen(level: 17),
              ),
            );
            break;
          case 18:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeatherDressUpScreen(level: 18),
              ),
            );
            break;
          case 19:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeatherTapSortScreen(level: 19),
              ),
            );
            break;
          case 20:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TreePartsAssemblyScreen(level: 20),
              ),
            );
            break;
          case 21:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodColoringScreen(level: 21),
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
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: ColorTheme.sagegreen,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ColorTheme.gunmetalgreen, width: 5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: size * 0.5,
                color: ColorTheme.gunmetalgreen,
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