import 'dart:async';
import 'dart:math';
import 'package:StarSight/games_ui_layer/lumi_town/tr.woo_reaction.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../business_layer/town_progress_service.dart';
import '../../ui_layer/loading_screen.dart';
import '../../ui_layer/lumi_town/lumi_buttons.dart';
import '../goodjob_prompt.dart';
import 'lumi_game_dont_talk_to_strangers.dart';

const String _introBg = 'assets/images/backgrounds/mama_little_bear_scene.png';
const String _gameBg = 'assets/images/backgrounds/bg_sky.png';
const String _completeBg = 'assets/images/backgrounds/mama_little_bear_happy_cleaning.png';
const String _teacherWooImage = 'assets/images/characters/tr.woo_the_owl.png';

const String _audioBase = 'assets/audio/lumi_town/';
const String _introAudio = '${_audioBase}cleaning_intro.wav';
const String _instructionAudio = '${_audioBase}cleaning_instruction.wav';
const String _wrongAudio = 'assets/audio/sound_effects/bubble_pop.wav';
const String _winAudio = '${_audioBase}cleaning_win.wav';

const String _sceneImageBase = 'assets/images/objects/lumi/';

const String _spongeAsset = '${_sceneImageBase}sponge_diswashing.png';
const String _dusterAsset = '${_sceneImageBase}duster.png';
const String _mopBucketAsset = '${_sceneImageBase}mop_bucket.png';
const String _broomDustpanAsset = '${_sceneImageBase}broom_dustpan.png';
const String _basketAsset = '${_sceneImageBase}basket.png';
const String _sprayWipeAsset = '${_sceneImageBase}spray_wipe.png';

// ============================================================================
// MODEL
// ============================================================================

enum CleaningMaterial { sponge, duster, mopBucket, broomDustpan, basket, sprayWipe }

extension CleaningMaterialAsset on CleaningMaterial {
  String get asset {
    switch (this) {
      case CleaningMaterial.sponge:
        return _spongeAsset;
      case CleaningMaterial.duster:
        return _dusterAsset;
      case CleaningMaterial.mopBucket:
        return _mopBucketAsset;
      case CleaningMaterial.broomDustpan:
        return _broomDustpanAsset;
      case CleaningMaterial.basket:
        return _basketAsset;
      case CleaningMaterial.sprayWipe:
        return _sprayWipeAsset;
    }
  }
}

const List<Color> _choiceColors = [
  Color(0xFF69b1d0),
  Color(0xFF96c042),
  Color(0xFFffca3b),
];

enum CleaningSequencePhase { intro, instruction, game, complete }

class CleaningScenarioModel {
  final String id;
  final String dirtyScene;
  final String cleanScene;
  final String questionAudio;
  final String correctAudio;
  final CleaningMaterial correctMaterial;
  final List<CleaningMaterial> choices;

  const CleaningScenarioModel({
    required this.id,
    required this.dirtyScene,
    required this.cleanScene,
    required this.questionAudio,
    required this.correctAudio,
    required this.correctMaterial,
    required this.choices,
  });
}

const List<CleaningScenarioModel> _scenarios = [
  CleaningScenarioModel(
    id: 'dirty_sink',
    dirtyScene: '${_sceneImageBase}dirty_sink.png',
    cleanScene: '${_sceneImageBase}clean_sink.png',
    questionAudio: '${_audioBase}cleaning_sink_question.wav',
    correctAudio: '${_audioBase}cleaning_sink_correct.wav',
    correctMaterial: CleaningMaterial.sponge,
    choices: [
      CleaningMaterial.sponge,
      CleaningMaterial.duster,
      CleaningMaterial.mopBucket,
    ],
  ),
  CleaningScenarioModel(
    id: 'dirty_floor',
    dirtyScene: '${_sceneImageBase}dirty_floor.png',
    cleanScene: '${_sceneImageBase}clean_floor.png',
    questionAudio: '${_audioBase}cleaning_floor_question.wav',
    correctAudio: '${_audioBase}cleaning_floor_correct.wav',
    correctMaterial: CleaningMaterial.mopBucket,
    choices: [
      CleaningMaterial.sponge,
      CleaningMaterial.duster,
      CleaningMaterial.mopBucket,
    ],
  ),
  CleaningScenarioModel(
    id: 'dirty_window',
    dirtyScene: '${_sceneImageBase}dirty_window.png',
    cleanScene: '${_sceneImageBase}clean_window.png',
    questionAudio: '${_audioBase}cleaning_window_question.wav',
    correctAudio: '${_audioBase}cleaning_window_correct.wav',
    correctMaterial: CleaningMaterial.sprayWipe,
    choices: [
      CleaningMaterial.sponge,
      CleaningMaterial.sprayWipe,
      CleaningMaterial.mopBucket,
    ],
  ),
  CleaningScenarioModel(
    id: 'dirty_room',
    dirtyScene: '${_sceneImageBase}dirty_room.png',
    cleanScene: '${_sceneImageBase}clean_room.png',
    questionAudio: '${_audioBase}cleaning_room_question.wav',
    correctAudio: '${_audioBase}cleaning_room_correct.wav',
    correctMaterial: CleaningMaterial.broomDustpan,
    choices: [
      CleaningMaterial.broomDustpan,
      CleaningMaterial.sponge,
      CleaningMaterial.mopBucket,
    ],
  ),
  CleaningScenarioModel(
    id: 'messy_toys',
    dirtyScene: '${_sceneImageBase}messy_toys.png',
    cleanScene: '${_sceneImageBase}clean_floor.png',
    questionAudio: '${_audioBase}cleaning_toys_question.wav',
    correctAudio: '${_audioBase}cleaning_toys_correct.wav',
    correctMaterial: CleaningMaterial.basket,
    choices: [
      CleaningMaterial.basket,
      CleaningMaterial.broomDustpan,
      CleaningMaterial.duster,
    ],
  ),
  CleaningScenarioModel(
    id: 'dirty_ceiling',
    dirtyScene: '${_sceneImageBase}dirty_ceiling.png',
    cleanScene: '${_sceneImageBase}clean_celing.png',
    questionAudio: '${_audioBase}cleaning_ceiling_question.wav',
    correctAudio: '${_audioBase}cleaning_ceiling_correct.wav',
    correctMaterial: CleaningMaterial.duster,
    choices: [
      CleaningMaterial.duster,
      CleaningMaterial.broomDustpan,
      CleaningMaterial.basket,
    ],
  ),
];

// ============================================================================
// SCREEN
// ============================================================================

class CleaningGameScreen extends StatefulWidget {
  final int level;

  const CleaningGameScreen({super.key, required this.level});

  @override
  State<CleaningGameScreen> createState() => _CleaningGameScreenState();
}

class _CleaningGameScreenState extends State<CleaningGameScreen>
    with TrWooReactionMixin<CleaningGameScreen> {
  final DateTime _loadStart = DateTime.now();

  // --- Audio -----------------------------------------------------------
  final AudioPlayer _narrationPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  final AudioPlayer _drWooPlayer = AudioPlayer();

  @override
  AudioPlayer get trWooPlayer => _drWooPlayer;

  // --- Game state --------------------------------------------------------
  late List<CleaningScenarioModel> _queue;
  late List<CleaningMaterial> _currentChoiceOrder;
  int _currentIndex = 0;

  bool _inputEnabled = false;
  bool _checkingAnswer = false;
  bool _showClean = false;
  CleaningSequencePhase _phase = CleaningSequencePhase.intro;
  bool _isLoading = true;
  bool _gameComplete = false;

  CleaningScenarioModel get _current => _queue[_currentIndex];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _queue = _shuffledScenarios();
    _currentChoiceOrder = _shuffledChoices(_queue[_currentIndex]);
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

    setState(() => _isLoading = false);
    await _startIntroFlow();
  }

  @override
  void dispose() {
    _narrationPlayer.dispose();
    _completePlayer.dispose();
    _drWooPlayer.dispose();
    super.dispose();
  }

  Widget buildTrWooContent(BuildContext context) {
    return switch (trWooState) {
      TrWooState.correct => Image.asset(
        'assets/animations/characters/dr.woo_thumbsup.webp',
        fit: BoxFit.contain,
      ),
      TrWooState.wrong => Image.asset(
        'assets/images/characters/tr.woo_tryagain.png',
        fit: BoxFit.contain,
      ),
      TrWooState.normal => Image.asset(
        'assets/images/characters/tr.woo_standing.png',
        fit: BoxFit.contain,
      ),
    };
  }

  // --- Shuffle helpers -----------------------------------------------------

  List<CleaningScenarioModel> _shuffledScenarios() {
    final rand = Random();
    final arr = List<CleaningScenarioModel>.of(_scenarios);
    for (int i = arr.length - 1; i > 0; i--) {
      final j = rand.nextInt(i + 1);
      final tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
    }
    return arr;
  }

  List<CleaningMaterial> _shuffledChoices(CleaningScenarioModel scenario) {
    final rand = Random();
    final arr = List<CleaningMaterial>.of(scenario.choices);
    for (int i = arr.length - 1; i > 0; i--) {
      final j = rand.nextInt(i + 1);
      final tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
    }
    return arr;
  }

  // --- Intro / instruction flow -------------------------------------------

  Future<void> _startIntroFlow() async {
    if (!mounted) return;

    setState(() {
      _phase = CleaningSequencePhase.intro;
      _inputEnabled = false;
    });

    await _playAndWait(_narrationPlayer, _introAudio);
    if (!mounted) return;

    setState(() {
      _phase = CleaningSequencePhase.instruction;
      _inputEnabled = false;
    });

    await _playAndWait(_narrationPlayer, _instructionAudio);
    if (!mounted) return;

    setState(() => _phase = CleaningSequencePhase.game);
    await _beginScenario(0);
  }

  Future<void> _beginScenario(int index) async {
    if (!mounted) return;

    unawaited(showTrWooReaction(TrWooState.normal));

    setState(() {
      _currentIndex = index;
      _showClean = false;
      _currentChoiceOrder = _shuffledChoices(_queue[index]);
      _inputEnabled = false;
      _checkingAnswer = false;
    });

    await _playAndWait(_narrationPlayer, _current.questionAudio);
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

  // --- Answer handling ------------------------------------------------------

  Future<void> _onAnswer(CleaningMaterial picked) async {
    if (!_inputEnabled || _checkingAnswer || !mounted) return;

    setState(() {
      _checkingAnswer = true;
      _inputEnabled = false;
    });

    final bool isCorrect = picked == _current.correctMaterial;

    if (isCorrect) {
      await showTrWooReaction(TrWooState.correct);
      if (!mounted) return;

      setState(() => _showClean = true);

      await _playAndWait(_narrationPlayer, _current.correctAudio);
      if (!mounted) return;

      if (_currentIndex == _queue.length - 1) {
        await _completeGame();
      } else {
        await _beginScenario(_currentIndex + 1);
      }
    } else {
      await _playAndWait(_narrationPlayer, _wrongAudio);
      if (!mounted) return;

      showTrWooReaction(TrWooState.wrong);

      setState(() {
        _checkingAnswer = false;
        _inputEnabled = true;
      });
    }
  }

  // --- Completion / restart --------------------------------------------------

  Future<void> _completeGame() async {
    if (!mounted) return;

    setState(() => _phase = CleaningSequencePhase.complete);

    TownProgressService.instance.markLevelComplete(widget.level);

    unawaited(showTrWooReaction(TrWooState.correct));
    if (!mounted) return;

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
      _queue = _shuffledScenarios();
      _currentIndex = 0;
      _showClean = false;
      _checkingAnswer = false;
      _gameComplete = false;
      _phase = CleaningSequencePhase.game;
      _inputEnabled = false;
    });

    await _beginScenario(0);
  }

  Future<void> _goBack() async {
    await _narrationPlayer.stop();
    await _completePlayer.stop();
    await _drWooPlayer.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: LoadingScreen.lumiTown());
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              _phase == CleaningSequencePhase.complete
                  ? _completeBg
                  : (_phase == CleaningSequencePhase.intro ||
                  _phase == CleaningSequencePhase.instruction)
                  ? _introBg
                  : _gameBg,
              fit: BoxFit.cover,
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (_phase == CleaningSequencePhase.instruction)
                    Positioned(
                      right: width * 0.04,
                      top: 0,
                      bottom: 0,
                      width: width * 0.18,
                      child: const _ScrollingMaterialsPreview(),
                    ),

                  if (_phase == CleaningSequencePhase.game)
                    Positioned(
                      left: width * 0.15,
                      right: width * 0.08 ,
                      top: height * 0.15,
                      bottom: height * 0.06,
                      child: _CleaningRound(
                        scenario: _current,
                        showClean: _showClean,
                        choiceOrder: _currentChoiceOrder,
                        inputEnabled: _inputEnabled && !_checkingAnswer,
                        onSelect: _onAnswer,
                      ),
                    ),
                ],
              );
            },
          ),

          if (_phase == CleaningSequencePhase.game)
            Positioned(
              left: 0,
              bottom: 0,
              width: 250,
              child: buildTrWooContent(context),
            ),

          // Back button.
          Positioned(top: 25, left: 25, child: LumiXButton()),

          // Completion overlay.
          if (_gameComplete)
            GoodJobOverlay(
              characterImage: _teacherWooImage,
              onNext: () async {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => DontTalkToStrangersGame(level: widget.level + 1),
                  ),
                );
              },
              onRestart: _restartGame,
              onBack: _goBack,
            ),
        ],
      ),
    );
  }
}

class _CleaningRound extends StatelessWidget {
  final CleaningScenarioModel scenario;
  final bool showClean;
  final List<CleaningMaterial> choiceOrder;
  final bool inputEnabled;
  final ValueChanged<CleaningMaterial> onSelect;

  const _CleaningRound({
    required this.scenario,
    required this.showClean,
    required this.choiceOrder,
    required this.inputEnabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = choiceOrder.length;

        final spacing = (constraints.maxHeight * 0.03);
        final totalSpacing = spacing * (count - 1);

        // Card size is capped by whichever is tighter: the width budget for
        // the choice column, or the height left once spacing is subtracted.
        final maxCardWidth = constraints.maxWidth * 0.16;
        final maxCardHeightFit = (constraints.maxHeight - totalSpacing) / count;
        final cardSize =
        (maxCardWidth < maxCardHeightFit ? maxCardWidth : maxCardHeightFit)
            .clamp(60.0, 130.0);

        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFFfe9322), width: 8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Image.asset(
                      showClean ? scenario.cleanScene : scenario.dirtyScene,
                      key: ValueKey(showClean ? scenario.cleanScene : scenario.dirtyScene),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: spacing * 8),
            SizedBox(
              width: cardSize,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < choiceOrder.length; i++) ...[
                    if (i != 0) SizedBox(height: spacing),
                    _MaterialAnswerCard(
                      key: ValueKey(choiceOrder[i]),
                      material: choiceOrder[i],
                      color: _choiceColors[i % _choiceColors.length],
                      size: cardSize,
                      enabled: inputEnabled,
                      onTap: () => onSelect(choiceOrder[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MaterialAnswerCard extends StatefulWidget {
  final CleaningMaterial material;
  final Color color;
  final double size;
  final bool enabled;
  final VoidCallback onTap;

  const _MaterialAnswerCard({
    super.key,
    required this.material,
    required this.color,
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_MaterialAnswerCard> createState() => _MaterialAnswerCardState();
}

class _MaterialAnswerCardState extends State<_MaterialAnswerCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.55,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: widget.size,
            height: widget.size,
            padding: EdgeInsets.all(widget.size * 0.09),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.size * 0.14),
              border: Border.all(
                color: Colors.white,
                width: (widget.size * 0.045).clamp(3.0, 6.0),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Image.asset(widget.material.asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _ScrollingMaterialsPreview extends StatefulWidget {
  const _ScrollingMaterialsPreview();

  @override
  State<_ScrollingMaterialsPreview> createState() => _ScrollingMaterialsPreviewState();
}

class _ScrollingMaterialsPreviewState extends State<_ScrollingMaterialsPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _materials = CleaningMaterial.values;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemSize = constraints.maxWidth.clamp(60.0, 130.0);
        const itemSpacing = 20.0;
        final itemExtent = itemSize + itemSpacing;
        final totalHeight = itemExtent * _materials.length;

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final offset = _controller.value * totalHeight;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -offset,
                    // Two copies back-to-back so the scroll loops seamlessly.
                    child: Column(
                      children: [
                        for (final m in [..._materials, ..._materials])
                          Padding(
                            padding: const EdgeInsets.only(bottom: itemSpacing),
                            child: Container(
                              width: itemSize,
                              height: itemSize,
                              padding: EdgeInsets.all(itemSize * 0.12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(itemSize * 0.14),
                                border: Border.all(color: const Color(0xFFf5dbb6), width: 4),
                              ),
                              child: Image.asset(m.asset, fit: BoxFit.contain),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}