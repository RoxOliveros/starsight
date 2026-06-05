import 'package:flutter/material.dart';
import 'lagoon_theme.dart'; // Make sure this path is correct for your project!

class LagoonBackButton extends StatelessWidget {
  const LagoonBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: LagoonColorTheme.pastelorange,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: LagoonColorTheme.wasteland, width: 5),
        ),
        child: const Text(
          'back',
          style: TextStyle(
            fontFamily: LagoonAppTextStyles.fredoka,
            fontSize: 18,
            color: LagoonColorTheme.wasteland,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class LagoonSkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const LagoonSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/buttons/skip_lagoon.png',
        width: 72,
        fit: BoxFit.contain,
      ),
    );
  }
}