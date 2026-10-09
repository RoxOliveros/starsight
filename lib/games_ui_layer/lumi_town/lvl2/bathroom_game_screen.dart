import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/game_loading_mixin.dart';
import '../../../ui_layer/loading_screen.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../lumi_game_ui_layer.dart';
import 'steps/step1_choice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/games_ui_layer/games_audio_helper.dart';

class Lvl2BathroomGameScreen extends StatefulWidget {
  final int level;

  const Lvl2BathroomGameScreen({super.key, required this.level});

  @override
  State<Lvl2BathroomGameScreen> createState() => _Lvl2BathroomGameScreenState();
}

class _Lvl2BathroomGameScreenState extends State<Lvl2BathroomGameScreen>
    with
        SingleTickerProviderStateMixin,
        AiCameraMixin<Lvl2BathroomGameScreen>,
        GameLoadingMixin,
        AppAudioLifecycleMixin<Lvl2BathroomGameScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    OrientationService.setLandscape();

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

    finishLoading(_playIntroThenProceed);
  }

  Future<void> _playIntroThenProceed() async {
    _fadeCtrl.forward();

    try {
      await playAssetAudio(
        _audioPlayer,
        'assets/audio/lumi_town/level2/vo_intro.wav',
      );
      await waitForAudio(_audioPlayer);
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
          level: widget.level,
        ),
      ),
    );
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
      body: buildWithLoading(
        loadingScreen: LoadingScreen.lumiTown(),
        gameBuilder: () => Listener(
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

                Positioned(top: 25, left: 25, child: LumiXButton()),
                Positioned(
                  top: 25,
                  right: 25,
                  child: LumiLevelBadge(level: widget.level),
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
      ),
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
