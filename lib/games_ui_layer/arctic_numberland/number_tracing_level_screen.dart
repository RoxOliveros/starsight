import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/arctic_database_service.dart';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'arctic_flow.dart';
import 'goodjob_doma_prompt.dart';
import 'number_introduction_screen.dart' show kNumberLevels, NumberLevelConfig;
import 'number_tracing_widget.dart';

class NumberTracingLevelScreen extends StatefulWidget {
  final List<int> numbers;
  final int level;

  const NumberTracingLevelScreen({
    super.key,
    required this.numbers,
    required this.level,
  });

  @override
  State<NumberTracingLevelScreen> createState() =>
      _NumberTracingLevelScreenState();
}

class _NumberTracingLevelScreenState extends State<NumberTracingLevelScreen>
    with
        AiCameraMixin<NumberTracingLevelScreen>,
        AppAudioLifecycleMixin<NumberTracingLevelScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  final GameTapTracker _tapTracker = GameTapTracker();

  int _index = 0;
  bool _enabled = false;
  bool _showWin = false;
  bool _hasSaved = false;
  bool _hideLightingCard = false;

  NumberLevelConfig get _config => kNumberLevels[widget.numbers[_index]]!;

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _startNumber());
  }

  Future<void> _startNumber() async {
    setState(() => _enabled = false);
    try {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, _config.writeAudio);
    } catch (e) {
      debugPrint('Write audio error: $e');
    }
    if (!mounted) return;
    setState(() => _enabled = true);
  }

  void _onTraced() {
    if (_index + 1 < widget.numbers.length) {
      setState(() => _index++);
      _startNumber();
      return;
    }
    _finish();
  }

  void _finish() {
    if (_hasSaved) return;
    _hasSaved = true;
    final emotions = stopAiCamera();

    ArcticDatabaseService.saveGameData(
      gameId: 'arctic_tracing_${widget.level}',
      mistakes: _tapTracker.mistakeCount,
      emotions: emotions,
    ).catchError((e) {
      debugPrint('Database Error saving metrics: $e');
    });

    ArcticProgressService.instance.markLevelComplete(widget.level).catchError((
        e,
        ) {
      debugPrint('Database Error marking level complete: $e');
    });

    if (!mounted) return;
    setState(() => _showWin = true);
  }

  @override
  void dispose() {
    disposeAiCamera();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = 'assets/images/backgrounds/bg_game_arctic.png';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(bg, fit: BoxFit.cover)),
          Positioned.fill(
            child: NumberTracingWidget(
              number: widget.numbers[_index],
              player: _audioPlayer,
              enabled: _enabled && !_showWin,
              onComplete: _onTraced,
              level: widget.level,
              tapTracker: _tapTracker,
              hintBackground: Image.asset(bg, fit: BoxFit.cover),
            ),
          ),
          if (_showWin)
            Positioned.fill(
              child: DomaGoodJobOverlay(
                characterImage: 'assets/images/characters/doma_the_penguin.png',
                closeButtonColor: ArcticColorTheme.slateblue,
                onNext: () {
                  final next = ArcticFlow.screenAfterLevel(widget.level);
                  if (next != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => next),
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
                onRestart: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NumberTracingLevelScreen(
                        numbers: widget.numbers,
                        level: widget.level,
                      ),
                    ),
                  );
                },
                onBack: () => Navigator.pop(context),
              ),
            ),
          if (hasCapturedFirstFrame && !isFaceDetected && !_hideLightingCard)
            Positioned.fill(
              child: LightingPromptCard(
                onClose: () => setState(() => _hideLightingCard = true),
              ),
            ),
        ],
      ),
    );
  }
}