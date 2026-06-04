import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../audio_helper.dart';
import '../widgets/shake_widget.dart';
import 'step3_combing.dart';

class Step3ChoiceScreen extends StatefulWidget {
  const Step3ChoiceScreen({super.key});

  @override
  State<Step3ChoiceScreen> createState() => _Step3ChoiceScreenState();
}

class _Step3ChoiceScreenState extends State<Step3ChoiceScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();

  final GlobalKey<ShakeWidgetState> _plantKey = GlobalKey();
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
    _iconFade =
        CurvedAnimation(parent: _iconEntranceCtrl, curve: Curves.easeIn);

    _playQuestionAudio();
  }

  Future<void> _playQuestionAudio() async {
    await playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_step3_question.wav');
    await waitForAudio(_player);
    if (mounted) _iconEntranceCtrl.forward();
  }

  Future<void> _onCorrect() async {
    await playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_comb_start.wav');
    await waitForAudio(_player);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fadeRoute(const Step3CombingScreen()),
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
          Image.asset('assets/images/backgrounds/bg_lumi_bathroom.png',
              fit: BoxFit.cover),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bearH = MediaQuery.of(context).size.height * 0.80;
                  return Image.asset(
                    'assets/images/characters/little_bear.png',
                    height: bearH,
                    fit: BoxFit.contain,
                  );
                },
              ),
            ),
          ),

          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _iconFade,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Comb — CORRECT
                  _ChoiceIcon(
                    imagePath: 'assets/images/objects/lumi/comb.png',
                    bgColor: const Color(0xFF5BAD72),
                    onTap: _onCorrect,
                  ),
                  const SizedBox(width: 24),

                  // Plant — WRONG
                  ShakeWidget(
                    key: _plantKey,
                    child: _ChoiceIcon(
                      imagePath: 'assets/images/objects/lumi/plant.png',
                      bgColor: const Color(0xFFB88FD4),
                      onTap: () => _onWrong(_plantKey),
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
