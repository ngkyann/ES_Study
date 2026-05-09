import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:esstudy/constants/colors.dart';

class AIAssistantFAB extends StatefulWidget {
  const AIAssistantFAB({super.key});

  @override
  State<AIAssistantFAB> createState() => _AIAssistantFABState();
}

class _AIAssistantFABState extends State<AIAssistantFAB> {
  bool _isChatOpen = false;
  Offset _offset = const Offset(25, 25);
  bool _isDragging = false;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  final List<Content> _history = [];
  bool _isLoading = false;

  final List<String> _modelPool = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3.1-flash',
  ];
  int _currentModelIndex = 0;

  late GenerativeModel _model;
  final String _apiKey = 'AIzaSyDEvXt5krUQ059RVimI7U6BluQtamVy_Hs';

  @override
  void initState() {
    super.initState();
    _initModel();
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
      requestOptions: const RequestOptions(apiVersion: 'v1'),
    );
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _history.clear();
      _offset = const Offset(25, 25);
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

  void _autoAdjustPosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_messages.length > 5 && _offset.dx > screenWidth * 0.2) {
      setState(() {
        _offset = Offset(20, _offset.dy);
      });
    }
  }

  Future<void> _sendMessage() async {
    final prompt = _textController.text.trim();
    if (prompt.isEmpty) return;

    // Chỗ này mình trả về lệnh clear bình thường cho nhẹ app
    _textController.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
      _isLoading = true;
    });

    _scrollToBottom();
    _autoAdjustPosition();

    bool success = false;
    int attempt = 0;

    while (!success && attempt < _modelPool.length) {
      try {
        final chat = _model.startChat(history: _history);
        final response = await chat.sendMessage(Content.text(prompt));

        if (mounted) {
          setState(() {
            final aiText = response.text ?? '...';
            _messages.add({'role': 'model', 'text': aiText});
            _history.add(Content.text(prompt));
            _history.add(Content.model([TextPart(aiText)]));
            _isLoading = false;
          });
          _scrollToBottom();
          _autoAdjustPosition();
        }
        success = true;
      } catch (e) {
        attempt++;
        if (attempt < _modelPool.length) {
          _currentModelIndex = (_currentModelIndex + 1) % _modelPool.length;
          continue;
        }
        setState(() => _isLoading = false);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        AnimatedPositioned(
          duration: Duration(milliseconds: _isDragging ? 0 : 200),
          curve: Curves.linear,
          bottom: _offset.dy + bottomInset,
          right: _offset.dx,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanEnd: (_) => setState(() => _isDragging = false),
            onPanUpdate: (details) {
              setState(() {
                _offset = Offset(
                  (_offset.dx - details.delta.dx).clamp(
                    10,
                    screenSize.width - 60,
                  ),
                  (_offset.dy - details.delta.dy).clamp(
                    10,
                    screenSize.height - 100,
                  ),
                );
              });
            },
            child: FloatingActionButton(
              backgroundColor: primaryColor,
              onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
              child: Icon(
                _isChatOpen ? Icons.close : Icons.smart_toy,
                color: Colors.white,
              ),
            ),
          ),
        ),

        if (_isChatOpen)
          AnimatedPositioned(
            duration: Duration(milliseconds: _isDragging ? 0 : 250),
            curve: Curves.easeOutCubic,
            bottom: _offset.dy + 70 + bottomInset,
            right: _offset.dx,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: screenSize.width * 0.85,
                constraints: BoxConstraints(
                  maxWidth: 350,
                  minHeight: 100,
                  maxHeight: screenSize.height * 0.6,
                ),
                decoration: const BoxDecoration(color: Colors.white),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "ES Assistant",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _startNewChat,
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(10),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final isUser = m['role'] == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? primaryColor.withOpacity(0.1)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                m['text']!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    if (_isLoading)
                      LinearProgressIndicator(
                        minHeight: 2,
                        color: primaryColor,
                      ),

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: const TextStyle(fontSize: 14),

                              // --- CÔNG THỨC VÀNG TRỊ LỖI GÕ TIẾNG VIỆT ---
                              autocorrect:
                                  false, // BẮT BUỘC FALSE: Tránh lỗi nhè chữ cũ khi gõ tiếp
                              enableSuggestions:
                                  true, // BẮT BUỘC TRUE: Tránh lỗi liệt nút xoá (Backspace)
                              keyboardType: TextInputType.multiline,

                              // ------------------------------------------
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: "Hỏi AI...",
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.send, color: primaryColor),
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
