import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../lumi_game_ui_layer.dart';
import '../../lvl3/clean_bedroom_audio_helper.dart';
import '../widgets/sparkle_overlay.dart';
import 'step3_choice.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

enum _WashPhase { washing, drying, done, dragging }

class Step2WashingScreen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Step2WashingScreen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Step2WashingScreen> createState() => _Step2WashingScreenState();
}

class _Step2WashingScreenState extends State<Step2WashingScreen>
    with
        TickerProviderStateMixin,
        AiCameraMixin<Step2WashingScreen>,
        AppAudioLifecycleMixin<Step2WashingScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _hideLightingCard = false;
  _WashPhase _phase = _WashPhase.dragging;
  StarState _starState = StarState.none;

  late AnimationController _wobbleCtrl;

  double _washProgress = 0.0;
  bool _halfFired = false;
  bool _completeFired = false;
  double _splashX = 0.0;
  double _splashY = 0.0;
  bool _isWashing = false;

  double _towelProgress = 0.0;
  bool _towelCompleteFired = false;
  double _towelX = 0.0;
  double _towelY = 0.0;
  bool _isWiping = false;
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

    _phase = _WashPhase.washing;

    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  void _onHalfway() {
    setState(() => _starState = StarState.few);
  }

  Future<void> _onWashComplete() async {
    widget.tapTracker.recordCorrectTap();
    setState(() {
      _starState = StarState.lot;
      _phase = _WashPhase.drying;
      _isWashing = false;
    });
    _wobbleCtrl.stop();
  }

  Future<void> _onTowelComplete() async {
    if (_phase != _WashPhase.drying) return;
    widget.tapTracker.recordCorrectTap();
    setState(() {
      _phase = _WashPhase.done;
      _starState = StarState.none;
      _isWiping = false;
    });
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level2/vo_wash_done.wav',
    );
    await waitForAudio(_player);
    if (!mounted) return;
    final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];
    Navigator.of(context).pushReplacement(
      _fadeRoute(
        Step3ChoiceScreen(
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

            // Little Bear + drop target on face
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenH = MediaQuery.of(context).size.height;
                    final bearH = screenH * 0.80;

                    return SizedBox(
                      width: bearH, // approximate bear width
                      height: bearH,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/characters/little_bear.png',
                            height: bearH,
                            fit: BoxFit.contain,
                          ),

                          // Stars
                          if (_phase == _WashPhase.washing ||
                              _phase == _WashPhase.drying)
                            Positioned(
                              top: 20,
                              child: StarSparkleOverlay(state: _starState),
                            ),

                          // Drying
                          if (_phase == _WashPhase.drying)
                            Positioned(
                              top: bearH * 0.28,
                              left: bearH * 0.25,
                              right: bearH * 0.25,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onPanStart: (details) {
                                  setState(() {
                                    _isWiping = true;
                                    _towelX = details.globalPosition.dx;
                                    _towelY = details.globalPosition.dy;
                                  });
                                },
                                onPanUpdate: (details) {
                                  if (_towelCompleteFired) return;
                                  setState(() {
                                    _towelX = details.globalPosition.dx;
                                    _towelY = details.globalPosition.dy;
                                    _towelProgress =
                                        (_towelProgress +
                                                details.delta.dx.abs() * 0.0010)
                                            .clamp(0.0, 1.0);
                                  });
                                  if (!_towelCompleteFired &&
                                      _towelProgress >= 1.0) {
                                    _towelCompleteFired = true;
                                    _onTowelComplete();
                                  }
                                },
                                onPanEnd: (_) =>
                                    setState(() => _isWiping = false),
                                child: Container(
                                  width: 160,
                                  height: 80,
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Swipe bar — appears after water dropped on face
            if (_phase == _WashPhase.washing)
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.28 + 70,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      setState(() {
                        _isWashing = true;
                        _splashX = details.globalPosition.dx;
                        _splashY = details.globalPosition.dy;
                      });
                    },
                    onPanUpdate: (details) {
                      if (_completeFired) return;
                      setState(() {
                        _splashX = details.globalPosition.dx;
                        _splashY = details.globalPosition.dy;
                        _washProgress =
                            (_washProgress + details.delta.dx.abs() * 0.0010)
                                .clamp(0.0, 1.0);
                      });
                      if (!_halfFired && _washProgress >= 0.5) {
                        _halfFired = true;
                        _onHalfway();
                      }
                      if (!_completeFired && _washProgress >= 1.0) {
                        _completeFired = true;
                        _onWashComplete();
                      }
                    },
                    onPanEnd: (_) => setState(() => _isWashing = false),
                    child: Container(
                      width: 160,
                      height: 80,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

            if (_isWashing)
              Positioned(
                left: _splashX - 30,
                top: _splashY - 30,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/objects/lumi/water_splash.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            if (_phase == _WashPhase.washing)
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
                        widthFactor: _washProgress,
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

            if (_isWiping)
              Positioned(
                left: _towelX - 30,
                top: _towelY - 30,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/objects/lumi/towel.png',
                    width: 130,
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            if (_phase == _WashPhase.drying)
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
                        widthFactor: _towelProgress,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFD580), Color(0xFFFFAA40)],
                            ),
                          ),
                        ),
                      ),
                    ),
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
