import 'dart:async';
import 'package:StarSight/games_ui_layer/lumi_town/lvl9/sorry_8.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

class Sorry7Screen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;

  const Sorry7Screen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
  });

  @override
  State<Sorry7Screen> createState() => _Sorry7ScreenState();
}

class _Sorry7ScreenState extends State<Sorry7Screen>
    with AiCameraMixin<Sorry7Screen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _currentPhase = 1;
  bool _canDrag = true;

  bool _kinuhaKoPlaced = false;
  bool _angPlaced = false;
  bool _laruanMoPlaced = false;

  bool _hindiPlaced = false;
  bool _koNaPlaced = false;
  bool _uulitinPlaced = false;

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
  }

  void _checkCompletion() {
    if (_currentPhase == 1) {
      if (_kinuhaKoPlaced && _angPlaced && _laruanMoPlaced) {
        debugPrint('Phase 1 Complete: KINUHA KO ANG LARUAN MO!');
        _playPhase1CompleteSequence();
      }
    } else if (_currentPhase == 2) {
      if (_hindiPlaced && _koNaPlaced && _uulitinPlaced) {
        debugPrint('Phase 2 Complete: HINDI KO NA UULITIN!');
        _playFinalVictorySequence();
      }
    }
  }

  Future<void> _playPhase1CompleteSequence() async {
    try {
      setState(() => _canDrag = false);
      await _audioPlayer.stop();

      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      setState(() {
        _currentPhase = 2;
        _canDrag = true;
      });
    } catch (e) {
      debugPrint('Error in Phase 1 transition: $e');
      if (mounted) {
        setState(() {
          _currentPhase = 2;
          _canDrag = true;
        });
      }
    }
  }

  Future<void> _playFinalVictorySequence() async {
    try {
      setState(() => _canDrag = false);
      await _audioPlayer.stop();

      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      await _audioPlayer.play(
        AssetSource('audio/lumi_town/level9/sorry_8.wav'),
      );
      await _audioPlayer.onPlayerComplete.first;
      if (!mounted) return;

      final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Sorry8Screen(
            priorEmotions: emotionsSoFar,
            tapTracker: widget.tapTracker,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in final victory sequence: $e');
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

    final double pieceWidth = sw * 0.16;
    final double pieceHeight = pieceWidth;

    final double row2WidthExpansion = pieceWidth * 0.08;
    final double row2PieceWidth = pieceWidth + row2WidthExpansion;

    final double puzzleTopPosition = _currentPhase == 1 ? sh * 0.18 : sh * 0.05;

    final double verticalOverlap = pieceHeight * 0.52;
    final double row2TopOffset = pieceHeight - verticalOverlap;

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

            AnimatedPositioned(
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOutBack,
              top: puzzleTopPosition,
              left: 0,
              right: 0,
              child: Builder(
                builder: (context) {
                  final double horizontalOverlap = pieceWidth * 0.42;
                  final double step = pieceWidth - horizontalOverlap;
                  final double totalWidth = pieceWidth + step * 2;
                  final double totalHeight = pieceHeight + row2TopOffset;

                  return Center(
                    child: SizedBox(
                      width: totalWidth,
                      height: totalHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: SizedBox(
                              width: totalWidth,
                              height: pieceHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0 - (pieceWidth * 0.03),
                                    top: 0,
                                    child: _buildDragTarget(
                                      id: 'KINUHA_KO',
                                      isPlaced: _kinuhaKoPlaced,
                                      placeholderAsset:
                                          'assets/images/objects/lumi/kinuhako_placeholder.png',
                                      placedAsset:
                                          'assets/images/objects/lumi/kinuhako_rp.png',
                                      width: pieceWidth,
                                      height: pieceHeight,
                                      onAccept: () => setState(() {
                                        _kinuhaKoPlaced = true;
                                        _checkCompletion();
                                      }),
                                    ),
                                  ),
                                  Positioned(
                                    left: (step * 2) + (pieceWidth * 0.03),
                                    top: 0,
                                    child: _buildDragTarget(
                                      id: 'LARUAN_MO',
                                      isPlaced: _laruanMoPlaced,
                                      placeholderAsset:
                                          'assets/images/objects/lumi/laruanmo_placeholder.png',
                                      placedAsset:
                                          'assets/images/objects/lumi/laruanmo_rp.png',
                                      width: pieceWidth,
                                      height: pieceHeight,
                                      onAccept: () => setState(() {
                                        _laruanMoPlaced = true;
                                        _checkCompletion();
                                      }),
                                    ),
                                  ),
                                  Positioned(
                                    left: step,
                                    top: 0,
                                    child: _buildDragTarget(
                                      id: 'ANG',
                                      isPlaced: _angPlaced,
                                      placeholderAsset:
                                          'assets/images/objects/lumi/ang_placeholder.png',
                                      placedAsset:
                                          'assets/images/objects/lumi/ang_rp.png',
                                      width: pieceWidth,
                                      height: pieceHeight,
                                      onAccept: () => setState(() {
                                        _angPlaced = true;
                                        _checkCompletion();
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            top: row2TopOffset,
                            left: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 450),
                              opacity: _currentPhase == 2 ? 1.0 : 0.0,
                              child: IgnorePointer(
                                ignoring: _currentPhase == 1,
                                child: SizedBox(
                                  width: totalWidth,
                                  height: pieceHeight,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 0 - (pieceWidth * 0.025),
                                        top: -1,
                                        child: _buildDragTarget(
                                          id: 'HINDI',
                                          isPlaced: _hindiPlaced,
                                          placeholderAsset:
                                              'assets/images/objects/lumi/hindi_placeholder.png',
                                          placedAsset:
                                              'assets/images/objects/lumi/hindi_rp.png',
                                          width: row2PieceWidth,
                                          height: pieceHeight,
                                          onAccept: () => setState(() {
                                            _hindiPlaced = true;
                                            _checkCompletion();
                                          }),
                                        ),
                                      ),

                                      Positioned(
                                        left:
                                            ((step * 2) +
                                                (pieceWidth * 0.015)) -
                                            row2WidthExpansion,
                                        top: 0,
                                        child: _buildDragTarget(
                                          id: 'UULITIN',
                                          isPlaced: _uulitinPlaced,
                                          placeholderAsset:
                                              'assets/images/objects/lumi/uulitin_placeholder.png',
                                          placedAsset:
                                              'assets/images/objects/lumi/uulitin_rp.png',
                                          width: row2PieceWidth,
                                          height: pieceHeight,
                                          onAccept: () => setState(() {
                                            _uulitinPlaced = true;
                                            _checkCompletion();
                                          }),
                                        ),
                                      ),

                                      Positioned(
                                        left: step - (row2WidthExpansion / 2),
                                        top: 0,
                                        child: _buildDragTarget(
                                          id: 'KO_NA',
                                          isPlaced: _koNaPlaced,
                                          placeholderAsset:
                                              'assets/images/objects/lumi/kona_placeholder.png',
                                          placedAsset:
                                              'assets/images/objects/lumi/kona_rp.png',
                                          width: row2PieceWidth,
                                          height: pieceHeight,
                                          onAccept: () => setState(() {
                                            _koNaPlaced = true;
                                            _checkCompletion();
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
              bottom: sh * 0.05,
              left: 0,
              right: 0,
              child: Center(
                child: _currentPhase == 1
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDraggablePiece(
                            id: 'LARUAN_MO',
                            isPlaced: _laruanMoPlaced,
                            assetPath:
                                'assets/images/objects/lumi/laruanmo_rp.png',
                            width: pieceWidth,
                            height: pieceHeight,
                          ),
                          SizedBox(width: pieceWidth * 0.15),
                          _buildDraggablePiece(
                            id: 'KINUHA_KO',
                            isPlaced: _kinuhaKoPlaced,
                            assetPath:
                                'assets/images/objects/lumi/kinuhako_rp.png',
                            width: pieceWidth,
                            height: pieceHeight,
                          ),
                          SizedBox(width: pieceWidth * 0.15),
                          _buildDraggablePiece(
                            id: 'ANG',
                            isPlaced: _angPlaced,
                            assetPath: 'assets/images/objects/lumi/ang_rp.png',
                            width: pieceWidth,
                            height: pieceHeight,
                          ),
                          SizedBox(width: pieceWidth * 0.15),
                          _buildDraggablePiece(
                            id: 'PANGIT_KA',
                            isPlaced: false,
                            assetPath:
                                'assets/images/objects/lumi/pangitka_wp.png',
                            width: pieceWidth,
                            height: pieceHeight,
                          ),
                        ],
                      )
                    : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDraggablePiece(
                                id: 'KO_NA',
                                isPlaced: _koNaPlaced,
                                assetPath:
                                    'assets/images/objects/lumi/kona_rp.png',
                                width: row2PieceWidth,
                                height: pieceHeight,
                              ),
                              SizedBox(width: pieceWidth * 0.10),
                              _buildDraggablePiece(
                                id: 'IBABALIK',
                                isPlaced: false,
                                assetPath:
                                    'assets/images/objects/lumi/ibabalik_wp.png',
                                width: row2PieceWidth,
                                height: pieceHeight,
                              ),
                              SizedBox(width: pieceWidth * 0.10),
                              _buildDraggablePiece(
                                id: 'UULITIN',
                                isPlaced: _uulitinPlaced,
                                assetPath:
                                    'assets/images/objects/lumi/uulitin_rp.png',
                                width: row2PieceWidth,
                                height: pieceHeight,
                              ),
                              SizedBox(width: pieceWidth * 0.10),
                              _buildDraggablePiece(
                                id: 'HINDI',
                                isPlaced: _hindiPlaced,
                                assetPath:
                                    'assets/images/objects/lumi/hindi_rp.png',
                                width: row2PieceWidth,
                                height: pieceHeight,
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(duration: const Duration(milliseconds: 450))
                          .slideY(begin: 0.3, end: 0.0),
              ),
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),

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
            fit: BoxFit.fill,
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
      fit: BoxFit.fill,
      errorBuilder: (ctx, err, st) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: (id == 'PANGIT_KA' || id == 'IBABALIK')
              ? Colors.redAccent
              : Colors.blueAccent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            id.replaceAll('_', ' '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
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
