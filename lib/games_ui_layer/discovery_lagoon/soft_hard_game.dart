import 'dart:math';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/feed_the_animal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'lagoon_game_ui.dart';

// Represents an item to be sorted
class SortableItem {
  final String imagePath;
  final bool isSoft; // true = goes Left (Soft), false = goes Right (Hard)

  SortableItem({required this.imagePath, required this.isSoft});
}

class SoftHardGameScreen extends StatefulWidget {
  final int level;

  const SoftHardGameScreen({super.key, required this.level});

  @override
  State<SoftHardGameScreen> createState() => _SoftHardGameScreenState();
}

class _SoftHardGameScreenState extends State<SoftHardGameScreen>
    with TickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  final Random _random = Random();

  bool _isIntroPlaying = true;

  // List of all items to sort
  late List<SortableItem> _remainingItems;
  SortableItem? _currentItem;

  // NEW: Lists to hold items that have been correctly sorted so they stay visible on screen!
  final List<SortableItem> _sortedSoftItems = [];
  final List<SortableItem> _sortedHardItems = [];

  // Track dragging position
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  // Track if game is won
  bool _isGameWon = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _audioPlayer = AudioPlayer();

    // --- NEW: Listen for when the intro audio finishes playing ---
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted && _isIntroPlaying) {
        setState(() {
          _isIntroPlaying = false; // Hide Kiki and show the game!
        });
      }
    });

    _initGame();
    _playIntro(); // Start the intro sequence
  }

  Future<void> _playIntro() async {
    try {
      // Ensure the path matches where you placed soft&hard_intro&tutorial.wav in your assets folder
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/soft&hard_intro&tutorial.wav'),
      );
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
      // Fallback just in case the audio fails to load, so the game isn't stuck
      if (mounted) {
        setState(() => _isIntroPlaying = false);
      }
    }
  }

  void _initGame() {
    // Populate with 4 soft items and 4 hard items
    _remainingItems = [
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/pillow.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/cushion.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/towel.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/teddybear.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/yarn_wb.png',
        isSoft: false,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/yoyo_wb.png',
        isSoft: false,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/plane_wb.png',
        isSoft: false,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/train_wb.png',
        isSoft: false,
      ),
    ];

    // Clear old sorted arrays when restarting!
    _sortedSoftItems.clear();
    _sortedHardItems.clear();

    // Shuffle so the order is randomized each game!
    _remainingItems.shuffle(_random);
    _loadNextItem();
  }

  void _loadNextItem() {
    setState(() {
      _dragOffset = Offset.zero;
      _isDragging = false;
      if (_remainingItems.isNotEmpty) {
        _currentItem = _remainingItems.removeLast();
      } else {
        _currentItem = null;
        _isGameWon = true; // All items sorted!
      }
    });
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing audio ($assetPath): $e");
    }
  }

  /// Handles when the player releases an item after dragging
  void _onPanEnd(DragEndDetails details, double screenWidth) {
    if (_currentItem == null) return;

    setState(() {
      _isDragging = false;
    });

    // Calculate where the item was dropped horizontally relative to screen center
    final double droppedX = (screenWidth / 2) + _dragOffset.dx;
    final bool droppedOnLeft = droppedX < screenWidth * 0.45;
    final bool droppedOnRight = droppedX > screenWidth * 0.55;

    // Check if sorted correctly!
    if (_currentItem!.isSoft && droppedOnLeft) {
      // Correctly placed in SOFT! Add it to the soft display array so it stays visible!
      _playSound('audio/sound_effects/shine.wav');
      setState(() {
        _sortedSoftItems.add(_currentItem!);
      });
      _loadNextItem();
    } else if (!_currentItem!.isSoft && droppedOnRight) {
      // Correctly placed in HARD! Add it to the hard display array so it stays visible!
      _playSound('audio/sound_effects/shine.wav');
      setState(() {
        _sortedHardItems.add(_currentItem!);
      });
      _loadNextItem();
    } else if (droppedOnLeft || droppedOnRight) {
      // Placed on the WRONG side! Snap back to center and play try-again sound.
      _playSound('audio/discovery_lagoon/kiki_tryagain.wav');
      setState(() {
        _dragOffset = Offset.zero; // Snap back to center line
      });
    } else {
      // Dropped too close to the middle dashed line, just snap back
      setState(() {
        _dragOffset = Offset.zero;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;
    final double itemSize = sh * 0.38; // Universal responsive item size!

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A. BACKGROUND LAYER
          Image.asset(
            'assets/images/objects/lagoon/soft_hard_bg.png',
            fit: BoxFit.cover,
          ),

          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

          // C. SORTED SOFT ITEMS LAYER (Displays correctly sorted items on the Left!)
          Positioned(
            left: sw * 0.03,
            top: sh * 0.32,
            width: sw * 0.42,
            height: sh * 0.65,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _sortedSoftItems.map((item) {
                return AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    item.imagePath,
                    width:
                        sh * 0.28, // Sized cleanly to fit 4 items on the side
                    height: sh * 0.28,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            ),
          ),

          // D. SORTED HARD ITEMS LAYER (Displays correctly sorted items on the Right!)
          Positioned(
            right: sw * 0.03,
            top: sh * 0.32,
            width: sw * 0.42,
            height: sh * 0.65,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _sortedHardItems.map((item) {
                return AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    item.imagePath,
                    width:
                        sh * 0.28, // Sized cleanly to fit 4 items on the side
                    height: sh * 0.28,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            ),
          ),

          // E. DRAGGABLE ITEM LAYER (Spawns on the center line!)
          if (_currentItem != null)
            Positioned(
              left: (sw / 2) - (itemSize / 2) + _dragOffset.dx,
              top: (sh / 2) - (itemSize / 2) + _dragOffset.dy + (sh * 0.10),
              child: GestureDetector(
                onPanStart: (_) => setState(() => _isDragging = true),
                onPanUpdate: (details) {
                  setState(() {
                    _dragOffset += details.delta;
                  });
                },
                onPanEnd: (details) => _onPanEnd(details, sw),
                child: AnimatedScale(
                  scale: _isDragging
                      ? 1.15
                      : 1.0, // Scales up slightly when dragged!
                  duration: const Duration(milliseconds: 150),
                  child: Image.asset(
                    _currentItem!.imagePath,
                    width: itemSize,
                    height: itemSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

          if (_isIntroPlaying)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(
                  0.5,
                ), // Dims the background slightly
                // Align to the bottom and push down by 50% of the image's height
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionalTranslation(
                    translation: const Offset(0.0, 0.2),
                    child: Image.asset(
                      'assets/images/characters/kiki_the_cat.png',
                      height: sh * 1, // Your adjusted height
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

          // F. GOOD JOB VICTORY OVERLAY (Appears once all 8 items are sorted!)
          if (_isGameWon)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/kiki_smiling.png',
              closeButtonColor: LagoonColorTheme.wasteland,
              characterSizeFactor: 0.9,
              onNext: () async {
                // Mark Level 5 as complete to unlock Level 6
                await LagoonProgressService.instance.markLevelComplete(5);
                if (context.mounted) {
                  // 2. Push directly to the next level's screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeedTheAnimalGame(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  _isGameWon = false;
                  _initGame();
                });
              },
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}