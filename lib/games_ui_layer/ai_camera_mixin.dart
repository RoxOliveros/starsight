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

  /// True once we've gotten at least one real reading back from the AI
  /// server this screen. Lets consumers tell "camera hasn't reported yet"
  /// apart from "camera reported no face" — the first is silence, the
  /// second is a real signal worth showing something for.
  bool hasCapturedFirstFrame = false;

  /// Fires once, the first time a face is ever detected on this screen.
  VoidCallback? onFirstFaceDetected;

  /// Fires on every confirmed detection result (including the first),
  /// with the current value. Unlike [onFirstFaceDetected], this keeps
  /// firing for the life of the screen — use it to react to a face being
  /// lost or regained mid-session, not just the first time.
  ValueChanged<bool>? onFaceDetectionChanged;

  List<String> sessionEmotions = [];

  final String pythonServerUrl = 'http://13.68.159.132:8080/analyze';

  Future<void> startAiCamera() async {
    // Reset per-screen: a face detected on a previous screen (or an
    // earlier hot reload) must not carry over and silently suppress
    // this screen's own lighting/face check.
    isFaceDetected = false;
    hasCapturedFirstFrame = false;
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

  Future<void> _captureAndAnalyzeFrame() async {
    if (aiCameraController == null || !aiCameraController!.value.isInitialized)
      return;
    if (aiCameraController!.value.isTakingPicture) return;

    File? imageFile;
    try {
      final XFile rawImage = await aiCameraController!.takePicture();
      imageFile = File(rawImage.path);

      var request = http.MultipartRequest('POST', Uri.parse(pythonServerUrl));
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

        sessionEmotions.add(detectedEmotion);
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
    return sessionEmotions;
  }

  void disposeAiCamera() {
    _analysisTimer?.cancel();
    aiCameraController?.dispose();
  }
}
