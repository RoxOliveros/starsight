import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color blue = Color(0xFF4C89C3);
  static const Color lightblue = Color(0xFF6FD3E3);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color yelloworange = Color(0xFFFACC58);
  static const Color brown = Color(0xFF6F6764);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
  static const String nunito = 'Nunito';
}

class PuzzleLevelScreen extends StatefulWidget {
  const PuzzleLevelScreen({super.key});

  @override
  State<PuzzleLevelScreen> createState() => _PuzzleLevelScreenState();
}

class _PuzzleLevelScreenState extends State<PuzzleLevelScreen> {
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
          // Positioned.fill(
          //   child:
          //   Image.asset(
          //     'assets/drafts/puzzle_bg.png',
          //     fit: BoxFit.cover,
          //   ),
          // ),
          //TODO: @Tin bg

          // 🌿 Content
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Outer stack for arrows
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      width: 600,
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EFE6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFB97A3D),
                          width: 4,
                        ),
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
                      top: -22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ColorTheme.yelloworange,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ColorTheme.orange,
                            width: 3,
                          ),
                        ),
                        child: const Text(
                          'SELECT LEVEL',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fredoka,
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    // Left arrow
                    Positioned(
                      left: -25,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _arrowButton(Icons.arrow_left)),
                    ),
                    // Right arrow
                    Positioned(
                      right: -25,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _arrowButton(Icons.arrow_right)),
                    ),
                  ],
                ),
              ],
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
      onTap: level == 1
          ? () {
        //TODO: @Tin Navigate to lvl1
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (context) => const ()),
        // );
      }
          : null,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF8BAA8E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF5F7A62), width: 2.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: const TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 26,
                color: Colors.white,
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
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade400,
          style: BorderStyle.solid,
        ),
      ),
      child: const Icon(Icons.lock, color: Colors.grey),
    );
  }
}
