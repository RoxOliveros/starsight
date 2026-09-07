import 'dart:async';
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

  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    sessionId = widget.childSessionId;
    onCalibrationComplete = () {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) widget.onCalibrationDone();
      });
    };

    // Tell the Python server to wipe the memory for this session
    resetCalibrationForNewChild().then((_) {
      if (mounted) {
        startAiCamera(captureInterval: const Duration(milliseconds: 900));
      }
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    disposeAiCamera();
    super.dispose();
  }

  Widget _buildCameraPreviewSquare() {
    final controller = aiCameraController!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 100, // SHRUNK to fit landscape screens better
        height: 100,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 100,
            height: controller.value.previewSize?.width ?? 100,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final size = MediaQuery.of(context).size;
    return Center(
      child: Container(
        width: size.width * 0.85,
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: size.height * 0.95,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7EB),
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [child],
                ),
              ),
            ),
            // THE NEW SKIP BUTTON
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded),
                color: const Color(0xFF5F7199).withValues(alpha: 0.5),
                iconSize: 28,
                onPressed: () {
                  // Manually trigger completion to bypass the screen
                  if (mounted) widget.onCalibrationDone();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsLightingPrompt =
        hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.6),
      body: _buildBodyContent(needsLightingPrompt),
    );
  }

  Widget _buildBodyContent(bool needsLightingPrompt) {
    if (needsLightingPrompt) {
      return LightingPromptCard(
        onClose: () => setState(() => _hideLightingCard = true),
      );
    }

    if (!hasCapturedFirstFrame) {
      return _buildCard(
        child: Column(
          children: [
            const SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                color: Color(0xFF5F7199),
                strokeWidth: 5,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Getting Ready...",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Color(0xFF5F7199),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Just a moment while we turn on the camera!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5E463E),
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    return _buildCard(
      child: Column(
        children: [
          if (isCameraInitialized && aiCameraController != null)
            _buildCameraPreviewSquare()
          else
            const SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(color: Color(0xFF5F7199)),
            ),
          const SizedBox(height: 12),
          const Text(
            "Say Hi to the Camera!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Color(0xFF5F7199),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Just look at the screen for a moment while we get to know you!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5E463E),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "⏱️ Calibrating: ${_elapsedSeconds}s",
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F7199),
            ),
          ),
        ],
      ),
    );
  }
}
