import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ActivitySessionScreen extends StatefulWidget {
  final String activityName;

  const ActivitySessionScreen({super.key, required this.activityName});

  @override
  State<ActivitySessionScreen> createState() => _ActivitySessionScreenState();
}

class _ActivitySessionScreenState extends State<ActivitySessionScreen> {
  CameraController? _cameraController;
  Timer? _analysisTimer;
  bool _isCameraInitialized = false;

  // This list collects the emotions to send to Gemini later!
  List<String> _sessionEmotions = [];

  final String pythonServerUrl = 'http://13.68.159.132:8080/analyze';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // 1. Find the front-facing camera
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      // 2. Set up the camera (Low resolution is faster for network sending)
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _startAnalysisLoop(); // Start taking pictures!
      }
    } catch (e) {
      print("Error initializing camera: \$e");
    }
  }

  void _startAnalysisLoop() {
    // Fire the camera every 3 seconds
    _analysisTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _captureAndAnalyzeFrame();
    });
  }

  Future<void> _captureAndAnalyzeFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (_cameraController!.value.isTakingPicture) return;

    File? imageFile;

    try {
      // 1. Take the picture
      final XFile rawImage = await _cameraController!.takePicture();
      imageFile = File(rawImage.path);

      // 2. Send the picture to the Python Server
      var request = http.MultipartRequest('POST', Uri.parse(pythonServerUrl));
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      var response = await request.send();

      // 3. SECURE DELETION: Data Privacy Act 2012 Compliance!
      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      // 4. Save the result to our list
      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseBody);

        String detectedEmotion = jsonResponse['emotion'];
        _sessionEmotions.add(detectedEmotion);

        // Print it to the console so you can see it working!
        print("AI Detected: \$detectedEmotion");
      }
    } catch (e) {
      print("Network Error: Make sure Python server is running! \$e");
      // Clean up the file even if the network fails
      if (imageFile != null && await imageFile.exists()) {
        await imageFile.delete();
      }
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _cameraController?.dispose();

    // When the screen closes, print the final list we will send to Gemini
    print("SESSION OVER. Collected emotions: \$_sessionEmotions");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7EB),
      appBar: AppBar(
        title: Text("Playing: \${widget.activityName}"),
        backgroundColor: const Color(0xFFFACC58),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videogame_asset,
              size: 80,
              color: Color(0xFF4C89C3),
            ),
            const SizedBox(height: 20),
            const Text(
              "Your child is playing the game!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // A tiny preview so you can make sure the camera works during testing
            _isCameraInitialized
                ? SizedBox(
                    width: 100,
                    height: 150,
                    child: CameraPreview(_cameraController!),
                  )
                : const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
