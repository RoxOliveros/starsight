import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'respect_1.dart';

class LumiClassroomScreen extends StatefulWidget {
  const LumiClassroomScreen({Key? key}) : super(key: key);

  @override
  State<LumiClassroomScreen> createState() => _LumiClassroomScreenState();
}

class _LumiClassroomScreenState extends State<LumiClassroomScreen>
    with TrWooReactionMixin {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    OrientationService.setLandscape();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playIntroAudio();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  AudioPlayer get trWooPlayer => _audioPlayer;

  Future<void> showDrWooReactionQuietly(TrWooState state) async {
    if (!mounted) return;
    setState(() => trWooState = state);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => trWooState = TrWooState.normal);
  }

  Future<void> _playIntroAudio() async {
    try {
      // 1. Play the intro audio first
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level7/respect_intro.wav'),
      );
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // 2. Play the tutorial audio
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level7/respect_tutorial.wav'),
      );

      // 3. Trigger Dr. Woo 6 seconds in
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          showDrWooReactionQuietly(TrWooState.correct);
        }
      });

      // 4. WAIT for the tutorial audio to finish entirely
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      // 5. Automatically jump to Respect 1!
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Respect1Screen()),
      );
    } catch (e) {
      debugPrint('Error playing audio sequence: $e');
    }
  }

  @override
  Widget buildTrWoo(BuildContext context) {
    final owlHeight = MediaQuery.of(context).size.height * 1.18;

    return Positioned(
      left: 0,
      right: 0,
      bottom: -(owlHeight * 0.15),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: owlHeight,
          child: switch (trWooState) {
            TrWooState.correct => Image.asset(
              'assets/animations/characters/dr.woo_thumbsup.webp',
              fit: BoxFit.contain,
            ),
            TrWooState.wrong => Image.asset(
              'assets/images/characters/tr.woo_tryagain.png',
              fit: BoxFit.contain,
            ),
            TrWooState.normal => Image.asset(
              'assets/images/characters/tr.woo_standing.png',
              fit: BoxFit.contain,
            ),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_lumi_classroom.png',
            fit: BoxFit.cover,
          ),
          buildTrWoo(context),
          Positioned(top: 25, left: 25, child: LumiXButton()),
        ],
      ),
    );
  }
}
