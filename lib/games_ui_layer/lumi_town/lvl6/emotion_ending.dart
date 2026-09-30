import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl7/lumi_classroom_screen.dart';
import 'package:StarSight/ui_layer/lumi_town/town_level.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';

import '../lumi_game_ui_layer.dart';
import 'emotion_stars_screen.dart';

class EmotionEndingScreen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const EmotionEndingScreen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker, required this.level,
  });

  @override
  State<EmotionEndingScreen> createState() => _EmotionEndingScreenState();
}

class _EmotionEndingScreenState extends State<EmotionEndingScreen>
    with SingleTickerProviderStateMixin, AiCameraMixin<EmotionEndingScreen> {
  late AudioPlayer _audioPlayer;

  late AnimationController _flickerController;
  late Animation<double> _flickerAnimation;

  bool _isAudioFinished = false;
  String? _selectedStarPath;
  bool _showGoodJobOverlay = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  static const String _audioEnding = 'audio/lumi_town/level6/emotion_ending.wav';

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _flickerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _flickerAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _flickerController, curve: Curves.easeInOut),
    );

    _audioPlayer = AudioPlayer();
    _playEndingAudio();
  }

  Future<void> _playEndingAudio() async {
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isAudioFinished = true;
        });
      }
    });

    await _audioPlayer.play(AssetSource(_audioEnding));
  }

  @override
  void dispose() {
    disposeAiCamera();
    _flickerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveDataAndMarkComplete() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;

    final finalEmotions = [...widget.priorEmotions, ...stopAiCamera()];

    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_emotions',
      activityName: 'Emotion Stars',
      emotions: finalEmotions,
      totalTaps: widget.tapTracker.totalTaps,
      mistakes: widget.tapTracker.mistakeCount,
      timePlayedSeconds: widget.tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    TownProgressService.instance.markLevelComplete(6).catchError((e) {
      debugPrint("Database Error marking level complete: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            final double baseElementSize =
                (screenWidth * 0.18 < screenHeight * 0.28)
                ? screenWidth * 0.25
                : screenHeight * 0.35;

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/backgrounds/bg_game_emotion.png',
                    fit: BoxFit.cover,
                  ),
                ),

                _buildResponsiveStar(
                  'assets/images/objects/lumi/scared.png',
                  baseElementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.15,
                  y: 0.65,
                  tiltDegrees: -8,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/happy.png',
                  baseElementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.25,
                  y: 0.25,
                  tiltDegrees: 8,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/disgust.png',
                  baseElementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.42,
                  y: 0.72,
                  tiltDegrees: -8,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/sad.png',
                  baseElementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.56,
                  y: 0.36,
                  tiltDegrees: -8,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/wow.png',
                  baseElementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.75,
                  y: 0.70,
                  tiltDegrees: 12,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/angry.png',
                  baseElementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.80,
                  y: 0.30,
                  tiltDegrees: -5,
                ),

                Positioned(top: 25, left: 25, child: LumiXButton()),
                Positioned(top: 25, right: 25, child: LumiLevelBadge(level: widget.level)),

                if (hasCapturedFirstFrame &&
                    !isFaceDetected &&
                    !_hideLightingCard)
                  LightingPromptCard(
                    onClose: () {
                      setState(() => _hideLightingCard = true);
                      releaseFaceGate();
                    },
                  ),

                if (_showGoodJobOverlay && _selectedStarPath != null)
                  Positioned.fill(
                    child: GoodJobOverlay(
                      characterImage: _selectedStarPath!,
                      onNext: () async {
                        await _saveDataAndMarkComplete();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const LumiClassroomScreen(),
                          ),
                        );
                      },
                      onRestart: () async {
                        await _saveDataAndMarkComplete();
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => EmotionStarsScreen(level: widget.level),
                          ),
                        );
                      },
                      onBack: () async {
                        await _saveDataAndMarkComplete();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LumiLevelScreen(),
                            ),
                            (route) => route.isFirst,
                          );
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResponsiveStar(
    String imagePath,
    double baseSize,
    double totalWidth,
    double totalHeight, {
    required double x,
    required double y,
    required double tiltDegrees,
  }) {
    final bool isSelected = _selectedStarPath == imagePath;
    final double currentSize = isSelected ? baseSize * 2.2 : baseSize;

    final double leftPosition = isSelected
        ? (totalWidth / 2) - (currentSize / 2)
        : (x * totalWidth) - (currentSize / 2);

    final double topPosition = isSelected
        ? (totalHeight / 2) - (currentSize / 2)
        : (y * totalHeight) - (currentSize / 2);

    final double targetRotation = isSelected ? 0.0 : (tiltDegrees / 360.0);

    final double baseOpacity = (_selectedStarPath == null || isSelected)
        ? 1.0
        : 0.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.fastOutSlowIn,
      left: leftPosition,
      top: topPosition,
      width: currentSize,
      height: currentSize,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: baseOpacity,
        child: AnimatedBuilder(
          animation: _flickerAnimation,
          builder: (context, child) {
            final double currentFlickerOpacity = (_selectedStarPath != null)
                ? 1.0
                : _flickerAnimation.value;

            return Opacity(opacity: currentFlickerOpacity, child: child);
          },
          child: GestureDetector(
            onTap: () {
              if (_isAudioFinished && !_showGoodJobOverlay) {
                if (!isSelected) {
                  widget.tapTracker.recordCorrectTap();
                }

                setState(() {
                  _selectedStarPath = isSelected ? null : imagePath;
                });

                if (!isSelected) {
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted && _selectedStarPath == imagePath) {
                      setState(() {
                        _showGoodJobOverlay = true;
                      });
                    }
                  });
                }
              }
            },
            child: AnimatedRotation(
              turns: targetRotation,
              duration: const Duration(milliseconds: 800),
              curve: Curves.fastOutSlowIn,
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
