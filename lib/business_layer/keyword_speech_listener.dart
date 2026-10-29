import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class KeywordSpeechListener {
  KeywordSpeechListener({
    required this.pattern,
    required this.onNewMatches,
    this.onSpeechActivity,
    this.preferredLocale = 'fil_PH',
    this.fallbackLocale = 'en_US',
  });

  final RegExp pattern;
  final void Function(int count) onNewMatches;
  final VoidCallback? onSpeechActivity;
  final String preferredLocale;
  final String fallbackLocale;

  final SpeechToText _speech = SpeechToText();
  late String _localeId = fallbackLocale;
  Timer? _restartTimer;
  bool _available = false;
  bool _wantListening = false;
  bool _disposed = false;
  int _sessionCounted = 0;
  int _failures = 0;

  Duration get _restartDelay =>
      Duration(milliseconds: 250 * (1 << math.min(_failures, 4)));

  Future<bool> start() async {
    _available = await _speech.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
    if (_disposed) {
      _detach();
      return false;
    }
    if (!_available) return false;

    _speech.errorListener = _onError;
    _speech.statusListener = _onStatus;

    final locales = await _speech.locales();
    if (_disposed) return false;
    _localeId = locales.any((l) => l.localeId == preferredLocale)
        ? preferredLocale
        : fallbackLocale;
    debugPrint('[Speech] Using locale: $_localeId');

    resume();
    return true;
  }

  void resume() {
    if (_disposed || !_available) return;
    _wantListening = true;
    _failures = 0;
    _schedule(const Duration(milliseconds: 150));
  }

  Future<void> pause() async {
    _wantListening = false;
    _restartTimer?.cancel();
    await _speech.cancel();
  }

  void dispose() {
    _disposed = true;
    _wantListening = false;
    _restartTimer?.cancel();
    _detach();
    unawaited(_speech.cancel());
  }

  void _detach() {
    if (_speech.errorListener == _onError) _speech.errorListener = null;
    if (_speech.statusListener == _onStatus) _speech.statusListener = null;
  }

  void _schedule(Duration delay) {
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, _listen);
  }

  Future<void> _listen() async {
    if (_disposed || !_wantListening || _speech.isListening) return;
    _sessionCounted = 0; // a new session starts from empty text
    try {
      await _speech.listen(
        localeId: _localeId,
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(minutes: 1),
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('[Speech] listen() failed: $e');
      _failures++;
      _schedule(_restartDelay);
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    if (_disposed || !_wantListening) return;
    if (r.recognizedWords.isNotEmpty) {
      _failures = 0;
      onSpeechActivity?.call();
    }
    final total = pattern.allMatches(r.recognizedWords.toLowerCase()).length;
    if (total > _sessionCounted) {
      final fresh = total - _sessionCounted;
      _sessionCounted = total;
      onNewMatches(fresh);
    }
  }

  void _onStatus(String status) {
    debugPrint('[Speech] Status: $status');
    final ended = status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus;
    if (!ended || !_wantListening) return;
    if (_restartTimer?.isActive ?? false) return;
    _schedule(_restartDelay);
  }

  void _onError(SpeechRecognitionError e) {
    debugPrint('[Speech] Error: ${e.errorMsg}');
    if (e.errorMsg == 'error_permission') {
      _wantListening = false;
      return;
    }
    final benign =
        e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout';
    if (!benign) _failures++;
    if (_wantListening) _schedule(_restartDelay);
  }
}