import 'package:StarSight/ui_layer/arctic_numberland/arctic_buttons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/arctic_numberland/lvl8_three_introduction.dart';
import '../../games_ui_layer/arctic_numberland/lvl9_four_introduction.dart';
import '../../games_ui_layer/arctic_numberland/lvl10_five_introduction.dart';
import '../../games_ui_layer/arctic_numberland/lvl11_345_reintroduction.dart';
import '../../games_ui_layer/arctic_numberland/lvl12_345_counting.dart';
import '../../games_ui_layer/arctic_numberland/lvl13_345_odd_one_out.dart';
import '../../games_ui_layer/arctic_numberland/lvl14_012345_sequence.dart';
import '../../games_ui_layer/arctic_numberland/lvl15_0to5_counting_trees.dart';
import '../../games_ui_layer/arctic_numberland/lvl16_0to5_building_igloo.dart';
import '../../games_ui_layer/arctic_numberland/lvl17_0to5_match_snowglobe.dart';
import '../../games_ui_layer/arctic_numberland/lvl4_number012_reintroduction.dart';
import '../../games_ui_layer/arctic_numberland/lvl5_number012_recognition.dart';
import '../../games_ui_layer/arctic_numberland/lvl1_zero_introduction.dart';
import '../../games_ui_layer/arctic_numberland/lvl2_one_introduction.dart';
import '../../games_ui_layer/arctic_numberland/lvl3_two_introduction.dart';
import '../../games_ui_layer/arctic_numberland/lvl6_number012_counting.dart';
import '../../games_ui_layer/arctic_numberland/lvl7_number012_counttap.dart';
import 'arctic_theme.dart';

class ArcticLevelScreen extends StatefulWidget {
  const ArcticLevelScreen({super.key});

  @override
  State<ArcticLevelScreen> createState() => _ArcticLevelScreenState();
}

class _ArcticLevelScreenState extends State<ArcticLevelScreen> {
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
              'assets/images/backgrounds/bg_arctic.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
          Positioned(top: 25, left: 25, child: ArcticBackButton()),

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
                      color: const Color(0xFFF4EFE6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ArcticColorTheme.slateblue,
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
                            return _LevelTile(level: level);
                          }),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (i) {
                            final level = _page * 8 + i + 5;
                            return _LevelTile(level: level);
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
                        if (_page < 2) setState(() => _page++);
                      },
                      child: Opacity(
                        opacity: _page < 2 ? 1.0 : 0.3,
                        child: Image.asset(
                          'assets/images/arrows/bttn_arctic_arrow_right.png',
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
                builder: (context) => const NumberZeroIntroductionScreen(),
              ),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NumberOneIntroductionScreen(),
              ),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NumberTwoIntroductionScreen(),
              ),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number012ReintroductionScreen(),
              ),
            );
            break;
          case 5:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number012RecognitionScreen(),
              ),
            );
            break;
          case 6:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number012CountingObjectsScreen(),
              ),
            );
            break;
          case 7:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number012TapCountScreen(),
              ),
            );
            break;
          case 8:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NumberThreeIntroductionScreen(),
              ),
            );
            break;
          case 9:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NumberFourIntroductionScreen(),
              ),
            );
            break;
          case 10:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NumberFiveIntroductionScreen(),
              ),
            );
            break;
          case 11:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number345ReintroductionScreen(),
              ),
            );
            break;
          case 12:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number345CountingScreen(),
              ),
            );
            break;
          case 13:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number345OddOneOutScreen(),
              ),
            );
            break;
          case 14:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number012345SequenceScreen(),
              ),
            );
            break;
          case 15:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number0to5CountingTreesScreen(),
              ),
            );
            break;
          case 16:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number0to5FillIglooScreen(),
              ),
            );
            break;
          case 17:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Number0to5MatchSnowglobesScreen(),
              ),
            );
            break;
          default:
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
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
              color: ArcticColorTheme.pictonblue,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ArcticColorTheme.slateblue, width: 5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: const TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: 40,
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
