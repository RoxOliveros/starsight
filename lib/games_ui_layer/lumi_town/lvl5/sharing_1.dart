import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl5/sharing_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:StarSight/business_layer/gesture_camera_view.dart';
import '../../../ui_layer/game_loading_mixin.dart';
import '../../../ui_layer/loading_screen.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../games_audio_helper.dart';
import '../lumi_game_ui_layer.dart';

enum _CameraGestureState { checking, granted, denied }

class Sharing1 extends StatefulWidget {
  final int level;

  const Sharing1({super.key, required this.level});

  @override
  State<Sharing1> createState() => _Sharing1State();
}

class _Sharing1State extends State<Sharing1>
    with
        AiCameraMixin<Sharing1>,
        GameLoadingMixin,
        AppAudioLifecycleMixin<Sharing1> {

  @override
  List<AudioPlayer> get lifecyclePlayers => [_voice];

  final GameTapTracker _tapTracker = GameTapTracker();
  final AudioPlayer _voice = AudioPlayer();
  static const String _voiceBase = 'assets/audio/lumi_town/';

  _CameraGestureState _cameraState = _CameraGestureState.checking;

  bool _disposed = false;
  bool _actionTaken = false;
  bool _introFinished = false;
  bool _hideLightingCard = false;

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
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _requestCameraPermission();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) finishLoading(_playIntro);
    });
  }

  Future<void> _speak(String file) async {
    try {
      await _voice.stop();
      await playAssetAudio(_voice, '$_voiceBase$file');
      await waitForAudio(_voice);
    } catch (e) {
      debugPrint('[Sharing1] Voice error ($file): $e');
    }
  }

  Future<void> _playIntro() async {
    if (_disposed || !mounted) return;

    await _speak('level5/intro.wav');
    if (_disposed || !mounted) return;

    setState(() => _introFinished = true);
    _startNoHandsTimer();

    await _speak('thumbsup_thumbsdown.wav');
    if (!_promptDone.isCompleted) _promptDone.complete();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (_disposed || !mounted) return;

    setState(() {
      _cameraState = status.isGranted
          ? _CameraGestureState.granted
          : _CameraGestureState.denied;
    });
    if (_introFinished) _startNoHandsTimer();
  }

  @override
  void onAppBackgrounded() {
    _noHandsTimer?.cancel();
  }

  @override
  void onAppForegrounded() {
    if (_introFinished) _startNoHandsTimer();
  }

  void _startNoHandsTimer() {
    _noHandsTimer?.cancel();
    if (_showButtons || _disposed || !mounted) return;

    if (_cameraState == _CameraGestureState.denied) {
      setState(() => _showButtons = true);
      return;
    }
    if (_cameraState == _CameraGestureState.checking) return;

    _noHandsTimer = Timer(_noHandsTimeout, () {
      if (!_disposed && mounted) setState(() => _showButtons = true);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    disposeAiCamera();
    _noHandsTimer?.cancel();
    _voice.dispose();
    if (!_promptDone.isCompleted) _promptDone.complete();
    super.dispose();
  }

  Future<void> _handleThumbsUp() async {
    if (_actionTaken) return;
    _actionTaken = true;

    await _promptDone.future;
    if (_disposed || !mounted) return;

    _tapTracker.recordCorrectTap();
    _noHandsTimer?.cancel();

    await _speak('level5/share_yes.wav');
    if (_disposed || !mounted) return;

    final emotionsSoFar = stopAiCamera();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => Sharing2(
          priorEmotions: emotionsSoFar,
          tapTracker: _tapTracker,
          level: widget.level,
        ),
      ),
    );
  }

  Future<void> _handleThumbsDown() async {
    if (_actionTaken) return;
    _actionTaken = true;

    await _promptDone.future;
    if (_disposed || !mounted) return;

    _tapTracker.recordMistake();

    await _speak('level5/share_no.wav');
    if (_disposed || !mounted) return;

    setState(() => _actionTaken = false);
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final double bearHeight = sh * 0.95;
    const double bearBottom = 0.0;
    final double tableBottom = -sh * 0.60;
    final double tableWidth = sw;

    final double plateWidth = sw * 0.26;
    final double pancakeWidth = sw * 0.20;
    final double stackBaseOffset = sh * 0.055;
    final double pancakeThickness = sh * 0.055;
    const int plainPancakeCount = 6;

    final rng = math.Random(7);
    final List<double> jitterDx = List.generate(
      plainPancakeCount + 1,
      (_) => (rng.nextDouble() - 0.5) * pancakeWidth * 0.18,
    );

    final double thumbSize = sw * 0.11;
    final double thumbBtnSize = sw * 0.135;

    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.lumiTown(),
        gameBuilder: () => Listener(
          onPointerDown: (_) => _tapTracker.recordGenericTap(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/backgrounds/bg_game_kitchen.png',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF3C8), Color(0xFFE8C97A)],
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: bearBottom,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    'assets/images/characters/little_bear_uniform.png',
                    height: bearHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, st) => const SizedBox(),
                  ),
                ),
              ),

              Positioned(
                bottom: tableBottom,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/images/objects/lumi/table.png',
                  width: tableWidth,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => Container(
                    height: sh * 0.22,
                    color: const Color(0xFFCD853F),
                  ),
                ),
              ),

              Positioned(
                bottom: stackBaseOffset,
                right: sw * 0.04,
                child: SizedBox(
                  width: plateWidth,
                  height: sh * 1.1,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        bottom: 0,
                        child: Image.asset(
                          'assets/images/objects/lumi/plate.png',
                          width: plateWidth,
                          errorBuilder: (ctx, err, st) => Container(
                            width: plateWidth,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),

                      ...List.generate(plainPancakeCount, (index) {
                        final dx = jitterDx[index];
                        return Positioned(
                          bottom: stackBaseOffset + (index * pancakeThickness),
                          left: plateWidth / 2 - pancakeWidth / 2 + dx,
                          child: Image.asset(
                            'assets/images/objects/lumi/pancake.png',
                            width: pancakeWidth,
                            errorBuilder: (ctx, err, st) => Container(
                              width: pancakeWidth,
                              height: pancakeThickness * 0.55,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8A037),
                                borderRadius: BorderRadius.circular(
                                  pancakeWidth / 2,
                                ),
                                border: Border.all(
                                  color: const Color(0xFFB8641A),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      Positioned(
                        bottom:
                            stackBaseOffset +
                            (plainPancakeCount * pancakeThickness),
                        left:
                            plateWidth / 2 -
                            pancakeWidth / 2 +
                            jitterDx[plainPancakeCount],
                        child: Image.asset(
                          'assets/images/objects/lumi/pancke_maple_syrup_butter.png',
                          width: pancakeWidth,
                          errorBuilder: (ctx, err, st) => Container(
                            width: pancakeWidth,
                            height: pancakeThickness * 0.55,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4843A),
                              borderRadius: BorderRadius.circular(
                                pancakeWidth / 2,
                              ),
                              border: Border.all(
                                color: const Color(0xFFB8641A),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
              ),

              // Gesture detection stays active when the camera is allowed,
              // but the buttons are always visible as soon as the intro ends.
              if (_introFinished && _cameraState == _CameraGestureState.granted)
                _HiddenGestureDetector(
                  onGesture: (result) {
                    _startNoHandsTimer(); // hand seen: restart countdown
                    if (result.isThumbsUp) {
                      _handleThumbsUp();
                    } else if (result.isThumbsDown) {
                      _handleThumbsDown();
                    }
                  },
                ),

              if (_showButtons)
                Positioned(
                  bottom: sh * 0.10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_actionTaken) return;
                            GamesSfxPlayer.instance.play(GameSfx.bubbleClick);
                            _handleThumbsUp();
                          },
                          child: _ThumbButton(
                            imagePath:
                                'assets/images/objects/lumi/thumbs_up.png',
                            backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                            size: thumbBtnSize,
                            iconSize: thumbSize,
                            animDelay: Duration.zero,
                          ),
                        ),
                        SizedBox(width: sw * 0.04),
                        GestureDetector(
                          onTap: () {
                            if (_actionTaken) return;
                            GamesSfxPlayer.instance.play(GameSfx.bubbleClick);
                            _handleThumbsDown();
                          },
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
    );
  }
}

class _HiddenGestureDetector extends StatelessWidget {
  final void Function(GestureResult result) onGesture;

  const _HiddenGestureDetector({required this.onGesture});

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
            child: GestureCameraView(onGesture: onGesture),
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
            errorBuilder: (ctx, err, st) {
              debugPrint('[ThumbButton] Could not load $imagePath: $err');
              return const SizedBox.shrink();
            },
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
