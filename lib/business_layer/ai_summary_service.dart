import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiSummaryService {
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<String> generateParentSummary({
    required String childName,
    required String activityName,
    required List<String> emotionsList,
    required String timePlayed,
    required int mistakesMade,
  }) async {
    if (emotionsList.isEmpty) {
      return "We didn't catch $childName's expressions this time, but they completed the activity!";
    }

    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: apiKey,
    );

    String systemPrompt =
        """
You are an encouraging and professional child development assistant for an app called IntelliPlay.
Your goal is to write a short, friendly report for a parent about their child's gameplay.

DATA:
Child's Name: $childName
Activity: $activityName
Emotions Detected: ${emotionsList.join(", ")}
Time Played: $timePlayed
Mistakes Made: $mistakesMade

INSTRUCTIONS:
1. First, provide exactly 4 bullet points. 
   - Emotion: (The dominant emotion from the list)
   - Focus: (High, Moderate, or Variable based on the emotions)
   - Time: $timePlayed
   - Performance: (Do not say the exact number of mistakes. If 0 mistakes, say "Completed the activity smoothly!". If 1-3 mistakes, say "Made a few learning attempts but figured it out nicely". If more than 3, say "Showed great persistence through the tricky parts".)

2. Skip a line.
3. Write a warm, 2-to-3 sentence paragraph summarizing their session. Frame the emotions and mistakes positively, emphasizing resilience, focus, and learning. Use the child's actual name. Keep the language simple, warm, and easy to read—do not use complicated academic jargon. Do not use bolding or asterisks in your response.

Format exactly like this example:
• Emotion: Frustrated
• Focus: High
• Time: 1m 45s
• Performance: Made a few learning attempts but figured it out nicely

$childName showed remarkable focus and determination while playing $activityName, staying engaged with the activity for the entire duration. While they encountered a few moments of frustration as they worked through the challenges, their persistence in staying on task is a wonderful sign of their developing resilience. We are so proud of how they stayed focused on their goal and kept working toward the finish line!
""";
    try {
      final content = [Content.text(systemPrompt)];
      final response = await model.generateContent(content);
      return response.text?.trim() ?? "Summary generation failed.";
    } catch (e) {
      print("Gemini Error: $e");
      return "Great job completing the activity!";
    }
  }
}
