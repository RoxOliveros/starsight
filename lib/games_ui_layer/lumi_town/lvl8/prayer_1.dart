import 'dart:async';
import 'package:StarSight/business_layer/gesture_camera_view.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_1.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
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
  Timer? _promptTimer;
  Timer? _skipTimer;

  // State flags for interactive gesture logic
  bool _hasCameraPermission = false;
  bool _isWaitingForPrayerGesture = false;
  bool _gestureDetected = false;
  bool _showPromptCard = false;
  bool _showSkipButton = false;
  bool _showGoodJob = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeSequence();
  }

  Future<void> _initializeSequence() async {
    final status = await Permission.camera.request();

    if (mounted) {
      setState(() {
        _hasCameraPermission = status.isGranted;
      });
    }

    await _audioPlayer.play(AssetSource('audio/lumi_town/level8/pray_1.wav'));

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

    await _audioPlayer.onPlayerComplete.first;
    if (!mounted || _gestureDetected) return;

    if (_hasCameraPermission) {
      setState(() {
        _isWaitingForPrayerGesture = true;
      });

      _promptTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _isWaitingForPrayerGesture && !_gestureDetected) {
          setState(() {
            _showPromptCard = true;
          });

          _skipTimer = Timer(const Duration(seconds: 5), () {
            if (mounted && _isWaitingForPrayerGesture && !_gestureDetected) {
              setState(() {
                _showPromptCard = false;
                _showSkipButton = true;
              });
            }
          });
        }
      });
    }
  }

  Future<void> _triggerSuccessSequence() async {
    // Cancel any pending timers
    _scene2Timer?.cancel();
    _scene3Timer?.cancel();
    _promptTimer?.cancel();
    _skipTimer?.cancel();

    setState(() {
      _gestureDetected = true;
      _isWaitingForPrayerGesture = false;
      _showPromptCard = false;
      _showSkipButton = false; // Hide the skip button if it was used!
      _currentScene = 'assets/images/objects/lumi/lvl8_scene4.png';
    });

    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('audio/lumi_town/level8/pray_2.wav'));

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

  void _onGestureDetected(GestureResult result) {
    if (!_isWaitingForPrayerGesture || _gestureDetected) return;

    if (result.isPraying) {
      _triggerSuccessSequence();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _scene2Timer?.cancel();
    _scene3Timer?.cancel();
    _promptTimer?.cancel();
    _skipTimer?.cancel();
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

          if (_hasCameraPermission)
            Positioned(
              left: -10,
              top: -10,
              width: 1,
              height: 1,
              child: GestureCameraView(
                key: const ValueKey('prayer_camera_2_hands'),
                onGesture: _onGestureDetected,
                minConfidence: 0.7,
                requiredConsecutiveFrames: 4,
                requiredHands: 2,
              ),
            ),

          Positioned(top: 25, left: 25, child: LumiXButton()),

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

          // ---  Skip Button  ---
          if (_showSkipButton)
            Positioned(
              bottom: 25,
              right: 25,
              child: GestureDetector(
                onTap: () {
                  if (!_gestureDetected) {
                    _triggerSuccessSequence();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: LumiColorTheme.seaglass,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: LumiColorTheme.darkolive,
                      width: 5,
                    ),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: LumiAppTextStyles.fredoka,
                      fontSize: 18,
                      color: LumiColorTheme.darkolive,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          if (_showGoodJob)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/tr.woo_smiling.png',
              onNext: () async {
                await TownProgressService.instance.markLevelComplete(8);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const Sorry1Screen()),
                );
              },
              onRestart: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const Prayer1()),
                );
              },
              onBack: () async {
                await TownProgressService.instance.markLevelComplete(7);
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const Prayer1()),
                    (route) => route.isFirst,
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
