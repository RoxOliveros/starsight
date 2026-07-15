import 'package:flutter/material.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';

class ForestInstructionBanner extends StatelessWidget {
  final String text;

  const ForestInstructionBanner({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: ForestColorTheme.darkseagreen.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: ForestColorTheme.darkseagreen.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: ForestAppTextStyles.fredoka,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
        ),
      ),
    );
  }
}

class ForestLevelBadge extends StatelessWidget {
  final int level;

  const ForestLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: ForestColorTheme.lightgrayishgreen,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: ForestColorTheme.darkseagreen, width: 5),
      ),
      child: Text(
        'Level $level',
        style: TextStyle(
          fontFamily: ForestAppTextStyles.fredoka,
          fontSize: 18,
          color: ForestColorTheme.darkseagreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}