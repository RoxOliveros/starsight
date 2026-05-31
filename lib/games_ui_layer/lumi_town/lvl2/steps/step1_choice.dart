import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../audio_helper.dart';
import '../widgets/shake_widget.dart';
import 'step1_brushing.dart';

class Step1ChoiceScreen extends StatefulWidget {
  const Step1ChoiceScreen({super.key});

  @override
  State<Step1ChoiceScreen> createState() => _Step1ChoiceScreenState();
}

class _Step1ChoiceScreenState extends State<Step1ChoiceScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();

  // Shake keys for wrong icons
  final GlobalKey<ShakeWidgetState> _combKey = GlobalKey();
  final GlobalKey<ShakeWidgetState> _appleKey = GlobalKey();

  late AnimationController _iconEntranceCtrl;
  late Animation<double> _iconFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _iconEntranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconFade = CurvedAnimation(parent: _iconEntranceCtrl, curve: Curves.easeIn);

    _playQuestionAudio();
  }

  Future<void> _playQuestionAudio() async {
    await playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_step1_question.wav');
    await waitForAudio(_player);
    if (mounted) _iconEntranceCtrl.forward();
  }

  Future<void> _onCorrect() async {
    await playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_brush_start.wav');
    await waitForAudio(_player);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fadeRoute(const Step1BrushingScreen()),
    );
  }

  Future<void> _onWrong(GlobalKey<ShakeWidgetState> key) async {
    key.currentState?.shake();
    await playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_step1_wrong.wav');
  }

  @override
  void dispose() {
    _player.dispose();
    _iconEntranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/images/backgrounds/bg_lumi_bathroom.png',
            fit: BoxFit.cover,
          ),

          // Little Bear
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/characters/bear.png',
                height: 300,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Bottom icon tray — 3 choices
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _iconFade,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Toothbrush — CORRECT
                  _ChoiceIcon(
                    imagePath: 'assets/images/objects/lumi/toothbrush.png',
                    bgColor: const Color(0xFFE8B84B),
                    onTap: _onCorrect,
                  ),
                  const SizedBox(width: 24),

                  // Comb — WRONG
                  ShakeWidget(
                    key: _combKey,
                    child: _ChoiceIcon(
                      imagePath: 'assets/images/objects/lumi/comb.png',
                      bgColor: const Color(0xFF5BAD72),
                      onTap: () => _onWrong(_combKey),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Apple — WRONG
                  ShakeWidget(
                    key: _appleKey,
                    child: _ChoiceIcon(
                      imagePath: 'assets/images/objects/lumi/apple.png',
                      bgColor: const Color(0xFF5B9FD4),
                      onTap: () => _onWrong(_appleKey),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // X button
          Positioned(
            top: 16,
            left: 16,
            child: LumiXButton(onTap: _onBack),
          ),
        ],
      ),
    );
  }

  void _onBack() {
    _player.stop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
      (route) => route.isFirst,
    );
  }
}

// ── Reusable choice icon tile ─────────────────────────────────────────────────
class _ChoiceIcon extends StatelessWidget {
  final String imagePath;
  final Color bgColor;
  final VoidCallback onTap;

  const _ChoiceIcon({
    required this.imagePath,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.help_outline, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}

Route<void> _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 600),
  );
}
