import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/forest_database_service.dart';
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../../business_layer/orientation_service.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'alphabet_game_ui.dart';
import 'forest_flow.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlphabetFallScreen extends StatefulWidget {
  final List<String> letters;

  const AlphabetFallScreen({super.key, required this.letters});

  @override
  State<AlphabetFallScreen> createState() => _AlphabetFallScreenState();
}

class _AlphabetFallScreenState extends State<AlphabetFallScreen>
    with
        SingleTickerProviderStateMixin,
        TofiReactionMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin<AlphabetFallScreen>,
        IdleHintMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _tofiPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _tofiPlayer];

  @override
  AudioPlayer get tofiPlayer => _tofiPlayer;

  final GameTapTracker _tapTracker = GameTapTracker();

  final List<FallingObject> _activeObjects = [];
  final Random _random = Random();

  // Timers are safely nullable
  Timer? _spawnTimer;
  Timer? _gameTimer;

  static const String _fallInstructionWav = 'assets/audio/alphabet_forest/alphabet_minigame_fall_instruction.wav';

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;
  bool _gameLoopsStarted = false;

  static const int _correctPerLetter = 3;
  static const double _basketInset = 16;
  static const List<Shadow> _letterShadows = [
    Shadow(blurRadius: 6, color: Colors.black87, offset: Offset(2, 2)),
  ];

  int _targetIndex = 0;
  int _correctForTarget = 0;

  String get _target => widget.letters[_targetIndex].toUpperCase();

  bool _inputEnabled = false;

  Size _field = Size.zero;
  double _objSize = 0;
  double _basketSize = 0;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // child's calibration separate from everyone else's.
    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };
    _playInstructionThenLetter();
  }

  // --- THE IMAGE DICTIONARY ---
  String _getImageForLetter(String letter) {
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

  void _startGameLoops() {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _spawnObject();
    });
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateObjectPositions();
    });
  }

  void _spawnObject() {
    if (!mounted) return;

    final others = widget.letters
        .where((l) => l.toUpperCase() != _target)
        .map((l) => l.toUpperCase())
        .toList();
    final useTarget = others.isEmpty || _random.nextDouble() < 0.5;
    final base = useTarget ? _target : others[_random.nextInt(others.length)];
    final letterToDrop = _random.nextBool() ? base : base.toLowerCase();

    setState(() {
      _activeObjects.add(
        FallingObject(
          letter: letterToDrop,
          imagePath: _getImageForLetter(letterToDrop),
          xPos: _random.nextDouble() * 0.72,
          // keep the basket column clear
          yPos: -0.1,
          speed:
              0.002 +
              (_random.nextDouble() * 0.0025), // slower: kids drag these
        ),
      );
    });
  }

  void _updateObjectPositions() {
    if (!mounted) return;
    setState(() {
      for (final obj in _activeObjects) {
        if (!obj.isDragging) obj.yPos += obj.speed;
      }
      _activeObjects.removeWhere((o) => !o.isDragging && o.yPos > 1.1);
    });
  }

  Rect _basketRect() => Rect.fromLTWH(
    _field.width - _basketInset - _basketSize,
    _field.height - _basketInset - _basketSize,
    _basketSize,
    _basketSize,
  );

  void _onDragStart(FallingObject obj, Offset topLeft) {
    if (!_inputEnabled) return;
    obj.isDragging = true;
    obj.dragTopLeft = topLeft;
  }

  void _onDragUpdate(FallingObject obj, Offset delta) {
    if (!obj.isDragging) return;
    setState(() => obj.dragTopLeft += delta);
  }

  void _onDragEnd(FallingObject obj) {
    if (!obj.isDragging) return;

    final center = obj.dragTopLeft + Offset(_objSize / 2, _objSize / 2);
    final overBasket = _basketRect().inflate(_objSize * 0.3).contains(center);

    if (!overBasket) {
      // dropped elsewhere: keep falling from where it was released
      setState(() {
        obj.isDragging = false;
        obj.xPos = (obj.dragTopLeft.dx / (_field.width - _objSize))
            .clamp(0.0, 1.0)
            .toDouble();
        obj.yPos = obj.dragTopLeft.dy / _field.height;
      });
      return;
    }

    if (obj.letter.toUpperCase() == _target) {
      _tapTracker.recordCorrectTap();
      unawaited(showTofiReaction(TofiState.correct));
      setState(() {
        _activeObjects.remove(obj);
        _correctForTarget++;
      });
      if (_correctForTarget >= _correctPerLetter) _onTargetDone();
    } else {
      _tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      unawaited(showTofiReaction(TofiState.wrong));
      setState(() => _activeObjects.remove(obj));
    }
  }

  Future<void> _onTargetDone() async {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    setState(() => _inputEnabled = false);

    if (_targetIndex + 1 >= widget.letters.length) {
      _saveDataAndShowApplause();
      return;
    }

    setState(() {
      _activeObjects.clear();
      _targetIndex++;
      _correctForTarget = 0;
    });
    await _playTargetSound();
    if (!mounted) return;
    _beginRound();
  }

  Future<void> _playInstructionThenLetter() async {
    try {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        _fallInstructionWav,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      await _playTargetSound();
    } finally {
      if (mounted) {
        _beginRound();
        _gameLoopsStarted = true;
        startIdleTimer();
      }
    }
  }

  Future<void> _playTargetSound() => playVoiceRestartingOnFaceLoss(
    _audioPlayer,
    'assets/audio/alphabet_forest/sound_effects/sound_${_target.toLowerCase()}.wav',
  );

  void _beginRound() {
    setState(() => _inputEnabled = true);
    _startGameLoops();
  }

  Future<void> _saveDataAndShowApplause() async {
    cancelIdleTimer();
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    ForestDatabaseService.saveGameData(
      gameId:
          'letter_fall_${widget.letters.map((l) => l.toLowerCase()).join()}',
      activityName:
          "Alphabet Fall (${widget.letters.map((l) => l.toUpperCase()).join(', ')})",
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
                builder: (_) => AlphabetFallScreen(letters: widget.letters),
              ),
            );
          },
          onBack: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ForestLevelScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    disposeIdleTimer();

    _audioPlayer.dispose();
    _tofiPlayer.dispose();

    disposeAiCamera();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Listener(
      onPointerDown: (_) {
        if (_gameLoopsStarted && !_hasSavedResult) resetIdleTimer();
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
                const Positioned(top: 25, left: 25, child: ForestXButton()),
                Positioned(
                  top: 25,
                  right: 20,
                  child: ForestLevelBadge(
                    level: ForestFlow.levelOf(widget.letters),
                  ),
                ),
                buildTofi(context),
                LayoutBuilder(
                  builder: (context, constraints) {
                    _field = Size(constraints.maxWidth, constraints.maxHeight);
                    _objSize = constraints.maxWidth * 0.12;
                    _basketSize = constraints.maxWidth * 0.2;

                    return Stack(
                      children: [
                        Positioned(
                          right: _basketInset,
                          bottom: _basketInset,
                          child: _buildBasket(_basketSize, _target),
                        ),
                        ..._activeObjects.map((obj) {
                          final left = obj.isDragging
                              ? obj.dragTopLeft.dx
                              : obj.xPos * (_field.width - _objSize);
                          final top = obj.isDragging
                              ? obj.dragTopLeft.dy
                              : obj.yPos * _field.height;
                          return Positioned(
                            key: ObjectKey(obj),
                            left: left,
                            top: top,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (_) =>
                                  _onDragStart(obj, Offset(left, top)),
                              onPanUpdate: (d) => _onDragUpdate(obj, d.delta),
                              onPanEnd: (_) => _onDragEnd(obj),
                              onPanCancel: () => _onDragEnd(obj),
                              child: _buildLetterObject(obj.letter, _objSize),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),

            if (showHowToPlay && _gameLoopsStarted && !_hasSavedResult)
              Positioned.fill(
                child: HowToPlayOverlay(
                  previewChild: _buildHowToPreview(size),
                  handAlignment: _demoHandStart(size),
                  handEndAlignment: _demoHandEnd(size),
                  handOffset: const Offset(0.15, 0.55),
                  onDismiss: resetIdleTimer,
                ),
              ),

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

  Widget _buildLetterObject(String letter, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(_getImageForLetter(letter), fit: BoxFit.contain),
          Text(
            letter,
            style: TextStyle(
              fontFamily: ForestAppTextStyles.fredoka,
              fontSize: size * 0.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: _letterShadows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasket(double size, String letter) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/objects/forest/basket.png',
            fit: BoxFit.contain,
          ),
          Padding(
            padding: EdgeInsets.only(top: size * 0.25),
            child: Text(
              '${letter.toUpperCase()}${letter.toLowerCase()}',
              style: TextStyle(
                fontFamily: ForestAppTextStyles.fredoka,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: _letterShadows,
              ),
            ),
          ),
        ],
      ),
    );
  }

// --- how-to demo: apple -> basket (shared by preview and hand) ---
  static const String _demoLetter = 'A'; // apple

  Offset _demoAppleTopLeft(Size s) => Offset(s.width * 0.35, s.height * 0.2);

  Alignment _toAlignment(Offset p, Size s) =>
      Alignment((2 * p.dx / s.width) - 1, (2 * p.dy / s.height) - 1);

// center of the apple
  Alignment _demoHandStart(Size s) {
    final o = _demoAppleTopLeft(s);
    final half = s.width * 0.12 / 2;
    return _toAlignment(Offset(o.dx + half, o.dy + half), s);
  }

// center of the basket
  Alignment _demoHandEnd(Size s) {
    final half = s.width * 0.2 / 2;
    return _toAlignment(
      Offset(s.width - _basketInset - half, s.height - _basketInset - half),
      s,
    );
  }

  Widget _buildHowToPreview(Size s) {
    final o = _demoAppleTopLeft(s);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/bg_game_forest.png',
          fit: BoxFit.cover,
        ),
        Positioned(
          right: _basketInset,
          bottom: _basketInset,
          child: _buildBasket(s.width * 0.2, _demoLetter),
        ),
        Positioned(
          left: o.dx,
          top: o.dy,
          child: _buildLetterObject(_demoLetter, s.width * 0.12),
        ),
      ],
    );
  }
}

class FallingObject {
  final String letter;
  final String imagePath;
  double xPos;
  bool isDragging = false;
  Offset dragTopLeft = Offset.zero;
  double yPos;
  final double speed;

  FallingObject({
    required this.letter,
    required this.imagePath,
    required this.xPos,
    required this.yPos,
    required this.speed,
  });
}
