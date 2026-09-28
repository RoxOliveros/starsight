import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_buttons.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/town_database_service.dart';

class FamilyTreeGame extends StatefulWidget {
  const FamilyTreeGame({super.key});

  @override
  State<FamilyTreeGame> createState() => _FamilyTreeGameState();
}

class _FamilyTreeGameState extends State<FamilyTreeGame>
    with SingleTickerProviderStateMixin, AiCameraMixin<FamilyTreeGame> {
  late final AnimationController _handAnimCtrl;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  // --- GAME STATE ---
  int _gamePhase = 0;
  bool _showHand = true;
  int _currentStage = 1;
  bool _isGameWon = false;

  // Stage 1 Placements
  bool isGrandpaPlaced = false;
  bool isMotherPlaced = false;
  bool isLittleBearPlaced = false;

  // Stage 2 Placements
  bool isGrandmaPlaced = false;
  bool isFatherPlaced = false;
  bool isSisterPlaced = false;
  bool isBrotherPlaced = false;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _handAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;

      if (_gamePhase < 2) {
        setState(() {
          _gamePhase = 2;
        });

        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showHand = false;
            });
          }
        });
      }
    });

    _playAudio('audio/lumi_town/level13/family_tree_game_intro.wav');

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _gamePhase == 0) {
        setState(() {
          _gamePhase = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    disposeAiCamera();
    _handAnimCtrl.dispose();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _playShineSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/sound_effects/shine.wav'));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint("Error playing audio ($path): $e");
    }
  }

  void _checkWinCondition() {
    if (_currentStage == 1 &&
        isGrandpaPlaced &&
        isMotherPlaced &&
        isLittleBearPlaced) {
      setState(() {
        _currentStage = 2;
      });
    } else if (_currentStage == 2 &&
        isGrandmaPlaced &&
        isFatherPlaced &&
        isSisterPlaced &&
        isBrotherPlaced) {
      debugPrint("Family Tree Fully Complete!");
      _saveDataAndShowGoodJob();
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    final finalEmotions = stopAiCamera();

    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_family_tree',
      activityName: 'Family Tree',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    TownProgressService.instance.markLevelComplete(13).catchError((e) {
      debugPrint("Database Error marking level complete: $e");
    });

    if (mounted) {
      setState(() {
        _isGameWon = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _tapTracker.recordGenericTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _gamePhase < 2
                  ? 'assets/images/backgrounds/bg_classroom_closeup.png'
                  : 'assets/images/backgrounds/bg_table.png',
              fit: BoxFit.cover,
            ),

            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sw = constraints.maxWidth;
                    final sh = constraints.maxHeight;

                    final double introBearWidth = 0.35;
                    final double introBearX = 0.325;
                    final double introBearBottom = -0.15;

                    final double introTreeWidth = 0.28;
                    final double introTreeX = 0.03;
                    final double introTreeBottom = 0.10;

                    final double treeWidth = 0.50;
                    final double treeX = 0.25;
                    final double treeY = 0.00;

                    final double holderWidth = 0.09;

                    final double h1X = 0.38;
                    final double h1Y = 0.18;

                    final double h2X = 0.51;
                    final double h2Y = 0.18;

                    final double h3X = 0.34;
                    final double h3Y = 0.35;

                    final double h4X = 0.56;
                    final double h4Y = 0.35;

                    final double h5X = 0.35;
                    final double h5Y = 0.55;

                    final double h6X = 0.45;
                    final double h6Y = 0.50;

                    final double h7X = 0.55;
                    final double h7Y = 0.55;

                    final double handWidth = 0.08;
                    final double handX = 0.43;
                    final double handY = 0.08;
                    final double handAngle = math.pi * 1.2;
                    final double handBounceX = -10.0;
                    final double handBounceY = 10.0;

                    final double grandpaPicWidth = 0.20;
                    final double grandpaPicX = 0.78;
                    final double grandpaPicY = 0.20;

                    final double motherPicWidth = 0.20;
                    final double motherPicX = 0.03;
                    final double motherPicY = 0.20;

                    final double littleBearPicWidth = 0.20;
                    final double littleBearPicX = 0.05;
                    final double littleBearPicY = 0.60;

                    final double grandmaPicWidth = 0.20;
                    final double grandmaPicX = 0.03;
                    final double grandmaPicY = 0.20;

                    final double daddyPicWidth = 0.20;
                    final double daddyPicX = 0.78;
                    final double daddyPicY = 0.20;

                    final double sisterPicWidth = 0.20;
                    final double sisterPicX = 0.05;
                    final double sisterPicY = 0.60;

                    final double brotherPicWidth = 0.20;
                    final double brotherPicX = 0.78;
                    final double brotherPicY = 0.60;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_gamePhase < 2) ...[
                          Positioned(
                            left: sw * introBearX,
                            bottom: sh * introBearBottom,
                            child: Image.asset(
                              'assets/images/characters/little_bear_uniform.png',
                              width: sw * introBearWidth,
                              fit: BoxFit.contain,
                            ),
                          ),
                          if (_gamePhase == 1)
                            Positioned(
                              left: sw * introTreeX,
                              bottom: sh * introTreeBottom,
                              child: Image.asset(
                                'assets/images/objects/lumi/familytree_sample.png',
                                width: sw * introTreeWidth,
                                fit: BoxFit.contain,
                              ),
                            ),
                        ] else ...[
                          Positioned(
                            top: sh * treeY,
                            left: sw * treeX,
                            child: Image.asset(
                              'assets/images/objects/lumi/familytree.png',
                              width: sw * treeWidth,
                              fit: BoxFit.contain,
                            ),
                          ),

                          Positioned(
                            top: sh * h1Y,
                            left: sw * h1X,
                            child: _buildCircleTarget(
                              expectedId: 'grandpa',
                              isPlaced: isGrandpaPlaced,
                              placedAssetPath:
                                  'assets/images/objects/lumi/grandpa_pfp.png',
                              width: sw * holderWidth,
                              onPlaced: () {
                                setState(() => isGrandpaPlaced = true);
                                _checkWinCondition();
                              },
                            ),
                          ),

                          Positioned(
                            top: sh * h2Y,
                            left: sw * h2X,
                            child: _buildCircleTarget(
                              expectedId: 'grandma',
                              isPlaced: isGrandmaPlaced,
                              placedAssetPath:
                                  'assets/images/objects/lumi/grandma_pfp.png',
                              width: sw * holderWidth,
                              onPlaced: () {
                                setState(() => isGrandmaPlaced = true);
                                _checkWinCondition();
                              },
                            ),
                          ),

                          Positioned(
                            top: sh * h3Y,
                            left: sw * h3X,
                            child: _buildCircleTarget(
                              expectedId: 'father',
                              isPlaced: isFatherPlaced,
                              placedAssetPath:
                                  'assets/images/objects/lumi/father_pfp.png',
                              width: sw * holderWidth,
                              onPlaced: () {
                                setState(() => isFatherPlaced = true);
                                _checkWinCondition();
                              },
                            ),
                          ),

                          Positioned(
                            top: sh * h4Y,
                            left: sw * h4X,
                            child: _buildCircleTarget(
                              expectedId: 'mother',
                              isPlaced: isMotherPlaced,
                              placedAssetPath:
                                  'assets/images/objects/lumi/mother_pfp.png',
                              width: sw * holderWidth,
                              onPlaced: () {
                                setState(() => isMotherPlaced = true);
                                _checkWinCondition();
                              },
                            ),
                          ),

                          Positioned(
                            top: sh * h5Y,
                            left: sw * h5X,
                            child: _buildCircleTarget(
                              expectedId: 'sister',
                              isPlaced: isSisterPlaced,
                              placedAssetPath:
                                  'assets/images/objects/lumi/sister_pfp.png',
                              width: sw * holderWidth,
                              onPlaced: () {
                                setState(() => isSisterPlaced = true);
                                _checkWinCondition();
                              },
                            ),
                          ),

                          Positioned(
                            top: sh * h6Y,
                            left: sw * h6X,
                            child: _buildCircleTarget(
                              expectedId: 'little_bear',
                              isPlaced: isLittleBearPlaced,
                              placedAssetPath:
                                  'assets/images/objects/lumi/littllebear_pfp.png',
                              width: sw * holderWidth,
                              onPlaced: () {
                                setState(() => isLittleBearPlaced = true);
                                _checkWinCondition();
                              },
                            ),
                          ),

                          Positioned(
                            top: sh * h7Y,
                            left: sw * h7X,
                            child: _buildCircleTarget(
                              expectedId: 'brother',
                              isPlaced: isBrotherPlaced,
                              placedAssetPath:
                                  'assets/images/objects/lumi/brother_pfp.png',
                              width: sw * holderWidth,
                              onPlaced: () {
                                setState(() => isBrotherPlaced = true);
                                _checkWinCondition();
                              },
                            ),
                          ),

                          if (_showHand)
                            Positioned(
                              top: sh * handY,
                              left: sw * handX,
                              child: AnimatedBuilder(
                                animation: _handAnimCtrl,
                                builder: (context, child) {
                                  final double curve = Curves.easeInOut
                                      .transform(_handAnimCtrl.value);
                                  return Transform.translate(
                                    offset: Offset(
                                      curve * handBounceX,
                                      curve * handBounceY,
                                    ),
                                    child: child,
                                  );
                                },
                                child: Transform.rotate(
                                  angle: handAngle,
                                  child: Image.asset(
                                    'assets/images/objects/lumi/pointing_hand.png',
                                    width: sw * handWidth,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),

                          if (_currentStage == 1) ...[
                            Positioned(
                              top: sh * grandpaPicY,
                              left: sw * grandpaPicX,
                              child: _buildDraggablePic(
                                id: 'grandpa',
                                assetPath:
                                    'assets/images/objects/lumi/grandpa_bear_pic.png',
                                width: sw * grandpaPicWidth,
                                isPlaced: isGrandpaPlaced,
                              ),
                            ),
                            Positioned(
                              top: sh * motherPicY,
                              left: sw * motherPicX,
                              child: _buildDraggablePic(
                                id: 'mother',
                                assetPath:
                                    'assets/images/objects/lumi/mother_bear_pic.png',
                                width: sw * motherPicWidth,
                                isPlaced: isMotherPlaced,
                              ),
                            ),
                            Positioned(
                              top: sh * littleBearPicY,
                              left: sw * littleBearPicX,
                              child: _buildDraggablePic(
                                id: 'little_bear',
                                assetPath:
                                    'assets/images/objects/lumi/little_bear_pic.png',
                                width: sw * littleBearPicWidth,
                                isPlaced: isLittleBearPlaced,
                              ),
                            ),
                          ],

                          if (_currentStage == 2) ...[
                            Positioned(
                              top: sh * grandmaPicY,
                              left: sw * grandmaPicX,
                              child: _buildDraggablePic(
                                id: 'grandma',
                                assetPath:
                                    'assets/images/objects/lumi/grandma_bear_pic.png',
                                width: sw * grandmaPicWidth,
                                isPlaced: isGrandmaPlaced,
                              ),
                            ),
                            Positioned(
                              top: sh * daddyPicY,
                              left: sw * daddyPicX,
                              child: _buildDraggablePic(
                                id: 'father',
                                assetPath:
                                    'assets/images/objects/lumi/daddy_bear_pic.png',
                                width: sw * daddyPicWidth,
                                isPlaced: isFatherPlaced,
                              ),
                            ),
                            Positioned(
                              top: sh * sisterPicY,
                              left: sw * sisterPicX,
                              child: _buildDraggablePic(
                                id: 'sister',
                                assetPath:
                                    'assets/images/objects/lumi/sister_bear_pic.png',
                                width: sw * sisterPicWidth,
                                isPlaced: isSisterPlaced,
                              ),
                            ),
                            Positioned(
                              top: sh * brotherPicY,
                              left: sw * brotherPicX,
                              child: _buildDraggablePic(
                                id: 'brother',
                                assetPath:
                                    'assets/images/objects/lumi/brother_bear_pic.png',
                                width: sw * brotherPicWidth,
                                isPlaced: isBrotherPlaced,
                              ),
                            ),
                          ],
                        ],
                      ],
                    );
                  },
                ),
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

            if (_isGameWon)
              Positioned.fill(
                child: GoodJobOverlay(
                  characterImage: 'assets/images/characters/tr.woo_smiling.png',
                  onNext: () {},
                  onRestart: () {
                    setState(() {
                      _hasSavedResult = false;
                      _tapTracker.startSession();

                      _gamePhase = 0;
                      _showHand = true;
                      _currentStage = 1;
                      _isGameWon = false;

                      isGrandpaPlaced = false;
                      isMotherPlaced = false;
                      isLittleBearPlaced = false;
                      isGrandmaPlaced = false;
                      isFatherPlaced = false;
                      isSisterPlaced = false;
                      isBrotherPlaced = false;

                      _handAnimCtrl.reset();
                      _handAnimCtrl.repeat(reverse: true);
                      _playAudio(
                        'audio/lumi_town/level13/family_tree_game_intro.wav',
                      );

                      Future.delayed(const Duration(seconds: 6), () {
                        if (mounted && _gamePhase == 0) {
                          setState(() {
                            _gamePhase = 1;
                          });
                        }
                      });
                    });
                  },
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleTarget({
    required String expectedId,
    required bool isPlaced,
    required String placedAssetPath,
    required double width,
    required VoidCallback onPlaced,
  }) {
    return DragTarget<String>(
      builder: (context, candidateData, rejectedData) {
        return Image.asset(
          isPlaced
              ? placedAssetPath
              : 'assets/images/objects/lumi/picture_holder.png',
          width: width,
          fit: BoxFit.contain,
        );
      },
      onWillAcceptWithDetails: (details) =>
          details.data == expectedId && !isPlaced,
      onAcceptWithDetails: (details) {
        _tapTracker.recordCorrectTap();
        _playShineSound();
        onPlaced();
      },
    );
  }

  Widget _buildDraggablePic({
    required String id,
    required String assetPath,
    required double width,
    required bool isPlaced,
  }) {
    if (isPlaced) {
      return const SizedBox.shrink();
    }

    return Draggable<String>(
      data: id,
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          _tapTracker.recordMistake();
        }
      },
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(assetPath, width: width * 1.1, fit: BoxFit.contain),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Image.asset(assetPath, width: width, fit: BoxFit.contain),
      ),
      child: Image.asset(assetPath, width: width, fit: BoxFit.contain),
    );
  }
}
