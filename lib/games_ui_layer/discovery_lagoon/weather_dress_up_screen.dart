import 'dart:math';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';

class ClothingItem {
  final String id;
  final String imagePath;
  final String targetWeatherId;
  ClothingItem({required this.id, required this.imagePath, required this.targetWeatherId});
}

class WeatherDressUpScreen extends StatefulWidget {
  final int level;
  const WeatherDressUpScreen({super.key, required this.level});

  @override
  State<WeatherDressUpScreen> createState() => _WeatherDressUpScreenState();
}

class _WeatherDressUpScreenState extends State<WeatherDressUpScreen>
    with TickerProviderStateMixin {

  final List<Map<String, String>> _weathers = [
    {'id': 'sunny',  'label': 'Sunny ☀️',  'image': 'assets/images/objects/lagoon/weather/bg_sunny.png'},
    {'id': 'rainy',  'label': 'Rainy 🌧️',  'image': 'assets/images/objects/lagoon/weather/bg_rainy.png'},
    {'id': 'cloudy', 'label': 'Cloudy ⛅', 'image': 'assets/images/objects/lagoon/weather/bg_cloudy.png'},
    {'id': 'windy',  'label': 'Windy 💨',  'image': 'assets/images/objects/lagoon/weather/bg_windy.png'},
  ];

  final List<ClothingItem> _allItems = [
    ClothingItem(id: 'sunhat',    imagePath: 'assets/images/objects/lagoon/weather/sunhat.png',    targetWeatherId: 'sunny'),
    ClothingItem(id: 'umbrella',  imagePath: 'assets/images/objects/lagoon/weather/umbrella.png',  targetWeatherId: 'rainy'),
    ClothingItem(id: 'raincoat',  imagePath: 'assets/images/objects/lagoon/weather/raincoat.png',  targetWeatherId: 'rainy'),
    ClothingItem(id: 'sunscreen', imagePath: 'assets/images/objects/lagoon/weather/sunscreen.png', targetWeatherId: 'sunny'),
    ClothingItem(id: 'scarf',     imagePath: 'assets/images/objects/lagoon/weather/scarf.png',     targetWeatherId: 'windy'),
    ClothingItem(id: 'kite',      imagePath: 'assets/images/objects/lagoon/weather/kite.png',      targetWeatherId: 'windy'),
    ClothingItem(id: 'jacket',    imagePath: 'assets/images/objects/lagoon/weather/jacket.png',    targetWeatherId: 'cloudy'),
    ClothingItem(id: 'boots',     imagePath: 'assets/images/objects/lagoon/weather/boots.png',     targetWeatherId: 'rainy'),
  ];

  late List<ClothingItem> _roundItems;
  late Map<String, String> _currentWeather;
  final Set<String> _matched = {};
  late Set<String> _targetIds;

  int _roundIndex = 0;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _floatCtrl;

  String? _lastWrongId;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _startRound();
  }

  void _startRound() {
    final weathers = List.of(_weathers)..shuffle();
    _currentWeather = weathers[_roundIndex % weathers.length];
    final correct = _allItems.where((i) => i.targetWeatherId == _currentWeather['id']).toList();
    final wrong = _allItems.where((i) => i.targetWeatherId != _currentWeather['id']).toList()..shuffle();
    _roundItems = [...correct, ...wrong.take(4 - correct.length)]..shuffle();
    _targetIds = correct.map((i) => i.id).toSet();
    _matched.clear();
  }

  Future<void> _onDrop(ClothingItem item) async {
    if (_matched.contains(item.id)) return;
    if (item.targetWeatherId == _currentWeather['id']) {
      setState(() { _matched.add(item.id); });
      _bounceCtrl.forward(from: 0);
      if (_matched.length == _targetIds.length) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        if (_roundIndex >= _weathers.length - 1) {
          _showSuccessDialog();
        } else {
          setState(() { _roundIndex++; _startRound(); });
        }
      }
    } else {
      setState(() => _lastWrongId = item.id);
      _shakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _lastWrongId = null);
    }
  }

  void _showSuccessDialog() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      barrierColor: Colors.black54,
      builder: (_) => GoodJobOverlay(
        characterImage: 'assets/images/characters/cat_holding_fishbone.png',
        closeButtonColor: LagoonColorTheme.darkbrown,
        onNext: () => Navigator.pop(context),
        onRestart: () {
          Navigator.pop(context);
          setState(() { _roundIndex = 0; _startRound(); });
        },
        onBack: () { Navigator.pop(context); Navigator.pop(context); },
      ),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _bounceCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _currentWeather['image']!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradientForWeather(_currentWeather['id']!),
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 50,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(alignment: Alignment.centerLeft, child: LagoonBackButton()),
                        // Weather label badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentWeather['label']!,
                            style: TextStyle(
                              fontFamily: LagoonAppTextStyles.fredoka,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: LagoonColorTheme.darkbrown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Drop zone + character
                Expanded(
                  flex: 6,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return DragTarget<ClothingItem>(
                      onWillAcceptWithDetails: (_) => true,
                      onAcceptWithDetails: (details) => _onDrop(details.data),
                      builder: (context, candidates, _) {
                        final isHovering = candidates.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isHovering
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: isHovering
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Character
                              ScaleTransition(
                                scale: _bounceAnim,
                                child: Image.asset(
                                  'assets/images/objects/lagoon/weather/character.png',
                                  height: constraints.maxHeight * 0.75,
                                  errorBuilder: (_, __, ___) => Text('🧒',
                                      style: TextStyle(fontSize: constraints.maxHeight * 0.4)),
                                ),
                              ),
                              // Matched items shown on character
                              ..._matched.map((id) {
                                final item = _allItems.firstWhere((i) => i.id == id);
                                return Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Image.asset(item.imagePath,
                                        width: 48,
                                        errorBuilder: (_, __, ___) =>
                                        const Text('✅', style: TextStyle(fontSize: 28))),
                                  ),
                                );
                              }),
                              if (isHovering)
                                Positioned(
                                  bottom: 12,
                                  child: Text('Drop here!',
                                      style: TextStyle(
                                        fontFamily: LagoonAppTextStyles.fredoka,
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),

                // Draggable clothing row
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _roundItems.map((item) {
                        final isMatched = _matched.contains(item.id);
                        final isWrong = _lastWrongId == item.id;

                        Widget child = AnimatedOpacity(
                          opacity: isMatched ? 0.3 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: AnimatedBuilder(
                            animation: _floatCtrl,
                            builder: (_, c) => Transform.translate(
                              offset: Offset(0, -6 * _floatCtrl.value),
                              child: c,
                            ),
                            child: Image.asset(
                              item.imagePath,
                              height: 70,
                              errorBuilder: (_, __, ___) =>
                              const Text('👕', style: TextStyle(fontSize: 40)),
                            ),
                          ),
                        );

                        if (isWrong) {
                          child = AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (_, c) => Transform.translate(
                              offset: Offset(sin(_shakeAnim.value * pi * 5) * 8, 0),
                              child: c,
                            ),
                            child: child,
                          );
                        }

                        if (isMatched) return SizedBox(width: 70, child: child);

                        return Draggable<ClothingItem>(
                          data: item,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Transform.scale(
                              scale: 1.2,
                              child: Image.asset(item.imagePath, height: 70,
                                  errorBuilder: (_, __, ___) =>
                                  const Text('👕', style: TextStyle(fontSize: 40))),
                            ),
                          ),
                          childWhenDragging: Opacity(opacity: 0.2, child: child),
                          child: child,
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Progress dots
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_weathers.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: i == _roundIndex ? 28 : 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: i < _roundIndex
                              ? LagoonColorTheme.darkbrown
                              : i == _roundIndex
                              ? LagoonColorTheme.ferngreen
                              : LagoonColorTheme.darkbrown.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _gradientForWeather(String id) {
    switch (id) {
      case 'sunny':  return [const Color(0xFFFFE066), const Color(0xFF87CEEB)];
      case 'rainy':  return [const Color(0xFF607D8B), const Color(0xFF90A4AE)];
      case 'cloudy': return [const Color(0xFFB0BEC5), const Color(0xFFECEFF1)];
      case 'windy':  return [const Color(0xFF80DEEA), const Color(0xFFE0F7FA)];
      default:       return [Colors.blue, Colors.lightBlue];
    }
  }
}