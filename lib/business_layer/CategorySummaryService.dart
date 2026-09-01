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
    // 1. Gather the criteria for the games they ACTUALLY played
    List<String> testedCriteria = [];
    for (String gameId in completedGameIds) {
      final config = GamePrompts.getConfig(gameId);
      testedCriteria.add("- ${config.activityName}: ${config.skillFocus}");
    }

    // 2. Build the Gemini Prompt
    final model = GenerativeModel(model: 'gemini-3.7-flash', apiKey: apiKey);

    String prompt =
        '''
You are an expert early childhood educator writing a progress report for a parent regarding their child, $childName. 
The child is currently playing the "$categoryName" category.

Here is the raw data from their recent session:
- Games Completed: ${completedGameIds.length} out of $totalCategoryGames
- Activities Played: ${completedGameIds.join(', ')}
- Predominant Facial Emotions Detected: ${aggregatedEmotions.join(', ')}
- Total Mistakes Made: $totalMistakes

Based strictly on this data, write a short, 3-section report formatted exactly like this:

**1. Current Engagement:** (Write 2 sentences analyzing their emotions and time spent based on the data provided. Do not assume they finished the category if the completed games are low.)
**2. Performance & Accuracy:** (Write 2 sentences analyzing their mistake count across the specific activities played.)
**3. Educator's Recommendation:** (Provide 1 specific, actionable tip for the parent based on this session's data.)

Do not include any generic greetings or sign-offs. 
''';

    // 3. Prepare the disclaimer in advance so the whole method can use it
    String disclaimer = "";
    if (completedGameIds.length < totalCategoryGames) {
      disclaimer =
          "\n\n*Please note: This analysis is based on partial progress and will evolve as $childName completes the rest of the $categoryName.*";
    }

    // 4. Call Gemini and append the disclaimer
    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      String aiGeneratedText =
          response.text?.trim() ?? "Not enough data to generate a report.";

      // Combine the AI text with our dynamic disclaimer
      return aiGeneratedText + disclaimer;
    } catch (e) {
      // If the internet drops or the API fails, it still returns a safe fallback with the disclaimer
      return "Great job exploring $categoryName!$disclaimer";
    }
  }
}
