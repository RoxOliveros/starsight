import 'package:flutter/material.dart';
import '../../ui_layer/puzzle_glade/puzzle_theme.dart';

class PuzzleLevelBadge extends StatelessWidget {
  final int level;

  const PuzzleLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: PuzzleColorTheme.lightgrayishyellow,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: PuzzleColorTheme.sunnyhue, width: 5),
      ),
      child: Text(
        'Level $level',
        style: const TextStyle(
          fontFamily: PuzzleAppTextStyles.fredoka,
          fontSize: 18,
          color: PuzzleColorTheme.sunnyhue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class PuzzleProgressDots extends StatelessWidget {
  final int currentRound;
  final int totalRounds;

  const PuzzleProgressDots({
    super.key,
    required this.currentRound,
    required this.totalRounds,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalRounds, (i) {
        final done = i + 1 < currentRound;
        final current = i + 1 == currentRound;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? PuzzleColorTheme.darkdesaturatedblue
                : current
                ? PuzzleColorTheme.sunnyhue
                : PuzzleColorTheme.darkdesaturatedblue
                .withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}