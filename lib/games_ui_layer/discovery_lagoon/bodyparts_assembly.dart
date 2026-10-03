import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/tree_game.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../goodjob_prompt.dart';
import 'audio_helper.dart';
import 'intro_phase.dart';
import 'lagoon_game_ui.dart';

class BodyPartItem {
  final String id;
  final String imagePath;

  BodyPartItem({required this.id, required this.imagePath});
}

class BodyPartsAssemblyScreen extends StatefulWidget {
  final int level;

  const BodyPartsAssemblyScreen({super.key, required this.level});

  @override
  State<BodyPartsAssemblyScreen> createState() =>
      _BodyPartsAssemblyScreenState();
}

class _BodyPartsAssemblyScreenState extends State<BodyPartsAssemblyScreen>
    with
        TickerProviderStateMixin,
        LagoonIntroMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<BodyPartsAssemblyScreen> {
  final AudioPlayer _player = AudioPlayer();
  final GameTapTracker _tapTracker = GameTapTracker();

  @override
  AudioPlayer get introAudioPlayer => _player;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_player];

  static const String _bgImage =
      'assets/images/backgrounds/bg_rainbow_closeup2.png';
  static const String _kikiFishboneImage =
      'assets/images/characters/cat_holding_fishbone.png';
  static const String _boyImage = 'assets/images/objects/lagoon/boy.png';

  static const String _introAudio =
      'assets/audio/discovery_lagoon/bodyparts_assembly_intro.wav';
  static const String _winAudio =
      'assets/audio/discovery_lagoon/bodyparts_assembly_win.wav';

  LagoonScreenPhase _screenPhase = LagoonScreenPhase.intro;

  final Set<String> _matchedParts = {};
  late List<BodyPartItem> _availableParts;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  final List<BodyPartItem> _allParts = [
    BodyPartItem(
      id: 'head',
      imagePath: 'assets/images/objects/lagoon/head.png',
    ),
    BodyPartItem(
      id: 'shoulder',
      imagePath: 'assets/images/objects/lagoon/shoulder.png',
    ),
    BodyPartItem(
      id: 'knee',
      imagePath: 'assets/images/objects/lagoon/knee.png',
    ),
    BodyPartItem(
      id: 'feet',
      imagePath: 'assets/images/objects/lagoon/feet.png',
    ),
  ];

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

    initLagoonIntro();
    _resetGame();

    startLagoonIntro(
      introAudioAsset: _introAudio,
      onGameStart: () {
        if (mounted) setState(() => _screenPhase = LagoonScreenPhase.game);
      },
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeLagoonIntro();
    _player.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _matchedParts.clear();
      _availableParts = List.from(_allParts)..shuffle();
      _hasSavedResult = false;
      _tapTracker.startSession();
    });
  }

  Future<void> _saveDataAndShowSuccessDialog() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    LagoonDatabaseService.saveGameData(
      gameId: 'lagoon_bodyparts',
      activityName: 'Body Parts Assembly',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    if (mounted) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (context) => GoodJobOverlay(
        characterImage: _kikiFishboneImage,
        characterSizeFactor: 0.9,
        onNext: () {
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TreeGameScreen(level: widget.level + 1),
            ),
          );
        },
        onRestart: () {
          Navigator.pop(context);
          setState(() {
            _screenPhase = LagoonScreenPhase.game;
            _resetGame();
          });
        },
        onBack: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          Positioned.fill(
            top: 50,
            child: _screenPhase == LagoonScreenPhase.intro
                ? buildLagoonIntroCharacter()
                : _buildGameContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double h = constraints.maxHeight;
          final double w = constraints.maxWidth;

          // Left side = diagram
          final double diagramWidth = w * 0.62;
          final double diagramHeight = h;

          final double optionsWidth = w * 0.38;

          return Row(
            children: [
              // =========================
              // LEFT: BODY DIAGRAM
              // =========================
              SizedBox(
                width: diagramWidth,
                height: diagramHeight,
                child: LayoutBuilder(
                  builder: (context, diagramConstraints) {
                    final double dh = diagramConstraints.maxHeight;
                    final double dw = diagramConstraints.maxWidth;

                    final double cx = dw / 2;
                    final double cy = dh / 2;

                    final double boxSize = dh * 0.20;

                    final double boyHeight = dh * 0.95;
                    final double boyWidth = boyHeight * 0.6;

                    final double boyLeft = cx - boyWidth / 2;
                    final double boyTop = cy - boyHeight / 2;

                    final Offset headTarget = Offset(
                      boyLeft + boyWidth * 0.20,
                      boyTop + boyHeight * 0.15,
                    );

                    final Offset shoulderTarget = Offset(
                      boyLeft + boyWidth * 0.71,
                      boyTop + boyHeight * 0.44,
                    );

                    final Offset kneeTarget = Offset(
                      boyLeft + boyWidth * 0.68,
                      boyTop + boyHeight * 0.80,
                    );

                    final Offset feetTarget = Offset(
                      boyLeft + boyWidth * 0.29,
                      boyTop + boyHeight * 0.92,
                    );

                    // Left/right target boxes around the boy
                    final Offset headBoxCenter = Offset(
                      cx - dh * 0.32,
                      cy - dh * 0.25,
                    );

                    final Offset shoulderBoxCenter = Offset(
                      cx + dh * 0.32,
                      cy - dh * 0.20,
                    );

                    final Offset feetBoxCenter = Offset(
                      cx - dh * 0.32,
                      cy + dh * 0.25,
                    );

                    final Offset kneeBoxCenter = Offset(
                      cx + dh * 0.32,
                      cy + dh * 0.25,
                    );

                    return Stack(
                      children: [
                        // Boy
                        Center(
                          child: Image.asset(
                            _boyImage,
                            height: boyHeight,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Connecting lines
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ConnectingLinesPainter(
                              headBox: headBoxCenter,
                              headTarget: headTarget,
                              shoulderBox: shoulderBoxCenter,
                              shoulderTarget: shoulderTarget,
                              feetBox: feetBoxCenter,
                              feetTarget: feetTarget,
                              kneeBox: kneeBoxCenter,
                              kneeTarget: kneeTarget,
                            ),
                          ),
                        ),

                        // HEAD
                        Positioned(
                          left: headBoxCenter.dx - boxSize / 2,
                          top: headBoxCenter.dy - boxSize / 2,
                          child: _buildTargetBox('head', boxSize),
                        ),

                        // SHOULDER
                        Positioned(
                          left: shoulderBoxCenter.dx - boxSize / 2,
                          top: shoulderBoxCenter.dy - boxSize / 2,
                          child: _buildTargetBox('shoulder', boxSize),
                        ),

                        // FEET
                        Positioned(
                          left: feetBoxCenter.dx - boxSize / 2,
                          top: feetBoxCenter.dy - boxSize / 2,
                          child: _buildTargetBox('feet', boxSize),
                        ),

                        // KNEE
                        Positioned(
                          left: kneeBoxCenter.dx - boxSize / 2,
                          top: kneeBoxCenter.dy - boxSize / 2,
                          child: _buildTargetBox('knee', boxSize),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // =========================
              // RIGHT: 2x2 OPTIONS
              // =========================
              SizedBox(
                width: optionsWidth,
                height: diagramHeight,
                child: Center(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                          childAspectRatio: 1,
                        ),
                    itemCount: _availableParts.length,
                    itemBuilder: (context, index) {
                      final part = _availableParts[index];

                      if (_matchedParts.contains(part.id)) {
                        return const SizedBox.shrink();
                      }

                      return Center(
                        child: Draggable<String>(
                          data: part.id,

                          onDragEnd: (details) {
                            if (!details.wasAccepted) {
                              _tapTracker.recordMistake();
                            }
                          },

                          feedback: _DraggableImage(
                            imagePath: part.imagePath,
                            isDragging: true,
                          ),

                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _DraggableImage(imagePath: part.imagePath),
                          ),

                          child: _DraggableImage(imagePath: part.imagePath),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTargetBox(String targetId, double size) {
    bool isMatched = _matchedParts.contains(targetId);
    String? matchedImagePath = isMatched
        ? _allParts.firstWhere((p) => p.id == targetId).imagePath
        : null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          details.data == targetId && !isMatched,
      onAcceptWithDetails: (details) async {
        _tapTracker.recordCorrectTap();

        setState(() {
          _matchedParts.add(targetId);
        });

        if (_matchedParts.length == _allParts.length) {
          await _player.play(
            AssetSource(_winAudio.replaceFirst('assets/', '')),
          );

          await _player.onPlayerComplete.first;

          if (mounted) {
            await _saveDataAndShowSuccessDialog();
          }
        } else {
          LagoonAudio.instance.play(targetId);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isHovering
                ? Colors.white
                : Colors.white.withValues(alpha: 0.9),
            border: Border.all(
              color: isHovering ? Colors.green : Colors.black87,
              width: isHovering ? 6 : 4,
            ),
            boxShadow: [
              if (isHovering)
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
            ],
          ),
          child: isMatched
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(matchedImagePath!, fit: BoxFit.contain),
                )
              : null,
        );
      },
    );
  }
}

class _DraggableImage extends StatelessWidget {
  final String imagePath;
  final bool isDragging;

  const _DraggableImage({required this.imagePath, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: isDragging ? 1.2 : 1.0,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class ConnectingLinesPainter extends CustomPainter {
  final Offset headBox, headTarget;
  final Offset shoulderBox, shoulderTarget;
  final Offset feetBox, feetTarget;
  final Offset kneeBox, kneeTarget;

  ConnectingLinesPainter({
    required this.headBox,
    required this.headTarget,
    required this.shoulderBox,
    required this.shoulderTarget,
    required this.feetBox,
    required this.feetTarget,
    required this.kneeBox,
    required this.kneeTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    void drawConnection(Offset box, Offset target) {
      canvas.drawLine(box, target, linePaint);
      canvas.drawCircle(target, 6.0, dotPaint);
    }

    drawConnection(headBox, headTarget);
    drawConnection(shoulderBox, shoulderTarget);
    drawConnection(feetBox, feetTarget);
    drawConnection(kneeBox, kneeTarget);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
