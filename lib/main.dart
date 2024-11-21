import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Démo chatbot IA - anjoyit CDS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Démo chatbot IA - anjoyit'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  String _recognizedText = 'Appuyez sur le bouton et commencez à parler';
  bool _isListening = false;
  String _aiResponse = '';
  String? _qrCodeData; // QR code data pour les directions Google Maps
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("fr-FR");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);

    // Animation pour l'indicateur visuel
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Statut : $status'),
      onError: (error) => print('Erreur : $error'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });
      });
    } else {
      setState(() =>
          _recognizedText = "La reconnaissance vocale n'est pas disponible.");
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);

    // Appeler l'IA après avoir arrêté l'écoute
    _sendQuestionToAI(_recognizedText);
  }

  Future<void> _sendQuestionToAI(String question) async {
    const String bearerToken =
        '';

    try {
      // Vérifier si la question concerne un trajet
      if (isDirectionsQuestion(question)) {
        final locations = extractLocations(question);
        if (locations != null) {
          final origin = locations['origin']!;
          final destination = locations['destination']!;
          final directionsLink =
              generateGoogleMapsDirectionsLink(origin, destination);

          setState(() {
            _qrCodeData = directionsLink;
            _aiResponse = 'Voici le trajet entre $origin et $destination.';
          });
        } else {
          setState(() {
            _qrCodeData = null;
            _aiResponse = 'Je n’ai pas compris les lieux.';
          });
        }
      } else {
        final response = await http.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': bearerToken,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': [
              {
                'role': 'system',
                'content':
                    'Tu es un assistant intelligent qui répond dans la langue utilisée.'
              },
              {
                'role': 'user',
                'content': question,
              }
            ],
            'max_tokens': 150,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          setState(() {
            _aiResponse = data['choices'][0]['message']['content'].toString();
          });
          _speak(_aiResponse);
        } else {
          setState(() {
            _aiResponse =
                'Erreur : ${response.statusCode} - ${response.reasonPhrase}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _aiResponse = 'Erreur de connexion : ${e.toString()}';
      });
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  // Vérifie si la question concerne un trajet
  bool isDirectionsQuestion(String question) {
    return question.toLowerCase().contains('aller de') &&
        question.toLowerCase().contains('à');
  }

  // Extrait les lieux A et B
  Map<String, String>? extractLocations(String question) {
    final RegExp regex = RegExp(r'aller de (.*?) à (.*)', caseSensitive: false);
    final match = regex.firstMatch(question);

    if (match != null) {
      return {
        'origin': match.group(1)!.trim(),
        'destination': match.group(2)!.trim(),
      };
    }
    return null;
  }

  // Génère un lien Google Maps pour un trajet
  String generateGoogleMapsDirectionsLink(String origin, String destination) {
    final Uri directionsUri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'origin': origin,
        'destination': destination,
      },
    );
    return directionsUri.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Texte Reconnu :',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _recognizedText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      width: _isListening
                          ? 100 + _animationController.value * 20
                          : 100,
                      height: _isListening
                          ? 100 + _animationController.value * 20
                          : 100,
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.blue : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(
                _isListening ? 'Arrêter l\'écoute' : 'Commencer l\'écoute',
              ),
            ),
            const SizedBox(height: 20),
            if (_aiResponse.isNotEmpty)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Réponse de l\'IA :',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _aiResponse,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_qrCodeData != null)
                    QrImageView(
                      data: _qrCodeData!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
