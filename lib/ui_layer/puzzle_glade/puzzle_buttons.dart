import 'package:flutter/material.dart';

import 'puzzle_theme.dart';

class PuzzleBackButton extends StatelessWidget {
  const PuzzleBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: PuzzleColorTheme.lightgrayishyellow,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: PuzzleColorTheme.sunnyhue, width: 5),
        ),
        child: const Text(
          'back',
          style: TextStyle(
            fontFamily: PuzzleAppTextStyles.fredoka,
            fontSize: 18,
            color: PuzzleColorTheme.sunnyhue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}