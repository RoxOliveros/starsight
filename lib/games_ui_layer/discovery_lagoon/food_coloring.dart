import 'dart:math';
import 'dart:ui' as ui;
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_background.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';

class FoodItem {
  final String id;
  final String imagePath;
  final bool isHealthy;

  FoodItem({
    required this.id,
    required this.imagePath,
    required this.isHealthy,
  });
}

class FoodColoringScreen extends StatefulWidget {
  final int level;

  const FoodColoringScreen({super.key, required this.level});

  @override
  State<FoodColoringScreen> createState() => _FoodColoringScreenState();
}

class _FoodColoringScreenState extends State<FoodColoringScreen>
    with TickerProviderStateMixin {

  // Selected color from palette
  Color? _selectedColor;

  // Track which healthy foods have been colored (ids are unique across
  // both rounds, so one flat set works fine for the whole game)
  final Set<String> _coloredHealthy = {};

  bool _showWinDialog = false;
  bool _showRoundComplete = false;

  // Which round (0 or 1) the player is currently on
  int _currentRound = 0;

  final Map<String, List<PaintPoint>> _paintStrokes = {}; // foodId → strokes
  String? _activeFoodId; // which food is currently being painted

  // One GlobalKey per food card, so we can find the *correct* local
  // RenderBox for each food when converting pan/drag positions.
  final Map<String, GlobalKey> _paintKeys = {};
  GlobalKey _keyFor(String foodId) =>
      _paintKeys.putIfAbsent(foodId, () => GlobalKey());

  final Map<String, Offset?> _lastPanPos = {};

  // Decoded image for each food — used as the alpha "stencil" that clips
  // paint strokes to the exact shape of the food, the same trick the
  // alphabet game uses to keep paint inside the letter.
  final Map<String, ui.Image> _foodImages = {};
  final List<ImageStreamListener> _imageListeners = [];

  final List<FoodItem> _foods = [
    FoodItem(id: 'carrot',    imagePath: 'assets/images/objects/lagoon/carrot.png',    isHealthy: true),
    FoodItem(id: 'apple',     imagePath: 'assets/images/objects/lagoon/apple.png',     isHealthy: true),
    FoodItem(id: 'banana',    imagePath: 'assets/images/objects/lagoon/banana.png',    isHealthy: true),
    FoodItem(id: 'broccoli',  imagePath: 'assets/images/objects/lagoon/brocoli.png',   isHealthy: true),
    FoodItem(id: 'fish',      imagePath: 'assets/images/objects/lagoon/fish.png',      isHealthy: true),
    FoodItem(id: 'salad',     imagePath: 'assets/images/objects/lagoon/salad.png',     isHealthy: true),
    FoodItem(id: 'burger',    imagePath: 'assets/images/objects/lagoon/burger.png',    isHealthy: false),
    FoodItem(id: 'softdrink', imagePath: 'assets/images/objects/lagoon/softdrink.png', isHealthy: false),
    FoodItem(id: 'donut',     imagePath: 'assets/images/objects/lagoon/donut.png',     isHealthy: false),
    FoodItem(id: 'icecream',  imagePath: 'assets/images/objects/lagoon/icecream.png',  isHealthy: false),
    FoodItem(id: 'pizza',     imagePath: 'assets/images/objects/lagoon/pizza.png',     isHealthy: false),
    FoodItem(id: 'candy',     imagePath: 'assets/images/objects/lagoon/candy.png',     isHealthy: false),
  ];

  // Shake animation for wrong tap
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  String? _shakingId;

  // Pop animation for correct tap
  late AnimationController _popCtrl;
  late Animation<double> _popAnim;
  String? _poppingId;

  final List<Color> _palette = [
    const Color(0xFFE74C3C), // red
    const Color(0xFFE67E22), // orange
    const Color(0xFFF1C40F), // yellow
    const Color(0xFF2ECC71), // green
    const Color(0xFF3498DB), // blue
    const Color(0xFF9B59B6), // purple
    const Color(0xFFE91E8C), // pink
    const Color(0xFF795548), // brown
    const Color(0xFF646D78), // gray
  ];

  List<FoodItem> get _healthyFoods => _foods.where((f) => f.isHealthy).toList();
  List<FoodItem> get _unhealthyFoods => _foods.where((f) => !f.isHealthy).toList();

  // Split into 2 rounds, each with half the healthy items and half the
  // unhealthy items, so every round still has both kinds to choose
  // between (rather than "round 1 = only healthy, round 2 = only junk").
  // Splitting in half also means each round only renders 6 cards instead
  // of 12, which is what gives them more room to be drawn bigger.
  // The healthy/unhealthy pools are shuffled before splitting, and the
  // result is cached in `_rounds` (computed once per game, not on every
  // access), so which specific foods land in round 1 vs round 2 changes
  // each playthrough while still guaranteeing no food appears in both.
  late List<List<FoodItem>> _rounds = _buildRounds();

  List<List<FoodItem>> _buildRounds() {
    final healthy = List<FoodItem>.from(_healthyFoods)..shuffle();
    final unhealthy = List<FoodItem>.from(_unhealthyFoods)..shuffle();
    final hHalf = (healthy.length / 2).ceil();
    final uHalf = (unhealthy.length / 2).ceil();
    return [
      [...healthy.sublist(0, hHalf), ...unhealthy.sublist(0, uHalf)]..shuffle(),
      [...healthy.sublist(hHalf), ...unhealthy.sublist(uHalf)]..shuffle(),
    ];
  }

  List<FoodItem> get _currentRoundFoods => _rounds[_currentRound];
  List<FoodItem> get _currentRoundHealthy =>
      _currentRoundFoods.where((f) => f.isHealthy).toList();
  int get _coloredInCurrentRound =>
      _currentRoundHealthy.where((f) => _coloredHealthy.contains(f.id)).length;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );

    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _popAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _popCtrl, curve: Curves.elasticOut),
    );

    _loadFoodImages();
  }

  // Decode every food's PNG once up front so the painter can use its
  // alpha channel as a stencil. Without this, paint would just smear
  // across a rectangle instead of staying inside the food's silhouette.
  void _loadFoodImages() {
    for (final food in _foods) {
      final provider = AssetImage(food.imagePath);
      final stream = provider.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((info, _) {
        if (!mounted) return;
        setState(() => _foodImages[food.id] = info.image);
      });
      _imageListeners.add(listener);
      stream.addListener(listener);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _popCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _onFoodPanStart(FoodItem food, Offset localPos) {
    if (_selectedColor == null) return;
    if (!food.isHealthy) {
      _triggerShake(food.id);
      return;
    }
    setState(() => _activeFoodId = food.id);
    _lastPanPos[food.id] = localPos;
  }

  void _onFoodPanUpdate(FoodItem food, Offset localPos, Size canvasSize) {
    if (_selectedColor == null || !food.isHealthy) return;
    if (_activeFoodId != food.id) return;

    final strokes = _paintStrokes.putIfAbsent(food.id, () => []);
    final last = _lastPanPos[food.id] ?? localPos;
    final rng = Random();

    // Scale the brush to the card's actual rendered size, so bigger cards
    // (like these 6-per-round ones) get a proportionally bigger brush
    // instead of a tiny fixed-size dot that'd take forever to fill in.
    final brush = canvasSize.shortestSide * 0.14;

    // Interpolate between the last point and this one so a fast drag
    // leaves a continuous painted line instead of separate dabs.
    final distance = (localPos - last).distance;
    final steps = max(1, (distance / 4).round());
    for (int s = 0; s <= steps; s++) {
      final t = s / steps;
      final p = Offset.lerp(last, localPos, t)!;
      for (int i = 0; i < 2; i++) {
        final jx = (rng.nextDouble() - 0.5) * brush * 0.3;
        final jy = (rng.nextDouble() - 0.5) * brush * 0.3;
        strokes.add(PaintPoint(
          position: Offset(p.dx + jx, p.dy + jy),
          color: _selectedColor!.withValues(alpha: 0.0001 + rng.nextDouble() * 0.15),
          radius: brush * (0.7 + rng.nextDouble() * 0.4),
        ));
      }
    }

    _lastPanPos[food.id] = localPos;
    _checkCoverage(food.id, canvasSize);
    setState(() {});
  }

  void _onFoodPanEnd(FoodItem food) {
    _activeFoodId = null;
    _lastPanPos.remove(food.id);
  }

  void _checkCoverage(String foodId, Size canvasSize) {
    final strokes = _paintStrokes[foodId] ?? [];
    if (strokes.isEmpty) return;

    const int grid = 20;
    final cw = canvasSize.width / grid;
    final ch = canvasSize.height / grid;
    int covered = 0;

    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        final pt = Offset(c * cw + cw / 2, r * ch + ch / 2);
        for (final p in strokes) {
          if ((p.position - pt).distance < p.radius * 1.5) {
            covered++;
            break;
          }
        }
      }
    }

    final coverage = covered / (grid * grid);
    if (coverage >= 0.45 && !_coloredHealthy.contains(foodId)) {
      setState(() => _coloredHealthy.add(foodId));
      _poppingId = foodId;
      _popCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _poppingId = null);
      });

      final roundDone =
      _currentRoundHealthy.every((f) => _coloredHealthy.contains(f.id));
      if (roundDone) {
        final isLastRound = _currentRound == _rounds.length - 1;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            if (isLastRound) {
              _showWinDialog = true;
            } else {
              _currentRound++;
            }
          });
        });
      }
    }
  }

  void _triggerShake(String id) {
    setState(() => _shakingId = id);
    _shakeCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _shakingId = null);
    });
  }

  void _goToNextRound() {
    setState(() {
      _currentRound++;
      _showRoundComplete = false;
    });
  }

  void _resetGame() {
    setState(() {
      _paintStrokes.clear();
      _coloredHealthy.clear();
      _selectedColor = null;
      _showWinDialog = false;
      _showRoundComplete = false;
      _currentRound = 0;
      _rounds = _buildRounds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LagoonBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 4),
                  // Food grid
                  Expanded(child: _buildFoodGrid()),
                  // Color palette
                  _buildPalette(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (_showRoundComplete) Positioned.fill(child: _buildRoundCompleteOverlay()),
            if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: LagoonBackButton(),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: LagoonColorTheme.pastelorange,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: LagoonColorTheme.wasteland, width: 4),
                ),
                child: const Text(
                  'Color the Healthy Foods!',
                  style: TextStyle(
                    fontFamily: LagoonAppTextStyles.fredoka,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: LagoonColorTheme.wasteland,
                  ),
                ),
              ),
            ],
          ),
          // Progress chip — scoped to the current round
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LagoonColorTheme.ferngreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_coloredInCurrentRound/${_currentRoundHealthy.length}',
                style: const TextStyle(
                  fontFamily: LagoonAppTextStyles.fredoka,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodGrid() {
    final foods = _currentRoundFoods;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A real grid (not hand-picked scattered fractions) guarantees
        // cards can never overlap — each card is confined to its own
        // cell, centered within it. With only 6 foods per round instead
        // of 12, each cell — and therefore each card — is roughly twice
        // as large as before.
        const columns = 3;
        final rows = (foods.length / columns).ceil();

        final cellWidth = constraints.maxWidth / columns;
        final cellHeight = constraints.maxHeight / rows;
        final itemSize = min(cellWidth, cellHeight) * 0.82;

        return Stack(
          children: List.generate(foods.length, (i) {
            final food = foods[i];
            final col = i % columns;
            final row = i ~/ columns;
            final cellLeft = col * cellWidth;
            final cellTop = row * cellHeight;
            final left = cellLeft + (cellWidth - itemSize) / 2;
            final top = cellTop + (cellHeight - itemSize) / 2;
            return Positioned(
              left: left,
              top: top,
              child: _buildFoodCard(food, itemSize),
            );
          }),
        );
      },
    );
  }

  Widget _buildFoodCard(FoodItem food, double size) {
    final isShaking = _shakingId == food.id;
    final isPopping = _poppingId == food.id;
    final isDone = _coloredHealthy.contains(food.id);
    final foodImage = _foodImages[food.id];

    Widget card = AnimatedBuilder(
      animation: Listenable.merge([_shakeCtrl, _popCtrl]),
      builder: (context, child) {
        double dx = 0;
        double scale = 1.0;
        if (isShaking) {
          dx = 6 * (0.5 - _shakeAnim.value).abs() * ((_shakeAnim.value * 8).floor().isEven ? 1 : -1);
        }
        if (isPopping) {
          scale = _popAnim.value;
        }
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            GestureDetector(
              key: _keyFor(food.id),
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                // Quick tap with no drag: shake if unhealthy or no color picked
                if (!food.isHealthy || _selectedColor == null) {
                  _triggerShake(food.id);
                }
              },
              onPanStart: (d) {
                final box = _keyFor(food.id).currentContext?.findRenderObject() as RenderBox?;
                if (box == null) return;
                _onFoodPanStart(food, box.globalToLocal(d.globalPosition));
              },
              onPanUpdate: (d) {
                final box = _keyFor(food.id).currentContext?.findRenderObject() as RenderBox?;
                if (box == null) return;
                _onFoodPanUpdate(food, box.globalToLocal(d.globalPosition), box.size);
              },
              onPanEnd: (_) => _onFoodPanEnd(food),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // foodImage being null only happens for a frame or two
                // while the asset decodes; the painter just no-ops until then.
                child: CustomPaint(
                  painter: _FoodColorPainter(
                    strokes: _paintStrokes[food.id] ?? [],
                    foodImage: foodImage,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (isDone)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: LagoonColorTheme.ferngreen, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );

    return card;
  }

  Widget _buildPalette() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Eraser / clear selection
          GestureDetector(
            onTap: () => setState(() => _selectedColor = null),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedColor == null
                      ? LagoonColorTheme.ferngreen
                      : Colors.black26,
                  width: _selectedColor == null ? 3 : 1.5,
                ),
              ),
              child: const Icon(Icons.restart_alt_rounded, size: 20, color: Colors.black54),
            ),
          ),
          ..._palette.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 44 : 36,
                height: isSelected ? 44 : 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.black26,
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)]
                      : [],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Shown between round 1 and round 2 — distinct from the final
  // GoodJobOverlay, since reaching the end of round 1 isn't level
  // completion yet.
  Widget _buildRoundCompleteOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: LagoonColorTheme.wasteland, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Round ${_currentRound + 1} Complete!',
                style: const TextStyle(
                  fontFamily: LagoonAppTextStyles.fredoka,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: LagoonColorTheme.wasteland,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Great coloring! Let\'s keep going.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _goToNextRound,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: LagoonColorTheme.ferngreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Next Round',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoodJobOverlay() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/cat_holding_fishbone.png',
      closeButtonColor: LagoonColorTheme.darkbrown,
      onNext: () {
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(builder: (_) => const NextScreen(level: widget.level + 1)),
        // );
      },
      onRestart: _resetGame,
      onBack: () {
        Navigator.of(context).pop();
      },
    );
  }
}

class PaintPoint {
  final Offset position;
  final Color color;
  final double radius;
  PaintPoint({required this.position, required this.color, required this.radius});
}

class _FoodColorPainter extends CustomPainter {
  final List<PaintPoint> strokes;
  final ui.Image? foodImage;

  _FoodColorPainter({
    required this.strokes,
    required this.foodImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final image = foodImage;
    if (image == null) return;

    final rect = Offset.zero & size;

    // 1. Draw the food art itself in full color as the base image.
    paintImage(
      canvas: canvas,
      rect: rect,
      image: image,
      fit: BoxFit.contain,
    );

    if (strokes.isEmpty) return;

    // 2. Paint the user's color strokes into an offscreen layer.
    canvas.saveLayer(rect, Paint());
    for (final p in strokes) {
      final strokePaint = Paint()
        ..color = p.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, p.radius, strokePaint);
    }

    // 3. Cut that layer down to exactly the food's silhouette using the
    //    food image's own alpha channel as a stencil — this is the same
    //    "dstIn mask" trick the alphabet letter-paint screen uses, just
    //    with an image mask instead of a text mask. Anything painted
    //    outside the food's shape gets clipped away here.
    final dstInPaint = Paint()..blendMode = BlendMode.dstIn;
    canvas.saveLayer(rect, dstInPaint);
    paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.contain);
    canvas.restore(); // apply dstIn mask
    canvas.restore(); // merge masked strokes onto the food art
  }

  @override
  bool shouldRepaint(_FoodColorPainter old) =>
      old.strokes.length != strokes.length || old.foodImage != foodImage;
}