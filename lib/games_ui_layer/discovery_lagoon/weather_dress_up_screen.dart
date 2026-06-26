import 'dart:async';
import 'dart:math';
import 'package:StarSight/games_ui_layer/discovery_lagoon/weather_tap_sort_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_level.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'audio_helper.dart';
import 'intro_phase.dart';

/// ---------------------------------------------------------------------------
/// MODELS
/// ---------------------------------------------------------------------------

class ClothingItem {
  final String id;
  final String imagePath;
  final String targetWeatherId;

  ClothingItem({
    required this.id,
    required this.imagePath,
    required this.targetWeatherId,
  });
}

class WeatherInfo {
  final String id;
  final String label;
  final String bgImage;

  const WeatherInfo({
    required this.id,
    required this.label,
    required this.bgImage,
  });
}

/// ---------------------------------------------------------------------------
/// CHARACTER IMAGE RESOLVER
/// ---------------------------------------------------------------------------

class CharacterImageResolver {
  static const String basePath = 'assets/images/objects/lagoon/boy.png';
  static const String folder = 'assets/images/objects/lagoon';

  /// Builds the path for whatever combination of items is currently matched
  /// within the given weather.
  static String resolve(String weatherId, Set<String> matchedIds) {
    if (matchedIds.isEmpty) return basePath;
    final sortedIds = matchedIds.toList()..sort();
    return '$folder/character_${weatherId}_${sortedIds.join('_')}.png';
  }
}

/// ---------------------------------------------------------------------------
/// STATIC GAME DATA
/// ---------------------------------------------------------------------------

class WeatherDressUpData {
  static const List<WeatherInfo> weathers = [
    WeatherInfo(
      id: 'sunny',
      label: 'Sunny',
      bgImage: 'assets/images/objects/lagoon/sunny_day_phase3.png',
    ),
    WeatherInfo(
      id: 'rainy',
      label: 'Rainy',
      bgImage: 'assets/images/objects/lagoon/rainy_day_phase2.png',
    ),
    WeatherInfo(
      id: 'cloudy',
      label: 'Cloudy',
      bgImage: 'assets/images/objects/lagoon/cloudy_day_phase3.png',
    ),
    WeatherInfo(
      id: 'windy',
      label: 'Windy',
      bgImage: 'assets/images/objects/lagoon/windy_day_phase2.png',
    ),
  ];

  static final List<ClothingItem> allItems = [
    // Sunny
    ClothingItem(
      id: 'top',
      imagePath: 'assets/images/objects/lagoon/sunny_top.png',
      targetWeatherId: 'sunny',
    ),
    ClothingItem(
      id: 'bottom',
      imagePath: 'assets/images/objects/lagoon/sunny_bottom.png',
      targetWeatherId: 'sunny',
    ),

    // Rainy
    ClothingItem(
      id: 'coat',
      imagePath: 'assets/images/objects/lagoon/rainy_coat.png',
      targetWeatherId: 'rainy',
    ),
    ClothingItem(
      id: 'umbrella_boots',
      imagePath: 'assets/images/objects/lagoon/rainy_umbrella_boots.png',
      targetWeatherId: 'rainy',
    ),

    // Cloudy
    ClothingItem(
      id: 'jacket',
      imagePath: 'assets/images/objects/lagoon/cloudy_jacket.png',
      targetWeatherId: 'cloudy',
    ),
    ClothingItem(
      id: 'pants',
      imagePath: 'assets/images/objects/lagoon/cloudy_pants.png',
      targetWeatherId: 'cloudy',
    ),

    // Windy
    ClothingItem(
      id: 'scarf',
      imagePath: 'assets/images/objects/lagoon/windy_scarf.png',
      targetWeatherId: 'windy',
    ),
    ClothingItem(
      id: 'kite',
      imagePath: 'assets/images/objects/lagoon/windy_kite.png',
      targetWeatherId: 'windy',
    ),
  ];

  /// Question line played when a weather round starts.
  static String questionKey(String weatherId) => 'dressup_q_$weatherId';

  /// Round-complete line played once both items for a weather are matched.
  static String winKey(String weatherId) => 'dressup_win_$weatherId';

  static List<Color> gradientForWeather(String id) {
    switch (id) {
      case 'sunny':
        return [const Color(0xFFFFE066), const Color(0xFF87CEEB)];
      case 'rainy':
        return [const Color(0xFF607D8B), const Color(0xFF90A4AE)];
      case 'cloudy':
        return [const Color(0xFFB0BEC5), const Color(0xFFECEFF1)];
      case 'windy':
        return [const Color(0xFF80DEEA), const Color(0xFFE0F7FA)];
      default:
        return [Colors.blue, Colors.lightBlue];
    }
  }
}

/// ---------------------------------------------------------------------------
/// ROUND STATE (pure logic, no Flutter/animation concerns)
/// ---------------------------------------------------------------------------

class WeatherRound {
  final WeatherInfo weather;
  final List<ClothingItem> roundItems;
  final Set<String> targetIds;
  final Set<String> matched = {};

  WeatherRound(
      {required this.weather, required this.roundItems, required this.targetIds});

  bool get isComplete => matched.length == targetIds.length;

  /// Returns true if [item] was the correct item for this weather.
  bool tryMatch(ClothingItem item) {
    if (matched.contains(item.id)) return true;
    if (item.targetWeatherId != weather.id) return false;
    matched.add(item.id);
    return true;
  }

  static WeatherRound generate(WeatherInfo weather, List<ClothingItem> allItems) {
    final correct = allItems.where((i) => i.targetWeatherId == weather.id).toList();
    final wrong = allItems.where((i) => i.targetWeatherId != weather.id).toList()..shuffle();

    final roundItems = [...correct, ...wrong.take(4 - correct.length)]..shuffle();
    final targetIds = correct.map((i) => i.id).toSet();

    return WeatherRound(weather: weather, roundItems: roundItems, targetIds: targetIds);
  }
}

/// ---------------------------------------------------------------------------
/// SCREEN
/// ---------------------------------------------------------------------------

class WeatherDressUpScreen extends StatefulWidget {
  final int level;
  const WeatherDressUpScreen({super.key, required this.level});

  @override
  State<WeatherDressUpScreen> createState() => _WeatherDressUpScreenState();
}

class _WeatherDressUpScreenState extends State<WeatherDressUpScreen>
    with TickerProviderStateMixin, LagoonIntroMixin {
  // ── Intro phase ────────────────────────────────────────────────────────

  final AudioPlayer _introPlayer = AudioPlayer();

  @override
  AudioPlayer get introAudioPlayer => _introPlayer;

  LagoonScreenPhase _screenPhase = LagoonScreenPhase.intro;

  // ── Game state ───────────────────────────────────────────────────────────

  late List<WeatherInfo> _weatherOrder;
  late WeatherRound _round;
  int _roundIndex = 0;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _floatCtrl;

  String? _lastWrongId;
  bool _roundLocked = false; // prevents double-drops while win audio plays

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

    _weatherOrder = List.of(WeatherDressUpData.weathers)..shuffle();
    _round = WeatherRound.generate(_weatherOrder[0], WeatherDressUpData.allItems);

    initLagoonIntro();
    startLagoonIntro(
      introAudioAsset: 'assets/audio/discovery_lagoon/dressup_intro.wav',
      onGameStart: () {
        if (!mounted) return;
        setState(() => _screenPhase = LagoonScreenPhase.game);
        LagoonAudio.instance.play(WeatherDressUpData.questionKey(_round.weather.id));
      },
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _bounceCtrl.dispose();
    _floatCtrl.dispose();
    disposeLagoonIntro();
    _introPlayer.dispose();
    super.dispose();
  }

  Future<void> _onDrop(ClothingItem item) async {
    if (_roundLocked || _round.matched.contains(item.id)) return;

    final wasCorrect = _round.tryMatch(item);

    if (wasCorrect) {
      setState(() {});
      _bounceCtrl.forward(from: 0);

      if (_round.isComplete) {
        _roundLocked = true;

        LagoonAudio.instance.playThenCallback('dressup_${item.id}', () async {
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;

          if (_roundIndex >= _weatherOrder.length - 1) {
            _showSuccessDialog();
          } else {
            setState(() {
              _roundIndex++;
              _round = WeatherRound.generate(
                _weatherOrder[_roundIndex],
                WeatherDressUpData.allItems,
              );
              _roundLocked = false;
            });
            LagoonAudio.instance.play(WeatherDressUpData.questionKey(_round.weather.id));
          }
        });
      } else {
        LagoonAudio.instance.play('dressup_${item.id}');
      }
    } else {
      setState(() => _lastWrongId = item.id);
      _shakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _lastWrongId = null);
    }
  }

  void _showSuccessDialog() {
    LagoonAudio.instance.playThenCallback('dressup_outro', () {
      if (!mounted) return;
      LagoonProgressService.instance.markLevelComplete(widget.level);
      showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        barrierColor: Colors.black54,
        builder: (_) => GoodJobOverlay(
          characterImage: 'assets/images/characters/cat_holding_fishbone.png',
          closeButtonColor: LagoonColorTheme.darkbrown,
          onNext: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const WeatherTapSortScreen(level: 19),
              ),
            );
          },
          onRestart: () {
            Navigator.pop(context);
            setState(() {
              _roundIndex = 0;
              _round = WeatherRound.generate(
                _weatherOrder[_roundIndex],
                WeatherDressUpData.allItems,
              );
              _roundLocked = false;
            });
            LagoonAudio.instance.play(WeatherDressUpData.questionKey(_round.weather.id));
          },
          onBack: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LagoonLevelScreen()),
                  (route) => route.isFirst,
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _Background(
            weather: _screenPhase == LagoonScreenPhase.intro
                ? _weatherOrder[0]
                : _round.weather,
          ),
          SafeArea(
            child: _screenPhase == LagoonScreenPhase.intro
                ? _buildIntroContent()
                : _buildGameContent(),
          ),
        ],
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
        _Header(weather: _round.weather),
        Expanded(
          flex: 6,
          child: _DropZone(
            weatherId: _round.weather.id,
            matchedIds: _round.matched,
            bounceAnim: _bounceAnim,
            onAccept: _onDrop,
          ),
        ),
        Expanded(
          flex: 3,
          child: _ClothingTray(
            items: _round.roundItems,
            matchedIds: _round.matched,
            wrongId: _lastWrongId,
            shakeAnim: _shakeAnim,
            floatCtrl: _floatCtrl,
          ),
        ),
        _ProgressDots(total: _weatherOrder.length, currentIndex: _roundIndex),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// SUB-WIDGETS
/// ---------------------------------------------------------------------------

class _Background extends StatelessWidget {
  final WeatherInfo weather;
  const _Background({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset(
        weather.bgImage,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: WeatherDressUpData.gradientForWeather(weather.id),
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final WeatherInfo weather;
  const _Header({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                weather.label,
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
    );
  }
}

/// The drop target showing the character. Swaps to the full-body combo PNG
/// matching whatever has been matched so far (see CharacterImageResolver).
class _DropZone extends StatelessWidget {
  final String weatherId;
  final Set<String> matchedIds;
  final Animation<double> bounceAnim;
  final void Function(ClothingItem) onAccept;

  const _DropZone({
    required this.weatherId,
    required this.matchedIds,
    required this.bounceAnim,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final characterPath = CharacterImageResolver.resolve(weatherId, matchedIds);

      return DragTarget<ClothingItem>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidates, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Character swaps fully (not layered) as items are matched.
                ScaleTransition(
                  scale: bounceAnim,
                  child: Image.asset(
                    characterPath,
                    key: ValueKey(characterPath), // forces rebuild/animation on swap
                    height: constraints.maxHeight * 0.75,
                    errorBuilder: (_, __, ___) => Text(
                      '🧒',
                      style: TextStyle(fontSize: constraints.maxHeight * 0.4),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

class _ClothingTray extends StatelessWidget {
  final List<ClothingItem> items;
  final Set<String> matchedIds;
  final String? wrongId;
  final Animation<double> shakeAnim;
  final AnimationController floatCtrl;

  const _ClothingTray({
    required this.items,
    required this.matchedIds,
    required this.wrongId,
    required this.shakeAnim,
    required this.floatCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((item) {
          final isMatched = matchedIds.contains(item.id);
          final isWrong = wrongId == item.id;

          Widget child = AnimatedOpacity(
            opacity: isMatched ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: AnimatedBuilder(
              animation: floatCtrl,
              builder: (_, c) => Transform.translate(
                offset: Offset(0, -6 * floatCtrl.value),
                child: c,
              ),
              child: Image.asset(
                item.imagePath,
                height: 70,
                errorBuilder: (_, __, ___) => const Text('👕', style: TextStyle(fontSize: 40)),
              ),
            ),
          );

          if (isWrong) {
            child = AnimatedBuilder(
              animation: shakeAnim,
              builder: (_, c) => Transform.translate(
                offset: Offset(sin(shakeAnim.value * pi * 5) * 8, 0),
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
                child: Image.asset(
                  item.imagePath,
                  height: 70,
                  errorBuilder: (_, __, ___) => const Text('👕', style: TextStyle(fontSize: 40)),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.2, child: child),
            child: child,
          );
        }).toList(),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int total;
  final int currentIndex;

  const _ProgressDots({required this.total, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: i == currentIndex ? 28 : 12,
            height: 12,
            decoration: BoxDecoration(
              color: i < currentIndex
                  ? LagoonColorTheme.darkbrown
                  : i == currentIndex
                  ? LagoonColorTheme.ferngreen
                  : LagoonColorTheme.darkbrown.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
    );
  }
}