import 'package:flutter/cupertino.dart';
import '../../ui_layer/lumi_town/lumi_theme.dart';

class LumiLevelBadge extends StatelessWidget {
  final int level;

  const LumiLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: LumiColorTheme.peach,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: LumiColorTheme.rust, width: 5),
      ),
      child: Text(
        'Level $level',
        style: TextStyle(
          fontFamily: LumiAppTextStyles.fredoka,
          fontSize: 18,
          color: LumiColorTheme.rust,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}