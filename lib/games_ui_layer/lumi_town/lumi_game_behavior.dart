import 'dart:async';
import 'dart:math';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:StarSight/ui_layer/lumi_town/lumi_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../business_layer/town_progress_service.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/lumi_town/lumi_buttons.dart';
import '../goodjob_prompt.dart';

// ============================================================================
// ASSET PATHS — replace if your exact filenames/folders differ
// ============================================================================

const String _classroomBg = 'assets/images/backgrounds/bg_lumi_classroom.png';
const String _teacherWooImage = 'assets/images/characters/dr.woo_the_owl.png';

const String _audioBase = 'assets/audio/lumi_town/';
const String _introAudio = '${_audioBase}behavior_intro.wav';
const String _instructionAudio = '${_audioBase}behavior_instructions.wav';
const String _winAudio = '${_audioBase}behavior_win.wav';

const String _redButton = 'assets/images/buttons/red_button.png';
const String _redButtonClicked = 'assets/images/buttons/red_clicked.png';
const String _greenButton = 'assets/images/buttons/green_button.png';
const String _greenButtonClicked = 'assets/images/buttons/green_clicked.png';

const String _sceneImageBase = 'assets/images/objects/lumi/';

// ============================================================================
// MODEL
// ============================================================================

enum BehaviorSequencePhase {
  intro,
  instruction,
  game,
  complete,
}

class BehaviorSceneModel {
  final String id;
  final String imageAsset;
  final String narrationAudio;
  final String correctFeedbackAudio;
  final bool expectedGreen;

  const BehaviorSceneModel({
    required this.id,
    required this.imageAsset,
    required this.narrationAudio,
    required this.correctFeedbackAudio,
    required this.expectedGreen,
  });
}

const List<BehaviorSceneModel> _behaviors = [
  BehaviorSceneModel(
    id: 'giving',
    imageAsset: '${_sceneImageBase}behavior_giving.png',
    narrationAudio: '${_audioBase}behavior_round_giving.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_giving.wav',
    expectedGreen: true,
  ),
  BehaviorSceneModel(
    id: 'fighting',
    imageAsset: '${_sceneImageBase}behavior_fighting.png',
    narrationAudio: '${_audioBase}behavior_round_fighting.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_fighting.wav',
    expectedGreen: false,
  ),
  BehaviorSceneModel(
    id: 'helping',
    imageAsset: '${_sceneImageBase}behavior_helping.png',
    narrationAudio: '${_audioBase}behavior_round_helping.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_helping.wav',
    expectedGreen: true,
  ),
  BehaviorSceneModel(
    id: 'littering',
    imageAsset: '${_sceneImageBase}behavior_littering.png',
    narrationAudio: '${_audioBase}behavior_round_littering.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_littering.wav',
    expectedGreen: false,
  ),
  BehaviorSceneModel(
    id: 'talking_in_class',
    imageAsset: '${_sceneImageBase}behavior_talking_in_class.png',
    narrationAudio: '${_audioBase}behavior_round_talking_in_class.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_talking_in_class.wav',
    expectedGreen: false,
  ),
  BehaviorSceneModel(
    id: 'cleaning_room',
    imageAsset: '${_sceneImageBase}behavior_cleaning_room.png',
    narrationAudio: '${_audioBase}behavior_round_cleaning_room.wav',
    correctFeedbackAudio: '${_audioBase}behavior_correct_cleaning_room.wav',
    expectedGreen: true,
  ),
];

// ============================================================================
// SCREEN
// ============================================================================

class BehaviorGameScreen extends StatefulWidget {
  final int level;

  const BehaviorGameScreen({super.key, required this.level});

  @override
  State<BehaviorGameScreen> createState() => _BehaviorGameScreenState();
}

class _BehaviorGameScreenState extends State<BehaviorGameScreen>
    with DrWooReactionMixin<BehaviorGameScreen> {
  final DateTime _loadStart = DateTime.now();

  // --- Audio ----------------------------------------------------------
  final AudioPlayer _narrationPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _drWooPlayer = AudioPlayer();

  @override
  AudioPlayer get drWooPlayer => _drWooPlayer;

  // --- Game state -------------------------------------------------------
  late List<BehaviorSceneModel> _queue;
  int _currentIndex = 0;

  bool _inputEnabled = false;
  bool _checkingAnswer = false;
  String? _pressedButton; // 'red' | 'green' | null, brief clicked-asset flash
  BehaviorSequencePhase _phase = BehaviorSequencePhase.intro;
  bool _isLoading = true;
  bool _gameComplete = false;

  BehaviorSceneModel get _current => _queue[_currentIndex];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _queue = _shuffledBehaviors();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    if (_isLoading) {
      final elapsed = DateTime.now().difference(_loadStart);
      final remaining = const Duration(milliseconds: 1500) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      if (!mounted) return;
    }

    setState(() {
      _isLoading = false;
    });

    await _startIntroFlow();
  }

  @override
  void dispose() {
    _narrationPlayer.dispose();
    _completePlayer.dispose();
    _drWooPlayer.dispose();
    super.dispose();
  }

  // --- Shuffle ------------------------------------------------------------

  List<BehaviorSceneModel> _shuffledBehaviors() {
    final rand = Random();
    final arr = List<BehaviorSceneModel>.of(_behaviors);
    for (int i = arr.length - 1; i > 0; i--) {
      final j = rand.nextInt(i + 1);
      final tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
    }
    return arr;
  }

  // --- Intro / instruction flow --------------------------------------------

  Future<void> _startIntroFlow() async {
    if (!mounted) return;

    setState(() {
      _phase = BehaviorSequencePhase.intro;
      _inputEnabled = false;
    });

    await _playAndWait(_narrationPlayer, _introAudio);

    if (!mounted) return;

    setState(() {
      _phase = BehaviorSequencePhase.instruction;
      _inputEnabled = false;
    });

    await _playAndWait(_narrationPlayer, _instructionAudio);

    if (!mounted) return;

    setState(() {
      _phase = BehaviorSequencePhase.game;
    });

    await _playCurrentNarration();
  }

  Future<void> _playCurrentNarration() async {
    setState(() => _inputEnabled = false);

    await _playAndWait(_narrationPlayer, _current.narrationAudio);

    if (!mounted) return;

    setState(() => _inputEnabled = true);
  }

  Future<void> _playAndWait(AudioPlayer player, String asset) async {
    final completer = Completer<void>();
    late final StreamSubscription<void> sub;

    sub = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await player.stop();
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future;
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    } finally {
      await sub.cancel();
    }
  }

  // --- Answer handling --------------------------------------------------

  Future<void> _onAnswer(bool pickedGreen) async {
    if (!_inputEnabled || _checkingAnswer || !mounted) return;

    setState(() {
      _checkingAnswer = true;
      _inputEnabled = false;
      _pressedButton = pickedGreen ? 'green' : 'red';
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _pressedButton = null);

    final bool isCorrect = pickedGreen == _current.expectedGreen;

    if (isCorrect) {
      unawaited(showDrWooReaction(DrWooState.correct));

      await _playAndWait(_narrationPlayer, _current.correctFeedbackAudio);
      if (!mounted) return;

      if (_currentIndex == _queue.length - 1) {
        await _completeGame();
      } else {
        setState(() {
          _currentIndex += 1;
          _checkingAnswer = false;
        });
        await _playCurrentNarration();
      }
    } else {
      unawaited(showDrWooReaction(DrWooState.wrong));

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      setState(() {
        _checkingAnswer = false;
        _inputEnabled = true;
      });
    }
  }

  // --- Completion / restart -------------------------------------------------

  Future<void> _completeGame() async {
    if (!mounted) return;

    setState(() {
      _phase = BehaviorSequencePhase.complete;
    });

    TownProgressService.instance.markLevelComplete(widget.level);

    await _playAndWait(_completePlayer, _winAudio);

    if (!mounted) return;

    setState(() {
      _gameComplete = true;
      _checkingAnswer = false;
    });
  }

  Future<void> _restartGame() async {
    if (!mounted) return;

    setState(() {
      _queue = _shuffledBehaviors();
      _currentIndex = 0;
      _checkingAnswer = false;
      _pressedButton = null;
      _gameComplete = false;
      _phase = BehaviorSequencePhase.game;
      _inputEnabled = false;
    });

    await _playCurrentNarration();
  }

  Future<void> _goBack() async {
    await _narrationPlayer.stop();
    await _completePlayer.stop();
    await _drWooPlayer.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: LoadingScreen.lumiTown(),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(_classroomBg, fit: BoxFit.cover),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // TEACHER WOO DURING INTRO
                  if (_phase == BehaviorSequencePhase.intro)
                    Positioned(
                      right: 0,
                      left: 0,
                      bottom: -110,
                      child: SizedBox(
                        height: height * 1.2,
                        child: Image.asset(_teacherWooImage, fit: BoxFit.contain),
                      ),
                    ),

                  // BEHAVIOR SCENE + ANSWER BUTTONS
                  if (_phase == BehaviorSequencePhase.game ||
                      _phase == BehaviorSequencePhase.complete)
                    Positioned(
                      left: width * 0.08,
                      right: width * 0.08,
                      top: height * 0.08,
                      bottom: height * 0.10,
                      child: _BehaviorRound(
                        scene: _current,
                        inputEnabled: _inputEnabled && !_checkingAnswer,
                        pressedButton: _pressedButton,
                        onRed: () => _onAnswer(false),
                        onGreen: () => _onAnswer(true),
                      ),
                    ),
                ],
              );
            },
          ),

          // Back button.
          Positioned(top: 25, left: 25, child: LumiXButton()),

          // Completion overlay.
          if (_gameComplete)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/dr.woo_the_owl.png',
              onNext: () async {
                // Navigator.of(context).pushReplacement( // TODO: wire to next Lumi Town level.
                //   MaterialPageRoute(
                //     builder: (_) => const (),
                //   ),
                // );
              },
              onRestart: _restartGame,
              onBack: _goBack,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// BEHAVIOR ROUND — center scene image, red button left, green button right
// ============================================================================

class _BehaviorRound extends StatelessWidget {
  final BehaviorSceneModel scene;
  final bool inputEnabled;
  final String? pressedButton;
  final VoidCallback onRed;
  final VoidCallback onGreen;

  const _BehaviorRound({
    required this.scene,
    required this.inputEnabled,
    required this.pressedButton,
    required this.onRed,
    required this.onGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AnswerButton(
          normalAsset: _redButton,
          clickedAsset: _redButtonClicked,
          isPressed: pressedButton == 'red',
          enabled: inputEnabled,
          onTap: onRed,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: LumiColorTheme.rust, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Image.asset(
                scene.imageAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        _AnswerButton(
          normalAsset: _greenButton,
          clickedAsset: _greenButtonClicked,
          isPressed: pressedButton == 'green',
          enabled: inputEnabled,
          onTap: onGreen,
        ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String normalAsset;
  final String clickedAsset;
  final bool isPressed;
  final bool enabled;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.normalAsset,
    required this.clickedAsset,
    required this.isPressed,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Image.asset(
          isPressed ? clickedAsset : normalAsset,
          width: 100,
          height: 100,
        ),
      ),
    );
  }
}
