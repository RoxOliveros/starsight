import 'dart:io';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/business_layer/town_database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:StarSight/games_ui_layer/lumi_town/1/wakeup1.dart';
import 'package:StarSight/ui_layer/lumi_town/town_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../../ui_layer/lumi_town/lumi_theme.dart';
import '../../goodjob_prompt.dart';
import '../lvl2/bathroom_game_screen.dart';

class Lumi2ValuesWakingup extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;

  const Lumi2ValuesWakingup({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
  });

  @override
  State<Lumi2ValuesWakingup> createState() => _Lumi2ValuesWakingupState();
}

class _Lumi2ValuesWakingupState extends State<Lumi2ValuesWakingup>
    with AiCameraMixin<Lumi2ValuesWakingup> {
  bool _showNext = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showGoodJob = false;

  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

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

  Future<void> _playAudio(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final Directory cacheDir = await getTemporaryDirectory();
      final String fileName = assetPath.split('/').last;
      final File tempFile = File('${cacheDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes, flush: true);
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
    } catch (e) {
      debugPrint('[Audio] Error: $e');
    }
  }

  Future<void> _playAlarm() =>
      _playAudio('assets/audio/sound_effects/alarmclock.wav');

  Future<void> _playNext() async {
    await _playAudio('assets/audio/lumi_town/level1/salamat.wav');
    await _audioPlayer.onPlayerComplete.first;
    if (mounted) setState(() => _showGoodJob = true);
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

    TownProgressService.instance.markLevelComplete(1).catchError((e) {
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

            if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
              LightingPromptCard(
                onClose: () {
                  setState(() => _hideLightingCard = true);
                  releaseFaceGate();
                },
              ),

            if (_showGoodJob)
              GoodJobOverlay(
                characterImage: 'assets/images/characters/tr.woo_the_owl.png',

                onNext: () async {
                  await _saveDataAndMarkComplete();

                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const Lvl2BathroomGameScreen(),
                      ),
                    );
                  }
                },
                onRestart: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const Lumi1ValuesWakeup(),
                    ),
                  );
                },
                onBack: () async {
                  // Unlock level 2 even after they tap the back btn
                  await _saveDataAndMarkComplete();

                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const LumiLevelScreen(),
                      ),
                      (route) => route.isFirst,
                    );
                  }
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

          //X button
          Positioned(top: 25, left: 25, child: LumiXButton()),
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
            'assets/images/backgrounds/bg_lumi_bed.png',
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: const Offset(0, 80),
              child: Image.asset(
                'assets/images/characters/little_bear.png',
                width: 300,
                fit: BoxFit.contain,
              ),
            ),
          ),
          //X button
          Positioned(top: 25, left: 25, child: LumiXButton()),
        ],
      ),
    );
  }
}