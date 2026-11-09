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

class AlphabetHuntScreen extends StatefulWidget {
  final List<String> letters;
  const AlphabetHuntScreen({super.key, required this.letters});

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

  final List<HuntObject> _activeObjects = [];

  int _correctCount = 0;

  final GameTapTracker _tapTracker = GameTapTracker();

  static const String _huntInstructionWav =
      'assets/audio/alphabet_forest/alphabet_minigame_hunt_instruction.wav';

  bool _inputEnabled = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  static const int _targetsPerRound = 3;
  static const int _gridCount = 8; // 4 x 2

  int _roundIndex = 0;
  String get _target =>
      widget.letters[min(_roundIndex, widget.letters.length - 1)].toUpperCase();

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

    _generateHuntField();
    _playInstructionThenLetter();
  }

  void _generateHuntField() {
    _activeObjects.clear();

    for (int i = 0; i < _targetsPerRound; i++) {
      _activeObjects.add(_createHuntObject(_target));
    }

    final others = _distractorLetters();
    for (int i = 0; i < _gridCount - _targetsPerRound; i++) {
      _activeObjects.add(_createHuntObject(others[i % others.length]));
    }

    _activeObjects.shuffle();
  }

  List<String> _distractorLetters() {
    final others = widget.letters
        .map((l) => l.toUpperCase())
        .where((l) => l != _target)
        .toList();

    if (others.length < 2) {
      final first = widget.letters.first.toUpperCase().codeUnitAt(0);
      final earlier = [for (var c = 65; c < first; c++) String.fromCharCode(c)]
        ..shuffle();
      others.addAll(earlier.take(2 - others.length));
    }
    return others;
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

    if (obj.letter == _target) {
      _tapTracker.recordCorrectTap();
      showTofiReaction(TofiState.correct);

      final bool roundDone = _correctCount + 1 >= _targetsPerRound;
      final bool lastRound = _roundIndex + 1 >= widget.letters.length;
      if (roundDone) cancelIdleTimer();

      setState(() {
        obj.found = true;
        _correctCount++;
        if (roundDone) _inputEnabled = false;
      });

      if (roundDone) {
        if (lastRound) {
          _saveDataAndShowApplause();
        } else {
          _nextRound();
        }
      }
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showTofiReaction(TofiState.wrong);
      setState(() => obj.found = true);
    }
  }

  Future<void> _nextRound() async {
    await Future.delayed(const Duration(milliseconds: 1200)); // let Tofi react
    if (!mounted) return;

    setState(() {
      _roundIndex++;
      _correctCount = 0;
      _generateHuntField();
    });

    try {
      await _playTargetSound();
    } catch (e) {
      debugPrint('Target audio error: $e');
    }
    if (!mounted) return;
    setState(() => _inputEnabled = true);
    startIdleTimer();
  }

  Future<void> _playInstructionThenLetter() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        _huntInstructionWav,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      await _playTargetSound();
    } catch (e) {
      debugPrint('Instruction audio error: $e');
    }
    if (mounted) {
      setState(() => _inputEnabled = true);
      startIdleTimer();
    }
  }

  Future<void> _playTargetSound() => playVoiceRestartingOnFaceLoss(
    _audioPlayer,
    'assets/audio/alphabet_forest/sound_effects/sound_${_target.toLowerCase()}.wav',
  );

  Future<void> _saveDataAndShowApplause() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId:
          'letter_hunt_${widget.letters.map((l) => l.toLowerCase()).join()}',
      activityName:
          "Alphabet Hunt (${widget.letters.map((l) => l.toUpperCase()).join(', ')})",
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
                builder: (_) => AlphabetHuntScreen(letters: widget.letters),
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
                    level: ForestFlow.levelOf(widget.letters),
                  ),
                ),

                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      // tap the card to hear the letter again
                      onTap: _inputEnabled
                          ? () => _playTargetSound().catchError((_) {})
                          : null,
                      child: _buildTargetCard(_target),
                    ),
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
                              child: _buildObjectTile(
                                obj.letter,
                                letterFontSize,
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

            if (showHowToPlay && _inputEnabled && !_hasSavedResult)
              Positioned.fill(
                child: HowToPlayOverlay(
                  previewChild: _buildHowToPreview(screenSize),
                  handAlignment: _handAlignmentForCell(screenSize, 1),
                  handOffset: const Offset(0.15, 0.65),
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

  Widget _buildTargetCard(String letter) {
    return Container(
      width: 62,
      height: 62,
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
        style: TextStyle(
          fontFamily: ForestAppTextStyles.fredoka,
          fontSize: 38,
          height: 1,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF3C5729),
        ),
      ),
    );
  }

  Widget _buildObjectTile(String letter, double fontSize) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(_getObjectImage(letter), fit: BoxFit.contain),

        // Letter outline
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.black87,
          ),
        ),

        // Letter fill
        Text(
          letter,
          style: TextStyle(
            fontFamily: ForestAppTextStyles.fredoka,
            fontSize: fontSize,
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
  }

  List<String> _previewLetters() {
    final inLevel = widget.letters.map((l) => l.toUpperCase()).toSet();
    final spare = [
      for (var c = 65; c < 91; c++) String.fromCharCode(c),
    ].where((l) => !inLevel.contains(l)).toList();
    final s = spare[0], a = spare[1], b = spare[2];
    return [a, s, b, s, b, a, s, a];
  }

  Alignment _handAlignmentForCell(Size s, int index) {
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
    final letters = _previewLetters();

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/bg_game_forest.png',
          fit: BoxFit.cover,
        ),
        Positioned(
          top: 12,
          left: 180,
          right: 20,
          child: Center(child: _buildTargetCard(letters[1])),
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
                children: letters
                    .map((l) => _buildObjectTile(l, itemSize * 0.45))
                    .toList(),
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
