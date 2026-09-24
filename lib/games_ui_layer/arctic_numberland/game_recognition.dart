import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import 'arctic_game_ui.dart';
import 'doma_reaction.dart';
import 'goodjob_doma_prompt.dart';
import 'game_12_counting.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';

enum _ScreenPhase { intro, miniGame }

class Number012RecognitionScreen extends StatefulWidget {
  final int level;

  const Number012RecognitionScreen({super.key, required this.level});

  @override
  State<Number012RecognitionScreen> createState() =>
      _Number012RecognitionScreenState();
}

class _Number012RecognitionScreenState extends State<Number012RecognitionScreen>
    with TickerProviderStateMixin, GameLoadingMixin, DomaReactionMixin, AiCameraMixin{
  @override
  AudioPlayer get domaPlayer => _player;

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const String _domaImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _speakerImage = 'assets/images/icons/speaker.png';

  static const String _audioIntro = 'assets/audio/arctic_numberland/012_recog_intro.wav';
  static const String _audioInstruction = 'assets/audio/arctic_numberland/012_recog_instruction.wav';

  static const String _audioBubblePop = 'assets/audio/sound_effects/bubble_pop.wav';

  late int _correctNumber;
  late List<int> _choices;
  int? _tappedIndex;
  int _round = 1;
  static const int _totalRounds = 5;
  bool _showWinDialog = false;
  bool _isInputLocked = true;

  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  final AudioPlayer _player = AudioPlayer();

  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  // --- ADDED TRACKING VARIABLES ---
  final GameTapTracker _tapTracker = GameTapTracker();
  bool _hideLightingCard = false;

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

    // Pause for face detection ONLY if this happens to be used as level 1
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

    _generateRound();
  }

  @override
  void dispose() {
    disposeAiCamera(); 
    _numberDanceCtrl.dispose();
    _player.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _generateRound() {
    final all = [0, 1, 2]..shuffle();

    _correctNumber = all.first;
    _choices = [0, 1, 2]..shuffle();
    _tappedIndex = null;
  }

  void _onChoiceTap(int index) async {
    if (_isInputLocked || _tappedIndex != null) return;

    setState(() {
      _isInputLocked = true;
    });

    if (_choices[index] == _correctNumber) {
      _tapTracker.recordCorrectTap();

      setState(() => _tappedIndex = index);
      showDomaReaction(DomaState.correct);
      await Future.delayed(const Duration(milliseconds: 1000));
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

        await Future.delayed(const Duration(milliseconds: 300));

        await _playCurrentNumber();

        if (mounted) {
          setState(() {
            _isInputLocked = false;
          });
        }
      }
    } else {
      _tapTracker.recordMistake();

      setState(() => _tappedIndex = index);

      await _playAudio(_audioBubblePop);

      showDomaReaction(DomaState.wrong);

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() {
          _tappedIndex = null;
          _isInputLocked = false;
        });
      }
    }
  }

  Future<void> _playCurrentNumber() async {
    await _playAudio(
      'assets/audio/arctic_numberland/$_correctNumber.wav',
    );
  }

  Future<void> _onSpeakerTap() async {
    if (_isInputLocked || _tappedIndex != null) return;

    if (mounted) {
      setState(() => _isInputLocked = true);
    }

    await _playCurrentNumber();

    if (mounted) {
      setState(() => _isInputLocked = false);
    }
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      setState(() => _isInputLocked = true);
    }

    await _playAudio(_audioIntro);

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      setState(() => _screenPhase = _ScreenPhase.miniGame);
    }

    await Future.delayed(const Duration(milliseconds: 500));

    await _playAudio(_audioInstruction);

    await Future.delayed(const Duration(milliseconds: 300));

    await _playCurrentNumber();

    if (mounted) {
      setState(() => _isInputLocked = false);
    }
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
    if (_choices[index] == _correctNumber) return ArcticColorTheme.pictonblue;
    if (_tappedIndex == index) return ArcticColorTheme.slateblue;
    return ArcticColorTheme.slateblue;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _tapTracker.recordGenericTap(),
      child: Scaffold(
        body: buildWithLoading(
          loadingScreen: LoadingScreen.arctic(),
          gameBuilder: () => Stack(
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
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 25,
                        right: 25,
                        top: 25,
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
                            child: ArcticLevelBadge(level: widget.level),
                          ),
                        ],
                      ),
                    ),

                    // --- MAIN CONTENT ---
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _isInputLocked ? null : _onSpeakerTap,
                            child: Container(
                              width: 160,
                              decoration: BoxDecoration(
                                color: ArcticColorTheme.pictonblue,
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: ArcticColorTheme.slateblue,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ArcticColorTheme.pictonblue.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Image.asset(
                                _speakerImage,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                const Icon(Icons.volume_up, color: Colors.white, size: 40),
                              ),
                            ),
                          ),

                          // CHOICES GRID
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_choices.length, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: GestureDetector(
                                  onTap: _isInputLocked
                                      ? null
                                      : () => _onChoiceTap(index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: _choiceColor(index),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: _choiceBorderColor(index),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _choiceColor(index).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Image.asset(
                                        'assets/fonts/game_numbers/${_choices[index]}.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            '${_choices[index]}',
                                            style: const TextStyle(
                                              fontFamily: ArcticAppTextStyles.fredoka,
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: ArcticColorTheme.cotton,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    _buildProgressDots(),

                    const SizedBox(height: 15),
                  ],
                ),

              if (_screenPhase == _ScreenPhase.miniGame) buildDoma(context),
              if (_showWinDialog)
                Positioned.fill(child: _buildGoodJobOverlay()),

              // --- ADDED LIGHTING PROMPT CARD ---
              if (widget.level == 1 && !isFaceDetected && !_hideLightingCard)
                Positioned.fill(
                  child: LightingPromptCard(
                    onClose: () {
                      setState(() {
                        isFaceDetected = true;
                        _hideLightingCard = true;
                      });
                      onFirstFaceDetected?.call();
                      onFirstFaceDetected = null;
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
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
            builder: (_) =>
                Number012CountingObjectsScreen(level: widget.level + 1),
          ),
        );
      },
      onRestart: () {
        Navigator.pop(context, Number012RecognitionScreen(level: widget.level));
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
              mainAxisAlignment: MainAxisAlignment.center,
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
            shadows: const [
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
