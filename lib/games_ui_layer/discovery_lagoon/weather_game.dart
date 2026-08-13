import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';

enum KikiState { normal, correct, wrong }

class WeatherGame extends StatefulWidget {
  const WeatherGame({Key? key}) : super(key: key);

  @override
  _WeatherGameState createState() => _WeatherGameState();
}

class _WeatherGameState extends State<WeatherGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  KikiState _kikiState = KikiState.normal;
  int currentLevelIndex = 0;
  bool _isGameComplete = false; // Tracks if the final level is finished

  final List<Map<String, String>> levelSequence = [
    {'bg': 'assets/images/backgrounds/bg_park_sunny.png', 'target': 'sunny'},
    {'bg': 'assets/images/backgrounds/bg_lake_rainy.png', 'target': 'rainy'},
    {'bg': 'assets/images/backgrounds/bg_beach_sunny.png', 'target': 'sunny'},
    {
      'bg': 'assets/images/backgrounds/bg_school_cloudy.png',
      'target': 'cloudy',
    },
    {'bg': 'assets/images/backgrounds/bg_fields_windy.png', 'target': 'windy'},
    {'bg': 'assets/images/backgrounds/bg_town_rainy.png', 'target': 'rainy'},
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _playAudio(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource(assetPath.replaceFirst('assets/', '')),
      );
    } catch (e) {
      debugPrint('Audio error ($assetPath): $e');
    }
  }

  Future<void> handleAnswer(String selectedWeather) async {
    // Prevent multiple clicks while Kiki is reacting or if the game is over
    if (_kikiState != KikiState.normal || _isGameComplete) return;

    String currentTarget = levelSequence[currentLevelIndex]['target']!;

    if (selectedWeather == currentTarget) {
      setState(() {
        _kikiState = KikiState.correct;
      });
      _playAudio('assets/audio/sound_effects/shine.wav');

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _kikiState = KikiState.normal;
          if (currentLevelIndex < levelSequence.length - 1) {
            currentLevelIndex++;
          } else {
            // Trigger the overlay on the last level
            _isGameComplete = true;
          }
        });
      }
    } else {
      setState(() {
        _kikiState = KikiState.wrong;
      });
      _playAudio('assets/audio/discovery_lagoon/kiki_tryagain.wav');

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _kikiState = KikiState.normal;
        });
      }
    }
  }

  String _getKikiImageAsset() {
    switch (_kikiState) {
      case KikiState.correct:
        return 'assets/images/characters/kiki_smiling.png';
      case KikiState.wrong:
        return 'assets/images/characters/kiki_smiling.png';
      case KikiState.normal:
      default:
        return 'assets/images/characters/kiki_the_cat.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double buttonSize = screenSize.width * 0.12;

    // Default Kiki size and position
    double kikiWidth = screenSize.width * 0.35;
    double kikiBottom = -screenSize.height * 0.15;

    // Adjust size/position based on current reaction state
    if (_kikiState == KikiState.correct) {
      kikiWidth = screenSize.width * 0.35;
      kikiBottom = -screenSize.height * 0.15;
    } else if (_kikiState == KikiState.wrong) {
      kikiBottom = -screenSize.height * 0.15;
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic Background Image
          Positioned.fill(
            child: Image.asset(
              levelSequence[currentLevelIndex]['bg']!,
              fit: BoxFit.cover,
            ),
          ),

          // 2. Weather Selection Buttons
          Positioned(
            bottom: screenSize.height * 0.08,
            left: screenSize.width * 0.05,
            child: Row(
              children: [
                _buildWeatherButton(
                  'rainy',
                  'assets/images/objects/lagoon/raincloud.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'sunny',
                  'assets/images/objects/lagoon/sun.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'windy',
                  'assets/images/objects/lagoon/windy.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'cloudy',
                  'assets/images/objects/lagoon/cloudy.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
              ],
            ),
          ),

          // 3. Kiki the Cat (Dynamic Size & Position)
          Positioned(
            bottom: kikiBottom,
            right: screenSize.width * 0.02,
            child: Image.asset(_getKikiImageAsset(), width: kikiWidth),
          ),

          // 4. Good Job Overlay (Shows when game is complete)
          if (_isGameComplete)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/kiki_tryagain.png',
                closeButtonColor: const Color(0xFF2C4463),
                onNext: () {
                  // Defines behavior for the Next button (e.g. Navigating to a new screen)
                  Navigator.of(context).pop();
                },
                onRestart: () {
                  // Resets the game state back to the first background
                  setState(() {
                    currentLevelIndex = 0;
                    _isGameComplete = false;
                    _kikiState = KikiState.normal;
                  });
                },
                onBack: () {
                  // Defines behavior for the top-left Close button
                  Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherButton(
    String weatherType,
    String imagePath,
    Color borderColor,
    double size, {
    bool isHighlighted = false,
  }) {
    return GestureDetector(
      onTap: () => handleAnswer(weatherType),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.15),
          border: Border.all(
            color: isHighlighted ? Colors.orange : borderColor,
            width: size * 0.04,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.15),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ── Overlay Implementation ──────────────────────────────────────────────────

class GoodJobOverlay extends StatefulWidget {
  final String characterImage;
  final Color closeButtonColor;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const GoodJobOverlay({
    super.key,
    required this.characterImage,
    required this.closeButtonColor,
    required this.onNext,
    required this.onRestart,
    required this.onBack,
  });

  @override
  State<GoodJobOverlay> createState() => _GoodJobOverlayState();
}

class _GoodJobOverlayState extends State<GoodJobOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late AnimationController _starsCtrl;
  late AnimationController _charBounceCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _bannerScale;
  late Animation<double> _charScale;
  late Animation<double> _charBounce;

  final AudioPlayer _overlayAudioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _initAudio();
    _playYeySound();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _charBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeIn);

    _bannerScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(_entranceCtrl);

    _charScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(_entranceCtrl);

    _charBounce = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _charBounceCtrl, curve: Curves.easeInOut),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _starsCtrl.dispose();
    _charBounceCtrl.dispose();
    _overlayAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    await _overlayAudioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _playYeySound() async {
    await _overlayAudioPlayer.play(AssetSource('audio/sound_effects/yey.wav'));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.of(context).size;
        final double screenWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mq.width;
        final double screenHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mq.height;

        final double shortestSide = screenWidth < screenHeight
            ? screenWidth
            : screenHeight;

        final double scale = (shortestSide / 390).clamp(0.7, 1.6);

        // ── Responsive metrics ────────────────────────────────────────
        final double bannerWidth = (550 * scale).clamp(
          220.0,
          screenWidth * 0.9,
        );
        final double bannerTop = (screenHeight * 0.06).clamp(24.0, 70.0);

        final double characterHeight = (300 * scale).clamp(
          140.0,
          screenHeight * 0.38,
        );
        final double characterTop = (screenHeight * 0.17).clamp(90.0, 190.0);

        final double actionButtonSize = (88 * scale).clamp(56.0, 120.0);
        final double edgeMargin = (screenWidth * 0.08).clamp(16.0, 48.0);
        final double bottomMargin = (screenHeight * 0.035).clamp(16.0, 44.0);

        final double closeButtonSize = (48 * scale).clamp(38.0, 58.0);
        final double closeButtonInset = (12 * scale).clamp(10.0, 22.0);

        return FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withValues(alpha: 0.45),
            child: Stack(
              children: [
                Positioned(
                  top: bannerTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8 * scale),
                      child: ScaleTransition(
                        scale: _bannerScale,
                        child: _ArcedGoodJobBanner(width: bannerWidth),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: characterTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _charBounceCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _charBounce.value * scale),
                        child: child,
                      ),
                      child: ScaleTransition(
                        scale: _charScale,
                        child: _buildCharacter(characterHeight),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: bottomMargin,
                  left: edgeMargin,
                  child: _ImageButton(
                    imagePath: 'assets/images/buttons/restart.png',
                    onTap: widget.onRestart,
                    size: actionButtonSize,
                    tooltip: 'Restart',
                  ),
                ),
                Positioned(
                  bottom: bottomMargin,
                  right: edgeMargin,
                  child: _ImageButton(
                    imagePath: 'assets/images/buttons/next.png',
                    onTap: widget.onNext,
                    size: actionButtonSize,
                    tooltip: 'Next Level',
                  ),
                ),
                Positioned(
                  top: closeButtonInset,
                  left: closeButtonInset,
                  child: _CloseButton(
                    onTap: widget.onBack,
                    color: widget.closeButtonColor,
                    size: closeButtonSize,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacter(double height) {
    return Image.asset(
      widget.characterImage,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.pets, size: height * 0.4, color: Colors.white),
    );
  }
}

class _ArcedGoodJobBanner extends StatelessWidget {
  final double width;

  const _ArcedGoodJobBanner({required this.width});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/goodjob.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _CloseButton({
    required this.onTap,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: size * 0.06),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: size * 0.17,
              offset: Offset(0, size * 0.06),
            ),
          ],
        ),
        child: Icon(Icons.close_rounded, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

class _ImageButton extends StatefulWidget {
  final String imagePath;
  final VoidCallback onTap;
  final double size;
  final String tooltip;

  const _ImageButton({
    required this.imagePath,
    required this.onTap,
    required this.size,
    required this.tooltip,
  });

  @override
  State<_ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<_ImageButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: ScaleTransition(
          scale: _ctrl,
          child: Image.asset(
            widget.imagePath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.circle, size: widget.size, color: Colors.orange),
          ),
        ),
      ),
    );
  }
}
