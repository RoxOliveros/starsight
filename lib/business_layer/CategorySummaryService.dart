import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'game_prompts.dart';

class CategorySummaryService {
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static const int _shortSummaryMaxWords = 35;

  /// Ensures a shortSummary never overflows the outer card's 4-line limit
  /// in a way that reads as cut off mid-sentence. If the model returns
  /// more than [_shortSummaryMaxWords] words, trims to the last full word
  /// within that budget and closes it out with a period, so the card
  /// always shows a complete-looking thought instead of a dangling clause.
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
    required List<String> aggregatedEmotions,
    required int totalMistakes,
  }) async {
    List<String> testedCriteria = [];
    for (String gameId in completedGameIds) {
      final config = GamePrompts.getConfig(gameId);
      testedCriteria.add("- ${config.activityName}: ${config.skillFocus}");
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
- Facial Emotions Detected (evaluate all carefully, including neutral and negative): ${aggregatedEmotions.join(', ')}
- Total Mistakes Made: $totalMistakes

IMPORTANT — this report is written by students, not licensed professionals.
It must stay strictly observational:
- Do NOT give the parent any suggestions, recommendations, tips, or things
  to try. Only describe what was observed and what that pattern generally
  indicates.
- Do NOT use "Confident" as a band — the only two allowed bands are
  "Emerging" and "Developing". Even strong performance should be described
  within "Developing", with the description explaining just how strong it
  was.

These two fields serve very different places in the UI and must never overlap in content:
- "shortSummary" appears ALONE on a small outer summary card, with no other
  text next to it. The card has room for about 4 lines of text, so
  "shortSummary" should be 1-2 complete sentences, roughly 20-30 words, and
  MUST NOT exceed 35 words (hard limit, never exceed this). It must be a
  punchy, self-contained, parent-friendly highlight — not a trimmed-down or
  compressed version of the detailed paragraph, and not a generic
  restatement of the band name. It should surface the single most notable,
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

Provide a JSON response strictly matching this structure:
{
  "overallAnalysis": "Write 3-4 sentences summarizing their overall performance and confidence, in plain language a parent can easily follow.",
  "engagement": {
    "band": "Emerging" | "Developing",
    "shortSummary": "1-2 complete sentences (~20-30 words) for the outer card — the single most notable takeaway about their engagement, not a summary of detailedDescription.",
    "detailedDescription": "3-5 sentences, shown only in the 'Learn More' dialog, describing their engagement in detail — what was observed, and what it generally suggests."
  },
  "attention": {
    "band": "Emerging" | "Developing",
    "shortSummary": "1-2 complete sentences (~20-30 words) for the outer card — the single most notable takeaway about their attention, not a summary of detailedDescription.",
    "detailedDescription": "3-5 sentences, shown only in the 'Learn More' dialog, describing their attention/focus in detail, based on mistakes and consistency — what was observed, and what it generally suggests."
  },
  "focus": {
    "band": "Emerging" | "Developing",
    "shortSummary": "1-2 complete sentences (~20-30 words) for the outer card — the single most notable takeaway about their focus, not a summary of detailedDescription.",
    "detailedDescription": "3-5 sentences, shown only in the 'Learn More' dialog, describing their ability to stick with tasks in detail — what was observed, and what it generally suggests."
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
      final response = await model.generateContent(content);

      if (response.text != null) {
        Map<String, dynamic> reportData = jsonDecode(response.text!);
        reportData['overallAnalysis'] =
            reportData['overallAnalysis'] + disclaimer;

        // Safety net: the model is instructed to keep shortSummary to
        // <=12 words, but if it ever overshoots, the card (maxLines: 2,
        // ellipsis) would cut it off mid-sentence and look broken. Trim at
        // a clean word boundary instead of letting the UI hard-truncate.
        for (final key in ['engagement', 'attention', 'focus']) {
          final construct = reportData[key];
          if (construct is Map && construct['shortSummary'] is String) {
            construct['shortSummary'] = _clampShortSummary(
              construct['shortSummary'] as String,
            );
          }
        }

        return reportData;
      }
      throw Exception("Null response from model");
    } catch (e) {
      print("Gemini API Error: $e");
      return {
        "overallAnalysis":
            "$childName explored $categoryName during this session, engaging with a mix of the activities available. "
            "Their responses varied across the different games played, showing both moments of steady focus and moments "
            "where attention shifted elsewhere.$disclaimer",
        "engagement": {
          "band": "Developing",
          "shortSummary":
              "Curiosity led the way this session, with $childName diving into activities eagerly and needing only the occasional pause.",
          "detailedDescription":
              "$childName showed curiosity while exploring the activities in $categoryName. "
              "There were periods of active participation mixed with brief pauses. "
              "This kind of variation is a normal part of how young children engage with new material.",
        },
        "attention": {
          "band": "Developing",
          "shortSummary":
              "Focus moved between tasks throughout the session, holding steadiest on the activities $childName found most engaging.",
          "detailedDescription":
              "During this session, $childName's focus shifted between the tasks at different points. "
              "Some activities held their attention more consistently than others. "
              "This pattern is common while a child is still building familiarity with an activity.",
        },
        "focus": {
          "band": "Developing",
          "shortSummary":
              "A steady, self-paced approach to each activity, with some tasks completed more smoothly than others.",
          "detailedDescription":
              "$childName worked through the activities at their own pace, with some tasks completed more smoothly than others. "
              "This reflects a child who is still developing the ability to stay with a task from start to finish.",
        },
      };
    }
  }
}
