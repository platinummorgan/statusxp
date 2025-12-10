import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AchievementGuideService {
  static bool _initialized = false;

  /// Initialize OpenAI with API key from environment
  static void initialize() {
    if (_initialized) return;
    
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in .env file');
    }
    
    OpenAI.apiKey = apiKey;
    _initialized = true;
  }

  /// Generate an achievement guide using OpenAI
  /// Returns a stream of text chunks as they're generated
  Stream<String> generateGuide({
    required String gameTitle,
    required String achievementName,
    required String achievementDescription,
    String? platform,
  }) async* {
    initialize();

    final prompt = _buildPrompt(
      gameTitle: gameTitle,
      achievementName: achievementName,
      achievementDescription: achievementDescription,
      platform: platform,
    );

    final stream = OpenAI.instance.chat.createStream(
      model: 'gpt-4o-mini', // Using mini for cost efficiency
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              'You are a helpful gaming assistant that provides concise, actionable guides for unlocking achievements and trophies. Keep responses under 200 words.',
            ),
          ],
        ),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
          ],
        ),
      ],
      temperature: 0.7,
      maxTokens: 300,
    );

    await for (final event in stream) {
      final content = event.choices.first.delta.content;
      if (content != null && content.isNotEmpty) {
        for (final item in content) {
          final text = item?.text;
          if (text != null) {
            yield text;
          }
        }
      }
    }
  }

  /// Build the prompt for OpenAI
  String _buildPrompt({
    required String gameTitle,
    required String achievementName,
    required String achievementDescription,
    String? platform,
  }) {
    final platformText = platform != null ? ' ($platform)' : '';
    
    return '''
Game: $gameTitle$platformText
Trophy/Achievement: $achievementName
Requirements: $achievementDescription

Respond EXACTLY in this format with these sections:

Obtainable?
[State if it's still obtainable, if it's missable, requires DLC, or has any restrictions]

Method:
[Provide clear, numbered steps on how to unlock this]
[Be specific with locations, button combinations, requirements]
[Mention if it's unmissable or story-related]

YouTube reference:
[Provide a YouTube URL for a video guide if possible, or state "No specific video guide found"]

Keep it concise and actionable. No fluff.
''';
  }
}
