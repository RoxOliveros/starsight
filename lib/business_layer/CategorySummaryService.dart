import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'game_prompts.dart';

class CategorySummaryService {
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<String> generateCategoryReport({
    required String categoryName, // e.g., "Alphabet Forest"
    required String childName,
    required List<String>
    completedGameIds, // e.g., ['forest_woodpecker', 'forest_mushroom']
    required int totalCategoryGames, // e.g., 24
    required List<String> aggregatedEmotions,
    required int totalMistakes,
  }) async {
    // 1. Check completion status for Roxanne's disclaimer
    bool isCompleted = completedGameIds.length >= totalCategoryGames;
    String disclaimer = isCompleted
        ? ""
        : "\n\n*Note: This analysis may change as the child has not yet completed all levels in this category.*";

    // 2. Gather the criteria for the games they ACTUALLY played
    List<String> testedCriteria = [];
    for (String gameId in completedGameIds) {
      final config = GamePrompts.getConfig(gameId);
      testedCriteria.add("- ${config.activityName}: ${config.skillFocus}");
    }

    // 3. Build the Gemini Prompt
    final model = GenerativeModel(model: 'gemini-3.7-flash', apiKey: apiKey);

    final String systemPrompt =
        """
You are a professional early childhood educator writing a category-level observation report for an app called StarSight.

DATA:
- Child's Name: $childName
- Category: $categoryName
- Games Played & Criteria Tested:
${testedCriteria.join("\n")}
- Overall Emotions Detected: ${aggregatedEmotions.join(", ")}
- Total Learning Attempts/Mistakes: $totalMistakes

REQUIREMENTS:
1. Write a comprehensive, descriptive paragraph (4-6 sentences) summarizing their performance across these specific criteria.
2. Adopt a clinical but encouraging educator tone. 
EXAMPLE TONE: "$childName demonstrated sustained attention while completing the activity and remained engaged with the task for most of the observation period. Occasional distractions were observed, but the child was able to return to the activity without assistance."
3. Frame mistakes positively as "learning attempts" or "problem-solving moments."
4. Do NOT use bullet points, bolding, or complicated jargon.
""";

    try {
      final content = [Content.text(systemPrompt)];
      final response = await model.generateContent(content);

      String finalReport =
          (response.text?.trim() ?? "Summary failed.") + disclaimer;
      return finalReport;
    } catch (e) {
      return "Great job exploring $categoryName!$disclaimer";
    }
  }
}
