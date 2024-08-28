// api_service.dart
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiService {
  final String deepgramApiKey = '3831117d877d51d0388b0ad264728c8c829496a9';
  late Deepgram deepgram;
  late DeepgramLiveTranscriber transcriber;

  ApiService() {
    deepgram = Deepgram(deepgramApiKey, baseQueryParams: {
      'model': 'nova-2-general',
      'detect_language': false,
      'language': 'hi',
      'encoding': 'linear16',
      'sample_rate': 16000,
      'interim_results': true,
      'vad_turnoff': 500, // 50
    });
  }

  void startTranscription(Stream<List<int>> audioStream,
      Function(String) onTranscription) {
    transcriber = deepgram.createLiveTranscriber(audioStream, queryParams: {
      'encoding': 'linear16',
      'sample_rate': 16000,
    });

    transcriber.stream.listen((DeepgramSttResult res) {
      if (res.transcript != null) {
        onTranscription(res.transcript!);
      }
    });

    transcriber.start();
  }

  void stopTranscription() {
    transcriber.close();
  }


Future<void> sendQueryToGroq(String queryText, Function(String) onTokenReceived) async {

  // final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
  // final headers = {
  //   'Content-Type': 'application/json',
  //   'Authorization': 'Bearer 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'
  // };
  //
  // final body = jsonEncode({
  //   'model': 'llama3-groq-70b-8192-tool-use-preview',  // or any other model you prefer
  //   'messages': [
  //     {'role': 'system',
  //       'content': promptMessage},
  //     {'role': 'user',
  //       'content': queryText}
  //   ],
  //   'temperature': 0.7,
  //   'max_tokens': 1000,
  //   'stream': false,
  // });
  //
  //
  // final request = http.Request('POST', url)
  //   ..headers.addAll(headers)
  //   ..body = body;
  //
  // final client = http.Client();
  // final streamedResponse = await client.send(request);
  //
  // streamedResponse.stream.transform(utf8.decoder).listen((value) {
  //
  //   final lines = value.split('\n');
  //
  //   print("Streamed Resp : $value");
  //
  //   // onTokenReceived(jsonDecode(value)['choices'][0]['message']['content']);
  //   for (final line in lines) {
  //     if (line.startsWith('data: ') && line != 'data: [DONE]') {
  //       final jsonLine = line.substring(6);
  //       final jsonResponse = jsonDecode(jsonLine);
  //       final token = jsonResponse['choices'][0]['delta']['content'];
  //       if (token != null) {
  //         onTokenReceived(token);
  //       }
  //     }
  //   }
  // });
}

  // Future<void> convertTextToSpeech(String text) async {
  //   print("Inside ConvertToSpeech Request");
  //   final response = await deepgram.speakFromText(text, queryParams: {
  //     'voice': 'en-US',
  //     'encoding': 'linear16',
  //     'container': 'wav',
  //   });
  //   if (response.data != null) {
  //     return response.data!;
  //   } else {
  //     throw Exception('Failed to convert text to speech');
  //   }

  Future<void> convertTextToSpeech(String text, Function(Uint8List) onAudioStreamReceived) async {

  //   Deepgram deepgramTTS = Deepgram(deepgramApiKey, baseQueryParams: {
  //     'model': 'aura-asteria-en',
  //     'encoding': "linear16",
  //     'container': "wav",
  //   });
  //
  //
  //   final res = await deepgramTTS.speakFromText(
  //       text
  //   );
  //
  //
  //   onAudioStreamReceived(res.data);
  }
}