import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../business_layer/orientation_service.dart';

abstract class ColorTheme {
  static const Color darkbrown = Color(0xFF4E360D);
  static const Color verydarkdesaturatedblue  = Color(0xFF24334D);
  static const Color darkdesaturatedblue  = Color(0xFF4C648A);
  static const Color sunnyhue = Color(0xFFF9AB19);
  static const Color goldenyellow = Color(0xFFFDCE57);
  static const Color peach = Color(0xFFFBEBC6);
  static const Color vandecane = Color(0xFFFAF7EB);
  static const Color lightgrayishyellow  = Color(0xFFFEFAD3);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class JarLevelScreen extends StatefulWidget {
  const JarLevelScreen({super.key});

  @override
  State<JarLevelScreen> createState() => _JarLevelScreenState();
}

class _JarLevelScreenState extends State<JarLevelScreen> {
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
              'assets/images/backgrounds/bg_jar.png',
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
                  color: ColorTheme.lightgrayishyellow,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: ColorTheme.sunnyhue, width: 5),
                ),
                child: const Text(
                  'back',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 18,
                    color: ColorTheme.sunnyhue,
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
                      color: ColorTheme.vandecane,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ColorTheme.darkbrown, width: 8),
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
                            color: ColorTheme.darkdesaturatedblue,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: ColorTheme.verydarkdesaturatedblue,
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
                  // Left arrow
                  Positioned(
                    left: -35,
                    top: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/arrows/bttn_jar_arrow_left.png',
                      width: 70,
                    ),
                  ),
                  // Right arrow
                  Positioned(
                    right: -35,
                    top: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/arrows/bttn_jar_arrow_right.png',
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
              color: ColorTheme.goldenyellow,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ColorTheme.darkdesaturatedblue, width: 5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: const TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 40,
                color: ColorTheme.darkdesaturatedblue,
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
