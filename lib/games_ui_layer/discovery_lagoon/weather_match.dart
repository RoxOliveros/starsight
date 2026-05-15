import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- GENERIC THEME ---
abstract class ColorTheme {
  static const Color background = Color(0xFFE8F4F8);
  static const Color textDark = Color(0xFF5E463E);
  static const Color primary = Color(0xFF75D5FF);
  static const Color success = Color(0xFF82C84B);
  static const Color accent = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class Weatherbg {
  final String id;
  final String imagePath;
  final String name;

  Weatherbg({required this.id, required this.imagePath, required this.name});
}

class Weather {
  final String name;
  final String imagePath;
  final String targetWeatherId;

  Weather({
    required this.name,
    required this.imagePath,
    required this.targetWeatherId,
  });
}

class WeatherMatch extends StatefulWidget {
  const WeatherMatch({super.key});

  @override
  State<WeatherMatch> createState() => _WeatherMatch();
}

class _WeatherMatch extends State<WeatherMatch>
    with SingleTickerProviderStateMixin {
  bool _isMatched = false;
  int _currentWeatherIndex = 0;
  late final AnimationController _floatingController;

  final List<Weatherbg> _Weatherbg = [
    Weatherbg(
      id: 'sunny',
      imagePath: 'assets/images/sunny_weather.png',
      name: 'Sunny',
    ),
    Weatherbg(
      id: 'rainy',
      imagePath: 'assets/images/rainy_weather.png',
      name: 'Rainy',
    ),
    Weatherbg(
      id: 'snowy',
      imagePath: 'assets/images/snowy_weather.png',
      name: 'Snowy',
    ),
  ];

  late List<Weather> _weather;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _weather = [
      Weather(
        name: 'Sunny',
        imagePath: 'assets/images/objects/sunny.png',
        targetWeatherId: 'sunny',
      ),
      Weather(
        name: 'Rainy',
        imagePath: 'assets/images/objects/rainy.png',
        targetWeatherId: 'rainy',
      ),
      Weather(
        name: 'Snowy',
        imagePath: 'assets/images/objects/winter.png',
        targetWeatherId: 'snowy',
      ),
    ]..shuffle();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _showSuccessDialog() {
    bool isLast = _currentWeatherIndex == _weather.length - 1;
    final currentWeather = _weather[_currentWeatherIndex];
    final correctWeatherbg = _Weatherbg.firstWhere(
      (h) => h.id == currentWeather.targetWeatherId,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Correct!",
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.success,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "The ${currentWeather.name} lives in the ${correctWeatherbg.name}!",
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 22,
            color: ColorTheme.textDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isMatched = false;
                if (isLast) {
                  _currentWeatherIndex = 0;
                  _weather.shuffle();
                } else {
                  _currentWeatherIndex++;
                }
              });
            },
            child: Text(
              isLast ? "Play Again" : "Next Weather",
              style: const TextStyle(
                color: ColorTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentWeather = _weather[_currentWeatherIndex];
    // Universal screen math
    final double screenHeight = MediaQuery.of(context).size.height;
    final double weatherSize = screenHeight * 0.35;

    return Scaffold(
      backgroundColor: ColorTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: ColorTheme.textDark,
                        size: 32,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Weather Match',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),

            // --- 3 HABITAT BACKGROUNDS (Drag Targets) ---
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: _Weatherbg.map((habitat) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: DragTarget<String>(
                          onWillAcceptWithDetails: (details) =>
                              details.data == habitat.id,
                          onAcceptWithDetails: (details) {
                            setState(() {
                              _isMatched = true;
                            });
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              _showSuccessDialog,
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            bool isHovering = candidateData.isNotEmpty;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isHovering
                                      ? ColorTheme.success
                                      : Colors.transparent,
                                  width: isHovering ? 6 : 0,
                                ),
                                boxShadow: [
                                  if (isHovering)
                                    BoxShadow(
                                      color: ColorTheme.success.withValues(alpha:
                                        0.6,
                                      ),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                ],
                                image: DecorationImage(
                                  image: AssetImage(habitat.imagePath),
                                  fit: BoxFit.cover,
                                  colorFilter: isHovering
                                      ? null
                                      : ColorFilter.mode(
                                          Colors.black.withValues(alpha: 0.1),
                                          BlendMode.darken,
                                        ),
                                ),
                              ),
                              child:
                                  _isMatched &&
                                      currentWeather.targetWeatherId ==
                                          habitat.id
                                  ? Center(
                                      child: Image.asset(
                                        currentWeather.imagePath,
                                        height:
                                            weatherSize *
                                            0.8, // Slightly smaller when placed
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // --- DRAGGABLE ANIMAL AREA ---
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
                          data: currentWeather.targetWeatherId,
                          feedback: _DraggableWeather(
                            imagePath: currentWeather.imagePath,
                            size: weatherSize,
                            isDragging: true,
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.0,
                            child: _DraggableWeather(
                              imagePath: currentWeather.imagePath,
                              size: weatherSize,
                            ),
                          ),
                          child: _DraggableWeather(
                            imagePath: currentWeather.imagePath,
                            size: weatherSize,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableWeather extends StatelessWidget {
  final String imagePath;
  final double size;
  final bool isDragging;

  const _DraggableWeather({
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
