import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl5/sharing_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:StarSight/business_layer/gesture_camera_view.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';

enum _CameraGestureState { checking, granted, denied }

class Sharing1 extends StatefulWidget {
  const Sharing1({super.key});

  @override
  State<Sharing1> createState() => _Sharing1State();
}

class _Sharing1State extends State<Sharing1> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  _CameraGestureState _cameraState = _CameraGestureState.checking;

  bool _actionTaken = false;
  bool _introFinished = false;

  static const _noHandsTimeout = Duration(seconds: 8);
  Timer? _noHandsTimer;

  bool _showNoHandsPrompt = false;
  bool _forceButtonFallback = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _audioPlayer.play(AssetSource('audio/lumi_town/level5/intro.wav'));
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && !_introFinished) {
        setState(() {
          _introFinished = true;
        });
      }
    });

    _requestCameraPermission();
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
    _audioPlayer.dispose();
    _noHandsTimer?.cancel();

    super.dispose();
  }

  // method. ──────────────────────────────────────────────────────────────

  Future<void> _handleThumbsUp() async {
    if (_actionTaken) return;
    _actionTaken = true;

    _noHandsTimer?.cancel();
    _noHandsTimer = null;
    if (_showNoHandsPrompt) {
      setState(() => _showNoHandsPrompt = false);
    }

    debugPrint('Thumbs Up!');
    await _audioPlayer.stop();
    await _audioPlayer.play(
      AssetSource('audio/lumi_town/level5/share_yes.wav'),
    );

    await _audioPlayer.onPlayerComplete.first;
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const Sharing2()),
    );
  }

  Future<void> _handleThumbsDown() async {
    if (_actionTaken) return;
    _actionTaken = true;

    _noHandsTimer?.cancel();
    _noHandsTimer = null;
    if (_showNoHandsPrompt) {
      setState(() => _showNoHandsPrompt = false);
    }

    debugPrint('Thumbs Down!');
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('audio/lumi_town/level5/share_no.wav'));

    if (!mounted) return;
    setState(() {
      _actionTaken = false;
    });
    _ensureNoHandsWatcherStarted();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    // ── Layout constants ──────────────────────────────────────────────────
    final double bearHeight = sh * 0.95;
    const double bearBottom = 0.0;
    final double tableBottom = -sh * 0.60;
    final double tableWidth = sw;

    // ── Pancake stack math ───────────────────────────────────────────────
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

    // ── Thumb button size (fallback UI only) ─────────────────────────────
    final double thumbSize = sw * 0.11;
    final double thumbBtnSize = sw * 0.135;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background ────────────────────────────────────────────
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

          // ── 2. Bear (behind table) ───────────────────────────────────
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

          // ── 3. Table (in front of bear) ──────────────────────────────
          Positioned(
            bottom: tableBottom,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/objects/lumi/table.png',
              width: tableWidth,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) =>
                  Container(height: sh * 0.22, color: const Color(0xFFCD853F)),
            ),
          ),

          // ── 4. Pancake stack (right side, on table surface) ──────────
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
                  // Plate
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

                  // Plain pancakes
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

                  // Top pancake — butter & syrup
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
                          borderRadius: BorderRadius.circular(pancakeWidth / 2),
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
            if (_showNoHandsPrompt)
              _NoHandsPrompt(onUseButtons: _switchToButtonFallback),
          ] else if (_introFinished &&
              (_cameraState == _CameraGestureState.denied ||
                  _forceButtonFallback))
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
          Positioned(top: 25, left: 25, child: LumiXButton()),
        ],
      ),
    );
  }
}

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
