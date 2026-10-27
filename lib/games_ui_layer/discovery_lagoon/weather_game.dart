import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/lagoon_database_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/goodjob_prompt.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/clothes_game.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'kiki_reaction.dart';
import 'lagoon_game_ui.dart';

class WeatherGame extends StatefulWidget {
  final int level;

  const WeatherGame({super.key, required this.level});

  @override
  State<WeatherGame> createState() => _WeatherGameState();
}

class _WeatherGameState extends State<WeatherGame>
    with AiCameraMixin, KikiReactionMixin, AppAudioLifecycleMixin<WeatherGame>, IdleHintMixin  {

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _kikiPlayer = AudioPlayer();

  final GameTapTracker _tapTracker = GameTapTracker();

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _kikiPlayer];

  int currentLevelIndex = 0;

  bool _isGameComplete = false;
  bool _isPromptPlaying = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  final List<Map<String, String>> levelSequence = [
    {'bg': 'assets/images/backgrounds/bg_park_sunny.png', 'target': 'sunny'},
    {'bg': 'assets/images/backgrounds/bg_lake_rainy.png', 'target': 'rainy'},
    {'bg': 'assets/images/backgrounds/bg_beach_sunny.png', 'target': 'sunny'},
    {'bg': 'assets/images/backgrounds/bg_school_cloudy.png', 'target': 'cloudy',},
    {'bg': 'assets/images/backgrounds/bg_fields_windy.png', 'target': 'windy'},
    {'bg': 'assets/images/backgrounds/bg_town_rainy.png', 'target': 'rainy'},
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted && _isPromptPlaying) {
        setState(() {
          _isPromptPlaying = false;
        });
      }
    });

    _playIntroPrompt();
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _audioPlayer.dispose();
    _kikiPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _playIntroPrompt() async {
    cancelIdleTimer();
    setState(() {
      _isPromptPlaying = true;
    });

    await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/discovery_lagoon/weather_game_intro.wav');
    if (!mounted) return;
    showHowToPlay = false;
    startIdleTimer();
  }

  Future<void> _playCorrectWeatherAudio(String weather) async {
    final Map<String, String> correctAudio = {
      'sunny': 'assets/audio/discovery_lagoon/weather_correct_sunny.wav',
      'rainy': 'assets/audio/discovery_lagoon/weather_correct_rainy.wav',
      'windy': 'assets/audio/discovery_lagoon/weather_correct_windy.wav',
      'cloudy': 'assets/audio/discovery_lagoon/weather_correct_cloudy.wav',
    };

    final asset = correctAudio[weather];
    if (asset == null) return;

    try {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, asset);
    } catch (e) {
      debugPrint('Correct weather audio error ($weather): $e');
    }
  }

  Future<void> handleAnswer(String selectedWeather) async {
    if (kikiState != KikiState.normal || _isGameComplete || _isPromptPlaying) {
      return;
    }

    final String currentTarget = levelSequence[currentLevelIndex]['target']!;

    if (selectedWeather == currentTarget) {
      _tapTracker.recordCorrectTap();

      setState(() {
        _isPromptPlaying = true;
      });

      showKikiReaction(KikiState.correct);

      await _playCorrectWeatherAudio(currentTarget);

      if (!mounted) return;

      setState(() {
        _isPromptPlaying = false;

        if (currentLevelIndex < levelSequence.length - 1) {
          currentLevelIndex++;
        } else {
          _saveDataAndShowGoodJob();
        }
      });
      if (!_isGameComplete) {   
        showHowToPlay = false;  
        startIdleTimer();       
      }
    } else {
      _tapTracker.recordMistake();

      setState(() {
        _isPromptPlaying = true;
      });

      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showKikiReaction(KikiState.wrong);

      setState(() {
        _isPromptPlaying = false;
      });
      startIdleTimer();
    }
  }

  Future<void> _saveDataAndShowGoodJob() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;
    List<String> finalEmotions = stopAiCamera();

    LagoonDatabaseService.saveGameData(
      gameId: 'lagoon_weather_game',
      activityName: 'Weather Game',
      emotions: finalEmotions,
      totalTaps: _tapTracker.totalTaps,
      mistakes: _tapTracker.mistakeCount,
      timePlayedSeconds: _tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });
    LagoonProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
    });
    if (mounted) {
      setState(() {
        _isGameComplete = true;
      });
    }
  }

  @override
  Widget buildKiki(BuildContext context, {double heightFactor = 0.50}) {
    return Positioned(
      right: 0,
      bottom: -30,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * heightFactor,
        child: switch (kikiState) {
          KikiState.correct => Image.asset(
            'assets/animations/characters/kiki_cheering.webp',
            fit: BoxFit.contain,
          ),
          KikiState.wrong => Image.asset(
            'assets/images/characters/kiki_tryagain.png',
            fit: BoxFit.contain,
          ),
          KikiState.normal => Image.asset(
            'assets/images/characters/kiki_standing.png',
            fit: BoxFit.contain,
          ),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double buttonSize = screenSize.width * 0.12;

    return Listener(
        onPointerDown: (_) {
          if (!_isPromptPlaying && !_isGameComplete) resetIdleTimer();
        },
        child:  Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              levelSequence[currentLevelIndex]['bg']!,
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(
            top: 25,
            right: 25,
            child: LagoonLevelBadge(level: widget.level),
          ),

          Positioned(
            bottom: screenSize.height * 0.08,
            left: screenSize.width * 0.05,
            child: Row(
              children: [
                _buildWeatherButton(
                  'rainy',
                  'assets/images/objects/lagoon/raincloud.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'sunny',
                  'assets/images/objects/lagoon/sun.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'windy',
                  'assets/images/objects/lagoon/windy.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
                SizedBox(width: screenSize.width * 0.02),
                _buildWeatherButton(
                  'cloudy',
                  'assets/images/objects/lagoon/cloudy.png',
                  const Color(0xFF2C4463),
                  buttonSize,
                ),
              ],
            ),
          ),

          buildKiki(context, heightFactor: 0.9),

          if (showHowToPlay &&
              !_isPromptPlaying &&
              !_isGameComplete &&
              kikiState == KikiState.normal)
            Positioned.fill(child: _buildHowToPlayOverlay(screenSize, buttonSize)),

          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            LightingPromptCard(
              onClose: () {
                setState(() => _hideLightingCard = true);
                releaseFaceGate();
              },
            ),

          if (_isGameComplete)
            Positioned.fill(
              child: GoodJobOverlay(
                characterImage:
                    'assets/images/characters/cat_holding_fishbone.png',
                characterSizeFactor: 0.9,
                onNext: () {
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClothesGame(level: widget.level + 1),
                      ),
                    );
                  }
                },
                onRestart: () {
                  setState(() {
                    currentLevelIndex = 0;
                    _isGameComplete = false;
                    kikiState = KikiState.normal;
                    _hasSavedResult = false;
                    _tapTracker.startSession();
                  });

                  _playIntroPrompt();
                },
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
        ),
    );
  }

  Widget _buildHowToPlayOverlay(Size sz, double btn) {
    final sw = sz.width, sh = sz.height;
    const order = ['rainy', 'sunny', 'windy', 'cloudy'];
    const icons = {
      'rainy': 'assets/images/objects/lagoon/raincloud.png',
      'sunny': 'assets/images/objects/lagoon/sun.png',
      'windy': 'assets/images/objects/lagoon/windy.png',
      'cloudy': 'assets/images/objects/lagoon/cloudy.png',
    };
    const sampleBg = 'assets/images/backgrounds/bg_park_sunny.png';
    const sampleIndex = 1;

    final gap = sw * 0.02;
    final left = sw * 0.05;
    final bottom = sh * 0.08;

    final preview = Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(sampleBg, fit: BoxFit.cover),
        Positioned(
          right: 0,
          bottom: -30,
          child: SizedBox(
            height: sh * 0.9,
            child: Image.asset('assets/images/characters/kiki_standing.png', fit: BoxFit.contain),
          ),
        ),
        Positioned(
          bottom: bottom,
          left: left,
          child: Row(
            children: [
              for (int i = 0; i < order.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Container(
                  width: btn,
                  height: btn,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(btn * 0.15),
                    border: Border.all(color: const Color(0xFF2C4463), width: btn * 0.04),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(btn * 0.15),
                    child: Image.asset(icons[order[i]]!, fit: BoxFit.contain),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final cx = left + sampleIndex * (btn + gap) + btn / 2;
    final cy = sh - bottom - btn / 2;

    return HowToPlayOverlay(
      previewChild: preview,
      handAlignment: Alignment(2 * cx / sw - 1, 2 * cy / sh - 1),
      handOffset: const Offset(0.15, 0.55),
      onDismiss: resetIdleTimer,
    );
  }

  Widget _buildWeatherButton(
    String weatherType,
    String imagePath,
    Color borderColor,
    double size, {
    bool isHighlighted = false,
  }) {
    return GestureDetector(
      onTap: () => handleAnswer(weatherType),
      child: Opacity(
        opacity: _isPromptPlaying ? 0.5 : 1.0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.15),
            border: Border.all(
              color: isHighlighted ? Colors.orange : borderColor,
              width: size * 0.04,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.15),
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
