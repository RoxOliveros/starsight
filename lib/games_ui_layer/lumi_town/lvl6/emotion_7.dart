import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_8.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../lumi_game_ui_layer.dart';

class Emotion7Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Emotion7Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker, required this.level,
  });

  @override
  State<Emotion7Screen> createState() => _Emotion7ScreenState();
}

class _Emotion7ScreenState extends State<Emotion7Screen>
    with TrWooReactionMixin, AiCameraMixin<Emotion7Screen> {
  late final AudioPlayer _audioPlayer;
  late final AudioPlayer _narratorPlayer;

  bool _isCorrectlyAnswered = false;
  bool _showSparkles = false;
  bool _showStars = false;
  bool _isSuccessAudioPlaying = false;
  bool _hideLightingCard = false;

  static const String _audioP5 = 'audio/lumi_town/level6/emotion_p5.wav';
  static const String _audioP5Rc = 'audio/lumi_town/level6/emotion_p5_rc.wav';

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _audioPlayer = AudioPlayer();
    _narratorPlayer = AudioPlayer();

    _playIntroAudio();
  }

  Future<void> _playIntroAudio() async {
    _narratorPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        if (_isSuccessAudioPlaying) {
          final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Emotion8Screen(
                priorEmotions: emotionsSoFar,
                tapTracker: widget.tapTracker,
                level: widget.level
              ),
            ),
          );
        } else {
          setState(() {
            _showStars = true;
          });
        }
      }
    });

    await _narratorPlayer.play(AssetSource(_audioP5));
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    _narratorPlayer.dispose();
    super.dispose();
  }

  @override
  Widget buildTrWoo(BuildContext context) {
    return Positioned(
      left: 10,
      bottom: 0,
      child: FractionalTranslation(
        translation: const Offset(0, 0.02),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.70,
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
      ),
    );
  }

  @override
  AudioPlayer get trWooPlayer => _audioPlayer;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    final double centerImageWidth = screenWidth * 0.60;
    final double centerImageHeight = screenHeight * 0.75;
    final double starButtonSize = screenHeight * 0.23;
    final double paddingEdge = screenWidth * 0.04;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/images/backgrounds/bg_game_emotion.png',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: centerImageWidth - (screenHeight * 0.015 * 2),
                  height: centerImageHeight - (screenHeight * 0.015 * 2),
                  child: DragTarget<TrWooState>(
                    onAcceptWithDetails: (details) async {
                      final droppedState = details.data;
                      showTrWooReaction(droppedState);

                      if (droppedState == TrWooState.correct &&
                          !_isCorrectlyAnswered) {
                        widget.tapTracker.recordCorrectTap();
                        _isCorrectlyAnswered = true;
                        _isSuccessAudioPlaying = true;
                        setState(() => _showStars = false);

                        await Future.delayed(
                          const Duration(milliseconds: 500),
                        );
                        await _narratorPlayer.stop();
                        await _narratorPlayer.play(AssetSource(_audioP5Rc));

                        setState(() => _showSparkles = true);
                        await Future.delayed(const Duration(seconds: 1));

                        if (mounted) {
                          setState(() {
                            _showSparkles = false;
                          });
                        }
                      } else if (!_isCorrectlyAnswered) {
                        widget.tapTracker.recordMistake();
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Stack(
                        alignment: Alignment.center,
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            _isCorrectlyAnswered
                                ? 'assets/images/objects/lumi/e5_right.png'
                                : 'assets/images/objects/lumi/e5_wrong.png',
                            fit: BoxFit.contain,
                          ),
                          IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: _showSparkles ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 400),
                              child: Image.asset(
                                'assets/images/objects/lumi/sparkle.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),


              Positioned(top: 25, left: 25, child: LumiXButton()),
              Positioned(top: 25,
                  right: 25,
                  child: LumiLevelBadge(level: widget.level)),

              Positioned(
                right: paddingEdge,
                top: screenHeight * 0.20,
                bottom: screenHeight * 0.02,
                child: IgnorePointer(
                  ignoring: !_showStars,
                  child: AnimatedOpacity(
                    opacity: _showStars ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildReactionDraggable(
                          'assets/images/objects/lumi/angry_wb.png',
                          TrWooState.correct,
                          starButtonSize,
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        _buildReactionDraggable(
                          'assets/images/objects/lumi/disgust_wb.png',
                          TrWooState.wrong,
                          starButtonSize,
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        _buildReactionDraggable(
                          'assets/images/objects/lumi/sad_wb.png',
                          TrWooState.wrong,
                          starButtonSize,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              buildTrWoo(context),

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

  Widget _buildReactionDraggable(
    String assetPath,
    TrWooState stateToTrigger,
    double size,
  ) {
    return Draggable<TrWooState>(
      data: stateToTrigger,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(assetPath, width: size, height: size),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Image.asset(assetPath, width: size, height: size),
      ),
      child: Image.asset(assetPath, width: size, height: size),
    );
  }
}
