import 'package:StarSight/ui_layer/arctic_numberland/arctic_buttons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/arctic numberland/arctic3_number_counting.dart';
import '../../games_ui_layer/arctic numberland/arctic4_number_matching.dart';
import '../../games_ui_layer/arctic numberland/arctic2_number_recognition.dart';
import 'arctic_theme.dart';

class ArcticLevelScreen extends StatefulWidget {
  const ArcticLevelScreen({super.key});

  @override
  State<ArcticLevelScreen> createState() => _ArcticLevelScreenState();
}

class _ArcticLevelScreenState extends State<ArcticLevelScreen> {
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
                            _LockedTile(),
                            _LockedTile(),
                            _LockedTile(),
                            _LockedTile(),
                          ],
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
                    child: Image.asset(
                      'assets/images/arrows/bttn_arctic_arrow_left.png',
                      width: 70,
                    ),
                  ),
                  // Right arrow
                  Positioned(
                    right: -35,
                    top: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/arrows/bttn_arctic_arrow_right.png',
                      width: 70,
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
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NumberRecognitionScreen(),
              ),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CountingObjectsScreen(),
              ),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NumberMatchingScreen(),
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
