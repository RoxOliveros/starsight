import 'package:flutter/material.dart';
import '../../business_layer/audio_helper.dart';
import '../../games_ui_layer/games_audio_helper.dart';
import 'lagoon_theme.dart';

class LagoonBackButton extends StatelessWidget {
  const LagoonBackButton({super.key});

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

/// Remembers the Lagoon level-select route so any game (or anything stacked on
/// top of a game: intro, camera/calibration, dialogs...) can jump straight back
/// to it. LagoonLevelScreen sets [levelRoute] while it is on the stack.
class LagoonNav {
  LagoonNav._();
  static Route<dynamic>? levelRoute;

  /// Closes everything above the Lagoon level screen.
  static void backToLevels(BuildContext context) {
    final route = levelRoute;
    if (route != null && route.isActive) {
      Navigator.of(context).popUntil((r) => identical(r, route));
    } else {
      Navigator.pop(context); // fallback: just close this screen
    }
  }
}

class LagoonXButton extends StatelessWidget {
  const LagoonXButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        GamesSfxPlayer.instance.play(GameSfx.bubbleClick);
        LagoonNav.backToLevels(context);
      },
      child: Image.asset('assets/images/buttons/x_brown.png', width: 50),
    );
  }
}

class LagoonSkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const LagoonSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        GamesSfxPlayer.instance.play(GameSfx.bubblePop);
        onTap();
      },
      child: Image.asset(
        'assets/images/buttons/skip_lagoon.png',
        width: 90,
        fit: BoxFit.contain,
      ),
    );
  }
}
