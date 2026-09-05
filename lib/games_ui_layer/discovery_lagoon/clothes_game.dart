import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/habitant_game.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import 'lagoon_game_ui.dart';

class ClothesGame extends StatefulWidget {
  final int level;

  const ClothesGame({super.key, required this.level});

  @override
  _ClothesGameState createState() => _ClothesGameState();
}

class _ClothesGameState extends State<ClothesGame> {
  // Game State variables
  bool showIntro = true; // New state to track if we are in the intro sequence
  int currentWeatherIndex = 0;

  // List of weathers including the new winter state
  final List<String> weathers = ['sunny', 'cloudy', 'rainy', 'windy', 'winter'];
  bool isDressed = false;

  // Shown once the bear is correctly dressed for the last weather (winter).
  bool showGoodJobOverlay = false;

  // Audio Player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Listen for when the intro audio finishes playing to start the game
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted && showIntro) {
        setState(() {
          showIntro = false;
        });
      }
    });

    // Start the intro sequence
    _playIntroAudio();
  }

  Future<void> _playIntroAudio() async {
    // Assuming the audio is placed in this directory based on previous files
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/clothes_game_intro.wav'),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _handleDrop(String draggedClothes) async {
    String currentWeather = weathers[currentWeatherIndex];

    if (draggedClothes == currentWeather) {
      // Correct clothes dropped
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));

      setState(() {
        isDressed = true;
      });

      final bool isLastWeather = currentWeatherIndex == weathers.length - 1;

      // Wait 2 seconds, then either move to the next weather, or — if this
      // was the last one (winter) — show the Good Job overlay instead.
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (isLastWeather) {
          setState(() {
            showGoodJobOverlay = true;
          });
        } else {
          setState(() {
            currentWeatherIndex++;
            isDressed = false;
          });
        }
      });
    } else {
      // Wrong clothes dropped
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/kiki_tryagain.wav'),
      );
    }
  }

  String _getBackgroundImage() {
    if (weathers[currentWeatherIndex] == 'sunny') {
      return 'assets/images/objects/lagoon/room_sunny.png';
    } else if (weathers[currentWeatherIndex] == 'cloudy') {
      return 'assets/images/objects/lagoon/room_cloudy.png';
    } else if (weathers[currentWeatherIndex] == 'rainy') {
      return 'assets/images/objects/lagoon/room_rainy.png';
    } else if (weathers[currentWeatherIndex] == 'windy') {
      return 'assets/images/objects/lagoon/room_windy.png';
    } else {
      return 'assets/images/objects/lagoon/room_winter.png';
    }
  }

  String _getDressedBearImage() {
    if (weathers[currentWeatherIndex] == 'sunny') {
      return 'assets/images/characters/little_bear_sunny.png';
    } else if (weathers[currentWeatherIndex] == 'cloudy') {
      return 'assets/images/characters/little_bear_cloudy.png';
    } else if (weathers[currentWeatherIndex] == 'rainy') {
      return 'assets/images/characters/little_bear_rainy.png';
    } else if (weathers[currentWeatherIndex] == 'windy') {
      return 'assets/images/characters/little_bear_windy.png';
    } else {
      return 'assets/images/characters/little_bear_winter.png';
    }
  }

  // Dynamically generate exactly two choices based on the current room state
  List<Widget> _getSidebarChoices(Size size) {
    if (weathers[currentWeatherIndex] == 'cloudy') {
      return [
        _buildClothingItem(
          size,
          'cloudy',
          'assets/images/objects/lagoon/clothes_cloudy.png',
        ),
        _buildClothingItem(
          size,
          'rainy',
          'assets/images/objects/lagoon/clothes_rainy.png',
        ),
      ];
    } else if (weathers[currentWeatherIndex] == 'rainy') {
      return [
        _buildClothingItem(
          size,
          'sunny',
          'assets/images/objects/lagoon/clothes_sunny.png',
        ),
        _buildClothingItem(
          size,
          'rainy',
          'assets/images/objects/lagoon/clothes_rainy.png',
        ),
      ];
    } else if (weathers[currentWeatherIndex] == 'windy') {
      return [
        _buildClothingItem(
          size,
          'windy',
          'assets/images/objects/lagoon/clothes_windy.png',
        ),
        _buildClothingItem(
          size,
          'winter',
          'assets/images/objects/lagoon/clothes_winter.png',
        ),
      ];
    } else if (weathers[currentWeatherIndex] == 'winter') {
      // Winter room choices: Winter clothe and Cloudy clothe
      return [
        _buildClothingItem(
          size,
          'winter',
          'assets/images/objects/lagoon/clothes_winter.png',
        ),
        _buildClothingItem(
          size,
          'cloudy',
          'assets/images/objects/lagoon/clothes_cloudy.png',
        ),
      ];
    } else {
      // Default to Sunny room choices
      return [
        _buildClothingItem(
          size,
          'sunny',
          'assets/images/objects/lagoon/clothes_sunny.png',
        ),
        _buildClothingItem(
          size,
          'cloudy',
          'assets/images/objects/lagoon/clothes_cloudy.png',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // --- Intro Sequence UI ---
    if (showIntro) {
      return Scaffold(
        body: Stack(
          children: [
            // Intro Background
            Positioned.fill(
              child: Image.asset(
                'assets/images/backgrounds/bg_lumi_bed.png',
                fit: BoxFit.cover,
              ),
            ),

            // X Button and Level Badge
            Positioned(top: 25, left: 25, child: const LagoonXButton()),
            Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

            // Kiki the Cat (Left side)
            Positioned(
              left: size.width * 0.20,
              bottom: size.height * -0.05,
              child: Image.asset(
                'assets/images/characters/kiki_the_cat.png',
                width: size.width * 0.35,
                fit: BoxFit.contain,
              ),
            ),

            // Little Bear (Right side)
            Positioned(
              right: size.width * 0.20,
              bottom: size.height * -0.08,
              child: Image.asset(
                'assets/images/characters/little_bear.png',
                width: size.width * 0.30,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      );
    }

    // --- Main Game UI ---
    final sidebarWidth = size.width * 0.22;

    // --- Independent sizing/positioning per bear asset ---

    // little_bear.png (undressed / default)
    final double bearWidthDefault = size.width * 0.28;
    final double bearBottomDefault = size.height * -0.08;
    final double bearLeftOffsetDefault = 0;

    // little_bear_sunny.png (dressed sunny)
    final double bearWidthSunny = size.width * 0.38;
    final double bearBottomSunny = size.height * -0.12;
    final double bearLeftOffsetSunny = 0;

    // little_bear_cloudy.png (dressed cloudy)
    final double bearWidthCloudy = size.width * 0.38;
    final double bearBottomCloudy = size.height * -0.095;
    final double bearLeftOffsetCloudy = 0;

    // little_bear_rainy.png (dressed rainy)
    final double bearWidthRainy = size.width * 0.48;
    final double bearBottomRainy = size.height * -0.095;
    final double bearLeftOffsetRainy = 0;

    // little_bear_windy.png (dressed windy)
    final double bearWidthWindy = size.width * 0.38;
    final double bearBottomWindy = size.height * -0.12;
    final double bearLeftOffsetWindy = 0;

    // little_bear_winter.png (dressed winter)
    final double bearWidthWinter = size.width * 0.40;
    final double bearBottomWinter = size.height * -0.09;
    final double bearLeftOffsetWinter = 0;

    // Active values based on current state
    double currentBearWidth = bearWidthDefault;
    double currentBearBottom = bearBottomDefault;
    double currentBearLeftOffset = bearLeftOffsetDefault;

    if (isDressed) {
      if (weathers[currentWeatherIndex] == 'sunny') {
        currentBearWidth = bearWidthSunny;
        currentBearBottom = bearBottomSunny;
        currentBearLeftOffset = bearLeftOffsetSunny;
      } else if (weathers[currentWeatherIndex] == 'cloudy') {
        currentBearWidth = bearWidthCloudy;
        currentBearBottom = bearBottomCloudy;
        currentBearLeftOffset = bearLeftOffsetCloudy;
      } else if (weathers[currentWeatherIndex] == 'rainy') {
        currentBearWidth = bearWidthRainy;
        currentBearBottom = bearBottomRainy;
        currentBearLeftOffset = bearLeftOffsetRainy;
      } else if (weathers[currentWeatherIndex] == 'windy') {
        currentBearWidth = bearWidthWindy;
        currentBearBottom = bearBottomWindy;
        currentBearLeftOffset = bearLeftOffsetWindy;
      } else if (weathers[currentWeatherIndex] == 'winter') {
        currentBearWidth = bearWidthWinter;
        currentBearBottom = bearBottomWinter;
        currentBearLeftOffset = bearLeftOffsetWinter;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(_getBackgroundImage(), fit: BoxFit.cover),
          ),

          // The Bear (DragTarget)
          Positioned(
            left:
                (size.width - sidebarWidth) / 2 -
                (currentBearWidth / 2) +
                currentBearLeftOffset,
            bottom: currentBearBottom,
            child: DragTarget<String>(
              builder: (context, candidateData, rejectedData) {
                return Image.asset(
                  isDressed
                      ? _getDressedBearImage()
                      : 'assets/images/characters/little_bear.png',
                  width: currentBearWidth,
                  fit: BoxFit.contain,
                );
              },
              onWillAccept: (data) => true,
              onAccept: _handleDrop,
            ),
          ),

          // The Clothes Sidebar
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: sidebarWidth,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                border: Border(
                  left: BorderSide(color: Color(0xFF3B82F6), width: 4),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
              child: DashedBox(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _getSidebarChoices(size),
                  ),
                ),
              ),
            ),
          ),

          // Good Job overlay — shown once winter (the last weather) is done
          if (showGoodJobOverlay)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/cat_holding_fishbone.png',
              
              characterSizeFactor: 0.9,
              onNext: () async {
                // 1. Mark the current level as complete (Change the number for each game)
                await LagoonProgressService.instance.markLevelComplete(9);

                if (context.mounted) {
                  // 2. Push directly to the next level's screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HabitantGame(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  currentWeatherIndex = 0;
                  isDressed = false;
                  showGoodJobOverlay = false;
                });
              },
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  // Helper widget to keep the column clean and avoid repeating code
  Widget _buildClothingItem(Size size, String type, String assetPath) {
    return Draggable<String>(
      data: type,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(
          assetPath,
          width: size.width * 0.16,
          fit: BoxFit.contain,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Image.asset(
          assetPath,
          width: size.width * 0.16,
          fit: BoxFit.contain,
        ),
      ),
      child: Image.asset(
        assetPath,
        width: size.width * 0.16,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// A small reusable widget that draws a dashed border around [child].
class DashedBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  const DashedBox({
    Key? key,
    required this.child,
    this.color = const Color(0xFF9CA3AF),
    this.strokeWidth = 2,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.borderRadius = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _createDashedPath(path);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source) {
    final dashedPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashWidth : dashSpace;
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashWidth != oldDelegate.dashWidth ||
        dashSpace != oldDelegate.dashSpace ||
        borderRadius != oldDelegate.borderRadius;
  }
}
