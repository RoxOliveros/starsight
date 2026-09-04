import 'package:flutter/cupertino.dart';

import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';

class LagoonLevelBadge extends StatelessWidget {
  final int level;

  const LagoonLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: LagoonColorTheme.pastelorange,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: LagoonColorTheme.wasteland, width: 5),
      ),
      child: Text(
        'Level $level',
        style: TextStyle(
          fontFamily: LagoonAppTextStyles.fredoka,
          fontSize: 18,
          color: LagoonColorTheme.wasteland,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}