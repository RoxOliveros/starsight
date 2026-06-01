import 'package:StarSight/ui_layer/lumi_town/lumi_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../business_layer/orientation_service.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../../goodjob_prompt.dart';
import '../lvl2/audio_helper.dart';
import 'clean_bedroom_game_screen.dart';


class CleanBedroomEndingScreen extends StatefulWidget {
  const CleanBedroomEndingScreen({super.key});

  @override
  State<CleanBedroomEndingScreen> createState() => _CleanBedroomEndingScreenState();
}

class _CleanBedroomEndingScreenState extends State<CleanBedroomEndingScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  bool _showOverlay = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    OrientationService.setLandscape();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _playEndingThenShow();
  }

  Future<void> _playEndingThenShow() async {
    await playAssetAudio(_player, 'assets/audio/lumi_town/level3/vo_ending.wav');
    await waitForAudio(_player);
    if (mounted) setState(() => _showOverlay = true);
  }

  @override
  void dispose() {
    _player.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_bed.png',
              fit: BoxFit.cover,
            ),
            if (_showOverlay)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/dr.woo_the_owl.png',
                closeButtonColor: LumiColorTheme.robroy,
                onNext: _onNext,
                onRestart: _onRestart,
                onBack: _onBack,
              ),
          ],
        ),
      ),
    );
  }

  void _onNext() {
    // Navigator.of(context).pushAndRemoveUntil(
    //   MaterialPageRoute(builder: (_) => const ()),
    //   (route) => route.isFirst,
    // );
  }

  void _onRestart() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CleanBedroomGameScreen()),
    );
  }

  void _onBack() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
      (route) => route.isFirst,
    );
  }
}
