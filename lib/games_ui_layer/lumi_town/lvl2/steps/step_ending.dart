import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl3/clean_bedroom_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../../../goodjob_prompt.dart';
import '../audio_helper.dart';
import '../bathroom_game_screen.dart';

class StepEndingScreen extends StatefulWidget {
  const StepEndingScreen({super.key});

  @override
  State<StepEndingScreen> createState() => _StepEndingScreenState();
}

class _StepEndingScreenState extends State<StepEndingScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _playEndingThenShow();
  }

  Future<void> _playEndingThenShow() async {
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level2/vo_ending.wav',
    );
    await waitForAudio(_player);
    if (mounted) setState(() => _showOverlay = true);
  }

  @override
  void dispose() {
    _player.dispose();
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

          // Little Bear still visible beneath overlay
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

          // Good Job overlay appears after ending audio
          if (_showOverlay)
            GoodJobOverlay(
              // Mr. Woo the owl appears in the Good Job screen
              characterImage: 'assets/images/characters/dr.woo_the_owl.png',
              closeButtonColor: const Color(0xFF4CAF50),
              onNext: _onNext,
              onRestart: _onRestart,
              onBack: _onBack,
            ),
        ],
      ),
    );
  }

  Future<void> _onNext() async {
    // 1. Unlock Level 3 in the database
    await TownProgressService.instance.markLevelComplete(2);

    if (mounted) {
      // 2. Navigate directly to Level 3!
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CleanBedroomGameScreen()),
      );
    }
  }

  void _onRestart() {
    // Restart from the very beginning of this game
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const Lvl2BathroomGameScreen()),
    );
  }

  Future<void> _onBack() async {
    await TownProgressService.instance.markLevelComplete(2);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
        (route) => route.isFirst,
      );
    }
  }
}
