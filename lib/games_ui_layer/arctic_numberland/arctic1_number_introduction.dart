import 'dart:async';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';

class NumberIntroductionScreen extends StatefulWidget {
  const NumberIntroductionScreen({super.key});

  @override
  State<NumberIntroductionScreen> createState() =>
      _NumberIntroductionScreenState();
}

class _NumberIntroductionScreenState extends State<NumberIntroductionScreen>
    with TickerProviderStateMixin {
  int _currentNumber = 1;
  static const int _totalNumbers = 5;

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

  // Pic & color theme per number
  static const _themes = [
    _NumberTheme(asset: 'assets/images/objects/ball.png',       label: 'ONE'),
    _NumberTheme(asset: 'assets/images/objects/car.png',        label: 'TWO'),
    _NumberTheme(asset: 'assets/images/objects/lamp.png',       label: 'THREE'),
    _NumberTheme(asset: 'assets/images/objects/teddybear.png',  label: 'FOUR'),
    _NumberTheme(asset: 'assets/images/objects/plant.png',      label: 'FIVE'),
  ];

  _NumberTheme get _theme => _themes[_currentNumber - 1];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _enterAnim = CurvedAnimation(parent: _enterController, curve: Curves.elasticOut);

    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _setupRound();
  }

  void _setupRound() {
    _dotsTapped = List.filled(_currentNumber, false);
    _allTapped = false;
    _transitioning = false;
    _dotOffsets = _generateDotOffsets(_currentNumber);
    _enterController.forward(from: 0);
    _bounceController.forward(from: 0);
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
      positions.add(Offset(
        30.0 + col * 90 + jitterX,   // tighter columns
        20.0 + row * 90 + jitterY,   // tighter rows
      ));
    }
    return positions;
  }

  void _onDotTap(int index) {
    if (_dotsTapped[index] || _transitioning) return;
    setState(() => _dotsTapped[index] = true);
    _bounceController.forward(from: 0);

    final allDone = _dotsTapped.every((t) => t);
    if (allDone && !_allTapped) {
      setState(() => _allTapped = true);
      Future.delayed(const Duration(milliseconds: 1200), _nextNumber);
    }
  }

  void _nextNumber() {
    if (_transitioning) return;
    setState(() => _transitioning = true);

    if (_currentNumber >= _totalNumbers) {
      _showEndDialog();
      return;
    }

    _enterController.reverse().then((_) {
      setState(() {
        _currentNumber++;
        _setupRound();
      });
    });
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                const Text(
                  'You know your numbers!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ArcticColorTheme.cadetblue,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1 · 2 · 3 · 4 · 5',
                  style: TextStyle(
                    fontFamily: ArcticAppTextStyles.fredoka,
                    fontSize: 18,
                    color: ArcticColorTheme.pictonblue,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArcticColorTheme.pictonblue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentNumber = 1;
                      _transitioning = false;
                      _setupRound();
                    });
                  },
                  child: const Text(
                    'Play Again',
                    style: TextStyle(
                      fontFamily: ArcticAppTextStyles.fredoka,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _enterController.dispose();
    _wiggleController.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _enterAnim,
                child: Row(
                  children: [
                    // LEFT: Number showcase
                    Expanded(flex: 4, child: _buildNumberShowcase()),
                    // Divider
                    Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      color: ArcticColorTheme.pictonblue.withValues(alpha: 0.3),
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
              color: ArcticColorTheme.cadetblue,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // balance back button
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
              child: Image.asset(_theme.asset, width: imageSize, height: imageSize, fit: BoxFit.contain),
            ),
            SizedBox(height: h * 0.03),
            ScaleTransition(
              scale: _bounceAnim,
              child: Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  color: ArcticColorTheme.pictonblue,
                  borderRadius: BorderRadius.circular(boxSize * 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: ArcticColorTheme.pictonblue.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
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
              padding: EdgeInsets.symmetric(horizontal: h * 0.06, vertical: h * 0.02),
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
        final countFontSize = (h * 0.06).clamp(11.0, 15.0);

        return Column(
          children: [
            SizedBox(height: h * 0.03),
            Text(
              _allTapped ? ' Great job!' : 'Tap all the ${_theme.label}!',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: labelFontSize,
                color: _allTapped ? ArcticColorTheme.cadetblue : ArcticColorTheme.slateblue,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$tappedCount / $_currentNumber',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: countFontSize,
                color: ArcticColorTheme.pictonblue,
                fontWeight: FontWeight.bold,
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
                              : (_wiggleController.value - 0.5) * 6 * ((i % 2 == 0) ? 1 : -1);
                          return Transform.translate(offset: Offset(0, wiggle), child: child);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: tapped ? dotSize * 0.9 : dotSize,
                          height: tapped ? dotSize * 0.9 : dotSize,
                          decoration: BoxDecoration(
                            color: tapped ? ArcticColorTheme.cadetblue : ArcticColorTheme.pictonblue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: ArcticColorTheme.pictonblue.withValues(alpha: tapped ? 0.2 : 0.5),
                                blurRadius: tapped ? 4 : 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: tapped
                                ? Icon(Icons.check_rounded, color: Colors.white, size: dotSize * 0.5)
                                : Padding(
                              padding: EdgeInsets.all(dotSize * 0.1),
                              child: Image.asset(_theme.asset, width: dotImageSize, height: dotImageSize, fit: BoxFit.contain),
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
}

class _NumberTheme {
  final String asset;
  final String label;

  const _NumberTheme({
    required this.asset,
    required this.label,
  });
}