import 'package:flutter/material.dart';

// USAGE
//
// StarRoundIndicator(
// totalRounds: _rounds.length,
// litCount: _currentRound,
// ),

class StarRoundIndicator extends StatefulWidget {
  final int totalRounds;
  final int litCount;

  const StarRoundIndicator({
    super.key,
    required this.totalRounds,
    required this.litCount,
  });

  static const String _litAsset = 'assets/images/objects/arctic/star.png';
  static const String _unlitAsset = 'assets/images/objects/arctic/star_bnw.png';
  static const double _size = 34;
  static const double _spacing = 4;
  static const Color _glowColor = Color(0xFFF9D552);

  @override
  State<StarRoundIndicator> createState() => _StarRoundIndicatorState();
}

class _StarRoundIndicatorState extends State<StarRoundIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.totalRounds, (i) {
        final isLit = i < widget.litCount;

        Widget star = Image.asset(
          isLit ? StarRoundIndicator._litAsset : StarRoundIndicator._unlitAsset,
          width: StarRoundIndicator._size,
          height: StarRoundIndicator._size,
        );

        if (isLit) {
          star = AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: StarRoundIndicator._glowColor
                        .withValues(alpha: 0.3 + 0.3 * _glowCtrl.value),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
            child: star,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: StarRoundIndicator._spacing),
          child: star,
        );
      }),
    );
  }
}