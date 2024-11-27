import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const MyApp());
}

// mon application flutter
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appart\'hotel Marianne - Assit IA',
      theme: ThemeData.dark(), // Couleur de thème global (modifiable ici)
      home: const HomePage(),
    );
  }
}

//! page home version 2.0
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  // ! code STYLE de page HOME
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appart\'hôtel MARIANNE - Home'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2A2A72), // Couleur de l'AppBar
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2A2A72),
                Color(0xFF009FFD)
              ], // Gradient de fond
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20), // Ajout du padding horizontal
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo ajouté ici
                Image.asset(
                  'assets/images/logo.jpg', // Chemin du logo
                  height: 100, // Hauteur du logo
                  fit: BoxFit.contain, // Ajustement de l'image
                ),
                const SizedBox(
                    height: 20), // Espacement entre le logo et le texte
                const Text(
                  'Bonjour, je suis Maria votre assistante IA !',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Couleur du texte principal
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChatbotTrajetsPage()),
                    );
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text("Chatbot : Trajets"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A72), // Couleur bouton
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChatbotHotelsPage()),
                    );
                  },
                  icon: const Icon(Icons.hotel),
                  label: const Text("Chatbot : Infos Appart'hôtel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A72), // Couleur bouton
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChatbotGeneralPage()),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text("Chatbot : Général"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A72), // Couleur bouton
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// classe pour moduler les fonctionnalités écoute + parler (on pourrait centraliser les interactions API dans cette classe à voir!!!!!!)
class ChatbotUtilities {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;

  ChatbotUtilities() {
    _flutterTts.setLanguage("fr-FR");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
  }

  Future<String> startListening(Function(String) onTextRecognized) async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Statut : $status'),
      onError: (error) => print('Erreur : $error'),
    );

    if (available) {
      _isListening = true;
      String recognizedText = '';
      _speech.listen(onResult: (result) {
        recognizedText = result.recognizedWords;
        onTextRecognized(recognizedText);
      });
      return recognizedText;
    } else {
      _isListening = false;
      return "La reconnaissance vocale n'est pas disponible.";
    }
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  bool get isListening => _isListening;
}

// Fonction pour capitaliser la première lettre du texte RECONNU user prompt (OPTION SECONDAIRE)
String capitalize(String text) {
  if (text.isEmpty) return text; // Vérifie si le texte est vide
  return text[0].toUpperCase() +
      text.substring(1); // Met la première lettre en majuscule
}

//! page trajet version 2.0
class ChatbotTrajetsPage extends StatefulWidget {
  const ChatbotTrajetsPage({Key? key}) : super(key: key);

  @override
  _ChatbotTrajetsPageState createState() => _ChatbotTrajetsPageState();
}

class _ChatbotTrajetsPageState extends State<ChatbotTrajetsPage> {
  final ChatbotUtilities utils = ChatbotUtilities();
  String _aiResponse = '';
  String? _qrCodeData;
  bool _isProcessing = false; // Indicateur de traitement
  bool _isListening = false; // Indicateur d'écoute
  String _recognizedText = ''; // Texte reconnu pendant l'écoute

  Future<void> handleQuestion(String question) async {
    setState(() {
      _isProcessing = true; // Début du traitement
    });

    try {
      if (question.toLowerCase().contains("aller de") &&
          question.toLowerCase().contains("à")) {
        final RegExp regex =
            RegExp(r'aller de (.*?) à (.*)', caseSensitive: false);
        final match = regex.firstMatch(question);

        if (match != null) {
          final origin = match.group(1)!.trim();
          final destination = match.group(2)!.trim();
          final googleMapsLink =
              "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination";

          setState(() {
            _qrCodeData = googleMapsLink;
            _aiResponse =
                "Voici votre itinéraire entre $origin et $destination.";
            _isProcessing = false; // Fin du traitement réussi
          });

          await utils.speak(_aiResponse);
          return; // Fin du traitement
        }
      }

      //! Si aucune correspondance n'est trouvée
      setState(() {
        _aiResponse =
            "Je n'ai pas compris votre question. Essayez de dire : 'aller de [lieu] à [lieu]'.";
        utils.speak(_aiResponse);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _aiResponse = "Une erreur est survenue pendant le traitement.";
        _isProcessing = false;
      });
    }
  }

  void startListening() async {
    setState(() {
      _isListening = true; // Début de l'écoute
      _recognizedText = ''; // Réinitialiser le texte reconnu
    });

    await utils.startListening((text) {
      setState(() {
        _recognizedText = text; // Mise à jour du texte reconnu en temps réel
      });
    });
  }

  void stopListening() async {
    utils.stopListening();
    setState(() {
      _isListening = false; // Fin de l'écoute
    });

    // Traiter la question après avoir arrêté l'écoute
    if (_recognizedText.isNotEmpty) {
      await handleQuestion(_recognizedText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot : Trajets"),
        backgroundColor: const Color(0xFF2A2A72),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isProcessing)
              const LinearProgressIndicator(), // Indicateur de traitement
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade800,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        // ! canevas texte reconnu + rep IA
                        children: [
                          const Text(
                            "Texte Reconnu :",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            capitalize(_recognizedText),
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Réponse IA :",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _aiResponse,
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_qrCodeData != null)
                      Center(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(20),
                          child: QrImageView(data: _qrCodeData!, size: 200.0),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.grey), // Séparation visuelle
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isListening ? stopListening : startListening,
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: _isListening
                            ? const Color.fromARGB(255, 255, 255, 255)
                            : null,
                      ),
                      label: Text(_isListening ? "Stop" : "Écouter"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        backgroundColor:
                            _isListening ? Colors.red : const Color(0xFF2A2A72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//! page hôtel version 2.0
//! page hôtel version 2.1 - Ajout de la gestion des réservations
//! page hôtel version 2.2 - Gestion des réservations via OpenAI
class ChatbotHotelsPage extends StatefulWidget {
  const ChatbotHotelsPage({Key? key}) : super(key: key);

  @override
  _ChatbotHotelsPageState createState() => _ChatbotHotelsPageState();
}
class _ChatbotHotelsPageState extends State<ChatbotHotelsPage> {
  final ChatbotUtilities utils = ChatbotUtilities();
  String _aiResponse = '';
  bool _isProcessing = false; // Indicateur de traitement
  bool _isListening = false; // Indique si le bot est en mode écoute
  String _recognizedText = ''; // Texte reconnu pendant l'écoute
  final String _cloudbedsApiKey =
      ''; // Remplacez par votre vraie clé API
  final String _openAiApiKey =
      ''; // Remplacez par votre clé OpenAI

  Future<void> handleQuestion(String question) async {
    setState(() {
      _isProcessing = true; // Début du traitement
      _aiResponse = "Traitement en cours...";
    });

    if (question.toLowerCase().contains("hôtel") || question.toLowerCase().contains("numéro de téléphone") || question.toLowerCase().contains("adresse")) {
      await _fetchHotelDetails(question);
    } else if (question.toLowerCase().contains("réservation") || question.toLowerCase().contains("réservé")) {
      await _fetchReservations(question);
    } else {
      setState(() {
        _aiResponse = "Je ne comprends pas votre demande. Essayez avec des mot-clés comme [Hôtel] ou [Réservation].";
        _isProcessing = false; // Fin du traitement
      });
    }

    await utils.speak(_aiResponse);
  }

  Future<void> _fetchHotelDetails(String question) async {
    final url = 'https://api.cloudbeds.com/api/v1.1/getHotelDetails';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_cloudbedsApiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _aiResponse = _analyzeHotelData(data, question);
          _isProcessing = false; // Fin du traitement
        });
      } else {
        setState(() {
          _aiResponse = "Erreur lors de la récupération des détails.";
          _isProcessing = false; // Fin du traitement
        });
      }
    } catch (e) {
      setState(() {
        _aiResponse = "Erreur de connexion : ${e.toString()}";
        _isProcessing = false; // Fin du traitement
      });
    }
  }

  Future<void> _fetchReservations(String question) async {
    final url = 'https://api.cloudbeds.com/api/v1.2/getReservations';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_cloudbedsApiKey'},
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        print(data);

        // Limiter les réservations à 12
        final limitedData = {
          "success": data["success"],
          "data": (data["data"] as List).take(12).toList(),
        };

        // Envoyer les 12 premières réservations pour analyse
        await _analyzeReservationsWithOpenAI(limitedData, question);
      } else {
        setState(() {
          _aiResponse = "Erreur lors de la récupération des réservations.";
          _isProcessing = false; // Fin du traitement
        });
      }
    } catch (e) {
      setState(() {
        _aiResponse = "Erreur de connexion : ${e.toString()}";
        _isProcessing = false; // Fin du traitement
      });
    }
  }

  Future<void> _analyzeReservationsWithOpenAI(
      Map<String, dynamic> data, String question) async {
    final String apiUrl = 'https://api.openai.com/v1/chat/completions';
    final String jsonString = jsonEncode(data['data']);
    final String prompt = '''
Voici les données des réservations sous forme de JSON :
$jsonString

Question : $question

Répondez de manière concise et en français en utilisant les informations des réservations fournies ci-dessus.
''';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $_openAiApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'Tu es un assistant qui analyse des données JSON.'
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        // Décoder la réponse d'OpenAI
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        setState(() {
          _aiResponse = data['choices'][0]['message']['content'];
          _isProcessing = false; // Fin du traitement
        });
      } else {
        setState(() {
          _aiResponse = "Erreur lors de l'interrogation de ChatGPT.";
          _isProcessing = false; // Fin du traitement
        });
      }
    } catch (e) {
      setState(() {
        _aiResponse = "Erreur de connexion avec OpenAI : ${e.toString()}";
        _isProcessing = false; // Fin du traitement
      });
    }
  }

  String _analyzeHotelData(Map<String, dynamic> data, String question) {
    final hotelData = data['data'];

    if (question.toLowerCase().contains("nom")) {
      return "Nom de l'hôtel : ${hotelData['propertyName']}";
    } else if (question.toLowerCase().contains("adresse")) {
      final address = hotelData['propertyAddress'];
      return "Adresse : ${address['propertyAddress1']}, ${address['propertyCity']}, ${address['propertyZip']}, ${address['propertyCountry']}";
    } else if (question.toLowerCase().contains("contact")) {
      return "Téléphone : \n${hotelData['propertyPhone']},\nEmail : \n${hotelData['propertyEmail']}";
    } else if (question.toLowerCase().contains("description")) {
      return "Description : ${hotelData['propertyDescription']}";
    } else if (question.toLowerCase().contains("équipements")) {
      return "Équipements : ${hotelData['propertyAmenities'].join(', ')}";
    }

    return "Je n'ai pas trouvé d'information correspondant à votre demande.";
  }

  void startListening() async {
    setState(() {
      _isListening = true; // Commence l'écoute
      _recognizedText = ''; // Réinitialiser le texte reconnu
    });

    await utils.startListening((text) {
      setState(() {
        _recognizedText = text; // Mettre à jour le texte reconnu en temps réel
      });
    });
  }

  void stopListening() async {
    utils.stopListening();
    setState(() {
      _isListening = false; // Fin de l'écoute
    });

    if (_recognizedText.isNotEmpty) {
      await handleQuestion(_recognizedText); // Traiter la question
    }
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController textController =
        TextEditingController(); // Contrôleur pour gérer le champ texte

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot : Hôtels et Réservations"),
        backgroundColor: const Color(0xFF2A2A72),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isProcessing)
              const LinearProgressIndicator(), // Indicateur de traitement
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade800,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment
                            .stretch, // Étend les messages horizontalement
                        children: [
                          // Texte reconnu (à droite, utilisateur)
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.end, // Aligne à droite
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Texte Reconnu :",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: 5), // Espacement léger
                                      Text(
                                        capitalize(_recognizedText),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                              height: 20), // Espacement entre les messages

                          // Réponse IA (à gauche)
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.start, // Aligne à gauche
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Réponse IA :",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: 5), // Espacement léger
                                      Text(
                                        _aiResponse,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController, // Lier au contrôleur
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _recognizedText =
                                value; // Enregistrer le texte saisi
                          });
                          handleQuestion(value); // Lancer le traitement
                          textController
                              .clear(); // Réinitialiser le champ après envoi
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "Posez votre question ici...",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            if (textController.text.isNotEmpty) {
                              setState(() {
                                _recognizedText =
                                    textController.text; // Enregistrer le texte
                              });
                              handleQuestion(
                                  _recognizedText); // Lancer le traitement
                              textController
                                  .clear(); // Réinitialiser après envoi
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isListening ? stopListening : startListening,
                    icon: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: _isListening ? Colors.white : null,
                    ),
                    label: Text(_isListening ? "Stop" : "Écouter"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      backgroundColor:
                          _isListening ? Colors.red : const Color(0xFF2A2A72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//! page generale version 2.0
//! page générale version 2.1
//! page generale version 2.1 avec champ texte
//! page generale version 2.2 avec icônes ajoutées
class ChatbotGeneralPage extends StatefulWidget {
  const ChatbotGeneralPage({Key? key}) : super(key: key);

  @override
  _ChatbotGeneralPageState createState() => _ChatbotGeneralPageState();
}

class _ChatbotGeneralPageState extends State<ChatbotGeneralPage> {
  final ChatbotUtilities utils = ChatbotUtilities();
  String _aiResponse = ''; // Réponse générée par IA
  String _recognizedText = ''; // Texte reconnu par reconnaissance vocale
  String? _qrCodeData; // Lien QR Code (si applicable)
  bool _isProcessing = false; // Indicateur de traitement
  bool _isListening = false; // Indicateur pour vérifier si STT est actif
  final String _cloudbedsApiKey = '';
  final String _openAiApiKey = '';

  Future<void> handleQuestion(String question) async {
    setState(() {
      _isProcessing = true;
      _aiResponse = "Traitement en cours..."; // Message temporaire
      _qrCodeData = null; // Réinitialise le QR code
    });

    if (question.toLowerCase().contains("aller de") &&
        question.toLowerCase().contains("à")) {
      await handleTrajetQuestion(question);
    } else if (question.toLowerCase().contains("hôtel") ||
        question.toLowerCase().contains("réservation")) {
      await _fetchHotelDetails(question);
    } else {
      await handleGeneralQuestion(question);
    }

    setState(() {
      _isProcessing = false; // Fin du traitement
    });

    if (!_isListening) {
      await utils.speak(
          _aiResponse); // Lire la réponse uniquement si l'écoute est terminée
    }
  }

  Future<void> handleTrajetQuestion(String question) async {
    final RegExp regex = RegExp(r'aller de (.*?) à (.*)', caseSensitive: false);
    final match = regex.firstMatch(question);

    if (match != null) {
      final origin = match.group(1)!.trim();
      final destination = match.group(2)!.trim();
      final googleMapsLink =
          "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination";

      setState(() {
        _qrCodeData = googleMapsLink;
        _aiResponse = "Voici votre itinéraire entre $origin et $destination.";
      });
    } else {
      setState(() {
        _aiResponse =
            "Je n'ai pas bien saisi votre demande, veuillez réessayer.";
      });
    }
  }

  Future<void> _fetchHotelDetails(String question) async {
    final url = 'https://api.cloudbeds.com/api/v1.1/getHotelDetails';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_cloudbedsApiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _aiResponse = _analyzeHotelData(data, question);
        });
      } else {
        setState(() {
          _aiResponse = "Erreur lors de la récupération des détails.";
        });
      }
    } catch (e) {
      setState(() {
        _aiResponse = "Erreur de connexion : ${e.toString()}";
      });
    }
  }

  Future<void> handleGeneralQuestion(String question) async {
    final url = 'https://api.openai.com/v1/chat/completions';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_openAiApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Tu es un assistant intelligent qui répond aux questions d\'ordre général, aux informations de l\'hôtel et aux réservations.'
            },
            {'role': 'user', 'content': question},
          ],
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);

        setState(() {
          _aiResponse = data['choices'][0]['message']['content'].toString();
        });
      } else {
        setState(() {
          _aiResponse = "Erreur lors de la génération de la réponse.";
        });
      }
    } catch (e) {
      setState(() {
        _aiResponse = "Erreur de connexion : ${e.toString()}";
      });
    }
  }

  String _analyzeHotelData(Map<String, dynamic> data, String question) {
    final hotelData = data['data'];

    if (question.toLowerCase().contains("nom")) {
      return "Nom de l'hôtel : ${hotelData['propertyName']}";
    } else if (question.toLowerCase().contains("adresse")) {
      final address = hotelData['propertyAddress'];
      return "Adresse : ${address['propertyAddress1']}, ${address['propertyCity']}, ${address['propertyZip']}, ${address['propertyCountry']}";
    } else if (question.toLowerCase().contains("contact")) {
      return "Téléphone : ${hotelData['propertyPhone']}, Email : ${hotelData['propertyEmail']}";
    } else if (question.toLowerCase().contains("description")) {
      return "Description : ${hotelData['propertyDescription']}";
    }

    return "Je n'ai pas trouvé d'information correspondant à votre demande.";
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _recognizedText = ''; // Réinitialise le texte reconnu
    });
    await utils.startListening((text) {
      setState(() {
        _recognizedText = text;
      });
    });
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
    });
    utils.stopListening();
    handleQuestion(
        _recognizedText); // Traite la question après avoir stoppé l'écoute
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController textController =
        TextEditingController(); // Contrôleur pour le champ de texte

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot : Général"),
        backgroundColor: const Color(0xFF2A2A72),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isProcessing) const LinearProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade800,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Texte Reconnu :",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            capitalize(_recognizedText),
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Réponse IA :",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _aiResponse,
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_qrCodeData != null)
                      Center(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(20),
                          child: QrImageView(data: _qrCodeData!, size: 200.0),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          textController, // Lier le TextField au contrôleur
                      onSubmitted: (value) {
                        setState(() {
                          _recognizedText = value; // Assigner directement
                        });
                        handleQuestion(value);
                        textController
                            .clear(); // Réinitialiser le champ après soumission
                      },
                      decoration: InputDecoration(
                        hintText: "Posez votre question ici...",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            if (textController.text.isNotEmpty) {
                              setState(() {
                                _recognizedText = textController.text;
                              });
                              handleQuestion(
                                  _recognizedText); // Traiter la question
                              textController.clear(); // Réinitialiser le champ
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isListening ? _stopListening : _startListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isListening ? Colors.red : const Color(0xFF2A2A72),
                    ),
                    icon: Icon(_isListening ? Icons.stop : Icons.mic),
                    label: Text(_isListening ? "Stop" : "Écouter"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
