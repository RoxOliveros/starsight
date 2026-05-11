import 'package:StarSight/games_ui_layer/alphabet_forest/lvl_1.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_trace.dart';
import 'package:lottie/lottie.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color peach = Color(0xFFFBEBC6);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color blue = Color(0xFF4C89C3);
  static const Color lightblue = Color(0xFF6FD3E3);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color yelloworange = Color(0xFFFACC58);
  static const Color brown = Color(0xFF6F6764);
  static const Color darkbrown = Color(0xFF4E360D);
  static const Color darkgreen = Color(0xFF3C5729);
  static const Color forestgreen = Color(0xFF9DA92A);
  static const Color flaxengold = Color(0xFFCAB781);
  static const Color olivegreen = Color(0xFF5D6F2F);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
  static const String nunito = 'Nunito';
}

class ForestLevelScreen extends StatefulWidget {
  const ForestLevelScreen({super.key});

  @override
  State<ForestLevelScreen> createState() => _ForestLevelScreenState();
}

class _ForestLevelScreenState extends State<ForestLevelScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
              'assets/images/backgrounds/bg_forest.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
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
                  border: Border.all(color: ColorTheme.olivegreen, width: 5),
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
                  SizedBox(height: 20),
                  Container(
                    width: 650,
                    height: 280,
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4EFE6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ColorTheme.darkbrown, width: 8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            _LevelTile(level: 1, stars: 3),
                            _LevelTile(level: 2, stars: 2),
                            _LevelTile(level: 3),
                            _LockedTile(),
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
                            color: ColorTheme.forestgreen,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: ColorTheme.darkgreen,
                              width: 5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
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
                  // Left arrow
                  Positioned(
                    left: -35,
                    top: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/arrows/bttn_forest_arrow_left.png',
                      width: 70,
                    ),
                  ),
                  // Right arrow
                  Positioned(
                    right: -35,
                    top: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/arrows/bttn_forest_arrow_right.png',
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

  Widget _arrowButton(IconData icon) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF8BAA8E),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final int stars;

  const _LevelTile({required this.level, this.stars = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        switch (level) {
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const lvl_1()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AlphabetTraceScreen(),
              ),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const lvl_1()),
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
          Positioned(
            bottom: -5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Image.asset(
                  'assets/images/star.png',
                  width: 14,
                  height: 14,
                  color: i < stars ? null : Colors.grey.shade400,
                  colorBlendMode: BlendMode.srcIn,
                );
              }),
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
