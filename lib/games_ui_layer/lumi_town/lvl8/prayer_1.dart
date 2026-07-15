import 'dart:async';
import 'package:StarSight/business_layer/gesture_camera_view.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'prayer_prompt_card.dart';

class Prayer1 extends StatefulWidget {
  const Prayer1({super.key});

  @override
  State<Prayer1> createState() => _Prayer1State();
}

class _Prayer1State extends State<Prayer1> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Track which scene is currently active
  String _currentScene = 'assets/images/objects/lumi/lvl8_scene1.png';

  // Timers
  Timer? _scene2Timer;
  Timer? _scene3Timer;
  Timer? _promptTimer; // Timer to trigger the helpful prompt

  // State flags for interactive gesture logic
  bool _hasCameraPermission = false;
  bool _isWaitingForPrayerGesture = false;
  bool _gestureDetected = false;
  bool _showPromptCard = false; // Controls whether the prompt card is visible
  bool _showGoodJob = false; // Controls whether the Good Job overlay is shown

  @override
  void initState() {
    super.initState();

    // Force Landscape & Immersive Full-Screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initializeSequence();
  }

  Future<void> _initializeSequence() async {
    // 1. Check if camera permission is granted
    final status = await Permission.camera.request();

    if (mounted) {
      setState(() {
        _hasCameraPermission = status.isGranted;
      });
    }

    // 2. Play the first prayer audio immediately
    await _audioPlayer.play(AssetSource('audio/lumi_town/level8/pray_1.wav'));

    // 3. Scene2 at 4s, scene3 at 9s — purely visual pacing that plays out
    // during the narration, independent of gesture detection. If the child
    // does the praying gesture at any point before these fire,
    // _onGestureDetected cancels both timers and jumps straight to scene4.
    _scene2Timer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _gestureDetected) return;

      setState(() {
        _currentScene = 'assets/images/objects/lumi/lvl8_scene2.png';
      });

      _scene3Timer = Timer(const Duration(seconds: 5), () {
        if (!mounted || _gestureDetected) return;
        setState(() {
          _currentScene = 'assets/images/objects/lumi/lvl8_scene3.png';
        });
      });
    });

    // 4. Wait for pray_1 to actually finish playing before turning on
    // gesture detection or arming the prompt timer. This guarantees the
    // prompt (and the ability to trigger scene4) can never appear while the
    // child is still mid-narration or still looking at scene2/scene3 — it
    // only kicks in once they've heard the full instruction.
    await _audioPlayer.onPlayerComplete.first;
    if (!mounted || _gestureDetected) return;

    if (_hasCameraPermission) {
      setState(() {
        _isWaitingForPrayerGesture = true;
      });

      // Give them a few seconds to actually try the gesture before nudging
      // with the prompt card.
      _promptTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _isWaitingForPrayerGesture && !_gestureDetected) {
          setState(() {
            _showPromptCard = true;
          });
        }
      });
    }
  }

  // This callback fires when your MediaPipe camera detects a stable gesture
  void _onGestureDetected(GestureResult result) async {
    if (!_isWaitingForPrayerGesture || _gestureDetected) return;

    // Check if the child did the praying gesture!
    if (result.isPraying) {
      // Cancel any pending timers — scene2/scene3 may still be pending if
      // pray_1's audio was unusually short, and the prompt timer may still
      // be pending regardless.
      _scene2Timer?.cancel();
      _scene3Timer?.cancel();
      _promptTimer?.cancel();

      setState(() {
        _gestureDetected = true;
        _isWaitingForPrayerGesture = false;
        _showPromptCard =
            false; // Hide the prompt card immediately if it was open!
        _currentScene = 'assets/images/objects/lumi/lvl8_scene4.png';
      });

      // Stop the first audio if it's still playing, and play pray_2.wav!
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/lumi_town/level8/pray_2.wav'));

      // Once pray_2 finishes, go back to scene2, play pray_3, then show
      // the Good Job overlay once that finishes too.
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      setState(() {
        _currentScene = 'assets/images/objects/lumi/lvl8_scene2.png';
      });

      await _audioPlayer.play(AssetSource('audio/lumi_town/level8/pray_3.wav'));

      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      setState(() {
        _showGoodJob = true;
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Clean up all timers & audio
    _scene2Timer?.cancel();
    _scene3Timer?.cancel();
    _promptTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Universal Storyboard Background Layer ---
          // Notice we moved the illustration to the VERY BOTTOM of the stack
          // so it acts as the true background layer.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Image.asset(
              _currentScene,
              key: ValueKey<String>(_currentScene),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // --- Hidden Camera Layer (FIXED) ---
          // Using Positioned overrides StackFit.expand and lets us hide
          // the native AndroidView off the edge of the screen!
          if (_hasCameraPermission)
            Positioned(
              left: -10, // Tucks it off screen to the left
              top: -10, // Tucks it off screen to the top
              width: 1, // Locks size to 1x1 pixel
              height: 1,
              child: GestureCameraView(
                onGesture: _onGestureDetected,
                minConfidence: 0.7,
                requiredConsecutiveFrames: 4,
                requiredHands: 2, // needed for palms-together praying detection
              ),
            ),

          // --- Universal Custom Yellow Close Button ---
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, left: 16.0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Image.asset(
                    'assets/images/buttons/x_yellow.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // --- Helpful Prompt Overlay ---
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showPromptCard
                  ? PrayerPromptCard(
                      key: const ValueKey('prompt_card'),
                      onClose: () {
                        setState(() {
                          _showPromptCard = false;
                        });
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // --- Good Job Overlay ---
          if (_showGoodJob)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/dr.woo_smiling.png',
              // TODO: replace with the actual theme color for this level
              closeButtonColor: Colors.blue,
              // TODO: navigate to whatever comes after this level
              onNext: () {},
              // TODO: replay this level (e.g. pushReplacement to Prayer1())
              onRestart: () {},
              // TODO: navigate back (e.g. pop, or pushAndRemoveUntil to a hub screen)
              onBack: () {},
            ),
        ],
      ),
    );
  }
}
