import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../business_layer/audio_settings.dart';

mixin AiCameraMixin<T extends StatefulWidget> on State<T> {
  CameraController? aiCameraController;
  Future<void>? _cameraInitFuture;
  Timer? _analysisTimer;
  bool isCameraInitialized = false;

  bool isFaceDetected = false;
  bool _isCameraDisposed = false;

  String sessionId = 'default';

  bool hasCapturedFirstFrame = false;

  VoidCallback? onFirstFaceDetected;

  ValueChanged<bool>? onFaceDetectionChanged;

  VoidCallback? onCalibrationComplete;
  bool _hasFiredCalibrationComplete = false;

  int calibrationProgress = 0;
  int calibrationNeeded = 15;

  List<String> sessionEmotions = [];

  final String pythonServerUrl = 'http://13.68.159.132:8080/analyze';
  final String pythonResetUrl = 'http://13.68.159.132:8080/reset_calibration';

  final Duration _serverTimeout = const Duration(seconds: 8);

  bool _isCapturing = false;
  static Future<void>? _cameraReleaseFuture;

  // ── Fast calibration (image stream) ──────────────────────────────────────
  // During calibration only, frames come from startImageStream instead of
  // takePicture(). We still send at most one frame every 0.6 s: the server
  // switches to its "dense" (video-rate) logic when frames arrive faster than
  // 0.5 s apart, and we don't want it flipping modes mid-calibration.
  static const Duration _calibrationSendGap = Duration(milliseconds: 600);
  bool _streaming = false;
  DateTime _lastStreamSend = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _captureInterval = const Duration(seconds: 3);

  // ── Face-aware tutorial audio ────────────────────────────────────────────
  Completer<void>? _activeVoiceInterrupt;
  AudioPlayer? _activeVoicePlayer;
  Completer<void>? _faceReturnGate;

  Future<void> playVoiceRestartingOnFaceLoss(
    AudioPlayer player,
    String asset, {
    Duration timeout = const Duration(seconds: 33),
  }) async {
    while (mounted && !_isCameraDisposed) {
      // Don't start a tutorial clip while the lighting card is waiting.
      final pending = _faceReturnGate;
      if (pending != null && !pending.isCompleted) {
        await pending.future;
        if (!mounted || _isCameraDisposed) return;
      }

      final interrupt = Completer<void>();
      final done = Completer<void>();
      StreamSubscription? sub;
      var interrupted = false;
      try {
        sub = player.onPlayerComplete.listen((_) {
          if (!done.isCompleted) done.complete();
        });
        _activeVoiceInterrupt = interrupt;
        _activeVoicePlayer = player;
        await player.play(
          AssetSource(asset.replaceFirst('assets/', '')),
          volume: AudioSettings.instance.gamesVolume,
        );
        await Future.any([done.future.timeout(timeout), interrupt.future]);
        interrupted = interrupt.isCompleted;
      } catch (e) {
        print('Voice audio error ($asset): $e');
      } finally {
        if (identical(_activeVoiceInterrupt, interrupt)) {
          _activeVoiceInterrupt = null;
          _activeVoicePlayer = null;
        }
        await sub?.cancel();
      }

      if (!interrupted) return; // finished normally -> done
      // interrupted -> loop back: waits for the face, then replays.
    }
  }

  void _handleFaceChangeForVoice(bool faceNowDetected) {
    if (faceNowDetected) {
      releaseFaceGate();
      return;
    }
    final gate = _faceReturnGate;
    if (gate == null || gate.isCompleted) _faceReturnGate = Completer<void>();

    final interrupt = _activeVoiceInterrupt;
    if (interrupt != null && !interrupt.isCompleted) {
      _activeVoicePlayer?.stop().catchError((_) {});
      interrupt.complete();
    }
  }

  /// Lets held tutorial audio continue. Called automatically when the face
  /// returns; also call it when the lighting card is dismissed with the X.
  void releaseFaceGate() {
    final gate = _faceReturnGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  Future<void> startAiCamera({
    Duration captureInterval = const Duration(seconds: 3),
    bool fastCalibration = false,
  }) async {
    _captureInterval = captureInterval;
    _isCameraDisposed = false;
    isFaceDetected = false;
    hasCapturedFirstFrame = false;
    sessionEmotions = [];

    // Let the previous screen's camera fully let go of the hardware first
    // (capped, so a stuck release can never block this screen forever).
    final pendingRelease = _cameraReleaseFuture;
    if (pendingRelease != null) {
      try {
        await pendingRelease.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    if (_isCameraDisposed) return;

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );

      aiCameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _cameraInitFuture = aiCameraController!.initialize();
      await _cameraInitFuture;
      if (_isCameraDisposed) return;
      if (mounted) {
        setState(() {
          isCameraInitialized = true;
        });

        if (fastCalibration && !_hasFiredCalibrationComplete) {
          await _startCalibrationStream();
        } else {
          _startPeriodicTimer();
        }
      }
    } catch (e) {
      print("Camera Error: $e");

      // PERMISSION FALLBACK
      // This forces the game to start even if the emulator blocks the camera
      _applyOfflineFallback();
    }
  }

  void _startPeriodicTimer() {
    if (_isCameraDisposed || _analysisTimer != null) return;
    _analysisTimer = Timer.periodic(_captureInterval, (timer) {
      _captureAndAnalyzeFrame();
    });
  }

  /// Lets the app continue when the camera/server can't be used.
  void _applyOfflineFallback() {
    if (mounted && !_isCameraDisposed && !hasCapturedFirstFrame) {
      setState(() {
        hasCapturedFirstFrame = true;
        isFaceDetected = true;
      });
      onFirstFaceDetected?.call();
      onFirstFaceDetected = null;
      _fireCalibrationComplete();
    }
  }

  void _fireCalibrationComplete() {
    if (_hasFiredCalibrationComplete) return;
    _hasFiredCalibrationComplete = true;
    onCalibrationComplete?.call();
    _endCalibrationStream();
  }

  // ── Image-stream calibration ─────────────────────────────────────────────
  Future<void> _startCalibrationStream() async {
    final controller = aiCameraController;
    if (controller == null || _streaming) return;
    _streaming = true;
    try {
      await controller.startImageStream(_onStreamFrame);
    } catch (e) {
      print("Image stream failed, using takePicture instead: $e");
      _streaming = false;
      _startPeriodicTimer();
    }
  }

  /// Stops the stream and hands over to the normal takePicture timer.
  Future<void> _endCalibrationStream() async {
    if (_streaming) {
      _streaming = false;
      try {
        await aiCameraController?.stopImageStream();
      } catch (_) {}
    }
    if (mounted && !_isCameraDisposed) _startPeriodicTimer();
  }

  void _onStreamFrame(CameraImage image) {
    if (_isCameraDisposed || !_streaming || _isCapturing) return;
    final now = DateTime.now();
    if (now.difference(_lastStreamSend) < _calibrationSendGap) return;

    // Unexpected pixel format (not 3-plane YUV420) -> give up on streaming.
    if (image.planes.length != 3) {
      print("Unsupported stream format (${image.planes.length} planes)");
      _endCalibrationStream();
      return;
    }

    _lastStreamSend = now;
    _isCapturing = true;
    _sendStreamFrame(image);
  }

  /// Rotation (clockwise degrees) that makes the raw sensor frame upright.
  int _streamRotation() {
    final controller = aiCameraController;
    if (controller == null) return 0;
    final sensor = controller.description.sensorOrientation;
    final deviceDeg = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final isFront =
        controller.description.lensDirection == CameraLensDirection.front;
    return isFront
        ? (sensor + deviceDeg) % 360
        : (sensor - deviceDeg + 360) % 360;
  }

  Future<void> _sendStreamFrame(CameraImage image) async {
    try {
      final jpeg = await compute(_yuv420ToJpeg, <String, dynamic>{
        'w': image.width,
        'h': image.height,
        'y': image.planes[0].bytes,
        'u': image.planes[1].bytes,
        'v': image.planes[2].bytes,
        'yRow': image.planes[0].bytesPerRow,
        'uvRow': image.planes[1].bytesPerRow,
        'uvPix': image.planes[1].bytesPerPixel ?? 1,
        'rotation': _streamRotation(),
      });
      if (_isCameraDisposed || !mounted) return;

      final request = http.MultipartRequest('POST', Uri.parse(pythonServerUrl));
      request.fields['session_id'] = sessionId;
      request.files.add(
        http.MultipartFile.fromBytes('image', jpeg, filename: 'frame.jpg'),
      );
      final response = await request.send().timeout(_serverTimeout);
      if (_isCameraDisposed || !mounted) return;

      await _handleAnalysisResponse(response);
    } catch (e) {
      print("NETWORK ERROR (stream): $e");
      _applyOfflineFallback();
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> resetCalibrationForNewChild() async {
    try {
      await http
          .post(Uri.parse(pythonResetUrl), body: {'session_id': sessionId})
          .timeout(_serverTimeout);
    } catch (e) {
      print("Failed to reset calibration: $e");
    }
  }

  Future<void> _captureAndAnalyzeFrame() async {
    if (_isCameraDisposed) return;
    if (aiCameraController == null ||
        !aiCameraController!.value.isInitialized) {
      return;
    }
    if (aiCameraController!.value.isTakingPicture) return;
    if (_isCapturing) return;
    _isCapturing = true;

    File? imageFile;
    try {
      final XFile rawImage = await aiCameraController!.takePicture();
      if (_isCameraDisposed || !mounted) return;
      imageFile = File(rawImage.path);

      var request = http.MultipartRequest('POST', Uri.parse(pythonServerUrl));
      request.fields['session_id'] = sessionId;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      var response = await request.send().timeout(_serverTimeout);
      if (_isCameraDisposed || !mounted) return;

      // SECURE DELETION
      if (await imageFile.exists()) await imageFile.delete();

      await _handleAnalysisResponse(response);
    } catch (e) {
      // ADD THIS LINE TO SEE THE REAL ERROR IN YOUR TERMINAL:
      print("NETWORK ERROR: $e");

      // Clean up the file even if the network fails
      if (imageFile != null && await imageFile.exists()) {
        await imageFile.delete();
      }

      // OFFLINE FALLBACK
      _applyOfflineFallback();
    } finally {
      _isCapturing = false;
    }
  }

  /// Reads the server's JSON reply and updates face/calibration state.
  Future<void> _handleAnalysisResponse(http.StreamedResponse response) async {
    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }
    String responseBody = await response.stream.bytesToString().timeout(
      _serverTimeout,
    );
    var jsonResponse = jsonDecode(responseBody);

    String detectedEmotion =
        jsonResponse['emotion']?.toString() ??
        jsonResponse['label']?.toString() ??
        "NO FACE DETECTED";

    final faceNowDetected = detectedEmotion != "NO FACE DETECTED";
    final isFirstReading = !hasCapturedFirstFrame;
    final changed = faceNowDetected != isFaceDetected;

    if (mounted && !_isCameraDisposed && (isFirstReading || changed)) {
      setState(() {
        hasCapturedFirstFrame = true;
        isFaceDetected = faceNowDetected;
      });
    }

    // FIX 2: Check both the root JSON and the 'debug' dictionary for progress
    var debugMap = jsonResponse['debug'] as Map<String, dynamic>?;
    int? parsedProgress =
        jsonResponse['calibration_progress'] as int? ??
        debugMap?['calibration_progress'] as int?;
    int? parsedNeeded =
        jsonResponse['calibration_needed'] as int? ??
        debugMap?['calibration_needed'] as int?;

    if (parsedProgress != null && mounted && !_isCameraDisposed) {
      if (parsedProgress != calibrationProgress ||
          parsedNeeded != calibrationNeeded) {
        setState(() {
          calibrationProgress = parsedProgress;
          calibrationNeeded = parsedNeeded ?? calibrationNeeded;
        });
      }
    }

    if (faceNowDetected && (isFirstReading || changed)) {
      onFirstFaceDetected?.call();
      onFirstFaceDetected = null;
    }
    if (isFirstReading || changed) {
      _handleFaceChangeForVoice(faceNowDetected);
      onFaceDetectionChanged?.call(faceNowDetected);
    }

    final isUsableReading =
        detectedEmotion != "NO FACE DETECTED" &&
        !detectedEmotion.startsWith("CALIBRATING");

    if (isUsableReading) {
      sessionEmotions.add(detectedEmotion);
      _fireCalibrationComplete();
    }

    print("Live Output: $detectedEmotion");
  }

  List<String> stopAiCamera() {
    releaseFaceGate();
    if (_isCameraDisposed) return List<String>.from(sessionEmotions);
    _analysisTimer?.cancel();
    _analysisTimer = null;
    if (_streaming) {
      _streaming = false;
      aiCameraController?.stopImageStream().catchError((_) {});
    }
    print("GAME OVER! Final Emotions: $sessionEmotions");
    return List<String>.from(sessionEmotions);
  }

  void disposeAiCamera() {
    _isCameraDisposed = true;
    releaseFaceGate();
    _analysisTimer?.cancel();
    _analysisTimer = null;
    final wasStreaming = _streaming;
    _streaming = false;
    final controller = aiCameraController;
    final initFuture = _cameraInitFuture;
    aiCameraController = null;
    _cameraInitFuture = null;
    if (controller == null) return;

    _cameraReleaseFuture = () async {
      if (initFuture != null) {
        try {
          await initFuture;
        } catch (_) {
          return;
        }
      }

      var waited = 0;
      while (_isCapturing && waited < 3000) {
        await Future.delayed(const Duration(milliseconds: 50));
        waited += 50;
      }

      if (wasStreaming) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }

      try {
        await controller.dispose();
      } catch (_) {}
    }();
  }
}

/// Converts one YUV420 camera frame to an upright JPEG.
/// Top-level so it can run in a background isolate via compute().
Uint8List _yuv420ToJpeg(Map<String, dynamic> a) {
  final int w = a['w'];
  final int h = a['h'];
  final Uint8List yP = a['y'];
  final Uint8List uP = a['u'];
  final Uint8List vP = a['v'];
  final int yRow = a['yRow'];
  final int uvRow = a['uvRow'];
  final int uvPix = a['uvPix'];
  final int rotation = a['rotation'];

  final out = img.Image(width: w, height: h);
  for (var row = 0; row < h; row++) {
    final yBase = row * yRow;
    final uvBase = (row >> 1) * uvRow;
    for (var col = 0; col < w; col++) {
      final uvIdx = uvBase + (col >> 1) * uvPix;
      final yy = yP[yBase + col];
      final uu = uP[uvIdx] - 128;
      final vv = vP[uvIdx] - 128;
      out.setPixelRgb(
        col,
        row,
        (yy + 1.402 * vv).round().clamp(0, 255),
        (yy - 0.344136 * uu - 0.714136 * vv).round().clamp(0, 255),
        (yy + 1.772 * uu).round().clamp(0, 255),
      );
    }
  }
  final upright = rotation == 0 ? out : img.copyRotate(out, angle: rotation);
  return Uint8List.fromList(img.encodeJpg(upright, quality: 80));
}