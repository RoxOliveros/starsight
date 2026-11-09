// pubspec.yaml dependencies:
//   video_player: ^2.9.0
//   shared_preferences: ^2.3.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:StarSight/business_layer/orientation_service.dart';

abstract class _IvPalette {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color brown = Color(0xFF6F6764);
  static const Color titleSky = Color(0xFF6FD3E3);
  static const Color titleGold = Color(0xFFFACC58);
  static const Color titleOrange = Color(0xFFEC8A20);
}

/// Remembers whether this account has already seen the intro.
/// Key is per user, so a different account on the same phone still sees it.
/// For reinstall-proof behavior, ALSO save a `hasSeenIntro` field on the
/// user's Firestore/DB document and check it at login.
class IntroVideoPrefs {
  static String _key(String uid) => 'seen_world_intro_$uid';

  static Future<bool> hasSeen(String uid) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key(uid)) ?? false;
  }

  static Future<void> markSeen(String uid) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key(uid), true);
  }
}

class IntroVideoScreen extends StatefulWidget {
  /// Public/streaming URL of the compressed .mp4 (recommended),
  /// e.g. a Firebase Storage download URL.
  final String? videoUrl;

  /// Or a bundled asset path (only if the file is small).
  final String? assetPath;

  final String uid;

  /// Called after the video ends, is skipped, or fails to load.
  final VoidCallback onFinished;

  /// Minimum time the "get ready" screen stays up, so it never just flashes.
  final Duration getReadyDuration;

  const IntroVideoScreen({
    super.key,
    required this.uid,
    required this.onFinished,
    this.videoUrl,
    this.assetPath,
    this.getReadyDuration = const Duration(seconds: 3),
  }) : assert(videoUrl != null || assetPath != null);

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  late final VideoPlayerController _controller;
  Timer? _getReadyTimer;

  bool _videoReady = false; // video finished loading in the background
  bool _minWaitDone = false; // "get ready" screen shown long enough
  bool _started = false; // switched over to the video
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape(); // video + dashboard are landscape
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = widget.videoUrl != null
        ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!))
        : VideoPlayerController.asset(widget.assetPath!);

    // Load the video while the "get ready" screen is showing.
    _controller.initialize().then((_) {
      if (!mounted) return;
      _videoReady = true;
      _controller.addListener(_onTick);
      _maybeStart();
    }).catchError((_) {
      // Never block the user because of a video problem.
      _finish();
    });

    _getReadyTimer = Timer(widget.getReadyDuration, () {
      _minWaitDone = true;
      _maybeStart();
    });
  }

  /// Starts the video once it is loaded AND the prompt was shown long enough.
  void _maybeStart() {
    if (!mounted || _started || _finished) return;
    if (!_videoReady || !_minWaitDone) return;
    setState(() => _started = true);
    _controller.play();
  }

  void _onTick() {
    final v = _controller.value;
    if (v.hasError) {
      _finish();
      return;
    }
    if (_started &&
        v.isInitialized &&
        !v.isPlaying &&
        v.position >= v.duration) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _getReadyTimer?.cancel();
    await IntroVideoPrefs.markSeen(widget.uid);
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _getReadyTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // back button = skip, not a dead end
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: _started ? Colors.black : _IvPalette.cream,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fades from the "get ready" screen into the video
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: _started
                  ? _buildVideo()
                  : const _GetReadyView(key: ValueKey('get_ready')),
            ),

            // Skip button (available on both screens)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _started ? Colors.black54 : _IvPalette.yellow,
                      foregroundColor:
                      _started ? Colors.white : _IvPalette.brown,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SKIP',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.skip_next_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    return Container(
      key: const ValueKey('video'),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),

          // Progress bar along the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: false,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: _IvPalette.orange,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// "GET READY" SCREEN shown before the video starts
// ══════════════════════════════════════════════════════════════════════════════
class _GetReadyView extends StatelessWidget {
  const _GetReadyView({super.key});

  // Multicolored title (same style as the other screens)
  Widget _rainbowTitle(String text) {
    const palette = [
      _IvPalette.titleSky,
      _IvPalette.titleGold,
      _IvPalette.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = _IvPalette.brown;
      } else {
        color = palette[(letterIndex ~/ 2) % palette.length];
        letterIndex++;
      }
      spans.add(TextSpan(text: char, style: TextStyle(color: color)));
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _IvPalette.cream,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_transparent_bg.png',
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                _rainbowTitle('WELCOME TO STARSIGHT'),
                const SizedBox(height: 10),
                const Text(
                  'Get ready for a short adventure!\n'
                      'Your introduction video is about to begin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: _IvPalette.brown,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      color: _IvPalette.orange,
                      backgroundColor: _IvPalette.yellow.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'You can skip it anytime.',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _IvPalette.deepNavyBlue.withValues(alpha: 0.7),
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