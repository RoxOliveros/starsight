import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';

/// Default praise clip played on a successful trace, reused across numbers
/// so most callers don't need to pass their own.
const String kDefaultTracingSuccessAudio =
    'assets/audio/arctic_numberland/mahusay.wav';

/// Candy-cane cursor asset that follows the child's finger while tracing.
const String _kCaneAsset = 'assets/images/objects/arctic/candy_cane.png';

const Map<int, List<List<Offset>>> kNumberStrokes = {
  0: [
    [
      Offset(0.5, 0.2),
      Offset(0.3, 0.3),
      Offset(0.3, 0.7),
      Offset(0.5, 0.8),
      Offset(0.7, 0.7),
      Offset(0.7, 0.3),
      Offset(0.5, 0.2),
    ],
  ],
  1: [
    [Offset(0.35, 0.3), Offset(0.5, 0.2), Offset(0.5, 0.8)],
  ],
  2: [
    [
      Offset(0.3, 0.3),
      Offset(0.35, 0.2),
      Offset(0.55, 0.2),
      Offset(0.7, 0.3),
      Offset(0.7, 0.45),
      Offset(0.3, 0.75),
      Offset(0.3, 0.8),
      Offset(0.7, 0.8),
    ],
  ],
  3: [
    [
      Offset(0.32, 0.25),
      Offset(0.5, 0.2),
      Offset(0.68, 0.3),
      Offset(0.55, 0.45),
      Offset(0.4, 0.48),
      Offset(0.55, 0.52),
      Offset(0.68, 0.65),
      Offset(0.55, 0.78),
      Offset(0.35, 0.75),
    ],
  ],
  4: [
    [Offset(0.62, 0.2), Offset(0.3, 0.6), Offset(0.72, 0.6)],
    [Offset(0.62, 0.2), Offset(0.62, 0.85)],
  ],
  5: [
    [Offset(0.68, 0.2), Offset(0.35, 0.2), Offset(0.35, 0.48)],
    [
      Offset(0.35, 0.48),
      Offset(0.55, 0.45),
      Offset(0.7, 0.55),
      Offset(0.7, 0.7),
      Offset(0.55, 0.82),
      Offset(0.35, 0.78),
    ],
  ],
  6: [
    [
      Offset(0.62, 0.22),
      Offset(0.42, 0.3),
      Offset(0.32, 0.5),
      Offset(0.32, 0.68),
      Offset(0.45, 0.82),
      Offset(0.62, 0.8),
      Offset(0.7, 0.68),
      Offset(0.62, 0.55),
      Offset(0.45, 0.55),
      Offset(0.35, 0.62),
    ],
  ],
  7: [
    [Offset(0.3, 0.22), Offset(0.7, 0.22)],
    [Offset(0.7, 0.22), Offset(0.42, 0.82)],
  ],
  8: [
    [
      Offset(0.5, 0.5),
      Offset(0.35, 0.42),
      Offset(0.35, 0.28),
      Offset(0.5, 0.2),
      Offset(0.65, 0.28),
      Offset(0.65, 0.42),
      Offset(0.5, 0.5),
    ],
    [
      Offset(0.5, 0.5),
      Offset(0.35, 0.58),
      Offset(0.35, 0.72),
      Offset(0.5, 0.8),
      Offset(0.65, 0.72),
      Offset(0.65, 0.58),
      Offset(0.5, 0.5),
    ],
  ],
  9: [
    [
      Offset(0.62, 0.42),
      Offset(0.62, 0.28),
      Offset(0.48, 0.2),
      Offset(0.35, 0.28),
      Offset(0.35, 0.42),
      Offset(0.48, 0.5),
      Offset(0.62, 0.42),
      Offset(0.6, 0.6),
      Offset(0.5, 0.8),
    ],
  ],
};

class NumberTracingWidget extends StatefulWidget {
  final int number;
  final AudioPlayer player;
  final VoidCallback onComplete;
  final String successAudio;

  const NumberTracingWidget({
    super.key,
    required this.number,
    required this.player,
    required this.onComplete,
    this.successAudio = kDefaultTracingSuccessAudio,
  });

  @override
  State<NumberTracingWidget> createState() => _NumberTracingWidgetState();
}

class _NumberTracingWidgetState extends State<NumberTracingWidget> {
  List<List<Offset>> _denseStrokes = [];
  int _currentStrokeIndex = 0;
  int _currentPointIndex = 0;
  bool _tracingComplete = false;
  Offset? _canePosition; // local to the trace box

  double _cachedW = -1;
  double _cachedH = -1;
  int _cachedNumber = -1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildTracingLayer(constraints.maxWidth, constraints.maxHeight),
    );
  }

  Widget _buildTracingLayer(double w, double h) {
    final caneSize = h * 0.14;
    final numberSize = h * 0.85;
    final traceW = widget.number == 1 ? numberSize * 0.35 : numberSize * 0.5;
    final traceH = numberSize;
    final traceLeft = w / 2 - traceW / 2;
    final traceTop = h / 2 - traceH / 2 + 15;

    // (Re)generate the dense guide path whenever the box size or the
    // number changes -- e.g. rotating the device, or a new level loading
    // this same widget instance.
    if (_cachedW != traceW || _cachedH != traceH || _cachedNumber != widget.number) {
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
    }

    final totalPoints = _denseStrokes.fold<int>(0, (sum, s) => sum + s.length);
    final donePoints = _denseStrokes
            .take(_currentStrokeIndex)
            .fold<int>(0, (sum, s) => sum + s.length) +
        _currentPointIndex;
    final progress = totalPoints == 0 ? 0.0 : donePoints / totalPoints;

    return Stack(
      children: [
        if (donePoints > 5)
          Positioned(
            bottom: h * 0.06,
            left: w * 0.15,
            right: w * 0.15,
            child: _buildProgressBar(progress),
          ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: _buildBanner(h)),
        ),

        Positioned(
          left: traceLeft,
          top: traceTop,
          width: traceW,
          height: traceH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => _onPanUpdate(details, traceW),
            onPanEnd: (_) => setState(() => _canePosition = null),
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

        // Cane following finger
        if (_canePosition != null)
          Positioned(
            left: traceLeft + _canePosition!.dx - caneSize * 0.15,
            top: traceTop + _canePosition!.dy - caneSize * 0.92,
            child: IgnorePointer(
              child: Image.asset(_kCaneAsset, width: caneSize, fit: BoxFit.contain),
            ),
          ),

        // Cane resting
        if (_canePosition == null && !_tracingComplete)
          Positioned(
            bottom: h * 0.08,
            left: w * 0.06,
            child: IgnorePointer(
              child: Image.asset(_kCaneAsset, width: caneSize, fit: BoxFit.contain),
            ),
          ),
      ],
    );
  }

  // ── Dense path generation ─────────────────────────────────────────────
  List<List<Offset>> _buildDenseStrokes(
    List<List<Offset>> fractionalStrokes,
    double w,
    double h,
  ) {
    final dense = <List<Offset>>[];
    for (final stroke in fractionalStrokes) {
      final points = <Offset>[];
      for (int i = 0; i < stroke.length - 1; i++) {
        final p1 = Offset(stroke[i].dx * w, stroke[i].dy * h);
        final p2 = Offset(stroke[i + 1].dx * w, stroke[i + 1].dy * h);
        final distance = (p2 - p1).distance;
        final steps = (distance / 6.0).ceil().clamp(1, 999);
        for (int j = 0; j <= steps; j++) {
          points.add(Offset(
            p1.dx + (p2.dx - p1.dx) * (j / steps),
            p1.dy + (p2.dy - p1.dy) * (j / steps),
          ));
        }
      }
      dense.add(points);
    }
    return dense;
  }

  // ── Guided drag tracking ──────────────────────────────────────────────
  void _onPanUpdate(DragUpdateDetails details, double traceW) {
    if (_tracingComplete) return;
    if (_denseStrokes.isEmpty || _currentStrokeIndex >= _denseStrokes.length) return;

    final dragPos = details.localPosition;
    final threshold = traceW * 0.14; // scales with box size across devices
    final currentStroke = _denseStrokes[_currentStrokeIndex];

    setState(() {
      _canePosition = dragPos;
      if (_currentPointIndex < currentStroke.length) {
        final dist = (dragPos - currentStroke[_currentPointIndex]).distance;
        if (dist < threshold) {
          while (_currentPointIndex < currentStroke.length &&
              (dragPos - currentStroke[_currentPointIndex]).distance < threshold) {
            _currentPointIndex++;
          }
          if (_currentPointIndex >= currentStroke.length) {
            _currentStrokeIndex++;
            _currentPointIndex = 0;
            if (_currentStrokeIndex >= _denseStrokes.length) {
              _accept();
            }
          }
        }
      }
    });
  }

  Future<void> _accept() async {
    if (_tracingComplete) return;
    setState(() {
      _tracingComplete = true;
      _canePosition = null;
    });
    try {
      await widget.player.play(
        AssetSource(widget.successAudio.replaceFirst('assets/', '')),
      );
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) widget.onComplete();
  }

  // ── UI bits ────────────────────────────────────────────────────────────
  Widget _buildProgressBar(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
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
                        : [ArcticColorTheme.pictonblue, ArcticColorTheme.slateblue],
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

  Widget _buildBanner(double h) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: ArcticColorTheme.pictonblue.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        'Trace the number ${widget.number}!',
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontSize: (h * 0.09).clamp(14.0, 22.0),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────
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

    // Faint full-path guide underneath, so the child can see the whole
    // shape before/while tracing it.
    canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.2));
    final bgPaint = Paint()
      ..color = Colors.grey.shade300
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

    // Filled-in progress + next-target indicator.
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
          canvas.drawCircle(stroke[currentPointIndex], size.width * 0.09, guidePaint);
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
