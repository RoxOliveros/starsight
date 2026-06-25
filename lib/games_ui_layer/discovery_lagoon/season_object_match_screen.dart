import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/weather_scene_builder_screen.dart';
import 'package:flutter/material.dart';

import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_level.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';

/// One of the four seasons, with its Polaroid-card background image.
class Season {
  final String id;
  final String imagePath;
  final String name;

  Season({required this.id, required this.imagePath, required this.name});
}

/// A clothing/seasonal item the child drags onto the matching [Season].
class SeasonItem {
  final String name;
  final String imagePath;
  final String targetSeasonId;

  SeasonItem({
    required this.name,
    required this.imagePath,
    required this.targetSeasonId,
  });
}

class SeasonObjectMatchScreen extends StatefulWidget {
  final int level;

  const SeasonObjectMatchScreen({super.key, required this.level});

  @override
  State<SeasonObjectMatchScreen> createState() =>
      _SeasonObjectMatchScreenState();
}

class _SeasonObjectMatchScreenState extends State<SeasonObjectMatchScreen>
    with TickerProviderStateMixin {
  bool _isMatched = false;
  int _currentItemIndex = 0;
  late final AnimationController _floatingController;

  // Bounce-on-correct-drop animation
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  // Wrong-drop flash state, keyed by season id
  final Map<String, bool> _flash = {};

  bool _showWinDialog = false;

  final List<Season> _seasons = [
    Season(
      id: 'spring',
      imagePath: 'assets/images/objects/lagoon/spring.png',
      name: 'Spring',
    ),
    Season(
      id: 'summer',
      imagePath: 'assets/images/objects/lagoon/summer.png',
      name: 'Summer',
    ),
    Season(
      id: 'fall',
      imagePath: 'assets/images/objects/lagoon/autumn.png',
      name: 'Fall',
    ),
    Season(
      id: 'winter',
      imagePath: 'assets/images/objects/lagoon/winter.png',
      name: 'Winter',
    ),
  ];

  late List<SeasonItem> _items;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _items = [
      SeasonItem(
        name: 'Flower',
        imagePath: 'assets/images/objects/lagoon/flower.png',
        targetSeasonId: 'spring',
      ),
      SeasonItem(
        name: 'Sunglasses',
        imagePath: 'assets/images/objects/lagoon/sunglasses.png',
        targetSeasonId: 'summer',
      ),
      SeasonItem(
        name: 'Pumpkin',
        imagePath: 'assets/images/objects/lagoon/pumpkin.png',
        targetSeasonId: 'fall',
      ),
      SeasonItem(
        name: 'Mittens',
        imagePath: 'assets/images/objects/lagoon/mittens.png',
        targetSeasonId: 'winter',
      ),
    ]..shuffle();

    for (final s in _seasons) {
      _flash[s.id] = false;
    }

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _bounceCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  bool get _isLast => _currentItemIndex == _items.length - 1;

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
        _currentItemIndex++;
      });
    }
  }

  Future<void> _onWrongDrop(String seasonId) async {
    setState(() => _flash[seasonId] = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _flash[seasonId] = false);
  }

  void _restart() {
    setState(() {
      _isMatched = false;
      _showWinDialog = false;
      _currentItemIndex = 0;
      _items.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _items[_currentItemIndex];
    final double screenHeight = MediaQuery.of(context).size.height;
    final double itemSize = screenHeight * 0.30;

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

                    // --- 4 SEASON CARDS (Drag Targets) ---
                    Expanded(
                      flex: 7,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: _seasons.map((season) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                ),
                                child: ScaleTransition(
                                  scale:
                                      (currentItem.targetSeasonId ==
                                              season.id &&
                                          _isMatched)
                                      ? _bounceAnim
                                      : const AlwaysStoppedAnimation(1.0),
                                  child: DragTarget<String>(
                                    onWillAcceptWithDetails: (details) => true,
                                    onAcceptWithDetails: (details) {
                                      if (details.data == season.id) {
                                        _onCorrectDrop();
                                      } else {
                                        _onWrongDrop(season.id);
                                      }
                                    },
                                    builder: (context, candidateData, _) {
                                      bool isHovering =
                                          candidateData.isNotEmpty;
                                      bool isFlashing =
                                          _flash[season.id] ?? false;

                                      return _buildSeasonCard(
                                        season: season,
                                        currentItem: currentItem,
                                        itemSize: itemSize,
                                        isHovering: isHovering,
                                        isFlashing: isFlashing,
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

                    // --- DRAGGABLE ITEM AREA ---
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: _isMatched
                            ? const SizedBox.shrink()
                            : AnimatedBuilder(
                                animation: _floatingController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      0,
                                      -10 * _floatingController.value,
                                    ),
                                    child: child,
                                  );
                                },
                                child: Draggable<String>(
                                  data: currentItem.targetSeasonId,
                                  feedback: _DraggableItem(
                                    imagePath: currentItem.imagePath,
                                    size: itemSize,
                                    isDragging: true,
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.0,
                                    child: _DraggableItem(
                                      imagePath: currentItem.imagePath,
                                      size: itemSize,
                                    ),
                                  ),
                                  child: _DraggableItem(
                                    imagePath: currentItem.imagePath,
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

  // ── Season card (Polaroid style: photo on top, caption strip below) ──────

  Widget _buildSeasonCard({
    required Season season,
    required SeasonItem currentItem,
    required double itemSize,
    required bool isHovering,
    required bool isFlashing,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
          // --- Photo area ---
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
                      season.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: LagoonColorTheme.pastelorange,
                        child: const Center(
                          child: Text('🌿', style: TextStyle(fontSize: 40)),
                        ),
                      ),
                    ),
                  ),
                  if (_isMatched && currentItem.targetSeasonId == season.id)
                    Center(
                      child: Image.asset(
                        currentItem.imagePath,
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
                            fontSize: 13,
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
          // --- Caption strip below photo ---
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                season.name,
                style: TextStyle(
                  fontFamily: LagoonAppTextStyles.fredoka,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: LagoonColorTheme.darkbrown,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: LagoonBackButton()),
          ],
        ),
      ),
    );
  }

  // ── Progress dots ─────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_items.length, (i) {
        final done = i < _currentItemIndex;
        final current = i == _currentItemIndex;
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

  // ── Win overlay ───────────────────────────────────────────────────────────

  Widget _buildGoodJobOverlay() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/cat_holding_fishbone.png',
      closeButtonColor: LagoonColorTheme.darkbrown,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const WeatherSceneBuilderScreen(level: 16),
          ),
        );
      },
      onRestart: () {
        _restart();
      },
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LagoonLevelScreen()),
              (route) => route.isFirst,
        );
      },
    );
  }
}

// Helper widget for the draggable clothing/item image
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
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('🧥', style: TextStyle(fontSize: 60)),
          ),
        ),
      ),
    );
  }
}
