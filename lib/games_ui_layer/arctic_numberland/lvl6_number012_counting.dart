import 'package:flutter/material.dart';
import '../../business_layer/orientation_service.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../goodjob_prompt.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import 'lvl7_number012_matching.dart';

enum _ScreenPhase { intro, miniGame }

class Number012CountingObjectsScreen extends StatefulWidget {
  const Number012CountingObjectsScreen({super.key});

  @override
  State<Number012CountingObjectsScreen> createState() =>
      _Number012CountingObjectsScreenState();
}

class _Number012CountingObjectsScreenState
    extends State<Number012CountingObjectsScreen>
    with TickerProviderStateMixin {
  late int _correctCount;
  late List<int> _choices;
  late String _currentObject;
  int? _tappedIndex;
  int _round = 1;
  static const int _totalRounds = 5;

  _ScreenPhase _screenPhase = _ScreenPhase.intro;
  bool _showWinDialog = false;
  final AudioPlayer _player = AudioPlayer();

  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  final List<Map<String, String>> _objects = [
    {'name': 'Earmuffs', 'asset': 'assets/images/objects/arctic/earmuffs.png'},
    {'name': 'Ice', 'asset': 'assets/images/objects/arctic/ice.png'},
    {
      'name': 'Ice Skates',
      'asset': 'assets/images/objects/arctic/ice_skates.png',
    },
    {'name': 'Ice Cream', 'asset': 'assets/images/objects/arctic/icecream.png'},
    {'name': 'Igloo', 'asset': 'assets/images/objects/arctic/igloo.png'},
    {'name': 'Sled', 'asset': 'assets/images/objects/arctic/sled.png'},
    {'name': 'Snowball', 'asset': 'assets/images/objects/arctic/snowball.png'},
    {
      'name': 'Snow Globe',
      'asset': 'assets/images/objects/arctic/snowglobe.png',
    },
    {'name': 'Snowman', 'asset': 'assets/images/objects/arctic/snowman.png'},
    {
      'name': 'Snowy Sign Board',
      'asset': 'assets/images/objects/arctic/snowy_signboard.png',
    },
    {
      'name': 'Snowy Tree',
      'asset': 'assets/images/objects/arctic/snowy_tree.png',
    },
    {
      'name': 'Candy Cane',
      'asset': 'assets/images/objects/arctic/candy_cane.png',
    },
    {
      'name': 'Winter Hat',
      'asset': 'assets/images/objects/arctic/winter_hat.png',
    },
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

    _startIntroFlow();
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
    final allNumbers = [0, 1, 2]..shuffle();
    _correctCount = allNumbers.first;

    final wrong = allNumbers.skip(1).take(3).toList();
    _choices = [...wrong, _correctCount]..shuffle();

    final obj = (_objects..shuffle()).first;
    _currentObject = obj['asset']!;

    setState(() => _tappedIndex = null);
  }

  void _onChoiceTap(int index) async {
    if (_tappedIndex != null) return;
    setState(() => _tappedIndex = index);

    if (_choices[index] == _correctCount) {
      _playAudio('assets/audio/bubble_pop.wav');
    }

    await Future.delayed(const Duration(milliseconds: 900));
    if (_round >= _totalRounds) {
      setState(() => _showWinDialog = true);
    } else {
      setState(() {
        _round++;
        _generateRound();
      });
    }
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _playAudio('assets/audio/arctic/level6/012_counting.wav');
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

  // Unselected → pictonblue | correct → green | wrong tap → red
  Color _choiceColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.pictonblue;
    if (_choices[index] == _correctCount) return Colors.green;
    if (_tappedIndex == index) return Colors.red;
    return ArcticColorTheme.pictonblue;
  }

  Color _choiceBorderColor(int index) {
    if (_tappedIndex == null) return ArcticColorTheme.slateblue;
    if (_choices[index] == _correctCount) return ArcticColorTheme.pictonblue;
    if (_tappedIndex == index) return ArcticColorTheme.slateblue;
    return ArcticColorTheme.slateblue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcticColorTheme.lightgrayishcyan,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_arctic.png',
              fit: BoxFit.cover,
            ),
          ),
          if (_screenPhase == _ScreenPhase.intro)
            _buildIntroContent()
          else
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // --- HEADER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ArcticBackButton(),
                        ),
                        const Text(
                          'Counting Objects',
                          style: TextStyle(
                            fontFamily: ArcticAppTextStyles.fredoka,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Text(
                    'How many are there?',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- MAIN CONTENT ---
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // OBJECTS DISPLAY BOX
                        Container(
                          width: 340,
                          height: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: ArcticColorTheme.cotton,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: ArcticColorTheme.pictonblue,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ArcticColorTheme.pictonblue.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildObjectGrid(),
                          ),
                        ),

                        // CHOICES
                        SizedBox(
                          width: 300,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 1.4,
                                ),
                            itemCount: _choices.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () => _onChoiceTap(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
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
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          '${_choices[index]}',
                                          style: const TextStyle(
                                            fontFamily:
                                                ArcticAppTextStyles.fredoka,
                                            fontSize: 36,
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
                  const SizedBox(height: 16),

                  _buildProgressDots(),
                ],
              ),
            ),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  Widget _buildObjectGrid() {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: List.generate(_correctCount, (i) {
        return Image.asset(
          _currentObject,
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Text('🍎', style: TextStyle(fontSize: 48)),
        );
      }),
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
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/doma_the_penguin.png',
      closeButtonColor: ArcticColorTheme.slateblue,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number012MatchingScreen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Number012CountingObjectsScreen()),
        );
      },
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ArcticLevelScreen()),
              (route) => route.isFirst,
        );
      },
    );
  }

  Widget _buildIntroContent() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(top: 8, left: 12, child: ArcticBackButton()),
          Positioned.fill(
            top: 50,
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/characters/doma_the_penguin.png',
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
                              padding: const EdgeInsets.symmetric(horizontal: 12),
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
            shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
          ),
        ),
      ],
    );
  }
}
