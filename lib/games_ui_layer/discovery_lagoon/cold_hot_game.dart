import 'dart:math';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

// Represents an item to be sorted
class SortableItem {
  final String imagePath;
  final bool isSoft; // true = goes Left (Soft), false = goes Right (Hard)

  SortableItem({required this.imagePath, required this.isSoft});
}

class ColdHotGame extends StatefulWidget {
  const ColdHotGame({super.key});

  @override
  State<ColdHotGame> createState() => _ColdHotGameState();
}

class _ColdHotGameState extends State<ColdHotGame>
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
        AssetSource('audio/discovery_lagoon/cold_hot_game_intro&tutorial.wav'),
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
        imagePath: 'assets/images/objects/lagoon/ice_wb.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/icecream_wb.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/snowball_wb.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/snowman_wb.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/igloo_wb.png',
        isSoft: true,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/towel.png',
        isSoft: false,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/yarn_wb.png',
        isSoft: false,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/plane_wb.png',
        isSoft: false,
      ),
      SortableItem(
        imagePath: 'assets/images/objects/lagoon/pillow.png',
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
            'assets/images/objects/lagoon/cold_hot_bg.png',
            fit: BoxFit.cover,
          ),

          // B. BACK BUTTON (Top Left)
          Positioned(
            top: 20,
            left: 20,
            child: _ImageButton(
              imagePath: 'assets/images/buttons/x_yellow.png',
              onTap: () => Navigator.of(context).pop(),
              size: 64,
              tooltip: 'Back',
            ),
          ),

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
              characterImage: 'assets/images/characters/kiki_tryagain.png',
              closeButtonColor: Colors.orange,
              onNext: () async {
                // Mark Level 5 as complete to unlock Level 6
                await LagoonProgressService.instance.markLevelComplete(5);
                if (context.mounted) {
                  // Pop back to the Level Selection Screen
                  Navigator.of(context).pop();
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

// ──────────────────────────────────────────────────────────────────────────────
// GOOD JOB OVERLAY & HELPER CLASSES (Required for victory screen!)
// ──────────────────────────────────────────────────────────────────────────────

class GoodJobOverlay extends StatefulWidget {
  final String characterImage;
  final Color closeButtonColor;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const GoodJobOverlay({
    super.key,
    required this.characterImage,
    required this.closeButtonColor,
    required this.onNext,
    required this.onRestart,
    required this.onBack,
  });

  @override
  State<GoodJobOverlay> createState() => _GoodJobOverlayState();
}

class _GoodJobOverlayState extends State<GoodJobOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late AnimationController _starsCtrl;
  late AnimationController _charBounceCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _bannerScale;
  late Animation<double> _charScale;
  late Animation<double> _charBounce;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _initAudio();
    _playYeySound();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _charBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeIn);

    _bannerScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(_entranceCtrl);

    _charScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(_entranceCtrl);

    _charBounce = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _charBounceCtrl, curve: Curves.easeInOut),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _starsCtrl.dispose();
    _charBounceCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _playYeySound() async {
    await _audioPlayer.play(AssetSource('audio/sound_effects/yey.wav'));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.45),
        child: Stack(
          children: [
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ScaleTransition(
                    scale: _bannerScale,
                    child: const _ArcedGoodJobBanner(),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _charBounceCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _charBounce.value),
                    child: child,
                  ),
                  child: ScaleTransition(
                    scale: _charScale,
                    child: _buildCharacter(),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 28,
              left: 32,
              child: _ImageButton(
                imagePath: 'assets/images/buttons/restart.png',
                onTap: widget.onRestart,
                size: 88,
                tooltip: 'Restart',
              ),
            ),

            Positioned(
              bottom: 28,
              right: 32,
              child: _ImageButton(
                imagePath: 'assets/images/buttons/next.png',
                onTap: widget.onNext,
                size: 88,
                tooltip: 'Next Level',
              ),
            ),

            Positioned(
              top: 16,
              left: 16,
              child: _CloseButton(
                onTap: widget.onBack,
                color: widget.closeButtonColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacter() {
    return Image.asset(
      widget.characterImage,
      height: 300,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.pets, size: 120, color: Colors.white),
    );
  }
}

class _ArcedGoodJobBanner extends StatelessWidget {
  const _ArcedGoodJobBanner();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/goodjob.png',
      width: 550,
      fit: BoxFit.contain,
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const _CloseButton({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

class _ImageButton extends StatefulWidget {
  final String imagePath;
  final VoidCallback onTap;
  final double size;
  final String tooltip;

  const _ImageButton({
    required this.imagePath,
    required this.onTap,
    required this.size,
    required this.tooltip,
  });

  @override
  State<_ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<_ImageButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: ScaleTransition(
          scale: _ctrl,
          child: Image.asset(
            widget.imagePath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.circle, size: widget.size, color: Colors.orange),
          ),
        ),
      ),
    );
  }
}
