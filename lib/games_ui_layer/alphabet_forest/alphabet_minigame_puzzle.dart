import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/forest_database_service.dart';
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
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
import 'forest_flow.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PuzzlePiece {
  final int id;

  PuzzlePiece({required this.id});
}

class AlphabetPuzzleScreen extends StatefulWidget {
  final List<String> letters;
  const AlphabetPuzzleScreen({super.key, required this.letters});

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

  static const String _puzzleInstructionWav =
      'assets/audio/alphabet_forest/alphabet_minigame_puzzle_instruction.wav';

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _inputEnabled = false;

  int _roundIndex = 0;
  String get _letter =>
      widget.letters[min(_roundIndex, widget.letters.length - 1)].toUpperCase();
  String get _fullImagePath => _getObjectImage(_letter);

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

    _allPieces = List.generate(4, (i) => PuzzlePiece(id: i));
    _resetGame();
    _playInstructionThenLetter();
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
      await _playLetterSound();
    } catch (e) {
      debugPrint('Instruction audio error: $e');
    } finally {
      if (mounted) {
        setState(() => _inputEnabled = true);
        startIdleTimer();
      }
    }
  }

  Future<void> _playLetterSound() => playVoiceRestartingOnFaceLoss(
    _audioPlayer,
    'assets/audio/alphabet_forest/sound_effects/sound_${_letter.toLowerCase()}.wav',
  );

  void _replayLetter() => _playLetterSound().catchError((_) {});

  Future<void> _onPuzzleComplete() async {
    cancelIdleTimer();
    setState(() => _inputEnabled = false);
    showTofiReaction(TofiState.correct);

    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        _getObjectAudio(_letter),
      );
    } catch (e) {
      debugPrint('Object audio error: $e');
    }
    if (!mounted) return;

    if (_roundIndex + 1 >= widget.letters.length) {
      _saveDataAndShowSuccessDialog();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() => _roundIndex++);
    _resetGame(); // new picture, pieces back in the tray

    try {
      await _playLetterSound();
    } catch (e) {
      debugPrint('Letter audio error: $e');
    }
    if (!mounted) return;
    setState(() => _inputEnabled = true);
    startIdleTimer();
  }

  Future<void> _saveDataAndShowSuccessDialog() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId:
          'letter_puzzle_${widget.letters.map((l) => l.toLowerCase()).join()}',
      activityName:
          "Alphabet Puzzle (${widget.letters.map((l) => l.toUpperCase()).join(', ')})",
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
    ForestProgressService.instance.markLevelComplete(
      ForestFlow.levelOf(widget.letters),
    );

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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ForestFlow.screenAfter(widget.letters),
              ),
            );
          },
          onRestart: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AlphabetPuzzleScreen(letters: widget.letters),
              ),
            );
          },

          onBack: () {
            ForestNav.backToLevels(context);
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
                    level: ForestFlow.levelOf(widget.letters),
                  ),
                ),

                Positioned(
                  top: 25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _inputEnabled ? _replayLetter : null,
                      child: _buildLetterCard(_letter),
                    ),
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

  Widget _buildLetterCard(String letter, {double size = 72}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ForestColorTheme.darkseagreen, width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        textScaler: const TextScaler.linear(1.0),
        style: TextStyle(
          fontFamily: ForestAppTextStyles.fredoka,
          fontSize: size * 0.62,
          height: 1,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF3C5729),
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
          _onPuzzleComplete();
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
