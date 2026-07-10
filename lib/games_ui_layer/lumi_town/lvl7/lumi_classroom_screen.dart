import 'package:StarSight/games_ui_layer/lumi_town/dr.woo_reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'respect_1.dart';

class LumiClassroomScreen extends StatefulWidget {
  const LumiClassroomScreen({Key? key}) : super(key: key);

  @override
  State<LumiClassroomScreen> createState() => _LumiClassroomScreenState();
}

class _LumiClassroomScreenState extends State<LumiClassroomScreen>
    with DrWooReactionMixin {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playIntroAudio();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  AudioPlayer get drWooPlayer => _audioPlayer;

  Future<void> showDrWooReactionQuietly(DrWooState state) async {
    if (!mounted) return;
    setState(() => drWooState = state);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => drWooState = DrWooState.normal);
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
          showDrWooReactionQuietly(DrWooState.correct);
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
  Widget buildDrWoo(BuildContext context) {
    final owlHeight = MediaQuery.of(context).size.height * 1.18;

    return Positioned(
      left: 0,
      right: 0,
      bottom: -(owlHeight * 0.15),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: owlHeight,
          child: switch (drWooState) {
            DrWooState.correct => Image.asset(
              'assets/animations/characters/dr.woo_thumbsup.webp',
              fit: BoxFit.contain,
            ),
            DrWooState.wrong => Image.asset(
              'assets/images/characters/dr.woo_tryagain.png',
              fit: BoxFit.contain,
            ),
            DrWooState.normal => Image.asset(
              'assets/images/characters/dr.woo_standing.png',
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
          buildDrWoo(context),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Image.asset(
                    'assets/images/buttons/x_blue.png',
                    width: 50,
                    height: 50,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
