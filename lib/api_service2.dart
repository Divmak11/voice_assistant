// api_calls.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiCalls {
  static const String SARVAM_STT_URL = 'https://api.sarvam.ai/speech-to-text';
  static const String SARVAM_TTS_URL = 'https://api.sarvam.ai/text-to-speech';
  static const String LLM_URL = 'https://api.groq.com/openai/v1/chat/completions';

  Future<String> transcribeAudio(List<int> audioBytes) async {


    final response = await http.post(
      Uri.parse(SARVAM_STT_URL),
      headers: {"Content-Type": "multipart/form-data",
        'api-subscription-key': 'd6f07450-51e3-4db9-ad97-db7746aa0d70'},
      body: {
        'file': audioBytes,
        "model": "saarika:v1",
        "language_code": "hi-IN"
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['transcription'];
    } else {
      throw Exception('Failed to transcribe audio');
    }
  }

  Stream<String> sendToLLM(String transcription) async* {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer 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'
    };

    final body = jsonEncode({
      'model': 'llama3-groq-70b-8192-tool-use-preview',  // or any other model you prefer
      'messages': [
        {'role': 'system', 'content': promptMessage},
        {'role': 'user', 'content': transcription}
      ],
      'temperature': 0.7,
      'max_tokens': 1000,
      'stream': true,
    });

    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = body;

    final client = http.Client();
    final streamedResponse = await client.send(request);

    await for (final value in streamedResponse.stream.transform(utf8.decoder)) {
      final lines = value.split('\n');

      for (final line in lines) {
        if (line.startsWith('data: ') && line != 'data: [DONE]') {
          final jsonLine = line.substring(6);
          final jsonResponse = jsonDecode(jsonLine);
          final token = jsonResponse['choices'][0]['delta']['content'];
          if (token != null) {
            yield token;
          }
        }
      }
    }
  }

  Future<List<int>> textToSpeech(String text) async {
    final response = await http.post(
      Uri.parse(SARVAM_TTS_URL),
      headers: {'Content-Type': 'application/json',
        'api-subscription-key': 'd6f07450-51e3-4db9-ad97-db7746aa0d70'},
      body: json.encode({
        'inputs': [text],
        'target_language_code': "hi-IN",
        "speaker": "meera",
        "pitch": -1,
        "speech_sample_rate":16000,
        "enable_preprocessing":true,
        "model":"bulbul:v1"
      }),
    );

    if (response.statusCode == 200) {
      // The response is a base64 encoded .wav file
      String base64Audio = json.decode(response.body)['audio'];
      return base64.decode(base64Audio);
    } else {
      throw Exception('Failed to convert text to speech: ${response.body}');
    }
  }
}