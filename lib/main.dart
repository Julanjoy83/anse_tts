import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo with Speech-to-Text'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Initialize the SpeechToText instance and variables
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _recognizedText = 'Press the button and start speaking';
  bool _isListening = false;
  String _aiResponse = '';

  // Function to start listening
  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });
        // Send the recognized text to OpenAI
        _sendToAI(result.recognizedWords);
      });
    } else {
      setState(() => _recognizedText = "Speech recognition is not available.");
    }
  }

  // Function to stop listening
  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  // Function to send message to OpenAI API and get the response
  Future<void> _sendToAI(String message) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization':
              'Bearer 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', // Remplacez par votre vraie clé API
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // Modèle spécifique
          'messages': [
            {
              'role': 'user',
              'content': message
            } // Message structuré pour le chat
          ],
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _aiResponse = data['choices'][0]['message']['content'].toString();
        });
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        setState(() {
          _aiResponse = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _aiResponse = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Recognized Text:',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              _recognizedText,
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'AI Response:',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              _aiResponse,
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
            ),
          ],
        ),
      ),
    );
  }
}
