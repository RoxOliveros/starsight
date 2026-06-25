import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';

import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_level.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';

class WeatherOption {
  final String id;
  final String imagePath;
  final String name;

  WeatherOption({
    required this.id,
    required this.imagePath,
    required this.name,
  });
}

class ClothingItem {
  final String name;
  final String imagePath;
  final String targetWeatherId;

  ClothingItem({
    required this.name,
    required this.imagePath,
    required this.targetWeatherId,
  });
}

class WeatherClothesMatchScreen extends StatefulWidget {
  final int level;

  const WeatherClothesMatchScreen({super.key, required this.level});

  @override
  State<WeatherClothesMatchScreen> createState() => _WeatherClothesMatchScreenState();
}

class _WeatherClothesMatchScreenState extends State<WeatherClothesMatchScreen>
    with TickerProviderStateMixin {
  bool _isMatched = false;
  int _currentClothingIndex = 0;
  late final AnimationController _floatingController;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  final Map<String, bool> _flash = {};

  bool _showWinDialog = false;

  final List<WeatherOption> _weatherOptions = [
    WeatherOption(
      id: 'sunny',
      imagePath: 'assets/images/objects/lagoon/sunny_day_phase2.png',
      name: 'Sunny',
    ),
    WeatherOption(
      id: 'winter',
      imagePath: 'assets/images/objects/lagoon/winter.png',
      name: 'Winter',
    ),
    WeatherOption(
      id: 'rainy',
      imagePath: 'assets/images/objects/lagoon/rainy_day_phase2.png',
      name: 'Rainy',
    ),
  ];

  late List<ClothingItem> _clothingItems;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _clothingItems = [
      ClothingItem(
        name: 'Sunny Outfit',
        imagePath: 'assets/images/objects/lagoon/character_sunny_bottom_top.png',
        targetWeatherId: 'sunny',
      ),
      ClothingItem(
        name: 'Winter Clothes',
        imagePath: 'assets/images/objects/lagoon/character_winter_clothes.png',
        targetWeatherId: 'winter',
      ),
      ClothingItem(
        name: 'Rain Gear',
        imagePath: 'assets/images/objects/lagoon/character_rainy_coat_umbrella_boots.png',
        targetWeatherId: 'rainy',
      ),
    ]..shuffle();

    for (final w in _weatherOptions) {
      _flash[w.id] = false;
    }

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _bounceCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  bool get _isLast => _currentClothingIndex == _clothingItems.length - 1;

  Future<void> _onCorrectDrop() async {
    setState(() => _isMatched = true);
    _bounceCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (_isLast) {
      setState(() => _showWinDialog = true);
    } else {
      setState(() {
        _isMatched = false;
        _currentClothingIndex++;
      });
    }
  }

  Future<void> _onWrongDrop(String weatherId) async {
    setState(() => _flash[weatherId] = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _flash[weatherId] = false);
  }

  void _restart() {
    setState(() {
      _isMatched = false;
      _showWinDialog = false;
      _currentClothingIndex = 0;
      _clothingItems.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentClothing = _clothingItems[_currentClothingIndex];
    final double screenHeight = MediaQuery.of(context).size.height;
    final double itemSize = screenHeight * 0.25;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_lagoon.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),

                    // --- 3 WEATHER CARDS (Drag Targets) ---
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: _weatherOptions.map((weather) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: ScaleTransition(
                                  scale: (currentClothing.targetWeatherId == weather.id && _isMatched)
                                      ? _bounceAnim
                                      : const AlwaysStoppedAnimation(1.0),
                                  child: DragTarget<String>(
                                    onWillAcceptWithDetails: (details) => true,
                                    onAcceptWithDetails: (details) {
                                      if (details.data == weather.id) {
                                        _onCorrectDrop();
                                      } else {
                                        _onWrongDrop(weather.id);
                                      }
                                    },
                                    builder: (context, candidateData, _) {
                                      bool isHovering = candidateData.isNotEmpty;
                                      bool isFlashing = _flash[weather.id] ?? false;

                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isFlashing
                                                ? const Color(0xFFE05A5A)
                                                : isHovering
                                                ? LagoonColorTheme.ferngreen
                                                : Colors.white,
                                            width: isHovering || isFlashing ? 4 : 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isHovering
                                                  ? LagoonColorTheme.ferngreen.withValues(alpha: 0.55)
                                                  : Colors.black.withValues(alpha: 0.30),
                                              blurRadius: isHovering ? 18 : 12,
                                              spreadRadius: isHovering ? 2 : 0,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // --- Weather image area ---
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    ColorFiltered(
                                                      colorFilter: isHovering
                                                          ? const ColorFilter.mode(
                                                        Colors.transparent,
                                                        BlendMode.multiply,
                                                      )
                                                          : ColorFilter.mode(
                                                        Colors.black.withValues(alpha: 0.10),
                                                        BlendMode.darken,
                                                      ),
                                                      child: Image.asset(
                                                        weather.imagePath,
                                                        fit: BoxFit.cover,
                                                        alignment: Alignment.topCenter,
                                                      ),
                                                    ),
                                                    // Show matched clothing on top of card
                                                    if (_isMatched &&
                                                        currentClothing.targetWeatherId == weather.id)
                                                      Center(
                                                        child: Image.asset(
                                                          currentClothing.imagePath,
                                                          height: itemSize * 0.8,
                                                        ),
                                                      ),
                                                    if (isFlashing)
                                                      Positioned(
                                                        bottom: 6,
                                                        left: 0,
                                                        right: 0,
                                                        child: Center(
                                                          child: Text(
                                                            'Oops! ❌',
                                                            style: TextStyle(
                                                              fontFamily: LagoonAppTextStyles.fredoka,
                                                              fontSize: 14,
                                                              color: const Color(0xFFE05A5A),
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // --- Caption strip ---
                                            SizedBox(
                                              height: 38,
                                              child: Center(
                                                child: Text(
                                                  weather.name,
                                                  style: TextStyle(
                                                    fontFamily: LagoonAppTextStyles.fredoka,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: LagoonColorTheme.darkbrown,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // --- DRAGGABLE CLOTHING ITEM ---
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: _isMatched
                            ? const SizedBox.shrink()
                            : AnimatedBuilder(
                          animation: _floatingController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, -10 * _floatingController.value),
                              child: child,
                            );
                          },
                          child: Draggable<String>(
                            data: currentClothing.targetWeatherId,
                            feedback: _DraggableItem(
                              imagePath: currentClothing.imagePath,
                              size: itemSize,
                              isDragging: true,
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.0,
                              child: _DraggableItem(
                                imagePath: currentClothing.imagePath,
                                size: itemSize,
                              ),
                            ),
                            child: _DraggableItem(
                              imagePath: currentClothing.imagePath,
                              size: itemSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildProgressDots(),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: LagoonBackButton()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: LagoonColorTheme.pastelorange,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: LagoonColorTheme.wasteland, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Weather Match',
                style: TextStyle(
                  fontFamily: LagoonAppTextStyles.fredoka,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: LagoonColorTheme.wasteland,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_clothingItems.length, (i) {
        final done = i < _currentClothingIndex;
        final current = i == _currentClothingIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? LagoonColorTheme.darkbrown
                : current
                ? LagoonColorTheme.ferngreen
                : LagoonColorTheme.darkbrown.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildGoodJobOverlay() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/cat_holding_fishbone.png',
      closeButtonColor: LagoonColorTheme.darkbrown,
      onNext: () {
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(
        //     builder: (_) => const AnimalHabitatMatchScreen(level: 14),
        //   ),
        // );
      },
      onRestart: _restart,
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LagoonLevelScreen()),
              (route) => route.isFirst,
        );
      },
    );
  }
}

class _DraggableItem extends StatelessWidget {
  final String imagePath;
  final double size;
  final bool isDragging;

  const _DraggableItem({
    required this.imagePath,
    required this.size,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: isDragging ? 1.2 : 1.0,
        child: Container(
          height: size,
          decoration: BoxDecoration(
            boxShadow: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}