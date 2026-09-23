import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  int calibrationNeeded = 30;

  List<String> sessionEmotions = [];

  final String pythonServerUrl = 'http://13.68.159.132:8080/analyze';
  final String pythonResetUrl = 'http://13.68.159.132:8080/reset_calibration';

  /// If the analysis server is slow or unreachable, give up on that request
  /// instead of hanging (and piling up uploads). A timeout takes the same
  /// path as any network error, so the game is never held up by it.
  final Duration _serverTimeout = const Duration(seconds: 8);

  // ── Face-aware tutorial audio ────────────────────────────────────────────
  Completer<void>? _activeVoiceInterrupt;
  AudioPlayer? _activeVoicePlayer;
  Completer<void>? _faceReturnGate;

  Future<void> playVoiceRestartingOnFaceLoss(
    AudioPlayer player,
    String asset, {
    Duration timeout = const Duration(seconds: 20),
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
        await player.play(AssetSource(asset.replaceFirst('assets/', '')));
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
  }) async {
    _isCameraDisposed = false;
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

      _cameraInitFuture = aiCameraController!.initialize();
      await _cameraInitFuture;
      if (_isCameraDisposed) return;
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

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString().timeout(
          _serverTimeout,
        );
        var jsonResponse = jsonDecode(responseBody);
        String detectedEmotion = jsonResponse['emotion'];
        final faceNowDetected = detectedEmotion != "NO FACE DETECTED";
        final isFirstReading = !hasCapturedFirstFrame;
        final changed = faceNowDetected != isFaceDetected;

        if (mounted && !_isCameraDisposed && (isFirstReading || changed)) {
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
              !_isCameraDisposed &&
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
          _handleFaceChangeForVoice(faceNowDetected);
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
      if (mounted && !_isCameraDisposed && !hasCapturedFirstFrame) {
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
    releaseFaceGate();
    if (_isCameraDisposed) return List<String>.from(sessionEmotions);
    _analysisTimer?.cancel();
    print("GAME OVER! Final Emotions: $sessionEmotions");
    return List<String>.from(sessionEmotions);
  }

  void disposeAiCamera() {
    _isCameraDisposed = true;
    releaseFaceGate();
    _analysisTimer?.cancel();
    final controller = aiCameraController;
    final initFuture = _cameraInitFuture;
    aiCameraController = null;
    _cameraInitFuture = null;
    if (controller == null) return;

    () async {
      if (initFuture != null) {
        try {
          await initFuture;
        } catch (_) {
          return;
        }
      }
      try {
        await controller.dispose();
      } catch (_) {
      }
    }();
  }
}
