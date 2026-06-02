import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../audio_helper.dart';
import '../widgets/bubble_overlay.dart';
import '../widgets/swipe_progress_bar.dart';
import 'step3_choice.dart';

enum _WashPhase { dragging, washing, drying, done }

class Step2WashingScreen extends StatefulWidget {
  const Step2WashingScreen({super.key});

  @override
  State<Step2WashingScreen> createState() => _Step2WashingScreenState();
}

class _Step2WashingScreenState extends State<Step2WashingScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  _WashPhase _phase = _WashPhase.dragging;
  BubbleState _bubbleState = BubbleState.none;

  late AnimationController _wobbleCtrl;
  late Animation<double> _wobbleAnim;

  // Towel bounce
  late AnimationController _towelBounceCtrl;

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

    _towelBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  void _onHalfway() {
    setState(() => _bubbleState = BubbleState.few);
  }

  Future<void> _onWashComplete() async {
    setState(() {
      _bubbleState = BubbleState.lot;
      _phase = _WashPhase.drying;
    });
    _wobbleCtrl.stop();
  }

  Future<void> _onTowelTap() async {
    if (_phase != _WashPhase.drying) return;
    setState(() {
      _phase = _WashPhase.done;
      _bubbleState = BubbleState.none;
    });
    await playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_wash_done.wav');
    await waitForAudio(_player);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fadeRoute(const Step3ChoiceScreen()),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _wobbleCtrl.dispose();
    _towelBounceCtrl.dispose();
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

          // Little Bear + drop target on face
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/characters/little_bear.png',
                    height: 300,
                    fit: BoxFit.contain,
                  ),

                  // Drop target on face area
                  if (_phase == _WashPhase.dragging)
                    Positioned(
                      top: 30,
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (_) => true,
                        onAcceptWithDetails: (_) {
                          setState(() => _phase = _WashPhase.washing);
                          _wobbleCtrl.stop();
                        },
                        builder: (context, candidateData, _) {
                          final isHovering = candidateData.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 80,
                            height: 70,
                            decoration: BoxDecoration(
                              color: isHovering
                                  ? Colors.lightBlue.withValues(alpha: 0.35)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isHovering
                                  ? Border.all(color: Colors.lightBlue, width: 2)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),

                  // Bubbles on face during washing / drying
                  if (_phase == _WashPhase.washing ||
                      _phase == _WashPhase.drying)
                    Positioned(
                      top: 20,
                      child: BubbleOverlay(state: _bubbleState),
                    ),
                ],
              ),
            ),
          ),

          // Bottom tray — water splash draggable
          if (_phase == _WashPhase.dragging)
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
                    data: 'water',
                    feedback: _ObjectIcon(
                        path: 'assets/images/objects/lumi/water_splash.png',
                        bgColor: const Color(0xFF5B9FD4),
                        opacity: 0.85),
                    childWhenDragging: _ObjectIcon(
                        path: 'assets/images/objects/lumi/water_splash.png',
                        bgColor: const Color(0xFF5B9FD4),
                        opacity: 0.3),
                    child: _ObjectIcon(
                        path: 'assets/images/objects/lumi/water_splash.png',
                        bgColor: const Color(0xFF5B9FD4),
                        opacity: 1.0),
                  ),
                ),
              ),
            ),

          // Swipe bar — appears after water dropped on face
          if (_phase == _WashPhase.washing)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: SwipeProgressBar(
                  onHalfway: _onHalfway,
                  onComplete: _onWashComplete,
                ),
              ),
            ),

          // Towel appears after washing — child taps to dry
          if (_phase == _WashPhase.drying)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _towelBounceCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                        0,
                        Tween<double>(begin: -4.0, end: 4.0)
                            .evaluate(_towelBounceCtrl)),
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: _onTowelTap,
                    child: _ObjectIcon(
                      path: 'assets/images/objects/lumi/towel.png',
                      bgColor: const Color(0xFFD4785B),
                      opacity: 1.0,
                    ),
                  ),
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

class _ObjectIcon extends StatelessWidget {
  final String path;
  final Color bgColor;
  final double opacity;

  const _ObjectIcon(
      {required this.path, required this.bgColor, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(path,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.help_outline, color: Colors.white, size: 36)),
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
