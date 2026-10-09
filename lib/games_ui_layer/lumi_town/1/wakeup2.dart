import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/business_layer/town_database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/games_ui_layer/lumi_town/1/wakeup1.dart';
import 'package:StarSight/ui_layer/lumi_town/town_level.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../games_audio_helper.dart';
import '../../goodjob_prompt.dart';
import '../lumi_game_ui_layer.dart';
import '../lvl2/bathroom_game_screen.dart';

class Lumi2ValuesWakingup extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const Lumi2ValuesWakingup({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<Lumi2ValuesWakingup> createState() => _Lumi2ValuesWakingupState();
}

class _Lumi2ValuesWakingupState extends State<Lumi2ValuesWakingup>
    with
        AiCameraMixin<Lumi2ValuesWakingup>,
        AppAudioLifecycleMixin<Lumi2ValuesWakingup> {
  bool _showNext = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showGoodJob = false;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  static const String _salamatAudio = 'assets/audio/lumi_town/level1/salamat.wav';

  static const String _bgImage = 'assets/images/backgrounds/bg_lumi_bed.png';
  static const String _trWooImage = 'assets/images/characters/tr.woo_the_owl.png';
  static const String _littleBearImage = 'assets/images/characters/little_bear.png';

  @override
  void initState() {
    super.initState();
    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _playAlarm();
    Future.delayed(const Duration(seconds: 9), () async {
      if (mounted) {
        await _audioPlayer.stop();
        setState(() => _showNext = true);
        await _playNext();
      }
    });
  }

  Future<void> _playAlarm() => GamesSfxPlayer.instance.play(GameSfx.alarmClock);

  Future<void> _playNext() async {
    try {
      await playAssetAudio(
        _audioPlayer,
        _salamatAudio,
      );
      await waitForAudio(_audioPlayer);
    } catch (e) {
      debugPrint('[Audio] Error: $e');
    }
    if (!mounted) return;

    await _saveDataAndMarkComplete();
    if (!mounted) return;

    setState(() => _showGoodJob = true);
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveDataAndMarkComplete() async {
    if (_hasSavedResult) return;
    _hasSavedResult = true;

    final List<String> finalEmotions = [
      ...widget.priorEmotions,
      ...stopAiCamera(),
    ];

    TownDatabaseService.saveGameData(
      gameId: 'lumi_town_wakeup',
      activityName: 'Wake Up',
      emotions: finalEmotions,
      totalTaps: widget.tapTracker.totalTaps,
      mistakes: widget.tapTracker.mistakeCount,
      timePlayedSeconds: widget.tapTracker.formattedDuration,
    ).catchError((e) {
      debugPrint("Database Error saving metrics: $e");
    });

    TownProgressService.instance.markLevelComplete(widget.level).catchError((
      e,
    ) {
      debugPrint("Database Error marking level complete: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: _showNext ? _buildNext() : _buildAwake(),
            ),

            Positioned(top: 25, left: 25, child: LumiXButton()),
            Positioned(
              top: 25,
              right: 25,
              child: LumiLevelBadge(level: widget.level),
            ),

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_showGoodJob)
              GoodJobOverlay(
                characterImage: _trWooImage,
                onNext: () async {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          Lvl2BathroomGameScreen(level: widget.level + 1),
                    ),
                  );
                },
                onRestart: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => Lumi1ValuesWakeup(level: widget.level),
                    ),
                  );
                },
                onBack: () async {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
                    (route) => route.isFirst,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAwake() {
    return SizedBox.expand(
      key: const ValueKey('awake'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/animations/awake.webp',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildNext() {
    return SizedBox.expand(
      key: const ValueKey('next'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _bgImage,
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: const Offset(0, 80),
              child: Image.asset(
                _littleBearImage,
                width: 300,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
