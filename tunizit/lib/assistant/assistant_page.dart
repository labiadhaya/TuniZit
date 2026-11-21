import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import '../theme/app_theme.dart';

const Color olive = AppColors.leaf;
const Color forest = AppColors.forest;
const Color ivory = AppColors.bg;
const Color sage = AppColors.tileBorder;
// Backend URL
const String apiUrl = 'http://localhost:5000/api/assistant/chat';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  final SpeechToText _speech = SpeechToText();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isStartingSpeech = false;
  String _speechLocaleId = 'fr_FR';

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Bonjour ! 🌿\n\nJe suis ZITIA, votre assistant Tunizit.\n\nJe suis là pour vous accompagner dans la culture de vos oliviers : entretien, irrigation, maladies, taille, choix des variétés et informations liées à la zakat.\n\nComment puis-je vous aider aujourd'hui ?",
      isUser: false,
    ),
  ];

  final List<String> _suggestions = [
    "Comment entretenir mes oliviers ?",
    "Quand dois-je irriguer ?",
    "Comment reconnaître l'œil de paon ?",
    "Quelle variété choisir à Sfax ?",
    "Quelles sont les activités de cette saison ?",
  ];
  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          setState(() {
            if (status == 'listening') {
              _isListening = true;
            } else if (status == 'done' || status == 'notListening') {
              _isListening = false;
            }
          });
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');

          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
      );

      if (_speechEnabled) {
        try {
          final locales = await _speech.locales();
          final arabicLocales = locales
              .where(
                (locale) => locale.localeId.toLowerCase().startsWith('ar'),
              )
              .toList();

          if (arabicLocales.isNotEmpty) {
            _speechLocaleId = arabicLocales
                .firstWhere(
                  (locale) =>
                      locale.localeId.toLowerCase().replaceAll('_', '-') ==
                      'ar-tn',
                  orElse: () => arabicLocales.first,
                )
                .localeId;

            debugPrint('Selected speech language: $_speechLocaleId');
          } else {
            debugPrint('No Arabic speech locale available');
          }
        } catch (e) {
          debugPrint('Speech locale lookup error: $e');
        }
      }
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _speechEnabled = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleListening() async {
    if (!_speechEnabled || _isTyping || _isStartingSpeech) {
      return;
    }

    if (_speech.isListening || _isListening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      return;
    }

    setState(() {
      _isStartingSpeech = true;
    });

    try {
      // Stop any previous recognition session
      await _speech.stop();

      await Future.delayed(const Duration(milliseconds: 300));

      await _speech.listen(
        localeId: _speechLocaleId,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),

        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _controller.text = result.recognizedWords;

            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        },
      );
    } catch (e) {
      debugPrint('Microphone error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isStartingSpeech = false;
          _isListening = _speech.isListening;
        });
      }
    }
  }

  Future<void> _sendMessage([String? suggestion]) async {
    final question = (suggestion ?? _controller.text).trim();

    if (question.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(ChatMessage(text: question, isUser: true));
      _controller.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // Récupération de l'historique précédent.
    final history = _messages
        .skip(1)
        .take(_messages.length - 2)
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'model',
            'text': message.text,
          },
        )
        .toList();

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': question, 'history': history}),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['success'] == true &&
          data['answer'] != null) {
        setState(() {
          _messages.add(
            ChatMessage(text: data['answer'].toString(), isUser: false),
          );
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  data['message']?.toString() ??
                  "Impossible d'obtenir une réponse. Réessayez.",
              isUser: false,
            ),
          );
        });
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text:
                "Le serveur met trop de temps à répondre. Veuillez réessayer.",
            isUser: false,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: "Impossible de contacter le serveur Tunizit. Vérifiez votre connexion et réessayez.",
            isUser: false,
          ),
        );
      });

      debugPrint('Assistant API error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _newConversation() {
    if (_isTyping) return;

    setState(() {
      _messages.clear();

      _messages.add(
        ChatMessage(
          text: "Bonjour ! 🌿\n\nJe suis Zakat & IA, votre assistant Tunizit.\n\nComment puis-je vous aider aujourd'hui ?",
          isUser: false,
        ),
      );
    });

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ivory,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildConversation()),
            _buildDisclaimer(),
            _buildSuggestions(),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  // HEADER

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: sage)),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: olive,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zakat & IA',
                  style: TextStyle(
                    color: forest,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'En ligne • Zakat & conseils oléicoles',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isTyping ? null : _newConversation,
            tooltip: 'Nouvelle conversation',
            icon: const Icon(Icons.refresh_rounded, color: forest),
          ),
        ],
      ),
    );
  }

  // CONVERSATION

  Widget _buildConversation() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 15),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }

        return _buildMessage(_messages[index]);
      },
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: message.isUser ? olive : Colors.white,
          border: message.isUser ? null : Border.all(color: sage),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 3),
            bottomRight: Radius.circular(message.isUser ? 3 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : forest,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ),
    );
  }

  // TYPING INDICATOR

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: sage),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: olive),
            ),
            SizedBox(width: 10),
            Text(
              'Analyse en cours...',
              style: TextStyle(color: forest, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // DISCLAIMER

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 5, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 15, color: olive),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              "Les réponses sont indicatives et ne remplacent pas "
              "l'avis d'un ingénieur agronome sur le terrain.",
              style: TextStyle(
                fontSize: 10,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // QUICK SUGGESTIONS

  Widget _buildSuggestions() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            backgroundColor: Colors.white,
            side: const BorderSide(color: sage),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            label: Text(
              _suggestions[index],
              style: const TextStyle(color: forest, fontSize: 11),
            ),
            onPressed: _isTyping
                ? null
                : () => _sendMessage(_suggestions[index]),
          );
        },
      ),
    );
  }

  // INPUT

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: sage)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Posez votre question à Tunizit...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                filled: true,
                fillColor: ivory,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 7),

          // MICROPHONE BUTTON
          SizedBox(
            height: 49,
            width: 49,
            child: IconButton.filled(
              onPressed: (_isTyping || !_speechEnabled || _isStartingSpeech)
                  ? null
                  : _toggleListening,
              style: IconButton.styleFrom(
                backgroundColor: _isListening ? Colors.red.shade600 : sage,
                foregroundColor: _isListening ? Colors.white : forest,
              ),
              icon: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                size: 23,
              ),
            ),
          ),

          const SizedBox(width: 7),

          // SEND BUTTON
          SizedBox(
            height: 49,
            width: 49,
            child: IconButton.filled(
              onPressed: _isTyping ? null : () => _sendMessage(),
              style: IconButton.styleFrom(
                backgroundColor: olive,
                foregroundColor: Colors.white,
                disabledBackgroundColor: sage,
              ),
              icon: const Icon(Icons.send_rounded, size: 21),
            ),
          ),
        ],
      ),
    );
  }
}
