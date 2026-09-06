import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class CalibrationScreen extends StatefulWidget {
  final String childSessionId;
  final VoidCallback onCalibrationDone;

  const CalibrationScreen({
    super.key,
    required this.childSessionId,
    required this.onCalibrationDone,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with AiCameraMixin {
  bool _hideLightingCard = false;

  @override
  void initState() {
    super.initState();
    sessionId = widget.childSessionId;
    onCalibrationComplete = () {
      // Brief pause so the "All set!" moment is actually visible before
      // moving on — otherwise this can feel like it just skips a step.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onCalibrationDone();
      });
    };
    startAiCamera();
  }

  @override
  void dispose() {
    disposeAiCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same rule as every game screen now uses: only treat this as a real
    // "can't find your face" problem once we've actually gotten a reading
    // back, not during the normal camera-startup wait.
    final needsLightingPrompt =
        hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard;
    final isCalibrating = hasCapturedFirstFrame && isFaceDetected;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7EB),
      body: Stack(
        children: [
          if (isCameraInitialized && aiCameraController != null)
            Positioned.fill(child: CameraPreview(aiCameraController!)),

          // Waiting on the very first picture back — normal, brief, not
          // a lighting problem, so this is a plain loading state.
          if (!hasCapturedFirstFrame)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      "Getting the camera ready...",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),

          // Genuine "we can't find your face" case — same card used on
          // every game screen, so the visual language stays consistent.
          if (needsLightingPrompt)
            LightingPromptCard(
              onClose: () => setState(() => _hideLightingCard = true),
            ),

          // Face found, calibration actively running in the background.
          if (isCalibrating)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Hi there! Just look at the screen for a moment...",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
