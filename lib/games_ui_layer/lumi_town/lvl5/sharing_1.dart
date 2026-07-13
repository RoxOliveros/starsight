import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/games_ui_layer/lumi_town/lvl5/sharing_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

// Adjust this import path to wherever you placed gesture_camera_view.dart
import 'package:StarSight/business_layer/gesture_camera_view.dart';

/// Tracks whether we know yet if the camera can be used, and if so, whether
/// the child granted or denied it.
enum _CameraGestureState { checking, granted, denied }

class Sharing1 extends StatefulWidget {
  const Sharing1({super.key});

  @override
  State<Sharing1> createState() => _Sharing1State();
}

class _Sharing1State extends State<Sharing1> {
  // Initialize a localized AudioPlayer for this specific screen
  final AudioPlayer _audioPlayer = AudioPlayer();

  _CameraGestureState _cameraState = _CameraGestureState.checking;

  // Guards against a single gesture hold firing the action twice (e.g. the
  // debounced GestureCameraView still emits once more before we navigate).
  bool _actionTaken = false;

  // The camera preview + "show a thumbs up" prompt only appear once the
  // intro narration has finished, so it doesn't compete with it.
  bool _introFinished = false;

  // If no gesture (of any kind) is detected within this window, we assume
  // the camera can't see the child's hands well and offer the button
  // fallback instead of leaving them stuck.
  static const _noHandsTimeout = Duration(seconds: 8);
  Timer? _noHandsTimer;
  bool _showNoHandsPrompt = false;

  // Set when the child explicitly chooses "Use buttons instead" from the
  // no-hands prompt — overrides camera mode even if permission is granted.
  bool _forceButtonFallback = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    // Play the audio intro as soon as the screen initializes
    _audioPlayer.play(AssetSource('audio/lumi_town/level5/intro.wav'));

    // Fires once the intro finishes. Also fires again later when share_yes/
    // share_no finish playing, but that's harmless since _introFinished just
    // stays true after the first time.
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

  /// Called on EVERY gesture result the camera detects (not just thumbs up/
  /// down — any recognized gesture proves a hand is visible). Resets the
  /// "no hands detected" countdown and clears the fallback prompt if shown.
  void _onAnyGestureDetected() {
    _noHandsTimer?.cancel();
    _noHandsTimer = Timer(_noHandsTimeout, () {
      if (mounted) setState(() => _showNoHandsPrompt = true);
    });

    if (_showNoHandsPrompt) {
      setState(() => _showNoHandsPrompt = false);
    }
  }

  /// Starts the no-hands countdown the first time the camera view actually
  /// becomes active (idempotent — safe to call on every build).
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
    // Stop and dispose of the player to free up resources when exiting
    _audioPlayer.dispose();
    _noHandsTimer?.cancel();

    // NOTE: orientation is intentionally NOT reset here anymore. Sharing2
    // locks itself to landscape in its own initState as soon as it mounts,
    // and resetting to portrait here at the same moment created a race
    // between the two async platform calls — sometimes portrait won,
    // causing Sharing2 to briefly (or fully) load in portrait. Orientation
    // reset now only happens when the child actually exits the level via
    // the close (X) button — see _exitLevel().
    super.dispose();
  }

  /// Used only when the child is actually leaving this level (close button),
  /// not when progressing forward to the next screen — see the comment in
  /// dispose() for why this distinction matters.
  Future<void> _exitLevel() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  // ── Shared action logic — called by BOTH the camera gesture AND the
  // fallback tap buttons, so behavior stays identical regardless of input
  // method. ──────────────────────────────────────────────────────────────

  Future<void> _handleThumbsUp() async {
    if (_actionTaken) return;
    _actionTaken = true;

    // An answer is being processed now — stop watching for "no hands",
    // otherwise it can fire while we're mid-navigation.
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

    // Give the child another chance to answer, same as the original behavior
    // (no navigation on thumbs down).
    if (!mounted) return;
    setState(() {
      _actionTaken = false;
    });
    // Restart the watcher now that we're waiting on a fresh answer.
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

          // ── 5. Camera gesture detection (PRIMARY, camera hidden) or
          // thumb buttons (FALLBACK — shown if denied OR the child chose
          // "use buttons" from the no-hands prompt). Both wait until the
          // intro narration finishes. ────────────────────────────────────
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
          // While _cameraState == checking, neither is shown yet — avoids a
          // flash of the fallback buttons before the permission prompt
          // resolves.

          // ── 7. Close button (Top Left) ────────────────────────────────
          Positioned(
            top: sh * 0.05,
            left: sw * 0.03,
            child: GestureDetector(
              onTap: _exitLevel,
              child: Image.asset(
                'assets/images/buttons/x_blue.png',
                width: sw * 0.065,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => Container(
                  width: sw * 0.065,
                  height: sw * 0.065,
                  decoration: const BoxDecoration(
                    color: Color(0xFF266589),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: sw * 0.04,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs the camera + gesture detection WITHOUT showing any visible preview.
/// The AndroidView still needs to exist in the widget tree to keep working
/// (camera/MediaPipe run natively regardless of what's visually drawn), so
/// this renders it at a near-zero size and fully transparent instead of
/// removing it — that keeps detection alive while showing nothing on
/// screen.
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
    // Start the no-hands countdown once this is actually in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMounted());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Off in a corner, effectively invisible, but still a real, live
      // platform view so the camera keeps running.
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

/// Shown when no hand has been detected for a while — offers the child (or
/// parent) a way out to the button fallback instead of getting stuck.
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
