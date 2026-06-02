import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../audio_helper.dart';
import '../widgets/swipe_progress_bar.dart';
import 'step_ending.dart';

class Step3CombingScreen extends StatefulWidget {
  const Step3CombingScreen({super.key});

  @override
  State<Step3CombingScreen> createState() => _Step3CombingScreenState();
}

class _Step3CombingScreenState extends State<Step3CombingScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  bool _dropped = false;

  late AnimationController _wobbleCtrl;
  late Animation<double> _wobbleAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _wobbleAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _wobbleCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _onCombComplete() async {
    _wobbleCtrl.stop();
    await playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_comb_done.wav');
    await waitForAudio(_player);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fadeRoute(const StepEndingScreen()),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _wobbleCtrl.dispose();
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

          // Little Bear + drop target on head
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Image.asset(
                    'assets/images/characters/little_bear.png',
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                  if (!_dropped)
                    DragTarget<String>(
                      onWillAcceptWithDetails: (_) => true,
                      onAcceptWithDetails: (_) {
                        setState(() => _dropped = true);
                        _wobbleCtrl.stop();
                      },
                      builder: (context, candidateData, _) {
                        final isHovering = candidateData.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 80,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isHovering
                                ? Colors.green.withOpacity(0.35)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isHovering
                                ? Border.all(color: Colors.greenAccent, width: 2)
                                : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Comb draggable in tray
          if (!_dropped)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _wobbleCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _wobbleAnim.value),
                    child: child,
                  ),
                  child: Draggable<String>(
                    data: 'comb',
                    feedback: _CombIcon(opacity: 0.85),
                    childWhenDragging: _CombIcon(opacity: 0.3),
                    child: _CombIcon(opacity: 1.0),
                  ),
                ),
              ),
            ),

          // Swipe bar after comb dropped
          if (_dropped)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: SwipeProgressBar(
                  onComplete: _onCombComplete,
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

class _CombIcon extends StatelessWidget {
  final double opacity;

  const _CombIcon({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF5BAD72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          'assets/images/objects/lumi/comb.png',
          fit: BoxFit.contain,
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
