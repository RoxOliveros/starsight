import 'package:flutter/material.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';

class ForestBackground extends StatelessWidget {
  final Widget child;

  const ForestBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        // Default solid color fallback
        color: ForestColorTheme.seagreen,

        image: DecorationImage(
          image: AssetImage('assets/images/backgrounds/bg_game_forest.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
