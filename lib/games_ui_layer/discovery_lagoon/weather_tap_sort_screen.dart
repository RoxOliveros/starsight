import 'dart:math';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';

class FallingIcon {
  final String id;
  final String weatherId;
  final String emoji;
  double x;
  double y;
  final double speed;
  bool tapped;
  bool wrong;

  FallingIcon({
    required this.id,
    required this.weatherId,
    required this.emoji,
    required this.x,
    required this.y,
    required this.speed,
    this.tapped = false,
    this.wrong = false,
  });
}

class WeatherTapSortScreen extends StatefulWidget {
  final int level;
  const WeatherTapSortScreen({super.key, required this.level});

  @override
  State<WeatherTapSortScreen> createState() => _WeatherTapSortScreenState();
}

class _WeatherTapSortScreenState extends State<WeatherTapSortScreen>
    with SingleTickerProviderStateMixin {

  final List<Map<String, dynamic>> _weathers = [
    {'id': 'sunny',  'label': 'Tap all ☀️ Sunny things!', 'emojis': ['☀️', '🌤️', '😎'], 'color': const Color(0xFFFFE066)},
    {'id': 'rainy',  'label': 'Tap all 🌧️ Rainy things!', 'emojis': ['🌧️', '☔', '💧'], 'color': const Color(0xFF90CAF9)},
    {'id': 'cloudy', 'label': 'Tap all ⛅ Cloudy things!', 'emojis': ['☁️', '⛅', '🌥️'], 'color': const Color(0xFFCFD8DC)},
    {'id': 'windy',  'label': 'Tap all 💨 Windy things!', 'emojis': ['💨', '🍃', '🪁'], 'color': const Color(0xFFB2EBF2)},
  ];

  final Map<String, List<String>> _decoyEmojis = {
    'sunny':  ['🌧️', '☁️', '💨', '☔', '🍃'],
    'rainy':  ['☀️', '💨', '🌤️', '😎', '🍃'],
    'cloudy': ['☀️', '🌧️', '💨', '😎', '💧'],
    'windy':  ['☀️', '🌧️', '☁️', '💧', '😎'],
  };

  int _roundIndex = 0;
  late Map<String, dynamic> _currentWeather;
  final List<FallingIcon> _icons = [];
  int _score = 0;
  int _needed = 0;
  bool _roundComplete = false;

  late AnimationController _tickCtrl;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _tickCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_tick)
      ..repeat();
    _startRound();
  }

  void _startRound() {
    _currentWeather = _weathers[_roundIndex];
    _icons.clear();
    _score = 0;
    _roundComplete = false;
    _needed = (_currentWeather['emojis'] as List).length * 2;
    _spawnInitialIcons();
  }

  void _spawnInitialIcons() {
    for (int i = 0; i < 10; i++) {
      _spawnIcon();
    }
  }

  void _spawnIcon() {
    final isCorrect = _rng.nextBool();
    final correctEmojis = _currentWeather['emojis'] as List<String>;
    final decoys = _decoyEmojis[_currentWeather['id']]!;

    final emoji = isCorrect
        ? correctEmojis[_rng.nextInt(correctEmojis.length)]
        : decoys[_rng.nextInt(decoys.length)];

    _icons.add(FallingIcon(
      id: UniqueKey().toString(),
      weatherId: isCorrect ? _currentWeather['id'] : 'other',
      emoji: emoji,
      x: _rng.nextDouble() * 0.9 + 0.05,
      y: -0.1 - _rng.nextDouble() * 0.3,
      speed: 0.001 + _rng.nextDouble() * 0.002,
    ));
  }

  void _tick() {
    if (!mounted || _roundComplete) return;
    setState(() {
      for (final icon in _icons) {
        if (!icon.tapped) icon.y += icon.speed;
      }
      _icons.removeWhere((i) => i.y > 1.1 && !i.tapped);
      while (_icons.where((i) => !i.tapped).length < 8) {
        _spawnIcon();
      }
    });
  }

  Future<void> _onTap(FallingIcon icon) async {
    if (icon.tapped) return;

    if (icon.weatherId == _currentWeather['id']) {
      setState(() {
        icon.tapped = true;
        _score++;
      });
      if (_score >= _needed) {
        setState(() => _roundComplete = true);
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        if (_roundIndex >= _weathers.length - 1) {
          _showSuccessDialog();
        } else {
          setState(() { _roundIndex++; _startRound(); });
        }
      }
    } else {
      setState(() => icon.wrong = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => icon.tapped = true);
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
    _tickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // Background
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (_currentWeather['color'] as Color).withValues(alpha: 0.8),
                        (_currentWeather['color'] as Color),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Falling icons
              ..._icons.where((i) => !i.tapped).map((icon) {
                return Positioned(
                  left: icon.x * w - 30,
                  top: icon.y * h - 30,
                  child: GestureDetector(
                    onTap: () => _onTap(icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 60,
                      height: 60,
                      decoration: icon.wrong
                          ? BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      )
                          : null,
                      child: Center(
                        child: Text(
                          icon.emoji,
                          style: TextStyle(fontSize: icon.wrong ? 28 : 36),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // UI overlay
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(alignment: Alignment.centerLeft, child: LagoonBackButton()),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: LagoonColorTheme.darkbrown,
                                ),
                              ),
                            ),
                            // Score badge
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: LagoonColorTheme.ferngreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_score / $_needed',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Progress dots
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                                  : Colors.white.withValues(alpha: 0.4),
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
          );
        },
      ),
    );
  }
}