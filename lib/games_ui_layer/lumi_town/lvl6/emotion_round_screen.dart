import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl6/emotion_ending.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../games_audio_helper.dart';
import '../../how_to_play_overlay.dart';
import '../../idle_hint_mixin.dart';
import '../lumi_game_ui_layer.dart';

class _Choice {
  final String emotion;
  final bool correct;
  const _Choice(this.emotion, {this.correct = false});
}

const List<List<_Choice>> _kRounds = [
  [_Choice('angry'), _Choice('disgust'), _Choice('happy', correct: true)],
  [_Choice('sad', correct: true), _Choice('happy'), _Choice('angry')],
  [_Choice('scared', correct: true), _Choice('wow'), _Choice('angry')],
  [_Choice('happy'), _Choice('disgust', correct: true), _Choice('sad')],
  [_Choice('angry', correct: true), _Choice('disgust'), _Choice('sad')],
  [_Choice('wow', correct: true), _Choice('disgust'), _Choice('sad')],
];

class EmotionRoundScreen extends StatefulWidget {
  final int roundIndex;
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const EmotionRoundScreen({
    super.key,
    required this.roundIndex,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<EmotionRoundScreen> createState() => _EmotionRoundScreenState();
}

class _EmotionRoundScreenState extends State<EmotionRoundScreen>
    with
        TrWooReactionMixin,
        AiCameraMixin<EmotionRoundScreen>,
        AppAudioLifecycleMixin<EmotionRoundScreen>,
        IdleHintMixin<EmotionRoundScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _trWooPlayer = AudioPlayer();
  StreamSubscription? _audioSub;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _trWooPlayer];

  @override
  AudioPlayer get trWooPlayer => _trWooPlayer;

  bool _isCorrectlyAnswered = false;
  bool _showSparkles = false;
  bool _showStars = false;
  bool _isSuccessAudioPlaying = false;
  bool _hideLightingCard = false;

  // ── Per-round data ────────────────────────────────────────────────────────
  List<_Choice> get _choices => _kRounds[widget.roundIndex];
  int get _n => widget.roundIndex + 1;

  String get _promptAudio =>
      'assets/audio/lumi_town/level6/emotion_p$_n.wav';
  String get _rightAudio =>
      'assets/audio/lumi_town/level6/emotion_p${_n}_rc.wav';
  String get _sceneWrong => 'assets/images/objects/lumi/e${_n}_wrong.png';
  String get _sceneRight => 'assets/images/objects/lumi/e${_n}_right.png';

  // ── Lifecycle ─────────────────────────────────────────────────────────────
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
    _audioSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_isSuccessAudioPlaying) {
        _goNext();
      } else {
        setState(() => _showStars = true);
        startIdleTimer();
      }
    });
    await playVoiceRestartingOnFaceLoss(_audioPlayer, _promptAudio);
  }

  void _goNext() {
    final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];
    final isLast = widget.roundIndex >= _kRounds.length - 1;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLast
            ? EmotionEndingScreen(
                priorEmotions: emotionsSoFar,
                tapTracker: widget.tapTracker,
                level: widget.level,
              )
            : EmotionRoundScreen(
                roundIndex: widget.roundIndex + 1,
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
    disposeIdleTimer();
    _audioSub?.cancel();
    _audioPlayer.dispose();
    _trWooPlayer.dispose();
    super.dispose();
  }

  // ── Drop handling ─────────────────────────────────────────────────────────
  Future<void> _onDrop(TrWooState droppedState) async {
    showTrWooReaction(droppedState);

    if (droppedState == TrWooState.correct && !_isCorrectlyAnswered) {
      widget.tapTracker.recordCorrectTap();
      _isCorrectlyAnswered = true;
      _isSuccessAudioPlaying = true;
      cancelIdleTimer();
      setState(() {
        _showStars = false;
        showHowToPlay = false;
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await playVoiceRestartingOnFaceLoss(_audioPlayer, _rightAudio);

      if (!mounted) return;
      setState(() => _showSparkles = true);
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) setState(() => _showSparkles = false);
    } else if (!_isCorrectlyAnswered) {
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      widget.tapTracker.recordMistake();
    }
  }

  // ── Tr.Woo ────────────────────────────────────────────────────────────────
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) {
          widget.tapTracker.recordGenericTap();
          if (showHowToPlay) setState(() => showHowToPlay = false);
          cancelIdleTimer();
        },
        onPointerUp: (_) {
          if (_showStars && !_isCorrectlyAnswered) startIdleTimer();
        },
        onPointerCancel: (_) {
          if (_showStars && !_isCorrectlyAnswered) startIdleTimer();
        },
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/backgrounds/bg_game_emotion.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              ..._buildScene(screen.width, screen.height),

              Positioned(top: 25, left: 25, child: LumiXButton()),
              Positioned(
                top: 25,
                right: 25,
                child: LumiLevelBadge(level: widget.level),
              ),

              if (showHowToPlay && _showStars && !_isCorrectlyAnswered)
                Positioned.fill(child: _buildHowToPlay(screen)),

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

  List<Widget> _buildScene(double sw, double sh, {bool preview = false}) {
    final double centerW = sw * 0.60;
    final double centerH = sh * 0.75;
    final double starSize = sh * 0.23;
    final double paddingEdge = sw * 0.04;

    return [
      Center(
        child: SizedBox(
          width: centerW - (sh * 0.015 * 2),
          height: centerH - (sh * 0.015 * 2),
          child: DragTarget<TrWooState>(
            onAcceptWithDetails: (details) => _onDrop(details.data),
            builder: (context, candidateData, rejectedData) {
              return Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _isCorrectlyAnswered ? _sceneRight : _sceneWrong,
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

      Positioned(
        right: paddingEdge,
        top: sh * 0.20,
        bottom: sh * 0.02,
        child: IgnorePointer(
          ignoring: !_showStars,
          child: AnimatedOpacity(
            opacity: _showStars ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _choices.length; i++) ...[
                  if (i > 0) SizedBox(height: sh * 0.01),
                  preview
                      ? _buildBlankStar(starSize)
                      : _buildReactionDraggable(_choices[i], starSize),
                ],
              ],
            ),
          ),
        ),
      ),

      buildTrWoo(context),
    ];
  }

  Widget _buildBlankStar(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          Icons.star_rounded,
          size: size * 0.8,
          color: const Color(0xFFFFD54F),
        ),
      ),
    );
  }

  Widget _buildReactionDraggable(_Choice choice, double size) {
    final asset = 'assets/images/objects/lumi/${choice.emotion}_wb.png';
    return Draggable<TrWooState>(
      data: choice.correct ? TrWooState.correct : TrWooState.wrong,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(asset, width: size, height: size),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Image.asset(asset, width: size, height: size),
      ),
      child: Image.asset(asset, width: size, height: size),
    );
  }

  Widget _buildHowToPlay(Size screen) {
    return HowToPlayOverlay(
      previewChild: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_game_emotion.png',
            fit: BoxFit.cover,
          ),
          ..._buildScene(screen.width, screen.height, preview: true),
        ],
      ),
      handAlignment: _starAlignment(0, screen.width, screen.height),
      handEndAlignment: Alignment.center,
      handOffset: const Offset(0.15, 0.4),
      onDismiss: resetIdleTimer,
    );
  }

  Alignment _starAlignment(int i, double sw, double sh) {
    final double size = sh * 0.23;
    final double gap = sh * 0.01;
    final double avail = sh * 0.78;
    final double content = _choices.length * size + (_choices.length - 1) * gap;
    final double cy = sh * 0.20 + (avail - content) / 2 + i * (size + gap) + size / 2;
    final double cx = sw - sw * 0.04 - size / 2;
    return Alignment(cx / sw * 2 - 1, cy / sh * 2 - 1);
  }
}
