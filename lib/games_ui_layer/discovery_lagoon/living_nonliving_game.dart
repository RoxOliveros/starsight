import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../goodjob_prompt.dart';

// --- Game Phase Enum ---
enum GamePhase { intro1, playLiving, intro2, playNonLiving, finished }

// --- Configuration Model ---
class AssetConfig {
  final String imagePath;
  final String coloredImagePath;

  final bool isLiving;
  final bool isClickable;

  final double? leftOffset;
  final double? rightOffset;
  final double? topOffset;
  final double? bottomOffset;
  final double? widthOffset;
  final double? heightOffset;
  final double? rotation;
  final double? coloredLeftOffset;
  final double? coloredRightOffset;
  final double? coloredTopOffset;
  final double? coloredBottomOffset;
  final double? coloredWidthOffset;
  final double? coloredHeightOffset;

  const AssetConfig({
    required this.imagePath,
    required this.coloredImagePath,
    this.isLiving = false,
    this.isClickable = true,
    this.leftOffset,
    this.rightOffset,
    this.topOffset,
    this.bottomOffset,
    this.widthOffset,
    this.heightOffset,
    this.rotation,
    this.coloredLeftOffset,
    this.coloredRightOffset,
    this.coloredTopOffset,
    this.coloredBottomOffset,
    this.coloredWidthOffset,
    this.coloredHeightOffset,
  });
}

class LivingNonLivingGame extends StatefulWidget {
  const LivingNonLivingGame({Key? key}) : super(key: key);

  @override
  State<LivingNonLivingGame> createState() => _LivingNonLivingGameState();
}

class _LivingNonLivingGameState extends State<LivingNonLivingGame> {
  // --- STATE VARIABLES ---
  final Set<AssetConfig> _tappedAssets = {};
  late List<AssetConfig> _gameItems;

  GamePhase _phase = GamePhase.intro1;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    // Grouping all clickable items into a list so we can easily count them for win conditions
    _gameItems = [
      sun,
      cloud1,
      cloud2,
      bird,
      tree,
      flowerbed,
      butterfly,
      wateringCan,
      puddle,
      antnest,
      rock,
      blanket,
      basket,
      apple,
      ant,
      kiki,
    ];

    _startPhase1();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- AUDIO & PHASE LOGIC ---

  void _startPhase1() async {
    setState(() => _phase = GamePhase.intro1);

    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/living_nonliving_game_part1.wav'),
    );

    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;
      if (_phase == GamePhase.intro1) {
        setState(() => _phase = GamePhase.playLiving);
      } else if (_phase == GamePhase.intro2) {
        setState(() => _phase = GamePhase.playNonLiving);
      }
    });
  }

  void _startPhase2() async {
    setState(() => _phase = GamePhase.intro2);
    await _audioPlayer.play(
      AssetSource('audio/discovery_lagoon/living_nonliving_game_part2.wav'),
    );
  }

  void _checkProgress() {
    if (_phase == GamePhase.playLiving) {
      final tappedLiving = _tappedAssets.where((a) => a.isLiving).length;
      final totalLiving = _gameItems.where((a) => a.isLiving).length;

      if (tappedLiving >= totalLiving) {
        _startPhase2();
      }
    } else if (_phase == GamePhase.playNonLiving) {
      final tappedNonLiving = _tappedAssets.where((a) => !a.isLiving).length;
      final totalNonLiving = _gameItems.where((a) => !a.isLiving).length;

      if (tappedNonLiving >= totalNonLiving) {
        setState(() => _phase = GamePhase.finished);
      }
    }
  }

  // --- Asset Configurations ---

  final AssetConfig sun = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/sun_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/sun.png',
    topOffset: 0.10,
    rightOffset: 0.33,
    widthOffset: 0.12,
  );

  final AssetConfig cloud1 = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/cloud_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/cloud_wc.png',
    topOffset: 0.160,
    leftOffset: 0.78,
    widthOffset: 0.16,
  );

  final AssetConfig cloud2 = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/cloud_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/cloud_wc.png',
    topOffset: -0.03,
    leftOffset: 0.65,
    widthOffset: 0.16,
  );

  final AssetConfig bird = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/bird_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/bird_wc.png',
    isLiving: true,
    topOffset: 0.12,
    leftOffset: 0.35,
    widthOffset: 0.08,
  );

  final AssetConfig tree = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/tree_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/t5_tree.png',
    isLiving: true,
    topOffset: -0.14,
    leftOffset: -0.02,
    heightOffset: 1.02,
    coloredTopOffset: -0.12,
    coloredLeftOffset: -0.04,
    coloredHeightOffset: 1.02,
  );

  final AssetConfig flowerbed = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/flowerbed_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/flowerbed_wc.png',
    isLiving: true,
    topOffset: 0.53,
    leftOffset: 0.35,
    widthOffset: 0.25,
  );

  final AssetConfig butterfly = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/butterfly_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/b4_butterfly.png',
    isLiving: true,
    topOffset: 0.43,
    leftOffset: 0.55,
    widthOffset: 0.06,
    rotation: 0.8,
  );

  final AssetConfig wateringCan = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/wateringcan_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/wateringcan_wc.png',
    topOffset: 0.62,
    leftOffset: 0.58,
    widthOffset: 0.07,
  );

  final AssetConfig puddle = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/puddle_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/puddle_wc.png',
    bottomOffset: 0.20,
    leftOffset: 0.28,
    widthOffset: 0.07,
  );

  final AssetConfig antnest = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/antnest_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/antnest_wc.png',
    bottomOffset: 0.01,
    leftOffset: 0.03,
    widthOffset: 0.08,
  );

  final AssetConfig rock = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/rock_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/rock_wc.png',
    bottomOffset: 0.13,
    leftOffset: 0.35,
    widthOffset: 0.08,
  );

  final AssetConfig blanket = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/blanket_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/blanket_wc.png',
    bottomOffset: 0.02,
    leftOffset: 0.42,
    widthOffset: 0.32,
  );

  final AssetConfig basket = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/basket_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/basket.png',
    bottomOffset: 0.14,
    leftOffset: 0.48,
    widthOffset: 0.1,
  );

  final AssetConfig apple = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/apple_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/apple_colored.png',
    bottomOffset: 0.10,
    leftOffset: 0.60,
    widthOffset: 0.06,
    rotation: 0.8,
  );

  final AssetConfig ant = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/ant_nc.png',
    coloredImagePath: 'assets/images/objects/lagoon/ant_wc.png',
    isLiving: true,
    bottomOffset: 0.08,
    leftOffset: 0.45,
    widthOffset: 0.05,
  );

  final AssetConfig kiki = const AssetConfig(
    imagePath: 'assets/images/objects/lagoon/kiki_nc.png',
    coloredImagePath: 'assets/images/characters/kiki_the_cat.png',
    isLiving: true, // <--- CHANGED: Kiki is now a living target!
    bottomOffset: 0.05,
    rightOffset: 0.04,
    heightOffset: 0.6,
  );

  // --- Widget Builder ---
  Widget _buildAsset(AssetConfig config, Size size) {
    bool isTapped = _tappedAssets.contains(config);
    String currentImagePath = isTapped
        ? config.coloredImagePath
        : config.imagePath;

    double? currentLeft = isTapped
        ? (config.coloredLeftOffset ?? config.leftOffset)
        : config.leftOffset;
    double? currentRight = isTapped
        ? (config.coloredRightOffset ?? config.rightOffset)
        : config.rightOffset;
    double? currentTop = isTapped
        ? (config.coloredTopOffset ?? config.topOffset)
        : config.topOffset;
    double? currentBottom = isTapped
        ? (config.coloredBottomOffset ?? config.bottomOffset)
        : config.bottomOffset;
    double? currentWidth = isTapped
        ? (config.coloredWidthOffset ?? config.widthOffset)
        : config.widthOffset;
    double? currentHeight = isTapped
        ? (config.coloredHeightOffset ?? config.heightOffset)
        : config.heightOffset;

    Widget imageContent = GestureDetector(
      onTap: () {
        if (!config.isClickable) return;
        if (isTapped) return;

        if (_phase == GamePhase.playLiving && !config.isLiving) return;
        if (_phase == GamePhase.playNonLiving && config.isLiving) return;

        setState(() {
          _tappedAssets.add(config);
          _checkProgress();
        });
      },
      behavior: HitTestBehavior.deferToChild,
      child: Image.asset(
        currentImagePath,
        width: currentWidth != null ? size.width * currentWidth : null,
        height: currentHeight != null ? size.height * currentHeight : null,
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
      ),
    );

    if (config.rotation != null) {
      imageContent = Transform.rotate(
        angle: config.rotation!,
        child: imageContent,
      );
    }

    return Positioned(
      left: currentLeft != null ? size.width * currentLeft : null,
      right: currentRight != null ? size.width * currentRight : null,
      top: currentTop != null ? size.height * currentTop : null,
      bottom: currentBottom != null ? size.height * currentBottom : null,
      child: imageContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    bool isIntro = _phase == GamePhase.intro1 || _phase == GamePhase.intro2;
    bool isFinished =
        _phase == GamePhase.finished; // <--- ADDED: Track finished state

    return Scaffold(
      body: Stack(
        children: [
          // 1. The Main Game Board
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/images/backgrounds/bg_lagoon_fields_closeup.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildAsset(sun, size),
                _buildAsset(cloud1, size),
                _buildAsset(cloud2, size),
                _buildAsset(bird, size),
                _buildAsset(tree, size),
                _buildAsset(flowerbed, size),
                _buildAsset(butterfly, size),
                _buildAsset(wateringCan, size),
                _buildAsset(puddle, size),
                _buildAsset(antnest, size),
                _buildAsset(rock, size),
                _buildAsset(blanket, size),
                _buildAsset(basket, size),
                _buildAsset(apple, size),
                _buildAsset(ant, size),
                _buildAsset(kiki, size),
              ],
            ),
          ),

          // 2. The Intro Overlay (Only visible during audio phases)
          if (isIntro)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _audioPlayer.stop();
                  setState(() {
                    if (_phase == GamePhase.intro1)
                      _phase = GamePhase.playLiving;
                    if (_phase == GamePhase.intro2)
                      _phase = GamePhase.playNonLiving;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: Offset(0, size.height * 0.25),
                      child: Image.asset(
                        'assets/images/characters/kiki_the_cat.png',
                        height: size.height * 0.8,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 3. The Good Job Overlay (Visible only when finished)
          if (isFinished)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage: 'assets/images/characters/kiki_the_cat.png',
                closeButtonColor: const Color.fromARGB(255, 252, 214, 0),
                onNext: () {
                  // Handle navigating to your next level here
                  print("Next Level Tapped");
                },
                onRestart: () {
                  // This instantly resets everything to play again
                  setState(() {
                    _tappedAssets.clear();
                    _startPhase1();
                  });
                },
                onBack: () {
                  // Return to the menu
                  Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}
