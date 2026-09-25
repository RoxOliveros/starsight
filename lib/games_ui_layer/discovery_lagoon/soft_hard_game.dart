import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/feed_the_animal.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../goodjob_prompt.dart';
import 'kiki_reaction.dart';
import 'lagoon_game_ui.dart';

class SortableItem {
  final String imagePath;
  final bool isSoft;

  SortableItem({required this.imagePath, required this.isSoft});
}

class SoftHardGameScreen extends StatefulWidget {
  final int level;

  const SoftHardGameScreen({super.key, required this.level});

  @override
  State<SoftHardGameScreen> createState() => _SoftHardGameScreenState();
}

class _SoftHardGameScreenState extends State<SoftHardGameScreen>
    with TickerProviderStateMixin, KikiReactionMixin, AiCameraMixin {
  late final AudioPlayer _audioPlayer;
  final Random _random = Random();
  final AudioPlayer _kikiPlayer = AudioPlayer();
  final GameTapTracker _tapTracker = GameTapTracker();

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  bool _isIntroPlaying = true;
  bool _hasPlayedInstruction = false;

  late List<SortableItem> _remainingItems;
  SortableItem? _currentItem;

  final List<SortableItem> _sortedSoftItems = [];
  final List<SortableItem> _sortedHardItems = [];

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  bool _isGameWon = false;
  bool _showVictoryOverlay = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  static const String _bgImage = 'assets/images/backgrounds/bg_rainbow_lagoon.png';
  static const String _softCloudImage = 'assets/images/objects/lagoon/soft_cloud.png';
  static const String _hardRockImage = 'assets/images/objects/lagoon/hard_rock.png';
  static const String _kikiImage = 'assets/images/characters/kiki_the_cat.png';
  static const String _goodJobImage = 'assets/images/characters/cat_holding_fishbone.png';

  static const String _pillowImage = 'assets/images/objects/lagoon/pillow.png';
  static const String _cushionImage = 'assets/images/objects/lagoon/cushion.png';
  static const String _towelImage = 'assets/images/objects/lagoon/towel.png';
  static const String _teddybearImage = 'assets/images/objects/lagoon/teddybear.png';
  static const String _yarnImage = 'assets/images/objects/lagoon/yarn_wb.png';
  static const String _yoyoImage = 'assets/images/objects/lagoon/yoyo_wb.png';
  static const String _planeImage = 'assets/images/objects/lagoon/plane_wb.png';
  static const String _trainImage = 'assets/images/objects/lagoon/train_wb.png';
  static const String _chairImage = 'assets/images/objects/lagoon/chair_wb.png';

  static const String _introAudio = 'audio/discovery_lagoon/soft&hard_intro&tutorial.wav';
  static const String _instructionAudio = 'audio/discovery_lagoon/soft&hard_instruction.wav';
  static const String _wrongAudio = 'audio/sound_effects/bubble_pop.wav';

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;

      if (_isIntroPlaying && !_hasPlayedInstruction) {
        _hasPlayedInstruction = true;
        _playInstruction();
      } else if (_isIntroPlaying) {
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

  Future<void> _playInstruction() async {
    try {
      await _audioPlayer.play(AssetSource(_instructionAudio));
    } catch (e) {
      debugPrint("Error playing instruction audio: $e");
      if (mounted) {
        setState(() => _isIntroPlaying = false);
      }
    }
  }

  void _initGame() {
    _remainingItems = [
      SortableItem(imagePath: _pillowImage, isSoft: true),
      SortableItem(imagePath: _cushionImage, isSoft: true),
      SortableItem(imagePath: _towelImage, isSoft: true),
      SortableItem(imagePath: _teddybearImage, isSoft: true),
      SortableItem(imagePath: _yarnImage, isSoft: true),
      SortableItem(imagePath: _yoyoImage, isSoft: false),
      SortableItem(imagePath: _planeImage, isSoft: false),
      SortableItem(imagePath: _trainImage, isSoft: false),
      SortableItem(imagePath: _chairImage, isSoft: false),
    ];

    _sortedSoftItems.clear();
    _sortedHardItems.clear();
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
        LagoonProgressService.instance.markLevelComplete(widget.level);
        _triggerVictoryOverlay();
      }
    });
  }

  void _triggerVictoryOverlay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isGameWon) {
        _saveDataAndShowGoodJob();
      }
    });
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    LagoonDatabaseService.saveGameData(
      gameId: 'lagoon_soft_hard',
      activityName: 'Soft & Hard Game',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    if (mounted) {
      setState(() => _showVictoryOverlay = true);
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

    if (_currentItem!.isSoft && droppedOnLeft) {
      _tapTracker.recordCorrectTap();
      showKikiReaction(KikiState.correct);
      setState(() {
        _sortedSoftItems.add(_currentItem!);
      });
      _loadNextItem();
    } else if (!_currentItem!.isSoft && droppedOnRight) {
      _tapTracker.recordCorrectTap();
      showKikiReaction(KikiState.correct);
      setState(() {
        _sortedHardItems.add(_currentItem!);
      });
      _loadNextItem();
    } else if (droppedOnLeft || droppedOnRight) {
      _tapTracker.recordMistake();
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
    disposeAiCamera();
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
          Image.asset(_bgImage, fit: BoxFit.cover),

          Positioned(
            top: sh * 0.03,
            left: sw * 0.5 - (sw * 0.34),
            child: Image.asset(
              _softCloudImage,
              height: sw * 0.11,
              fit: BoxFit.contain,
            ),
          ),

          Positioned(
            top: sh * 0.03,
            right: sw * 0.5 - (sw * 0.34),
            child: Image.asset(
              _hardRockImage,
              height: sw * 0.11,
              fit: BoxFit.contain,
            ),
          ),

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
                    width: sh * 0.28,
                    height: sh * 0.28,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            ),
          ),

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
                    width: sh * 0.28,
                    height: sh * 0.28,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            ),
          ),

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
                    child: Image.asset(
                      _kikiImage,
                      height: sh * 1,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (_showVictoryOverlay)
            GoodJobOverlay(
              characterImage: _goodJobImage,
              characterSizeFactor: 0.9,
              onNext: () async {
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FeedTheAnimalGame(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: () {
                setState(() {
                  _isGameWon = false;
                  _showVictoryOverlay = false;
                  _hasSavedResult = false;
                  _tapTracker.startSession();
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

  _DashedLinePainter({this.topPadding = 0, this.bottomPadding = 0});

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
