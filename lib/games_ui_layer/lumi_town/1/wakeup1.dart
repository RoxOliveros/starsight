import 'dart:async';
import 'dart:io';
import 'package:StarSight/games_ui_layer/lumi_town/1/wakeup2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart' hide LottieCache;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../business_layer/orientation_service.dart';
import '../../../ui_layer/lumi_town.dart/lumi_buttons.dart';

class Lumi1ValuesWakeup extends StatefulWidget {
  final String imagePath;
  final String audioBinPath2;
  final bool loopAudio;
  final double volume;

  const Lumi1ValuesWakeup({
    super.key,
    this.imagePath = 'assets/animations/sleeping.json',
    this.audioBinPath2 = 'assets/audio/values1/gising.mp3',
    this.loopAudio = false,
    this.volume = 1.0,
  });

  @override
  State<Lumi1ValuesWakeup> createState() => _Lumi1ValuesWakeupState();
}

class _Lumi1ValuesWakeupState extends State<Lumi1ValuesWakeup>
    with SingleTickerProviderStateMixin {
  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _completeSub;
  String? _audioError;
  bool _audioFinished = false;

  // ── Speech ─────────────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  int _gisingCount = 0;
  static const int _gisingTarget = 3;
  bool _completed = false;

  // ── Animation (subtle fade-in) ─────────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // 1. Lock to landscape.
    OrientationService.setLandscape();

    // 2. Hide system UI for a truly immersive full-screen experience.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 3. Fade-in animation.
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // 4. Prepare & play the .bin audio file.
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final Directory cacheDir = await getTemporaryDirectory();

      await _audioPlayer.setVolume(widget.volume);
      await _audioPlayer.setReleaseMode(ReleaseMode.release);

      // Load and play gising.mp3 directly
      final ByteData data = await rootBundle.load(widget.audioBinPath2);
      final Uint8List bytes = data.buffer.asUint8List();
      final String fileName = widget.audioBinPath2.split('/').last;
      final File tempFile = File('${cacheDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes, flush: true);
      await _audioPlayer.play(DeviceFileSource(tempFile.path));

      // Start listening after audio finishes
      _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
        _completeSub?.cancel();
        debugPrint('[Speech] Audio done, now listening...');
        if (mounted) setState(() => _audioFinished = true);
        _initSpeech();
      });

    } catch (e) {
      debugPrint('[Lumi1ValuesWakeup] Audio error: $e');
      if (mounted) setState(() => _audioError = e.toString());
    }
  }

  String _localeId = 'en_US'; // default fallback

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        debugPrint('[Speech] Error: $e');
        // Restart on error after a short delay
        Future.delayed(const Duration(seconds: 1), _startListening);
      },
      onStatus: (s) {
        debugPrint('[Speech] Status: $s');
        // Restart when session ends naturally
        if (s == 'done' || s == 'notListening') {
          Future.delayed(const Duration(milliseconds: 500), _startListening);
        }
      },
    );
    // Resolve locale once after init
    final locales = await _speech.locales();
    final hasFil = locales.any((l) => l.localeId == 'fil_PH');
    _localeId = hasFil ? 'fil_PH' : 'en_US';
    debugPrint('[Speech] Using locale: $_localeId');

    if (_speechAvailable) _startListening();
  }

  String _lastInterimWords = '';

  void _startListening() {
    if (!_speechAvailable || _completed) return;
    _lastInterimWords = '';
    debugPrint('[Speech] Started listening...');
    _speech.listen(
      localeId: _localeId,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
      onResult: (result) {
        debugPrint('[Speech] Heard: "${result.recognizedWords}" | final: ${result.finalResult}');
        final words = result.recognizedWords.toLowerCase();

        // Count NEW "gising" appearances compared to last interim
        final newCount = _countWord(words, 'gising');
        final oldCount = _countWord(_lastInterimWords, 'gising');

        if (newCount > oldCount) {
          final diff = newCount - oldCount;
          debugPrint('[Speech] ✅ +$diff Gising detected! Total: ${_gisingCount + diff}');
          setState(() => _gisingCount = (_gisingCount + diff).clamp(0, _gisingTarget));
          if (_gisingCount >= _gisingTarget) _onCompleted();
        }

        _lastInterimWords = words;
      },
      onSoundLevelChange: null,
    );
  }

  int _countWord(String text, String word) {
    if (text.isEmpty) return 0;
    return word.allMatches(text).length;
  }

  void _onCompleted() {
    if (_completed) return;
    setState(() => _completed = true);
    _speech.stop();
    _audioPlayer.stop();
    Future.delayed(
      const Duration(milliseconds: 1500),
          () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const Lumi2ValuesWakingup(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 1500),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _speech.stop();
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
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen landscape image ──────────────────────────────────
            Lottie.asset(
              widget.imagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stack) => _buildImageError(),
            ),

            // ── Audio status overlay (debug / error only) ────────────────────
            if (_audioError != null) _buildAudioErrorBadge(),

            _buildMeter(),

            //X button
            Positioned(top: 25, left: 25, child: LumiXButton()),
          ],
        ),
      ),
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
              'Image not found.\nCheck assets/images/animations/sleeping.json',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeter() {
    if (!_audioFinished) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            'Sabihin ang "Gising!" nang $_gisingCount / $_gisingTarget',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Bar track
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Background track
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                ),

                // Filled portion
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

                // 3 tick markers
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
                            color: reached ? const Color(0xFFFFD700) : Colors.white24,
                            border: Border.all(
                              color: reached ? Colors.orange : Colors.white38,
                              width: 2,
                            ),
                            boxShadow: reached
                                ? [BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )]
                                : [],
                          ),
                          child: reached
                              ? const Icon(Icons.star_rounded, size: 13, color: Colors.white)
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