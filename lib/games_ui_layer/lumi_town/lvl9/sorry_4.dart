import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_5.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../lumi_game_ui_layer.dart';

class Sorry4Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Sorry4Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker, required this.level,
  });

  @override
  State<Sorry4Screen> createState() => _Sorry4ScreenState();
}

class _Sorry4ScreenState extends State<Sorry4Screen>
    with TickerProviderStateMixin, AiCameraMixin<Sorry4Screen> {
  late final AnimationController _walkController;
  final Duration _walkDuration = const Duration(milliseconds: 1800);
  final Duration _stepDuration = const Duration(milliseconds: 260);
  final double _bounceHeightFraction = 0.045;

  bool _hideLightingCard = false;

  @override
  void initState() {
    super.initState();
    _walkController = AnimationController(vsync: this, duration: _walkDuration);
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startWalkAndTransition();
    });
  }

  Future<void> _startWalkAndTransition() async {
    try {
      await _walkController.forward(from: 0);
      if (!mounted) return;

      final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Sorry5Screen(
            priorEmotions: emotionsSoFar,
            tapTracker: widget.tapTracker,
            level: widget.level
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error transitioning from sorry_4: $e');
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    _walkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final baseCharacterHeight = MediaQuery.of(context).size.height * 1.18;
    final characterHeight = baseCharacterHeight * 0.70;

    final double startX = sw;
    final int stepCount =
        (_walkDuration.inMilliseconds / _stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);
    final double bounceHeightPx = characterHeight * _bounceHeightFraction;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_classroom.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => const Center(
                child: Text(
                  'Background could not be loaded.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),

            Positioned(
              left: sw * 0.12,
              bottom: -(baseCharacterHeight * 0.15),
              child: SizedBox(
                height: characterHeight,
                child: Image.asset(
                  'assets/images/characters/littlebear_sad_tears.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            AnimatedBuilder(
              animation: _walkController,
              builder: (context, child) {
                final double t = _walkController.value;
                final double easedT = Curves.easeOutCubic.transform(t);

                final double dx = startX * (1 - easedT);
                final double bounce = t < 1.0
                    ? (math.sin(t * stepCount * math.pi)).abs() * bounceHeightPx
                    : 0.0;

                return Positioned(
                  right: (sw * 0.12) - dx,
                  bottom: -(baseCharacterHeight * 0.12) + bounce,
                  child: SizedBox(
                    height: characterHeight,
                    width: characterHeight * 0.85,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(
                          'assets/images/characters/jack_sad.png',
                          height: characterHeight,
                          fit: BoxFit.contain,
                        ),

                        Positioned(
                          bottom: characterHeight * 0.12,
                          left: characterHeight * 0.08,
                          child: Image.asset(
                            'assets/images/objects/lumi/car.png',
                            width: characterHeight * 0.35,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(top: 25, right: 25, child: LumiLevelBadge(level: widget.level)),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),
          ],
        ),
      ),
    );
  }
}
