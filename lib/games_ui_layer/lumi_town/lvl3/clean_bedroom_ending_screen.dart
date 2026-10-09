import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/business_layer/town_progress_service.dart';
import 'package:StarSight/business_layer/town_database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../business_layer/orientation_service.dart';
import '../../../../ui_layer/lumi_town/town_level.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../games_audio_helper.dart';
import '../../goodjob_prompt.dart';
import '../lumi_game_ui_layer.dart';
import '../lvl4_cooking/game_screen.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'clean_bedroom_audio_helper.dart';
import 'clean_bedroom_game_screen.dart';

class CleanBedroomEndingScreen extends StatefulWidget {
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const CleanBedroomEndingScreen({
    super.key,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<CleanBedroomEndingScreen> createState() =>
      _CleanBedroomEndingScreenState();
}

class _CleanBedroomEndingScreenState extends State<CleanBedroomEndingScreen>
    with
        SingleTickerProviderStateMixin,
        AiCameraMixin<CleanBedroomEndingScreen>,
        AppAudioLifecycleMixin<CleanBedroomEndingScreen> {
  final AudioPlayer _player = AudioPlayer();

  bool _showOverlay = false;
  bool _hideLightingCard = false;
  bool _hasSavedResult = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  List<AudioPlayer> get lifecyclePlayers => [_player];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _playEndingThenShow();
  }

  Future<void> _playEndingThenShow() async {
    await playAssetAudio(
      _player,
      'assets/audio/lumi_town/level3/vo_ending.wav',
    );
    await waitForAudio(_player);
    if (!mounted) return;

    await _saveDataAndMarkComplete();
    if (!mounted) return;

    setState(() => _showOverlay = true);
  }

  @override
  void dispose() {
    disposeAiCamera();
    _player.dispose();
    _fadeCtrl.dispose();
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
      gameId: 'lumi_town_bedroom',
      activityName: 'Clean Bedroom',
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
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/backgrounds/bg_lumi_bed.png',
                fit: BoxFit.cover,
              ),

              Positioned(top: 25, left: 25, child: LumiXButton()),
              Positioned(
                top: 25,
                right: 25,
                child: LumiLevelBadge(level: widget.level),
              ),

              if (_showOverlay)
                GoodJobOverlay(
                  characterImage: 'assets/images/characters/tr.woo_the_owl.png',
                  onNext: _onNext,
                  onRestart: _onRestart,
                  onBack: _onBack,
                ),

              if (hasCapturedFirstFrame &&
                  !isFaceDetected &&
                  !_hideLightingCard)
                LightingPromptCard(
                  onClose: () {
                    setState(() => _hideLightingCard = true);
                    releaseFaceGate();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onNext() async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => CookingGameScreen(level: widget.level + 1),
      ),
      (route) => route.isFirst,
    );
  }

  void _onRestart() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CleanBedroomGameScreen(level: widget.level),
      ),
    );
  }

  Future<void> _onBack() async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LumiLevelScreen()),
      (route) => route.isFirst,
    );
  }
}
