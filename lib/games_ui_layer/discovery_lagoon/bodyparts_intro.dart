import 'dart:async';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_background.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_theme.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/bodyparts_drag.dart';
import 'package:audioplayers/audioplayers.dart';

enum IntroPhase { entering, playingIntro, showingPart, done }

class BodyPartsIntroScreen extends StatefulWidget {
  final String bodyPart;
  final int level;

  const BodyPartsIntroScreen({
    super.key,
    required this.bodyPart,
    required this.level,
  });

  @override
  State<BodyPartsIntroScreen> createState() => _BodyPartsIntroScreenState();
}

class _BodyPartsIntroScreenState extends State<BodyPartsIntroScreen>
    with TickerProviderStateMixin {
  IntroPhase _introPhase = IntroPhase.entering;

  // --- AUDIO & SPEECH VARIABLES ---
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- ANIMATION CONTROLLERS ---
  late AnimationController _charSlideCtrl;
  late Animation<Offset> _charSlide;

  late AnimationController _partPopCtrl;
  late Animation<double> _partPop;

  late AnimationController _partDanceCtrl;
  late Animation<double> _partDance;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _initAnimations();
    _startIntroFlow();
  }

  void _initAnimations() {
    _charSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _charSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _charSlideCtrl, curve: Curves.elasticOut),
        );

    _partPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _partPop = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _partPopCtrl, curve: Curves.easeOut));

    _partDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _partDance = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(parent: _partDanceCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _charSlideCtrl.dispose();
    _partPopCtrl.dispose();
    _partDanceCtrl.dispose();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _startIntroFlow() async {
    await _charSlideCtrl.forward();
    if (!mounted) return;                       // <-- add
    setState(() => _introPhase = IntroPhase.playingIntro);

    // 1. Set up the Listener to wait for the audio to finish!
    Completer<void> audioFinished = Completer<void>();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!audioFinished.isCompleted) audioFinished.complete();
    });

    String audioFile =
        'audio/discovery_lagoon/intro_${widget.bodyPart.toLowerCase()}.wav';
    await _audioPlayer.play(AssetSource(audioFile));
    if (!mounted) return;                        // <-- add

    // 3. Pop the custom GIF onto the screen after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;                         // <-- add

    setState(() => _introPhase = IntroPhase.showingPart);
    _partPopCtrl.forward();
    _partDanceCtrl.repeat(reverse: true);

    // 4. FREEZE! Wait for the cat to finish talking
    await audioFinished.future;
    if (!mounted) return;                         // <-- add
    setState(() => _introPhase = IntroPhase.done);
  }

  Widget _buildAnimatedGif() {
    return LayoutBuilder(
      builder: (context, constraints) {
        (constraints.maxHeight * 0.55).clamp(100.0, 250.0);

        if (_introPhase == IntroPhase.entering ||
            _introPhase == IntroPhase.playingIntro) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_partPopCtrl, _partDanceCtrl]),
          builder: (_, child) => Transform.rotate(
            angle: _partDance.value,
            child: ScaleTransition(scale: _partPop, child: child),
          ),
          child: Image.asset(
            'assets/gifs/bodyparts/intro_${widget.bodyPart.toLowerCase()}.gif',
            width: 500,
            height: 500,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(
              widget.bodyPart,
              style: const TextStyle(
                fontSize: 80,
                color: LagoonColorTheme.wasteland,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: LagoonBackground(
        child: SafeArea(
          child: Stack(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: LagoonBackButton(),
                ),
              ),

              Positioned(
                left: 40,
                bottom: 0,
                child: SlideTransition(
                  position: _charSlide,
                  child: Image.asset(
                    'assets/images/characters/cat_holding_fishbone.png',
                    height: screenSize.height * 0.5,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: screenSize.height * 0.45,
                      child: _buildAnimatedGif(),
                    ),
                  ],
                ),
              ),

              if (_introPhase == IntroPhase.done)
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: GestureDetector(
                    onTap: () {
                      _audioPlayer.stop(); // Stop audio if they tap early
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BodyPartsDragScreen(
                            bodyPart: widget.bodyPart,
                            level: widget.level + 1,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: LagoonColorTheme.ferngreen,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: LagoonColorTheme.gunmetalgreen,
                          width: 4,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Let's Play!",
                            style: TextStyle(
                              fontFamily: LagoonAppTextStyles.fredoka,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
