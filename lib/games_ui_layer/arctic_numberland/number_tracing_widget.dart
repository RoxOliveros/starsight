import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';

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
    required this.successAudio,
  });

  @override
  State<NumberTracingWidget> createState() => _NumberTracingWidgetState();
}

class _NumberTracingWidgetState extends State<NumberTracingWidget> {
  final List<Offset> _tracedPoints = [];
  bool _tracingComplete = false;
  Offset? _canePosition;
  bool _pendingRebuild = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return _buildTracingLayer(w, h);
      },
    );
  }

  Widget _buildTracingLayer(double w, double h) {
    final caneSize = h * 0.14;
    final numberSize = h * 0.85;
    final traceW = numberSize * 0.5;
    final traceH = numberSize;
    final traceLeft = w / 2 - traceW / 2;
    final traceTop = h / 2 - traceH / 2 + 15;

    return Stack(
      children: [
        // Progress bar
        if (_tracedPoints.where((p) => p != const Offset(-1, -1)).length > 5)
          Positioned(
            bottom: h * 0.06,
            left: w * 0.15,
            right: w * 0.15,
            child: _buildProgressBar(),
          ),

        // Instruction banner
        Positioned(
          top: 0, left: 0, right: 0,
          child: Center(child: _buildBanner(h)),
        ),

        // Tracing image
        Positioned(
          left: traceLeft, top: traceTop,
          width: traceW, height: traceH,
          child: Image.asset(
            'assets/fonts/game_numbers/${widget.number}_tracing.png',
            fit: BoxFit.contain,
          ),
        ),

        // Gesture + paint layer
        Positioned(
          left: traceLeft, top: traceTop,
          width: traceW, height: traceH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              _tracedPoints.add(details.localPosition);
              _canePosition = Offset(
                traceLeft + details.localPosition.dx,
                traceTop + details.localPosition.dy,
              );
              if (!_tracingComplete) _checkComplete(traceW, traceH);
              if (!_pendingRebuild) {
                _pendingRebuild = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _pendingRebuild = false);
                });
              }
            },
            onPanEnd: (_) {
              setState(() {
                _tracedPoints.add(const Offset(-1, -1));
                _canePosition = null;
              });
            },
            child: CustomPaint(
              size: Size(traceW, traceH),
              painter: _TracePainter(
                tracedPoints: _tracedPoints,
                isComplete: _tracingComplete,
              ),
            ),
          ),
        ),

        // Cane following finger
        if (_canePosition != null)
          Positioned(
            left: _canePosition!.dx - caneSize * 0.15,
            top: _canePosition!.dy - caneSize * 0.92,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/objects/arctic/candy_cane.png',
                width: caneSize,
                fit: BoxFit.contain,
              ),
            ),
          ),

        // Cane resting
        if (_canePosition == null && !_tracingComplete)
          Positioned(
            bottom: h * 0.08, left: w * 0.06,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/objects/arctic/candy_cane.png',
                width: caneSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final validCount = _tracedPoints
        .where((p) => p != const Offset(-1, -1))
        .length;
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
              widthFactor: (validCount / 20).clamp(0.0, 1.0),
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
              top: 2, left: 6, right: 6,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✏️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            'Trace the number ${widget.number}!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: (h * 0.09).clamp(14.0, 22.0),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  void _checkComplete(double traceW, double traceH) {
    final valid = _tracedPoints
        .where((p) => p != const Offset(-1, -1))
        .toList();

    if (valid.length < 12) return;

    // Skip top/bottom start-end checks for closed-loop numbers
    final isClosedLoop = widget.number == 0 || widget.number == 8;

    if (!isClosedLoop) {
      final ys = valid.map((p) => p.dy).toList();
      final minY = ys.reduce(min);
      final maxY = ys.reduce(max);

      final minSpan = (widget.number == 4 || widget.number == 5) ? 0.40 : 0.55;
      if ((maxY - minY) / traceH < minSpan) return;

      final firstY = valid.take(5).map((p) => p.dy).reduce((a, b) => a + b) / 5;
      if (firstY > traceH * 0.75) return;

      if (widget.number != 4 && widget.number != 5) {
        final lastY = valid.skip(valid.length - 5).map((p) => p.dy).reduce((a, b) => a + b) / 5;
        if (lastY < traceH * 0.60) return;
      }
    }

    if (!_numberSpecificCheck(valid, traceW, traceH)) return;

    _accept();
  }

  bool _numberSpecificCheck(List<Offset> valid, double traceW, double traceH) {
    switch (widget.number) {
      case 0:
      // Require more points per quadrant for a confident oval
        final tl = valid.where((p) => p.dy < traceH * 0.5 && p.dx < traceW * 0.5).length;
        final tr = valid.where((p) => p.dy < traceH * 0.5 && p.dx >= traceW * 0.5).length;
        final bl = valid.where((p) => p.dy >= traceH * 0.5 && p.dx < traceW * 0.5).length;
        final br = valid.where((p) => p.dy >= traceH * 0.5 && p.dx >= traceW * 0.5).length;
        // Also require vertical coverage
        final ys = valid.map((p) => p.dy).toList();
        final xs2 = valid.map((p) => p.dx).toList();
        final ySpan = ys.reduce(max) - ys.reduce(min);
        final xSpan = xs2.reduce(max) - xs2.reduce(min);
        return tl >= 3 && tr >= 3 && bl >= 3 && br >= 3
            && ySpan > traceH * 0.55
            && xSpan > traceW * 0.40;

      case 1:
      // Was 0.40 — too strict due to the top serif/hook
        final xs = valid.map((p) => p.dx).toList();
        final xRange = xs.reduce(max) - xs.reduce(min);
        return xRange < traceW * 0.65; // loosened

      case 2:
      // Top curve: needs horizontal spread in upper half
        final topPts = valid.where((p) => p.dy < traceH * 0.50).toList();
        if (topPts.length < 3) return false;
        final topXs = topPts.map((p) => p.dx).toList();
        if ((topXs.reduce(max) - topXs.reduce(min)) < traceW * 0.30) return false;

        // Bottom sweep: must be wide
        final bottomPts = valid.where((p) => p.dy > traceH * 0.60).toList();
        if (bottomPts.length < 4) return false;
        final bxs = bottomPts.map((p) => p.dx).toList();
        if ((bxs.reduce(max) - bxs.reduce(min)) < traceW * 0.45) return false;

        // Stroke must end on the right side (the baseline goes left→right)
        final lastPt = valid.last;
        return lastPt.dx > traceW * 0.50;

      case 3:
      // Two bumps on the right side — x range biased right (most points > 30% x)
        final rightPts = valid.where((p) => p.dx > traceW * 0.30).length;
        if (rightPts / valid.length < 0.65) return false;
        // Must have a middle notch — points near vertical center left of midpoint
        final middlePts = valid.where((p) =>
        p.dy > traceH * 0.40 && p.dy < traceH * 0.60 && p.dx < traceW * 0.55).length;
        return middlePts >= 2;

      case 4:
        final rightStem = valid.where((p) => p.dx > traceW * 0.40).toList();
        if (rightStem.length < 4) return false;
        final stemYs = rightStem.map((p) => p.dy).toList();
        final stemRange = stemYs.reduce(max) - stemYs.reduce(min);
        if (stemRange < traceH * 0.30) return false;
        final crossPts = valid.where((p) => p.dy > traceH * 0.20 && p.dy < traceH * 0.80).toList();
        if (crossPts.length < 3) return false;
        final crossXs = crossPts.map((p) => p.dx).toList();
        return (crossXs.reduce(max) - crossXs.reduce(min)) >= traceW * 0.25;

      case 5:
      // Top horizontal bar
        final topPts = valid.where((p) => p.dy < traceH * 0.40).toList();
        if (topPts.length < 2) return false;
        final topXs = topPts.map((p) => p.dx).toList();
        if ((topXs.reduce(max) - topXs.reduce(min)) < traceW * 0.20) return false;

        // Bottom curve — right side coverage
        final bottomPts = valid.where((p) => p.dy > traceH * 0.40).toList();
        if (bottomPts.length < 3) return false;
        final bxs = bottomPts.map((p) => p.dx).toList();
        if (bxs.reduce(max) < traceW * 0.30) return false; // loosened from 0.45

        // Left side of bottom curve must exist (the round belly of 5)
        final bottomLeft = bottomPts.where((p) => p.dx < traceW * 0.50).length;
        if (bottomLeft < 2) return false;

        // Overall vertical span
        final ys = valid.map((p) => p.dy).toList();
        return (ys.reduce(max) - ys.reduce(min)) > traceH * 0.35; // loosened from 0.45

      case 6:
      // Top curves left, then closes into a loop at bottom
      // Bottom half must have points in all quadrants (the closed loop)
        final bl = valid.where((p) => p.dy > traceH * 0.50 && p.dx < traceW * 0.50).length;
        final br = valid.where((p) => p.dy > traceH * 0.50 && p.dx >= traceW * 0.50).length;
        if (bl < 3 || br < 3) return false;
        // Top must curve — has points left of center in upper half
        final topLeft = valid.where((p) => p.dy < traceH * 0.50 && p.dx < traceW * 0.55).length;
        return topLeft >= 3;

      case 7:
      // Top horizontal sweep, then diagonal down-left
        final topPts = valid.where((p) => p.dy < traceH * 0.25).toList();
        if (topPts.length < 3) return false;
        final topXs = topPts.map((p) => p.dx).toList();
        if ((topXs.reduce(max) - topXs.reduce(min)) < traceW * 0.50) return false;
        // End point should be lower-left area
        final lastPt = valid.last;
        return lastPt.dy > traceH * 0.70 && lastPt.dx < traceW * 0.60;

      case 8:
      // Points in all 4 quadrants (two loops)
        final tl = valid.where((p) => p.dy < traceH * 0.5 && p.dx < traceW * 0.5).length;
        final tr = valid.where((p) => p.dy < traceH * 0.5 && p.dx >= traceW * 0.5).length;
        final bl = valid.where((p) => p.dy >= traceH * 0.5 && p.dx < traceW * 0.5).length;
        final br = valid.where((p) => p.dy >= traceH * 0.5 && p.dx >= traceW * 0.5).length;
        return tl >= 3 && tr >= 3 && bl >= 3 && br >= 3;

      case 9:
      // Top loop — all 4 quadrants in upper half
        final tl = valid.where((p) => p.dy < traceH * 0.55 && p.dx < traceW * 0.5).length;
        final tr = valid.where((p) => p.dy < traceH * 0.55 && p.dx >= traceW * 0.5).length;
        if (tl < 3 || tr < 3) return false;
        // Tail goes down on right side
        final tail = valid.where((p) => p.dy > traceH * 0.50 && p.dx > traceW * 0.40).length;
        return tail >= 5;

      default:
        return true;
    }
  }

  Future<void> _accept() async {
    if (_tracingComplete) return;
    setState(() => _tracingComplete = true);
    try {
      await widget.player.play(
        AssetSource(widget.successAudio.replaceFirst('assets/', '')),
      );
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) widget.onComplete();
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────
class _TracePainter extends CustomPainter {
  final List<Offset> tracedPoints;
  final bool isComplete;

  _TracePainter({required this.tracedPoints, required this.isComplete});

  @override
  void paint(Canvas canvas, Size size) {
    if (tracedPoints.length < 2) return;
    final paint = Paint()
      ..color = isComplete ? Colors.greenAccent : Colors.yellowAccent
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool newStroke = true;
    for (final p in tracedPoints) {
      if (p == const Offset(-1, -1)) {
        newStroke = true;
      } else if (newStroke) {
        path.moveTo(p.dx, p.dy);
        newStroke = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.tracedPoints != tracedPoints || old.isComplete != isComplete;
}