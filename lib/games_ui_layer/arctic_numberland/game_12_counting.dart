import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'game_counttap.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

enum _ScreenPhase { intro, miniGame }

class Number12CountingObjectsScreen extends StatefulWidget {
  final int level;

  const Number12CountingObjectsScreen({super.key, required this.level});

  @override
  State<Number12CountingObjectsScreen> createState() => _Number12CountingObjectsScreenState();
}

class _Number12CountingObjectsScreenState
    extends State<Number12CountingObjectsScreen>
    with TickerProviderStateMixin, DomaReactionMixin, GameLoadingMixin, AiCameraMixin {
  @override
  AudioPlayer get domaPlayer => _player;

  static const String _domaImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/012_counting_intro.wav';
  static const String _audioInstruction = 'assets/audio/arctic_numberland/012_counting_instruction.wav';
  static const String _audioBubblePop = 'assets/audio/sound_effects/bubble_pop.wav';

  late int _correctCount;
  late List<int> _choices;
  late String _currentObject;
  int? _tappedIndex;
  int _round = 1;
  static const int _totalRounds = 5;

  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  bool _showWinDialog = false;
  bool _canTapChoices = false;
  final AudioPlayer _player = AudioPlayer();

  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  // --- ADDED TRACKING VARIABLES ---
  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;
  bool _loadingScreenElapsed = false;
  Timer? _minLoadTimer;

  final List<Map<String, String>> _objects = [
    {'name': 'Earmuffs', 'asset': 'assets/images/objects/arctic/earmuffs.png'},
    {'name': 'Ice', 'asset': 'assets/images/objects/arctic/ice.png'},
    {'name': 'Ice Skates', 'asset': 'assets/images/objects/arctic/ice_skates.png',},
    {'name': 'Ice Cream', 'asset': 'assets/images/objects/arctic/icecream.png'},
    {'name': 'Igloo', 'asset': 'assets/images/objects/arctic/igloo.png'},
    {'name': 'Sled', 'asset': 'assets/images/objects/arctic/sled.png'},
    {'name': 'Snowball', 'asset': 'assets/images/objects/arctic/snowball.png'},
    {'name': 'Snow Globe', 'asset': 'assets/images/objects/arctic/snowglobe.png',},
    {'name': 'Snowman', 'asset': 'assets/images/objects/arctic/snowman.png'},
    {'name': 'Snowy Sign Board', 'asset': 'assets/images/objects/arctic/snowy_signboard.png',},
    {'name': 'Snowy Tree', 'asset': 'assets/images/objects/arctic/snowy_tree.png',},
    {'name': 'Candy Cane', 'asset': 'assets/images/objects/arctic/candy_cane.png',},
    {'name': 'Winter Hat', 'asset': 'assets/images/objects/arctic/winter_hat.png',},
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) {
        setState(() => _hideLightingCard = false);
      }
    };

    _minLoadTimer = Timer(minLoadTime, () {
      if (mounted) setState(() => _loadingScreenElapsed = true);
    });

    if (widget.level == 1) {
      onFirstFaceDetected = () {
        finishLoading(_startIntroFlow);
      };
      if (isFaceDetected) {
        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;
      }
    } else {
      finishLoading(_startIntroFlow);
    }

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) {
        setState(() => _hideLightingCard = false);
      }
    };

    _generateRound();
  }

  @override
  void dispose() {
    disposeAiCamera(); 
    _minLoadTimer?.cancel();
    _numberDanceCtrl.dispose();
    _player.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _generateRound() {
    final allNumbers = [1, 2]..shuffle();

    _correctCount = allNumbers.first;

    _choices = List<int>.from(allNumbers)..shuffle();

    final obj = (_objects..shuffle()).first;
    _currentObject = obj['asset']!;

    _tappedIndex = null;
  }

  void _onChoiceTap(int index) async {
    if (!_canTapChoices || _tappedIndex != null) {
      return;
    }

    if (_choices[index] == _correctCount) {
      _tapTracker.recordCorrectTap();

      setState(() => _tappedIndex = index);
      await _playAudio('assets/audio/arctic_numberland/$_correctCount.wav');
      showDomaReaction(DomaState.correct);
      await Future.delayed(const Duration(milliseconds: 900));
      if (_round >= _totalRounds) {
        List<String> finalEmotions = stopAiCamera();

        try {
          ArcticDatabaseService.saveGameData(
            gameId: 'arctic_numberland_${widget.level}',
            mistakes: _tapTracker.mistakeCount,
            emotions: finalEmotions,
          );
        } catch (e) {
          debugPrint("Database Error saving Arctic metrics: $e");
        }

        ArcticProgressService.instance.markLevelComplete(widget.level);
        setState(() => _showWinDialog = true);
      } else {
        setState(() {
          _round++;
          _generateRound();
        });
      }
    } else {
      _tapTracker.recordMistake();
      setState(() => _tappedIndex = index);

      await _playAudio(_audioBubblePop);
      showDomaReaction(DomaState.wrong);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _tappedIndex = null);
    }
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(
      const Duration(milliseconds: 400),
    );

    await _playAudio(_audioIntro);

    if (!mounted) return;

    setState(() {
      _screenPhase = _ScreenPhase.miniGame;
      _canTapChoices = false;
    });

    await Future.delayed(
      const Duration(milliseconds: 400),
    );

    await _playAudio(_audioInstruction);

    if (!mounted) return;

    setState(() {
      _canTapChoices = true;
    });
  }

  Future<void> _playAudio(String asset) async {
    try {
      final completer = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await completer.future;
      await sub.cancel();
    } catch (e) {
      debugPrint('Audio error ($asset): $e');
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Color _choiceColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.pictonblue;
    return ArcticColorTheme.pictonblue;
  }

  Color _choiceBorderColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.slateblue;
    return ArcticColorTheme.slateblue;
  }

  @override
  Widget build(BuildContext context) {
    final gateNeedsLightingPrompt = widget.level == 1 && !isFaceDetected;
    final reactiveNeedsLightingPrompt =
        hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard;

    Widget reactiveLightingCard() =>
        LightingPromptCard(
          onClose: () => setState(() => _hideLightingCard = true),
        );

    final loadingSlot = (_loadingScreenElapsed && gateNeedsLightingPrompt)
        ? LightingPromptCard(
      onClose: () {
        setState(() => isFaceDetected = true);
        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;
      },
    )
        : LoadingScreen.arctic();

    return Listener(
      onPointerDown: (_) => _tapTracker.recordGenericTap(),
      child: Scaffold(
        backgroundColor: ArcticColorTheme.lightgrayishcyan,
        body: buildWithLoading(
          loadingScreen: loadingSlot,
          gameBuilder: () {
            final gameContent = Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    _bgImage,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_screenPhase == _ScreenPhase.intro)
                  _buildIntroLayer()
                else
                  Stack(
                    children: [
                      Column(
                        children: [
                          // HEADER
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 25,
                            ),
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ArcticXButton(),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ArcticLevelBadge(
                                    level: widget.level,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // MAIN CONTENT
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 150,
                                right: 150,

                                // Leave room for progress dots.
                                bottom: 30,
                              ),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.center,
                                children: [
                                  // OBJECT BOX
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      height: double.infinity,
                                      margin: const EdgeInsets.only(
                                        bottom: 16,
                                        left: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ArcticColorTheme.cotton,
                                        borderRadius:
                                        BorderRadius.circular(24),
                                        border: Border.all(
                                          color:
                                          ArcticColorTheme.pictonblue,
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: ArcticColorTheme
                                                .pictonblue
                                                .withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding:
                                        const EdgeInsets.all(16),
                                        child: _buildObjectGrid(),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 30),

                                  // CHOICES
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding:
                                      const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: List.generate(
                                          _choices.length,
                                              (index) {
                                            return Expanded(
                                              child: Padding(
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                  vertical: 7,
                                                ),
                                                child: GestureDetector(
                                                  onTap: _canTapChoices
                                                      ? () =>
                                                      _onChoiceTap(
                                                        index,
                                                      )
                                                      : null,
                                                  child:
                                                  AnimatedContainer(
                                                    duration:
                                                    const Duration(
                                                      milliseconds: 250,
                                                    ),
                                                    width:
                                                    double.infinity,
                                                    decoration:
                                                    BoxDecoration(
                                                      color:
                                                      _choiceColor(
                                                        index,
                                                      ),
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                        18,
                                                      ),
                                                      border:
                                                      Border.all(
                                                        color:
                                                        _choiceBorderColor(
                                                          index,
                                                        ),
                                                        width: 3,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .all(
                                                          10,
                                                        ),
                                                        child:
                                                        Image.asset(
                                                          'assets/fonts/game_numbers/${_choices[index]}.png',
                                                          fit: BoxFit
                                                              .contain,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
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
                            ),
                          ),
                        ],
                      ),

                      // PROGRESS DOTS
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 15,
                        child: Center(
                          child: _buildProgressDots(),
                        ),
                      ),
                    ],
                  ),


                if (_screenPhase == _ScreenPhase.miniGame) buildDoma(context),
                if (_showWinDialog)
                  Positioned.fill(child: _buildGoodJobOverlay()),
              ],
            );
            return reactiveNeedsLightingPrompt
                ? Stack(
              children: [
                Positioned.fill(child: gameContent),
                Positioned.fill(child: reactiveLightingCard()),
              ],
            )
                : gameContent;
          },
        ),
      ),
    );
  }

  Widget _buildObjectGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final objSize = MediaQuery.of(context).size.height * 0.30;
        return Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_correctCount, (i) {
            return Image.asset(
              _currentObject,
              width: objSize,
              height: objSize,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text('🍎', style: TextStyle(fontSize: 48)),
            );
          }),
        );
      },
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i + 1 < _round;
        final current = i + 1 == _round;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? ArcticColorTheme.cadetblue
                : current
                ? ArcticColorTheme.pictonblue
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildGoodJobOverlay() {
    return DomaGoodJobOverlay(
      characterImage: _domaImage,
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Number012TapCountScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pop(
          context,
          Number12CountingObjectsScreen(level: widget.level),
        );
      },
      onBack: () {
        Navigator.pop(context);
      },
    );
  }

  Widget _buildIntroLayer() {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Stack(
        children: [
          Positioned(top: 25, left: 25, child: ArcticXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: ArcticLevelBadge(level: widget.level),
          ),
          Positioned.fill(
            top: 50,
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(
                      _domaImage,
                      height: MediaQuery.of(context).size.height * 0.65,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Text('🐧', style: TextStyle(fontSize: 60)),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _numberDanceCtrl,
                      builder: (_, __) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final angle =
                                _numberDance.value * ((i % 2 == 0) ? 1 : -1);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Transform.rotate(
                                angle: angle,
                                child: _buildIntroNumberCard(i),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroNumberCard(int number) {
    final size = MediaQuery.of(context).size.height * 0.28;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Image.asset(
              'assets/fonts/game_numbers/$number.png',
              width: size * 0.64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                '$number',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ['ZERO', 'ONE', 'TWO'][number],
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
