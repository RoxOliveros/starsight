import 'package:flutter/cupertino.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';

class ArcticLevelBadge extends StatelessWidget {
  final int level;

  const ArcticLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: ArcticColorTheme.cotton,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: ArcticColorTheme.slateblue, width: 5),
      ),
      child: Text(
        'Level $level',
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontSize: 18,
          color: ArcticColorTheme.slateblue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}