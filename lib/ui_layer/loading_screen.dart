import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final String imagePath;
  final Color dotColor;
  final Color overlayColor;
  final Color cardColor;
  final double imageWidth;

  const LoadingScreen({
    super.key,
    required this.imagePath,
    required this.dotColor,
    this.overlayColor = const Color(0x99000000), // translucent black
    this.cardColor = Colors.white,
    this.imageWidth = 130,
  });

  // ── 1. Alphabet Forest ─────────────────────────────────────────────────
  factory LoadingScreen.alphabetForest() {
    return const LoadingScreen(
      imagePath: 'assets/images/characters/doby_standing_armsonhips.png',
      dotColor: Color(0xFF4C89C3), // blue
    );
  }

  // ── 2. Lumi Town ────────────────────────────────────────────────────────
  factory LoadingScreen.lumiTown() {
    return const LoadingScreen(
      imagePath: 'assets/images/characters/dr.woo_the_owl.png',
      dotColor: Color(0xFFEC8A20), // orange
    );
  }

  // ── 3. Arctic Numberland ────────────────────────────────────────────────
  factory LoadingScreen.arctic() {
    return const LoadingScreen(
      imagePath: 'assets/images/characters/doma_writing_on_board.png',
      dotColor: Color(0xFF6FD3E3), // light blue
    );
  }

  // ── 4. Discovery Lagoon ─────────────────────────────────────────────────
  factory LoadingScreen.discoveryLagoon() {
    return const LoadingScreen(
      imagePath: 'assets/images/characters/cat_holding_fishbone.png',
      dotColor: Color(0xFF5F7199), // deep navy blue
    );
  }

  // ── 5. Puzzle Glade ─────────────────────────────────────────────────────
  factory LoadingScreen.puzzleGlade() {
    return const LoadingScreen(
      imagePath: 'assets/images/characters/bunny_holding_star.png',
      dotColor: Color(0xFFF9D552), // yellow
    );
  }

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.overlayColor,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              widget.imagePath,
              width: widget.imageWidth,
              errorBuilder: (_, __, ___) => SizedBox(
                width: widget.imageWidth,
                height: widget.imageWidth,
              ),
            ),
            const SizedBox(height: 18),
            _DancingDots(color: widget.dotColor),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DANCING DOTS
// ══════════════════════════════════════════════════════════════════════════════
class _DancingDots extends StatefulWidget {
  final Color color;
  final int dotCount;
  final double dotSize;

  const _DancingDots({
    required this.color,
    this.dotCount = 3,
    this.dotSize = 12,
  });

  @override
  State<_DancingDots> createState() => _DancingDotsState();
}

class _DancingDotsState extends State<_DancingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.dotCount, (index) {
            // stagger each dot's bounce by a fraction of the cycle
            final delay = index / widget.dotCount;
            final t = (_controller.value - delay) % 1.0;
            // bounce curve: 0 -> up -> 0
            final bounce = (t < 0.5)
                ? Curves.easeOut.transform(t * 2)
                : Curves.easeIn.transform(1 - (t - 0.5) * 2);
            final offsetY = -10 * bounce;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, offsetY),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}