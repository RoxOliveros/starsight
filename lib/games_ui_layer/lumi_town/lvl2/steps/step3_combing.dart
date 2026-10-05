import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../../lumi_game_ui_layer.dart';
import '../audio_helper.dart';
import 'step_ending.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class Step3CombingScreen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Step3CombingScreen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Step3CombingScreen> createState() => _Step3CombingScreenState();
}

class _Step3CombingScreenState extends State<Step3CombingScreen>
    with
        SingleTickerProviderStateMixin,
        AiCameraMixin<Step3CombingScreen>,
        AppAudioLifecycleMixin<Step3CombingScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _hideLightingCard = false;
  bool _dropped = false;

  double _combProgress = 0.0;
  bool _quarterFired = false;
  bool _halfFired = false;
  bool _completeFired = false;
  double _combX = 0.0;
  double _combY = 0.0;
  bool _isCombing = false;
  bool _audioFired = false;

  late AnimationController _wobbleCtrl;

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

    _dropped = true;

    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  Future<void> _onCombComplete() async {
    widget.tapTracker.recordCorrectTap();
    _wobbleCtrl.stop();
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level2/vo_comb_done.wav',
    );
    await waitForAudio(_player);
    if (!mounted) return;
    final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];
    Navigator.of(context).pushReplacement(
      _fadeRoute(
        StepEndingScreen(
          priorEmotions: emotionsSoFar,
          tapTracker: widget.tapTracker,
          level: widget.level,
        ),
      ),
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    _player.dispose();
    _wobbleCtrl.dispose();
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

            // Little Bear + drop target on head
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/characters/little_bear.png',
                  height: MediaQuery.of(context).size.height * 0.80,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Gesture area on bear's head
            if (_dropped)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.18,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      setState(() {
                        _isCombing = true;
                        _combX = details.globalPosition.dx;
                        _combY = details.globalPosition.dy;
                      });
                    },
                    onPanUpdate: (details) {
                      if (_completeFired) return;
                      setState(() {
                        _combX = details.globalPosition.dx;
                        _combY = details.globalPosition.dy;
                        _combProgress =
                            (_combProgress + details.delta.dx.abs() * 0.0010)
                                .clamp(0.0, 1.0);
                      });
                      if (!_audioFired && _combProgress >= 0.15) {
                        _audioFired = true;
                      }
                      if (!_quarterFired && _combProgress >= 0.5) {
                        _quarterFired = true;
                      }
                      if (!_halfFired && _combProgress >= 0.75) {
                        _halfFired = true;
                      }
                      if (!_completeFired && _combProgress >= 1.0) {
                        _completeFired = true;
                        _onCombComplete();
                      }
                    },
                    onPanEnd: (_) => setState(() => _isCombing = false),
                    child: Container(
                      width: 160,
                      height: 80,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

            // Progress bar
            if (_dropped)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    height: 22,
                    width: MediaQuery.of(context).size.width * 0.65,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white38, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 100),
                        widthFactor: _combProgress,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF80DFFF), Color(0xFF00BFFF)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Comb follows finger
            if (_isCombing)
              Positioned(
                left: _combX - 30,
                top: _combY - 30,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/objects/lumi/comb.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
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

Route<void> _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 600),
  );
}
