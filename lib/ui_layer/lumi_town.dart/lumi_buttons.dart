import 'package:flutter/material.dart';
import 'lumi_theme.dart';

class LumiBackButton extends StatelessWidget {
  const LumiBackButton({super.key});

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
          color: LumiColorTheme.seaglass,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: LumiColorTheme.darkolive, width: 5),
        ),
        child: const Text(
          'back',
          style: TextStyle(
            fontFamily: LumiAppTextStyles.fredoka,
            fontSize: 18,
            color: LumiColorTheme.darkolive,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class LumiXButton extends StatelessWidget {
  final VoidCallback? onTap;

  const LumiXButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Image.asset('assets/images/lumi/bttn_x.png', width: 50)
    );
  }
}