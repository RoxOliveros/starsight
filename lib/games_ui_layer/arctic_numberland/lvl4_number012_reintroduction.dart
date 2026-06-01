import 'dart:async';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_level.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import '../goodjob_prompt.dart';
import 'lvl5_number012_recognition.dart';

enum _ScreenPhase { intro, miniGame }

class Number012ReintroductionScreen extends StatefulWidget {
  const Number012ReintroductionScreen({super.key});

  @override
  State<Number012ReintroductionScreen> createState() =>
      _Number012ReintroductionScreenState();
}

class _Number012ReintroductionScreenState
    extends State<Number012ReintroductionScreen>
    with TickerProviderStateMixin {
  int _currentNumber = 0;
  static const int _totalNumbers = 3;

  // Which dots have been tapped
  late List<bool> _dotsTapped;

  // Number bounce animation
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  // Number fade/scale in on new stage
  late AnimationController _enterController;
  late Animation<double> _enterAnim;

  // Dot wiggle controller (loops)
  late AnimationController _wiggleController;

  // Dot positions (randomized per round)
  late List<Offset> _dotOffsets;

  bool _allTapped = false;
  bool _transitioning = false;

  //Audio
  final AudioPlayer _player = AudioPlayer();

  // Dialog
  bool _showWinDialog = false;

  // Screen
  _ScreenPhase _screenPhase = _ScreenPhase.intro;

  // Animations
  late AnimationController _numberDanceCtrl;
  late Animation<double> _numberDance;

  // Pic & color theme per number
  static const _themes = [
    _NumberTheme(
      asset: 'assets/images/objects/arctic/earmuffs.png',
      label: 'ZERO',
    ),
    _NumberTheme(asset: 'assets/images/objects/arctic/ice.png', label: 'ONE'),
    _NumberTheme(
      asset: 'assets/images/objects/arctic/ice_skates.png',
      label: 'TWO',
    ),
  ];

  _NumberTheme get _theme => _themes[_currentNumber];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnim =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
        );

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _enterAnim = CurvedAnimation(
      parent: _enterController,
      curve: Curves.elasticOut,
    );

    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _numberDanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _numberDance = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _numberDanceCtrl, curve: Curves.easeInOut),
    );

    _startIntroFlow();
  }

  void _setupRound() {
    _dotsTapped = List.filled(_currentNumber == 0 ? 0 : _currentNumber, false);
    _allTapped = _currentNumber == 0;
    _transitioning = false;
    _dotOffsets = _generateDotOffsets(_currentNumber);
    _enterController.forward(from: 0);
    _bounceController.forward(from: 0);

    if (_currentNumber == 0) {
      Future.delayed(const Duration(milliseconds: 1800), _nextNumber);
    }
  }

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _playAudio('assets/audio/arctic_numberland/level4/012_reintro.wav');
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      _setupRound();
      setState(() => _screenPhase = _ScreenPhase.miniGame);
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

  // Generate non-overlapping dot positions in the right panel area
  List<Offset> _generateDotOffsets(int count) {
    final List<Offset> positions = [];
    final rand = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < count; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final jitterX = ((rand * (i + 1) * 31) % 20) - 10.0;
      final jitterY = ((rand * (i + 1) * 17) % 20) - 10.0;
      positions.add(
        Offset(
          30.0 + col * 90 + jitterX, // tighter columns
          20.0 + row * 90 + jitterY, // tighter rows
        ),
      );
    }
    return positions;
  }

  void _onDotTap(int index) {
    if (_dotsTapped[index] || _transitioning) return;
    setState(() => _dotsTapped[index] = true);
    _bounceController.forward(from: 0);

    final countSoFar = index + 1;
    _playAudio('assets/audio/arctic_numberland/$countSoFar.wav');

    final allDone = _dotsTapped.every((t) => t);
    if (allDone && !_allTapped) {
      setState(() => _allTapped = true);
      Future.delayed(const Duration(milliseconds: 1200), _nextNumber);
    }
  }

  void _nextNumber() {
    if (_transitioning) return;
    setState(() => _transitioning = true);

    if (_currentNumber >= _totalNumbers - 1) {
      setState(() => _showWinDialog = true);
      return;
    }

    _enterController.reverse().then((_) {
      setState(() {
        _currentNumber++;
        _setupRound();
      });
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _enterController.dispose();
    _wiggleController.dispose();
    _player.dispose();
    _numberDanceCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arctic background
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
                  _buildHeader(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _enterAnim,
                      child: Row(
                        children: [
                          // LEFT: Doma + Number showcase
                          Expanded(flex: 4, child: _buildNumberShowcase()),
                          Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          // RIGHT: Dot tapping area
                          Expanded(flex: 6, child: _buildDotArea()),
                        ],
                      ),
                    ),
                  ),
                  _buildProgressDots(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          ArcticBackButton(),
          const Spacer(),
          Text(
            'Number Introduction',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildNumberShowcase() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final boxSize = (h * 0.42).clamp(80.0, 140.0);
        final imageSize = (h * 0.18).clamp(28.0, 48.0);
        final numberSize = (boxSize * 0.64).clamp(50.0, 90.0);
        final labelFontSize = (h * 0.09).clamp(14.0, 22.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _bounceAnim,
              child: Image.asset(
                _theme.asset,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: h * 0.03),
            ScaleTransition(
              scale: _bounceAnim,
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: Center(
                  child: Image.asset(
                    'assets/fonts/game_numbers/$_currentNumber.png',
                    width: numberSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      '$_currentNumber',
                      style: TextStyle(
                        fontFamily: ArcticAppTextStyles.fredoka,
                        fontSize: numberSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: h * 0.04),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: h * 0.06,
                vertical: h * 0.02,
              ),
              decoration: BoxDecoration(
                color: ArcticColorTheme.cadetblue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _theme.label,
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDotArea() {
    final tappedCount = _dotsTapped.where((t) => t).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final dotSize = (h * 0.28).clamp(52.0, 80.0);
        final dotImageSize = (dotSize * 0.6).clamp(28.0, 50.0);
        final labelFontSize = (h * 0.07).clamp(13.0, 18.0);

        return Column(
          children: [
            SizedBox(height: h * 0.03),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: ArcticColorTheme.pictonblue.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👆', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    _allTapped
                        ? 'Great job!'
                        : 'Tap all the ${_theme.label}!  $tappedCount / $_currentNumber',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0x55003366),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: List.generate(_currentNumber, (i) {
                  final tapped = _dotsTapped[i];
                  return Positioned(
                    left: _dotOffsets[i].dx,
                    top: _dotOffsets[i].dy,
                    child: GestureDetector(
                      onTap: () => _onDotTap(i),
                      child: AnimatedBuilder(
                        animation: _wiggleController,
                        builder: (_, child) {
                          final wiggle = tapped
                              ? 0.0
                              : (_wiggleController.value - 0.5) *
                                    6 *
                                    ((i % 2 == 0) ? 1 : -1);
                          return Transform.translate(
                            offset: Offset(0, wiggle),
                            child: child,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: tapped ? dotSize * 0.9 : dotSize,
                          height: tapped ? dotSize * 0.9 : dotSize,
                          decoration: BoxDecoration(
                            color: tapped
                                ? ArcticColorTheme.cadetblue
                                : ArcticColorTheme.pictonblue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: ArcticColorTheme.pictonblue.withValues(
                                  alpha: tapped ? 0.2 : 0.5,
                                ),
                                blurRadius: tapped ? 4 : 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: tapped
                                ? Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: dotSize * 0.5,
                                  )
                                : Padding(
                                    padding: EdgeInsets.all(dotSize * 0.1),
                                    child: Image.asset(
                                      _theme.asset,
                                      width: dotImageSize,
                                      height: dotImageSize,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalNumbers, (i) {
        final done = i + 1 < _currentNumber;
        final current = i + 1 == _currentNumber;
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
          MaterialPageRoute(builder: (_) => const Number012RecognitionScreen()),
        );
      },
      onRestart: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const Number012ReintroductionScreen(),
          ),
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
                // LEFT — Doma
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

                // RIGHT — 0, 1, 2 dancing
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
          ),
        ),
      ],
    );
  }
}

class _NumberTheme {
  final String asset;
  final String label;

  const _NumberTheme({required this.asset, required this.label});
}
