import 'package:flutter/material.dart';
import 'forest_theme.dart';

class ForestBackButton extends StatelessWidget {
  const ForestBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: ForestColorTheme.lightgrayishgreen,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: ForestColorTheme.darkseagreen, width: 5),
        ),
        child: Text(
          'back',
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontSize: 18,
            color: ForestColorTheme.darkseagreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class ForestSkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const ForestSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/buttons/skip_forest.png',
        width: 72,
        fit: BoxFit.contain,
      ),
    );
  }
}
