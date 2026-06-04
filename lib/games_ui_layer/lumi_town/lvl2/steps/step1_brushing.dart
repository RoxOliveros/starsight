import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../audio_helper.dart';
import '../widgets/bubble_overlay.dart';
import '../widgets/sparkle_overlay.dart';
import 'step2_choice.dart';

class Step1BrushingScreen extends StatefulWidget {
  const Step1BrushingScreen({super.key});

  @override
  State<Step1BrushingScreen> createState() => _Step1BrushingScreenState();
}

class _Step1BrushingScreenState extends State<Step1BrushingScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();

  bool _dropped = false; // toothbrush has been dragged to mouth
  BubbleState _bubbleState = BubbleState.none;
  StarState _starState = StarState.none;

  // Wobble animation for the draggable toothbrush hint
  late AnimationController _wobbleCtrl;
  late Animation<double> _wobbleAnim;

  double _brushProgress = 0.0;
  bool _quarterFired = false;
  bool _halfFired = false;
  bool _completeFired = false;

  double _toothbrushX = 0.0;
  double _toothbrushY = 0.0;
  bool _isBrushing = false;

  bool _audioFired = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _dropped = true;

    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _wobbleAnim = Tween<double>(
      begin: -4.0,
      end: 4.0,
    ).animate(CurvedAnimation(parent: _wobbleCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _player.dispose();
    _wobbleCtrl.dispose();
    super.dispose();
  }

  void _onHalfway() {
    setState(() => _bubbleState = BubbleState.lot);
  }

  Future<void> _onBrushComplete() async {
    setState(() => _bubbleState = BubbleState.none);
    setState(() => _starState = StarState.lot); //TODO
    _wobbleCtrl.stop();
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level2/vo_brush_done.wav',
    );
    await waitForAudio(_player);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(_fadeRoute(const Step2ChoiceScreen()));
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

          // Little Bear with DragTarget on mouth area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenH = MediaQuery.of(context).size.height;
                  final bearH = screenH * 0.80;
                  final mouthBottom =
                      bearH * 0.28; // adjust this % to hit the mouth

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/characters/little_bear.png',
                        height: bearH,
                        fit: BoxFit.contain,
                      ),

                      // Bubbles and Stars
                      if (_dropped)
                        Positioned(
                          bottom: mouthBottom + 90,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              BubbleOverlay(state: _bubbleState, size: 40),
                              StarSparkleOverlay(state: _starState),
                            ],
                          ),
                        ),

                      // Swipe touch area on mouth
                      if (_dropped)
                        Positioned(
                          bottom: mouthBottom + 70,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) {
                              setState(() {
                                _isBrushing = true;
                                _toothbrushX = details.globalPosition.dx;
                                _toothbrushY = details.globalPosition.dy;
                              });
                            },
                            onPanUpdate: (details) {
                              if (_completeFired) return;
                              setState(() {
                                _toothbrushX = details.globalPosition.dx;
                                _toothbrushY = details.globalPosition.dy;
                                _brushProgress = (_brushProgress + details.delta.dx.abs() * 0.0010).clamp(0.0, 1.0);

                              });
                              if (!_audioFired && _brushProgress >= 0.15) {
                                _audioFired = true;
                                playAssetAudio(_player, 'assets/audio/lumi_town/level2/vo_brush_mid.wav');
                              }
                              if (!_quarterFired && _brushProgress >= 0.5) {
                                _quarterFired = true;
                                setState(() => _bubbleState = BubbleState.few);
                              }
                              if (!_halfFired && _brushProgress >= 0.75) {
                                _halfFired = true;
                                _onHalfway();
                              }
                              if (!_completeFired && _brushProgress >= 1.0) {
                                _completeFired = true;
                                _onBrushComplete();
                              }
                            },
                            onPanEnd: (_) =>
                                setState(() => _isBrushing = false),
                            child: Container(
                              width: 160,
                              height: 80,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: _ToothbrushIcon(size: 80, opacity: 0.85),
                    childWhenDragging: _ToothbrushIcon(size: 80, opacity: 0.3),
                    child: _ToothbrushIcon(size: 80, opacity: 1.0),
                  ),
                ),
              ),
            ),

          // Toothbrush follows finger
          if (_isBrushing)
            Positioned(
              left: _toothbrushX - 30,
              top: _toothbrushY - 30,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/objects/lumi/toothbrush.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // Progress bar
          if (_dropped)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 22,
                  width: MediaQuery.of(context).size.width * 0.65,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white38, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 100),
                      widthFactor: _brushProgress,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF80DFFF), Color(0xFF00BFFF)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // X button
          Positioned(top: 16, left: 16, child: LumiXButton(onTap: _onBack)),
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
      child: Image.asset(
        'assets/images/objects/lumi/toothbrush.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
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
