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

  VoidCallback? onCalibrationComplete;
  bool _hasFiredCalibrationComplete = false;

  int calibrationProgress = 0;
  int calibrationNeeded = 30;

  List<String> sessionEmotions = [];

  final String pythonServerUrl = 'http://13.68.159.132:8080/analyze';
  final String pythonResetUrl = 'http://13.68.159.132:8080/reset_calibration';

  Future<void> startAiCamera({
    Duration captureInterval = const Duration(seconds: 3),
  }) async {
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

        _analysisTimer = Timer.periodic(captureInterval, (timer) {
          _captureAndAnalyzeFrame();
        });
      }
    } catch (e) {
      print("Camera Error: $e");

      // PERMISSION FALLBACK
      // This forces the game to start even if the emulator blocks the camera
      if (mounted && !hasCapturedFirstFrame) {
        setState(() {
          hasCapturedFirstFrame = true;
          isFaceDetected = true;
        });
        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;

        if (!_hasFiredCalibrationComplete) {
          _hasFiredCalibrationComplete = true;
          onCalibrationComplete?.call();
        }
      }
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

        if (jsonResponse['calibration_progress'] != null) {
          final newProgress = jsonResponse['calibration_progress'] as int;
          final newNeeded =
              jsonResponse['calibration_needed'] as int? ?? calibrationNeeded;
          if (mounted &&
              (newProgress != calibrationProgress ||
                  newNeeded != calibrationNeeded)) {
            setState(() {
              calibrationProgress = newProgress;
              calibrationNeeded = newNeeded;
            });
          }
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
          if (!_hasFiredCalibrationComplete) {
            _hasFiredCalibrationComplete = true;
            onCalibrationComplete?.call();
          }
        }

        print("Live Emotion: $detectedEmotion");
      }
    } catch (e) {
      // Clean up the file even if the network fails
      if (imageFile != null && await imageFile.exists()) {
        await imageFile.delete();
      }

      // OFFLINE FALLBACK
      if (mounted && !hasCapturedFirstFrame) {
        setState(() {
          hasCapturedFirstFrame = true;
          isFaceDetected = true;
        });

        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;

        if (!_hasFiredCalibrationComplete) {
          _hasFiredCalibrationComplete = true;
          onCalibrationComplete?.call();
        }
      }
    }
  }

  List<String> stopAiCamera() {
    _analysisTimer?.cancel();
    print("GAME OVER! Final Emotions: $sessionEmotions");
    return List<String>.from(sessionEmotions);
  }

  void disposeAiCamera() {
    _analysisTimer?.cancel();
    aiCameraController?.dispose();
  }
}
