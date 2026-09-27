import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../ui_layer/lumi_town/town_level.dart';
import 'steps/step1_choice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class Lvl2BathroomGameScreen extends StatefulWidget {
  const Lvl2BathroomGameScreen({super.key});

  @override
  State<Lvl2BathroomGameScreen> createState() => _Lvl2BathroomGameScreenState();
}

class _Lvl2BathroomGameScreenState extends State<Lvl2BathroomGameScreen>
    with SingleTickerProviderStateMixin, AiCameraMixin<Lvl2BathroomGameScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Tracking (camera + taps; this level spans 8 screens ending at
  // StepEndingScreen, so this tracker and the emotions list travel with the
  // player through every one of them) ─────────────────────────────────────
  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    OrientationService.setLandscape();

    // Starts immediately - never waits for a face. Session id/tap tracker
    // are shared with every following screen in this level.
    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _playIntroThenProceed();
  }

  Future<void> _playIntroThenProceed() async {
    try {
      await _playAudio('assets/audio/lumi_town/level2/vo_intro.wav');
      await _audioPlayer.onPlayerComplete.first;
    } catch (_) {}

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final emotionsSoFar = stopAiCamera();
    Navigator.of(context).pushReplacement(
      _fadeRoute(
        Step1ChoiceScreen(
          priorEmotions: emotionsSoFar,
          tapTracker: _tapTracker,
        ),
      ),
    );
  }

  Future<void> _playAudio(String assetPath) async {
    final dir = await getTemporaryDirectory();
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await _audioPlayer.play(DeviceFileSource(file.path));
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: (_) => _tapTracker.recordGenericTap(),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background
              Image.asset(
                'assets/images/backgrounds/bg_lumi_bathroom.png',
                fit: BoxFit.cover,
              ),

              // 2. Bear — behind choices
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bearH = MediaQuery.of(context).size.height * 0.80;
                      return Image.asset(
                        'assets/images/characters/little_bear.png',
                        height: bearH,
                        fit: BoxFit.contain,
                      );
                    },
                  ),
                ),
              ),

              // 3. X button — always on top
              Positioned(
                top: 25,
                left: 25,
                child: LumiXButton(
                  onTap: _onBack,
                ), // was unwired: X did nothing before
              ),

              if (hasCapturedFirstFrame &&
                  !isFaceDetected &&
                  !_hideLightingCard)
                LightingPromptCard(
                  onClose: () {
                    setState(() => _hideLightingCard = true);
                    releaseFaceGate();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onBack() {
    _audioPlayer.stop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
      (route) => route.isFirst,
    );
  }
}

// ── Shared fade page route helper (used across all steps) ─────────────────────
Route<void> _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 600),
  );
}
