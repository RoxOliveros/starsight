import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class HabitantGame extends StatefulWidget {
  const HabitantGame({Key? key}) : super(key: key);

  @override
  State<HabitantGame> createState() => _HabitantGameState();
}

class _HabitantGameState extends State<HabitantGame> {
  // The AudioPlayer instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  // We now map the zone to the character ID rather than the image directly
  Map<String, String> currentPlacements = {
    'arctic': 'dog',
    'town': 'frog',
    'waterfall': 'bear',
    'forest': 'penguin',
  };

  // Defines the correct winning zones for each character
  final Map<String, String> correctHabitats = {
    'dog': 'town',
    'frog': 'waterfall',
    'bear': 'forest',
    'penguin': 'arctic',
  };

  // The images to show when the character is in the WRONG habitat
  final Map<String, String> sadImages = {
    'dog': 'tofi_cold.png',
    'frog': 'frog_sad.png',
    'bear': 'little_bear_wet.png',
    'penguin': 'doma_sweat.png',
  };

  // The images to show when the character is in the RIGHT habitat
  final Map<String, String> happyImages = {
    'dog': 'tofi_smiling.png',
    'frog': 'frog.png',
    'bear': 'little_bear_uniform.png',
    'penguin': 'doma_smiling.png',
  };

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
  }

  @override
  void dispose() {
    OrientationService.setPortrait();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Plays the shine sound only when the drop is correct
  Future<void> _playSound(bool isCorrect) async {
    if (isCorrect) {
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
    }
    // Removed the else block for the 'try again' audio
  }

  /// Determines which image to display based on the character's current location
  String _getCharacterImage(String characterId, String currentZone) {
    if (correctHabitats[characterId] == currentZone) {
      return happyImages[characterId]!;
    }
    return sadImages[characterId]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
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
                  child: _buildDropZone('waterfall', 'bg_rainbow_closeup2.png'),
                ),
                Expanded(
                  child: _buildDropZone('forest', 'bg_forest_closeup.png'),
                ),
              ],
            ),
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

    return DragTarget<String>(
      onWillAccept: (sourceZoneId) => sourceZoneId != zoneId,
      onAccept: (sourceZoneId) {
        setState(() {
          String movingCharacter = currentPlacements[sourceZoneId]!;
          String displacedCharacter = currentPlacements[zoneId]!;

          // Swap their positions
          currentPlacements[zoneId] = movingCharacter;
          currentPlacements[sourceZoneId] = displacedCharacter;

          // Check if the character being dropped is now in its correct habitat
          bool isCorrect = correctHabitats[movingCharacter] == zoneId;
          _playSound(isCorrect);
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
                child: Image.asset(
                  'assets/images/characters/$currentCharacterFileName',
                  height: 150,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/images/characters/$currentCharacterFileName',
                  height: 150,
                ),
              ),
              child: Image.asset(
                'assets/images/characters/$currentCharacterFileName',
                height: 150,
              ),
            ),
          ),
        );
      },
    );
  }
}
