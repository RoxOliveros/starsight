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

class PuzzlePiece {
  final int id;

  PuzzlePiece({required this.id});
}

class AlphabetPuzzleScreen extends StatefulWidget {
  final String letter;

  const AlphabetPuzzleScreen({super.key, required this.letter});

  @override
  State<AlphabetPuzzleScreen> createState() => _AlphabetPuzzleScreenState();
}

class _AlphabetPuzzleScreenState extends State<AlphabetPuzzleScreen>
    with
        TofiReactionMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<AlphabetPuzzleScreen>,
        IdleHintMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _tofiPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _tofiPlayer];

  @override
  AudioPlayer get tofiPlayer => _tofiPlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  late List<PuzzlePiece> _availablePieces;
  final Map<int, PuzzlePiece> _placedPieces = {};

  late List<PuzzlePiece> _allPieces;
  late String _fullImagePath;

  static const String _puzzleInstructionWav =
      'assets/audio/alphabet_forest/alphabet_minigame_puzzle_instruction.wav';

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _inputEnabled = false;

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

    _fullImagePath = _getObjectImage(widget.letter);
    _allPieces = List.generate(4, (i) => PuzzlePiece(id: i));
    _playInstructionThenLetter();
    _resetGame();
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

  static const Map<String, String> _objectMap = {
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

  String _objectName(String letter) =>
      _objectMap[letter.toUpperCase()] ?? 'apple';

  String _getObjectImage(String letter) =>
      'assets/images/objects/forest/${_objectName(letter)}.png';

  String _getObjectAudio(String letter) =>
      'assets/audio/alphabet_forest/${_objectName(letter)}.wav';

  void _resetGame() {
    setState(() {
      _placedPieces.clear();
      _availablePieces = List.from(_allPieces)..shuffle();
    });
  }

  Future<void> _playInstructionThenLetter() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        _puzzleInstructionWav,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        'assets/audio/alphabet_forest/sound_effects/sound_${widget.letter.toLowerCase()}.wav',
      );
    } catch (e) {
      debugPrint('Instruction audio error: $e');
    } finally {
      if (mounted) {
        setState(() => _inputEnabled = true);
        startIdleTimer();
      }
    }
  }

  Future<void> _saveDataAndShowSuccessDialog() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId: 'letter_puzzle_${widget.letter.toLowerCase()}',
      activityName: "Alphabet Puzzle (${widget.letter.toUpperCase()})",
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    await Future.delayed(Duration(seconds: 1));
    if (!mounted) return;

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
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

    // mark level complete for some letters
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

          //Wag po buburahin 1
          // 1. NEXT BUTTON: What happens when they click the right arrow?
          // onNext: () {
          // Navigator.pop(context);
          // Navigator.pop(
          //   context,
          // );
          // },
          //Wag po buburahin 2

          // 2. Goes from PUZZLE to PUZZLE continuously (D -> E -> F)
          onNext: () {
            Navigator.pop(context); // Close the prompt

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
                // Reached the end with no more letters/boss levels mapped.
                // Go back to a fresh level-select screen so it reloads
                // progress on its own, instead of popping back to a
                // potentially stale existing instance.
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
                builder: (_) => AlphabetPuzzleScreen(letter: widget.letter),
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
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double boardSize = screenSize.height * 0.65;
    final double pieceSize = boardSize / 2;

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

                // Back button
                const Positioned(top: 25, left: 25, child: ForestXButton()),

                // Level badge
                Positioned(
                  top: 25,
                  right: 20,
                  child: ForestLevelBadge(
                    level:
                        ForestProgressService.levelNumberForLetter(
                          widget.letter.toUpperCase(),
                        ) ??
                        1,
                  ),
                ),

                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 70),
                      child: Center(
                        child: SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: ForestColorTheme.lightgreen,
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: AssetImage(_fullImagePath),
                                fit: BoxFit.contain,
                                opacity: 0.65,
                              ),
                            ),
                            child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              removeBottom: true,
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 4,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                    ),
                                itemBuilder: (context, index) {
                                  return _buildTargetSlot(index, pieceSize);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      top: 80,
                      bottom: 20,
                      child: SizedBox(
                        width: screenSize.width * 0.28,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _availablePieces.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1,
                                ),
                            itemBuilder: (context, index) {
                              final piece = _availablePieces[index];

                              return Opacity(
                                opacity: _inputEnabled ? 1.0 : 0.75,
                                child: Draggable<PuzzlePiece>(
                                  data: piece,
                                  maxSimultaneousDrags: _inputEnabled ? 1 : 0,
                                  onDragStarted: cancelIdleTimer,
                                  onDragEnd: (_) {
                                    if (!_hasSavedResult &&
                                        _placedPieces.length < 4) {
                                      startIdleTimer();
                                    }
                                  },
                                  feedback: _PuzzlePieceWidget(
                                    imagePath: _fullImagePath,
                                    pieceId: piece.id,
                                    size: pieceSize,
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.2,
                                    child: _PuzzlePieceWidget(
                                      imagePath: _fullImagePath,
                                      pieceId: piece.id,
                                      size: pieceSize,
                                    ),
                                  ),
                                  child: _PuzzlePieceWidget(
                                    imagePath: _fullImagePath,
                                    pieceId: piece.id,
                                    size: pieceSize,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (showHowToPlay &&
                _inputEnabled &&
                !_hasSavedResult &&
                _availablePieces.isNotEmpty)
              Positioned.fill(
                child: HowToPlayOverlay(
                  previewChild: _buildHowToPreview(screenSize, boardSize),
                  handAlignment: _handStartAlignment(screenSize),
                  handEndAlignment: _handEndAlignment(screenSize, boardSize),
                  handOffset: const Offset(0.15, 0.4),
                  onDismiss: resetIdleTimer,
                ),
              ),

            // 2. The Lighting Prompt Card Overlay
            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate(); // don't leave the tutorial audio waiting
                },
              ),
          ],
        ),
      ),
    );
  }

  Alignment _toAlignment(double cx, double cy, Size s) {
    return Alignment((2 * cx / s.width) - 1, (2 * cy / s.height) - 1);
  }

  // Centre of the first piece in the tray.
  Alignment _handStartAlignment(Size s) {
    final double inner = s.width * 0.28 - 40;
    final double cell = (inner - 16) / 2;
    final double gridLeft = s.width - s.width * 0.28;
    const double gridTop = 100;

    const int index = 0;
    final double cx = gridLeft + (index % 2) * (cell + 16) + cell / 2;
    final double cy = gridTop + (index ~/ 2) * (cell + 16) + cell / 2;
    return _toAlignment(cx, cy, s);
  }

  // Centre of the board slot that the first tray piece belongs in.
  Alignment _handEndAlignment(Size s, double boardSize) {
    if (_availablePieces.isEmpty) return Alignment.center;
    final int slot = _availablePieces.first.id;

    final double boardLeft = (s.width - boardSize) / 2;
    final double boardTop = 70 + (s.height - 70 - boardSize) / 2;
    final double slotSize = (boardSize - 8) / 2; // 4px border on each side

    final double cx = boardLeft + 4 + (slot % 2) * slotSize + slotSize / 2;
    final double cy = boardTop + 4 + (slot ~/ 2) * slotSize + slotSize / 2;
    return _toAlignment(cx, cy, s);
  }

  Widget _buildHowToPreview(Size s, double boardSize) {
    final double slotSize = (boardSize - 8) / 2;
    final double traySize = s.width * 0.28 - 40;
    final double cell = (traySize - 16) / 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/bg_game_forest.png',
          fit: BoxFit.cover,
        ),
        Positioned(
          left: (s.width - boardSize) / 2,
          top: 70 + (s.height - 70 - boardSize) / 2,
          width: boardSize,
          height: boardSize,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: ForestColorTheme.lightgreen, width: 4),
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage(_fullImagePath),
                fit: BoxFit.contain,
                opacity: 0.65,
              ),
            ),
            child: GridView.count(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              children: List.generate(4, (i) {
                final placed = _placedPieces[i];
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ForestColorTheme.darkseagreen.withValues(
                        alpha: 0.1,
                      ),
                    ),
                  ),
                  child: placed == null
                      ? null
                      : _PuzzlePieceWidget(
                          imagePath: _fullImagePath,
                          pieceId: placed.id,
                          size: slotSize,
                        ),
                );
              }),
            ),
          ),
        ),
        Positioned(
          left: s.width - s.width * 0.28,
          top: 100,
          width: traySize,
          child: GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: _availablePieces.map((p) {
              return _PuzzlePieceWidget(
                imagePath: _fullImagePath,
                pieceId: p.id,
                size: cell,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetSlot(int slotIndex, double size) {
    bool isFilled = _placedPieces.containsKey(slotIndex);
    PuzzlePiece? placedPiece = _placedPieces[slotIndex];

    return DragTarget<PuzzlePiece>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        if (isFilled || details.data.id != slotIndex) {
          GamesSfxPlayer.instance.play(GameSfx.bubblePop);
          showTofiReaction(TofiState.wrong);
          _tapTracker.recordMistake();
          return;
        }
        _tapTracker.recordCorrectTap();
        setState(() {
          _placedPieces[slotIndex] = details.data;
          _availablePieces.removeWhere((p) => p.id == details.data.id);
        });

        if (_placedPieces.length == 4) {
          try {
            await playVoiceRestartingOnFaceLoss(
              _audioPlayer,
              _getObjectAudio(widget.letter),
            );
          } catch (e) {
            debugPrint('Object audio error: $e');
          }
          if (!mounted) return;
          _saveDataAndShowSuccessDialog();
        } else {
          showTofiReaction(TofiState.correct);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering =
            !isFilled && candidateData.any((p) => p?.id == slotIndex);

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isHovering
                  ? ForestColorTheme.seagreen
                  : ForestColorTheme.darkseagreen.withValues(alpha: 0.1),
              width: isHovering ? 4 : 1,
            ),
            // Changed this to be more transparent so the background hint shows through clearly
            color: isHovering
                ? ForestColorTheme.lightgreen.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          child: isFilled
              ? _PuzzlePieceWidget(
                  imagePath: _fullImagePath,
                  pieceId: placedPiece!.id,
                  size: size,
                )
              : null,
        );
      },
    );
  }
}

class _PuzzlePieceWidget extends StatelessWidget {
  final String imagePath;
  final int pieceId;
  final double size;
  final bool isDragging;

  const _PuzzlePieceWidget({
    required this.imagePath,
    required this.pieceId,
    required this.size,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(
      pieceId.isEven ? -1.0 : 1.0,
      pieceId < 2 ? -1.0 : 1.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double s = constraints.hasTightWidth && constraints.hasTightHeight
            ? constraints.biggest.shortestSide
            : size;

        return Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: isDragging ? 1.05 : 1.0,
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  if (isDragging)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(5, 5),
                    ),
                ],
              ),
              child: ClipRect(
                child: OverflowBox(
                  alignment: alignment,
                  minWidth: s * 2,
                  maxWidth: s * 2,
                  minHeight: s * 2,
                  maxHeight: s * 2,
                  child: Image.asset(
                    imagePath,
                    width: s * 2,
                    height: s * 2,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
