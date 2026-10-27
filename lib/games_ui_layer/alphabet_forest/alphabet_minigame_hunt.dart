import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/forest_database_service.dart';
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_mail_delivery.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'alphabet_game_ui.dart';
import 'forest_game_acorn_basket.dart';
import 'forest_game_berry_bush_harvest.dart';
import 'forest_game_butterfly_flower.dart';
import 'forest_game_letter_match.dart';
import 'forest_game_mushroom_hidenseek.dart';
import 'forest_game_paw_print.dart';
import 'forest_game_stick_letter_builder.dart';
import 'forest_game_yak_zebra_race.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlphabetHuntScreen extends StatefulWidget {
  final String letter;

  const AlphabetHuntScreen({super.key, required this.letter});

  @override
  State<AlphabetHuntScreen> createState() => _AlphabetHuntScreenState();
}

class _AlphabetHuntScreenState extends State<AlphabetHuntScreen>
    with
        TofiReactionMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<AlphabetHuntScreen>,
        IdleHintMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _tofiPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _tofiPlayer];

  @override
  AudioPlayer get tofiPlayer => _tofiPlayer;

  late List<String> _letterPool;
  final List<HuntObject> _activeObjects = [];

  int _correctCount = 0;
  final int _winCondition = 4;

  final GameTapTracker _tapTracker = GameTapTracker();

  static const String _huntInstructionWav =
      'assets/audio/alphabet_forest/alphabet_minigame_hunt_instruction.wav';

  bool _inputEnabled = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

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

    _letterPool = _getPoolForLetter(widget.letter);

    _generateHuntField();
    _playInstructionThenLetter();
  }

  List<String> _getPoolForLetter(String target) {
    String upperTarget = target.toUpperCase();

    if (['A', 'B', 'C'].contains(upperTarget)) return ['A', 'B', 'C'];
    if (['D', 'E', 'F'].contains(upperTarget)) return ['D', 'E', 'F'];
    if (['G', 'H', 'I'].contains(upperTarget)) return ['G', 'H', 'I'];
    if (['J', 'K', 'L'].contains(upperTarget)) return ['J', 'K', 'L'];
    if (['M', 'N', 'O'].contains(upperTarget)) return ['M', 'N', 'O'];
    if (['P', 'Q', 'R'].contains(upperTarget)) return ['P', 'Q', 'R'];
    if (['S', 'T', 'U'].contains(upperTarget)) return ['S', 'T', 'U'];
    if (['V', 'W', 'X'].contains(upperTarget)) return ['V', 'W', 'X'];
    if (['X', 'Y', 'Z'].contains(upperTarget)) return ['X', 'Y', 'Z'];

    return ['A', 'B', 'C'];
  }

  void _generateHuntField() {
    _activeObjects.clear();

    for (int i = 0; i < _winCondition; i++) {
      _activeObjects.add(_createHuntObject(widget.letter.toUpperCase()));
    }

    List<String> distractors = _letterPool
        .where((l) => l != widget.letter.toUpperCase())
        .toList();

    for (String distractorLetter in distractors) {
      for (int i = 0; i < 2; i++) {
        _activeObjects.add(_createHuntObject(distractorLetter));
      }
    }

    _activeObjects.shuffle();
  }

  HuntObject _createHuntObject(String letter) {
    return HuntObject(
      id: UniqueKey().toString(),
      letter: letter,
      imagePath: _getObjectImage(letter),
      rotation: 0.0,
      offsetX: 0.0,
      offsetY: 0.0,
    );
  }

  String _getObjectImage(String letter) {
    const Map<String, String> objectMap = {
      'A': 'apple',
      'B': 'ball',
      'C': 'car',
      'D': 'duck',
      'E': 'egg',
      'F': 'feet',
      'G': 'glass',
      'H': 'hat',
      'I': 'igloo',
      'J': 'jar',
      'K': 'key',
      'L': 'lamp',
      'M': 'milk',
      'N': 'nose',
      'O': 'oil',
      'P': 'pan',
      'Q': 'queen',
      'R': 'rain',
      'S': 'sun',
      'T': 'tree',
      'U': 'umbrella',
      'V': 'vase',
      'W': 'window',
      'X': 'xylophone',
      'Y': 'yarn',
      'Z': 'zero',
    };
    final name = objectMap[letter.toUpperCase()] ?? 'apple';
    return 'assets/images/objects/forest/$name.png';
  }

  void _onObjectTap(HuntObject obj, GlobalKey key) {
    if (!_inputEnabled || obj.found) return;

    if (obj.letter == widget.letter.toUpperCase()) {
      _tapTracker.recordCorrectTap();
      showTofiReaction(TofiState.correct);

      final bool won = _correctCount + 1 >= _winCondition;

      if (won) cancelIdleTimer();

      setState(() {
        obj.found = true;
        _correctCount++;
        if (won) _inputEnabled = false;
      });

      if (won) _saveDataAndShowApplause();
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTofiReaction(TofiState.wrong);

      setState(() => obj.found = true);
    }
  }

  Future<void> _playInstructionThenLetter() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        _huntInstructionWav,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        'assets/audio/alphabet_forest/sound_effects/sound_${widget.letter.toLowerCase()}.wav',
      );
    } catch (e) {
      debugPrint('Instruction audio error: $e');
    }
    if (mounted) {
      setState(() => _inputEnabled = true);
      startIdleTimer();
    }
  }

  Future<void> _saveDataAndShowApplause() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'letter_hunt_${widget.letter.toLowerCase()}',
      activityName: "Alphabet Hunt (${widget.letter.toUpperCase()})",
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    await Future.delayed(Duration(seconds: 2));
    if (!mounted) return;

    _showApplause();
  }

  void _showApplause() {
    final String currentLetter = widget.letter.toUpperCase();

    const skipGoodJobLetters = {
      'A',
      'B',
      'D',
      'E',
      'G',
      'H',
      'J',
      'K',
      'M',
      'N',
      'P',
      'Q',
      'S',
      'T',
      'V',
      'W',
      'Y',
    };

    if (skipGoodJobLetters.contains(currentLetter)) {
      String nextLetter = String.fromCharCode(currentLetter.codeUnitAt(0) + 1);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlphabetIntroScreen(letter: nextLetter),
        ),
      );
      return;
    }

    const completeLevelsLetters = {'C', 'F', 'I', 'L', 'O', 'R', 'U', 'X', 'Z'};

    if (completeLevelsLetters.contains(currentLetter)) {
      final completedLevel = ForestProgressService.levelNumberForLetter(
        currentLetter,
      );

      if (completedLevel != null) {
        ForestProgressService.instance.markLevelComplete(completedLevel);
      }
    }

    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: 'assets/images/characters/dog.png',

          onNext: () {
            Navigator.pop(context);

            String current = widget.letter.toUpperCase();

            if (currentLetter == 'C') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ForestMailDeliveryGame(level: 2),
                ),
              );
            } else if (currentLetter == 'F') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcornBasketGame(level: 4),
                ),
              );
            } else if (currentLetter == 'I') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ButterflyFlowerGardenGame(level: 6),
                ),
              );
            } else if (currentLetter == 'L') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ButterflyLetterMatchGame(level: 8),
                ),
              );
            } else if (currentLetter == 'O') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const MushroomHideAndSeekGame(level: 10),
                ),
              );
            } else if (currentLetter == 'R') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BerryBushHarvestGame(level: 12),
                ),
              );
            } else if (currentLetter == 'U') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowThePawPrintsGame(level: 14),
                ),
              );
            } else if (currentLetter == 'X') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const FallenStickLetterBuilderGame(level: 16),
                ),
              );
            } else if (currentLetter == 'Z') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const YakZebraRaceGame(level: 18),
                ),
              );
            } else {
              // Otherwise, just go to the next normal Intro screen!
              int charCode = current.codeUnitAt(0);
              if (charCode >= 65 && charCode < 90) {
                String nextLetter = String.fromCharCode(charCode + 1);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlphabetIntroScreen(letter: nextLetter),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForestLevelScreen(),
                  ),
                );
              }
            }
          },
          onRestart: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AlphabetHuntScreen(letter: widget.letter),
              ),
            );
          },
          onBack: () {
            Navigator.pop(context); // Close the prompt
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ForestLevelScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    OrientationService.setLandscape();
    _audioPlayer.dispose();
    _tofiPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double objSize = (screenSize.height * 0.22).clamp(80.0, 150.0);

    return Listener(
      onPointerDown: (_) {
        if (_inputEnabled && !_hasSavedResult) resetIdleTimer();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/backgrounds/bg_game_forest.png',
                fit: BoxFit.cover,
              ),
            ),
            Stack(
              children: [
                buildTofi(context),

                // ── Back button ──
                const Positioned(top: 25, left: 25, child: ForestXButton()),

                // Level Badge
                Positioned(
                  top: 25,
                  right: 25,
                  child: ForestLevelBadge(
                    level:
                        ForestProgressService.levelNumberForLetter(
                          widget.letter.toUpperCase(),
                        ) ??
                        1,
                  ),
                ),

                Positioned(
                  top: 80,
                  bottom: 20,
                  left: 180,
                  right: 20,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double itemWidth =
                          (constraints.maxWidth - (3 * 12)) / 4;
                      final double itemHeight =
                          (constraints.maxHeight - (2 * 12)) / 2;
                      final double itemSize = itemWidth < itemHeight
                          ? itemWidth
                          : itemHeight;
                      final double letterFontSize = itemSize * 0.45;

                      return GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: itemWidth / itemHeight,
                        children: _activeObjects.map((obj) {
                          if (obj.found) return const SizedBox.shrink();

                          return Opacity(
                            opacity: _inputEnabled ? 1.0 : 0.7,
                            child: GestureDetector(
                              key: obj.key,
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onObjectTap(obj, obj.key),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    obj.imagePath,
                                    fit: BoxFit.contain,
                                  ),
                                  Text(
                                    obj.letter,
                                    style: TextStyle(
                                      fontFamily: ForestAppTextStyles.fredoka,
                                      fontSize: letterFontSize,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Colors.black87,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),

            if (showHowToPlay &&
                _inputEnabled &&
                !_hasSavedResult &&
                _firstTargetIndex() != -1)
              Positioned.fill(
                child: HowToPlayOverlay(
                  previewChild: _buildHowToPreview(screenSize),
                  handAlignment: _handAlignmentForTarget(screenSize),
                  handOffset: const Offset(0.15, 0.4),
                  onDismiss: resetIdleTimer,
                ),
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

  // Index of the first target letter still on the board, or -1 if none.
  int _firstTargetIndex() {
    final String target = widget.letter.toUpperCase();
    return _activeObjects.indexWhere((o) => !o.found && o.letter == target);
  }

  // Centre of that grid cell, converted to an Alignment.
  Alignment _handAlignmentForTarget(Size s) {
    final int index = _firstTargetIndex();
    if (index < 0) return Alignment.center;

    const double left = 180, right = 20, top = 80, bottom = 20, gap = 12;
    final double gridW = s.width - left - right;
    final double gridH = s.height - top - bottom;
    final double cellW = (gridW - 3 * gap) / 4;
    final double cellH = (gridH - gap) / 2;

    final int col = index % 4;
    final int row = index ~/ 4;

    final double cx = left + col * (cellW + gap) + cellW / 2;
    final double cy = top + row * (cellH + gap) + cellH / 2;

    return Alignment((2 * cx / s.width) - 1, (2 * cy / s.height) - 1);
  }

  Widget _buildHowToPreview(Size screenSize) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/bg_game_forest.png',
          fit: BoxFit.cover,
        ),
        Positioned(
          top: 80,
          bottom: 20,
          left: 180,
          right: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = (constraints.maxWidth - (3 * 12)) / 4;
              final double itemHeight = (constraints.maxHeight - (2 * 12)) / 2;
              final double itemSize = itemWidth < itemHeight
                  ? itemWidth
                  : itemHeight;

              return GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: itemWidth / itemHeight,
                children: _activeObjects.map((obj) {
                  if (obj.found) return const SizedBox.shrink();

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(obj.imagePath, fit: BoxFit.contain),
                      Text(
                        obj.letter,
                        style: TextStyle(
                          fontFamily: ForestAppTextStyles.fredoka,
                          fontSize: itemSize * 0.45,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black87,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HuntObject {
  final String id;
  final String letter;
  final String imagePath;
  final double rotation;
  final double offsetX;
  final double offsetY;
  final GlobalKey key = GlobalKey();
  bool found = false;

  HuntObject({
    required this.id,
    required this.letter,
    required this.imagePath,
    required this.rotation,
    required this.offsetX,
    required this.offsetY,
  });
}
