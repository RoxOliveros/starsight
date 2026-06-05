import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BearSpeechBubble extends StatelessWidget {
  final String text;
  final String? instruction;
  final bool visible;
  final bool showImageBubble;
  final String? bubbleImagePath;

  const BearSpeechBubble({
    super.key,
    required this.text,
    this.instruction,
    this.visible = true,
    this.showImageBubble = false,
    this.bubbleImagePath,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Animate(
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 300)),
        ScaleEffect(
          begin: Offset(0.8, 0.8),
          end: Offset(1.0, 1.0),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
        ),
      ],
      child: showImageBubble && bubbleImagePath != null
          ? _ImageSpeechBubble(imagePath: bubbleImagePath!)
          : _TextSpeechBubble(text: text, instruction: instruction),
    );
  }
}

class _TextSpeechBubble extends StatelessWidget {
  final String text;
  final String? instruction;

  const _TextSpeechBubble({required this.text, this.instruction});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.trim().isNotEmpty)
              Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5C3A1E),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            if (instruction != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0A0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFCB9B3E),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  instruction!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5E10),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageSpeechBubble extends StatelessWidget {
  final String imagePath;

  const _ImageSpeechBubble({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(),
      child: Container(
        width: 160,
        height: 140,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Image.asset(imagePath, fit: BoxFit.contain),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFF9EE)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF5C3A1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    const radius = 20.0;
    const tailHeight = 20.0;
    const tailWidth = 24.0;
    const tailX = 40.0;
    final h = size.height - tailHeight;

    path.moveTo(radius, 0);
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, h - radius);
    path.quadraticBezierTo(size.width, h, size.width - radius, h);
    path.lineTo(tailX + tailWidth, h);
    path.lineTo(tailX + tailWidth / 2, size.height);
    path.lineTo(tailX, h);
    path.lineTo(radius, h);
    path.quadraticBezierTo(0, h, 0, h - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}
