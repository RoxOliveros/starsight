import 'package:flutter/material.dart';

//──────────────────────────────────────────────────────────────────────────────────────────────────
//──────────────────────────────────────────────────────────────────────────────────────────────────
//
// add in class
// GameLoadingMixin
//
// in init
// _startIntroFlow to finishLoading(_startIntroFlow);
//
// in build
// return Scaffold( body: buildWithLoading(
// loadingScreen: LoadingScreen.arctic(), gameBuilder: () =>
// Stack (...),
// ),
//
//──────────────────────────────────────────────────────────────────────────────────────────────────
//──────────────────────────────────────────────────────────────────────────────────────────────────


class LoadingScreen extends StatefulWidget {
  final String imagePath;
  final Color dotColor;
  final Color overlayColor;
  final Color cardColor;
  final double? cardHeight;

  const LoadingScreen({
    super.key,
    required this.imagePath,
    required this.dotColor,
    this.overlayColor = const Color(0x99000000),
    this.cardColor = Colors.white,
    this.cardHeight,
  });

  // ── 1. Alphabet Forest ─────────────────────────────────────────────────
  factory LoadingScreen.alphabetForest() {
    return const LoadingScreen(
      imagePath: 'assets/animations/characters/tofi_reading.webp',
      dotColor: Color(0xFF3B873B), // green
    );
  }

  // ── 2. Lumi Town ────────────────────────────────────────────────────────
  factory LoadingScreen.lumiTown() {
    return const LoadingScreen(
      imagePath: 'assets/animations/characters/drwoo_teaching.webp',
      dotColor: Color(0xFFECC06C), // orange
    );
  }

  // ── 3. Arctic Numberland ────────────────────────────────────────────────
  factory LoadingScreen.arctic() {
    return const LoadingScreen(
      imagePath: 'assets/animations/characters/doma_writing_on_board.webp',
      dotColor: Color(0xFF6288B0), // blue
    );
  }

  // ── 4. Discovery Lagoon ─────────────────────────────────────────────────
  factory LoadingScreen.discoveryLagoon() {
    return const LoadingScreen(
      imagePath: 'assets/animations/characters/kiki_fishing.webp',
      dotColor: Color(0xFF6B6A41), // dark green
    );
  }

  // ── 5. Puzzle Glade ─────────────────────────────────────────────────────
  factory LoadingScreen.puzzleGlade() {
    return const LoadingScreen(
      imagePath: 'assets/animations/characters/roxie_puzzle.webp',
      dotColor: Color(0xFFFDCE57), // yellow
    );
  }

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final effectiveHeight = widget.cardHeight ?? screenHeight * 0.8;

    return Container(
      color: widget.overlayColor,
      alignment: Alignment.center,
      child: Container(
        width: effectiveHeight,
        height: effectiveHeight, // remove this line if you don't want it square anymore
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset(
                widget.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
    this.dotCount = 4,
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
            final delay = index / widget.dotCount;
            final t = (_controller.value - delay) % 1.0;
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