import 'package:flutter/material.dart';

/// A progress bar that fills as the child swipes over it.
/// [onComplete] fires when progress reaches 1.0.
class SwipeProgressBar extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onHalfway;

  const SwipeProgressBar({
    super.key,
    required this.onComplete,
    this.onHalfway,
  });

  @override
  State<SwipeProgressBar> createState() => _SwipeProgressBarState();
}

class _SwipeProgressBarState extends State<SwipeProgressBar> {
  double _progress = 0.0;
  bool _halfFired = false;
  bool _completeFired = false;

  // Each pixel of horizontal drag adds this much progress
  static const double _sensitivity = 0.003;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_completeFired) return;

    setState(() {
      _progress = (_progress + details.delta.dx.abs() * _sensitivity).clamp(0.0, 1.0);
    });

    if (!_halfFired && _progress >= 0.5) {
      _halfFired = true;
      widget.onHalfway?.call();
    }

    if (!_completeFired && _progress >= 1.0) {
      _completeFired = true;
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: _onPanUpdate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bar track
          Container(
            height: 22,
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white38, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 100),
                widthFactor: _progress,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF80DFFF), Color(0xFF00BFFF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Swipe hint icon row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              const Icon(Icons.swipe, color: Colors.white70, size: 20),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
            ],
          ),
        ],
      ),
    );
  }
}
