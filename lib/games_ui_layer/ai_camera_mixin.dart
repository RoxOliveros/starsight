import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

mixin AiCameraMixin<T extends StatefulWidget> on State<T> {
  CameraController? aiCameraController;
  Timer? _analysisTimer;
  bool isCameraInitialized = false;
  bool isFaceDetected = false;

  String sessionId = 'default';

  bool hasCapturedFirstFrame = false;

  VoidCallback? onFirstFaceDetected;

  ValueChanged<bool>? onFaceDetectionChanged;

  List<String> sessionEmotions = [];

  final String pythonServerUrl = 'http://13.68.159.132:8080/analyze';
  final String pythonResetUrl = 'http://13.68.159.132:8080/reset_calibration';

  Future<void> startAiCamera() async {
    isFaceDetected = false;
    hasCapturedFirstFrame = false;
    sessionEmotions = [];
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );

      aiCameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await aiCameraController!.initialize();
      if (mounted) {
        setState(() {
          isCameraInitialized = true;
        });

        // Start taking pictures every 3 seconds
        _analysisTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
          _captureAndAnalyzeFrame();
        });
      }
    } catch (e) {
      print("Camera Error: $e");
    }
  }

  Future<void> resetCalibrationForNewChild() async {
    try {
      await http.post(
        Uri.parse(pythonResetUrl),
        body: {'session_id': sessionId},
      );
    } catch (e) {
      print("Failed to reset calibration: $e");
    }
  }

  Future<void> _captureAndAnalyzeFrame() async {
    if (aiCameraController == null || !aiCameraController!.value.isInitialized)
      return;
    if (aiCameraController!.value.isTakingPicture) return;

    File? imageFile;
    try {
      final XFile rawImage = await aiCameraController!.takePicture();
      imageFile = File(rawImage.path);

      var request = http.MultipartRequest('POST', Uri.parse(pythonServerUrl));
      request.fields['session_id'] = sessionId;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      var response = await request.send();

      // SECURE DELETION
      if (await imageFile.exists()) await imageFile.delete();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseBody);
        String detectedEmotion = jsonResponse['emotion'];
        final faceNowDetected = detectedEmotion != "NO FACE DETECTED";
        final isFirstReading = !hasCapturedFirstFrame;
        final changed = faceNowDetected != isFaceDetected;

        if (mounted && (isFirstReading || changed)) {
          setState(() {
            hasCapturedFirstFrame = true;
            isFaceDetected = faceNowDetected;
          });
        }

        if (faceNowDetected && (isFirstReading || changed)) {
          onFirstFaceDetected?.call();
          onFirstFaceDetected = null;
        }
        if (isFirstReading || changed) {
          onFaceDetectionChanged?.call(faceNowDetected);
        }

        final isUsableReading =
            detectedEmotion != "NO FACE DETECTED" &&
            !detectedEmotion.startsWith("CALIBRATING");
        if (isUsableReading) {
          sessionEmotions.add(detectedEmotion);
        }

        print("Live Emotion: $detectedEmotion");
      }
    } catch (e) {
      // Clean up the file even if the network fails
      if (imageFile != null && await imageFile.exists())
        await imageFile.delete();
    }
  }

  List<String> stopAiCamera() {
    _analysisTimer
        ?.cancel(); // Stop taking pictures, but leave the camera on screen!
    print("GAME OVER! Final Emotions: $sessionEmotions");
    return List<String>.from(sessionEmotions);
  }

  void disposeAiCamera() {
    _analysisTimer?.cancel();
    aiCameraController?.dispose();
  }
}
