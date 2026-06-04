import 'dart:math';
import 'package:flutter/material.dart';

enum StarState { none, few, lot }

class StarSparkleOverlay extends StatefulWidget {
  final StarState state;
  const StarSparkleOverlay({super.key, required this.state});

  @override
  State<StarSparkleOverlay> createState() => _StarSparkleOverlayState();
}

class _StarSparkleOverlayState extends State<StarSparkleOverlay>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scales;
  late List<Animation<double>> _opacities;

  final List<Offset> _positions = const [
    Offset(-60, 10), Offset(60, -10), Offset(0, -40),
    Offset(-80, -30), Offset(80, 20), Offset(30, 30),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (i) => AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600 + i * 120),
    )..repeat(reverse: true, period: Duration(milliseconds: 900 + i * 150)));

    _scales = _controllers.map((c) =>
        Tween<double>(begin: 0.6, end: 1.3).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();

    _opacities = _controllers.map((c) =>
        Tween<double>(begin: 0.3, end: 1.0).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  int get _count {
    switch (widget.state) {
      case StarState.none: return 0;
      case StarState.few: return 3;
      case StarState.lot: return 6;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state == StarState.none) return const SizedBox.shrink();
    return SizedBox(
      width: 200,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(_count, (i) {
          return Positioned(
            left: 100 + _positions[i].dx,
            top: 50 + _positions[i].dy,
            child: AnimatedBuilder(
              animation: _controllers[i],
              builder: (_, __) => Opacity(
                opacity: _opacities[i].value,
                child: Transform.scale(
                  scale: _scales[i].value,
                  child: _StarIcon(size: i % 2 == 0 ? 22.0 : 16.0),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StarIcon extends StatelessWidget {
  final double size;
  const _StarIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparkleStarPainter(),
    );
  }
}

class _SparkleStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFE566)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // 4-point sparkle star
    final path = Path();
    final r = size.width / 2;
    final inner = r * 0.35;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * 3.14159 / 180;
      final dist = i % 2 == 0 ? r : inner;
      final x = cx + dist * cos(angle - 3.14159 / 2);
      final y = cy + dist * sin(angle - 3.14159 / 2);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();

    // Glow
    canvas.drawCircle(Offset(cx, cy), r * 0.5,
        Paint()..color = const Color(0x55FFE566)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(path, paint);

    // White center shine
    canvas.drawCircle(Offset(cx - r * 0.15, cy - r * 0.15), r * 0.18,
        Paint()..color = Colors.white.withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(_) => false;
}