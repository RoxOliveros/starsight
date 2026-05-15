import 'package:flutter/material.dart';

import 'jar_theme.dart';

class JarBackButton extends StatelessWidget {
  const JarBackButton({super.key});

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
          color: JarColorTheme.lightgrayishyellow,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: JarColorTheme.sunnyhue, width: 5),
        ),
        child: const Text(
          'back',
          style: TextStyle(
            fontFamily: JarAppTextStyles.fredoka,
            fontSize: 18,
            color: JarColorTheme.sunnyhue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}