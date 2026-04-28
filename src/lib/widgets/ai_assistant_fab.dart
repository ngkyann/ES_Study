import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIAssistantFAB extends StatefulWidget {
  const AIAssistantFAB({super.key});

  @override
  State<AIAssistantFAB> createState() => _AIAssistantFABState();
}

class _AIAssistantFABState extends State<AIAssistantFAB> {
  bool _isChatOpen = false;
  // Vị trí mặc định của nút
  Offset _offset = const Offset(25, 25);
  
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Danh sách hiển thị trên UI
  final List<Map<String, String>> _messages = [];
  // Lịch sử thực tế để gửi cho AI (giữ context)
  final List<Content> _history = [];
  
  bool _isLoading = false;

  final List<String> _modelPool = [
    'gemma-3-1b-it',
    'gemma-3-4b-it',
    'gemma-3-8b-it',
    'gemma-3-27b-it',
    'gemma-3-2b-it'
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
      _isLoading = true;
      _textController.clear();
    });
    _scrollToBottom();

    bool success = false;
    int attempt = 0;

    // Vòng lặp thử các model trong pool
    while (!success && attempt < _modelPool.length) {
      try {
        // Khởi tạo chat với lịch sử đã có
        final chat = _model.startChat(history: _history);
        final response = await chat.sendMessage(Content.text(prompt));
        
        setState(() {
          _messages.add({'role': 'model', 'text': response.text ?? '...' });
          // Lưu vào lịch sử thật để giữ context cho câu hỏi sau
          _history.add(Content.text(prompt));
          _history.add(Content.model([TextPart(response.text ?? '')]));
          _isLoading = false;
        });
        success = true;
      } catch (e) {
        final errorStr = e.toString();
        // Nếu lỗi 429 (Overloaded/Quota) hoặc 503 (Server busy)
        if (errorStr.contains('429') || errorStr.contains('503') || errorStr.contains('quota')) {
          attempt++;
          if (attempt < _modelPool.length) {
            _currentModelIndex = (_currentModelIndex + 1) % _modelPool.length;
            _initModel(); // Đổi sang model tiếp theo
            continue; 
          }
        }
        
        // Nếu đã thử hết các model mà vẫn lỗi
        setState(() {
          _messages.add({'role': 'model', 'text': 'Hệ thống đang quá tải, thử lại sau nhé!'});
          _isLoading = false;
        });
        break;
      }
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Nút FAB có khả năng kéo thả
        Positioned(
          bottom: _offset.dy,
          right: _offset.dx,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                // Giới hạn không cho kéo ra khỏi màn hình
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

        if (_isChatOpen)
          Positioned(
            bottom: _offset.dy + 70, // Luôn hiện trên đầu nút FAB
            right: _offset.dx,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.45,
                constraints: const BoxConstraints(maxWidth: 350, maxHeight: 500),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    // Header hiện model đang chạy (ẩn danh cho user)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text("ES Study Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10),
                        itemCount: _messages.length,
                        itemBuilder: (c, i) {
                          final m = _messages[i];
                          return Align(
                            alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: m['role'] == 'user' ? Colors.blue[50] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(m['text']!, style: const TextStyle(fontSize: 13)),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: InputDecoration(
                                hintText: "Hỏi AI...",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.blueAccent),
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