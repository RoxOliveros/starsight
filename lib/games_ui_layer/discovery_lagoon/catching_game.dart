import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/soft_hard_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
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
  int _wrongCatchCount = 0;
  final int _targetToWin = 15;

  bool _canTapFavorite = false;
  bool _disposed = false;

  final String _catchMissedFoods = 'audio/discovery_lagoon/catching_missed_food.wav';

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
        _startSweetRound();
      });
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
      if (mounted) {
        setState(() => _currentPhase = GamePhase.playing);
        _gameLoopController.forward();
      }
    }
  }

  Future<void> _startSweetRound() async {
    setState(() {
      _fallingItems.clear();
      _caughtCount = 0;
      _wrongCatchCount = 0;
      _currentRound = TasteRound.sweet;
      _currentPhase = GamePhase.sweetPrompt;
    });

    try {
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
    } catch (e) {
      debugPrint("Error playing sweet audio: $e");
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
      _wrongCatchCount = 0;
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
      _wrongCatchCount = 0;
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
      _wrongCatchCount = 0;
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

  Future<void> _repeatCurrentRound() async {
    switch (_currentRound) {
      case TasteRound.sweet:
        await _startSweetRound();
        break;
      case TasteRound.sour:
        await _startSourRound();
        break;
      case TasteRound.salty:
        await _startSaltyRound();
        break;
      case TasteRound.bitter:
        await _startBitterRound();
        break;
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
            } else {
              _wrongCatchCount++;
            }

            final int totalCatches = _caughtCount + _wrongCatchCount;

            if (totalCatches >= _targetToWin) {
              _gameLoopController.stop();

              if (_wrongCatchCount >= _caughtCount) {
                _playSound(_catchMissedFoods);
                _waitForAudioComplete().then((_) {
                  if (!mounted || _disposed) return;
                  _repeatCurrentRound();
                });
              } else {
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
              }
            } else {
              if (caughtItem.isTarget) {
                _playSound('audio/sound_effects/shine.wav');
              } else {
                _playSound('audio/discovery_lagoon/kiki_tryagain.wav');
              }
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
    // 50% chance to spawn target food, 30% chance to spawn a distraction!
    bool spawnTarget = _random.nextDouble() < 0.50;

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
      _wrongCatchCount = 0;
      _fallingItems.clear();
      _currentRound = TasteRound.sweet;
      _currentPhase = GamePhase.intro;
    });
    _playIntroSequence();
  }

  @override
  void dispose() {
    _disposed = true;
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
              characterImage: 'assets/images/characters/cat_holding_fishbone.png',
              closeButtonColor: LagoonColorTheme.wasteland,
              characterSizeFactor: 0.9,
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