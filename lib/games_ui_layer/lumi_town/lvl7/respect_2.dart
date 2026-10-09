import 'dart:math' as math;
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl7/respect_3.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../games_audio_helper.dart';
import '../lumi_game_ui_layer.dart';

class Respect2Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Respect2Screen({
    Key? key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  }) : super(key: key);

  @override
  State<Respect2Screen> createState() => _Respect2ScreenState();
}

class _Respect2ScreenState extends State<Respect2Screen>
    with
        TickerProviderStateMixin,
        TrWooReactionMixin,
        AiCameraMixin<Respect2Screen>,
        AppAudioLifecycleMixin<Respect2Screen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _walkController;

  final Duration _walkDuration = const Duration(milliseconds: 1800);
  final Duration _stepDuration = const Duration(milliseconds: 260);
  final double _bounceHeightFraction = 0.045;

  bool _showButtons = false;
  bool _answered = false;
  bool _hideLightingCard = false;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  @override
  void initState() {
    super.initState();
    _walkController = AnimationController(vsync: this, duration: _walkDuration);

    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _walkController.forward(from: 0);
      _playSceneAudio();
    });
  }

  @override
  void dispose() {
    disposeAiCamera();
    _walkController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  AudioPlayer get trWooPlayer => _audioPlayer;

  Future<void> showDrWooReactionQuietly(TrWooState state) async {
    if (!mounted) return;
    setState(() => trWooState = state);

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => trWooState = TrWooState.normal);
  }

  Future<void> _playSceneAudio() async {
    try {
      await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level7/respect_jack1.wav');
      await waitForAudio(_audioPlayer);
      if (!mounted) return;

      setState(() {
        _showButtons = true;
      });
    } catch (e) {
      debugPrint('Error playing scene audio: $e');
    }
  }

  @override
  Widget buildTrWoo(BuildContext context) {
    final owlHeight = MediaQuery.of(context).size.height * 1.18;

    return Positioned(
      left: MediaQuery.of(context).size.width * 0.10,
      bottom: -(owlHeight * 0.15),
      child: SizedBox(
        height: owlHeight,
        child: switch (trWooState) {
          TrWooState.correct => Image.asset(
            'assets/animations/characters/dr.woo_thumbsup.webp',
            fit: BoxFit.contain,
          ),
          TrWooState.wrong => Image.asset(
            'assets/images/characters/tr.woo_tryagain.png',
            fit: BoxFit.contain,
          ),
          TrWooState.normal => Image.asset(
            'assets/images/characters/tr.woo_standing.png',
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

    final double startX = sw;
    final int stepCount =
        (_walkDuration.inMilliseconds / _stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);
    final double bounceHeightPx = roxieHeight * _bounceHeightFraction;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_classroom.png',
              fit: BoxFit.cover,
            ),

            buildTrWoo(context),

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
                  right: (sw * 0.08) - dx,
                  bottom: -(baseCharacterHeight * 0.15) + bounce,
                  child: SizedBox(
                    height: roxieHeight,
                    child: Image.asset(
                      'assets/images/characters/jack_the_fox.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),

            if (_showButtons) ...[
              // Jack 1: Thumbs Up is Wrong
              Positioned(
                left: 20,
                bottom: 40,
                child: GestureDetector(
                  onTap: () {
                    if (_answered) return;
                    widget.tapTracker.recordMistake();
                    GamesSfxPlayer.instance.play(GameSfx.bubblePop);
                    showTrWooReaction(TrWooState.wrong);
                  },
                  child: Image.asset(
                    'assets/images/objects/lumi/thumbs_up.png',
                    width: 100,
                    height: 100,
                  ),
                ),
              ),

              // Jack 1: Thumbs Down is Correct
              Positioned(
                right: 20,
                bottom: 40,
                child: GestureDetector(
                  onTap: () async {
                    if (_answered) return;
                    setState(() => _answered = true);
                    widget.tapTracker.recordCorrectTap();
                    showTrWooReaction(TrWooState.correct);
                    await playAssetAudio(_audioPlayer, 'assets/audio/lumi_town/level7/respect_jack1_rc.wav');
                    await waitForAudio(_audioPlayer);
                    if (!mounted) return;

                    final emotionsSoFar = [
                      ...widget.priorEmotions,
                      ...stopAiCamera(),
                    ];
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => Respect3Screen(
                          priorEmotions: emotionsSoFar,
                          tapTracker: widget.tapTracker,
                          level: widget.level,
                        ),
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
