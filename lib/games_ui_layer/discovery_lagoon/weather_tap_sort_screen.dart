import 'dart:math';
import 'package:StarSight/games_ui_layer/discovery_lagoon/treeparts_assembly.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'audio_helper.dart';
import 'intro_phase.dart';

class FallingIcon {
  final String id;
  final String weatherId;
  final String imagePath;
  double x;
  double y;
  final double speed;
  bool tapped;
  bool wrong;

  FallingIcon({
    required this.id,
    required this.weatherId,
    required this.imagePath,
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
    with TickerProviderStateMixin, LagoonIntroMixin {
  // ── Intro phase ────────────────────────────────────────────────────────

  final AudioPlayer _introPlayer = AudioPlayer();

  @override
  AudioPlayer get introAudioPlayer => _introPlayer;

  LagoonScreenPhase _screenPhase = LagoonScreenPhase.intro;

  // ── Game data ────────────────────────────────────────────────────────────

  final List<Map<String, dynamic>> _weathers = [
    {'id': 'sunny',  'label': 'Tap all Sunny things!', 'color': const Color(0xFFFFE066)},
    {'id': 'rainy',  'label': 'Tap all Rainy things!', 'color': const Color(0xFF90CAF9)},
    {'id': 'cloudy', 'label': 'Tap all Cloudy things!', 'color': const Color(0xFFCFD8DC)},
    {'id': 'windy',  'label': 'Tap allWindy things!', 'color': const Color(0xFFB2EBF2)},
  ];

  final Map<String, String> _weatherBgImage = {
    'sunny': 'assets/images/objects/lagoon/sunny_day_phase3.png',
    'rainy': 'assets/images/objects/lagoon/rainy_day_phase2.png',
    'cloudy': 'assets/images/objects/lagoon/cloudy_day_phase3.png',
    'windy': 'assets/images/objects/lagoon/windy_day_phase2.png',
  };

  final Map<String, List<String>> _items = {
    'sunny':  [
      'assets/images/objects/lagoon/sunglasses.png',
      'assets/images/objects/lagoon/rainbow.png',
      'assets/images/objects/lagoon/sun.png',
    ],
    'rainy':  [
      'assets/images/objects/lagoon/raincloud.png',
      'assets/images/objects/lagoon/rainy_puddle.png',
      'assets/images/objects/lagoon/rainy_umbrella_boots.png',
    ],
    'cloudy': [
      'assets/images/objects/lagoon/graycloud.png',
      'assets/images/objects/lagoon/cloudy_jacket.png',
      'assets/images/objects/lagoon/cloudy_blanket.png',
    ],
    'windy':  [
      'assets/images/objects/lagoon/strong_wind.png',
      'assets/images/objects/lagoon/windy_kite.png',
      'assets/images/objects/lagoon/windy_pinwheel.png',
    ],
  };

  /// Question line played when a weather round starts.
  static String _questionKey(String weatherId) => 'tapsort_q_$weatherId';

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
    _startRound(playPrompt: false);

    initLagoonIntro();
    startLagoonIntro(
      introAudioAsset: 'assets/audio/discovery_lagoon/tapsort_intro.wav',
      onGameStart: () {
        if (!mounted) return;
        setState(() => _screenPhase = LagoonScreenPhase.game);
        LagoonAudio.instance.play(_questionKey(_currentWeather['id'] as String));
      },
    );
  }

  void _startRound({bool playPrompt = true}) {
    _currentWeather = _weathers[_roundIndex];
    _icons.clear();
    _score = 0;
    _roundComplete = false;
    _needed = 5;
    _spawnInitialIcons();

    if (playPrompt) {
      LagoonAudio.instance.play(_questionKey(_currentWeather['id'] as String));
    }
  }

  void _spawnInitialIcons() {
    for (int i = 0; i < 5; i++) {
      _spawnIcon();
    }
  }

  void _spawnIcon() {
    final isCorrect = _rng.nextBool();
    final currentId = _currentWeather['id'] as String;

    String chosenWeatherId;
    String imagePath;

    if (isCorrect) {
      chosenWeatherId = currentId;
      final pool = _items[currentId]!;
      imagePath = pool[_rng.nextInt(pool.length)];
    } else {
      final otherWeatherIds = _items.keys.where((id) => id != currentId).toList();
      chosenWeatherId = otherWeatherIds[_rng.nextInt(otherWeatherIds.length)];
      final pool = _items[chosenWeatherId]!;
      imagePath = pool[_rng.nextInt(pool.length)];
    }

    _icons.add(FallingIcon(
      id: UniqueKey().toString(),
      weatherId: isCorrect ? currentId : 'other',
      imagePath: imagePath,
      x: _rng.nextDouble() * 0.9 + 0.05,
      y: -0.1 - _rng.nextDouble() * 0.3,
      speed: 0.001 + _rng.nextDouble() * 0.002,
    ));
  }

  void _tick() {
    if (!mounted || _roundComplete || _screenPhase != LagoonScreenPhase.game) return;
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
      LagoonAudio.instance.play('correct');
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
        onNext: (){
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const TreePartsAssemblyScreen(level: 20),
            ),
          );
        },
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
    disposeLagoonIntro();
    _introPlayer.dispose();
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
              Positioned.fill(
                child: Image.asset(
                  _weatherBgImage[_currentWeather['id']]!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Container(
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
              ),

              // Falling icons — only shown once the game phase starts.
              if (_screenPhase == LagoonScreenPhase.game)
                ..._icons.where((i) => !i.tapped).map((icon) {
                  return Positioned(
                    left: icon.x * w - 30,
                    top: icon.y * h - 30,
                    child: GestureDetector(
                      onTap: () => _onTap(icon),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 100,
                        height: 100,
                        decoration: icon.wrong
                            ? BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        )
                            : null,
                        child: Center(
                          child: Image.asset(
                            icon.imagePath,
                            width: icon.wrong ? 100 : 100,
                            height: icon.wrong ? 100 : 100,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_not_supported,
                              size: 28,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              // UI overlay
              SafeArea(
                child: _screenPhase == LagoonScreenPhase.intro
                    ? _buildIntroContent()
                    : _buildGameContent(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIntroContent() {
    return Stack(
      children: [
        const Positioned(top: 8, left: 12, child: LagoonBackButton()),
        Positioned.fill(top: 48, child: buildLagoonIntroCharacter()),
      ],
    );
  }

  Widget _buildGameContent() {
    return Column(
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
                    color: LagoonColorTheme.pastelorange,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: LagoonColorTheme.wasteland, width: 5),
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
    );
  }
}