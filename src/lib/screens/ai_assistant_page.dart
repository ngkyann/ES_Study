import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:esstudy/constants/colors.dart';

class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  final List<Content> _history = [];
  bool _isLoading = false;

  final List<String> _modelPool = [
    'gemma-3-1b-it',
    'gemma-3-2b-it',
    'gemma-3-4b-it',
    'gemma-3-8b-it',
    'gemma-3-27b-it',
  ];
  int _currentModelIndex = 0;

  late GenerativeModel _model;
  final String _apiKey = 'AIzaSyConvnHnodpl11TI9kb-P_kFTF34Q78JDo';

  @override
  void initState() {
    super.initState();
    _initModel();
    _messages.add({
      'role': 'model',
      'text':
          'Chào bạn! Mình là ES Assistant. Mình có thể giúp gì cho việc học của bạn hôm nay?',
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initModel() {
    _model = GenerativeModel(
      model: _modelPool[_currentModelIndex],
      apiKey: _apiKey,
      requestOptions: const RequestOptions(apiVersion: 'v1beta'),
    );
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _history.clear();
      _messages.add({
        'role': 'model',
        'text': 'Đã xóa lịch sử trò chuyện. Chúng ta bắt đầu chủ đề mới nhé!',
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final prompt = _textController.text.trim();
    if (prompt.isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
      _isLoading = true;
    });

    _scrollToBottom();

    bool success = false;
    int attempt = 0;

    while (!success && attempt < _modelPool.length) {
      try {
        // 1. Phải khởi tạo lại model với Index mới trước khi chat
        _model = GenerativeModel(
          model: _modelPool[_currentModelIndex],
          apiKey: _apiKey,
        );

        final chat = _model.startChat(history: _history);
        final response = await chat.sendMessage(Content.text(prompt));

        if (mounted) {
          setState(() {
            final aiText = response.text ?? '...';
            _messages.add({'role': 'model', 'text': aiText});

            // Lưu history (Giữ tối đa 10 tin nhắn gần nhất để tránh quá tải dung lượng)
            _history.add(Content.text(prompt));
            _history.add(Content.model([TextPart(aiText)]));
            if (_history.length > 20) _history.removeRange(0, 2);

            _isLoading = false;
          });
          _scrollToBottom();
        }
        success = true;
      } catch (e) {
        debugPrint("Lỗi tại model ${_modelPool[_currentModelIndex]}: $e");
        attempt++;

        if (attempt < _modelPool.length) {
          // 2. Chờ 1 giây trước khi đổi model để tránh bị Google chặn IP
          await Future.delayed(const Duration(seconds: 1));
          _currentModelIndex = (_currentModelIndex + 1) % _modelPool.length;
          continue;
        }

        if (mounted) {
          setState(() {
            _messages.add({
              'role': 'model',
              'text':
                  '⚠️ Hiện tại tất cả máy chủ AI đều bận. Ông đợi khoảng 30 giây rồi hỏi lại tôi nhé!',
            });
            _isLoading = false;
          });
          _scrollToBottom();
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "ES Assistant",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Cuộc trò chuyện mới",
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Khu vực hiển thị tin nhắn
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m['role'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? primaryColor.withOpacity(0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser
                            ? const Radius.circular(20)
                            : const Radius.circular(5),
                        bottomRight: isUser
                            ? const Radius.circular(5)
                            : const Radius.circular(20),
                      ),
                      boxShadow: [
                        if (!isUser)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Text(
                      m['text']!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: isUser ? Colors.black87 : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Thanh Loading khi AI đang "suy nghĩ"
          if (_isLoading)
            LinearProgressIndicator(
              minHeight: 3,
              color: primaryColor,
              backgroundColor: primaryColor.withOpacity(0.2),
            ),

          // Khu vực nhập văn bản
          Container(
            padding: const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              20,
            ), // Padding dưới to hơn để tránh thanh điều hướng
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(fontSize: 15),
                    autocorrect: false, // Tránh lỗi gõ tiếng Việt
                    enableSuggestions: true,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Hỏi AI điều gì đó...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
