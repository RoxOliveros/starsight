import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

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
  const CatchingGameScreen({super.key});

  @override
  State<CatchingGameScreen> createState() => _CatchingGameScreenState();
}

class _CatchingGameScreenState extends State<CatchingGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _gameLoopController;
  late final AudioPlayer _audioPlayer;
  final Random _random = Random();

  // Start in the intro phase and sweet round!
  GamePhase _currentPhase = GamePhase.intro;
  TasteRound _currentRound = TasteRound.sweet;

  // Game state variables
  double _basketX =
      0.5; // Basket centers at 0.5 (middle of screen horizontally)
  final List<FallingFood> _fallingItems = [];
  int _spawnTimer = 0;

  // Track caught items! Win goal is set to 10 per round.
  int _caughtCount = 0;
  final int _targetToWin = 10;

  // Locks taps during the final favorite taste question until audio ends!
  bool _canTapFavorite = false;

  // Asset paths for sweet foods
  final List<String> _sweetFoodImages = [
    'assets/images/objects/lagoon/cookie.png',
    'assets/images/objects/lagoon/chocolate.png',
    'assets/images/objects/lagoon/candy_colored.png',
    'assets/images/objects/lagoon/strawberry.png',
    'assets/images/objects/lagoon/banana_colored.png',
  ];

  // Asset paths for sour foods
  final List<String> _sourFoodImages = [
    'assets/images/objects/lagoon/orange.png',
    'assets/images/objects/lagoon/lemon.png',
    'assets/images/objects/lagoon/yogurt.png',
    'assets/images/objects/lagoon/tamarid.png',
    'assets/images/objects/lagoon/vinegar.png',
  ];

  // Asset paths for salty foods
  final List<String> _saltyFoodImages = [
    'assets/images/objects/lagoon/pizza_colored.png',
    'assets/images/objects/lagoon/fries.png',
    'assets/images/objects/lagoon/chips.png',
    'assets/images/objects/lagoon/cheese.png',
    'assets/images/objects/lagoon/bacon.png',
  ];

  // Asset paths for bitter foods
  final List<String> _bitterFoodImages = [
    'assets/images/objects/lagoon/coffee.png',
    'assets/images/objects/lagoon/lettuce.png',
    'assets/images/objects/lagoon/bittergourd.png',
    'assets/images/objects/lagoon/broccoli.png',
  ];

  // Asset paths for wrong / non-food items
  final List<String> _wrongFoodImages = [
    'assets/images/objects/lagoon/onion.png',
    'assets/images/objects/lagoon/perfume_fish.png',
    'assets/images/objects/lagoon/socks.png',
  ];

  @override
  void initState() {
    super.initState();
    // 1. FORCE LANDSCAPE ORIENTATION & FULLSCREEN
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 2. SETUP AUDIO & START INTRO
    _audioPlayer = AudioPlayer();
    _playIntroSequence();

    // 3. SETUP 60 FPS GAME LOOP (Not started until intro finishes!)
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1), // Runs continuously
    )..addListener(_updateGame);
  }

  /// Plays catching_intro.wav, then catching_sweet.wav, then starts Round 1!
  Future<void> _playIntroSequence() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_intro.wav'),
      );

      _audioPlayer.onPlayerComplete.first.then((_) async {
        if (mounted) {
          setState(() {
            _currentPhase = GamePhase.sweetPrompt;
          });
          await _audioPlayer.play(
            AssetSource('audio/discovery_lagoon/catching_sweet.wav'),
          );

          _audioPlayer.onPlayerComplete.first.then((_) {
            if (mounted) {
              setState(() {
                _currentPhase = GamePhase.playing;
              });
              _gameLoopController.forward();
            }
          });
        }
      });
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  /// Plays catching_sour.wav, then starts Round 2 (Sour)!
  Future<void> _startSourRound() async {
    setState(() {
      _fallingItems.clear(); // Clear old items from the screen
      _caughtCount = 0; // Reset counter for Round 2
      _currentRound = TasteRound.sour;
      _currentPhase = GamePhase.sourPrompt;
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_sour.wav'),
      );

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() {
            _currentPhase = GamePhase.playing;
          });
          _gameLoopController.forward(); // Resume falling items!
        }
      });
    } catch (e) {
      debugPrint("Error playing sour audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  /// Plays catching_salty.wav, then starts Round 3 (Salty)!
  Future<void> _startSaltyRound() async {
    setState(() {
      _fallingItems.clear(); // Clear old items from the screen
      _caughtCount = 0; // Reset counter for Round 3
      _currentRound = TasteRound.salty;
      _currentPhase = GamePhase.saltyPrompt;
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_salty.wav'),
      );

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() {
            _currentPhase = GamePhase.playing;
          });
          _gameLoopController.forward(); // Resume falling items!
        }
      });
    } catch (e) {
      debugPrint("Error playing salty audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  /// Plays catching_bitter.wav, then starts Round 4 (Bitter)!
  Future<void> _startBitterRound() async {
    setState(() {
      _fallingItems.clear(); // Clear old items from the screen
      _caughtCount = 0; // Reset counter for Round 4
      _currentRound = TasteRound.bitter;
      _currentPhase = GamePhase.bitterPrompt;
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_bitter.wav'),
      );

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() {
            _currentPhase = GamePhase.playing;
          });
          _gameLoopController.forward(); // Resume falling items!
        }
      });
    } catch (e) {
      debugPrint("Error playing bitter audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  /// Transitions to the Favorite Taste finale screen after winning all rounds!
  Future<void> _startFavoriteTastePhase() async {
    setState(() {
      _fallingItems.clear();
      _currentPhase = GamePhase.favoriteTaste;
      _canTapFavorite = false; // Lock taps until audio finishes!
    });

    try {
      await _audioPlayer.play(
        AssetSource('audio/discovery_lagoon/catching_fav_taste.wav'),
      );

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() {
            _canTapFavorite = true; // Unlock taps!
          });
        }
      });
    } catch (e) {
      debugPrint("Error playing fav taste audio: $e");
      if (mounted) {
        setState(() => _canTapFavorite = true);
      }
    }
  }

  /// Handles when player taps one of the 4 favorite taste baskets
  void _onFavoriteTasteTapped() {
    if (!_canTapFavorite || _currentPhase != GamePhase.favoriteTaste) return;

    setState(() {
      _canTapFavorite = false; // Lock further taps so they can't spam it!
    });

    // Play shine sound effect first!
    _playSound('audio/sound_effects/shine.wav');

    _audioPlayer.onPlayerComplete.first.then((_) {
      if (mounted) {
        // Play Kiki's ending voiceover!
        _playSound('audio/discovery_lagoon/catching_ending.wav');

        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) {
            // Transition to the final Good Job Victory screen!
            setState(() {
              _currentPhase = GamePhase.goodJob;
            });
          }
        });
      }
    });
  }

  /// Helper method to play sound effects
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing audio ($assetPath): $e");
    }
  }

  /// Called every frame (~60 times per second) to update item positions and check catches!
  void _updateGame() {
    if (_currentPhase != GamePhase.playing) return;

    setState(() {
      // 1. Spawn new food every ~40 frames
      _spawnTimer++;
      if (_spawnTimer >= 40) {
        _spawnTimer = 0;
        _spawnFood();
      }

      // 2. Move existing items down
      for (int i = _fallingItems.length - 1; i >= 0; i--) {
        _fallingItems[i].y += _fallingItems[i].speed;

        // 3. Check for collision with the basket!
        if (_fallingItems[i].y >= 0.65 && _fallingItems[i].y <= 0.85) {
          double horizontalDistance = (_fallingItems[i].x - _basketX).abs();

          if (horizontalDistance < 0.22) {
            final caughtItem = _fallingItems[i];
            _fallingItems.removeAt(i); // Remove caught item

            // 4. CHECK IF CAUGHT ITEM MATCHES ACTIVE ROUND!
            if (caughtItem.isTarget) {
              _caughtCount++;

              // Check Win Condition for current round!
              if (_caughtCount >= _targetToWin) {
                // A. STOP GAME LOOP IMMEDIATELY SO NOTHING ELSE FALLS
                _gameLoopController.stop();

                // B. PLAY SHINE SOUND EFFECT
                _playSound('audio/sound_effects/shine.wav');

                // C. WAIT FOR SHINE.WAV TO FINISH BEFORE SWITCHING ROUNDS!
                _audioPlayer.onPlayerComplete.first.then((_) {
                  if (mounted) {
                    if (_currentRound == TasteRound.sweet) {
                      _startSourRound();
                    } else if (_currentRound == TasteRound.sour) {
                      _startSaltyRound();
                    } else if (_currentRound == TasteRound.salty) {
                      _startBitterRound();
                    } else {
                      // All 4 rounds complete! Trigger the Favorite Taste finale!
                      _startFavoriteTastePhase();
                    }
                  }
                });
              } else {
                // Regular catch (not the final winning item yet)
                _playSound('audio/sound_effects/shine.wav');
              }
            } else {
              // Caught a wrong item! Play try-again sound.
              _playSound('audio/discovery_lagoon/kiki_tryagain.wav');
            }
            continue;
          }
        }

        // 5. Remove items that fell off the bottom of the screen
        if (_fallingItems[i].y > 1.1) {
          _fallingItems.removeAt(i);
        }
      }
    });
  }

  /// Spawns either a target food or a wrong item at the top of the screen
  void _spawnFood() {
    // 70% chance to spawn target food, 30% chance to spawn a distraction!
    bool spawnTarget = _random.nextDouble() < 0.70;

    String randomImage;
    if (spawnTarget) {
      if (_currentRound == TasteRound.sweet) {
        randomImage =
            _sweetFoodImages[_random.nextInt(_sweetFoodImages.length)];
      } else if (_currentRound == TasteRound.sour) {
        randomImage = _sourFoodImages[_random.nextInt(_sourFoodImages.length)];
      } else if (_currentRound == TasteRound.salty) {
        randomImage =
            _saltyFoodImages[_random.nextInt(_saltyFoodImages.length)];
      } else {
        randomImage =
            _bitterFoodImages[_random.nextInt(_bitterFoodImages.length)];
      }
    } else {
      List<String> distractionPool = [..._wrongFoodImages];
      if (_currentRound == TasteRound.sweet) {
        distractionPool.addAll(_sourFoodImages);
        distractionPool.addAll(_saltyFoodImages);
        distractionPool.addAll(_bitterFoodImages);
      } else if (_currentRound == TasteRound.sour) {
        distractionPool.addAll(_sweetFoodImages);
        distractionPool.addAll(_saltyFoodImages);
        distractionPool.addAll(_bitterFoodImages);
      } else if (_currentRound == TasteRound.salty) {
        distractionPool.addAll(_sweetFoodImages);
        distractionPool.addAll(_sourFoodImages);
        distractionPool.addAll(_bitterFoodImages);
      } else {
        distractionPool.addAll(_sweetFoodImages);
        distractionPool.addAll(_sourFoodImages);
        distractionPool.addAll(_saltyFoodImages);
      }
      randomImage = distractionPool[_random.nextInt(distractionPool.length)];
    }

    _fallingItems.add(
      FallingFood(
        imagePath: randomImage,
        x: 0.1 + (_random.nextDouble() * 0.8),
        y: -0.15,
        speed: 0.006 + (_random.nextDouble() * 0.005),
        isTarget: spawnTarget,
      ),
    );
  }

  /// Updates basket position when player drags it horizontally
  void _onPanUpdate(DragUpdateDetails details, double screenWidth) {
    if (_currentPhase != GamePhase.playing) return;

    setState(() {
      _basketX += details.delta.dx / screenWidth;
      _basketX = _basketX.clamp(0.15, 0.85);
    });
  }

  /// Restarts the game from scratch
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
    _gameLoopController.dispose();
    _audioPlayer.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    // 1. INTRO PHASE
    if (_currentPhase == GamePhase.intro) {
      return Scaffold(
        body: Stack(
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
        ),
      );
    }

    // 2. SWEET PROMPT PHASE
    if (_currentPhase == GamePhase.sweetPrompt) {
      return Scaffold(
        body: Image.asset(
          'assets/images/objects/lagoon/sweet.png',
          width: sw,
          height: sh,
          fit: BoxFit.cover,
        ),
      );
    }

    // 3. SOUR PROMPT PHASE
    if (_currentPhase == GamePhase.sourPrompt) {
      return Scaffold(
        body: Image.asset(
          'assets/images/objects/lagoon/sour.png',
          width: sw,
          height: sh,
          fit: BoxFit.cover,
        ),
      );
    }

    // 4. SALTY PROMPT PHASE
    if (_currentPhase == GamePhase.saltyPrompt) {
      return Scaffold(
        body: Image.asset(
          'assets/images/objects/lagoon/salty.png',
          width: sw,
          height: sh,
          fit: BoxFit.cover,
        ),
      );
    }

    // 5. BITTER PROMPT PHASE
    if (_currentPhase == GamePhase.bitterPrompt) {
      return Scaffold(
        body: Image.asset(
          'assets/images/objects/lagoon/bitter.png',
          width: sw,
          height: sh,
          fit: BoxFit.cover,
        ),
      );
    }

    // 6. FAVORITE TASTE FINALE PHASE
    if (_currentPhase == GamePhase.favoriteTaste) {
      return Scaffold(
        body: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            // A. Background Layer
            Image.asset(
              'assets/images/backgrounds/bg_rainbow_closeup.png',
              fit: BoxFit.cover,
            ),
            // B. Kiki Character Layer
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
            // C. 4 Baskets Row Layer
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
        ),
      );
    }

    // 7. PLAYING & VICTORY PHASES
    final double basketWidth = sh * 0.75;
    final double basketHeight = sh * 0.55;
    final double foodSize = sh * 0.26;

    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) => _onPanUpdate(details, sw),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A. BACKGROUND LAYER
            Image.asset(
              'assets/images/backgrounds/bg_rainbow_closeup.png',
              fit: BoxFit.cover,
            ),

            // B. BASKET LAYER
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

            // C. FALLING FOODS LAYER
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
              ); // <-- Make sure this line ends with a semicolon inside the return statement!
            }), // <-- Notice there is NO semicolon here after the closing bracket and parenthesis! Just a comma or nothing!
            // D. GOOD JOB OVERLAY LAYER (Appears after the favorite taste finale!)
            if (_currentPhase == GamePhase.goodJob)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/kiki_tryagain.png',
                closeButtonColor: Colors.orange,
                onNext: () {
                  Navigator.of(context).pop();
                },
                onRestart: _restartGame,
                onBack: () {
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Helper widget to build the 4 basket choices with foods drawn ON TOP of the basket overlay!
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
          // 1. Basket drawn FIRST (at the back)
          Image.asset(
            'assets/images/objects/lagoon/basket.png',
            width: basketW,
            height: basketH,
            fit: BoxFit.contain,
          ),
          // 2. Food drawn SECOND (on top / in front of the basket overlay!)
          Positioned(
            bottom: screenHeight * 0.15, // Positions it cleanly over the rim
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
