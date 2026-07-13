import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single detected gesture from the native MediaPipe recognizer.
class GestureResult {
  final String gesture; // e.g. "Thumb_Up", "Thumb_Down", "None"
  final double confidence;
  final int timestampMs;

  GestureResult({
    required this.gesture,
    required this.confidence,
    required this.timestampMs,
  });

  factory GestureResult.fromMap(Map<dynamic, dynamic> map) {
    return GestureResult(
      gesture: map['gesture'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      timestampMs: map['timestampMs'] as int,
    );
  }

  bool get isThumbsUp => gesture == 'Thumb_Up';
  bool get isThumbsDown => gesture == 'Thumb_Down';
}

/// Embeds the native camera + MediaPipe gesture recognizer view, and exposes
/// a debounced stream of stable gesture detections via [onGesture].
///
/// Debouncing matters because raw per-frame output flickers — a hand moving
/// into position might register a stray "Thumb_Up" for one frame. This only
/// fires a callback once the same gesture has been seen for
/// [requiredConsecutiveFrames] frames in a row.
class GestureCameraView extends StatefulWidget {
  static const _eventChannel = EventChannel(
    'com.example.starsight/gesture_events',
  );
  static const _viewType = 'com.example.starsight/gesture_camera_view';

  final void Function(GestureResult result) onGesture;
  final double minConfidence;
  final int requiredConsecutiveFrames;

  const GestureCameraView({
    super.key,
    required this.onGesture,
    this.minConfidence = 0.7,
    this.requiredConsecutiveFrames = 4,
  });

  @override
  State<GestureCameraView> createState() => _GestureCameraViewState();
}

class _GestureCameraViewState extends State<GestureCameraView> {
  StreamSubscription? _subscription;
  String? _lastGesture;
  int _consecutiveCount = 0;
  String? _lastFiredGesture;

  @override
  void initState() {
    super.initState();
    _subscription = GestureCameraView._eventChannel
        .receiveBroadcastStream()
        .listen(
          _handleEvent,
          onError: (error) {
            debugPrint('Gesture stream error: $error');
          },
        );
  }

  void _handleEvent(dynamic event) {
    final result = GestureResult.fromMap(event as Map<dynamic, dynamic>);

    if (result.confidence < widget.minConfidence) {
      _consecutiveCount = 0;
      _lastGesture = null;
      return;
    }

    if (result.gesture == _lastGesture) {
      _consecutiveCount++;
    } else {
      _lastGesture = result.gesture;
      _consecutiveCount = 1;
    }

    // Only fire once the gesture has been stable for N frames, and don't
    // keep re-firing the same gesture every frame after that.
    if (_consecutiveCount >= widget.requiredConsecutiveFrames &&
        _lastFiredGesture != result.gesture) {
      _lastFiredGesture = result.gesture;
      widget.onGesture(result);
    }

    // Reset "already fired" once the gesture goes back to None, so the same
    // gesture can be detected again later (e.g. thumbs up -> down -> up).
    if (result.gesture == 'None') {
      _lastFiredGesture = null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AndroidView embeds the native PlatformView (camera preview + detector).
    // Remember: you must have already requested camera permission before
    // showing this widget (e.g. via the permission_handler package).
    return const AndroidView(
      viewType: GestureCameraView._viewType,
      creationParams: <String, dynamic>{},
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}

/// Example usage:
///
/// ```dart
/// GestureCameraView(
///   onGesture: (result) {
///     if (result.isThumbsUp) {
///       // e.g. mark the current activity as "correct" / "yes"
///     } else if (result.isThumbsDown) {
///       // e.g. mark it "incorrect" / "no"
///     }
///   },
/// )
/// ```
