import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Progress indicator for whisking / cooking timers
class CookingProgressBar extends StatelessWidget {
  final double progress;
  final String label;
  final Color color;

  const CookingProgressBar({
    super.key,
    required this.progress,
    this.label = '',
    this.color = const Color(0xFFFF9800),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C3A1E),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          width: 200,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF5C3A1E), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Star burst celebration overlay
class CelebrationOverlay extends StatelessWidget {
  final bool visible;

  const CelebrationOverlay({super.key, this.visible = false});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    // Positions clustered around the pancake area (center-bottom)
    final positions = [
      (0.35, 0.68), // left of pancake
      (0.60, 0.68), // right of pancake
      (0.47, 0.60), // above pancake
      (0.50, 0.78), // below pancake
      (0.35, 0.80), // far left
      (0.60, 0.80), // far right
    ];

    return IgnorePointer(
      child: Stack(
        children: List.generate(positions.length, (i) {
          final (x, y) = positions[i];
          return Positioned(
            left: sw * x,
            top: sh * y,
            child: _ShineStar(
              size: 22 + (i % 3) * 5.0,
              delay: Duration(milliseconds: i * 150),
            ),
          );
        }),
      ),
    );
  }
}

class _ShineStar extends StatelessWidget {
  final double size;
  final Duration delay;

  const _ShineStar({required this.size, required this.delay});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ShineStarPainter(),
    )
        .animate(delay: delay, onPlay: (c) => c.repeat(reverse: true))
        .scale(
      begin: const Offset(0.6, 0.6),
      end: const Offset(1.3, 1.3),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    )
        .fadeIn(duration: const Duration(milliseconds: 300));
  }
}

class _ShineStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.width / 2;
    final inner = size.width / 5;

    final path = Path();
    for (int i = 0; i < 4; i++) {
      final outerAngle = (i * 90 - 90) * math.pi / 180;
      final innerAngle = (i * 90 - 45) * math.pi / 180;

      if (i == 0) {
        path.moveTo(cx + outer * math.cos(outerAngle), cy + outer * math.sin(outerAngle));
      } else {
        path.lineTo(cx + outer * math.cos(outerAngle), cy + outer * math.sin(outerAngle));
      }
      path.lineTo(cx + inner * math.cos(innerAngle), cy + inner * math.sin(innerAngle));
    }
    path.close();

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, paint);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tap hint animation (glowing circle pulse)
class TapHint extends StatelessWidget {
  final bool visible;

  const TapHint({super.key, this.visible = false});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFCC44), width: 3),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.4, 1.4),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
        )
        .fade(begin: 1, end: 0, duration: const Duration(milliseconds: 800));
  }
}

/// Animated water drop / pour particle
class PourParticles extends StatelessWidget {
  final bool visible;

  const PourParticles({super.key, this.visible = false});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Column(
      children: List.generate(3, (i) {
        return Container(
          width: 8,
          height: 12,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
        )
            .animate(delay: Duration(milliseconds: i * 100))
            .moveY(
              begin: -10,
              end: 30,
              duration: const Duration(milliseconds: 400),
            )
            .fade();
      }),
    );
  }
}

/// Settings toggle row (sfx / music / voice)
class SettingsRow extends StatelessWidget {
  final bool sfxOn;
  final bool musicOn;
  final bool voiceOn;
  final VoidCallback onToggleSfx;
  final VoidCallback onToggleMusic;
  final VoidCallback onToggleVoice;

  const SettingsRow({
    super.key,
    required this.sfxOn,
    required this.musicOn,
    required this.voiceOn,
    required this.onToggleSfx,
    required this.onToggleMusic,
    required this.onToggleVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF5C3A1E), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(icon: sfxOn ? '🔊' : '🔇', label: 'SFX', onTap: onToggleSfx),
          const SizedBox(width: 8),
          _ToggleBtn(icon: musicOn ? '🎵' : '🔕', label: 'Music', onTap: onToggleMusic),
          const SizedBox(width: 8),
          _ToggleBtn(icon: voiceOn ? '🐻' : '😶', label: 'Voice', onTap: onToggleVoice),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF5C3A1E)),
          ),
        ],
      ),
    );
  }
}
