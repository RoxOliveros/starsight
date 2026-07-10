import 'dart:math' as math;
import 'package:StarSight/games_ui_layer/lumi_town/dr.woo_reaction.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl7/respect_7.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class Respect6Screen extends StatefulWidget {
  const Respect6Screen({Key? key}) : super(key: key);

  @override
  State<Respect6Screen> createState() => _Respect6ScreenState();
}

class _Respect6ScreenState extends State<Respect6Screen>
    with TickerProviderStateMixin, DrWooReactionMixin {
  late final AudioPlayer _audioPlayer;
  bool _showButtons = false;

  // --- Animation Variables (Now only used for Roxie) ---
  late final AnimationController _walkController;
  final Duration _walkDuration = const Duration(milliseconds: 1800);
  final Duration _stepDuration = const Duration(milliseconds: 260);
  final double _bounceHeightFraction = 0.045;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Setup the walking animation
    _walkController = AnimationController(vsync: this, duration: _walkDuration);

    // Lock to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start the walk animation immediately (Roxie enters)
      _walkController.forward(from: 0);
      _playSceneAudio();
    });
  }

  @override
  void dispose() {
    // Reset orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _walkController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  AudioPlayer get drWooPlayer => _audioPlayer;

  // ---------------------------------------------------------------------------
  // Custom visual-only reaction
  // ---------------------------------------------------------------------------
  Future<void> showDrWooReactionQuietly(DrWooState state) async {
    if (!mounted) return;
    setState(() => drWooState = state);

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => drWooState = DrWooState.normal);
  }

  Future<void> _playSceneAudio() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level7/respect_roxie2.wav'),
      );

      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      setState(() {
        _showButtons = true;
      });
    } catch (e) {
      debugPrint('Error playing scene audio: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // OVERRIDDEN: Dr. Woo is back to his static placement
  // ---------------------------------------------------------------------------
  @override
  Widget buildDrWoo(BuildContext context) {
    final owlHeight = MediaQuery.of(context).size.height * 1.18;

    return Positioned(
      left: MediaQuery.of(context).size.width * 0.10,
      bottom: -(owlHeight * 0.15),
      child: SizedBox(
        height: owlHeight,
        child: switch (drWooState) {
          DrWooState.correct => Image.asset(
            'assets/animations/characters/dr.woo_thumbsup.webp',
            fit: BoxFit.contain,
          ),
          DrWooState.wrong => Image.asset(
            'assets/images/characters/dr.woo_tryagain.png',
            fit: BoxFit.contain,
          ),
          DrWooState.normal => Image.asset(
            'assets/images/characters/dr.woo_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final baseCharacterHeight = MediaQuery.of(context).size.height * 1.18;
    final roxieHeight = baseCharacterHeight * 0.70;

    // Animation Math for Roxie (From Right)
    final double startX = sw; // Start off-screen right
    final int stepCount =
        (_walkDuration.inMilliseconds / _stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);
    final double bounceHeightPx = roxieHeight * _bounceHeightFraction;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/images/backgrounds/bg_lumi_classroom.png',
            fit: BoxFit.cover,
          ),

          // 1. Dr. Woo Layer (Left Side - Static)
          buildDrWoo(context),

          // 2. Rabbit Character Layer (Right Side - Animated Entrance)
          AnimatedBuilder(
            animation: _walkController,
            builder: (context, child) {
              final double t = _walkController.value;
              final double easedT = Curves.easeOutCubic.transform(t);

              final double dx = startX * (1 - easedT);
              final double bounce = t < 1.0
                  ? (math.sin(t * stepCount * math.pi)).abs() * bounceHeightPx
                  : 0.0;

              return Positioned(
                right:
                    (sw * 0.08) - dx, // Subtract dx because she is on the right
                bottom: -(baseCharacterHeight * 0.15) + bounce,
                child: SizedBox(
                  height: roxieHeight,
                  child: Image.asset(
                    'assets/images/characters/roxie_standing.png',
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),

          // Buttons Layer
          if (_showButtons) ...[
            // Thumbs Up Button
            Positioned(
              left: 20,
              bottom: 40,
              child: GestureDetector(
                onTap: () {
                  showDrWooReaction(DrWooState.wrong);
                },
                child: Image.asset(
                  'assets/images/objects/lumi/thumbs_up.png',
                  width: 100,
                  height: 100,
                ),
              ),
            ),

            // Thumbs Down Button
            Positioned(
              right: 20,
              bottom: 40,
              child: GestureDetector(
                onTap: () async {
                  _audioPlayer.play(
                    AssetSource('audio/lumi_town/level7/respect_roxie2_rc.wav'),
                  );
                  // 2. The Magic Fix: Wait for BOTH the reaction AND the audio to finish!
                  await Future.wait([
                    showDrWooReactionQuietly(DrWooState.correct),
                    _audioPlayer.onPlayerComplete.first,
                  ]);

                  // 3. Ensure the screen is still active
                  if (!mounted) return;

                  // 4. Navigate safely
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const Respect7Screen(),
                    ),
                  );
                },
                child: Image.asset(
                  'assets/images/objects/lumi/thumbs_down.png',
                  width: 100,
                  height: 100,
                ),
              ),
            ),
          ],

          // Close Button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Image.asset(
                    'assets/images/buttons/x_blue.png',
                    width: 50,
                    height: 50,
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
