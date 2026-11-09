import 'dart:async';

import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/forest_database_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/trace_letter_data.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../business_layer/forest_progress_service.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_level.dart';
import '../goodjob_prompt.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'alphabet_game_ui.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forest_flow.dart';

class AlphabetTraceScreen extends StatefulWidget {
  final int level;

  const AlphabetTraceScreen({super.key, required this.level});

  @override
  State<AlphabetTraceScreen> createState() => _AlphabetTraceScreenState();
}

class _AlphabetTraceScreenState extends State<AlphabetTraceScreen>
    with
        TofiReactionMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<AlphabetTraceScreen>,
        IdleHintMixin {
  final GameTapTracker _tapTracker = GameTapTracker();
  final GlobalKey _canvasKey = GlobalKey();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _tofiPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _tofiPlayer];

  @override
  AudioPlayer get tofiPlayer => _tofiPlayer;

  int _currentStrokeIndex = 0;
  int _currentPointIndex = 0;

  List<List<Offset>> _denseStrokes = [];

  static const String _traceInstructionWav =
      'assets/audio/alphabet_forest/trace_letter_instruction.wav';

  late final List<TraceStep> _steps;
  int _stepIndex = 0;

  TraceStep get _step => _steps[_stepIndex];

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _awaitingLift = false;
  bool _touchValid = false;
  bool _audioFinished = false;

  bool _isDotStroke(List<Offset> stroke) => stroke.length <= 3;

  bool get _hintActive =>
      _audioFinished &&
      !_hasSavedResult &&
      _denseStrokes.isNotEmpty &&
      _currentStrokeIndex < _denseStrokes.length;

  bool get _hintAllowed => showHowToPlay && _hintActive;

  Timer? _demoTimer;

  Size _lastCanvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // child's calibration separate from everyone else's.
    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera(); // <-- Start the camera
    _tapTracker.startSession();

    // Lighting card can reappear later if the face is lost again mid-play.
    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };
    _steps = [
      for (final l in ForestFlow.traceLetters(widget.level))
        for (final t in TraceData.forLetter(l)) TraceStep(l, t),
    ];
    _playInstructionThenLetter();
  }

  Future<void> _playInstructionThenLetter() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        _traceInstructionWav,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      await _playDemo(); 
      if (!mounted) return; 
      await _playLetterSound();
    } finally {
      if (mounted) {
        setState(() => _audioFinished = true);
        startIdleTimer();
      }
    }
  }

  Future<void> _playDemo() async {
    for (int i = 0; i < 50 && _denseStrokes.isEmpty && mounted; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted || _denseStrokes.isEmpty) return;

    final done = Completer<void>();
    int hold = 0;
    _resetBoard();

    _demoTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_currentStrokeIndex >= _denseStrokes.length) {
        t.cancel();
        if (!done.isCompleted) done.complete();
        return;
      }
      final stroke = _denseStrokes[_currentStrokeIndex];
      setState(() {
        if (_isDotStroke(stroke)) {
          if (++hold < 40) return;
          hold = 0;
          _currentStrokeIndex++;
          _currentPointIndex = 0;
        } else {
          _currentPointIndex += 1;
          if (_currentPointIndex >= stroke.length) {
            _currentStrokeIndex++;
            _currentPointIndex = 0;
          }
        }
      });
    });

    await done.future;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _resetBoard();
  }

  Future<void> _playLetterSound() => playVoiceRestartingOnFaceLoss(
    _audioPlayer,
    'assets/audio/alphabet_forest/sound_effects/sound_${_step.letter.toLowerCase()}.wav',
  );

  @override
  void dispose() {
    _demoTimer?.cancel();
    disposeAiCamera();
    disposeIdleTimer();
    OrientationService.setLandscape();
    _audioPlayer.dispose();
    _tofiPlayer.dispose();
    super.dispose();
  }

  void _generateDensePaths(Size size) {
    if (size.isEmpty) return;

    List<List<Offset>> newDenseStrokes = [];

    for (var stroke in _step.trace.strokes) {
      final pts = stroke
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();

      if (pts.length < 2) {
        newDenseStrokes.add(pts);
        continue;
      }

      List<Offset> densePoints = [];
      for (int i = 0; i < pts.length - 1; i++) {
        final p0 = i == 0
            ? pts[i]
            : pts[i - 1]; // ADD: neighbor points for the curve
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];

        final distance = (p2 - p1).distance;
        final steps = (distance / 5.0).ceil().clamp(1, 999);

        for (int j = 0; j <= steps; j++) {
          final t = j / steps;
          densePoints.add(
            _catmullRom(p0, p1, p2, p3, t),
          ); // CHANGED from straight lerp
        }
      }
      newDenseStrokes.add(densePoints);
    }

    setState(() {
      _denseStrokes = newDenseStrokes;
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (!_audioFinished) return;
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    final stroke = _denseStrokes[_currentStrokeIndex];
    if (!_isDotStroke(stroke)) return;

    if ((details.localPosition - stroke.first).distance < 60.0) {
      setState(() => _currentPointIndex = stroke.length);
      _moveToNextStroke();
      _awaitingLift = false;
    }
  }

  Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    final x =
        0.5 *
        ((2 * p1.dx) +
            (p2.dx - p0.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (3 * p1.dx - p0.dx - 3 * p2.dx + p3.dx) * t3);
    final y =
        0.5 *
        ((2 * p1.dy) +
            (p2.dy - p0.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (3 * p1.dy - p0.dy - 3 * p2.dy + p3.dy) * t3);
    return Offset(x, y);
  }

  void _onPanStart(DragStartDetails details) {
    _touchValid = false;
    if (!_audioFinished) return;
    if (_awaitingLift) return;
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    final stroke = _denseStrokes[_currentStrokeIndex];
    if (_isDotStroke(stroke)) return;
    if (_currentPointIndex >= stroke.length) return;

    final d = (details.localPosition - stroke[_currentPointIndex]).distance;
    _touchValid = d < 60.0;
  }

  void _onPanEnd(DragEndDetails details) {
    _awaitingLift = false;
    _touchValid = false;
  }

  void _onPanCancel() {
    _awaitingLift = false;
    _touchValid = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_awaitingLift || !_touchValid) return;
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    final dragPos = details.localPosition;
    final currentStroke = _denseStrokes[_currentStrokeIndex];
    if (_currentPointIndex >= currentStroke.length) return;

    const double reach = 40.0;
    const int lookAhead = 20;

    int best = -1;
    double bestDist = reach;
    final end = min(currentStroke.length, _currentPointIndex + lookAhead);

    for (int i = _currentPointIndex; i < end; i++) {
      final d = (dragPos - currentStroke[i]).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }

    if (best < 0) return;

    setState(() => _currentPointIndex = best + 1);

    if (_currentPointIndex >= currentStroke.length) {
      _moveToNextStroke();
    }
  }

  void _moveToNextStroke() {
    _tapTracker.recordCorrectTap();
    _awaitingLift = true;
    _touchValid = false;
    setState(() {
      _currentStrokeIndex++;
      _currentPointIndex = 0;
    });

    if (_currentStrokeIndex >= _denseStrokes.length) {
      _showSuccessDialog();
    }
  }

  void _resetBoard() {
    setState(() {
      _currentStrokeIndex = 0;
      _currentPointIndex = 0;
    });
  }

  Future<void> _showSuccessDialog() async {
    cancelIdleTimer();
    if (showHowToPlay) setState(() => showHowToPlay = false);
    await showTofiReaction(TofiState.correct);
    if (!mounted) return;

    if (_stepIndex + 1 < _steps.length) {
      final bool newLetter = _steps[_stepIndex + 1].letter != _step.letter;

      setState(() {
        _resetBoard();
        _stepIndex++;
        _audioFinished = false;
      });
      _generateDensePaths(_lastCanvasSize);

      await _playDemo();
      if (!mounted) return;

      if (newLetter) {
        try {
          await _playLetterSound();
        } catch (e) {
          debugPrint('Letter audio error: $e');
        }
        if (!mounted) return;
      }

      setState(() => _audioFinished = true);
      startIdleTimer();
      return;
    }

    if (_hasSavedResult) return;
    _hasSavedResult = true;
    final List<String> finalEmotions = stopAiCamera();
    final letters = ForestFlow.traceLetters(widget.level);

    ForestDatabaseService.saveGameData(
      gameId: 'letter_trace_level_${widget.level}',
      activityName: "Alphabet Trace (${letters.first}-${letters.last})",
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      // strokes completed
      mistakes: 0,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    _showGoodJob();
  }

  void _showGoodJob() {
    ForestProgressService.instance.markLevelComplete(widget.level);

    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: 'assets/images/characters/dog.png',
          onNext: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ForestFlow.screenAfterLevel(widget.level),
              ),
            );
          },
          onRestart: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AlphabetTraceScreen(level: widget.level),
              ),
            );
          },
          onBack: () {
            Navigator.of(context).pop(); // close dialog
            ForestNav.backToLevels(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (!_hintActive) return;
        if (showHowToPlay) setState(() => showHowToPlay = false);
        cancelIdleTimer();
      },
      onPointerUp: (_) {
        if (_hintActive) startIdleTimer();
      },
      onPointerCancel: (_) {
        if (_hintActive) startIdleTimer();
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildScene(),

            if (_hintAllowed) Positioned.fill(child: _buildHowToPlay()),

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

  Widget _buildScene({bool preview = false}) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/bg_game_forest.png',
            fit: BoxFit.cover,
          ),
        ),

        Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 80,
                  child: Stack(
                    children: [
                      const Positioned(
                        top: 25,
                        left: 25,
                        child: ForestXButton(),
                      ),
                      Positioned(
                        top: 25,
                        right: 20,
                        child: ForestLevelBadge(level: widget.level),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Container(
                          key: preview ? null : _canvasKey,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: ForestColorTheme.lightgreen,
                              width: 4,
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = constraints.biggest;
                              if (!preview && size != _lastCanvasSize) {
                                _lastCanvasSize = size;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) _generateDensePaths(size);
                                });
                              }
                              return Stack(
                                children: [
                                  GestureDetector(
                                    onTapDown: _onTapDown,
                                    onPanStart: _onPanStart,
                                    onPanUpdate: _onPanUpdate,
                                    onPanEnd: _onPanEnd,
                                    onPanCancel: _onPanCancel,
                                    child: CustomPaint(
                                      painter: GuidedTracePainter(
                                        denseStrokes: _denseStrokes,
                                        currentStrokeIndex: _currentStrokeIndex,
                                        currentPointIndex: _currentPointIndex,
                                      ),
                                      size: Size.infinite,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            buildTofi(context),
          ],
        ),
      ],
    );
  }

  List<Alignment> _canvasPath(List<Offset> points) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    if (box == null || root == null || !box.hasSize) return [];

    return points.map((p) {
      final g = box.localToGlobal(p + const Offset(4, 4), ancestor: root);
      return Alignment(
        g.dx / root.size.width * 2 - 1,
        g.dy / root.size.height * 2 - 1,
      );
    }).toList();
  }

  Widget _buildHowToPlay() {
    final stroke = _denseStrokes[_currentStrokeIndex];
    final from = min(_currentPointIndex, stroke.length - 1);

    List<Alignment> path;
    if (_isDotStroke(stroke)) {
      path = _canvasPath([stroke[from]]);
    } else {
      final to = min(stroke.length - 1, from + 60);
      final pts = <Offset>[];
      for (int i = from; i <= to; i += 3) {
        pts.add(stroke[i]);
      }
      if ((to - from) % 3 != 0) pts.add(stroke[to]);
      path = _canvasPath(pts);
    }

    return HowToPlayOverlay(
      handAlignment: path.isNotEmpty ? path.first : Alignment.center,
      handPath: path.length >= 2 ? path : null,
      handOffset: const Offset(0.15, 0.45),
      onDismiss: startIdleTimer,
      previewChild: _buildScene(preview: true),
    );
  }
}

class GuidedTracePainter extends CustomPainter {
  final List<List<Offset>> denseStrokes;
  final int currentStrokeIndex;
  final int currentPointIndex;

  GuidedTracePainter({
    required this.denseStrokes,
    required this.currentStrokeIndex,
    required this.currentPointIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (denseStrokes.isEmpty) return;

    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );

    final bgPaint = Paint()
      ..color = Colors.grey.shade900
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 35.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < denseStrokes.length; i++) {
      var stroke = denseStrokes[i];
      if (stroke.isEmpty) continue;

      Path bgPath = Path();
      bgPath.moveTo(stroke[0].dx, stroke[0].dy);
      for (int j = 1; j < stroke.length; j++) {
        bgPath.lineTo(stroke[j].dx, stroke[j].dy);
      }
      canvas.drawPath(bgPath, bgPaint);
    }

    canvas.restore();

    final fillPaint = Paint()
      ..color = ForestColorTheme.mediumseagreen
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 30.0
      ..style = PaintingStyle.stroke;

    final guidePaint = Paint()
      ..color = ForestColorTheme.darkseagreen
      ..style = PaintingStyle.fill;

    for (int i = 0; i < denseStrokes.length; i++) {
      var stroke = denseStrokes[i];
      if (stroke.isEmpty) continue;

      if (i < currentStrokeIndex) {
        Path fillPath = Path();
        fillPath.moveTo(stroke[0].dx, stroke[0].dy);
        for (int j = 1; j < stroke.length; j++) {
          fillPath.lineTo(stroke[j].dx, stroke[j].dy);
        }
        canvas.drawPath(fillPath, fillPaint);
      } else if (i == currentStrokeIndex) {
        if (currentPointIndex > 0) {
          Path fillPath = Path();
          fillPath.moveTo(stroke[0].dx, stroke[0].dy);
          for (int j = 1; j < currentPointIndex; j++) {
            fillPath.lineTo(stroke[j].dx, stroke[j].dy);
          }
          canvas.drawPath(fillPath, fillPaint);
        }

        if (currentPointIndex < stroke.length) {
          canvas.drawCircle(stroke[currentPointIndex], 20.0, guidePaint);

          final iconPaint = Paint()
            ..color = Colors.white
            ..strokeWidth = 4.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          Offset center = stroke[currentPointIndex];
          canvas.drawLine(
            Offset(center.dx - 5, center.dy),
            Offset(center.dx, center.dy + 5),
            iconPaint,
          );
          canvas.drawLine(
            Offset(center.dx, center.dy + 5),
            Offset(center.dx + 8, center.dy - 6),
            iconPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuidedTracePainter oldDelegate) => true;
}
