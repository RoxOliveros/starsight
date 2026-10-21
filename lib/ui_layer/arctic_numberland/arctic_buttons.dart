import 'package:flutter/material.dart';
import '../../business_layer/audio_helper.dart';
import '../../games_ui_layer/games_audio_helper.dart';
import 'arctic_theme.dart';

class ArcticBackButton extends StatelessWidget {
  const ArcticBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SfxHelper.instance.play(Sfx.keyTap);
        Navigator.pop(context);
      },
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

class ArcticXButton extends StatelessWidget {
  final VoidCallback? onTap;

  const ArcticXButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap ?? () {
          GamesSfxPlayer.instance.play(GameSfx.bubbleClick);
          Navigator.pop(context);
        },
        child: Image.asset('assets/images/buttons/x_blue.png', width: 50)
    );
  }
}