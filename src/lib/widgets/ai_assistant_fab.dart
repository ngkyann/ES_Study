import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIAssistantFAB extends StatefulWidget {
  const AIAssistantFAB({super.key});

  @override
  State<AIAssistantFAB> createState() => _AIAssistantFABState();
}

class _AIAssistantFABState extends State<AIAssistantFAB> {
  bool _isChatOpen = false;
  Offset _offset = const Offset(25, 25); // Vị trí kéo thả

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Lưu lịch sử dưới dạng Content để gửi cho API
  final List<Content> _apiHistory = [];
  // Lưu dưới dạng Map để hiển thị UI
  final List<Map<String, String>> _messages = [];
  
  bool _isLoading = false;

  final List<String> _modelPool = [
    'gemma-3-1b-it',
    'gemma-3-4b-it',
    'gemma-3-12b-it',
    'gemma-3-27b-it',
  ];
  
  int _currentModelIndex = 0;
  late GenerativeModel _model;
  final String _apiKey = 'AIzaSyConvnHnodpl11TI9kb-P_kFTF34Q78JDo';

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  void _initModel() {
    _model = GenerativeModel(
      model: _modelPool[_currentModelIndex],
      apiKey: _apiKey,
      requestOptions: const RequestOptions(apiVersion: 'v1beta'),
    );
    if (_apiHistory.isEmpty) {
      _apiHistory.add(Content.text("Hệ thống: Bạn là trợ lý học tập của ES Study."));
    }
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
    final prompt = _textController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
      _apiHistory.add(Content.text(prompt)); // Lưu vào lịch sử gửi đi
      _isLoading = true;
      _textController.clear();
    });
    _scrollToBottom();

    bool success = false;
    int retryCount = 0;

    while (!success && retryCount < _modelPool.length) {
      try {
        // Gửi toàn bộ lịch sử _apiHistory đi thay vì dùng ChatSession
        final response = await _model.generateContent(_apiHistory);
        final text = response.text;

        setState(() {
          _messages.add({'role': 'model', 'text': text ?? 'AI im lặng...'});
          _apiHistory.add(Content.model([TextPart(text ?? '')])); // Lưu câu trả lời của AI vào sử
          _isLoading = false;
        });
        success = true;
      } catch (e) {
        String errorStr = e.toString();
        if (errorStr.contains('429') || errorStr.contains('503')) {
          retryCount++;
          if (_currentModelIndex < _modelPool.length - 1) {
            _currentModelIndex++;
            _initModel();
            debugPrint('Chuyển model: ${_modelPool[_currentModelIndex]} - Lịch sử vẫn giữ nguyên');
          } else {
            _addSystemMessage('Tất cả model đều bận, vui lòng thử lại sau.');
            break;
          }
        } else {
          _addSystemMessage('Lỗi: $errorStr');
          break;
        }
      }
    }
    _scrollToBottom();
  }

  void _addSystemMessage(String msg) {
    setState(() {
      _messages.add({'role': 'model', 'text': msg});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Nút FAB kéo thả
        Positioned(
          bottom: _offset.dy,
          right: _offset.dx,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _offset = Offset(
                  (_offset.dx - details.delta.dx).clamp(10, MediaQuery.of(context).size.width - 60),
                  (_offset.dy - details.delta.dy).clamp(10, MediaQuery.of(context).size.height - 100),
                );
              });
            },
            child: FloatingActionButton(
              backgroundColor: Colors.blueAccent,
              onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
              child: Icon(_isChatOpen ? Icons.close : Icons.smart_toy, color: Colors.white),
            ),
          ),
        ),

        // Cửa sổ Chat
        if (_isChatOpen)
          Positioned(
            bottom: _offset.dy + 70,
            right: _offset.dx,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.45,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.yellow, size: 20),
                          const SizedBox(width: 8),
                          const Text("ES Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(_modelPool[_currentModelIndex].split('-')[2].toUpperCase(), 
                               style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                    // Chat List
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(15),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          bool isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.blue[50] : Colors.grey[100],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(15),
                                  topRight: const Radius.circular(15),
                                  bottomLeft: Radius.circular(isUser ? 15 : 0),
                                  bottomRight: Radius.circular(isUser ? 0 : 15),
                                ),
                              ),
                              child: Text(msg['text']!, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isLoading) const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
                    // Input
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: InputDecoration(
                                hintText: "Hỏi AI bài tập...",
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 5),
                          CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white, size: 20),
                              onPressed: _sendMessage,
                            ),
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