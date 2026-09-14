import 'dart:math';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/weather_tap_sort_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'kiki_reaction.dart';
import 'lagoon_game_ui.dart';

class SortableItem {
  final String imagePath;
  final bool isCold; // true = Cold side, false = Hot side

  SortableItem({required this.imagePath, required this.isCold});
}

class ColdHotGame extends StatefulWidget {
  final int level;

  const ColdHotGame({super.key, required this.level});

  @override
  State<ColdHotGame> createState() => _ColdHotGameState();
}

class _ColdHotGameState extends State<ColdHotGame>
    with TickerProviderStateMixin, KikiReactionMixin {
  late final AudioPlayer _audioPlayer;
  final Random _random = Random();

  final AudioPlayer _kikiPlayer = AudioPlayer();

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  bool _isIntroPlaying = true;
  // bool _hasPlayedInstruction = false;

  late List<SortableItem> _remainingItems;
  SortableItem? _currentItem;

  final List<SortableItem> _sortedColdItems = [];
  final List<SortableItem> _sortedHotItems = [];

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  bool _isGameWon = false;
  bool _showVictoryOverlay = false;

  // --- Asset paths ---
  static const String _bgImage = 'assets/images/backgrounds/bg_rainbow_lagoon.png';
  static const String _coldBadgeImage = 'assets/images/objects/lagoon/cold_icecube.png';
  static const String _hotBadgeImage = 'assets/images/objects/lagoon/hot_flame.png';
  static const String _kikiImage = 'assets/images/characters/kiki_the_cat.png';
  static const String _goodJobImage = 'assets/images/characters/cat_holding_fishbone.png';

  static const String _iceImage = 'assets/images/objects/lagoon/ice_wb.png';
  static const String _icecreamImage = 'assets/images/objects/lagoon/icecream_wb.png';
  static const String _snowballImage = 'assets/images/objects/lagoon/snowball_wb.png';
  static const String _snowmanImage = 'assets/images/objects/lagoon/snowman_wb.png';
  static const String _iglooImage = 'assets/images/objects/lagoon/igloo_wb.png';
  static const String _coffeeImage = 'assets/images/objects/lagoon/coffee_wb.png';
  static const String _sunImage = 'assets/images/objects/lagoon/sun_wb.png';
  static const String _candleImage = 'assets/images/objects/lagoon/candle_wb.png';
  static const String _kettleImage = 'assets/images/objects/lagoon/kettle_wb.png';

  static const String _introAudio = 'audio/discovery_lagoon/cold_hot_game_intro&tutorial.wav';
  // static const String _instructionAudio = 'audio/discovery_lagoon/cold_hot_instruction.wav';
  static const String _wrongAudio = 'audio/sound_effects/bubble_pop.wav';

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;
      //
      // if (_isIntroPlaying && !_hasPlayedInstruction) {
      //   _hasPlayedInstruction = true;
      //   _playInstruction();
      // } else if (

      if (_isIntroPlaying) {
        setState(() {
          _isIntroPlaying = false;
        });
      }
    });

    _initGame();
    _playIntro();
  }

  Future<void> _playIntro() async {
    try {
      await _audioPlayer.play(AssetSource(_introAudio));
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
      if (mounted) {
        setState(() => _isIntroPlaying = false);
      }
    }
  }

  // Future<void> _playInstruction() async {
  //   try {
  //     await _audioPlayer.play(AssetSource(_instructionAudio));
  //   } catch (e) {
  //     debugPrint("Error playing instruction audio: $e");
  //     if (mounted) {
  //       setState(() => _isIntroPlaying = false);
  //     }
  //   }
  // }

  void _initGame() {
    _remainingItems = [
      SortableItem(imagePath: _iceImage, isCold: true),
      SortableItem(imagePath: _icecreamImage, isCold: true),
      SortableItem(imagePath: _snowballImage, isCold: true),
      SortableItem(imagePath: _snowmanImage, isCold: true),
      SortableItem(imagePath: _iglooImage, isCold: true),
      SortableItem(imagePath: _coffeeImage, isCold: false),
      SortableItem(imagePath: _sunImage, isCold: false),
      SortableItem(imagePath: _candleImage, isCold: false),
      SortableItem(imagePath: _kettleImage, isCold: false),
    ];

    _sortedColdItems.clear();
    _sortedHotItems.clear();

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
        _isGameWon = true;
      }
    });

    if (_currentItem == null) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isGameWon) {
          setState(() {
            LagoonProgressService.instance.markLevelComplete(widget.level);
            _showVictoryOverlay = true;
          });
        }
      });
    }
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing audio ($assetPath): $e");
    }
  }

  Future<void> _onPanEnd(DragEndDetails details, double screenWidth) async {
    if (_currentItem == null) return;

    setState(() {
      _isDragging = false;
    });

    final double droppedX = (screenWidth / 2) + _dragOffset.dx;
    final bool droppedOnLeft = droppedX < screenWidth * 0.45;
    final bool droppedOnRight = droppedX > screenWidth * 0.55;

    if (_currentItem!.isCold && droppedOnLeft) {
      // await _playSound(_shineAudio);
      showKikiReaction(KikiState.correct);
      setState(() {
        _sortedColdItems.add(_currentItem!);
      });
      _loadNextItem();
    } else if (!_currentItem!.isCold && droppedOnRight) {
      // await _playSound(_shineAudio);
      showKikiReaction(KikiState.correct);
      setState(() {
        _sortedHotItems.add(_currentItem!);
      });
      _loadNextItem();
    } else if (droppedOnLeft || droppedOnRight) {
      await _playSound(_wrongAudio);
      showKikiReaction(KikiState.wrong);
      setState(() {
        _dragOffset = Offset.zero;
      });
    } else {
      setState(() {
        _dragOffset = Offset.zero;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _kikiPlayer.dispose();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;
    final double itemSize = sh * 0.38;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A. BACKGROUND LAYER
          Image.asset(_bgImage, fit: BoxFit.cover),

          // COLD badge (upper-left-center)
          Positioned(
            top: sh * 0.03,
            left: sw * 0.5 - (sw * 0.34),
            child: Image.asset(
              _coldBadgeImage,
              width: sw * 0.3,
              fit: BoxFit.contain,
            ),
          ),

          // HOT badge (upper-right-center)
          Positioned(
            top: sh * 0.03,
            right: sw * 0.5 - (sw * 0.34),
            child: Image.asset(
              _hotBadgeImage,
              width: sw * 0.25,
              fit: BoxFit.contain,
            ),
          ),

          // Dashed vertical separator line down the middle
          Positioned(
            top: 0,
            bottom: 0,
            left: sw / 2 - 1,
            child: CustomPaint(
              size: Size(2, sh),
              painter: _DashedLinePainter(
                topPadding: sh * 0.15,
                bottomPadding: sh * 0.08,
              ),
            ),
          ),

          // C. SORTED COLD ITEMS LAYER (Left)
          Positioned(
            left: sw * 0.03,
            top: sh * 0.32,
            width: sw * 0.42,
            height: sh * 0.65,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _sortedColdItems.map((item) {
                return AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    item.imagePath,
                    width: sh * 0.28,
                    height: sh * 0.28,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            ),
          ),

          // D. SORTED HOT ITEMS LAYER (Right)
          Positioned(
            right: sw * 0.03,
            top: sh * 0.32,
            width: sw * 0.42,
            height: sh * 0.65,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _sortedHotItems.map((item) {
                return AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    item.imagePath,
                    width: sh * 0.28,
                    height: sh * 0.28,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            ),
          ),

          // E. DRAGGABLE ITEM LAYER
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
                  scale: _isDragging ? 1.15 : 1.0,
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
                color: Colors.black.withValues(alpha: 0.5),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionalTranslation(
                    translation: const Offset(0.0, 0.2),
                    child: Image.asset(_kikiImage, height: sh * 1, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),

          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),

          // F. GOOD JOB VICTORY OVERLAY
          if (_showVictoryOverlay)
            GoodJobOverlay(
              characterImage: _goodJobImage,
              characterSizeFactor: 0.9,
              onNext: () async {
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeatherTapSortScreen(level: 19),
                    ),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  _isGameWon = false;
                  _showVictoryOverlay = false;
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

class _DashedLinePainter extends CustomPainter {
  final double topPadding;
  final double bottomPadding;

  _DashedLinePainter({
    this.topPadding = 0,
    this.bottomPadding = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF737373).withValues(alpha: 0.85)
      ..strokeWidth = 3;

    const dashHeight = 12.0;
    const dashSpace = 8.0;
    double startY = topPadding;
    final double endY = size.height - bottomPadding;

    while (startY < endY) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.topPadding != topPadding ||
          oldDelegate.bottomPadding != bottomPadding;
}