import 'dart:async';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl5/sharing_1.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_stars_screen.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl7/lumi_classroom_screen.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl8/prayer_1.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_1.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/lumi_town/1/wakeup1.dart';
import '../../games_ui_layer/lumi_town/lvl2/bathroom_game_screen.dart';
import '../../games_ui_layer/lumi_town/lvl3/clean_bedroom_game_screen.dart';
import '../../games_ui_layer/lumi_town/lvl4_cooking/game_screen.dart';
import '../loading_screen.dart';
import 'lumi_buttons.dart';
import 'lumi_theme.dart';

class LumiLevelScreen extends StatefulWidget {
  const LumiLevelScreen({super.key});

  @override
  State<LumiLevelScreen> createState() => _LumiLevelScreenState();
}

class _LumiLevelScreenState extends State<LumiLevelScreen> {
  int _unlockedLevel = 1;
  bool _isLoadingProgress = true;
  StreamSubscription<int>? _progressSub;
  final DateTime _loadStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _listenToProgress();
  }

  void _listenToProgress() {
    _progressSub = TownProgressService.instance.streamUnlockedLevel().listen((
      level,
    ) async {
      if (!mounted) return;

      if (_isLoadingProgress) {
        final elapsed = DateTime.now().difference(_loadStart);
        //Loading time
        final remaining = const Duration(milliseconds: 1500) - elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
        if (!mounted) return;
      }

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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProgress) {
      return Scaffold(body: LoadingScreen.lumiTown());
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_town.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 25, left: 20, child: LumiBackButton()),

          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = MediaQuery.of(context).size.width;
                final screenH = MediaQuery.of(context).size.height;

                final cardWidth = (screenW * 0.75).clamp(320.0, 700.0);
                final cardHeight = (screenH * 0.80).clamp(220.0, 320.0);
                final tileSize = (cardWidth / 4 - 24).clamp(48.0, 90.0);

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
                            color: LumiColorTheme.darkbrown,
                            width: 8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = i + 1;
                                return level <= _unlockedLevel
                                    ? _LevelTile(level: level, size: tileSize)
                                    : _LockedTile(size: tileSize);
                              }),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = i + 5;
                                return level <= _unlockedLevel
                                    ? _LevelTile(level: level, size: tileSize)
                                    : _LockedTile(size: tileSize);
                              }),
                            ),
                          ],
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
                                color: LumiColorTheme.rust,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: LumiColorTheme.darkbrown,
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
                                  fontFamily: LumiAppTextStyles.fredoka,
                                  fontSize: 25,
                                  color: LumiColorTheme.peach,
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
                  child: CircularProgressIndicator(color: LumiColorTheme.rust),
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
  final double size;

  const _LevelTile({required this.level, required this.size});

  Widget? _screenForLevel() {
    switch (level) {
      case 1:
        return Lumi1ValuesWakeup();
      case 2:
        return Lvl2BathroomGameScreen();
      case 3:
        return CleanBedroomGameScreen();
      case 4:
        return CookingGameScreen();
      case 5:
        return Sharing1();
      case 6:
        return EmotionStarsScreen();
      case 7:
        return LumiClassroomScreen();
      case 8:
        return Prayer1();
      case 9:
        return Sorry1Screen();

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final screen = _screenForLevel();
        if (screen == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: LumiColorTheme.robroy,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: LumiColorTheme.rust, width: 5),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level',
          style: TextStyle(
            fontFamily: LumiAppTextStyles.fredoka,
            fontSize: size * 0.5,
            color: LumiColorTheme.rust,
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
