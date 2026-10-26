import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/app_audio_lifecycle_mixin.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../ai_camera_mixin.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'arctic_game_ui.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart'; 

const String kDefaultTracingSuccessAudio = 'assets/audio/arctic_numberland/mahusay.wav';

const String _kCaneAsset = 'assets/images/objects/arctic/candy_cane.png';

const Map<int, List<List<Offset>>> kNumberStrokes = {
  0: [
    [
      Offset(0.50, 0.20),
      Offset(0.40, 0.24),
      Offset(0.33, 0.35),
      Offset(0.30, 0.50),
      Offset(0.33, 0.65),
      Offset(0.40, 0.76),
      Offset(0.50, 0.80),
      Offset(0.60, 0.76),
      Offset(0.67, 0.65),
      Offset(0.70, 0.50),
      Offset(0.67, 0.35),
      Offset(0.60, 0.24),
      Offset(0.50, 0.20),
    ],
  ],
  1: [
    [Offset(0.35, 0.3), Offset(0.5, 0.2), Offset(0.5, 0.8)],
  ],
  2: [
    [
      Offset(0.30, 0.30),
      Offset(0.35, 0.23),
      Offset(0.44, 0.20),
      Offset(0.55, 0.20),
      Offset(0.65, 0.24),
      Offset(0.70, 0.32),
      Offset(0.67, 0.41),
      Offset(0.58, 0.50),
      Offset(0.45, 0.62),
      Offset(0.34, 0.74),
      Offset(0.30, 0.80),
      Offset(0.40, 0.80),
      Offset(0.55, 0.80),
      Offset(0.70, 0.80),
    ],
  ],
  3: [
    [
      Offset(0.30, 0.30),
      Offset(0.36, 0.23),
      Offset(0.45, 0.20),
      Offset(0.55, 0.20),
      Offset(0.64, 0.24),
      Offset(0.69, 0.31),
      Offset(0.66, 0.39),
      Offset(0.56, 0.45),
      Offset(0.45, 0.49),
      Offset(0.57, 0.52),
      Offset(0.66, 0.57),
      Offset(0.70, 0.65),
      Offset(0.67, 0.74),
      Offset(0.58, 0.80),
      Offset(0.48, 0.82),
      Offset(0.39, 0.80),
      Offset(0.31, 0.74),
    ],
  ],
  4: [
    [Offset(0.62, 0.2), Offset(0.3, 0.6)],
    [Offset(0.3, 0.6), Offset(0.72, 0.6)],
    [Offset(0.62, 0.2), Offset(0.62, 0.85)],
  ],
  5: [
    [Offset(0.68, 0.2), Offset(0.35, 0.2), Offset(0.35, 0.48)],
    [
      Offset(0.35, 0.48),
      Offset(0.45, 0.45),
      Offset(0.56, 0.45),
      Offset(0.65, 0.49),
      Offset(0.70, 0.57),
      Offset(0.70, 0.67),
      Offset(0.65, 0.76),
      Offset(0.56, 0.81),
      Offset(0.46, 0.82),
      Offset(0.37, 0.79),
      Offset(0.31, 0.74),
    ],
  ],
  6: [
    [
      Offset(0.62, 0.22),
      Offset(0.50, 0.27),
      Offset(0.40, 0.38),
      Offset(0.33, 0.52),
      Offset(0.32, 0.65),
      Offset(0.38, 0.76),
      Offset(0.48, 0.81),
      Offset(0.58, 0.80),
      Offset(0.66, 0.73),
      Offset(0.68, 0.64),
      Offset(0.63, 0.56),
      Offset(0.54, 0.53),
      Offset(0.44, 0.55),
      Offset(0.36, 0.62),
    ],
  ],
  7: [
    [Offset(0.3, 0.22), Offset(0.7, 0.22)],
    [Offset(0.7, 0.22), Offset(0.42, 0.82)],
  ],
  8: [
    [
      Offset(0.50, 0.50),
      Offset(0.41, 0.47),
      Offset(0.36, 0.41),
      Offset(0.35, 0.34),
      Offset(0.38, 0.27),
      Offset(0.44, 0.22),
      Offset(0.50, 0.20),
      Offset(0.56, 0.22),
      Offset(0.62, 0.27),
      Offset(0.65, 0.34),
      Offset(0.64, 0.41),
      Offset(0.59, 0.47),
      Offset(0.50, 0.50),
    ],
    [
      Offset(0.50, 0.50),
      Offset(0.40, 0.53),
      Offset(0.34, 0.59),
      Offset(0.33, 0.66),
      Offset(0.37, 0.73),
      Offset(0.43, 0.78),
      Offset(0.50, 0.80),
      Offset(0.57, 0.78),
      Offset(0.63, 0.73),
      Offset(0.67, 0.66),
      Offset(0.66, 0.59),
      Offset(0.60, 0.53),
      Offset(0.50, 0.50),
    ],
  ],
  9: [
    [
      Offset(0.64, 0.38),
      Offset(0.56, 0.45),
      Offset(0.46, 0.47),
      Offset(0.37, 0.44),
      Offset(0.32, 0.36),
      Offset(0.34, 0.27),
      Offset(0.42, 0.20),
      Offset(0.52, 0.19),
      Offset(0.62, 0.24),
      Offset(0.68, 0.35),
      Offset(0.67, 0.48),
      Offset(0.60, 0.62),
      Offset(0.50, 0.73),
      Offset(0.38, 0.78),
    ],
  ],
  10: [
    [Offset(0.18, 0.3), Offset(0.28, 0.2), Offset(0.28, 0.8)],
    [
      Offset(0.65, 0.20),
      Offset(0.565, 0.24),
      Offset(0.50, 0.35),
      Offset(0.48, 0.50),
      Offset(0.50, 0.65),
      Offset(0.565, 0.76),
      Offset(0.65, 0.80),
      Offset(0.735, 0.76),
      Offset(0.80, 0.65),
      Offset(0.82, 0.50),
      Offset(0.80, 0.35),
      Offset(0.735, 0.24),
      Offset(0.65, 0.20),
    ],
  ],
};

class NumberTracingWidget extends StatefulWidget {
  final int number;
  final AudioPlayer player;
  final VoidCallback onComplete;
  final String successAudio;
  final int level;
  final GameTapTracker tapTracker;
  final bool enabled;
  final Widget? hintBackground;

  const NumberTracingWidget({
    super.key,
    required this.number,
    required this.player,
    required this.onComplete,
    required this.level,
    required this.tapTracker,
    this.enabled = true,
    this.hintBackground,
    this.successAudio = kDefaultTracingSuccessAudio,
  });

  @override
  State<NumberTracingWidget> createState() => _NumberTracingWidgetState();
}

class _NumberTracingWidgetState extends State<NumberTracingWidget>
  with AiCameraMixin, AppAudioLifecycleMixin, IdleHintMixin  {

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  List<List<Offset>> _denseStrokes = [];

  int _currentStrokeIndex = 0;
  int _currentPointIndex = 0;

  bool _tracingComplete = false;
  bool _awaitingLift = false;
  bool _touchValid = false;

  Offset? _canePosition;

  double _cachedW = -1;
  double _cachedH = -1;
  int _cachedNumber = -1;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) startIdleTimer();
  }

  @override
  void didUpdateWidget(covariant NumberTracingWidget old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) {
      cancelIdleTimer();
      showHowToPlay = false;
    } else if (!old.enabled || old.number != widget.number) {
      showHowToPlay = false;
      startIdleTimer();
    }
  }

  @override
  void dispose() {
    disposeIdleTimer();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        widget.tapTracker.recordGenericTap();
        cancelIdleTimer();
        if (showHowToPlay) setState(() => showHowToPlay = false);
      },
      onPointerUp: (_) {
        if (widget.enabled && !_tracingComplete) startIdleTimer();
      },
      onPointerCancel: (_) {
        if (widget.enabled && !_tracingComplete) startIdleTimer();
      },
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _buildTracingLayer(constraints.maxWidth, constraints.maxHeight),
      ),
    );
  }

  Widget _buildTracingLayer(double w, double h, {bool preview = false}) {
    final caneSize = h * 0.14;
    final numberSize = h * 0.70;
    final traceW = numberSize * 0.78;
    final traceH = numberSize;
    final traceLeft = w / 2 - traceW / 2;
    final traceTop = h / 2 - traceH / 2 + 20;

    final containerW = traceW;
    final containerH = traceH * 0.85;
    final containerLeft = w / 2 - containerW / 2;
    final containerTop = h / 2 - containerH / 2 + 20;

    final numberOffsetX = 0.0;
    final numberOffsetY = 0.0;

      if (!preview &&
      (_cachedW != traceW ||
      _cachedH != traceH ||
      _cachedNumber != widget.number)) {
      _cachedW = traceW;
      _cachedH = traceH;
      _cachedNumber = widget.number;
      _denseStrokes = _buildDenseStrokes(
        kNumberStrokes[widget.number] ?? kNumberStrokes[1]!,
        traceW,
        traceH,
      );
      _currentStrokeIndex = 0;
      _currentPointIndex = 0;
      _tracingComplete = false;
      _awaitingLift = false;   
      _touchValid = false;
    }

    final totalPoints = _denseStrokes.fold<int>(0, (sum, s) => sum + s.length);
    final donePoints =
        _denseStrokes
            .take(_currentStrokeIndex)
            .fold<int>(0, (sum, s) => sum + s.length) +
        _currentPointIndex;
    final progress = totalPoints == 0 ? 0.0 : donePoints / totalPoints;

    return Stack(
      children: [
        if (donePoints > 5)
          Positioned(
            key: const ValueKey('progress_bar'),
            bottom: h * 0.06,
            left: w * 0.15,
            right: w * 0.15,
            child: _buildProgressBar(progress),
          ),

        Positioned(
          key: const ValueKey('header'),
          left: 25,
          right: 25,
          top: 25,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(alignment: Alignment.centerLeft, child: ArcticXButton()),
              Align(
                alignment: Alignment.centerRight,
                child: ArcticLevelBadge(level: widget.level),
              ),
            ],
          ),
        ),

        Positioned(
          key: const ValueKey('trace_container'),
          left: containerLeft,
          top: containerTop,
          width: containerW,
          height: containerH,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ArcticColorTheme.pictonblue, width: 4),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Transform.translate(
                  offset: Offset(numberOffsetX, numberOffsetY),
                  child: SizedBox(
                    width: traceW,
                    height: traceH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _onPanStart(d, traceW),          
                      onPanUpdate: (details) => _onPanUpdate(details, traceW),
                      onPanEnd: (_) => _onPanEnd(),                       
                      onPanCancel: _onPanEnd,                             
                      child: CustomPaint(
                        size: Size(traceW, traceH),
                        painter: _NumberGuidePainter(
                          denseStrokes: _denseStrokes,
                          currentStrokeIndex: _currentStrokeIndex,
                          currentPointIndex: _currentPointIndex,
                          complete: _tracingComplete,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        if (!preview && _canePosition != null)
          Positioned(
            key: const ValueKey('cane_moving'),
            left: traceLeft + _canePosition!.dx - caneSize * 0.15,
            top: traceTop + _canePosition!.dy - caneSize * 0.92,
            child: IgnorePointer(
              child: Image.asset(
                _kCaneAsset,
                width: caneSize,
                fit: BoxFit.contain,
              ),
            ),
          ),

        if (!preview && _canePosition == null && !_tracingComplete)
          Positioned(
            key: const ValueKey('cane_idle'),
            bottom: h * 0.08,
            left: w * 0.06,
            child: IgnorePointer(
              child: Image.asset(
                _kCaneAsset,
                width: caneSize,
                fit: BoxFit.contain,
              ),
            ),
          ),

        if (!preview &&
            showHowToPlay &&
            widget.enabled &&
            !_tracingComplete &&
            _currentStrokeIndex < _denseStrokes.length)
          Positioned.fill(child: _buildHowToPlay(w, h, traceW, traceH)),
      ],
    );
  }

  Alignment _traceToAlignment(
      Offset p, double w, double h, double traceW, double traceH) {
    final containerH = traceH * 0.85;
    final s = min((traceW - 8) / traceW, (containerH - 8) / traceH);
    final cx = w / 2;
    final cy = h / 2 + 20;
    final x = cx + (p.dx - traceW / 2) * s;
    final y = cy + (p.dy - traceH / 2) * s;
    return Alignment(x / w * 2 - 1, y / h * 2 - 1);
  }

  Widget _buildHowToPlay(double w, double h, double traceW, double traceH) {
    final stroke = _denseStrokes[_currentStrokeIndex];
    final int end = min<int>(
      stroke.length - 1,
      _currentPointIndex + max<int>(10, (stroke.length * 0.3).round()),
    );
    final int start = min<int>(_currentPointIndex, max<int>(0, end - 10));

    return HowToPlayOverlay(
      previewChild: Stack(
        children: [
          Positioned.fill(
            child: widget.hintBackground ??
                const ColoredBox(color: ArcticColorTheme.lightgrayishcyan),
          ),
          LayoutBuilder(
            builder: (context, c) =>
                _buildTracingLayer(c.maxWidth, c.maxHeight, preview: true),
          ),
        ],
      ),
      handAlignment: _traceToAlignment(stroke[start], w, h, traceW, traceH),
      handEndAlignment: _traceToAlignment(stroke[end], w, h, traceW, traceH),
      handOffset: const Offset(0.15, 0.46),
      onDismiss: resetIdleTimer,
    );
  }

  List<List<Offset>> _buildDenseStrokes(
    List<List<Offset>> fractionalStrokes,
    double w,
    double h,
  ) {
    final dense = <List<Offset>>[];
    for (final stroke in fractionalStrokes) {
      final pts = stroke.map((p) => Offset(p.dx * w, p.dy * h)).toList();
      if (pts.length < 2) {
        dense.add(pts);
        continue;
      }

      final points = <Offset>[];
      for (int i = 0; i < pts.length - 1; i++) {
        final p0 = i == 0 ? pts[i] : pts[i - 1];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];

        final distance = (p2 - p1).distance;
        final steps = (distance / 5.0).ceil().clamp(1, 999);
        for (int j = 0; j <= steps; j++) {
          final t = j / steps;
          points.add(_catmullRom(p0, p1, p2, p3, t));
        }
      }
      dense.add(points);
    }
    return dense;
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

  void _onPanStart(DragStartDetails details, double traceW) {
    _touchValid = false;
    if (!widget.enabled || _tracingComplete) return;
    if (_awaitingLift) return;
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    final stroke = _denseStrokes[_currentStrokeIndex];
    if (_currentPointIndex >= stroke.length) return;

    // finger must land on the current guide dot
    final d = (details.localPosition - stroke[_currentPointIndex]).distance;
    _touchValid = d < traceW * 0.18;
  }

  void _onPanEnd() {
    setState(() {
      _canePosition = null;
      _awaitingLift = false;
      _touchValid = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, double traceW) {
    if (!widget.enabled) return;
    if (_tracingComplete) return;
    cancelIdleTimer();
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) {
      return;
    }

    final dragPos = details.localPosition;

    if (_awaitingLift || !_touchValid) {
      setState(() => _canePosition = dragPos);
      return;
    }

    final threshold = traceW * 0.14;
    const lookAhead = 20;
    final currentStroke = _denseStrokes[_currentStrokeIndex];

    setState(() {
      _canePosition = dragPos;

      final end = min(currentStroke.length, _currentPointIndex + lookAhead);
      int best = -1;
      for (int i = _currentPointIndex; i < end; i++) {
        if ((dragPos - currentStroke[i]).distance < threshold) {
          best = i;
        }
      }

      if (best != -1) {
        _currentPointIndex = best + 1;

        if (_currentPointIndex >= currentStroke.length) {
          _currentStrokeIndex++;
          _currentPointIndex = 0;
          _awaitingLift = true;
          _touchValid = false;
          if (_currentStrokeIndex >= _denseStrokes.length) {
            _accept();
          }
        }
      }
    });
  }

  Future<void> _accept() async {
    if (_tracingComplete) return;
    cancelIdleTimer();

    widget.tapTracker.recordCorrectTap();

    setState(() {
      _tracingComplete = true;
      _canePosition = null;
    });
    try {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, widget.successAudio);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) widget.onComplete();
  }

  Widget _buildProgressBar(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  gradient: LinearGradient(
                    colors: _tracingComplete
                        ? [Colors.greenAccent, Colors.green]
                        : [
                            ArcticColorTheme.pictonblue,
                            ArcticColorTheme.slateblue,
                          ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              left: 6,
              right: 6,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberGuidePainter extends CustomPainter {
  final List<List<Offset>> denseStrokes;
  final int currentStrokeIndex;
  final int currentPointIndex;
  final bool complete;

  _NumberGuidePainter({
    required this.denseStrokes,
    required this.currentStrokeIndex,
    required this.currentPointIndex,
    required this.complete,
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
      ..strokeWidth = size.width * 0.18
      ..style = PaintingStyle.stroke;
    for (final stroke in denseStrokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, bgPaint);
    }
    canvas.restore();

    final fillPaint = Paint()
      ..color = complete ? Colors.greenAccent : ArcticColorTheme.pictonblue
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.15
      ..style = PaintingStyle.stroke;

    final guidePaint = Paint()
      ..color = ArcticColorTheme.slateblue
      ..style = PaintingStyle.fill;

    for (int i = 0; i < denseStrokes.length; i++) {
      final stroke = denseStrokes[i];
      if (stroke.isEmpty) continue;

      if (i < currentStrokeIndex) {
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (final p in stroke.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, fillPaint);
      } else if (i == currentStrokeIndex) {
        if (currentPointIndex > 0) {
          final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
          for (int j = 1; j < currentPointIndex; j++) {
            path.lineTo(stroke[j].dx, stroke[j].dy);
          }
          canvas.drawPath(path, fillPaint);
        }
        if (currentPointIndex < stroke.length) {
          canvas.drawCircle(
            stroke[currentPointIndex],
            size.width * 0.09,
            guidePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_NumberGuidePainter old) =>
      old.denseStrokes != denseStrokes ||
      old.currentStrokeIndex != currentStrokeIndex ||
      old.currentPointIndex != currentPointIndex ||
      old.complete != complete;
}
