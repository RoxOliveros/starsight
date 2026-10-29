import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:StarSight/games_ui_layer/lumi_town/1/wakeup2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import '../../../business_layer/keyword_speech_listener.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/loading_screen.dart';
import '../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../lumi_game_ui_layer.dart';

class Lumi1ValuesWakeup extends StatefulWidget {
  final String imagePath;
  final String audioBinPath2;
  final bool loopAudio;
  final double volume;
  final int level;

  const Lumi1ValuesWakeup({
    super.key,
    this.imagePath = 'assets/animations/sleeping.webp',
    this.audioBinPath2 = 'assets/audio/lumi_town/level1/gising.wav',
    this.loopAudio = false,
    this.volume = 1.0,
    required this.level,
  });

  @override
  State<Lumi1ValuesWakeup> createState() => _Lumi1ValuesWakeupState();
}

class _Lumi1ValuesWakeupState extends State<Lumi1ValuesWakeup>
    with
        SingleTickerProviderStateMixin,
        AiCameraMixin<Lumi1ValuesWakeup>,
        AppAudioLifecycleMixin<Lumi1ValuesWakeup> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  static const int _gisingTarget = 3;
  static const Duration _reminderDelay = Duration(seconds: 12);
  static const String _reminderAudio = 'assets/audio/lumi_town/level1/say_gising.wav';

  final GameTapTracker _tapTracker = GameTapTracker();
  final DateTime _loadStart = DateTime.now();

  late final KeywordSpeechListener _listener;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Timer? _reminderTimer;
  String? _audioError;

  int _gisingCount = 0;

  bool _hideLightingCard = false;
  bool _inputEnabled = false;
  bool _completed = false;
  bool _reminderPlaying = false;
  bool _animationReady = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();
    _tapTracker.startSession();

    _listener = KeywordSpeechListener(
      pattern: RegExp(r'gising|gizing|giseng|giging|gisen|gisin|ising'),
      onNewMatches: _onGisingHeard,
      onSpeechActivity: _scheduleReminder,
    );

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnimation());
  }

  void _scheduleReminder() {
    _reminderTimer?.cancel();
    if (!mounted || _completed || _reminderPlaying) return;
    _reminderTimer = Timer(_reminderDelay, _playReminder);
  }

  Future<void> _playReminder() async {
    if (!mounted || _completed) return;
    _reminderPlaying = true;
    await _listener.pause();
    try {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, _reminderAudio);
    } catch (e) {
      debugPrint('[Reminder] Audio error: $e');
    }
    _reminderPlaying = false;
    if (!mounted || _completed) return;
    _listener.resume();
    _scheduleReminder();
  }

  Future<void> _initAudio() async {
    try {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, widget.audioBinPath2);
    } catch (e) {
      debugPrint('[Lumi1ValuesWakeup] Audio error: $e');
      if (mounted) setState(() => _audioError = e.toString());
    }
    if (!mounted || _completed) return;
    setState(() => _inputEnabled = true);
    if (await _listener.start() && mounted) _scheduleReminder();
  }

  void _onGisingHeard(int heard) {
    if (!mounted || _completed) return;
    final credit = heard.clamp(0, _gisingTarget - _gisingCount);
    if (credit <= 0) return;

    for (var i = 0; i < credit; i++) {
      _tapTracker.recordCorrectTap();
    }
    setState(() => _gisingCount += credit);
    _scheduleReminder();

    if (_gisingCount >= _gisingTarget) _onCompleted();
  }

  void _stopListening() {
    _reminderTimer?.cancel();
    _listener.dispose();
  }

  Future<void> _loadAnimation() async {
    if (!mounted) return;

    try {
      await precacheImage(AssetImage(widget.imagePath), context);
    } catch (e) {
      debugPrint('[Lumi1ValuesWakeup] Precache error: $e');
    }
    if (!mounted) return;

    final elapsed = DateTime.now().difference(_loadStart);
    final remaining = const Duration(milliseconds: 1500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
      if (!mounted) return;
    }

    setState(() {
      _animationReady = true;
    });
    _fadeController.forward();
    _initAudio();
  }

  void _onCompleted() {
    if (_completed) return;
    setState(() => _completed = true);
    _stopListening();
    unawaited(_audioPlayer.stop());
    Future.delayed(const Duration(milliseconds: 1500), _goToNextScreen);
  }

  void _goToNextScreen() {
    if (!mounted) return;
    final emotionsSoFar = stopAiCamera();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => Lumi2ValuesWakingup(
          priorEmotions: emotionsSoFar,
          tapTracker: _tapTracker,
          level: widget.level,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  void dispose() {
    disposeAiCamera();
    _stopListening();
    _audioPlayer.dispose();
    OrientationService.setLandscape();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _fadeController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _animationReady
          ? Listener(
              onPointerDown: (_) => _tapTracker.recordGenericTap(),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stack) =>
                          _buildImageError(),
                    ),
                    if (_audioError != null) _buildAudioErrorBadge(),
                    _buildMeter(),

                    Positioned(top: 25, left: 25, child: LumiXButton()),
                    Positioned(
                      top: 25,
                      right: 25,
                      child: LumiLevelBadge(level: widget.level),
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
            )
          : LoadingScreen.lumiTown(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildImageError() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
            SizedBox(height: 12),
            Text(
              'Image not found.\nCheck assets/animations/sleeping.json',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeter() {
    if (!_inputEnabled) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Align(
              alignment: Alignment.centerRight,
              child: LumiSkipButton(onTap: () => _onCompleted()),
            ),
          ),
          const SizedBox(height: 15),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                ),

                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  widthFactor: _gisingCount / _gisingTarget,
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

                Row(
                  children: List.generate(_gisingTarget, (i) {
                    final reached = i < _gisingCount;
                    return Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: reached
                                ? const Color(0xFFFFD700)
                                : Colors.white24,
                            border: Border.all(
                              color: reached ? Colors.orange : Colors.white38,
                              width: 2,
                            ),
                            boxShadow: reached
                                ? [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: 0.8,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: reached
                              ? const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioErrorBadge() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '⚠ Audio error: $_audioError',
          style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
