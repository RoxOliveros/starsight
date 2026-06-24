import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiSummaryService {
  static final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<String> generateParentSummary({
    required String childName,
    required String activityName,
    required List<String> emotionsList,
  }) async {
    if (emotionsList.isEmpty) {
      return "We didn't catch $childName's expressions this time, but they completed the activity!";
    }

    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: apiKey,
    );

    final prompt =
        '''
      You are an encouraging early childhood educator. 
      The child's name is $childName. They just finished playing the "$activityName" game.
      While playing, our AI camera tracked their focus and emotions every 3 seconds. 
      Here is the raw data list of their states: $emotionsList

      Write a short, warm, 2-to-3 sentence summary for the parents. 
      Highlight their overall focus, mention if they got frustrated or stayed happy, and keep it encouraging. 
      Do not list the raw data. Write it like a professional progress report.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text?.trim() ?? "Summary generation failed.";
    } catch (e) {
      print("Gemini Error: $e");
      return "Great job completing the activity!";
    }
  }
}
