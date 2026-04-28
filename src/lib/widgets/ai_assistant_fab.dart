import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIAssistantFAB extends StatefulWidget {
  const AIAssistantFAB({super.key});

  @override
  State<AIAssistantFAB> createState() => _AIAssistantFABState();
}

class _AIAssistantFABState extends State<AIAssistantFAB> {
  bool _isChatOpen = false;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Danh sách lưu trữ hội thoại
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  late final GenerativeModel _model;
  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    // Khởi tạo model Gemini
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // Hoặc 'models/gemini-2.0-flash' nếu đã có
      apiKey: 'AIzaSyConvnHnodpl11TI9kb-P_kFTF34Q78JDo',
    );

    _chat = _model.startChat();
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

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': message});
      _isLoading = true;
      _textController.clear();
    });
    _scrollToBottom();

    try {
      final response = await _chat.sendMessage(Content.text(message));
      final text = response.text;

      setState(() {
        _messages.add({
          'role': 'model',
          'text': text ?? 'AI không phản hồi...',
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'model', 'text': 'Lỗi: ${e.toString()}'});
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Nút bong bóng chính
        Positioned(
          bottom: 25,
          right: 25,
          child: FloatingActionButton(
            backgroundColor: Colors.blueAccent,
            onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
            child: Icon(
              _isChatOpen ? Icons.close : Icons.smart_toy,
              color: Colors.white,
            ),
          ),
        ),

        // Cửa sổ Chat
        if (_isChatOpen)
          Positioned(
            bottom: 95,
            right: 25,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.5,
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 600,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "AI Assistant",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Danh sách tin nhắn
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          bool isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.blue[100]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg['text']!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                    // Input field
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                hintText: "Nhập câu hỏi...",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Colors.blueAccent,
                            ),
                            onPressed: _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
