
// main.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'dart:typed_data';
import 'package:sound_stream/sound_stream.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final RecorderStream _recorder = RecorderStream();
  bool _isRecording = false;
  String _currentTranscript = '';
  String _query = '';
  bool _isProcessing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime _lastTimestamp = DateTime.now();
  List<Uint8List> _audioChunks = [];
  Queue<Uint8List> _chunkQueue = Queue<Uint8List>();
  bool _isProcessingChunk = false;
  int _sampleRate = 16000; // Assuming 16kHz sample rate
  int _bytesPerSample = 2; // Assuming 16-bit audio
  int _chunkSize = 32000; // 250ms at 16kHz, 16-bit = 8000 bytes
  DateTime _lastApiCallTime = DateTime.now();


  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder.initialize();
  }

  @override
  void dispose() {
    _recorder.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startListening() async {

    setState(() {
      _isRecording = true;
      _currentTranscript = '';
      _query = '';
      _audioChunks.clear();
    });


      _recorder.audioStream.listen((audio) {
        _processAudioChunk(audio);
      });

      // _apiService.startTranscription(_recorder.audioStream, (transcription) {
      //   final now = DateTime.now();
      //   final durationSinceLast = now.difference(_lastTimestamp).inMilliseconds / 1000.0;
      //
      //   if (durationSinceLast <= 0.5) {
      //     _query += ' ' + transcription;
      //   } else {
      //     if (_query.isNotEmpty && !_isProcessing) { // Added check for processing state
      //       _sendQueryToGroq(_query);
      //     }
      //     _query = transcription;
      //   }
      //
      //   _lastTimestamp = now;
      //
      //   setState(() {
      //     _currentTranscript = _query;
      //   });
      // });
    await _recorder.start();
  }

  void _processAudioChunk(Uint8List audio) {

    //Each Uint8List is being added to a buffer named _audioChunks
    _audioChunks.add(audio);
    int _overlapSize = _chunkSize ~/ 2;
    //Need to calculate when that buffer has more data than chunkSize
    int totalBytes = _audioChunks.fold(0, (sum, chunk) => sum + chunk.length);

    while (_audioChunks.isNotEmpty && totalBytes >= _chunkSize) {

      Uint8List chunk = _extractChunk();
      if (_detectVoiceActivity(chunk)) {

        _chunkQueue.add(chunk);
      } else {
        print("No speech detected in this chunk, skipping STT API call.");
      }
      totalBytes -= (_chunkSize - _overlapSize);
    }

    _processQueue();
  }

  void _processQueue() {
    if (_isProcessingChunk || _chunkQueue.isEmpty) return;

    _isProcessingChunk = true;

    setState(() {});


    Timer(Duration(milliseconds: 50), () {
      print("Timer fired. Queue empty: ${_chunkQueue.isEmpty}");
      if (_chunkQueue.isNotEmpty) {
        Uint8List chunk = _chunkQueue.removeFirst();
        print("Sending chunk to STT");
        sendToSTT(chunk);
      }
      _isProcessingChunk = false;
      setState(() {});
      print("Recursively calling _processQueue");
      _processQueue(); // Process next chunk if available
    });
  }

  Uint8List _extractChunk() {
    List<int> chunkData = [];

    while (chunkData.length < _chunkSize && _audioChunks.isNotEmpty) {

      Uint8List currentChunk = _audioChunks.first;
      int remainingBytes = _chunkSize - chunkData.length;

      if (currentChunk.length <= remainingBytes) {
        chunkData.addAll(currentChunk);
        _audioChunks.removeAt(0);
      } else {
        chunkData.addAll(currentChunk.sublist(0, remainingBytes));
        _audioChunks[0] = currentChunk.sublist(remainingBytes);
      }
    }

    return Uint8List.fromList(chunkData);
  }

  Future<String> sendToSTT(Uint8List audioData) async {

    if (audioData.isEmpty) {
      throw Exception('Audio data is empty');
    }

    // DateTime now = DateTime.now();
    // if (now.difference(_lastApiCallTime).inMilliseconds < 200) {
    //   // If less than 200ms since last API call, wait
    //   await Future.delayed(Duration(milliseconds: 200) - now.difference(_lastApiCallTime));
    // }


    // Create WAV file from PCM data
    List<int> wavFile = _createWavFile(audioData.toList());

    // Save the WAV file and get the file path
    // String wavFilePath = await _saveWavFile(wavFile);


    var url = Uri.parse('https://api.sarvam.ai/speech-to-text');

    var request = http.MultipartRequest('POST', url);

    // Add headers
    request.headers['api-subscription-key'] = 'd6f07450-51e3-4db9-ad97-db7746aa0d70';

    // Add body fields
    // final mimeTypeData = lookupMimeType(wavFile) ?? 'audio/wav';
    // request.files.add(await http.MultipartFile.fromBytes('file', wavFile, contentType: MediaType.parse(mimeTypeData)));


    request.files.add(http.MultipartFile.fromBytes(
        'file',
        wavFile,
        filename: 'audio.wav',
        contentType: MediaType('audio', 'wav')
    ));
    request.fields['language_code'] = 'hi-IN';
    request.fields['model'] = 'saarika:v1';

    var response = await request.send();
    _lastApiCallTime = DateTime.now();
    setState(() {});
    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      // Parse the JSON response and extract the transcript
      var jsonResponse = json.decode(responseBody);
      _currentTranscript += jsonResponse['transcript'] + ' ';
      setState(() {});
      return jsonResponse['transcript'];
    } else {
      var errorBody = await response.stream.bytesToString();
      dev.log("Error Code: ${response.statusCode}");
      dev.log("Error Body: $errorBody");
      throw Exception('Failed to convert speech to text');
    }
  }

  bool _detectVoiceActivity(Uint8List audioData) {

    // Convert to 16-bit PCM samples
    List<int> samples = [];
    for (int i = 0; i < audioData.length; i += 2) {
      int sample = (audioData[i+1] << 8) | audioData[i];
      samples.add(sample);
    }

    // Calculate RMS energy
    double sumOfSquares = 0;
    for (int sample in samples) {
      sumOfSquares += sample * sample;
    }
    double rmsEnergy = sqrt(sumOfSquares / samples.length);

    dev.log('RMS : ${rmsEnergy}');

    // You may need to adjust this threshold based on your specific use case
    double threshold = 44000; // Adjust this value as needed

    return rmsEnergy > threshold;
  }

  List<int> _createWavFile(List<int> pcmData) {

    if (pcmData.isEmpty) {
      throw Exception('PCM data is empty');
    }

    final int fileSize = 36 + pcmData.length;
    final int sampleRate = 16000;
    final int byteRate = sampleRate * 2;

    List<int> wavHeader = [
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      fileSize & 0xFF, (fileSize >> 8) & 0xFF, (fileSize >> 16) & 0xFF, (fileSize >> 24) & 0xFF,
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      0x66, 0x6D, 0x74, 0x20, // "fmt "
      16, 0, 0, 0, // Size of fmt chunk
      1, 0, // Audio format (PCM)
      1, 0, // Num channels (Mono)
      sampleRate & 0xFF, (sampleRate >> 8) & 0xFF, (sampleRate >> 16) & 0xFF, (sampleRate >> 24) & 0xFF,
      byteRate & 0xFF, (byteRate >> 8) & 0xFF, (byteRate >> 16) & 0xFF, (byteRate >> 24) & 0xFF,
      2, 0, // Block align
      16, 0, // Bits per sample
      0x64, 0x61, 0x74, 0x61, // "data"
      pcmData.length & 0xFF, (pcmData.length >> 8) & 0xFF, (pcmData.length >> 16) & 0xFF, (pcmData.length >> 24) & 0xFF,
    ];

    return wavHeader + pcmData;
  }

  Future<String> _saveWavFile(List<int> wavFile) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String wavPath = '${appDocDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    await File(wavPath).writeAsBytes(wavFile);
    print('Saved WAV file: $wavPath');
    return wavPath;
  }

  void _sendQueryToGroq(String query) async {
    List<String> buffer = [];
    String currentSentence = '';

    await _apiService.sendQueryToGroq(query, (token) async {
      currentSentence += token;
      if (token.contains('.') || token.contains('?') || token.contains('!')) {
        buffer.add(currentSentence.trim());
        currentSentence = '';

        if (buffer.isNotEmpty) {
          String textToConvert = buffer.join(' ');
          buffer.clear();
          await _apiService.convertTextToSpeech(textToConvert, (audioStream) {
            // // Play the audio stream
            // int random = DateTime.now().millisecondsSinceEpoch;
            // final path = await saveDataToFile("$random.wav", audioStream.data);
            // await player.play(DeviceFileSource(path));

            _playAudio(audioStream);
          });
        }
      }
    });

    // Convert any remaining text in the buffer
    if (currentSentence.isNotEmpty) {
      buffer.add(currentSentence.trim());
    }
    if (buffer.isNotEmpty) {
      String textToConvert = buffer.join(' ');
      await _apiService.convertTextToSpeech(textToConvert, (audioStream) {
        // Play the audio stream
        // int random = DateTime.now().millisecondsSinceEpoch;
        // final path = await saveDataToFile("$random.wav", audioStream.data);
        // await player.play(DeviceFileSource(path));
        _playAudio(audioStream);

      });
    }
  }

  Future<void> _playAudio(Uint8List audioData) async {
    try {
      final audioBuffer = Uint8List.fromList(audioData);

      // Create an AudioSource from the buffer
      final audioSource = AudioSource.uri(
        Uri.dataFromBytes(audioBuffer, mimeType: 'audio/wav'),
      );

      // Set the audio source and play
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  void _stopListening() {
    setState(() {
      _isRecording = false;
    });
    _recorder.stop();
    _apiService.stopTranscription();
    if (_query.isNotEmpty && !_isProcessing) { // Added check for processing state
      // _sendQueryToGroq(_query);
    }
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
              onPressed: _isRecording ? null : _startListening,
              child: Text('Start Listening'),
            ),
            ElevatedButton(
              onPressed: _isRecording ? _stopListening : null,
              child: Text('Stop Listening'),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Transcription: $_currentTranscript'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyCustomSource extends StreamAudioSource {
  final Uint8List _buffer;

  MyCustomSource(this._buffer);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}