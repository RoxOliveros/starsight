import 'dart:async';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'kiki_reaction.dart';

class RainbowGameScreen extends StatefulWidget {
  const RainbowGameScreen({super.key});

  @override
  State<RainbowGameScreen> createState() => _RainbowGameScreenState();
}

class _RainbowGameScreenState extends State<RainbowGameScreen>
    with KikiReactionMixin {
  late final AudioPlayer _audioPlayer;

  // Track if intro/question narration is locking gameplay
  bool _isIntroPlaying = true;

  // Track our UI level: Level 1 -> Level 8
  int _currentLevel = 1;

  // Track when to show the Good Job celebration overlay!
  bool _showGoodJob = false;

  @override
  AudioPlayer get kikiPlayer => _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _startLevel1Intro();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ==========================================
  // AUDIO MANAGEMENT HELPERS
  // ==========================================

  Future<void> _playAudio(String assetPath) async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();

      sub = _audioPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      await _audioPlayer.play(
        AssetSource(assetPath.replaceFirst('assets/', '')),
      );

      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Audio playback error ($assetPath): $e');
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> _startLevel1Intro() async {
    setState(() => _isIntroPlaying = true);
    await _playAudio('assets/audio/discovery_lagoon/whereis_therainbow.wav');
    if (mounted) setState(() => _isIntroPlaying = false);
  }

  // ==========================================
  // LEVEL 1: RAINBOW TAP LOGIC
  // ==========================================
  void _onRainbowTapped() async {
    if (_isIntroPlaying || kikiState != KikiState.normal) return;

    await showKikiReaction(KikiState.correct);

    if (mounted) {
      setState(() {
        _currentLevel = 2;
        _isIntroPlaying = true;
      });

      await _playAudio('assets/audio/discovery_lagoon/what_color1.wav');

      if (mounted) setState(() => _isIntroPlaying = false);
    }
  }

  // ==========================================
  // LEVEL 2 THROUGH LEVEL 8: ITEM SELECTION LOGIC
  // ==========================================
  void _onItemTapped(bool isCorrect) async {
    if (_isIntroPlaying || kikiState != KikiState.normal) return;

    if (isCorrect) {
      setState(() => kikiState = KikiState.correct);

      await _playAudio('assets/audio/sound_effects/shine.wav');

      if (_currentLevel == 8) {
        await _playAudio('assets/audio/discovery_lagoon/what_part_rc.wav');
      } else {
        await _playAudio('assets/audio/discovery_lagoon/what_color_rc.wav');
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => kikiState = KikiState.normal);

      // LEVEL 2 -> LEVEL 3
      if (_currentLevel == 2 && mounted) {
        setState(() {
          _currentLevel = 3;
          _isIntroPlaying = true;
        });
        await _playAudio('assets/audio/discovery_lagoon/what_color2.wav');
        if (mounted) setState(() => _isIntroPlaying = false);
      }
      // LEVEL 3 -> LEVEL 4
      else if (_currentLevel == 3 && mounted) {
        setState(() {
          _currentLevel = 4;
          _isIntroPlaying = true;
        });
        await _playAudio('assets/audio/discovery_lagoon/what_color3.wav');
        if (mounted) setState(() => _isIntroPlaying = false);
      }
      // LEVEL 4 -> LEVEL 5
      else if (_currentLevel == 4 && mounted) {
        setState(() {
          _currentLevel = 5;
          _isIntroPlaying = true;
        });
        await _playAudio('assets/audio/discovery_lagoon/what_color4.wav');
        if (mounted) setState(() => _isIntroPlaying = false);
      }
      // LEVEL 5 -> LEVEL 6
      else if (_currentLevel == 5 && mounted) {
        setState(() {
          _currentLevel = 6;
          _isIntroPlaying = true;
        });
        await _playAudio('assets/audio/discovery_lagoon/what_color5.wav');
        if (mounted) setState(() => _isIntroPlaying = false);
      }
      // LEVEL 6 -> LEVEL 7
      else if (_currentLevel == 6 && mounted) {
        setState(() {
          _currentLevel = 7;
          _isIntroPlaying = true;
        });
        await _playAudio('assets/audio/discovery_lagoon/what_color6.wav');
        if (mounted) setState(() => _isIntroPlaying = false);
      }
      // LEVEL 7 -> LEVEL 8
      else if (_currentLevel == 7 && mounted) {
        setState(() {
          _currentLevel = 8;
          _isIntroPlaying = true;
        });
        await _playAudio('assets/audio/discovery_lagoon/what_part.wav');
        if (mounted) setState(() => _isIntroPlaying = false);
      }
      // LEVEL 8 COMPLETED -> SHOW GOOD JOB OVERLAY!
      else if (_currentLevel == 8 && mounted) {
        setState(() => _showGoodJob = true);
      }
    } else {
      showKikiReaction(KikiState.wrong);
    }
  }

  // Helper logic for when the player taps the Skip button
  void _onSkipTapped() {
    if (_currentLevel < 8) {
      setState(() {
        _currentLevel++;
        _isIntroPlaying = false; // Unlock gameplay instantly when skipped
      });
    } else {
      setState(() => _showGoodJob = true);
    }
  }

  // Helper to restart game from Level 1
  void _restartGame() {
    setState(() {
      _currentLevel = 1;
      _showGoodJob = false;
    });
    _startLevel1Intro();
  }

  // Overridden Kiki pose (Centered under lips in Level 8!)
  @override
  Widget buildKiki(BuildContext context) {
    final kikiWidget = SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: switch (kikiState) {
        KikiState.correct => Image.asset(
          'assets/animations/characters/kiki_cheering.webp',
          fit: BoxFit.contain,
        ),
        KikiState.wrong => Image.asset(
          'assets/images/characters/kiki_tryagain.png',
          fit: BoxFit.contain,
        ),
        KikiState.normal => Image.asset(
          'assets/images/characters/kiki_standing.png',
          fit: BoxFit.contain,
        ),
      },
    );

    if (_currentLevel == 8) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: -35,
        child: Align(alignment: Alignment.bottomCenter, child: kikiWidget),
      );
    }

    return Positioned(left: 16, bottom: -35, child: kikiWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            children: [
              // 1. Dynamic Background
              Positioned.fill(
                child: Image.asset(switch (_currentLevel) {
                  1 => 'assets/images/backgrounds/bg_rainbow_lagoon.png',
                  2 => 'assets/images/objects/lagoon/rainbow_bg_c1.png',
                  3 => 'assets/images/objects/lagoon/rainbow_bg_c2.png',
                  4 => 'assets/images/objects/lagoon/rainbow_bg_c3.png',
                  5 => 'assets/images/objects/lagoon/rainbow_bg_c4.png',
                  6 => 'assets/images/objects/lagoon/rainbow_bg_c5.png',
                  7 => 'assets/images/objects/lagoon/rainbow_bg_c6.png',
                  _ => 'assets/images/backgrounds/bg_rainbow_lagoon.png',
                }, fit: BoxFit.cover),
              ),

              // LEVEL 1 UI ELEMENTS
              if (_currentLevel == 1) ...[
                if (kikiState == KikiState.correct)
                  Positioned(
                    left: width * 0.35,
                    top: height * 0.08,
                    width: width * 0.30,
                    height: height * 0.35,
                    child: Image.asset(
                      'assets/images/objects/lagoon/sparkle.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                Positioned(
                  left: width * 0.22,
                  top: height * 0.05,
                  width: width * 0.56,
                  height: height * 0.45,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onRainbowTapped,
                  ),
                ),
              ],

              // LEVEL 2 THROUGH 7 UI ELEMENTS
              if (_currentLevel >= 2 && _currentLevel <= 7) ...[
                Positioned(
                  left: width * 0.38,
                  top: height * 0.52,
                  right: width * 0.08,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _buildLevelItems(width, _currentLevel),
                  ),
                ),
              ],

              // LEVEL 8 UI ELEMENTS (CENTERED IN SKY!)
              if (_currentLevel == 8) ...[
                Positioned(
                  left: width * 0.20,
                  top: height * 0.15,
                  right: width * 0.20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildItemCard(
                        width: width,
                        imageAsset: 'assets/images/objects/lagoon/eye.png',
                        isCorrect: true,
                      ),
                      _buildItemCard(
                        width: width,
                        imageAsset: 'assets/images/objects/lagoon/lips.png',
                        isCorrect: false,
                      ),
                      _buildItemCard(
                        width: width,
                        imageAsset: 'assets/images/objects/lagoon/nose.png',
                        isCorrect: false,
                      ),
                    ],
                  ),
                ),
              ],

              // Kiki Character Layer
              buildKiki(context),

              // ==========================================
              // LAGOON THEME BUTTONS (TOP LEFT & RIGHT)
              // ==========================================
              // Back Button (Top Left)
              Positioned(top: 16, left: 16, child: const LagoonBackButton()),

              // Skip Button (Top Right) - Only shows during active levels!
              if (!_showGoodJob)
                Positioned(
                  top: 16,
                  right: 16,
                  child: LagoonSkipButton(onTap: _onSkipTapped),
                ),

              // ==========================================
              // GOOD JOB OVERLAY (DISPLAYS WHEN LEVEL 8 FINISHES!)
              // ==========================================
              if (_showGoodJob)
                GoodJobOverlay(
                  characterImage: 'assets/images/characters/kiki_tryagain.png',
                  closeButtonColor: LagoonColorTheme.wasteland,
                  onNext: _restartGame,
                  onRestart: _restartGame,
                  onBack: () => Navigator.of(context).pop(),
                ),
            ],
          );
        },
      ),
    );
  }

  // Helper method to keep build() clean for Levels 2 through 7!
  List<Widget> _buildLevelItems(double width, int level) {
    switch (level) {
      case 2:
        return [
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/apple_colored.png',
            isCorrect: true,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/comb.png',
            isCorrect: false,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/toothbrush.png',
            isCorrect: false,
          ),
        ];
      case 3:
        return [
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/duck.png',
            isCorrect: false,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/comb.png',
            isCorrect: true,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/apple_colored.png',
            isCorrect: false,
          ),
        ];
      case 4:
        return [
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/comb.png',
            isCorrect: false,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/rug.png',
            isCorrect: false,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/duck.png',
            isCorrect: true,
          ),
        ];
      case 5:
        return [
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/leaves.png',
            isCorrect: true,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/chair.png',
            isCorrect: false,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/rug.png',
            isCorrect: false,
          ),
        ];
      case 6:
        return [
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/rug.png',
            isCorrect: true,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/car.png',
            isCorrect: false,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/lagoon/ball.png',
            isCorrect: false,
          ),
        ];
      case 7:
        return [
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/puzzle/pen.png',
            isCorrect: true,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/puzzle/compass.png',
            isCorrect: false,
          ),
          _buildItemCard(
            width: width,
            imageAsset: 'assets/images/objects/puzzle/notebook.png',
            isCorrect: false,
          ),
        ];
      default:
        return [];
    }
  }

  // Helper method to build rounded white item cards
  Widget _buildItemCard({
    required double width,
    required String imageAsset,
    required bool isCorrect,
  }) {
    final cardSize = width * 0.14;

    return GestureDetector(
      onTap: () => _onItemTapped(isCorrect),
      child: Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Image.asset(imageAsset, fit: BoxFit.contain),
      ),
    );
  }
}
