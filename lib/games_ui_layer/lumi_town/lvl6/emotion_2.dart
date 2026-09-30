import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_3.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

import '../lumi_game_ui_layer.dart';

class Emotion2 extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Emotion2({
    super.key,
    required this.priorEmotions,
    required this.tapTracker, required this.level,
  });

  @override
  State<Emotion2> createState() => _Emotion2State();
}

class _Emotion2State extends State<Emotion2> with AiCameraMixin<Emotion2> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  Timer? _carouselAppearanceTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _audioCompleteSubscription;

  bool _showCarousel = false;
  bool _hideLightingCard = false;

  final List<String> _scenarioImages = [
    'assets/images/objects/lumi/e1_wrong.png',
    'assets/images/objects/lumi/e2_wrong.png',
    'assets/images/objects/lumi/e3_wrong.png',
    'assets/images/objects/lumi/e4_wrong.png',
    'assets/images/objects/lumi/e5_wrong.png',
    'assets/images/objects/lumi/e6_wrong.png',
  ];

  static const String _audioStart = 'audio/lumi_town/level6/emotion_start.wav';
  static const String _audioTutorial = 'audio/lumi_town/level6/emotion_tutorial.wav';

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _initAudioAndSequence();
  }

  void _initAudioAndSequence() async {
    bool isTutorialPlaying = true;

    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((
      _,
    ) async {
      if (isTutorialPlaying) {
        isTutorialPlaying = false;
        await _audioPlayer.play(AssetSource(_audioStart));
      } else {
        if (mounted) {
          final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Emotion3Screen(
                priorEmotions: emotionsSoFar,
                tapTracker: widget.tapTracker,
                level: widget.level,
              ),
            ),
          );
        }
      }
    });

    await _audioPlayer.play(AssetSource(_audioTutorial));

    _carouselAppearanceTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showCarousel = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startAutoScroll();
        });
      }
    });
  }

  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients) {
        double currentPosition = _scrollController.position.pixels;
        _scrollController.jumpTo(currentPosition + 1.5);
      }
    });
  }

  @override
  void dispose() {
    disposeAiCamera();
    _scrollTimer?.cancel();
    _carouselAppearanceTimer?.cancel();
    _audioCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/backgrounds/bg_lumi_park_night.png',
                    fit: BoxFit.cover,
                  ),
                ),

                Positioned(
                  left: screenWidth * 0.15,
                  bottom: -55,
                  child: SizedBox(
                    width: screenWidth * 0.35,
                    child: Image.asset(
                      'assets/images/characters/tr.woo_the_owl.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                Positioned(
                  right: screenWidth * 0.08,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: screenWidth * 0.25,
                    child: AnimatedOpacity(
                      opacity: _showCarousel ? 1.0 : 0.0,
                      duration: const Duration(seconds: 1),
                      child: _buildCarousel(),
                    ),
                  ),
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return ListView.builder(
      controller: _scrollController,
      itemBuilder: (context, index) {
        final String imagePath =
            _scenarioImages[index % _scenarioImages.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: const Color(0xFFE8D5B5), width: 5.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15.0),
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}
