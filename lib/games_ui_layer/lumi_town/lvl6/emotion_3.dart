import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_4.dart';
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

class Emotion3Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Emotion3Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Emotion3Screen> createState() => _Emotion3ScreenState();
}

class _Emotion3ScreenState extends State<Emotion3Screen>
    with
        TrWooReactionMixin,
        AiCameraMixin<Emotion3Screen>,
        AppAudioLifecycleMixin<Emotion3Screen> {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _trWooPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _trWooPlayer];

  bool _isCorrectlyAnswered = false;
  bool _showSparkles = false;
  bool _showStars = false;
  bool _isSuccessAudioPlaying = false;
  bool _hideLightingCard = false;

  static const String _audioP1 = 'assets/audio/lumi_town/level6/emotion_p1.wav';
  static const String _audioP1Rc = 'assets/audio/lumi_town/level6/emotion_p1_rc.wav';

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _playIntroAudio();
  }

  Future<void> _playIntroAudio() async {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        if (_isSuccessAudioPlaying) {
          final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Emotion4Screen(
                priorEmotions: emotionsSoFar,
                tapTracker: widget.tapTracker,
                level: widget.level,
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

    await playAssetAudio(_audioPlayer, _audioP1);
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    _trWooPlayer.dispose();
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
  AudioPlayer get trWooPlayer => _trWooPlayer;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    final double centerImageWidth = screenWidth * 0.60;
    final double centerImageHeight = screenHeight * 0.75;
    final double starButtonSize = screenHeight * 0.24;
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

                        await Future.delayed(const Duration(milliseconds: 500));
                        await playAssetAudio(_audioPlayer, _audioP1Rc);

                        setState(() => _showSparkles = true);
                        await Future.delayed(const Duration(seconds: 1));

                        if (mounted) {
                          setState(() {
                            _showSparkles = false;
                          });
                        }
                      } else if (!_isCorrectlyAnswered) {
                        GamesSfxPlayer.instance.play(GameSfx.bubblePop);
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
                                ? 'assets/images/objects/lumi/e1_right.png'
                                : 'assets/images/objects/lumi/e1_wrong.png',
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
              Positioned(
                top: 25,
                right: 25,
                child: LumiLevelBadge(level: widget.level),
              ),

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
                          TrWooState.wrong,
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
                          'assets/images/objects/lumi/happy_wb.png',
                          TrWooState.correct,
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
