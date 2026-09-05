import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/listening_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'lagoon_game_ui.dart';

class PerfumeGame extends StatefulWidget {
  final int level;

  const PerfumeGame({super.key, required this.level});

  @override
  State<PerfumeGame> createState() => _PerfumeGameState();
}

class _PerfumeGameState extends State<PerfumeGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _currentStage = 1;
  bool _showOptions = false;
  bool _canTap = false;
  bool _isKikiSmiling = false;
  bool _actionTaken = false;

  bool _hasFlower = false;
  bool _hasStrawberry = false;
  bool _hasLemon = false;
  bool _hasHoney = false;

  bool _canDragIngredients = false;
  bool _flowerInBowl = false;
  bool _strawberryInBowl = false;
  bool _lemonInBowl = false;
  bool _honeyInBowl = false;
  bool _canMix = false;
  bool _isMixing = false;
  bool _showMixStar = false;
  bool _showPerfume = false;
  bool _showKikiCheering = false;

  bool _showGoodJob = false;

  // NEW: guards against acting on a disposed player / stream
  bool _disposed = false;

  bool get _allIngredientsInBowl =>
      _flowerInBowl && _strawberryInBowl && _lemonInBowl && _honeyInBowl;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _startAudioSequence();
  }

  /// NEW: waits for the current sound to finish without throwing
  /// "Bad state: No element" if the player is disposed mid-wait.
  Future<void> _waitForAudioComplete() async {
    try {
      await _audioPlayer.onPlayerComplete.first;
    } catch (_) {
      // Stream closed (player disposed) before it ever completed — ignore.
    }
  }

  Future<void> _startAudioSequence() async {
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/perfume_intro.wav'),
    );

    _waitForAudioComplete().then((_) async {
      if (!mounted || _disposed) return;

      setState(() {
        _showOptions = true;
        _canTap = false;
      });

      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/perfume_tutorial.wav'),
      );

      _waitForAudioComplete().then((_) {
        if (!mounted || _disposed) return;
        setState(() {
          _canTap = true;
        });
      });
    });
  }

  Future<void> _playKikiAudio(String assetPath) async {
    if (_disposed) return;
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(assetPath));
  }

  Future<void> _handleCorrectPick() async {
    if (!_canTap || _actionTaken) return;
    _actionTaken = true;

    setState(() {
      _showOptions = false;
      _isKikiSmiling = true;
      _canTap = false;

      if (_currentStage == 1) {
        _hasFlower = true;
      } else if (_currentStage == 2) {
        _hasStrawberry = true;
      } else if (_currentStage == 3) {
        _hasLemon = true;
      } else if (_currentStage == 4) {
        _hasHoney = true;
      }
    });

    await _playKikiAudio('audio/sound_effects/shine.wav');
    await _waitForAudioComplete();
    if (_disposed) return;

    await _playKikiAudio('audio/discovery_lagoon/perfume_rc.wav');
    await _waitForAudioComplete();
    if (_disposed) return;

    if (_currentStage == 1 && mounted) {
      _transitionToStage2();
    } else if (_currentStage == 2 && mounted) {
      _transitionToStage3
        (
      );
    } else if (_currentStage == 3 && mounted) {
      _transitionToStage4
        (
      );
    } else if (_currentStage == 4 && mounted) {
      _transitionToStage5();
    }
  }

  void _transitionToStage2() {
    setState(() {
      _currentStage = 2;
      _isKikiSmiling = false;
      _actionTaken = false;
      _showOptions = true;
      _canTap = true;
    });
  }

  void _transitionToStage3() {
    setState(() {
      _currentStage = 3;
      _isKikiSmiling = false;
      _actionTaken = false;
      _showOptions = true;
      _canTap = true;
    });
  }

  void _transitionToStage4() {
    setState(() {
      _currentStage = 4;
      _isKikiSmiling = false;
      _actionTaken = false;
      _showOptions = true;
      _canTap = true;
    });
  }

  Future<void> _transitionToStage5() async {
    setState(() {
      _currentStage = 5;
      _isKikiSmiling = false;
      _actionTaken = false;
      _canTap = false;
    });

    await _playKikiAudio('audio/discovery_lagoon/perfume_complete_recipe.wav');
    await _waitForAudioComplete();
    if (_disposed) return;

    if (mounted) {
      setState(() {
        _canDragIngredients = true;
      });
    }
  }

  void _handleIngredientDropped(String id) {
    setState(() {
      switch (id) {
        case 'flower':
          _flowerInBowl = true;
          break;
        case 'strawberry':
          _strawberryInBowl = true;
          break;
        case 'lemon':
          _lemonInBowl = true;
          break;
        case 'honey':
          _honeyInBowl = true;
          break;
      }
      if (_allIngredientsInBowl) {
        _canMix = true;
        _currentStage = 6;
      }
    });
  }

  Future<void> _handleMixerDropped() async {
    if (!_canMix || _isMixing) return;

    setState(() {
      _isMixing = true;
      _canMix = false;
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _disposed) return;

    setState(() {
      _showMixStar = true;
    });

    await _playKikiAudio('audio/sound_effects/shine.wav');
    await _waitForAudioComplete();
    if (!mounted || _disposed) return;

    setState(() {
      _currentStage = 7;
      _isMixing = false;
      _showMixStar = false;
      _showPerfume = true;
      _showKikiCheering = true;
      _isKikiSmiling = true;
    });

    await _playKikiAudio('audio/discovery_lagoon/perfume_completed.wav');
    await _waitForAudioComplete();
    if (_disposed) return;

    if (mounted) {
      _transitionToStage8();
    }
  }

  Future<void> _transitionToStage8() async {
    setState(() {
      _currentStage = 8;
      _showPerfume = false;
      _showKikiCheering = false;
      _isKikiSmiling = false;
      _actionTaken = false;
      _showOptions = true;
      _canTap = false;
    });

    await _playKikiAudio('audio/discovery_lagoon/perfume_whatpart.wav');
    await _waitForAudioComplete();
    if (_disposed) return;

    if (mounted) {
      setState(() {
        _canTap = true;
      });
    }
  }

  Future<void> _handleCorrectNosePick() async {
    if (!_canTap || _actionTaken) return;

    setState(() {
      _actionTaken = true;
      _canTap = false;
      _showOptions = false;
      _showKikiCheering = true;
    });

    await _playKikiAudio('audio/sound_effects/shine.wav');
    await _waitForAudioComplete();
    if (_disposed) return;

    await _playKikiAudio('audio/discovery_lagoon/perfume_ending.wav');
    await _waitForAudioComplete();
    if (_disposed) return;

    if (mounted) {
      setState(() {
        _showGoodJob = true;
      });
    }
  }

  Future<void> _handleWrongPick() async {
    if (!_canTap || _actionTaken) return;

    setState(() {
      _canTap = false;
    });

    await _playKikiAudio('audio/discovery_lagoon/kiki_tryagain.wav');

    _waitForAudioComplete().then((_) {
      if (mounted && !_disposed && !_actionTaken) {
        setState(() {
          _canTap = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final double catHeight = sh * 0.85;
    final double catBottom = sh * 0.05;
    final double tableWidth = sw;
    final double tableBottom = -sh * 0.58;
    final double bowlWidth = sw * 0.14;
    final double bowlBottom = sh * 0.10;
    final double mixerWidth = sw * 0.11;
    final double mixerBottom = sh * 0.07;
    final double cardSize = sw * 0.18;
    final double cardTop = sh * 0.22;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_lagoon.png',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8AD8E8), Color(0xFFA8E6CF)],
                ),
              ),
            ),
          ),

          // ── 2. Cat Character (Behind table)
          Positioned(
            bottom: catBottom,
            left: 0,
            right: 0,
            child: Center(
              child:
                  Image.asset(
                        _showKikiCheering
                            ? 'assets/animations/characters/kiki_cheering.webp'
                            : _isKikiSmiling
                            ? 'assets/images/characters/kiki_smiling.png'
                            : 'assets/images/characters/kiki_the_cat.png',
                        height: _showKikiCheering ? catHeight * 1.1 : catHeight,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => Container(
                          width: catHeight * 0.8,
                          height: catHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3D1),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: const Color(0xFF6D4C41),
                              width: 4,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.pets,
                              size: 64,
                              color: Color(0xFF8D6E63),
                            ),
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(
                        begin: 0,
                        end: -8,
                        duration: 1500.ms,
                        curve: Curves.easeInOut,
                      ),
            ),
          ),

          // ── 3. Table Foreground
          Positioned(
            bottom: tableBottom,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/objects/lumi/table.png',
              width: tableWidth,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) =>
                  Container(height: sh * 0.28, color: const Color(0xFFD0812D)),
            ),
          ),

          // ── 4. Mortar / Bowl
          if (_currentStage < 7)
            Positioned(
              bottom: bowlBottom,
              left: sw * 0.43,
              child:
                  DragTarget<String>(
                        onWillAcceptWithDetails: (details) {
                          if (details.data == 'mixer') {
                            return _canMix && !_isMixing;
                          }
                          return _canDragIngredients && !_isMixing;
                        },
                        onAcceptWithDetails: (details) {
                          if (details.data == 'mixer') {
                            _handleMixerDropped();
                          } else {
                            _handleIngredientDropped(details.data);
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          final bool isHovering = candidateData.isNotEmpty;
                          return AnimatedScale(
                            scale: isHovering ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child:
                                Image.asset(
                                      'assets/images/objects/lagoon/bowl.png',
                                      width: bowlWidth,
                                      fit: BoxFit.contain,
                                      errorBuilder: (ctx, err, st) => Container(
                                        width: bowlWidth,
                                        height: bowlWidth * 0.8,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFA07040),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                bottom: Radius.circular(40),
                                              ),
                                          border: Border.all(
                                            color: const Color(0xFF5D4037),
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate(target: _isMixing ? 1 : 0)
                                    .shake(
                                      duration: 1500.ms,
                                      hz: 6,
                                      rotation: 0.06,
                                    ),
                          );
                        },
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.0, 1.0),
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
            ),

          if (_showMixStar)
            Positioned(
              bottom: bowlBottom,
              left: sw * 0.38,
              child:
                  Image.asset(
                        'assets/images/objects/lagoon/mixstar.png',
                        width: bowlWidth * 1.4,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => Icon(
                          Icons.auto_awesome,
                          size: bowlWidth * 0.9,
                          color: const Color(0xFFFFD700),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 250.ms)
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.15, 1.15),
                        duration: 350.ms,
                        curve: Curves.easeOutBack,
                      ),
            ),

          // ── 4c. Finished Perfume
          if (_showPerfume && _currentStage == 7)
            Positioned(
              bottom: bowlBottom,
              left: sw * 0.42,
              child:
                  Image.asset(
                        'assets/images/objects/lagoon/perfume.png',
                        width: bowlWidth * 1.2,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => Icon(
                          Icons.local_drink,
                          size: bowlWidth,
                          color: const Color(0xFF8E5A9D),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.0, 1.0),
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),
            ),

          // ── 5. Pestle / Mixer
          if (_currentStage < 7 && !_isMixing)
            Positioned(
              bottom: mixerBottom,
              left: sw * 0.53,
              child: _buildMixerWidget(mixerWidth)
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),

          // ── 6. Table Ingredients
          if (_hasHoney && !_honeyInBowl && _currentStage < 7)
            Positioned(
              bottom: bowlBottom * 0.75,
              left: sw * 0.09,
              child:
                  _buildTableIngredient(
                        id: 'honey',
                        angle: 0.0,
                        imagePath: 'assets/images/objects/lagoon/honey.png',
                        width: sw * 0.110,
                        fallbackIcon: Icons.shopping_bag,
                        fallbackColor: const Color(0xFFF09838),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
            ),

          if (_hasLemon && !_lemonInBowl && _currentStage < 7)
            Positioned(
              bottom: bowlBottom * 0.68,
              left: sw * 0.18,
              child:
                  _buildTableIngredient(
                        id: 'lemon',
                        angle: -0.15,
                        imagePath: 'assets/images/objects/lagoon/lemon.png',
                        width: sw * 0.085,
                        fallbackIcon: Icons.circle,
                        fallbackColor: const Color(0xFFEAD13C),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
            ),

          if (_hasFlower && !_flowerInBowl && _currentStage < 7)
            Positioned(
              bottom: bowlBottom * 0.9,
              left: sw * 0.27,
              child:
                  _buildTableIngredient(
                        id: 'flower',
                        angle: 0.5,
                        imagePath:
                            'assets/images/objects/lagoon/perfume_flower.png',
                        width: sw * 0.06,
                        fallbackIcon: Icons.local_florist,
                        fallbackColor: const Color(0xFF8E5A9D),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
            ),

          if (_hasStrawberry && !_strawberryInBowl && _currentStage < 7)
            Positioned(
              bottom: bowlBottom * 0.9,
              left: sw * 0.33,
              child:
                  _buildTableIngredient(
                        id: 'strawberry',
                        angle: -0.15,
                        imagePath:
                            'assets/images/objects/lagoon/strawberry.png',
                        width: sw * 0.055,
                        fallbackIcon: Icons.cake,
                        fallbackColor: const Color(0xFFE55A5A),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
            ),

          // ── 7. Option Cards
          if (_showOptions && _currentStage == 1) ...[
            Positioned(
              top: cardTop,
              left: sw * 0.15,
              child:
                  GestureDetector(
                        onTap: _handleWrongPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize,
                          borderColor: const Color(0xFF5C94D6),
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath:
                              'assets/images/objects/lagoon/perfume_fish.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
            ),
            Positioned(
              top: cardTop,
              right: sw * 0.15,
              child:
                  GestureDetector(
                        onTap: _handleCorrectPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize,
                          borderColor: const Color(0xFF8E5A9D),
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath:
                              'assets/images/objects/lagoon/perfume_flower.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 150.ms)
                      .scale(curve: Curves.easeOutBack),
            ),
          ] else if (_showOptions && _currentStage == 2) ...[
            Positioned(
              top: cardTop,
              left: sw * 0.15,
              child:
                  GestureDetector(
                        onTap: _handleCorrectPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize,
                          borderColor: const Color(0xFFE55A5A),
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath:
                              'assets/images/objects/lagoon/strawberry.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
            ),
            Positioned(
              top: cardTop,
              right: sw * 0.15,
              child:
                  GestureDetector(
                        onTap: _handleWrongPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize,
                          borderColor: const Color(0xFF70B85D),
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath: 'assets/images/objects/lagoon/leaf.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 150.ms)
                      .scale(curve: Curves.easeOutBack),
            ),
          ] else if (_showOptions && _currentStage == 3) ...[
            Positioned(
              top: cardTop,
              left: sw * 0.15,
              child:
                  GestureDetector(
                        onTap: _handleWrongPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize,
                          borderColor: const Color(0xFF8E936D),
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath: 'assets/images/objects/lagoon/socks.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
            ),
            Positioned(
              top: cardTop,
              right: sw * 0.15,
              child:
                  GestureDetector(
                        onTap: _handleCorrectPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize,
                          borderColor: const Color(0xFFEAD13C),
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath: 'assets/images/objects/lagoon/lemon.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 150.ms)
                      .scale(curve: Curves.easeOutBack),
            ),
          ] else if (_showOptions && _currentStage == 4) ...[
            Positioned(
              top: cardTop,
              left: sw * 0.15,
              child:
                  GestureDetector(
                        onTap: _handleCorrectPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize,
                          borderColor: const Color(0xFFF09838),
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath: 'assets/images/objects/lagoon/honey.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
            ),
            Positioned(
              top: cardTop,
              right: sw * 0.15,
              child:
                  GestureDetector(
                        onTap: _handleWrongPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize,
                          borderColor: const Color(0xFFB261B8),
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath: 'assets/images/objects/lagoon/onion.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 150.ms)
                      .scale(curve: Curves.easeOutBack),
            ),
          ] else if (_showOptions && _currentStage == 8) ...[
            // Stage 8: Eye, Mouth, Nose Finale!
            Positioned(
              bottom: sh * 0.15,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                        onTap: _handleWrongPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize * 0.8,
                          borderColor:
                              Colors.transparent, // Clean borderless look
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath: 'assets/images/objects/lagoon/eye.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
                  SizedBox(width: sw * 0.05),
                  GestureDetector(
                        onTap: _handleWrongPick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize * 0.8,
                          borderColor: Colors.transparent,
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath: 'assets/images/objects/lagoon/lips.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .scale(curve: Curves.easeOutBack),
                  SizedBox(width: sw * 0.05),
                  GestureDetector(
                        onTap: _handleCorrectNosePick,
                        child: _buildOptionCard(
                          context: context,
                          size: cardSize * 0.8,
                          borderColor: Colors.transparent,
                          placeholderPath:
                              'assets/images/objects/lagoon/white_placeholder.png',
                          itemPath: 'assets/images/objects/lagoon/nose.png',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms)
                      .scale(curve: Curves.easeOutBack),
                ],
              ),
            ),
          ],

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

          // ── 12. Good Job Overlay
          if (_showGoodJob)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/cat_holding_fishbone.png',
              
              characterSizeFactor: 0.9,
              onNext: () async {
                // Mark Level 2 as complete to unlock Level 3
                await LagoonProgressService.instance.markLevelComplete(2);
                if (context.mounted) {
                  // Jump to Level 3 (Listening)
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => ListeningGame(level: widget.level + 1)),
                  );
                }
              },
              onRestart: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => PerfumeGame(level: widget.level)),
                );
              },
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildMixerWidget(double width) {
    final Widget image = Image.asset(
      'assets/images/objects/lagoon/mixer.png',
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, st) => Container(
        width: width,
        height: width * 0.4,
        decoration: BoxDecoration(
          color: const Color(0xFF8D6E63),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4E342E), width: 2),
        ),
      ),
    );

    if (!_canMix) return image;

    return Draggable<String>(
      data: 'mixer',
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(
          'assets/images/objects/lagoon/mixer.png',
          width: width,
          fit: BoxFit.contain,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: image),
      child: image,
    );
  }

  Widget _buildTableIngredient({
    required String id,
    required double angle,
    required String imagePath,
    required double width,
    required IconData fallbackIcon,
    required Color fallbackColor,
  }) {
    final Widget image = Transform.rotate(
      angle: angle,
      child: Image.asset(
        imagePath,
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, st) =>
            Icon(fallbackIcon, size: 40, color: fallbackColor),
      ),
    );

    if (!_canDragIngredients) return image;

    return Draggable<String>(
      data: id,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(imagePath, width: width, fit: BoxFit.contain),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: image),
      child: image,
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required double size,
    required Color borderColor,
    required String placeholderPath,
    required String itemPath,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: borderColor == Colors.transparent
            ? null
            : Border.all(color: borderColor, width: size * 0.06),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              placeholderPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(color: Colors.white),
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.15),
              child: Image.asset(
                itemPath,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => Icon(
                  itemPath.contains('fish')
                      ? Icons.phishing
                      : itemPath.contains('flower')
                      ? Icons.local_florist
                      : itemPath.contains('strawberry')
                      ? Icons.cake
                      : itemPath.contains('lemon')
                      ? Icons.circle
                      : itemPath.contains('honey')
                      ? Icons.shopping_bag
                      : itemPath.contains('eye')
                      ? Icons.visibility
                      : itemPath.contains('mouth')
                      ? Icons.record_voice_over
                      : itemPath.contains('nose')
                      ? Icons.face
                      : Icons.eco,
                  size: size * 0.5,
                  color: borderColor == Colors.transparent
                      ? Colors.grey
                      : borderColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
