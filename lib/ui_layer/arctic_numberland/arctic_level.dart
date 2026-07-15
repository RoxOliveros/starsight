import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:StarSight/games_ui_layer/arctic_numberland/addition_package_delivery_game.dart';
import 'package:StarSight/ui_layer/arctic_numberland/arctic_buttons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/arctic_numberland/addition_rescue_bridge_game.dart';
import '../../games_ui_layer/arctic_numberland/addition_subtraction_signboard.dart';
import '../../games_ui_layer/arctic_numberland/aurora_catcher.dart';
import '../../games_ui_layer/arctic_numberland/decorate_snowy_tree.dart';
import '../../games_ui_layer/arctic_numberland/build_snowman.dart';
import '../../games_ui_layer/arctic_numberland/iceberg_tip.dart';
import '../../games_ui_layer/arctic_numberland/igloo_peekaboo.dart';
import '../../games_ui_layer/arctic_numberland/number345_counting.dart';
import '../../games_ui_layer/arctic_numberland/number345_odd_one_out.dart';
import '../../games_ui_layer/arctic_numberland/number1to5_sequence.dart';
import '../../games_ui_layer/arctic_numberland/number1to5_counting_trees.dart';
import '../../games_ui_layer/arctic_numberland/number1to5_building_igloo.dart';
import '../../games_ui_layer/arctic_numberland/number1to5_match_snowglobe.dart';
import '../../games_ui_layer/arctic_numberland/number012_recognition.dart';
import '../../games_ui_layer/arctic_numberland/number012_counting.dart';
import '../../games_ui_layer/arctic_numberland/number012_counttap.dart';
import '../../games_ui_layer/arctic_numberland/number_introduction_screen.dart';
import '../../games_ui_layer/arctic_numberland/number_memory_match.dart';
import '../../games_ui_layer/arctic_numberland/penguin_line_walk.dart';
import '../../games_ui_layer/arctic_numberland/sled_shape_sort.dart';
import '../../games_ui_layer/arctic_numberland/shooting_star.dart';
import '../../games_ui_layer/arctic_numberland/snowglobe_shake_count.dart';
import '../../games_ui_layer/arctic_numberland/snowman_shape_hunt.dart';
import '../../games_ui_layer/arctic_numberland/subtraction_compare_game.dart';
import '../../games_ui_layer/arctic_numberland/subtraction_melting_ice_game.dart';
import '../loading_screen.dart';
import 'arctic_theme.dart';

class ArcticLevelScreen extends StatefulWidget {
  const ArcticLevelScreen({super.key});

  @override
  State<ArcticLevelScreen> createState() => _ArcticLevelScreenState();
}

class _ArcticLevelScreenState extends State<ArcticLevelScreen> {
  int _page = 0;
  int _unlockedLevel = 1;
  bool _isLoading = true;
  final DateTime _loadStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final unlocked = await ArcticProgressService.instance.getUnlockedLevel();

    final elapsed = DateTime.now().difference(_loadStart);
    // Loading time
    final remaining = const Duration(milliseconds: 1500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    setState(() {
      _unlockedLevel = unlocked;
      _isLoading = false;
    });
  }

  Future<void> _openLevel(Widget screen) async {
    final nextScreen = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (!mounted) return;

    await _loadProgress();

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
    if (_isLoading) {
      return Scaffold(body: LoadingScreen.arctic());
    }

    return Scaffold(
      body: Stack(
        children: [
          // 🌳 Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_arctic.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
          Positioned(top: 25, left: 20, child: ArcticBackButton()),

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
                      SizedBox(height: 20),
                      Container(
                        width: cardWidth,
                        height: cardHeight,
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EFE6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ArcticColorTheme.slateblue,
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
                                color: ArcticColorTheme.lightblue,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: ArcticColorTheme.slateblue,
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
                              child: Text(
                                ' SELECT LEVEL ',
                                style: TextStyle(
                                  fontFamily: ArcticAppTextStyles.fredoka,
                                  fontSize: 25,
                                  color: ArcticColorTheme.lightgrayishcyan,
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
                            if (_page > 0) setState(() => _page--);
                          },
                          child: Opacity(
                            opacity: _page > 0 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_arctic_arrow_left.png',
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
                            if (_page < 3) setState(() => _page++);
                          },
                          child: Opacity(
                            opacity: _page < 3 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_arctic_arrow_right.png',
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

      //TODO: @Tin update 1-3 intro here
      case 1:
        return NumberIntroductionScreen.forSequence(
          [0, 1, 2],
          nextScreen: const Number012RecognitionScreen(level: 2),
        );

      case 2:
        return const Number012RecognitionScreen(level: 2);
      case 3:
        return const Number012CountingObjectsScreen(level: 3);
      case 4:
        return const Number012TapCountScreen(level: 4);

      case 5:
        return NumberIntroductionScreen.forSequence(
          [3, 4, 5],
          nextScreen: const Number345CountingObjectsScreen(level: 6),
        );
      case 6:

        return const Number345CountingObjectsScreen(level: 6);
      case 7:
        return const Number345OddOneOutScreen(level: 7);
      case 8:
        return const Number012345SequenceScreen(level: 8);
      case 9:
        return const Number1to5CountingTreesScreen(level: 9);
      case 10:
        return const Number1to5FillIglooScreen(level: 10);
      case 11:
        return const Number1to5MatchSnowglobesScreen(level: 11);

      //TODO: @Tin add 6-8 intro here
      case 12:
        return null;

      case 13:
        return const PenguinLineWalkGame(level: 13);
      case 14:
        return const IglooPeekabooGame(level: 14);
      case 15:
        return const BuildSnowmanGame(level: 15);

      //TODO: @Tin add 9-10 intro here
      case 16:
        return null;

      case 17:
        return const NumberMemoryMatchGame(level: 17);
      case 18:
        return const IcebergTipGame(level: 18);
      case 19:
        return const SnowglobeShakeGame(level: 19);
      case 20:
        return const AdditionRescueBridgeGame(level: 20);
      case 21:
        return const AdditionPackageDeliveryGame(level: 21);
      case 22:
        return const SubtractionMeltingIceGame(level: 22);
      case 23:
        return const SubtractionCompareGame(level: 23);
      case 24:
        return const SignboardMathGame(level: 24);
      case 25:
        return const SnowmanShapeHuntGame(level: 25);
      case 26:
        return const SledShapeSortGame(level: 26);
      case 27:
        return const DecorateSnowyTreeGame(level: 27);
      case 28:
        return const AuroraCatcherGame(level: 28);
      case 29:
        return const ShootingStarCountingGame(level: 29);

      //TODO: @Tin add an ending game for arctic
      case 30:
        return null;

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (level > 30) return SizedBox(width: size, height: size);

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
              color: ArcticColorTheme.pictonblue,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ArcticColorTheme.slateblue, width: 5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: size * 0.5,
                color: ArcticColorTheme.cadetblue,
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
            ),
          ),
        ),
      ),
    );
  }
}
