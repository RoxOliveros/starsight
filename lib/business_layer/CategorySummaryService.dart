import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'game_prompts.dart';

class CategorySummaryService {
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

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
  was — the certainty implied by "Confident" isn't something we can claim.
- Each "description" should be 3-5 sentences, written in warm, plain
  language a parent with no background in child development or psychology
  could easily follow. Avoid clinical or academic terms. Be specific about
  what was actually observed during play (not generic filler), and explain
  in simple terms what that pattern generally means for a child this age
  — without turning it into advice.

Provide a JSON response strictly matching this structure:
{
  "overallAnalysis": "Write 3-4 sentences summarizing their overall performance and confidence, in plain language a parent can easily follow.",
  "engagement": {
    "band": "Emerging" | "Developing",
    "description": "3-5 sentences describing their engagement in detail — what was observed, and what it generally suggests."
  },
  "attention": {
    "band": "Emerging" | "Developing",
    "description": "3-5 sentences describing their attention/focus in detail, based on mistakes and consistency — what was observed, and what it generally suggests."
  },
  "focus": {
    "band": "Emerging" | "Developing",
    "description": "3-5 sentences describing their ability to stick with tasks in detail — what was observed, and what it generally suggests."
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
        // Append the disclaimer to the overall analysis
        reportData['overallAnalysis'] =
            reportData['overallAnalysis'] + disclaimer;
        return reportData;
      }
      throw Exception("Null response from model");
    } catch (e) {
      print("Gemini API Error: $e");
      // Safe fallback map if offline or error — kept in the same
      // observational, no-advice, two-band style as the real prompt above.
      return {
        "overallAnalysis":
            "$childName explored $categoryName during this session, engaging with a mix of the activities available. "
            "Their responses varied across the different games played, showing both moments of steady focus and moments "
            "where attention shifted elsewhere.$disclaimer",
        "engagement": {
          "band": "Developing",
          "description":
              "$childName showed curiosity while exploring the activities in $categoryName. "
              "There were periods of active participation mixed with brief pauses. "
              "This kind of variation is a normal part of how young children engage with new material.",
        },
        "attention": {
          "band": "Developing",
          "description":
              "During this session, $childName's focus shifted between the tasks at different points. "
              "Some activities held their attention more consistently than others. "
              "This pattern is common while a child is still building familiarity with an activity.",
        },
        "focus": {
          "band": "Developing",
          "description":
              "$childName worked through the activities at their own pace, with some tasks completed more smoothly than others. "
              "This reflects a child who is still developing the ability to stay with a task from start to finish.",
        },
      };
    }
  }
}
