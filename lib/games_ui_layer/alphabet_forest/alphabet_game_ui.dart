import 'package:flutter/material.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';

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