import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'game_prompts.dart';

/// Why a report could not be generated.
enum ReportErrorType { noInternet, serviceError }

/// Thrown instead of returning a made-up report, so the screen can tell the
/// parent what actually went wrong.
class ReportGenerationException implements Exception {
  final ReportErrorType type;
  const ReportGenerationException(this.type);

  /// Parent-friendly explanation, safe to show on screen.
  String get message {
    switch (type) {
      case ReportErrorType.noInternet:
        return "We couldn't load the report because there's no internet "
            "connection. Please check your Wi-Fi or mobile data and try again.";
      case ReportErrorType.serviceError:
        return "Something went wrong on our side while preparing the report, "
            "so it isn't available right now. Please try again in a little "
            "while.";
    }
  }

  @override
  String toString() => 'ReportGenerationException($type)';
}

class CategorySummaryService {
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static const Duration _requestTimeout = Duration(seconds: 40);

  /// True when [e] looks like a connectivity problem (as opposed to the AI
  /// service or the app itself failing).
  static bool looksLikeNetworkError(Object e) {
    if (e is SocketException ||
        e is TimeoutException ||
        e is http.ClientException) {
      return true;
    }
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection reset') ||
        msg.contains('connection refused') ||
        msg.contains('connection closed') ||
        msg.contains('network-request-failed') ||
        msg.contains('cloud_firestore/unavailable');
  }

  static const int _shortSummaryMaxWords = 35;

  /// Ensures a shortSummary never overflows the outer card's 4-line limit
  /// in a way that reads as cut off mid-sentence. If the model returns
  /// more than [_shortSummaryMaxWords] words, trims to the last full word
  /// within that budget and closes it out with a period, so the card
  /// always shows a complete-looking thought instead of a dangling clause.
  /// Maps a raw label from the camera server (including old saved sessions
  /// that still carry "FOCUSED - HAPPY" style labels) to a simple bucket.
  static String _bucketFor(String raw) {
    final s = raw.toUpperCase();
    if (s.startsWith('FOCUSED')) return 'onScreen';
    if (s.contains('LOOKING AWAY')) return 'lookingAway';
    if (s.contains('HEAD TURNED')) return 'headTurned';
    if (s.contains('AWAY FROM SCREEN')) return 'movedBack';
    if (s.contains('EYES DROOPING')) return 'tiredEyes';
    return 'other';
  }

  /// Turns the list of per-frame attention labels into a short plain-text
  /// summary for the prompt. Percentages go to the model only; the prompt
  /// tells it to describe them in words, never as numbers.
  static String _summarizeAttention(List<String> states) {
    final readings = states.map(_bucketFor).where((b) => b != 'other').toList();
    if (readings.isEmpty) {
      return 'No camera readings were available for this session. Do NOT make '
          'any claims about where the child was looking; base "attention" '
          'only on mistakes and games completed.';
    }

    final counts = <String, int>{};
    for (final b in readings) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
    int pct(String key) =>
        (((counts[key] ?? 0) * 100) / readings.length).round();

    return '''Camera attention readings (${readings.length} readings, estimates only):
- Face and eyes toward the screen: ${pct('onScreen')}%
- Eyes looked away from the screen: ${pct('lookingAway')}%
- Head turned away: ${pct('headTurned')}%
- Moved back / away from the screen: ${pct('movedBack')}%
- Eyes looked tired or closed: ${pct('tiredEyes')}%''';
  }

  static String _clampShortSummary(String text) {
    final trimmed = text.trim();
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length <= _shortSummaryMaxWords) return trimmed;

    String clipped = words.take(_shortSummaryMaxWords).join(' ');
    // Drop a trailing comma/semicolon/dash left dangling by the cut.
    clipped = clipped.replaceAll(RegExp(r'[,;:\-–—]+$'), '');
    if (!clipped.endsWith('.') &&
        !clipped.endsWith('!') &&
        !clipped.endsWith('?')) {
      clipped = '$clipped.';
    }
    return clipped;
  }

  static Future<Map<String, dynamic>> generateCategoryReport({
    required String categoryName,
    required String childName,
    required List<String> completedGameIds,
    required int totalCategoryGames,
    required List<String> attentionStates,
    required int totalMistakes,
  }) async {
    List<String> testedCriteria = [];
    for (String gameId in completedGameIds) {
      final config = GamePrompts.getConfig(gameId);
      testedCriteria.add("- ${config.activityName}: ${config.skillFocus}");
    }

    if (apiKey.isEmpty) {
      print('GEMINI_API_KEY is missing');
      throw const ReportGenerationException(ReportErrorType.serviceError);
    }

    // Force the API to return strict JSON
    final model = GenerativeModel(
      model: 'gemini-3.5-flash-lite',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    String prompt =
        '''
You are an expert early childhood educator writing a progress report for a parent regarding their child, $childName, who is playing "$categoryName".

Raw Session Data:
- Games Completed: ${completedGameIds.length} out of $totalCategoryGames
- Activities Played: ${completedGameIds.join(', ')}
- ${_summarizeAttention(attentionStates)}
- Total Mistakes Made: $totalMistakes

IMPORTANT — this report is written by students, not licensed professionals.
It must stay strictly observational:
- Do NOT give the parent any suggestions, recommendations, tips, or things
  to try. Only describe what was observed and what that pattern generally
  indicates.
- Do NOT assign labels, levels, bands, grades, or scores of any kind.
  Describe what was observed in plain words only.
- The camera readings are automatic estimates, so use soft wording such as
  "appeared to" or "seemed to". Do NOT quote any numbers or percentages;
  describe amounts in words like "most of the time" or "occasionally".
- Do NOT describe or guess the child's emotions or mood. Only attention
  (where they seemed to be looking), and how steadily they worked, are
  measured.

These two fields serve very different places in the UI and must never overlap in content:
- "shortSummary" appears ALONE on a small outer summary card, with no other
  text next to it. The card has room for about 4 lines of text, so
  "shortSummary" should be 1-2 complete sentences, roughly 20-30 words, and
  MUST NOT exceed 35 words (hard limit, never exceed this). It must be a
  punchy, self-contained, parent-friendly highlight — not a trimmed-down or
  compressed version of the detailed paragraph, and not a generic
  restatement of the topic name. It should surface the single most notable,
  specific takeaway (e.g. a concrete behavior or standout moment), written
  so every sentence in it is fully finished within the word limit — never
  write a longer passage and assume it will be cut off, since it will
  display exactly as written and get truncated with "..." if too long.
- "detailedDescription" appears ONLY inside a separate "Learn More" dialog
  that the parent opens deliberately. This is the sole place for the fuller
  3-5 sentence explanation — supporting observations, nuance, and what the
  pattern generally indicates. Do not front-load its content into
  shortSummary; assume the parent has not yet seen detailedDescription when
  they read shortSummary.

Provide a JSON response strictly matching this structure (no other keys):
{
  "overallAnalysis": "Write 3-4 sentences summarizing their overall performance, in plain language a parent can easily follow.",
  "attention": {
    "shortSummary": "1-2 complete sentences (~20-30 words) for the outer card — the single most notable takeaway about where their eyes and face seemed to be during play, not a summary of detailedDescription.",
    "detailedDescription": "3-5 sentences, shown only in the 'Learn More' dialog, describing their attention in detail, based mainly on the camera readings — what was observed, and what it generally suggests."
  },
  "focus": {
    "shortSummary": "1-2 complete sentences (~20-30 words) for the outer card — the single most notable takeaway about how steadily they worked, not a summary of detailedDescription.",
    "detailedDescription": "3-5 sentences, shown only in the 'Learn More' dialog, describing their ability to stick with tasks in detail, based on games completed, mistakes and consistency — what was observed, and what it generally suggests."
  }
}
''';

    String disclaimer = "";
    if (completedGameIds.length < totalCategoryGames) {
      disclaimer =
          "\n\n*Please note: This analysis is based on partial progress and will evolve as $childName completes the rest of the $categoryName.*";
    }

    try {
      final content = [Content.text(prompt)];
      final response = await model
          .generateContent(content)
          .timeout(_requestTimeout);

      if (response.text != null) {
        final decoded = jsonDecode(response.text!);
        if (decoded is! Map<String, dynamic> ||
            decoded['overallAnalysis'] is! String ||
            decoded['attention'] is! Map ||
            decoded['focus'] is! Map) {
          throw const ReportGenerationException(ReportErrorType.serviceError);
        }
        final Map<String, dynamic> reportData = decoded;
        reportData['overallAnalysis'] =
            reportData['overallAnalysis'] + disclaimer;

        // Safety net: the model is instructed to keep shortSummary to
        // <=35 words, but if it ever overshoots, the card would cut it off
        // mid-sentence and look broken. Trim at a clean word boundary
        // instead of letting the UI hard-truncate.
        for (final key in ['attention', 'focus']) {
          final construct = reportData[key];
          if (construct is Map && construct['shortSummary'] is String) {
            construct['shortSummary'] = _clampShortSummary(
              construct['shortSummary'] as String,
            );
          }
        }

        return reportData;
      }
      throw const ReportGenerationException(ReportErrorType.serviceError);
    } on ReportGenerationException {
      rethrow;
    } catch (e) {
      print("Gemini API Error: $e");
      // Never invent a report. Tell the parent what actually went wrong.
      throw ReportGenerationException(
        looksLikeNetworkError(e)
            ? ReportErrorType.noInternet
            : ReportErrorType.serviceError,
      );
    }
  }
}
