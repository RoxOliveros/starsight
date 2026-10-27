import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/season_scene_tap_screen.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../goodjob_prompt.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'kiki_reaction.dart';
import 'lagoon_audio_path.dart';
import 'lagoon_game_ui.dart';

class TreeGameScreen extends StatefulWidget {
  final int level;

  const TreeGameScreen({super.key, required this.level});

  @override
  State<TreeGameScreen> createState() => _TreeGameScreenState();
}

class _TreePart {
  final String id;
  final String asset;
  final double width;
  final double height;
  final double targetLeft;
  final double targetTop;
  final Alignment scatterPosition;
  final double scatterTilt;

  const _TreePart({
    required this.id,
    required this.asset,
    required this.width,
    required this.height,
    required this.targetLeft,
    required this.targetTop,
    required this.scatterPosition,
    this.scatterTilt = 0.0,
  });
}

class _TreeGameScreenState extends State<TreeGameScreen>
    with AppAudioLifecycleMixin<TreeGameScreen>, AiCameraMixin<TreeGameScreen>, KikiReactionMixin, IdleHintMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _kikiPlayer= AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _kikiPlayer];

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  static const String _introAudio = 'audio/discovery_lagoon/tree_game_intro.wav';

  static const String _fullTreeAsset = 'assets/images/objects/lagoon/t5_tree.png';

  static const double _canvasWidth = 260;
  static const double _canvasHeight = 311;

  static const double _kikiAlignX = -1.00;
  static const double _kikiAlignY = 1.70;
  static const double _kikiHeight = 230.0;

  static const double _trunkScatterX = -0.45;
  static const double _trunkScatterY = 0.55;

  static const List<_TreePart> _parts = [
    _TreePart(
      id: 'leaves',
      asset: 'assets/images/objects/lagoon/t4_leaves.png',
      width: 1.0,
      height: 0.65,
      targetLeft: 0.0,
      targetTop: 0.0,
      scatterPosition: Alignment(-0.85, -0.8),
      scatterTilt: -0.08,
    ),
    _TreePart(
      id: 'branch',
      asset: 'assets/images/objects/lagoon/t3_branch.png',
      width: 0.388,
      height: 0.248,
      targetLeft: 0.310,
      targetTop: 0.434,
      scatterPosition: Alignment(0.9, -0.6),
      scatterTilt: 0.12,
    ),
    _TreePart(
      id: 'trunk',
      asset: 'assets/images/objects/lagoon/t2_trunk.png',
      width: 0.244,
      height: 0.30,
      targetLeft: 0.394,
      targetTop: 0.564,
      scatterPosition: Alignment(_trunkScatterX, _trunkScatterY),
      scatterTilt: -0.10,
    ),
    _TreePart(
      id: 'root',
      asset: 'assets/images/objects/lagoon/t1_root.png',
      width: 1.0,
      height: 0.20,
      targetLeft: 0.0,
      targetTop: 0.78,
      scatterPosition: Alignment(0.85, 0.85),
      scatterTilt: 0.07,
    ),
  ];

  static const Map<String, String> _partAudio = {
    'leaves': LagoonAudio.leaves,
    'branch': LagoonAudio.branch,
    'trunk': LagoonAudio.trunk,
    'root': LagoonAudio.roots,
  };

  final Set<String> _placed = {};
  bool _showOverlay = false;
  bool _showIntro = true;

  final GameTapTracker _tapTracker = GameTapTracker();

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  bool get isCompleted => _placed.length == _parts.length;

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

    _playIntroAudio();
  }

  Future<void> _playIntroAudio() async {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _showIntro = false;
        });
        if (!isCompleted) startIdleTimer();
      }
    });

    await playVoiceRestartingOnFaceLoss(_audioPlayer, _introAudio);
  }

  Future<void> _playPartAudio(String partId) async {
    final audio = _partAudio[partId];
    if (audio == null) return;

    await playVoiceRestartingOnFaceLoss(_audioPlayer, audio);
    await _audioPlayer.onPlayerComplete.first;
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _audioPlayer.dispose();
    _kikiPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    cancelIdleTimer();
    List<String> finalEmotions = stopAiCamera();

    LagoonDatabaseService.saveGameData(
      gameId: 'lagoon_tree_game',
      activityName: 'Tree Game',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });
    LagoonProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
    });

    if (mounted) {
      setState(() => _showOverlay = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
        onPointerDown: (_) {
          _tapTracker.recordGenericTap();
          if (!_showIntro && !_showOverlay && !isCompleted) resetIdleTimer();
        },
        child:  Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgrounds/bg_lagoon_fields.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            isCompleted ? _buildCompletedTree() : _buildGameArea(),

            if (!_showIntro)
              Align(
                alignment: const Alignment(_kikiAlignX, _kikiAlignY),
                child: Image.asset(
                  'assets/images/characters/kiki_the_cat.png',
                  height: _kikiHeight,
                ),
              ),

            if (_showIntro)
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.75),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: -150,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          'assets/images/characters/kiki_the_cat.png',
                          height: 500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Positioned(top: 25, left: 25, child: const LagoonXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LagoonLevelBadge(level: widget.level),
            ),

            if (showHowToPlay &&
                !_showIntro &&
                !_showOverlay &&
                !isCompleted)
              Positioned.fill(
                child: Builder(
                  builder: (context) {
                    final sz = MediaQuery.of(context).size;
                    final g = _hintGeometry();
                    Alignment toAlign(Offset p) => Alignment(
                      p.dx / sz.width * 2 - 1,
                      p.dy / sz.height * 2 - 1,
                    );
                    return HowToPlayOverlay(
                      previewChild: _buildHowToPreview(),
                      handAlignment: toAlign(g.piece),
                      handEndAlignment: toAlign(g.target),
                      handOffset: const Offset(0.15, 0.46),
                      onDismiss: resetIdleTimer,
                    );
                  },
                ),
              ),

            if (_showOverlay)
              GoodJobOverlay(
                characterImage:
                    'assets/images/characters/cat_holding_fishbone.png',
                characterSizeFactor: 0.9,
                onNext: () {
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const SeasonSceneTapScreen(level: 14),
                      ),
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    _placed.clear();
                    _showOverlay = false;
                    _hasSavedResult = false;
                    _tapTracker.startSession();
                  });
                  startIdleTimer();
                },
                onBack: () => Navigator.of(context).pop(),
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
        ),
    );
  }

  _TreePart get _samplePart => _parts.firstWhere((p) => p.id == 'leaves');

  ({Offset piece, Offset target}) _hintGeometry() {
    final mq = MediaQuery.of(context);
    final sz = mq.size;
    final pad = mq.padding;
    final areaW = sz.width - pad.left - pad.right;
    final areaH = sz.height - pad.top - pad.bottom;
    final part = _samplePart;
    final pw = part.width * _canvasWidth;
    final ph = part.height * _canvasHeight;

    final a = part.scatterPosition;
    final piece = Offset(
      pad.left + (a.x + 1) / 2 * (areaW - pw) + pw / 2,
      pad.top + (a.y + 1) / 2 * (areaH - ph) + ph / 2,
    );

    final canvasLeft = pad.left + (areaW - _canvasWidth) / 2;
    final canvasTop = pad.top + (areaH - _canvasHeight) / 2;
    final target = Offset(
      canvasLeft + part.targetLeft * _canvasWidth + pw / 2,
      canvasTop + part.targetTop * _canvasHeight + ph / 2,
    );
    return (piece: piece, target: target);
  }

  Widget _buildHowToPreview() {
    final part = _samplePart;
    final pw = part.width * _canvasWidth;
    final ph = part.height * _canvasHeight;
    final g = _hintGeometry();

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/bg_lagoon_fields.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          left: g.target.dx - pw / 2,
          top: g.target.dy - ph / 2,
          width: pw,
          height: ph,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Positioned(
          left: g.piece.dx - pw / 2,
          top: g.piece.dy - ph / 2,
          child: _piece(part),
        ),
      ],
    );
  }

  Widget _buildCompletedTree() {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final treeHeight = (constraints.maxHeight * 0.8).clamp(120.0, 350.0);
          return Center(child: Image.asset(_fullTreeAsset, height: treeHeight));
        },
      ),
    );
  }

  Widget _buildGameArea() {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: _canvasWidth,
              height: _canvasHeight,
              child: Stack(
                children: [for (final part in _parts) _buildTarget(part)],
              ),
            ),
          ),
          for (final part in _parts)
            if (!_placed.contains(part.id))
              Align(
                alignment: part.scatterPosition,
                child: Transform.rotate(
                  angle: part.scatterTilt,
                  child: _buildDraggable(part),
                ),
              ),
        ],
      ),
    );
  }

  Widget _piece(_TreePart part) => Image.asset(
    part.asset,
    width: part.width * _canvasWidth,
    height: part.height * _canvasHeight,
    fit: BoxFit.contain,
  );

  Widget _buildDraggable(_TreePart part) {
    return Draggable<String>(
      data: part.id,
      onDragStarted: cancelIdleTimer,
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          startIdleTimer();
          _tapTracker.recordMistake();
        }
      },
      feedback: Material(color: Colors.transparent, child: _piece(part)),
      childWhenDragging: Opacity(opacity: 0.3, child: _piece(part)),
      child: _piece(part),
    );
  }

  Widget _buildTarget(_TreePart part) {
    final boxWidth = part.width * _canvasWidth;
    final boxHeight = part.height * _canvasHeight;

    return Positioned(
      left: part.targetLeft * _canvasWidth,
      top: part.targetTop * _canvasHeight,
      width: boxWidth,
      height: boxHeight,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data == part.id,
        onAcceptWithDetails: (details) async {
          _tapTracker.recordCorrectTap();

          setState(() {
            _placed.add(part.id);
          });

          await _playPartAudio(part.id);

          if (_placed.length == _parts.length) {
            showKikiReaction(KikiState.correct);

            await Future.delayed(const Duration(seconds: 2));

            if (mounted) {
              _saveDataAndShowGoodJob();
            }
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isPlaced = _placed.contains(part.id);
          final isTargeted = candidateData.isNotEmpty;
          return Container(
            decoration: isTargeted && !isPlaced
                ? BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  )
                : null,
            child: isPlaced ? _piece(part) : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
