import 'dart:async';
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
import 'number012_counting.dart';

enum _ScreenPhase { intro, miniGame }

class Number012RecognitionScreen extends StatefulWidget {
  final int level;

  const Number012RecognitionScreen({super.key, required this.level});

  @override
  State<Number012RecognitionScreen> createState() =>
      _Number012RecognitionScreenState();
}

class _Number012RecognitionScreenState extends State<Number012RecognitionScreen>
    with TickerProviderStateMixin, GameLoadingMixin, DomaReactionMixin {

  @override
  AudioPlayer get domaPlayer => _player;

  late int _correctNumber;
  late List<int> _choices;
  int? _tappedIndex;
  int _round = 1;
  static const int _totalRounds = 5;
  bool _showWinDialog = false;
  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  final AudioPlayer _player = AudioPlayer();

  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

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

    finishLoading(_startIntroFlow);

    _generateRound();
  }

  @override
  void dispose() {
    _numberDanceCtrl.dispose();
    _player.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _generateRound() {
    final all = [0, 1, 2]..shuffle();
    _correctNumber = all.first;
    _choices = [0, 1, 2]..shuffle();
    setState(() => _tappedIndex = null);
  }

  void _onChoiceTap(int index) async {
    if (_tappedIndex != null) return;

    if (_choices[index] == _correctNumber) {
      setState(() => _tappedIndex = index);
      await _playAudio('assets/audio/arctic_numberland/$_correctNumber.wav');
      showDomaReaction(DomaState.correct);
      await Future.delayed(const Duration(milliseconds: 900));
      if (_round >= _totalRounds) {
        await ArcticProgressService.instance.markLevelComplete(widget.level);
        setState(() => _showWinDialog = true);
      } else {
        setState(() {
          _round++;
          _generateRound();
        });
      }
    } else {
      setState(() => _tappedIndex = index);
      await _playAudio('assets/audio/sound_effects/bubble_pop.wav');
      showDomaReaction(DomaState.wrong);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _tappedIndex = null);
    }
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _playAudio('assets/audio/arctic_numberland/level5/012_recog.wav');
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _screenPhase = _ScreenPhase.miniGame);
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
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.arctic(),
        gameBuilder: () => Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/backgrounds/bg_game_arctic.png',
                fit: BoxFit.cover,
              ),
            ),
            if (_screenPhase == _ScreenPhase.intro)
              _buildIntroLayer()
            else
              Column(
                children: [
                  // --- HEADER ---
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, top: 25),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ArcticBackButton(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ArcticLevelBadge(level: widget.level),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8,),
                          decoration: BoxDecoration(
                            color: ArcticColorTheme.pictonblue.withValues(
                                alpha: 0.92),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: ArcticColorTheme.pictonblue.withValues(
                                    alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Tap the number you see!',
                            style: TextStyle(
                              fontFamily: ArcticAppTextStyles.fredoka,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- MAIN CONTENT ---
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // BIG NUMBER CARD
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: ArcticColorTheme.cotton,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: ArcticColorTheme.pictonblue,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ArcticColorTheme.pictonblue
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/fonts/game_numbers/$_correctNumber.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  Center(
                                    child: Text(
                                      '$_correctNumber',
                                      style: const TextStyle(
                                        fontFamily: ArcticAppTextStyles.fredoka,
                                        fontSize: 100,
                                        fontWeight: FontWeight.bold,
                                        color: ArcticColorTheme.cadetblue,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                            ),
                          ),
                        ),

                        // CHOICES GRID
                        SizedBox(
                          width: 280,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.3,
                            ),
                            itemCount: _choices.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () => _onChoiceTap(index),
                                child: AnimatedContainer(
                                  duration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _choiceColor(index),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _choiceBorderColor(index),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _choiceColor(
                                          index,
                                        ).withValues(alpha: 0.35),
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
                                      errorBuilder: (_, __, ___) =>
                                          Center(
                                            child: Text(
                                              '${_choices[index]}',
                                              style: const TextStyle(
                                                fontFamily:
                                                ArcticAppTextStyles.fredoka,
                                                fontSize: 40,
                                                fontWeight: FontWeight.bold,
                                                color: ArcticColorTheme.cotton,
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
                      ],
                    ),
                  ),

                  _buildProgressDots(),

                  const SizedBox(height: 15),
                ],
              ),

            if (_screenPhase == _ScreenPhase.miniGame) buildDoma(context),
            if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
          ],
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
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Number012CountingObjectsScreen(
              level: widget.level + 1,
            ),
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
          Positioned(top: 25, left: 20, child: ArcticBackButton()),
          Positioned(top: 25, right: 20, child: ArcticLevelBadge(level: widget.level)),
          Positioned.fill(
            top: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/characters/doma_the_penguin.png',
                      height: MediaQuery
                          .of(context)
                          .size
                          .height * 0.65,
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
