import 'dart:async';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_level.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'audio_helper.dart';
import 'intro_phase.dart';

class WeatherElement {
  final String id;
  final String imagePath;
  final String weatherId;
  final Alignment scenePosition;
  WeatherElement({
    required this.id,
    required this.imagePath,
    required this.weatherId,
    required this.scenePosition,
  });
}

class WeatherSceneBuilderScreen extends StatefulWidget {
  final int level;
  const WeatherSceneBuilderScreen({super.key, required this.level});

  @override
  State<WeatherSceneBuilderScreen> createState() =>
      _WeatherSceneBuilderScreenState();
}

class _WeatherSceneBuilderScreenState extends State<WeatherSceneBuilderScreen>
    with TickerProviderStateMixin, LagoonIntroMixin {

  // ── Intro phase ──────────────────────────────────────────────────────────

  final AudioPlayer _introPlayer = AudioPlayer();

  @override
  AudioPlayer get introAudioPlayer => _introPlayer;

  LagoonScreenPhase _screenPhase = LagoonScreenPhase.intro;

  // ── Data ─────────────────────────────────────────────────────────────────

  final List<Map<String, String>> _weathers = [
    {'id': 'sunny',  'label': 'Build a Sunny Day!',   'qKey': 'weather_q_sunny',  'winKey': 'weather_win_sunny'},
    {'id': 'rainy',  'label': 'Build a Rainy Day!',   'qKey': 'weather_q_rainy',  'winKey': 'weather_win_rainy'},
    {'id': 'cloudy', 'label': 'Build a Cloudy Day!',  'qKey': 'weather_q_cloudy', 'winKey': 'weather_win_cloudy'},
    {'id': 'windy',  'label': 'Build a Windy Day!',   'qKey': 'weather_q_windy',  'winKey': 'weather_win_windy'},
  ];

  final List<WeatherElement> _allElements = [
    WeatherElement(id: 'sun',         imagePath: 'assets/images/objects/lagoon/sun.png',         weatherId: 'sunny',  scenePosition: const Alignment(0.6, -0.8)),
    WeatherElement(id: 'rainbow',     imagePath: 'assets/images/objects/lagoon/rainbow.png',     weatherId: 'sunny',  scenePosition: const Alignment(-0.2, -0.5)),
    WeatherElement(id: 'raincloud',   imagePath: 'assets/images/objects/lagoon/raincloud.png',   weatherId: 'rainy',  scenePosition: const Alignment(0.0, -0.9)),
    WeatherElement(id: 'raindrop',    imagePath: 'assets/images/objects/lagoon/raindrop.png',    weatherId: 'rainy',  scenePosition: const Alignment(-0.5, 0.0)),
    WeatherElement(id: 'suncloud',    imagePath: 'assets/images/objects/lagoon/suncloud.png',    weatherId: 'cloudy', scenePosition: const Alignment(0.3, -0.7)),
    WeatherElement(id: 'graycloud',   imagePath: 'assets/images/objects/lagoon/graycloud.png',   weatherId: 'cloudy', scenePosition: const Alignment(-0.4, -0.5)),
    WeatherElement(id: 'windy',       imagePath: 'assets/images/objects/lagoon/windy.png',       weatherId: 'windy',  scenePosition: const Alignment(0.0, -0.2)),
    WeatherElement(id: 'strong_wind', imagePath: 'assets/images/objects/lagoon/strong_wind.png', weatherId: 'windy',  scenePosition: const Alignment(0.5, 0.1)),
  ];

  int _roundIndex = 0;
  late Map<String, String> _currentWeather;
  late List<WeatherElement> _currentElements;
  late List<WeatherElement> _choices;
  final Set<String> _placed = {};
  bool _roundLocked = false; // prevent double-taps during transition

  late AnimationController _popCtrl;
  late Map<String, AnimationController> _itemCtrls;
  late List<String> _currentPhases;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _itemCtrls = {};

    _startRound(playPrompt: false);

    initLagoonIntro();
    startLagoonIntro(
      introAudioAsset:
      'assets/audio/discovery_lagoon/weather_builder_intro.wav',
      onGameStart: () {
        if (!mounted) return;
        setState(() => _screenPhase = LagoonScreenPhase.game);
        LagoonAudio.instance.play(_currentWeather['qKey']!);
      },
    );
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    for (final c in _itemCtrls.values) {
      c.dispose();
    }
    disposeLagoonIntro();
    _introPlayer.dispose();
    super.dispose();
  }

  // ── Round logic ───────────────────────────────────────────────────────────

  void _startRound({bool playPrompt = true}) {
    _currentWeather = _weathers[_roundIndex];
    _currentElements =
        _allElements.where((e) => e.weatherId == _currentWeather['id']).toList();
    _currentPhases = _weatherPhases[_currentWeather['id']] ?? [];

    final decoys = _allElements
        .where((e) => e.weatherId != _currentWeather['id'])
        .toList()
      ..shuffle();
    _choices = [..._currentElements, ...decoys.take(2)]..shuffle();
    _placed.clear();
    _roundLocked = false;

    for (final e in _choices) {
      _itemCtrls[e.id]?.dispose();
      _itemCtrls[e.id] = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
    }

    if (playPrompt) {
      LagoonAudio.instance.play(_currentWeather['qKey']!);
    }
  }

  Future<void> _onTap(WeatherElement el) async {
    if (_roundLocked || _placed.contains(el.id)) return;

    if (el.weatherId == _currentWeather['id']) {
      setState(() => _placed.add(el.id));
      _itemCtrls[el.id]?.forward(from: 0);

      if (_placed.length == _currentElements.length) {
        _roundLocked = true;
        // Play round-complete audio, then advance
        LagoonAudio.instance.playThenCallback(
          _currentWeather['winKey']!,
              () {
            if (!mounted) return;
            if (_roundIndex >= _weathers.length - 1) {
              _showSuccessDialog();
            } else {
              setState(() {
                _roundIndex++;
                _startRound();
              });
            }
          },
        );
      }
    } else {
      // Wrong tap — brief red flash via controller forward/reverse
      _itemCtrls[el.id]?.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _itemCtrls[el.id]?.reverse();
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
          setState(() {
            _roundIndex = 0;
            _startRound();
          });
        },
        onBack: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LagoonLevelScreen()),
                (route) => route.isFirst,
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _screenPhase == LagoonScreenPhase.intro
                ? Image.asset(
              'assets/images/backgrounds/bg_game_lagoon.png',
              fit: BoxFit.cover,
            )
                : AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: Image.asset(
                _currentPhases.isEmpty
                    ? 'assets/images/objects/lagoon/summer.png'
                    : _currentPhases[
                _placed.length.clamp(0, _currentPhases.length - 1)],
                key: ValueKey('${_currentWeather['id']}_${_placed.length}'),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
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
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: SizedBox(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: LagoonBackButton()),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: LagoonColorTheme.pastelorange,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: LagoonColorTheme.wasteland, width: 5),
                  ),
                  child: Text(
                    _currentWeather['label']!,
                    style: TextStyle(
                      fontFamily: LagoonAppTextStyles.fredoka,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: LagoonColorTheme.darkbrown,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Choice buttons
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _choices.map((el) {
              final isPlaced = _placed.contains(el.id);
              return GestureDetector(
                onTap: () => _onTap(el),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isPlaced ? 0.3 : 1.0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      el.imagePath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Progress dots
        Container(
          padding: const EdgeInsets.only(bottom: 10),
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
                      : LagoonColorTheme.darkbrown
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Phase images ──────────────────────────────────────────────────────────

  final Map<String, List<String>> _weatherPhases = {
    'sunny': [
      'assets/images/objects/lagoon/sunny_day_phase1.png',
      'assets/images/objects/lagoon/sunny_day_phase2.png',
      'assets/images/objects/lagoon/sunny_day_phase3.png',
    ],
    'rainy': [
      'assets/images/objects/lagoon/rainy_day_phase1.png',
      'assets/images/objects/lagoon/rainy_day_phase2.png',
      'assets/images/objects/lagoon/rainy_day_phase3.png',
    ],
    'cloudy': [
      'assets/images/objects/lagoon/cloudy_day_phase1.png',
      'assets/images/objects/lagoon/cloudy_day_phase2.png',
      'assets/images/objects/lagoon/cloudy_day_phase3.png',
    ],
    'windy': [
      'assets/images/objects/lagoon/windy_day_phase1.png',
      'assets/images/objects/lagoon/windy_day_phase2.png',
      'assets/images/objects/lagoon/windy_day_phase3.png',
    ],
  };
}