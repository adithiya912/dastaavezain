import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class DocumentFillerPage extends StatefulWidget {
  const DocumentFillerPage({Key? key}) : super(key: key);

  @override
  State<DocumentFillerPage> createState() => _DocumentFillerPageState();
}

class _DocumentFillerPageState extends State<DocumentFillerPage> {
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

  // Store filled data
  final Map<String, String> _filledFields = {};

  // NEW: Pictogram feature
  bool _isLoadingPictogram = false;
  String? _currentPictogramExplanation;
  IconData? _currentPictogramIcon;

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

    await _setTtsLanguage(_selectedLanguage);
  }

  Future<void> _setTtsLanguage(String languageCode) async {
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
      await _flutterTts.setLanguage('en-IN');
    }
  }

  Future<void> _speakText(String text) async {
    if (text.isEmpty) return;

    try {
      await _flutterTts.stop();
      await _setTtsLanguage(_selectedLanguage);
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

  // NEW: Request pictogram explanation for current field
  Future<void> _requestPictogramHelp() async {
    if (_currentImageUrl == null) return;

    setState(() {
      _isLoadingPictogram = true;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('generatePictogramHelp');

      final result = await callable.call({
        'imageUrl': _currentImageUrl,
        'extractedText': _extractedData,
        'language': _selectedLanguage,
        'filledFields': _filledFields,
      });

      final explanation = result.data['explanation'] ?? 'Visual help is not available for this field.';
      final iconName = result.data['iconSuggestion'] ?? 'help_outline';

      setState(() {
        _currentPictogramExplanation = explanation;
        _currentPictogramIcon = _getIconFromName(iconName);
        _isLoadingPictogram = false;
      });

      // Show the pictogram dialog
      _showPictogramDialog();

      // Speak the explanation
      await _speakText(explanation);

    } catch (e) {
      setState(() {
        _isLoadingPictogram = false;
      });
      _showError('Error loading visual help: $e');
    }
  }

  IconData _getIconFromName(String iconName) {
    final iconMap = {
      'person': Icons.person,
      'email': Icons.email,
      'phone': Icons.phone,
      'home': Icons.home,
      'location_on': Icons.location_on,
      'calendar_today': Icons.calendar_today,
      'work': Icons.work,
      'badge': Icons.badge,
      'credit_card': Icons.credit_card,
      'description': Icons.description,
      'edit': Icons.edit,
      'message': Icons.message,
      'account_circle': Icons.account_circle,
      'business': Icons.business,
      'school': Icons.school,
      'family_restroom': Icons.family_restroom,
      'male': Icons.male,
      'female': Icons.female,
      'cake': Icons.cake,
      'fingerprint': Icons.fingerprint,
      'medical_services': Icons.medical_services,
      'local_hospital': Icons.local_hospital,
      'help_outline': Icons.help_outline,
    };

    return iconMap[iconName] ?? Icons.help_outline;
  }

  void _showPictogramDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Visual Help',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _currentPictogramIcon ?? Icons.help_outline,
                  size: 80,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _currentPictogramExplanation ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        if (_currentPictogramExplanation != null) {
                          _speakText(_currentPictogramExplanation!);
                        }
                      },
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Read Aloud'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got It'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
          _filledFields.clear();
          _currentPictogramExplanation = null;
          _currentPictogramIcon = null;
        });
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
      final callable = functions.httpsCallable('analyzeDocumentForFilling');

      final result = await callable.call({
        'imageUrl': downloadUrl,
      });

      setState(() {
        _extractedData = result.data['extractedText'] ?? 'No data extracted';
        _currentImageUrl = downloadUrl;
        _isUploading = false;
      });

      final initialMessage = "I've analyzed your document and identified the fields that need to be filled. I'll help you fill them one by one. What information would you like to provide first? Tap the 💡 help icon if you need visual guidance for any field!";

      _messages.add(ChatMessage(
        text: initialMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ));

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
      final callable = functions.httpsCallable('fillDocumentField');

      final result = await callable.call({
        'imageUrl': _currentImageUrl,
        'extractedText': _extractedData,
        'userMessage': text,
        'language': _selectedLanguage,
        'filledFields': _filledFields,
      });

      final aiResponse = result.data['response'] ?? 'Sorry, I could not process that.';
      final updatedFields = result.data['updatedFields'] as Map<dynamic, dynamic>?;

      if (updatedFields != null) {
        setState(() {
          updatedFields.forEach((key, value) {
            _filledFields[key.toString()] = value.toString();
          });
        });
      }

      final aiMessage = ChatMessage(
        text: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isSendingMessage = false;
      });

      _scrollToBottom();
      await _speakText(aiResponse);

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

  Future<void> _generateFilledDocument() async {
    if (_filledFields.isEmpty) {
      _showError('No fields have been filled yet');
      return;
    }

    setState(() => _isSendingMessage = true);

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('generateFilledDocument');

      final result = await callable.call({
        'imageUrl': _currentImageUrl,
        'filledFields': _filledFields,
        'language': _selectedLanguage,
      });

      final summary = result.data['summary'] ?? 'Document filled successfully!';

      final aiMessage = ChatMessage(
        text: summary,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isSendingMessage = false;
      });

      _scrollToBottom();
      await _speakText(summary);
      _showSuccessDialog();

    } catch (e) {
      setState(() => _isSendingMessage = false);
      _showError('Error generating document: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: const Text('Your document has been filled with all the provided information.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill Document with AI'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
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
          : _buildFillingView(),
    );
  }

  Widget _buildUploadSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green.shade700, size: 30),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Upload a document with blank fields. AI will help you fill them intelligently with visual guidance.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

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
                border: Border.all(color: Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No document selected',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
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
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              disabledBackgroundColor: Colors.grey.shade300,
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
              'Start Filling Document',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFillingView() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_imageFile != null)
                  Container(
                    height: 180,
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
                            _filledFields.clear();
                            _currentPictogramExplanation = null;
                            _currentPictogramIcon = null;
                          });
                          _stopSpeaking();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('New Document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _filledFields.isEmpty ? null : _generateFilledDocument,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (_filledFields.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Filled Fields:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        ..._filledFields.entries.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.arrow_right, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${entry.key}: ${entry.value}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tap the 💡 icon below for visual help with any field',
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
                  color: Colors.green.shade700,
                  child: Row(
                    children: [
                      const Icon(Icons.smart_toy, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'AI Form Filler',
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
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('AI is processing...'),
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
                        // NEW: Pictogram Help Button
                        IconButton(
                          onPressed: _isLoadingPictogram ? null : _requestPictogramHelp,
                          icon: _isLoadingPictogram
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amber.shade700,
                            ),
                          )
                              : const Icon(Icons.lightbulb),
                          color: Colors.amber.shade700,
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.amber.shade50,
                          ),
                          tooltip: 'Get Visual Help',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: 'Provide information to fill...',
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
                            color: _isListening ? Colors.red : Colors.green.shade700,
                          ),
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: _isListening
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _sendMessage(_chatController.text),
                          icon: const Icon(Icons.send),
                          color: Colors.green.shade700,
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
              backgroundColor: Colors.green.shade700,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
              radius: 16,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.green.shade700 : Colors.white,
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
              backgroundColor: Colors.blue.shade700,
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