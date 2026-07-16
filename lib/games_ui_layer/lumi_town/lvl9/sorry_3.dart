import 'dart:async';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_4.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

// Adjust this import path to wherever your gesture_camera_view.dart is located
import 'package:StarSight/business_layer/gesture_camera_view.dart';

// Adjust this to wherever your next screen/level is located!
// import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_4.dart';

enum _CameraGestureState { checking, granted, denied }

class Sorry3Screen extends StatefulWidget {
  const Sorry3Screen({super.key});

  @override
  State<Sorry3Screen> createState() => _Sorry3ScreenState();
}

class _Sorry3ScreenState extends State<Sorry3Screen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;

  // --- Story Sequence State ---
  bool _showScene4 = false;
  bool _introFinished = false;
  bool _actionTaken = false;

  // --- Camera & Fallback State ---
  _CameraGestureState _cameraState = _CameraGestureState.checking;
  static const _noHandsTimeout = Duration(seconds: 8);
  Timer? _noHandsTimer;
  bool _showNoHandsPrompt = false;
  bool _forceButtonFallback = false;

  @override
  void initState() {
    super.initState();
    _setupLandscapeOrientation();
    _startStorySequence();
    _requestCameraPermission();
  }

  void _setupLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Plays Scene 3 audio -> swaps to Scene 4 at 4s mark -> finishes audio -> plays Scene 4 audio -> enables interactive UI
  Future<void> _startStorySequence() async {
    try {
      // 1. Listen to playback timestamp to trigger Scene 4 at exactly 4 seconds
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

      // 2. Play sorry_2.wav (starts on Scene 3)
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_2.wav'),
      );

      // Wait for sorry_2.wav to completely finish playing
      await _audioPlayer.onPlayerComplete.first;
      _positionSub?.cancel();
      if (!mounted) return;

      // Safety check: ensure Scene 4 is visible even if the audio was shorter than 4 seconds
      if (!_showScene4) {
        setState(() {
          _showScene4 = true;
        });
      }

      // 3. Play sorry_3.wav for Scene 4
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_3.wav'),
      );
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // 4. Enable gesture recognition or fallback buttons
      setState(() {
        _introFinished = true;
      });
    } catch (e) {
      debugPrint('Error playing story sequence: $e');
      if (mounted) setState(() => _introFinished = true);
    }
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

  void _onAnyGestureDetected() {
    _noHandsTimer?.cancel();
    _noHandsTimer = Timer(_noHandsTimeout, () {
      if (mounted) setState(() => _showNoHandsPrompt = true);
    });

    if (_showNoHandsPrompt) {
      setState(() => _showNoHandsPrompt = false);
    }
  }

  void _ensureNoHandsWatcherStarted() {
    if (_noHandsTimer != null) return;
    _noHandsTimer = Timer(_noHandsTimeout, () {
      if (mounted) setState(() => _showNoHandsPrompt = true);
    });
  }

  void _switchToButtonFallback() {
    _noHandsTimer?.cancel();
    setState(() {
      _forceButtonFallback = true;
      _showNoHandsPrompt = false;
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _audioPlayer.dispose();
    _noHandsTimer?.cancel();
    super.dispose();
  }

  Future<void> _exitLevel() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  // ============================================================================
  // UPDATED GESTURE & BUTTON ACTION HANDLERS
  // ============================================================================

  Future<void> _handleThumbsUp() async {
    if (_actionTaken) return;
    _actionTaken = true;

    _noHandsTimer?.cancel();
    _noHandsTimer = null;
    if (_showNoHandsPrompt) setState(() => _showNoHandsPrompt = false);

    debugPrint('Thumbs Up Detected / Clicked! Playing sorry_4.wav...');

    try {
      // 1. Stop any lingering audio and play the success sound
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_4.wav'),
      );

      // 2. Wait for sorry_4.wav to finish playing before leaving the screen
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      debugPrint('Error playing sorry_4.wav: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const Sorry4Screen()),
    );
  }

  Future<void> _handleThumbsDown() async {
    if (_actionTaken) return;
    _actionTaken = true;

    _noHandsTimer?.cancel();
    _noHandsTimer = null;
    if (_showNoHandsPrompt) setState(() => _showNoHandsPrompt = false);

    debugPrint('Thumbs Down Detected / Clicked! Playing try again audio...');

    try {
      // 1. Stop any lingering audio and play Dr. Woo's try again sound
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/dr.woo_tryagain.wav'),
      );

      // 2. Wait for Dr. Woo to finish speaking before letting them try again
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      debugPrint('Error playing dr.woo_tryagain.wav: $e');
    }

    if (!mounted) return;

    // 3. Reset state so the user can try showing a gesture or clicking again
    setState(() {
      _actionTaken = false;
    });
    _ensureNoHandsWatcherStarted();
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final double thumbSize = sw * 0.11;
    final double thumbBtnSize = sw * 0.135;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Scene Image (Swaps seamlessly from Scene 3 to Scene 4 at 4s)
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

          // 2. Camera Gesture Detection (Active once intro is finished)
          if (_introFinished &&
              _cameraState == _CameraGestureState.granted &&
              !_forceButtonFallback) ...[
            _HiddenGestureDetector(
              onGesture: (result) {
                _onAnyGestureDetected();
                if (result.isThumbsUp) {
                  _handleThumbsUp();
                } else if (result.isThumbsDown) {
                  _handleThumbsDown();
                }
              },
              onMounted: _ensureNoHandsWatcherStarted,
            ),

            // Instruction Banner
            Positioned(
              bottom: sh * 0.10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Show a thumbs up or thumbs down!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF5E463E),
                    ),
                  ),
                ),
              ),
            ),

            // Timeout Prompt ("We can't see your hands!")
            if (_showNoHandsPrompt)
              _NoHandsPrompt(onUseButtons: _switchToButtonFallback),

            // 3. Fallback Thumbs Up / Down Buttons (Shown if camera denied or fallback chosen)
          ] else if (_introFinished &&
              (_cameraState == _CameraGestureState.denied ||
                  _forceButtonFallback)) ...[
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
                        imagePath: 'assets/images/objects/lumi/thumbs_down.png',
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
          ],

          // 4. Close Button (Top Left)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: _exitLevel,
                  child: Image.asset(
                    'assets/images/buttons/x_blue.png',
                    width: 50,
                    height: 50,
                    errorBuilder: (ctx, err, st) => Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF266589),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

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

class _NoHandsPrompt extends StatelessWidget {
  final VoidCallback onUseButtons;

  const _NoHandsPrompt({required this.onUseButtons});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7EB),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "We can't see your hands!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFFE8A037),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Try showing your thumb again, or use the buttons instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5E463E),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: onUseButtons,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF266589),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Use buttons instead',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
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
