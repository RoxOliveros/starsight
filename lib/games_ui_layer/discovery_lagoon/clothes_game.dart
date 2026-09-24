import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/habitant_game.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';

import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import 'lagoon_game_ui.dart';

class ClothesGame extends StatefulWidget {
  final int level;

  const ClothesGame({super.key, required this.level});

  @override
  _ClothesGameState createState() => _ClothesGameState();
}

class _ClothesGameState extends State<ClothesGame> with AiCameraMixin {
  final GameTapTracker _tapTracker = GameTapTracker();

  bool showIntro = true;
  int currentWeatherIndex = 0;

  final List<String> weathers = ['sunny', 'cloudy', 'rainy', 'windy', 'winter'];
  bool isDressed = false;

  bool showGoodJobOverlay = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted && showIntro) {
        setState(() {
          showIntro = false;
        });
      }
    });

    _playIntroAudio();
  }

  Future<void> _playIntroAudio() async {
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/clothes_game_intro.wav'),
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _handleDrop(String draggedClothes) async {
    String currentWeather = weathers[currentWeatherIndex];

    if (draggedClothes == currentWeather) {
      _tapTracker.recordCorrectTap();
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));

      setState(() {
        isDressed = true;
      });

      final bool isLastWeather = currentWeatherIndex == weathers.length - 1;

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (isLastWeather) {
          _saveDataAndShowGoodJob();
        } else {
          setState(() {
            currentWeatherIndex++;
            isDressed = false;
          });
        }
      });
    } else {
      _tapTracker.recordMistake();
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/kiki_tryagain.wav'),
      );
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    try {
      await LagoonDatabaseService.saveGameData(
        gameId: 'lagoon_clothes_game',
        activityName: 'Clothes Game',
        emotions: finalEmotions,
        totalTaps: _tapTracker.totalTaps,
        mistakes: _tapTracker.mistakeCount,
        timePlayedSeconds: _tapTracker.formattedDuration,
      );
    } catch (e) {
      debugPrint("Database Error saving metrics: $e");
    }
    await LagoonProgressService.instance.markLevelComplete(9);

    if (mounted) {
      setState(() {
        showGoodJobOverlay = true;
      });
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

    if (showIntro) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/backgrounds/bg_lumi_bed.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned(top: 25, left: 25, child: const LagoonXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LagoonLevelBadge(level: widget.level),
            ),
            Positioned(
              left: size.width * 0.20,
              bottom: size.height * -0.05,
              child: Image.asset(
                'assets/images/characters/kiki_the_cat.png',
                width: size.width * 0.35,
                fit: BoxFit.contain,
              ),
            ),
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

    final sidebarWidth = size.width * 0.22;

    final double bearWidthDefault = size.width * 0.28;
    final double bearBottomDefault = size.height * -0.08;
    final double bearLeftOffsetDefault = 0;

    final double bearWidthSunny = size.width * 0.38;
    final double bearBottomSunny = size.height * -0.12;
    final double bearLeftOffsetSunny = 0;

    final double bearWidthCloudy = size.width * 0.38;
    final double bearBottomCloudy = size.height * -0.095;
    final double bearLeftOffsetCloudy = 0;

    final double bearWidthRainy = size.width * 0.48;
    final double bearBottomRainy = size.height * -0.095;
    final double bearLeftOffsetRainy = 0;

    final double bearWidthWindy = size.width * 0.38;
    final double bearBottomWindy = size.height * -0.12;
    final double bearLeftOffsetWindy = 0;

    final double bearWidthWinter = size.width * 0.40;
    final double bearBottomWinter = size.height * -0.09;
    final double bearLeftOffsetWinter = 0;

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
          Positioned.fill(
            child: Image.asset(_getBackgroundImage(), fit: BoxFit.cover),
          ),
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
              onWillAcceptWithDetails: (data) => true,
              onAcceptWithDetails: (details) => _handleDrop(details.data),
            ),
          ),
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

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (showGoodJobOverlay)
            GoodJobOverlay(
              characterImage:
                  'assets/images/characters/cat_holding_fishbone.png',
              characterSizeFactor: 0.9,
              onNext: () {
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HabitantGame(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  currentWeatherIndex = 0;
                  isDressed = false;
                  showGoodJobOverlay = false;
                  _hasSavedResult = false;
                  _tapTracker.startSession();
                });
              },
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

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
