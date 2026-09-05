import 'dart:async';
import 'dart:math' as math;
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl12/appreciation_game.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_buttons.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';

// ==========================================
// 🛠️ TRASH ITEM DATA MODEL
// ==========================================
class TrashItem {
  final String imagePath;
  final int correctBinId; // 1 = Green, 2 = Blue, 3 = Yellow

  TrashItem(this.imagePath, this.correctBinId);
}

class ThrowingTrashGame extends StatefulWidget {
  const ThrowingTrashGame({Key? key}) : super(key: key);

  @override
  State<ThrowingTrashGame> createState() => _ThrowingTrashGameState();
}

class _ThrowingTrashGameState extends State<ThrowingTrashGame>
    with TickerProviderStateMixin {
  // ==========================================
  // 🛠️ ADJUSTERS
  // ==========================================
  // Trashcan Adjusters
  final double trashcanWidthPercentage = 0.25;
  final double trashcanIntroBottomOffset = 20.0; // Height during intro
  final double spacingBetweenCans = 20.0;
  final double backgroundWhiteOpacity = 0.4;
  final double walkBounceHeight = 25.0;
  final double jumpHeight = 30.0;

  // Timing Adjusters
  final int audioIntervalMilliseconds = 800;

  // Dr. Woo Adjusters
  final double drWooHeightPercentage = 0.85;
  final double darkOverlayOpacity = 0.7;
  final double drWooVerticalOffset = 60.00;

  late final AnimationController _walkCtrl;
  late final AnimationController _jumpCtrl;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _introStep = 0;

  // Gameplay State
  late List<TrashItem> _remainingTrash;
  TrashItem? _currentTrash;
  int _sadBinId = 0;
  bool _isGameWon = false;

  // NEW: State for fading trash at the drop location
  bool _isTrashFading = false;
  TrashItem? _fadingTrash;
  Offset? _droppedPosition;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _initTrashItems();

    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _jumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..repeat(reverse: true);

    _audioPlayer.onPlayerComplete.listen((event) async {
      if (!mounted) return;

      if (_introStep == 1) {
        setState(() => _introStep = -1);
        await Future.delayed(Duration(milliseconds: audioIntervalMilliseconds));
        if (!mounted) return;

        setState(() => _introStep = 2);
        _playAudio('audio/lumi_town/level11/throwing_trash_game_trashcan1.wav');
      } else if (_introStep == 2) {
        setState(() => _introStep = -1);
        await Future.delayed(Duration(milliseconds: audioIntervalMilliseconds));
        if (!mounted) return;

        setState(() => _introStep = 3);
        _playAudio('audio/lumi_town/level11/throwing_trash_game_trashcan2.wav');
      } else if (_introStep == 3) {
        setState(() => _introStep = -1);
        await Future.delayed(Duration(milliseconds: audioIntervalMilliseconds));
        if (!mounted) return;

        setState(() => _introStep = 4);
        _playAudio('audio/lumi_town/level11/throwing_trash_game_trashcan3.wav');
      } else if (_introStep == 4) {
        setState(() {
          _introStep = 5; // Intro done! Gameplay begins, trashcans slide down.
          _jumpCtrl.stop();
        });
      }
    });

    _walkCtrl.forward().then((_) {
      if (mounted) {
        setState(() => _introStep = 1);
        _playAudio('audio/lumi_town/level11/throwing_trash_game_intro.wav');
      }
    });
  }

  void _initTrashItems() {
    _remainingTrash = [
      // BIN 1: Biodegradable (Rotting/Decaying)
      TrashItem('assets/images/objects/lumi/trash_apple.png', 1),
      TrashItem('assets/images/objects/lumi/trash_banana.png', 1),
      TrashItem('assets/images/objects/lumi/trash_fishbone.png', 1),
      TrashItem('assets/images/objects/lumi/trash_leaf.png', 1),
      TrashItem('assets/images/objects/lumi/trash_stick.png', 1),

      // BIN 2: Non-Biodegradable
      TrashItem('assets/images/objects/lumi/trash_chips2.png', 2),
      TrashItem('assets/images/objects/lumi/trash_garbagebag2.png', 2),
      TrashItem('assets/images/objects/lumi/trash_styro.png', 2),
      TrashItem('assets/images/objects/lumi/trash_chips1.png', 2),
      TrashItem('assets/images/objects/lumi/trash_plasticbag.png', 2),
      TrashItem('assets/images/objects/lumi/trash_spoon.png', 2),
      TrashItem('assets/images/objects/lumi/trash_plastic1.png', 2),
      TrashItem('assets/images/objects/lumi/trash_drink.png', 2),
      TrashItem('assets/images/objects/lumi/trash_garbagebag1.png', 2),
      TrashItem('assets/images/objects/lumi/trash_rug.png', 2),

      // BIN 3: Recyclable
      TrashItem('assets/images/objects/lumi/trash_waterbottle.png', 3),
      TrashItem('assets/images/objects/lumi/trash_sodacan.png', 3),
      TrashItem('assets/images/objects/lumi/trash_glassbottle.png', 3),
    ];

    _remainingTrash.shuffle();
    _loadNextTrash();
  }

  void _loadNextTrash() {
    setState(() {
      if (_remainingTrash.isNotEmpty) {
        _currentTrash = _remainingTrash.removeLast();
      } else {
        _currentTrash = null;
        _isGameWon = true;
      }
    });
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint("Error playing audio ($path): $e");
    }
  }

  // Changed to receive DragTargetDetails so we can get the exact pixel location
  void _handleDrop(DragTargetDetails<TrashItem> details, int targetBinId) {
    final TrashItem item = details.data;

    if (item.correctBinId == targetBinId) {
      // Correct Bin!
      _playAudio('audio/sound_effects/shine.wav');

      setState(() {
        _isTrashFading = true; // Hides the main draggable at the top
        _fadingTrash = item; // Sets the clone image
        _droppedPosition = details.offset; // Grabs the exact drop coordinates
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadNextTrash();
          setState(() {
            _isTrashFading = false;
            _fadingTrash = null;
            _droppedPosition = null;
          });
        }
      });
    } else {
      // Wrong Bin!
      _playAudio('audio/lumi_town/dr.woo_tryagain.wav');

      setState(() => _sadBinId = targetBinId);

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _sadBinId = 0);
        }
      });
    }
  }

  @override
  void dispose() {
    _walkCtrl.dispose();
    _jumpCtrl.dispose();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Widget _buildTrashcan(
    String happyPath,
    String sadPath,
    double width,
    int step,
    int binId,
  ) {
    final bool isJumping = _introStep == step;
    final bool isSad = _sadBinId == binId;

    return DragTarget<TrashItem>(
      onAcceptWithDetails: (details) => _handleDrop(details, binId),
      builder: (context, candidateData, rejectedData) {
        return AnimatedBuilder(
          animation: _jumpCtrl,
          builder: (context, child) {
            final double bounce = isJumping
                ? _jumpCtrl.value * jumpHeight
                : 0.0;
            return Transform.translate(
              offset: Offset(0, -bounce),
              child: child,
            );
          },
          child: Image.asset(
            isSad ? sadPath : happyPath,
            width: width,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final trashcanWidth = sw * trashcanWidthPercentage;
    final double trashItemSize = sh * 0.30;

    final double dynamicBottomOffset = _introStep == 5
        ? -sh * 0.15
        : trashcanIntroBottomOffset;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Base Background Image
          Image.asset(
            'assets/images/backgrounds/bg_park_sunny.png',
            fit: BoxFit.cover,
          ),

          // 2. Low Opacity White Overlay
          Container(color: Colors.white.withOpacity(backgroundWhiteOpacity)),

          // 3. The Animated Trashcans Container
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            bottom: dynamicBottomOffset,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _walkCtrl,
              builder: (context, child) {
                final double t = _walkCtrl.value;
                final double easedT = Curves.easeOutCubic.transform(t);
                final double dx = sw * (1 - easedT);
                final int stepCount = 8;
                final double walkBounce = t < 1.0
                    ? (math.sin(t * stepCount * math.pi)).abs() *
                          walkBounceHeight
                    : 0.0;

                return Transform.translate(
                  offset: Offset(dx, -walkBounce),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildTrashcan(
                    'assets/images/objects/lumi/trashcan1_happy.png',
                    'assets/images/objects/lumi/trashcan1_sad.png',
                    trashcanWidth,
                    2,
                    1,
                  ),
                  SizedBox(width: spacingBetweenCans),
                  _buildTrashcan(
                    'assets/images/objects/lumi/trashcan2_happy.png',
                    'assets/images/objects/lumi/trashcan2_sad.png',
                    trashcanWidth,
                    3,
                    2,
                  ),
                  SizedBox(width: spacingBetweenCans),
                  _buildTrashcan(
                    'assets/images/objects/lumi/trashcan3_happy.png',
                    'assets/images/objects/lumi/trashcan3_sad.png',
                    trashcanWidth,
                    4,
                    3,
                  ),
                ],
              ),
            ),
          ),

          // 4. Dr. Woo Intro Overlay
          if (_introStep == 1)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(darkOverlayOpacity),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: Offset(0, drWooVerticalOffset),
                    child: Image.asset(
                      'assets/images/characters/dr.woo_the_owl.png',
                      height: sh * drWooHeightPercentage,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

          // 5. The Draggable Trash Item (Hidden while fading to prevent snapping back)
          if (_introStep == 5 &&
              _currentTrash != null &&
              !_isGameWon &&
              !_isTrashFading)
            Positioned(
              top: sh * 0.08,
              left: (sw / 2) - (trashItemSize / 2),
              child: Draggable<TrashItem>(
                data: _currentTrash,
                feedback: Material(
                  color: Colors.transparent,
                  child: Image.asset(
                    _currentTrash!.imagePath,
                    width: trashItemSize * 1.2,
                    height: trashItemSize * 1.2,
                    fit: BoxFit.contain,
                  ),
                ),
                childWhenDragging: SizedBox(
                  width: trashItemSize,
                  height: trashItemSize,
                ),
                child: Image.asset(
                  _currentTrash!.imagePath,
                  width: trashItemSize,
                  height: trashItemSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // 6. The Fading "Ghost" Trash (Spawns exactly where dropped!)
          if (_fadingTrash != null && _droppedPosition != null)
            Positioned(
              left: _droppedPosition!.dx,
              top: _droppedPosition!.dy,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1.0, end: 0.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves
                    .easeInBack, // Shrinks down with a slight bounce effect
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  _fadingTrash!.imagePath,
                  // Uses the 1.2 multiplier to match the size it was while being dragged!
                  width: trashItemSize * 1.2,
                  height: trashItemSize * 1.2,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // 7. Good Job Overlay
          if (_isGameWon)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/dr.woo_the_owl.png',
                
                onNext: () async {
                  await TownProgressService.instance.markLevelComplete(11);

                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const AppreciationGame(),
                      ),
                      (route) => route.isFirst,
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    _isGameWon = false;
                    _initTrashItems();
                  });
                },
                onBack: () => Navigator.of(context).pop(),
              ),
            ),

          // 8. Universal Back Button
          const Positioned(top: 25, left: 20, child: LumiBackButton()),
        ],
      ),
    );
  }
}
