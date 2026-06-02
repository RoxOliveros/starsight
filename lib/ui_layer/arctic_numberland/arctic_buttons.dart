import 'package:flutter/material.dart';
import 'arctic_theme.dart';

class ArcticBackButton extends StatelessWidget {
  const ArcticBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: ArcticColorTheme.cotton,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: ArcticColorTheme.slateblue, width: 5),
        ),
        child: Text(
          'back',
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: 18,
            color: ArcticColorTheme.slateblue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class ArcticSkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const ArcticSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/buttons/skip.png',
        width: 72,
        fit: BoxFit.contain,
      ),
    );
  }
}