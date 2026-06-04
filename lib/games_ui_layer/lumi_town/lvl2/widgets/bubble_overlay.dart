import 'package:flutter/material.dart';

enum BubbleState { none, few, lot }

class BubbleOverlay extends StatelessWidget {
  final BubbleState state;
  final double size;

  const BubbleOverlay({super.key, required this.state,  this.size = 200});

  @override
  Widget build(BuildContext context) {
    if (state == BubbleState.none) return const SizedBox.shrink();

    final imagePath = state == BubbleState.few
        ? 'assets/images/objects/lumi/bubbles_few.png'
        : 'assets/images/objects/lumi/bubbles_lot.png';

    return AnimatedOpacity(
      opacity: state == BubbleState.none ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          height: size,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
