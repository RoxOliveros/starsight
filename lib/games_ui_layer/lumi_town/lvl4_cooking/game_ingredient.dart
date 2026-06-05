import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GameIngredient extends StatefulWidget {
  final String imagePath;
  final String id;
  final bool isActive;
  final bool isVisible;
  final VoidCallback? onTap;
  final bool animatePour; // triggers pour animation
  final bool bounce;

  const GameIngredient({
    super.key,
    required this.imagePath,
    required this.id,
    this.isActive = false,
    this.isVisible = true,
    this.onTap,
    this.animatePour = false,
    this.bounce = false,
  });

  @override
  State<GameIngredient> createState() => _GameIngredientState();
}

class _GameIngredientState extends State<GameIngredient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnim = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    if (widget.bounce) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GameIngredient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bounce && !oldWidget.bounce) {
      _controller.repeat(reverse: true);
    } else if (!widget.bounce && oldWidget.bounce) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    Widget child = GestureDetector(
      onTap: widget.isActive ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, widget.bounce ? _bounceAnim.value : 0),
            child: child,
          );
        },
        child: widget.animatePour
            ? _PourAnimation(imagePath: widget.imagePath)
            : _StaticIngredient(
                imagePath: widget.imagePath,
                isActive: widget.isActive,
              ),
      ),
    );

    return child;
  }
}

class _StaticIngredient extends StatelessWidget {
  final String imagePath;
  final bool isActive;

  const _StaticIngredient({required this.imagePath, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: isActive
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFCC44).withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            )
          : null,
      child: Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, st) => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber),
          ),
          child: const Icon(Icons.image_not_supported, color: Colors.amber),
        ),
      ),
    );
  }
}

class _PourAnimation extends StatelessWidget {
  final String imagePath;
  const _PourAnimation({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Image.asset(imagePath, fit: BoxFit.contain)
        .animate(onPlay: (c) => c.forward())
        .rotate(
          begin: 0,
          end: -0.5,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        )
        .moveY(begin: 0, end: -20, duration: const Duration(milliseconds: 400));
  }
}

// ─── Whisk drag widget ─────────────────────────────────────────────────────
class WhiskWidget extends StatefulWidget {
  final double progress;
  final ValueChanged<double> onProgress;
  final VoidCallback onComplete;

  const WhiskWidget({
    super.key,
    required this.progress,
    required this.onProgress,
    required this.onComplete,
  });

  @override
  State<WhiskWidget> createState() => _WhiskWidgetState();
}

class _WhiskWidgetState extends State<WhiskWidget> {
  Offset _position = const Offset(0, 0);
  double _rotation = 0;
  bool _isDragging = false;
  Offset? _lastPos;
  double _totalDistance = 0;
  static const double _requiredDistance = 600;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
          _lastPos = details.localPosition;
        });
      },
      onPanUpdate: (details) {
        if (_lastPos != null) {
          final delta = details.localPosition - _lastPos!;
          _totalDistance += delta.distance;
          _rotation += delta.dx * 0.05;

          setState(() {
            _position += delta;
            _lastPos = details.localPosition;
          });

          widget.onProgress((_totalDistance / _requiredDistance).clamp(0, 1));
          if (_totalDistance >= _requiredDistance) {
            widget.onComplete();
          }
        }
      },
      onPanEnd: (_) {
        setState(() {
          _isDragging = false;
          _lastPos = null;
          // Spring back
          _position = Offset.zero;
        });
      },
      child: Transform.translate(
        offset: _position,
        child: Transform.rotate(
          angle: _rotation,
          child: Image.asset(
            'assets/images/objects/lumi/whisk.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) => const Icon(
              Icons.cable,
              size: 60,
              color: Color(0xFF8B5E10),
            ),
          ),
        ),
      ),
    );
  }
}
