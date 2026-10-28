import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl7/respect_ending.dart';
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

/// One round of the respect game (old respect_1 .. respect_7).
///
/// [audio]      -> respect_<audio>.wav (question) and respect_<audio>_rc.wav (reply)
/// [character]  -> assets/images/characters/<character>.png
/// [rightFraction] -> distance of the character from the right edge (x screen width)
/// [thumbsUp]   -> true if thumbs UP is the correct answer, false if thumbs DOWN
class _RespectRound {
  final String audio;
  final String character;
  final double rightFraction;
  final bool thumbsUp;
  const _RespectRound(
    this.audio,
    this.character,
    this.rightFraction, {
    required this.thumbsUp,
  });
}

const List<_RespectRound> _kRounds = [
  _RespectRound('roxie1', 'roxie_standing', 0.08, thumbsUp: true),
  _RespectRound('jack1', 'jack_the_fox', 0.08, thumbsUp: false),
  _RespectRound('bear1', 'little_bear_uniform', 0.15, thumbsUp: true),
  _RespectRound('kiki1', 'kiki_the_cat', 0.10, thumbsUp: false),
  _RespectRound('tofee1', 'tofi_smiling', 0.10, thumbsUp: true),
  _RespectRound('roxie2', 'roxie_standing', 0.08, thumbsUp: false),
  _RespectRound('doma1', 'doma_the_penguin2', 0.08, thumbsUp: true),
];

class RespectRoundScreen extends StatefulWidget {
  /// 0-based: 0 = first round after LumiClassroomScreen, 6 = last round.
  final int roundIndex;
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const RespectRoundScreen({
    super.key,
    required this.roundIndex,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<RespectRoundScreen> createState() => _RespectRoundScreenState();
}

class _RespectRoundScreenState extends State<RespectRoundScreen>
    with
        TickerProviderStateMixin,
        TrWooReactionMixin,
        AiCameraMixin<RespectRoundScreen>,
        AppAudioLifecycleMixin<RespectRoundScreen>,
        IdleHintMixin<RespectRoundScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _walkController;

  final Duration _walkDuration = const Duration(milliseconds: 1800);
  final Duration _stepDuration = const Duration(milliseconds: 260);
  final double _bounceHeightFraction = 0.045;

  bool _showButtons = false;
  bool _answered = false;
  bool _hideLightingCard = false;

  static const String _audioBase = 'assets/audio/lumi_town/level7/respect_';

  // Thumb button layout (shared by live buttons, preview and hand positions)
  static const double _thumbSize = 100;
  static const double _thumbSide = 20;
  static const double _thumbBottom = 40;

  _RespectRound get _round => _kRounds[widget.roundIndex];

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  @override
  AudioPlayer get trWooPlayer => _audioPlayer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
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
    disposeIdleTimer();
    _walkController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSceneAudio() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        '$_audioBase${_round.audio}.wav',
      );
      if (!mounted) return;
      setState(() => _showButtons = true);
      startIdleTimer();
    } catch (e) {
      debugPrint('Error playing scene audio: $e');
    }
  }

  // ── Answering ─────────────────────────────────────────────────────────────
  Future<void> _onThumb({required bool up}) async {
    if (_answered) return;

    if (up != _round.thumbsUp) {
      widget.tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTrWooReaction(TrWooState.wrong);
      return;
    }

    setState(() {
      _answered = true;
      showHowToPlay = false;
    });
    cancelIdleTimer();
    widget.tapTracker.recordCorrectTap();
    showTrWooReaction(TrWooState.correct);
    await playVoiceRestartingOnFaceLoss(
      _audioPlayer,
      '$_audioBase${_round.audio}_rc.wav',
    );

    if (!mounted) return;
    _goNext();
  }

  void _goNext() {
    final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];
    final isLast = widget.roundIndex >= _kRounds.length - 1;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLast
            ? RespectEnding(
                priorEmotions: emotionsSoFar,
                tapTracker: widget.tapTracker,
                level: widget.level,
              )
            : RespectRoundScreen(
                roundIndex: widget.roundIndex + 1,
                priorEmotions: emotionsSoFar,
                tapTracker: widget.tapTracker,
                level: widget.level,
              ),
      ),
    );
  }

  // ── Tr.Woo ────────────────────────────────────────────────────────────────
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
          if (_showButtons && !_answered) startIdleTimer();
        },
        onPointerCancel: (_) {
          if (_showButtons && !_answered) startIdleTimer();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_classroom.png',
              fit: BoxFit.cover,
            ),

            buildTrWoo(context),

            _buildWalkingCharacter(screen),

            if (_showButtons) ...[
              Positioned(
                left: _thumbSide,
                bottom: _thumbBottom,
                child: _thumb(up: true, onTap: () => _onThumb(up: true)),
              ),
              Positioned(
                right: _thumbSide,
                bottom: _thumbBottom,
                child: _thumb(up: false, onTap: () => _onThumb(up: false)),
              ),
            ],

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LumiLevelBadge(level: widget.level),
            ),

            if (showHowToPlay && _showButtons && !_answered)
              Positioned.fill(child: _buildHowToPlay(screen)),

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

  Widget _thumb({required bool up, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        up
            ? 'assets/images/objects/lumi/thumbs_up.png'
            : 'assets/images/objects/lumi/thumbs_down.png',
        width: _thumbSize,
        height: _thumbSize,
      ),
    );
  }

  /// The character who walks in from the right and bounces like steps.
  Widget _buildWalkingCharacter(Size screen) {
    final double sw = screen.width;
    final double baseH = screen.height * 1.18;
    final double charH = baseH * 0.70;
    final int stepCount =
        (_walkDuration.inMilliseconds / _stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);
    final double bouncePx = charH * _bounceHeightFraction;

    return AnimatedBuilder(
      animation: _walkController,
      builder: (context, child) {
        final double t = _walkController.value;
        final double easedT = Curves.easeOutCubic.transform(t);
        final double dx = sw * (1 - easedT);
        final double bounce =
            t < 1.0 ? (math.sin(t * stepCount * math.pi)).abs() * bouncePx : 0.0;

        return Positioned(
          right: (sw * _round.rightFraction) - dx,
          bottom: -(baseH * 0.15) + bounce,
          child: SizedBox(height: charH, child: child),
        );
      },
      child: Image.asset(
        'assets/images/characters/${_round.character}.png',
        fit: BoxFit.contain,
      ),
    );
  }

  // ── How to play ───────────────────────────────────────────────────────────
  Widget _buildHowToPlay(Size screen) {
    final double sw = screen.width;
    final double sh = screen.height;
    final double baseH = sh * 1.18;
    final double charH = baseH * 0.70;

    // Static copy of the scene with the character already in place
    final preview = Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/bg_lumi_classroom.png',
          fit: BoxFit.cover,
        ),
        buildTrWoo(context),
        Positioned(
          right: sw * _round.rightFraction,
          bottom: -(baseH * 0.15),
          child: SizedBox(
            height: charH,
            child: Image.asset(
              'assets/images/characters/${_round.character}.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(left: _thumbSide, bottom: _thumbBottom, child: _thumb(up: true)),
        Positioned(right: _thumbSide, bottom: _thumbBottom, child: _thumb(up: false)),
      ],
    );

    // Centers of the two buttons
    final double cy = sh - _thumbBottom - _thumbSize / 2;
    final Offset upCenter = Offset(_thumbSide + _thumbSize / 2, cy);
    final Offset downCenter = Offset(sw - _thumbSide - _thumbSize / 2, cy);

    Alignment align(Offset c) =>
        Alignment(c.dx / sw * 2 - 1, c.dy / sh * 2 - 1);

    // The hand taps BOTH buttons in turn, so the hint never shows which
    // answer is the right one.
    return HowToPlayOverlay(
      previewChild: preview,
      handAlignment: align(upCenter),
      handEndAlignment: align(downCenter),
      tapSequence: true,
      handOffset: const Offset(0.15, 0.4),
      onDismiss: resetIdleTimer,
    );
  }
}
