import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'game_prompts.dart';

class CategorySummaryService {
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  // CHANGED: Now returns a Map (JSON) instead of a String!
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

Provide a JSON response strictly matching this structure:
{
  "overallAnalysis": "Write 2-3 sentences summarizing their overall performance and confidence.",
  "engagement": {
    "band": "Emerging" | "Developing" | "Confident",
    "description": "1 sentence describing their engagement.",
    "tips": ["Tip 1", "Tip 2", "Tip 3"]
  },
  "attention": {
    "band": "Emerging" | "Developing" | "Confident",
    "description": "1 sentence describing their attention/focus based on mistakes.",
    "tips": ["Tip 1", "Tip 2", "Tip 3"]
  },
  "focus": {
    "band": "Emerging" | "Developing" | "Confident",
    "description": "1 sentence describing their ability to stick with tasks.",
    "tips": ["Tip 1", "Tip 2", "Tip 3"]
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
      // Safe fallback map if offline or error
      return {
        "overallAnalysis": "Great job exploring $categoryName!$disclaimer",
        "engagement": {
          "band": "Developing",
          "description": "Showing great curiosity.",
          "tips": ["Keep playing consistently!"],
        },
        "attention": {
          "band": "Developing",
          "description": "Learning new patterns.",
          "tips": ["Take breaks if needed."],
        },
        "focus": {
          "band": "Developing",
          "description": "Working through challenges.",
          "tips": ["Celebrate the small wins."],
        },
      };
    }
  }
}
