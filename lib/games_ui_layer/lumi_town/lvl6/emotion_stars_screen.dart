import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_2.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/game_loading_mixin.dart';
import '../../../ui_layer/loading_screen.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../lumi_game_ui_layer.dart';

class EmotionStarsScreen extends StatefulWidget {
  final int level;
  const EmotionStarsScreen({super.key, required this.level});

  @override
  State<EmotionStarsScreen> createState() => _EmotionStarsScreenState();
}

class _EmotionStarsScreenState extends State<EmotionStarsScreen>
    with
        SingleTickerProviderStateMixin,
        AiCameraMixin<EmotionStarsScreen>,
        GameLoadingMixin,
        AppAudioLifecycleMixin<EmotionStarsScreen> {
  late AnimationController _fadeController;
  late Animation<double> _opacityAnimation;
  late AudioPlayer _audioPlayer;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  final GameTapTracker _tapTracker = GameTapTracker();

  bool _hideLightingCard = false;

  static const String _audioIntro = 'audio/lumi_town/level6/emotion_intro.wav';

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

    _audioPlayer = AudioPlayer();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.35,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.35,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.35,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.20,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
    ]).animate(_fadeController);

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _playAudio();
      }
    });

    finishLoading(_startIntroFlow);
  }

  void _startIntroFlow() {
    if (!mounted) return;
    _fadeController.forward();
  }

  Future<void> _playAudio() async {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        final emotionsSoFar = stopAiCamera();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Emotion2(
              priorEmotions: emotionsSoFar,
              tapTracker: _tapTracker,
              level: widget.level,
            ),
          ),
        );
      }
    });

    await _audioPlayer.play(AssetSource(_audioIntro));
  }

  @override
  void dispose() {
    disposeAiCamera();
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithLoading(
      loadingScreen: ColoredBox(
        color: Colors.white,
        child: LoadingScreen.lumiTown(),
      ),
      gameBuilder: () => Listener(
        onPointerDown: (_) => _tapTracker.recordGenericTap(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            final double elementSize =
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
                  elementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.15,
                  y: 0.65,
                  tiltDegrees: -8,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/happy.png',
                  elementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.25,
                  y: 0.25,
                  tiltDegrees: 8,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/disgust.png',
                  elementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.42,
                  y: 0.72,
                  tiltDegrees: -8,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/sad.png',
                  elementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.56,
                  y: 0.36,
                  tiltDegrees: -8,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/wow.png',
                  elementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.75,
                  y: 0.70,
                  tiltDegrees: 12,
                ),
                _buildResponsiveStar(
                  'assets/images/objects/lumi/angry.png',
                  elementSize,
                  screenWidth,
                  screenHeight,
                  x: 0.80,
                  y: 0.30,
                  tiltDegrees: -5,
                ),

                Positioned(top: 25, left: 25, child: LumiXButton()),
                Positioned(
                  top: 25,
                  right: 25,
                  child: LumiLevelBadge(level: widget.level),
                ),

                if (hasCapturedFirstFrame &&
                    !isFaceDetected &&
                    !_hideLightingCard)
                  LightingPromptCard(
                    onClose: () {
                      setState(() => _hideLightingCard = true);
                      releaseFaceGate();
                    },
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
    double size,
    double totalWidth,
    double totalHeight, {
    required double x,
    required double y,
    required double tiltDegrees,
  }) {
    final double leftPosition = x * totalWidth - (size / 2);
    final double topPosition = y * totalHeight - (size / 2);
    final double tiltRadians = tiltDegrees * math.pi / 180;

    return Positioned(
      left: leftPosition,
      top: topPosition,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Transform.rotate(
          angle: tiltRadians,
          child: SizedBox(
            width: size,
            height: size,
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
