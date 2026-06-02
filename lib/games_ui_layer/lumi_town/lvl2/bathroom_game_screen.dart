import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../ui_layer/lumi_town/town_level.dart';
import 'steps/step1_choice.dart';

class Lvl2BathroomGameScreen extends StatefulWidget {
  const Lvl2BathroomGameScreen({super.key});

  @override
  State<Lvl2BathroomGameScreen> createState() => _Lvl2BathroomGameScreenState();
}

class _Lvl2BathroomGameScreenState extends State<Lvl2BathroomGameScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    OrientationService.setLandscape();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _playIntroThenProceed();
  }

  Future<void> _playIntroThenProceed() async {
    try {
      await _playAudio('assets/audio/lumi_town/level2/vo_intro.wav');
      await _audioPlayer.onPlayerComplete.first;
    } catch (_) {}

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      _fadeRoute(const Step1ChoiceScreen()),
    );
  }

  Future<void> _playAudio(String assetPath) async {
    final dir = await getTemporaryDirectory();
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await _audioPlayer.play(DeviceFileSource(file.path));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
            // 1. Background
            Image.asset('assets/images/backgrounds/bg_lumi_bathroom.png', fit: BoxFit.cover),

            // 2. Bear — behind choices
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset('assets/images/characters/little_bear.png', height: 320, fit: BoxFit.contain),
              ),
            ),

            // 3. X button — always on top
            Positioned(
              top: 16,
              left: 16,
              child: LumiXButton(onTap: _onBack),
            ),
          ],
        )
      ),
    );
  }

  Widget _choiceIcon(String path, Color bg) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 3),
      ),
      padding: const EdgeInsets.all(12),
      child: Image.asset(path, fit: BoxFit.contain),
    );
  }

  void _onBack() {
    _audioPlayer.stop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
      (route) => route.isFirst,
    );
  }
}

// ── Shared fade page route helper (used across all steps) ─────────────────────
Route<void> _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 600),
  );
}
