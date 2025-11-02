import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class DocumentScannerPage extends StatefulWidget {
  const DocumentScannerPage({Key? key}) : super(key: key);

  @override
  State<DocumentScannerPage> createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage> {
  File? _imageFile;
  bool _isUploading = false;
  String? _extractedData;
  String? _currentImageUrl;
  final ImagePicker _picker = ImagePicker();

  // Chat related variables
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendingMessage = false;

  // Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _selectedLanguage = 'en-IN';

  // Text to speech
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    _flutterTts = FlutterTts();

    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
      });
      print("TTS Error: $msg");
    });

    // Set initial language
    await _setTtsLanguage(_selectedLanguage);
  }

  Future<void> _setTtsLanguage(String languageCode) async {
    // Map Flutter locale codes to TTS language codes
    final ttsLanguageMap = {
      'en-IN': 'en-IN',
      'hi-IN': 'hi-IN',
      'ta-IN': 'ta-IN',
      'te-IN': 'te-IN',
      'mr-IN': 'mr-IN',
      'bn-IN': 'bn-IN',
      'gu-IN': 'gu-IN',
      'kn-IN': 'kn-IN',
      'ml-IN': 'ml-IN',
      'pa-IN': 'pa-IN',
      'or-IN': 'or-IN',
      'as-IN': 'as-IN',
    };

    String ttsLanguage = ttsLanguageMap[languageCode] ?? 'en-IN';

    try {
      await _flutterTts.setLanguage(ttsLanguage);
      print("TTS language set to: $ttsLanguage");
    } catch (e) {
      print("Error setting TTS language: $e");
      // Fallback to English if language not available
      await _flutterTts.setLanguage('en-IN');
    }
  }

  Future<void> _speakText(String text) async {
    if (text.isEmpty) return;

    try {
      // Stop any ongoing speech
      await _flutterTts.stop();

      // Set language before speaking
      await _setTtsLanguage(_selectedLanguage);

      // Speak the text
      await _flutterTts.speak(text);
    } catch (e) {
      print("Error speaking text: $e");
      _showError('Error playing audio: $e');
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _extractedData = null;
          _currentImageUrl = null;
          _messages.clear();
        });
        // Stop any ongoing speech when new image is picked
        await _stopSpeaking();
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _uploadAndProcess() async {
    if (_imageFile == null) return;

    setState(() {
      _isUploading = true;
      _extractedData = null;
    });

    try {
      final fileName = 'documents/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      final uploadTask = await storageRef.putFile(_imageFile!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('Image uploaded successfully: $downloadUrl');

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('analyzeDocument');

      final result = await callable.call({
        'imageUrl': downloadUrl,
      });

      setState(() {
        _extractedData = result.data['extractedText'] ?? 'No data extracted';
        _currentImageUrl = downloadUrl;
        _isUploading = false;
      });

      final initialMessage = "I've analyzed your document. Feel free to ask me any questions about it!";

      _messages.add(ChatMessage(
        text: initialMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ));

      // Automatically speak the AI's initial message
      await _speakText(initialMessage);

    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showError('Error processing document: $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _currentImageUrl == null) return;

    // Stop any ongoing speech
    await _stopSpeaking();

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isSendingMessage = true;
      _chatController.clear();
    });

    _scrollToBottom();

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('chatWithDocument');

      final result = await callable.call({
        'imageUrl': _currentImageUrl,
        'extractedText': _extractedData,
        'userMessage': text,
        'language': _selectedLanguage,
      });

      final aiResponseText = result.data['response'] ?? 'Sorry, I could not process that.';

      final aiMessage = ChatMessage(
        text: aiResponseText,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isSendingMessage = false;
      });

      _scrollToBottom();

      // Automatically speak the AI's response
      await _speakText(aiResponseText);

    } catch (e) {
      setState(() {
        _isSendingMessage = false;
      });
      _showError('Error sending message: $e');
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        _showError('Speech recognition error: ${error.errorMsg}');
        setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _chatController.text = result.recognizedWords;
          });
        },
        localeId: _selectedLanguage,
      );
    } else {
      _showError('Speech recognition not available');
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => LanguageSelector(
        selectedLanguage: _selectedLanguage,
        onLanguageSelected: (language) async {
          setState(() => _selectedLanguage = language);
          await _setTtsLanguage(language);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DastaavezAi - Document Scanner'),
        actions: [
          if (_extractedData != null)
            IconButton(
              icon: const Icon(Icons.language),
              onPressed: _showLanguageSelector,
              tooltip: 'Select Language',
            ),
          if (_extractedData != null)
            IconButton(
              icon: Icon(_isSpeaking ? Icons.volume_off : Icons.volume_up),
              onPressed: _isSpeaking ? _stopSpeaking : null,
              tooltip: _isSpeaking ? 'Stop Speaking' : 'Audio Playing',
            ),
        ],
      ),
      body: _extractedData == null
          ? _buildUploadSection()
          : _buildAnalyzedView(),
    );
  }

  Widget _buildUploadSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_imageFile != null)
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_imageFile!, fit: BoxFit.cover),
              ),
            )
          else
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('No image selected'),
              ),
            ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: _imageFile == null || _isUploading
                ? null
                : _uploadAndProcess,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.all(16),
            ),
            child: _isUploading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Text(
              'Analyze Document with AI',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzedView() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_imageFile != null)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    ),
                  ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _imageFile = null;
                            _extractedData = null;
                            _currentImageUrl = null;
                            _messages.clear();
                          });
                          _stopSpeaking();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('New Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Extracted Information:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        _extractedData!,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Use the chat below to ask questions about this document',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Divider(height: 1, thickness: 2, color: Colors.grey.shade300),

        Expanded(
          flex: 5,
          child: Container(
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade700,
                  child: Row(
                    children: [
                      const Icon(Icons.smart_toy, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'AI Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_isSpeaking)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.volume_up, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Speaking...',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getLanguageName(_selectedLanguage),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: _messages[index]);
                    },
                  ),
                ),

                if (_isSendingMessage)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('AI is thinking...'),
                      ],
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: 'Ask a question...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isListening ? _stopListening : _startListening,
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : Colors.blue.shade700,
                          ),
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: _isListening
                                ? Colors.red.shade50
                                : Colors.blue.shade50,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _sendMessage(_chatController.text),
                          icon: const Icon(Icons.send),
                          color: Colors.blue.shade700,
                          iconSize: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getLanguageName(String code) {
    const languages = {
      'en-IN': 'English',
      'hi-IN': 'हिंदी',
      'ta-IN': 'தமிழ்',
      'te-IN': 'తెలుగు',
      'mr-IN': 'मराठी',
      'bn-IN': 'বাংলা',
      'gu-IN': 'ગુજરાતી',
      'kn-IN': 'ಕನ್ನಡ',
      'ml-IN': 'മലയാളം',
      'pa-IN': 'ਪੰਜਾਬੀ',
      'or-IN': 'ଓଡ଼ିଆ',
      'as-IN': 'অসমীয়া',
    };
    return languages[code] ?? 'English';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
        message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.blue.shade700,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
              radius: 16,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue.shade700 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.green.shade700,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
              radius: 16,
            ),
          ],
        ],
      ),
    );
  }
}

class LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final Function(String) onLanguageSelected;

  const LanguageSelector({
    Key? key,
    required this.selectedLanguage,
    required this.onLanguageSelected,
  }) : super(key: key);

  static const Map<String, String> languages = {
    'en-IN': 'English',
    'hi-IN': 'हिंदी (Hindi)',
    'ta-IN': 'தமிழ் (Tamil)',
    'te-IN': 'తెలుగు (Telugu)',
    'mr-IN': 'मराठी (Marathi)',
    'bn-IN': 'বাংলা (Bengali)',
    'gu-IN': 'ગુજરાતી (Gujarati)',
    'kn-IN': 'ಕನ್ನಡ (Kannada)',
    'ml-IN': 'മലയാളം (Malayalam)',
    'pa-IN': 'ਪੰਜਾਬੀ (Punjabi)',
    'or-IN': 'ଓଡ଼ିଆ (Odia)',
    'as-IN': 'অসমীয়া (Assamese)',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Language / भाषा चुनें',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: languages.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  leading: Radio<String>(
                    value: entry.key,
                    groupValue: selectedLanguage,
                    onChanged: (value) {
                      if (value != null) {
                        onLanguageSelected(value);
                      }
                    },
                  ),
                  onTap: () => onLanguageSelected(entry.key),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
