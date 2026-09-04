import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/soft_hard_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'lagoon_game_ui.dart';

// Added favoriteTaste phase for the final interactive question!
enum GamePhase {
  intro,
  sweetPrompt,
  playing,
  sourPrompt,
  saltyPrompt,
  bitterPrompt,
  favoriteTaste,
  goodJob,
}

// Tracks which taste round is currently active
enum TasteRound { sweet, sour, salty, bitter }

// Represents a single falling food item on the screen
class FallingFood {
  String imagePath;
  double x; // Horizontal position (from 0.0 left to 1.0 right)
  double y; // Vertical position (from -0.2 top to 1.2 bottom)
  double speed; // How fast it falls
  bool isTarget; // Distinguishes between correct taste items and wrong items!

  FallingFood({
    required this.imagePath,
    required this.x,
    required this.y,
    required this.speed,
    required this.isTarget,
  });
}

class CatchingGameScreen extends StatefulWidget {
  final int level;

  const CatchingGameScreen({super.key, required this.level});

  @override
  State<CatchingGameScreen> createState() => _CatchingGameScreenState();
}

class _CatchingGameScreenState extends State<CatchingGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _gameLoopController;
  late final AudioPlayer _audioPlayer;
  final Random _random = Random();

  GamePhase _currentPhase = GamePhase.intro;
  TasteRound _currentRound = TasteRound.sweet;

  double _basketX = 0.5;
  final List<FallingFood> _fallingItems = [];
  int _spawnTimer = 0;

  int _caughtCount = 0;
  final int _targetToWin = 10;

  bool _canTapFavorite = false;

  // NEW: guards every pending audio wait against a disposed player
  bool _disposed = false;

  // ...(food asset lists unchanged)...

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _audioPlayer = AudioPlayer();
    _playIntroSequence();

    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_updateGame);
  }

  /// NEW: waits for the current sound to finish without throwing
  /// "Bad state: No element" if the player gets disposed mid-wait.
  Future<void> _waitForAudioComplete() async {
    try {
      await _audioPlayer.onPlayerComplete.first;
    } catch (_) {
      // Stream closed (player disposed) before it ever completed — ignore.
    }
  }

  Future<void> _playIntroSequence() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_intro.wav'),
      );

      _waitForAudioComplete().then((_) async {
        if (!mounted || _disposed) return;
        setState(() {
          _currentPhase = GamePhase.sweetPrompt;
        });
        await _audioPlayer.play(
          AssetSource('audio/discovery_lagoon/catching_sweet.wav'),
        );

        _waitForAudioComplete().then((_) {
          if (!mounted || _disposed) return;
          setState(() {
            _currentPhase = GamePhase.playing;
          });
          _gameLoopController.forward();
        });
      });
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  Future<void> _startSourRound() async {
    setState(() {
      _fallingItems.clear();
      _caughtCount = 0;
      _currentRound = TasteRound.sour;
      _currentPhase = GamePhase.sourPrompt;
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_sour.wav'),
      );

      _waitForAudioComplete().then((_) {
        if (!mounted || _disposed) return;
        setState(() {
          _currentPhase = GamePhase.playing;
        });
        _gameLoopController.forward();
      });
    } catch (e) {
      debugPrint("Error playing sour audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  Future<void> _startSaltyRound() async {
    setState(() {
      _fallingItems.clear();
      _caughtCount = 0;
      _currentRound = TasteRound.salty;
      _currentPhase = GamePhase.saltyPrompt;
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_salty.wav'),
      );

      _waitForAudioComplete().then((_) {
        if (!mounted || _disposed) return;
        setState(() {
          _currentPhase = GamePhase.playing;
        });
        _gameLoopController.forward();
      });
    } catch (e) {
      debugPrint("Error playing salty audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  Future<void> _startBitterRound() async {
    setState(() {
      _fallingItems.clear();
      _caughtCount = 0;
      _currentRound = TasteRound.bitter;
      _currentPhase = GamePhase.bitterPrompt;
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_bitter.wav'),
      );

      _waitForAudioComplete().then((_) {
        if (!mounted || _disposed) return;
        setState(() {
          _currentPhase = GamePhase.playing;
        });
        _gameLoopController.forward();
      });
    } catch (e) {
      debugPrint("Error playing bitter audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  Future<void> _startFavoriteTastePhase() async {
    setState(() {
      _fallingItems.clear();
      _currentPhase = GamePhase.favoriteTaste;
      _canTapFavorite = false;
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_fav_taste.wav'),
      );

      _waitForAudioComplete().then((_) {
        if (!mounted || _disposed) return;
        setState(() {
          _canTapFavorite = true;
        });
      });
    } catch (e) {
      debugPrint("Error playing fav taste audio: $e");
      if (mounted) {
        setState(() => _canTapFavorite = true);
      }
    }
  }

  void _onFavoriteTasteTapped() {
    if (!_canTapFavorite || _currentPhase != GamePhase.favoriteTaste) return;

    setState(() {
      _canTapFavorite = false;
    });

    _playSound('audio/sound_effects/shine.wav');

    _waitForAudioComplete().then((_) {
      if (!mounted || _disposed) return;
      _playSound('audio/discovery_lagoon/catching_ending.wav');

      _waitForAudioComplete().then((_) {
        if (!mounted || _disposed) return;
        setState(() {
          _currentPhase = GamePhase.goodJob;
        });
      });
    });
  }

  Future<void> _playSound(String assetPath) async {
    if (_disposed) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing audio ($assetPath): $e");
    }
  }

  void _updateGame() {
    if (_currentPhase != GamePhase.playing) return;

    setState(() {
      _spawnTimer++;
      if (_spawnTimer >= 40) {
        _spawnTimer = 0;
        _spawnFood();
      }

      for (int i = _fallingItems.length - 1; i >= 0; i--) {
        _fallingItems[i].y += _fallingItems[i].speed;

        if (_fallingItems[i].y >= 0.65 && _fallingItems[i].y <= 0.85) {
          double horizontalDistance = (_fallingItems[i].x - _basketX).abs();

          if (horizontalDistance < 0.22) {
            final caughtItem = _fallingItems[i];
            _fallingItems.removeAt(i);

            if (caughtItem.isTarget) {
              _caughtCount++;

              if (_caughtCount >= _targetToWin) {
                _gameLoopController.stop();
                _playSound('audio/sound_effects/shine.wav');

                _waitForAudioComplete().then((_) {
                  if (!mounted || _disposed) return;
                  if (_currentRound == TasteRound.sweet) {
                    _startSourRound();
                  } else if (_currentRound == TasteRound.sour) {
                    _startSaltyRound();
                  } else if (_currentRound == TasteRound.salty) {
                    _startBitterRound();
                  } else {
                    _startFavoriteTastePhase();
                  }
                });
              } else {
                _playSound('audio/sound_effects/shine.wav');
              }
            } else {
              _playSound('audio/discovery_lagoon/kiki_tryagain.wav');
            }
            continue;
          }
        }

        if (_fallingItems[i].y > 1.1) {
          _fallingItems.removeAt(i);
        }
      }
    });
  }

  void _spawnFood() {
    // ...(unchanged)...
  }

  void _onPanUpdate(DragUpdateDetails details, double screenWidth) {
    if (_currentPhase != GamePhase.playing) return;

    setState(() {
      _basketX += details.delta.dx / screenWidth;
      _basketX = _basketX.clamp(0.15, 0.85);
    });
  }

  void _restartGame() {
    setState(() {
      _caughtCount = 0;
      _fallingItems.clear();
      _currentRound = TasteRound.sweet;
      _currentPhase = GamePhase.intro;
    });
    _playIntroSequence();
  }

  @override
  void dispose() {
    _disposed = true; // set FIRST so any in-flight .then() bails out
    _gameLoopController.dispose();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPhaseContent(sw, sh),

          // X Button and Level Badge — on every phase except the
          // victory overlay, which has its own close button.
          if (_currentPhase != GamePhase.goodJob) ...[
            Positioned(top: 25, left: 25, child: const LagoonXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LagoonLevelBadge(level: widget.level),
            ),
          ],
        ],
      ),
    );
  }

  /// Returns just the content for the current phase (no Scaffold —
  /// build() now provides one Scaffold shared by every phase).
  Widget _buildPhaseContent(double sw, double sh) {
    if (_currentPhase == GamePhase.intro) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_closeup2.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: -sh * 0.10,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/characters/kiki_the_cat.png',
                height: sh * 0.90,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: -sh * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/objects/lagoon/basket.png',
                width: sh * 0.75,
                height: sh * 0.55,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      );
    }

    if (_currentPhase == GamePhase.sweetPrompt) {
      return Image.asset(
        'assets/images/objects/lagoon/sweet.png',
        width: sw,
        height: sh,
        fit: BoxFit.cover,
      );
    }

    if (_currentPhase == GamePhase.sourPrompt) {
      return Image.asset(
        'assets/images/objects/lagoon/sour.png',
        width: sw,
        height: sh,
        fit: BoxFit.cover,
      );
    }

    if (_currentPhase == GamePhase.saltyPrompt) {
      return Image.asset(
        'assets/images/objects/lagoon/salty.png',
        width: sw,
        height: sh,
        fit: BoxFit.cover,
      );
    }

    if (_currentPhase == GamePhase.bitterPrompt) {
      return Image.asset(
        'assets/images/objects/lagoon/bitter.png',
        width: sw,
        height: sh,
        fit: BoxFit.cover,
      );
    }

    if (_currentPhase == GamePhase.favoriteTaste) {
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_closeup.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: -sh * 0.20,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/characters/kiki_the_cat.png',
                height: sh * 1.15,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: -sh * 0.12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFavoriteChoice(
                  'assets/images/objects/lagoon/chocolate.png',
                  sh,
                  sw,
                ),
                _buildFavoriteChoice(
                  'assets/images/objects/lagoon/lemon.png',
                  sh,
                  sw,
                ),
                _buildFavoriteChoice(
                  'assets/images/objects/lagoon/fries.png',
                  sh,
                  sw,
                ),
                _buildFavoriteChoice(
                  'assets/images/objects/lagoon/bittergourd.png',
                  sh,
                  sw,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // PLAYING & GOOD JOB PHASES
    final double basketWidth = sh * 0.75;
    final double basketHeight = sh * 0.55;
    final double foodSize = sh * 0.26;

    return GestureDetector(
      onPanUpdate: (details) => _onPanUpdate(details, sw),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_rainbow_closeup.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            left: (_basketX * sw) - (basketWidth / 2),
            bottom: -sh * 0.15,
            child: Image.asset(
              'assets/images/objects/lagoon/basket.png',
              width: basketWidth,
              height: basketHeight,
              fit: BoxFit.contain,
            ),
          ),
          ..._fallingItems.map((food) {
            return Positioned(
              left: (food.x * sw) - (foodSize / 2),
              top: food.y * sh,
              child: Image.asset(
                food.imagePath,
                width: foodSize,
                height: foodSize,
                fit: BoxFit.contain,
              ),
            );
          }),
          if (_currentPhase == GamePhase.goodJob)
            GoodJobOverlay(
              characterImage: 'assets/images/characters/kiki_tryagain.png',
              closeButtonColor: Colors.orange,
              onNext: () async {
                await LagoonProgressService.instance.markLevelComplete(4);
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          SoftHardGameScreen(level: widget.level + 1),
                    ),
                  );
                }
              },
              onRestart: _restartGame,
              onBack: () {
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFavoriteChoice(
      String foodImagePath,
      double screenHeight,
      double screenWidth,
      ) {
    final double basketW = screenWidth * 0.23;
    final double basketH = screenHeight * 0.38;
    final double foodS = screenHeight * 0.28;

    return GestureDetector(
      onTap: _onFavoriteTasteTapped,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Image.asset(
            'assets/images/objects/lagoon/basket.png',
            width: basketW,
            height: basketH,
            fit: BoxFit.contain,
          ),
          Positioned(
            bottom: screenHeight * 0.15,
            child: Image.asset(
              foodImagePath,
              width: foodS,
              height: foodS,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// GOOD JOB OVERLAY & HELPER CLASSES (Required for victory screen!)
// ──────────────────────────────────────────────────────────────────────────────

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

  final AudioPlayer _audioPlayer = AudioPlayer();

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
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _playYeySound() async {
    await _audioPlayer.play(AssetSource('audio/sound_effects/yey.wav'));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.45),
        child: Stack(
          children: [
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ScaleTransition(
                    scale: _bannerScale,
                    child: const _ArcedGoodJobBanner(),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _charBounceCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _charBounce.value),
                    child: child,
                  ),
                  child: ScaleTransition(
                    scale: _charScale,
                    child: _buildCharacter(),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 28,
              left: 32,
              child: _ImageButton(
                imagePath: 'assets/images/buttons/restart.png',
                onTap: widget.onRestart,
                size: 88,
                tooltip: 'Restart',
              ),
            ),

            Positioned(
              bottom: 28,
              right: 32,
              child: _ImageButton(
                imagePath: 'assets/images/buttons/next.png',
                onTap: widget.onNext,
                size: 88,
                tooltip: 'Next Level',
              ),
            ),

            Positioned(
              top: 16,
              left: 16,
              child: _CloseButton(
                onTap: widget.onBack,
                color: widget.closeButtonColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacter() {
    return Image.asset(
      widget.characterImage,
      height: 300,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.pets, size: 120, color: Colors.white),
    );
  }
}

class _ArcedGoodJobBanner extends StatelessWidget {
  const _ArcedGoodJobBanner();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/goodjob.png',
      width: 550,
      fit: BoxFit.contain,
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const _CloseButton({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
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
