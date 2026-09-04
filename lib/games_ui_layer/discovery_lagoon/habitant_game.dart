import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/seed_game.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../goodjob_prompt.dart';
import 'lagoon_game_ui.dart';

class CharacterAdjustment {
  final double size;
  final double offsetX;
  final double offsetY;

  const CharacterAdjustment({
    this.size = 150.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });
}

class HabitantGame extends StatefulWidget {
  final int level;

  const HabitantGame({super.key, required this.level});

  @override
  State<HabitantGame> createState() => _HabitantGameState();
}

class _HabitantGameState extends State<HabitantGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _audioSubscription;

  bool _showIntro = true;
  bool _isGameWon = false; // Tracks if the player has won

  Map<String, String> currentPlacements = {
    'arctic': 'dog',
    'town': 'frog',
    'waterfall': 'bear',
    'forest': 'penguin',
  };

  final Map<String, String> correctHabitats = {
    'dog': 'town',
    'frog': 'waterfall',
    'bear': 'forest',
    'penguin': 'arctic',
  };

  final Map<String, String> sadImages = {
    'dog': 'tofi_cold.png',
    'frog': 'frog_sad.png',
    'bear': 'little_bear_wet.png',
    'penguin': 'doma_sweat.png',
  };

  final Map<String, String> happyImages = {
    'dog': 'tofi_smiling.png',
    'frog': 'frog.png',
    'bear': 'little_bear_uniform.png',
    'penguin': 'doma_smiling.png',
  };

  final Map<String, CharacterAdjustment> adjustments = {
    'dog': const CharacterAdjustment(
      size: 200.0,
      offsetX: -15.0,
      offsetY: 60.0,
    ),
    'frog': const CharacterAdjustment(
      size: 175.0,
      offsetX: 10.0,
      offsetY: 60.0,
    ),
    'bear': const CharacterAdjustment(
      size: 200.0,
      offsetX: -15.0,
      offsetY: 50.0,
    ),
    'penguin': const CharacterAdjustment(
      size: 210.0,
      offsetX: 10.0,
      offsetY: 40.0,
    ),
  };

  // Adjusters for the Intro Cat
  final CharacterAdjustment introCatAdjustment = const CharacterAdjustment(
    size: 400.0,
    offsetX: 0.0,
    offsetY: 80.0,
  );

  final double introHeightFactor = 1.0;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _playIntro();
  }

  Future<void> _playIntro() async {
    _audioSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && _showIntro) {
        setState(() {
          _showIntro = false;
        });
      }
    });

    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/habitant_game_intro_tutorial.wav'),
    );
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    _audioSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(bool isCorrect) async {
    if (isCorrect) {
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
    }
  }

  String _getCharacterImage(String characterId, String currentZone) {
    if (correctHabitats[characterId] == currentZone) {
      return happyImages[characterId]!;
    }
    return sadImages[characterId]!;
  }

  /// Checks if every character is currently in their correct habitat
  void _checkForWin() {
    bool allCorrect = true;
    currentPlacements.forEach((zoneId, characterId) {
      if (correctHabitats[characterId] != zoneId) {
        allCorrect = false;
      }
    });

    if (allCorrect) {
      setState(() {
        _isGameWon = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- THE MAIN GAME ---
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildDropZone('arctic', 'bg_arctic.png')),
                    Expanded(child: _buildDropZone('town', 'bg_town.png')),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDropZone(
                        'waterfall',
                        'bg_rainbow_closeup2.png',
                      ),
                    ),
                    Expanded(
                      child: _buildDropZone('forest', 'bg_forest_closeup.png'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // --- THE INTRO OVERLAY ---
          if (_showIntro)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Transform.translate(
                  offset: Offset(
                    introCatAdjustment.offsetX,
                    introCatAdjustment.offsetY,
                  ),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: introHeightFactor,
                      child: Image.asset(
                        'assets/images/characters/kiki_the_cat.png',
                        height: introCatAdjustment.size,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

          // --- THE GOOD JOB OVERLAY ---
          if (_isGameWon)
            GoodJobOverlay(
              // Using Kiki for the congratulations screen, but you can change this!
              characterImage: 'assets/images/characters/kiki_smiling.png',
              closeButtonColor: Colors.orange,
              onNext: () async {
                // 1. Mark the current level as complete (Change the number for each game)
                await LagoonProgressService.instance.markLevelComplete(10);

                if (context.mounted) {
                  // 2. Push directly to the next level's screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => SeedGame(level: widget.level)),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  _isGameWon = false;
                  // Reset animals to their incorrect starting positions
                  currentPlacements = {
                    'arctic': 'dog',
                    'town': 'frog',
                    'waterfall': 'bear',
                    'forest': 'penguin',
                  };
                });
              },
              onBack: () {
                // Pops the screen to go back to the previous menu
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDropZone(String zoneId, String backgroundFileName) {
    String currentCharacterId = currentPlacements[zoneId]!;
    String currentCharacterFileName = _getCharacterImage(
      currentCharacterId,
      zoneId,
    );

    CharacterAdjustment adjustment =
        adjustments[currentCharacterId] ?? const CharacterAdjustment();

    Widget characterImageWidget = Transform.translate(
      offset: Offset(adjustment.offsetX, adjustment.offsetY),
      child: Image.asset(
        'assets/images/characters/$currentCharacterFileName',
        height: adjustment.size,
      ),
    );

    return DragTarget<String>(
      onWillAccept: (sourceZoneId) => sourceZoneId != zoneId,
      onAccept: (sourceZoneId) {
        setState(() {
          String movingCharacter = currentPlacements[sourceZoneId]!;
          String displacedCharacter = currentPlacements[zoneId]!;

          currentPlacements[zoneId] = movingCharacter;
          currentPlacements[sourceZoneId] = displacedCharacter;

          bool isCorrect = correctHabitats[movingCharacter] == zoneId;
          _playSound(isCorrect);

          // Check if the game is won after this move
          _checkForWin();
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/images/backgrounds/$backgroundFileName',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Draggable<String>(
              data: zoneId,
              feedback: Material(
                color: Colors.transparent,
                child: characterImageWidget,
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: characterImageWidget,
              ),
              child: characterImageWidget,
            ),
          ),
        );
      },
    );
  }
}
