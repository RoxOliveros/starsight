import 'dart:math';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_buttons.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../goodjob_prompt.dart';
import 'alphabet_game_ui.dart';
import 'alphabet_intro.dart';
import 'forest_audio_helper.dart';

class WoodpeckerLetterListenGame extends StatefulWidget {
  final int level;

  const WoodpeckerLetterListenGame({super.key, required this.level});

  @override
  State<WoodpeckerLetterListenGame> createState() =>
      _WoodpeckerLetterListenGameState();
}

class _WoodpeckerLetterListenGameState extends State<WoodpeckerLetterListenGame>
    with TickerProviderStateMixin, GameLoadingMixin, ForestAudioMixin, TofiReactionMixin {

  @override
  AudioPlayer get tofiPlayer => _player;

  final AudioPlayer _player = AudioPlayer();

  static const List<String> _letters = ['A', 'B', 'C'];

  late List<String> _shuffledLetters;
  late String _targetLetter;

  int _currentRound = 0;
  static const int _totalRounds = 5;

  double _currentHeightFraction = 1.0;
  double _targetHeightFraction = 1.0;

  // ── Woodpecker position/animation ──────────────────────────────────
  late AnimationController _hopController;
  late Animation<double> _hopAnimation;

  // Peck bounce (used both for correct pecks and wrong bounce-offs)
  late AnimationController _peckController;
  String? _activeTapLetter;
  bool _lastTapWasWrong = false;

  bool _introPlaying = true;
  late AnimationController _tofiFloatCtrl;

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();

    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _hopAnimation =
        CurvedAnimation(parent: _hopController, curve: Curves.easeOutBack)
          ..addListener(() {
            setState(() {
              _currentHeightFraction = lerpDouble(
                _currentHeightFraction,
                _targetHeightFraction,
                _hopAnimation.value,
              )!;
            });
          });

    _peckController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    finishLoading(_startIntroFlow);
    _loadRound();
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));

    await playVoice(
      'assets/audio/alphabet_forest/woodpecker_intro.wav',
    );

    if (!mounted) return;

    setState(() {
      _introPlaying = false;
    });

    // Let the game appear first.
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await playVoice(
      'assets/audio/alphabet_forest/woodpecker_instruction.wav',
    );

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 150));

    playVoice(ForestAudioAssets.forLetter(_targetLetter));
  }

  void _loadRound() {
    _shuffledLetters = List.from(_letters)..shuffle(Random());

    _targetLetter = _letters[Random().nextInt(_letters.length)];

    setState(() {});
  }

  double? lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _hopController.dispose();
    _peckController.dispose();
    _player.dispose();
    _tofiFloatCtrl.dispose();
    super.dispose();
  }

  void _onRungTapped(String letter) {
    setState(() {
      _activeTapLetter = letter;
      _lastTapWasWrong = letter != _targetLetter;
    });

    _peckController.forward(from: 0);

    if (letter == _targetLetter) {
      _handleCorrect();
    } else {
      _handleWrong();
    }
  }

  void _handleCorrect() {
    showTofiReaction(TofiState.correct);

    _currentRound++;

    _targetHeightFraction = 1.0 - (_currentRound / _totalRounds);

    _hopController.forward(from: 0);

    if (_currentRound >= _totalRounds) {
      Future.delayed(const Duration(milliseconds: 700), () async {
        if (!mounted) return;

        await ForestProgressService.instance.markLevelComplete(widget.level);

        if (!mounted) return;

        // Play the victory voice
        await playVoice(
          'assets/audio/alphabet_forest/woodpecker_win.wav',
        );

        if (!mounted) return;

        _showGoodJob();
      });
    }else {
      Future.delayed(const Duration(milliseconds: 700), () async {
        if (!mounted) return;

        _loadRound();

        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          playVoice(ForestAudioAssets.forLetter(_targetLetter));
        }
      });
    }

    setState(() {});
  }

  void _handleWrong() {
    showTofiReaction(TofiState.wrong);
  }

  void _showGoodJob() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) =>
          Material(
            type: MaterialType.transparency,
            child: GoodJobOverlay(
              characterImage: 'assets/images/characters/dog.png',
              closeButtonColor: ForestColorTheme.seagreen,
              onNext: () {
                Navigator.of(context).pop(); // close the dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => AlphabetIntroScreen(letter: 'D'),
                  ),
                );
              },
              onRestart: () {
                Navigator.of(context).pop(); // close the dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        WoodpeckerLetterListenGame(level: widget.level),
                  ),
                );
              },
              onBack: () {
                Navigator.of(context).pop(); // close the dialog
                Navigator.of(context).pop(); // pop Woodpecker → back to level screen
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.alphabetForest(),
        gameBuilder: () => Stack(
          children: [
            if (_introPlaying)
              _buildIntroLayer()
            else
              _buildGameContent(),

            if (!_introPlaying)
              buildTofi(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/bg_game_forest.png',
            fit: BoxFit.cover,
          ),
        ),

        const Positioned(
          top: 25,
          left: 20,
          child: ForestBackButton(),
        ),

        Positioned(
          top: 25,
          right: 20,
          child: ForestLevelBadge(level: widget.level),
        ),

        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _tofiFloatCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    0,
                    Tween<double>(
                      begin: -6,
                      end: 6,
                    ).evaluate(
                      CurvedAnimation(
                        parent: _tofiFloatCtrl,
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ),
                  child: child,
                ),
                child: Image.asset(
                  'assets/images/characters/dog.png',
                  height: screenH * .72,
                ),
              ),

              const SizedBox(width: 120),

              Image.asset(
                'assets/images/objects/forest/woodpecker.png',
                height: screenH * .45,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trunkHeight = constraints.maxHeight * 0.72;

        return Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                'assets/images/backgrounds/bg_game_forest.png',
                fit: BoxFit.cover,
              ),
            ),

            const Positioned(top: 25, left: 20, child: ForestBackButton()),

            Positioned(
              top: 25,
              left: 0,
              right: 0,
              child: Center(
                child: ForestInstructionBanner(
                  text: 'Tap the letter you hear!',
                ),
              ),
            ),

            Positioned(
              bottom: 15,
              left: 0,
              right: 0,
              child: _buildRoundIndicator(),
            ),

            Positioned(
              top: 25,
              right: 20,
              child: ForestLevelBadge(level: widget.level),
            ),

            Positioned(
              bottom: 0,
              right: 20,
              child: GestureDetector(
                onTap: () =>
                    playVoice(ForestAudioAssets.forLetter(_targetLetter)),
                child: Image.asset(
                  'assets/images/icons/speaker.png',
                  width: 90,
                  height: 90,
                ),
              ),
            ),

            // CENTER TREE + RIGHT LETTER CHOICES
            Positioned.fill(
              top: 90,
              bottom: 30,
              child: Row(
                children: [
                  // Empty left space so the tree stays centered
                  const Expanded(flex: 1, child: SizedBox()),

                  // CENTER TREE
                  Expanded(
                    flex: 2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/objects/lagoon/trunk.png',
                            fit: BoxFit.contain,
                          ),
                        ),

                        AnimatedBuilder(
                          animation: _hopController,
                          builder: (context, child) {
                            const topMin = 0.0;
                            final topMax = trunkHeight - 130;
                            final top =
                                topMin +
                                    (topMax - topMin) * _currentHeightFraction;

                            return Positioned(
                              top: top,
                              child: Image.asset(
                                'assets/images/objects/forest/woodpecker.png',
                                width: 90,
                                height: 90,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // RIGHT LETTER CHOICES
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _LetterRung(
                                letter: _shuffledLetters[0],
                                isActiveTap:
                                _activeTapLetter == _shuffledLetters[0],
                                isWrongBounce:
                                _lastTapWasWrong &&
                                    _activeTapLetter == _shuffledLetters[0],
                                peckController: _peckController,
                                onTap: () =>
                                    _onRungTapped(_shuffledLetters[0]),
                              ),
                              const SizedBox(width: 30),
                              _LetterRung(
                                letter: _shuffledLetters[1],
                                isActiveTap:
                                _activeTapLetter == _shuffledLetters[1],
                                isWrongBounce:
                                _lastTapWasWrong &&
                                    _activeTapLetter == _shuffledLetters[1],
                                peckController: _peckController,
                                onTap: () =>
                                    _onRungTapped(_shuffledLetters[1]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          _LetterRung(
                            letter: _shuffledLetters[2],
                            isActiveTap:
                            _activeTapLetter == _shuffledLetters[2],
                            isWrongBounce:
                            _lastTapWasWrong &&
                                _activeTapLetter == _shuffledLetters[2],
                            peckController: _peckController,
                            onTap: () => _onRungTapped(_shuffledLetters[2]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            buildTofi(context),
          ],
        );
      },
    );
  }

    Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _currentRound;
        final current = i == _currentRound && _currentRound < _totalRounds;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ForestColorTheme.darkseagreen
                : current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// _LetterRung — a single tappable carved letter on the trunk.
/// ─────────────────────────────────────────────────────────────────────────
class _LetterRung extends StatelessWidget {
  final String letter;
  final bool isActiveTap;
  final bool isWrongBounce;
  final AnimationController peckController;
  final VoidCallback? onTap;

  const _LetterRung({
    required this.letter,
    required this.isActiveTap,
    required this.isWrongBounce,
    required this.peckController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: peckController,
        builder: (context, child) {
          double offsetX = 0;
          double scale = 1.0;

          if (isActiveTap) {
            if (isWrongBounce) {
              // Harmless side-to-side bounce for a wrong tap.
              final t = peckController.value;
              offsetX = sin(t * pi * 3) * 6 * (1 - t);
            } else {
              // Quick "peck" squash-and-hop for a correct tap.
              final t = peckController.value;
              scale = 1.0 + (sin(t * pi) * 0.15);
            }
          }

          return Transform.translate(
            offset: Offset(offsetX, 0),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6B4226), // carved bark color
            border: Border.all(color: const Color(0xFF4A2C17), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF4E4C1),
            ),
          ),
        ),
      ),
    );
  }
}
