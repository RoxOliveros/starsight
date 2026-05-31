import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../audio_helper.dart';
import '../widgets/bubble_overlay.dart';
import '../widgets/swipe_progress_bar.dart';
import 'step2_choice.dart';

class Step1BrushingScreen extends StatefulWidget {
  const Step1BrushingScreen({super.key});

  @override
  State<Step1BrushingScreen> createState() => _Step1BrushingScreenState();
}

class _Step1BrushingScreenState extends State<Step1BrushingScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();

  bool _isDragging = false;
  bool _dropped = false; // toothbrush has been dragged to mouth
  BubbleState _bubbleState = BubbleState.none;

  // Wobble animation for the draggable toothbrush hint
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

  void _onHalfway() {
    setState(() => _bubbleState = BubbleState.few);
    playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_brush_mid.wav');
  }

  Future<void> _onBrushComplete() async {
    setState(() => _bubbleState = BubbleState.lot);
    _wobbleCtrl.stop();
    await playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_brush_done.wav');
    await waitForAudio(_player);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fadeRoute(const Step2ChoiceScreen()),
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
    //final size = MediaQuery.of(context).size;

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

          // Little Bear with DragTarget on mouth area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/characters/bear.png',
                    height: 300,
                    fit: BoxFit.contain,
                  ),

                  // Mouth drop target — positioned in the lower-center of bear
                  if (!_dropped)
                    Positioned(
                      bottom: 60,
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (details) => true,
                        onAcceptWithDetails: (details) {
                          setState(() => _dropped = true);
                          _wobbleCtrl.stop();
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHovering = candidateData.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 70,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isHovering
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isHovering
                                  ? Border.all(color: Colors.white54, width: 2)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),

                  // Bubbles appear around bear's mouth
                  if (_dropped)
                    Positioned(
                      bottom: 100,
                      child: BubbleOverlay(state: _bubbleState),
                    ),
                ],
              ),
            ),
          ),

          // Toothbrush draggable in bottom tray
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
                    data: 'toothbrush',
                    feedback: _ToothbrushIcon(size: 80, opacity: 0.85),
                    childWhenDragging: _ToothbrushIcon(size: 80, opacity: 0.3),
                    onDragStarted: () => setState(() => _isDragging = true),
                    onDraggableCanceled: (_, __) =>
                        setState(() => _isDragging = false),
                    child: _ToothbrushIcon(size: 80, opacity: 1.0),
                  ),
                ),
              ),
            ),

          // Swipe bar — only appears after toothbrush is dropped on mouth
          if (_dropped)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: SwipeProgressBar(
                  onHalfway: _onHalfway,
                  onComplete: _onBrushComplete,
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

class _ToothbrushIcon extends StatelessWidget {
  final double size;
  final double opacity;

  const _ToothbrushIcon({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE8B84B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          'assets/images/objects/lumi/toothbrush.png',
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
