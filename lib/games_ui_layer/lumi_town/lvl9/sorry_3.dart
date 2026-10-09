import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_4.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:StarSight/business_layer/gesture_camera_view.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../games_audio_helper.dart';
import '../lumi_game_ui_layer.dart';

enum _CameraGestureState { checking, granted, denied }

class Sorry3Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Sorry3Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Sorry3Screen> createState() => _Sorry3ScreenState();
}

class _Sorry3ScreenState extends State<Sorry3Screen>
    with AiCameraMixin<Sorry3Screen>, AppAudioLifecycleMixin<Sorry3Screen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  bool _showScene4 = false;
  bool _introFinished = false;
  bool _actionTaken = false;
  bool _hideLightingCard = false;

  _CameraGestureState _cameraState = _CameraGestureState.checking;
  static const _noHandsTimeout = Duration(seconds: 8);
  Timer? _noHandsTimer;
  bool _showButtons = false;

  final Completer<void> _promptDone = Completer<void>();

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _startStorySequence();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _cameraState = status.isGranted
          ? _CameraGestureState.granted
          : _CameraGestureState.denied;
    });
  }

  Future<void> _startStorySequence() async {
    try {
      _positionSub = _audioPlayer.onPositionChanged.listen((position) {
        if (position >= const Duration(seconds: 4) && !_showScene4) {
          if (mounted) {
            setState(() {
              _showScene4 = true;
            });
          }
          _positionSub?.cancel();
        }
      });

      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level9/sorry_2.wav');
      await waitForAudio(_audioPlayer);    
      _positionSub?.cancel();
      if (!mounted) return;

      if (!_showScene4) {
        setState(() {
          _showScene4 = true;
        });
      }

      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level9/sorry_3.wav');
      await waitForAudio(_audioPlayer);    
      if (!mounted) return;

      setState(() {
        _introFinished = true;
      });
      await _playThumbsPrompt();
    } catch (e) {
      debugPrint('Error playing story sequence: $e');
      if (mounted) setState(() => _introFinished = true);
      if (!_promptDone.isCompleted) _promptDone.complete();
    }
  }

  Future<void> _playThumbsPrompt() async {
    try {
      final done = _audioPlayer.onPlayerComplete.first;
      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/thumbsup_thumbsdown.wav');
      await done;
    } catch (e) {
      debugPrint('Error playing thumbsup_thumbsdown.wav: $e');
    } finally {
      if (!_promptDone.isCompleted) _promptDone.complete();
      _startNoHandsTimer();
    }
  }

  void _startNoHandsTimer() {
    _noHandsTimer?.cancel();
    if (_showButtons || !mounted || !_promptDone.isCompleted) return;
    _noHandsTimer = Timer(_noHandsTimeout, () {
      if (mounted) setState(() => _showButtons = true);
    });
  }

  @override
  void dispose() {
    disposeAiCamera();
    _positionSub?.cancel();
    _audioPlayer.dispose();
    _noHandsTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleThumbsUp() async {
    if (_actionTaken) return;
    _actionTaken = true;

    await _promptDone.future;
    if (!mounted) return;

    widget.tapTracker.recordCorrectTap();

    _noHandsTimer?.cancel();
    _noHandsTimer = null;

    try {
      await _audioPlayer.stop();
      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level9/sorry_4.wav');
      await waitForAudio(_audioPlayer);    
    } catch (e) {
      debugPrint('Error playing sorry_4.wav: $e');
    }

    if (!mounted) return;

    final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => Sorry4Screen(
          priorEmotions: emotionsSoFar,
          tapTracker: widget.tapTracker,
          level: widget.level,
        ),
      ),
    );
  }

  Future<void> _handleThumbsDown() async {
    if (_actionTaken) return;
    _actionTaken = true;

    await _promptDone.future;
    if (!mounted) return;

    widget.tapTracker.recordMistake();

    _noHandsTimer?.cancel();
    _noHandsTimer = null;

    try {
      await _audioPlayer.stop();
      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/dr.woo_tryagain.wav');
      await waitForAudio(_audioPlayer);    
    } catch (e) {
      debugPrint('Error playing dr.woo_tryagain.wav: $e');
    }

    if (!mounted) return;

    setState(() {
      _actionTaken = false;
    });
    _startNoHandsTimer();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final double thumbSize = sw * 0.11;
    final double thumbBtnSize = sw * 0.135;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _showScene4
                  ? 'assets/images/objects/lumi/lvl9_scene4.png'
                  : 'assets/images/objects/lumi/lvl9_scene3.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => const Center(
                child: Text(
                  'Scene asset could not be loaded.',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),

            if (_introFinished && _cameraState == _CameraGestureState.granted)
              _HiddenGestureDetector(
                onGesture: (result) {
                  _startNoHandsTimer();
                  if (result.isThumbsUp) {
                    _handleThumbsUp();
                  } else if (result.isThumbsDown) {
                    _handleThumbsDown();
                  }
                },
                onMounted: _startNoHandsTimer,
              ),

            if (_introFinished &&
                (_showButtons || _cameraState == _CameraGestureState.denied))
              Positioned(
                bottom: sh * 0.10,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _handleThumbsUp,
                        child: _ThumbButton(
                          imagePath: 'assets/images/objects/lumi/thumbs_up.png',
                          backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                          size: thumbBtnSize,
                          iconSize: thumbSize,
                          animDelay: Duration.zero,
                        ),
                      ),
                      SizedBox(width: sw * 0.04),
                      GestureDetector(
                        onTap: _handleThumbsDown,
                        child: _ThumbButton(
                          imagePath:
                              'assets/images/objects/lumi/thumbs_down.png',
                          backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                          size: thumbBtnSize,
                          iconSize: thumbSize,
                          animDelay: const Duration(milliseconds: 400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LumiLevelBadge(level: widget.level),
            ),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HiddenGestureDetector extends StatefulWidget {
  final void Function(GestureResult result) onGesture;
  final VoidCallback onMounted;

  const _HiddenGestureDetector({
    required this.onGesture,
    required this.onMounted,
  });

  @override
  State<_HiddenGestureDetector> createState() => _HiddenGestureDetectorState();
}

class _HiddenGestureDetectorState extends State<_HiddenGestureDetector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMounted());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.0,
          child: SizedBox(
            width: 4,
            height: 4,
            child: GestureCameraView(onGesture: widget.onGesture),
          ),
        ),
      ),
    );
  }
}

class _ThumbButton extends StatelessWidget {
  final String imagePath;
  final Color backgroundColor;
  final double size;
  final double iconSize;
  final Duration animDelay;

  const _ThumbButton({
    required this.imagePath,
    required this.backgroundColor,
    required this.size,
    required this.iconSize,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(size * 0.10),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) => Icon(
              imagePath.contains('up') ? Icons.thumb_up : Icons.thumb_down,
              color: Colors.white,
              size: iconSize * 0.7,
            ),
          ),
        )
        .animate(delay: animDelay, onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.06, 1.06),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
  }
}
