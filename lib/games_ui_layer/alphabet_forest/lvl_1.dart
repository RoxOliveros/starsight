import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_trace.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../business_layer/orientation_service.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFE8F4F8);
  static const Color deepNavyBlue = Color(0xFF5E463E);
  static const Color orange = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class lvl_1 extends StatefulWidget {
  const lvl_1({super.key});

  @override
  State<lvl_1> createState() => _lvl_1State();
}

class _lvl_1State extends State<lvl_1> with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _idleController;
  late Animation<double> _idleAnimation;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _idleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
  }

  void _playLetterSound() async {
    await _audioPlayer.setVolume(1.0);
    await _audioPlayer.play(AssetSource('audio/apple_intro.mp3'));
  }

  void _onLetterTapped() {
    if (!_isRevealed) {
      _playLetterSound();
      setState(() {
        _isRevealed = true;
      });
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- THE ANIMATED SECTION ---
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 500),
                crossFadeState: _isRevealed
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,

                // BEFORE TAP
                firstChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _idleAnimation,
                      child: GestureDetector(
                        onTap: _onLetterTapped,
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.all(10.0),
                          child: Image.asset(
                            'assets/fonts/game_letters/Big_A.png',
                            height: 200,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Tap the letter!',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ColorTheme.deepNavyBlue,
                      ),
                    ),
                  ],
                ),

                // AFTER TAP
                secondChild: ScaleTransition(
                  scale: _idleAnimation, // This makes bounce animation
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 170,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              bottom: 0,
                              child: Image.asset(
                                'assets/fonts/game_letters/Big_A.png',
                                height: 170,
                              ),
                            ),
                            Positioned(
                              left: 80,
                              bottom: 0,
                              child: Image.asset(
                                'assets/fonts/game_letters/Small_a.png',
                                height: 165,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 60),

                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/apple.png', height: 150),

                          Transform.translate(
                            offset: const Offset(0, -10),
                            child: const Text(
                              'Apple!',
                              style: TextStyle(
                                fontFamily: AppTextStyles.fredoka,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: ColorTheme.deepNavyBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // --- "Trace it!" BUTTON ---
              AnimatedOpacity(
                opacity: _isRevealed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                child: ElevatedButton(
                  onPressed: _isRevealed
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AlphabetTraceScreen(),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorTheme.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Trace it!',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
