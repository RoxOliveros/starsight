import 'dart:async';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/animal_lifecycle_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/catching_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/clothes_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/cold_hot_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/feed_the_animal.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/habitant_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/listening_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/living_nonliving_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/lunchbox_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/perfume_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/pickup_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/rainbow_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/seed_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/soft_hard_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/tree_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/weather_game.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/audio_helper.dart';
import '../../business_layer/music_zones.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/discovery_lagoon/bodyparts_assembly.dart';
import '../../games_ui_layer/discovery_lagoon/season_scene_tap_screen.dart';
import '../../games_ui_layer/discovery_lagoon/weather_scene_builder_screen.dart';
import '../../games_ui_layer/discovery_lagoon/weather_tap_sort_screen.dart';
import '../../ui_layer/app_dialog.dart';
import '../loading_screen.dart';
import '../starsight_setup_dialog.dart';
import 'lagoon_theme.dart';

class LagoonLevelScreen extends StatefulWidget {
  const LagoonLevelScreen({super.key});

  @override
  State<LagoonLevelScreen> createState() => _LagoonLevelScreenState();
}

class _LagoonLevelScreenState extends State<LagoonLevelScreen>
    with MusicZoneMixin {
  int _currentPage = 0;
  final int _maxPages = 2;

  int _unlockedLevel = 5;
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
    _progressSub = LagoonProgressService.instance.streamUnlockedLevel().listen((
      level,
    ) async {
      if (!mounted) return;

      if (_isLoading) {
        final elapsed = DateTime.now().difference(_loadStart);
        final remaining = _minLoadingTime - elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
        if (!mounted) return;
      }

      final wasLoading = _isLoading;

      setState(() {
        _unlockedLevel = level;
        _isLoading = false;
      });

      if (wasLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          StarsightSetupTutorial.show(
            context,
            levelId: 'discovery_lagoon',
            forceShow: true,
            onDone: () {},
          );
        });
      }
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
      return Scaffold(body: LoadingScreen.discoveryLagoon());
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
                  if (level > 20) {
                    return SizedBox(width: tileSize, height: tileSize);
                  } else if (level <= _unlockedLevel) {
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
                            color: LagoonColorTheme.darkbrown,
                            width: 8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = _currentPage * 8 + i + 1;
                                return buildTile(level);
                              }),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = _currentPage * 8 + i + 5;
                                return buildTile(level);
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
                                color: LagoonColorTheme.ferngreen,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: LagoonColorTheme.gunmetalgreen,
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
                                  color: LagoonColorTheme.peach,
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
                            SfxHelper.instance.play(Sfx.keyTap);
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
                            SfxHelper.instance.play(Sfx.keyTap);
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
        ],
      ),
    );
  }
}

// String? _lagoonCalibratedSessionId;
//
// Future<void> _ensureLagoonCalibrated(BuildContext context) async {
//   final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';
//   if (_lagoonCalibratedSessionId == uid) return;
//   _lagoonCalibratedSessionId = uid;
//
//   await Navigator.push(
//     context,
//
//     PageRouteBuilder(
//       opaque: false,
//       pageBuilder: (context, animation, secondaryAnimation) =>
//           CalibrationScreen(
//             childSessionId: uid,
//             onCalibrationDone: () => Navigator.pop(context),
//           ),
//     ),
//   );
// }

class _LevelTile extends StatelessWidget {
  final int level;
  final double size;

  const _LevelTile({required this.level, required this.size});

  Widget? _screenForLevel() {
    switch (level) {
      case 1:
        return BodyPartsAssemblyScreen(level: 1);
      case 2:
        return TreeGameScreen(level: 2);
      case 3:
        return const RainbowGameScreen(level: 3);
      case 4:
        return const FeedTheAnimalGame(level: 4);
      case 5:
        return const HabitantGame(level: 5);
      case 6:
        return const SoftHardGameScreen(level: 6);
      case 7:
        return ColdHotGame(level: 7);
      case 8:
        return const LunchboxHealthyUnhealthyFoodsGameIntro(level: 8);
      case 9:
        return const CatchingDifferentTasteGameScreen(level: 9);
      case 10:
        return SeasonSceneTapScreen(level: 10);
      case 11:
        return const ClothesGame(level: 11);
      case 12:
        return WeatherTapSortScreen(level: 12);
      case 13:
        return const WeatherGame(level: 13);
      case 14:
        return WeatherSceneBuilderScreen(level: 14);
      case 15:
        return PickupSchoolGame(level: 15);
      case 16:
        return const ListeningAnimalGame(level: 16);
      case 17:
        return const PerfumeGame(level: 17);
      case 18:
        return const SeedGame(level: 18);
      case 19:
        return AnimalLifecycleGame(level: 19);
      case 20:
        return LivingNonLivingGame(level: 20);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        SfxHelper.instance.play(Sfx.keyTap);
        //await _ensureLagoonCalibrated(context);
        if (!context.mounted) return;
        final screen = _screenForLevel();
        if (screen == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: LagoonColorTheme.sagegreen,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: LagoonColorTheme.gunmetalgreen,
                width: 5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: size * 0.5,
                color: LagoonColorTheme.gunmetalgreen,
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
