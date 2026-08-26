import 'dart:async'; // Added for StreamSubscription
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class PickingTrashGame extends StatefulWidget {
  const PickingTrashGame({Key? key}) : super(key: key);

  @override
  State<PickingTrashGame> createState() => _PickingTrashGameState();
}

class _PickingTrashGameState extends State<PickingTrashGame> {
  // ==========================================
  // GAME STATE
  // ==========================================
  bool _showDrWoo = true;
  bool _isGameFinished =
      false; // Tracks when all trash is collected and ending is done[cite: 6]

  final double drWooX = 0.35;
  final double drWooY = 0.33;
  final double drWooSize = 0.30;

  late AudioPlayer _audioPlayer;
  StreamSubscription<void>?
  _playerCompleteSubscription; // Added to manage audio listeners

  List<TrashItemData> trashItems = [];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _audioPlayer = AudioPlayer();
    _resetLevel(); // Initialize the level items and audio for the first time[cite: 6]
  }

  // ==========================================
  // LEVEL INITIALIZATION & RESTART
  // ==========================================
  void _resetLevel() {
    setState(() {
      _isGameFinished = false;
      _showDrWoo = true;

      // Load all items with their fresh starting coordinates[cite: 6]
      trashItems = [
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_apple.png',
          x: 0.00,
          y: 0.68,
          size: 0.08,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_chips2.png',
          x: 0.10,
          y: 0.83,
          size: 0.10,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_garbagebag2.png',
          x: 0.10,
          y: 0.38,
          size: 0.10,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_styro.png',
          x: 0.21,
          y: 0.39,
          size: 0.075,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_banana.png',
          x: 0.27,
          y: 0.40,
          size: 0.07,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_spoon.png',
          x: 0.35,
          y: 0.49,
          size: 0.06,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_plasticbag.png',
          x: 0.25,
          y: 0.58,
          size: 0.11,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_chips1.png',
          x: 0.26,
          y: 0.85,
          size: 0.08,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_sodacan.png',
          x: 0.42,
          y: 0.46,
          size: 0.07,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_stick.png',
          x: 0.40,
          y: 0.55,
          size: 0.12,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_plastic1.png',
          x: 0.46,
          y: 0.78,
          size: 0.08,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_waterbottle.png',
          x: 0.53,
          y: 0.63,
          size: 0.09,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_drink.png',
          x: 0.58,
          y: 0.36,
          size: 0.03,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_leaf.png',
          x: 0.62,
          y: 0.50,
          size: 0.09,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_garbagebag1.png',
          x: 0.79,
          y: 0.54,
          size: 0.06,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_glassbottle.png',
          x: 0.84,
          y: 0.48,
          size: 0.06,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_fishbone.png',
          x: 0.67,
          y: 0.76,
          size: 0.07,
        ),
        TrashItemData(
          image: 'assets/images/objects/lumi/trash_rug.png',
          x: 0.90,
          y: 0.82,
          size: 0.09,
        ),
      ];
    });

    _playIntroSequence();
  }

  Future<void> _playIntroSequence() async {
    await _audioPlayer.play(
      AssetSource('audio/lumi_town/level10/picking_trash_game_intro.wav'),
    );

    // Cancel any previous listeners before adding a new one
    _playerCompleteSubscription?.cancel();

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _showDrWoo = false;
        });
      }
    });
  }

  Future<void> _playEndingSequence() async {
    // Bring Dr. Woo back to the center of the screen
    setState(() {
      _showDrWoo = true;
    });

    // Play the ending audio
    await _audioPlayer.play(
      AssetSource('audio/lumi_town/level10/picking_trash_game_ending.wav'),
    );

    // Swap the listener to wait for the ending audio to finish
    _playerCompleteSubscription?.cancel();

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _showDrWoo = false; // Hide Dr. Woo again
          _isGameFinished = true; // Trigger the GoodJobOverlay
        });
      }
    });
  }

  // ==========================================
  // ANIMATION & WIN LOGIC
  // ==========================================
  Future<void> _handleTrashTap(TrashItemData item) async {
    // Added a check: If ending sequence is playing (_showDrWoo is true), prevent taps
    if (_showDrWoo || item.isCollected || _isGameFinished) return;

    bool startedOnLeft = item.x < 0.5;

    // 1. Move to the center AND bring to the front
    setState(() {
      trashItems.remove(item);
      trashItems.add(item);

      item.x = 0.5 - (item.size / 2);
      item.y = 0.5 - (item.size / 2);
    });

    await Future.delayed(const Duration(milliseconds: 800));
    await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));

    // 2. Fly away left or right
    setState(() {
      if (startedOnLeft) {
        item.x = -0.5;
      } else {
        item.x = 1.5;
      }
    });

    await Future.delayed(const Duration(milliseconds: 800));

    // 3. Mark as collected and CHECK WIN CONDITION
    if (mounted) {
      setState(() {
        item.isCollected = true;

        // If every item in the list is collected, trigger the ending sequence!
        if (trashItems.every((t) => t.isCollected)) {
          _playEndingSequence();
        }
      });
    }
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel(); // Clean up the listener
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_park_sunny.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Trash Assets Overlay (Animated)[cite: 6]
          ...trashItems.where((item) => !item.isCollected).map((item) {
            return AnimatedPositioned(
              key: ValueKey(item.image),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              left: screenSize.width * item.x,
              top: screenSize.height * item.y,
              width: screenSize.width * item.size,
              child: GestureDetector(
                onTap: () => _handleTrashTap(item),
                child: Image.asset(item.image, fit: BoxFit.contain),
              ),
            );
          }).toList(),

          const Positioned(top: 25, left: 20, child: LumiBackButton()),

          // 3. Dr. Woo (The Owl) Overlay[cite: 6]
          if (_showDrWoo)
            Positioned(
              left: screenSize.width * drWooX,
              top: screenSize.height * drWooY,
              width: screenSize.width * drWooSize,
              child: Image.asset(
                'assets/images/characters/dr.woo_the_owl.png',
                fit: BoxFit.contain,
              ),
            ),

          // 4. Good Job Overlay (Appears when all trash is collected AND audio finishes)[cite: 6]
          if (_isGameFinished)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/dr.woo_the_owl.png',
                closeButtonColor: Colors.blueAccent,
                onNext: () async {
                  await TownProgressService.instance.markLevelComplete(10);
                  // TODO: Navigate to the next level
                  print("Proceed to next level!");
                },
                onRestart: () {
                  // Resets everything back to the beginning
                  _resetLevel();
                },
                onBack: () {
                  // Navigate back to the level selection menu
                  Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class TrashItemData {
  final String image;
  double x;
  double y;
  final double size;
  bool isCollected;

  TrashItemData({
    required this.image,
    required this.x,
    required this.y,
    required this.size,
    this.isCollected = false,
  });
}
