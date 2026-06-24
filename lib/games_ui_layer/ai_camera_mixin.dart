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

  List<String> sessionEmotions = [];

  final String pythonServerUrl = 'http://13.68.159.132:8080/analyze';

  Future<void> startAiCamera() async {
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

        // ---> NEW FACE TRACKING LOGIC <---
        if (detectedEmotion == "NO FACE DETECTED") {
          if (isFaceDetected) {
            setState(() => isFaceDetected = false); // Show the prompt
          }
        } else {
          if (!isFaceDetected) {
            setState(() => isFaceDetected = true); // Hide the prompt
          }
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
