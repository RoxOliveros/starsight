import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../business_layer/orientation_service.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'clean_bedroom_data.dart';
import 'clean_bedroom_round_screen.dart';

class CleanBedroomGameScreen extends StatefulWidget {
  const CleanBedroomGameScreen({super.key});

  @override
  State<CleanBedroomGameScreen> createState() => _CleanBedroomGameScreenState();
}

class _CleanBedroomGameScreenState extends State<CleanBedroomGameScreen>
    with SingleTickerProviderStateMixin, AiCameraMixin<CleanBedroomGameScreen> {
  final AudioPlayer _player = AudioPlayer();

  // ── Tracking (camera + taps; this level spans the 4 rounds and ends at
  // CleanBedroomEndingScreen, so this tracker and the emotions list travel
  // with the player through every one of them) ──────────────────────────────
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
      await _playAudio('assets/audio/lumi_town/level3/vo_intro.wav');
      await _player.onPlayerComplete.first;
    } catch (_) {}

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final allIds = List<String>.from(kAllToyIds)..shuffle();
    final rounds = List.generate(4, (i) => allIds.sublist(i * 3, i * 3 + 3));

    final emotionsSoFar = stopAiCamera();

    Navigator.of(context).pushReplacement(
      _fadeRoute(
        BedroomRoundScreen(
          roundIndex: 0,
          rounds: rounds,
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
    await _player.play(DeviceFileSource(file.path));
  }

  @override
  void dispose() {
    disposeAiCamera();
    _player.dispose();
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
              Image.asset(
                'assets/images/backgrounds/bg_lumi_messy_bed.png',
                fit: BoxFit.cover,
              ),
              Positioned(top: 25, left: 25, child: LumiXButton(onTap: _onBack)),

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
    _player.stop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
      (route) => route.isFirst,
    );
  }
}

Route<void> _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 600),
  );
}
