import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_6.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

import '../lumi_game_ui_layer.dart';

class Sorry5Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Sorry5Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Sorry5Screen> createState() => _Sorry5ScreenState();
}

class _Sorry5ScreenState extends State<Sorry5Screen>
    with AiCameraMixin<Sorry5Screen>, AppAudioLifecycleMixin<Sorry5Screen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  bool _canDrag = false;

  bool _imPlaced = false;
  bool _sorryPlaced = false;
  bool _littleBearPlaced = false;

  bool _hideLightingCard = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startIntroAudio();
    });
  }

  Future<void> _startIntroAudio() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_5.wav'),
      );

      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      setState(() {
        _canDrag = true;
      });
    } catch (e) {
      debugPrint('Error playing sorry_5.wav: $e');
      if (mounted) setState(() => _canDrag = true);
    }
  }

  void _checkCompletion() {
    if (_imPlaced && _sorryPlaced && _littleBearPlaced) {
      debugPrint('Puzzle Complete!');
      _playVictorySequence();
    }
  }

  Future<void> _playVictorySequence() async {
    try {
      await _audioPlayer.stop();

      await _audioPlayer.play(AssetSource('audio/sound_effects/sfx_shine.wav'));
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_6.wav'),
      );
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Sorry6Screen(
            priorEmotions: emotionsSoFar,
            tapTracker: widget.tapTracker,
            level: widget.level,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in victory sequence: $e');
    }
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final double pieceWidth = sw * 0.18;
    final double pieceHeight = pieceWidth;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/bg_lumi_puzzle.jpg',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFBE4C3),
                      Color(0xFFFBE4C3),
                      Color(0xFFECA352),
                      Color(0xFFECA352),
                    ],
                    stops: [0.0, 0.60, 0.60, 1.0],
                  ),
                ),
              ),
            ),

            Positioned(
              top: sh * 0.15,
              left: 0,
              right: 0,
              child: Builder(
                builder: (context) {
                  final double overlapAmount = pieceWidth * 0.26;
                  final double step = pieceWidth - overlapAmount;
                  final double totalWidth = pieceWidth + step * 2;

                  return Center(
                    child: SizedBox(
                      width: totalWidth,
                      height: pieceHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: _buildDragTarget(
                              id: 'IM',
                              isPlaced: _imPlaced,
                              placeholderAsset:
                                  'assets/images/objects/lumi/im_placeholder.png',
                              placedAsset:
                                  'assets/images/objects/lumi/im_rp.png',
                              width: pieceWidth,
                              height: pieceHeight,
                              onAccept: () => setState(() {
                                _imPlaced = true;
                                _checkCompletion();
                              }),
                            ),
                          ),

                          Positioned(
                            left: step,
                            top: 0,
                            child: _buildDragTarget(
                              id: 'SORRY',
                              isPlaced: _sorryPlaced,
                              placeholderAsset:
                                  'assets/images/objects/lumi/sorry_placeholder.png',
                              placedAsset:
                                  'assets/images/objects/lumi/sorry_rp.png',
                              width: pieceWidth,
                              height: pieceHeight,
                              onAccept: () => setState(() {
                                _sorryPlaced = true;
                                _checkCompletion();
                              }),
                            ),
                          ),

                          Positioned(
                            left: (step * 2) - (pieceWidth * 0.05),
                            top: 0,
                            child: _buildDragTarget(
                              id: 'LITTLE_BEAR',
                              isPlaced: _littleBearPlaced,
                              placeholderAsset:
                                  'assets/images/objects/lumi/littlebear_placeholder.png',
                              placedAsset:
                                  'assets/images/objects/lumi/littlebear_rp.png',
                              width: pieceWidth,
                              height: pieceHeight,
                              onAccept: () => setState(() {
                                _littleBearPlaced = true;
                                _checkCompletion();
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Positioned(
              bottom: sh * 0.08,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDraggablePiece(
                      id: 'IM',
                      isPlaced: _imPlaced,
                      assetPath: 'assets/images/objects/lumi/im_rp.png',
                      width: pieceWidth,
                      height: pieceHeight,
                    ),

                    SizedBox(width: pieceWidth * 0.35),

                    _buildDraggablePiece(
                      id: 'SORRY',
                      isPlaced: _sorryPlaced,
                      assetPath: 'assets/images/objects/lumi/sorry_rp.png',
                      width: pieceWidth,
                      height: pieceHeight,
                    ),

                    SizedBox(width: pieceWidth * 0.35),

                    _buildDraggablePiece(
                      id: 'LITTLE_BEAR',
                      isPlaced: _littleBearPlaced,
                      assetPath: 'assets/images/objects/lumi/littlebear_rp.png',
                      width: pieceWidth,
                      height: pieceHeight,
                    ),
                  ],
                ),
              ),
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LumiLevelBadge(level: widget.level),
            ),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragTarget({
    required String id,
    required bool isPlaced,
    required String placeholderAsset,
    required String placedAsset,
    required double width,
    required double height,
    required VoidCallback onAccept,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data == id && !isPlaced,
      onAcceptWithDetails: (details) {
        widget.tapTracker.recordCorrectTap();
        onAccept();
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Image.asset(
            isPlaced ? placedAsset : placeholderAsset,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) => Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isPlaced
                    ? Colors.orange
                    : Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  isPlaced ? id : '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggablePiece({
    required String id,
    required bool isPlaced,
    required String assetPath,
    required double width,
    required double height,
  }) {
    if (isPlaced) {
      return SizedBox(width: width, height: height);
    }

    final Widget pieceImage = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, st) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            id,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

    if (!_canDrag) {
      return Opacity(opacity: 0.65, child: pieceImage);
    }

    return Draggable<String>(
      data: id,
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          widget.tapTracker.recordMistake();
        }
      },
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.10, child: pieceImage),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: pieceImage),
      child: pieceImage
          .animate(target: _canDrag ? 1 : 0)
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
          ),
    );
  }
}
