import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../games_audio_helper.dart';
import '../../lumi_game_ui_layer.dart';
import '../widgets/shake_widget.dart';
import 'step2_washing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class Step2ChoiceScreen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Step2ChoiceScreen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Step2ChoiceScreen> createState() => _Step2ChoiceScreenState();
}

class _Step2ChoiceScreenState extends State<Step2ChoiceScreen>
    with
        SingleTickerProviderStateMixin,
        AiCameraMixin<Step2ChoiceScreen>,
        AppAudioLifecycleMixin<Step2ChoiceScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _hideLightingCard = false;

  final GlobalKey<ShakeWidgetState> _combKey = GlobalKey();
  final GlobalKey<ShakeWidgetState> _towelKey = GlobalKey();

  late AnimationController _iconEntranceCtrl;
  late Animation<double> _iconFade;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_player];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _iconEntranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconFade = CurvedAnimation(
      parent: _iconEntranceCtrl,
      curve: Curves.easeIn,
    );

    _playQuestionAudio();
  }

  Future<void> _playQuestionAudio() async {
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level2/vo_step2_question.wav',
    );
    await waitForAudio(_player);
    if (mounted) _iconEntranceCtrl.forward();
  }

  Future<void> _onCorrect() async {
    widget.tapTracker.recordCorrectTap();
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level2/vo_wash_start.wav',
    );
    await waitForAudio(_player);
    if (!mounted) return;
    final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];
    Navigator.of(context).pushReplacement(
      _fadeRoute(
        Step2WashingScreen(
          priorEmotions: emotionsSoFar,
          tapTracker: widget.tapTracker,
          level: widget.level,
        ),
      ),
    );
  }

  Future<void> _onWrong(GlobalKey<ShakeWidgetState> key) async {
    widget.tapTracker.recordMistake();
    key.currentState?.shake();
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level2/vo_step1_wrong.wav',
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    _player.dispose();
    _iconEntranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_bathroom.png',
              fit: BoxFit.cover,
            ),
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
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _iconFade,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Water splash — CORRECT
                    _ChoiceIcon(
                      imagePath: 'assets/images/objects/lumi/water_splash.png',
                      bgColor: const Color(0xFF5B9FD4),
                      onTap: _onCorrect,
                    ),
                    const SizedBox(width: 24),

                    // Comb — WRONG
                    ShakeWidget(
                      key: _combKey,
                      child: _ChoiceIcon(
                        imagePath: 'assets/images/objects/lumi/chair.png',
                        bgColor: const Color(0xFF5BAD72),
                        onTap: () => _onWrong(_combKey),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Towel — WRONG (close but not yet)
                    ShakeWidget(
                      key: _towelKey,
                      child: _ChoiceIcon(
                        imagePath: 'assets/images/objects/lumi/rug.png',
                        bgColor: const Color(0xFFD4785B),
                        onTap: () => _onWrong(_towelKey),
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

class _ChoiceIcon extends StatelessWidget {
  final String imagePath;
  final Color bgColor;
  final VoidCallback onTap;

  const _ChoiceIcon({
    required this.imagePath,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.help_outline, color: Colors.white, size: 40),
        ),
      ),
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
