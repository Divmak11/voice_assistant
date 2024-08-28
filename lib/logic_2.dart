import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'api_service2.dart'; // Make sure this file exists with the ApiCalls class

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Assistant',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: VoiceAssistant(),
    );
  }
}

class VoiceAssistant extends StatefulWidget {
  @override
  _VoiceAssistantState createState() => _VoiceAssistantState();
}

class _VoiceAssistantState extends State<VoiceAssistant> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ApiCalls _apiCalls = ApiCalls();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  String _transcription = '';
  String _assistantResponse = '';
  Timer? _silenceTimer;
  StreamSubscription? _recorderSubscription;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _startRecording() async {
    if (!_recorder.isRecording) {
      await _recorder.startRecorder(
        toFile: 'temp_audio.wav',
        codec: Codec.pcm16WAV,
        numChannels: 1,
        sampleRate: 16000,
      );
      setState(() {
        _isRecording = true;
        _transcription = '';
        _assistantResponse = '';
      });
      _startListening();
    }
  }

  void _startListening() {
    _recorderSubscription = _recorder.onProgress!.listen((event) {
      if (event.duration.inMilliseconds >= 1000) {
        _processAudioChunk();
      }
      _resetSilenceTimer();
    });
  }

  Future<void> _processAudioChunk() async {
    String? path = await _recorder.stopRecorder();
    if (path != null) {
      Uint8List audioData = await File(path).readAsBytes();

      // Restart recording
      await _startRecording();

      // Process the audio chunk
      String partialTranscription = await _apiCalls.transcribeAudio(audioData);
      setState(() {
        _transcription += ' ' + partialTranscription;
      });
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(milliseconds: 400), _onSilenceDetected);
  }

  void _onSilenceDetected() async {
    await _stopRecording();
    _sendToLLM();
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    _recorderSubscription?.cancel();
    setState(() => _isRecording = false);
  }

  void _sendToLLM() async {
    String fullTranscription = _transcription.trim();
    if (fullTranscription.isNotEmpty) {
      _apiCalls.sendToLLM(fullTranscription).listen(
            (response) {
          setState(() {
            _assistantResponse += response;
          });
          if (_assistantResponse.endsWith('.') || _assistantResponse.endsWith('!') || _assistantResponse.endsWith('?')) {
            _convertToSpeech(_assistantResponse);
            _assistantResponse = '';
          }
        },
        onDone: () {
          if (_assistantResponse.isNotEmpty) {
            _convertToSpeech(_assistantResponse);
            _assistantResponse = '';
          }
        },
      );
    }
  }

  void _convertToSpeech(String text) async {
    List<int> audioBytes = await _apiCalls.textToSpeech(text);
    await _audioPlayer.setAudioSource(
      AudioSource.uri(Uri.dataFromBytes(audioBytes)),
    );
    _audioPlayer.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Voice Assistant')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            SizedBox(height: 20),
            Text('User: $_transcription'),
            SizedBox(height: 20),
            Text('Assistant: $_assistantResponse'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    _silenceTimer?.cancel();
    _recorderSubscription?.cancel();
    super.dispose();
  }
}

//DEEPGRAM LOGIC

// // main.dart
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'api_service.dart';
// import 'dart:typed_data';
// import 'package:sound_stream/sound_stream.dart';
// import 'package:just_audio/just_audio.dart';
//
// void main() => runApp(MyApp());
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: HomeScreen(),
//     );
//   }
// }
//
// class HomeScreen extends StatefulWidget {
//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   final ApiService _apiService = ApiService();
//   final RecorderStream _recorder = RecorderStream();
//   bool _isRecording = false;
//   String _currentTranscript = '';
//   String _query = '';
//   bool _isProcessing = false;
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   DateTime _lastTimestamp = DateTime.now();
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeRecorder();
//   }
//
//   Future<void> _initializeRecorder() async {
//     await Permission.microphone.request();
//     await _recorder.initialize();
//   }
//
//   @override
//   void dispose() {
//     _recorder.stop();
//     _audioPlayer.dispose();
//     super.dispose();
//   }
//
//   void _startListening() async {
//       _isRecording = true;
//       _currentTranscript = '';
//       _query = '';
//
//       _apiService.startTranscription(_recorder.audioStream, (transcription) {
//         final now = DateTime.now();
//         final durationSinceLast = now.difference(_lastTimestamp).inMilliseconds / 1000.0;
//
//         if (durationSinceLast <= 0.5) {
//           _query += ' ' + transcription;
//         } else {
//           if (_query.isNotEmpty && !_isProcessing) { // Added check for processing state
//             _sendQueryToGroq(_query);
//           }
//           _query = transcription;
//         }
//
//         _lastTimestamp = now;
//
//         setState(() {
//           _currentTranscript = _query;
//         });
//       });
//     await _recorder.start();
//   }
//
//   void _sendQueryToGroq(String query) async {
//     List<String> buffer = [];
//     String currentSentence = '';
//
//     await _apiService.sendQueryToGroq(query, (token) async {
//       currentSentence += token;
//       if (token.contains('.') || token.contains('?') || token.contains('!')) {
//         buffer.add(currentSentence.trim());
//         currentSentence = '';
//
//         if (buffer.isNotEmpty) {
//           String textToConvert = buffer.join(' ');
//           buffer.clear();
//           await _apiService.convertTextToSpeech(textToConvert, (audioStream) {
//             // // Play the audio stream
//             // int random = DateTime.now().millisecondsSinceEpoch;
//             // final path = await saveDataToFile("$random.wav", audioStream.data);
//             // await player.play(DeviceFileSource(path));
//
//             _playAudio(audioStream);
//           });
//         }
//       }
//     });
//
//     // Convert any remaining text in the buffer
//     if (currentSentence.isNotEmpty) {
//       buffer.add(currentSentence.trim());
//     }
//     if (buffer.isNotEmpty) {
//       String textToConvert = buffer.join(' ');
//       await _apiService.convertTextToSpeech(textToConvert, (audioStream) {
//         // Play the audio stream
//         // int random = DateTime.now().millisecondsSinceEpoch;
//         // final path = await saveDataToFile("$random.wav", audioStream.data);
//         // await player.play(DeviceFileSource(path));
//         _playAudio(audioStream);
//
//       });
//     }
//   }
//
//   Future<void> _playAudio(Uint8List audioData) async {
//     try {
//       final audioBuffer = Uint8List.fromList(audioData);
//
//       // Create an AudioSource from the buffer
//       final audioSource = AudioSource.uri(
//         Uri.dataFromBytes(audioBuffer, mimeType: 'audio/wav'),
//       );
//
//       // Set the audio source and play
//       await _audioPlayer.setAudioSource(audioSource);
//       await _audioPlayer.play();
//     } catch (e) {
//       print("Error playing audio: $e");
//     }
//   }
//
//   void _stopListening() {
//     setState(() {
//       _isRecording = false;
//     });
//     _recorder.stop();
//     _apiService.stopTranscription();
//     if (_query.isNotEmpty && !_isProcessing) { // Added check for processing state
//       _sendQueryToGroq(_query);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Voice Assistant')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             ElevatedButton(
//               onPressed: _isRecording ? null : _startListening,
//               child: Text('Start Listening'),
//             ),
//             ElevatedButton(
//               onPressed: _isRecording ? _stopListening : null,
//               child: Text('Stop Listening'),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Text('Transcription: $_currentTranscript'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class MyCustomSource extends StreamAudioSource {
//   final Uint8List _buffer;
//
//   MyCustomSource(this._buffer);
//
//   @override
//   Future<StreamAudioResponse> request([int? start, int? end]) async {
//     start ??= 0;
//     end ??= _buffer.length;
//     return StreamAudioResponse(
//       sourceLength: _buffer.length,
//       contentLength: end - start,
//       offset: start,
//       stream: Stream.value(_buffer.sublist(start, end)),
//       contentType: 'audio/wav',
//     );
//   }
// }


///NEXT CODE LOGIC