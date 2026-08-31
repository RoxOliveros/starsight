import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'game_prompts.dart';

class AiSummaryService {
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<String> generateParentSummary({
    required String gameId,
    required String childName,
    required List<String> emotionsList,
    required String timePlayed,
    required int totalTaps,
    required int mistakesMade,
  }) async {
    final config = GamePrompts.getConfig(gameId);

    if (emotionsList.isEmpty) {
      return "We didn't catch $childName's expressions this time, but they completed ${config.activityName} nicely!";
    }

    final model = GenerativeModel(model: 'gemini-3.7-flash', apiKey: apiKey);

    final String systemPrompt =
        """
You are an encouraging and professional early childhood educator writing an observation note for parents on an app called StarSight.

SESSION DATA:
- Child's Name: $childName
- Activity: ${config.activityName}
- Specific Skill Focus: ${config.skillFocus}
- Emotions Detected: ${emotionsList.join(", ")}
- Time Played: $timePlayed
- Total Interactions / Taps: $totalTaps
- Learning Attempts / Mistakes: $mistakesMade

REQUIREMENTS:
1. Write a single, warm, descriptive paragraph (3 to 4 sentences).
2. Use the child's actual name ($childName).
3. Frame emotions and mistakes positively, emphasizing curiosity, focus, and resilience.
4. ${config.educatorGuidance}
5. Keep language simple, encouraging, and natural for parents. Do NOT use bullet points, asterisks, or bold text.
""";

    try {
      final content = [Content.text(systemPrompt)];
      final response = await model.generateContent(content);
      return response.text?.trim() ??
          "Great job completing ${config.activityName}!";
    } catch (e) {
      return "Great job completing ${config.activityName}!";
    }
  }
}
