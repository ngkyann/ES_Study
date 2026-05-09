import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Để dùng nút Copy
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart'; // Để hiển thị Toán/Hóa học
import 'package:markdown/markdown.dart' as md; // Để cấu hình Markdown
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isFetchingHistory = true;

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
    _loadChatHistory();
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

  Future<void> _loadChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_chats')
          .orderBy('timestamp', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _messages.add({
              'role': 'model',
              'text':
                  'Chào bạn! Mình là ES Assistant. Mình có thể giúp gì cho việc học của bạn hôm nay?',
            });
            _isFetchingHistory = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final role = data['role'] as String;
              final text = data['text'] as String;

              _messages.add({'role': role, 'text': text});

              if (role == 'user') {
                _history.add(Content.text(text));
              } else {
                _history.add(Content.model([TextPart(text)]));
              }
            }

            if (_history.length > 20) {
              _history.removeRange(0, _history.length - 20);
            }

            _isFetchingHistory = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Lỗi khi tải lịch sử: $e");
      if (mounted) setState(() => _isFetchingHistory = false);
    }
  }

  Future<void> _saveMessageToFirestore(String role, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_chats')
          .add({
        'role': role,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Lỗi khi lưu tin nhắn: $e");
    }
  }

  Future<void> _startNewChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('ai_chats')
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (e) {
        debugPrint("Lỗi khi xóa chat: $e");
      }
    }

    if (mounted) {
      setState(() {
        _messages.clear();
        _history.clear();
        _messages.add({
          'role': 'model',
          'text': 'Đã xóa lịch sử trò chuyện. Chúng ta bắt đầu chủ đề mới nhé!',
        });
        _isLoading = false;
      });
    }
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
    await _saveMessageToFirestore('user', prompt);

    bool success = false;
    int attempt = 0;

    while (!success && attempt < _modelPool.length) {
      try {
        _model = GenerativeModel(
          model: _modelPool[_currentModelIndex],
          apiKey: _apiKey,
          requestOptions: const RequestOptions(apiVersion: 'v1'),
        );

        final chat = _model.startChat(history: _history);
        final response = await chat.sendMessage(Content.text(prompt));

        if (mounted) {
          final aiText = response.text ?? '...';

          setState(() {
            _messages.add({'role': 'model', 'text': aiText});

            _history.add(Content.text(prompt));
            _history.add(Content.model([TextPart(aiText)]));
            if (_history.length > 20) _history.removeRange(0, 2);

            _isLoading = false;
          });
          _scrollToBottom();
          await _saveMessageToFirestore('model', aiText);
        }
        success = true;
      } catch (e) {
        debugPrint("Lỗi tại model ${_modelPool[_currentModelIndex]}: $e");
        attempt++;

        if (attempt < _modelPool.length) {
          await Future.delayed(const Duration(seconds: 1));
          _currentModelIndex = (_currentModelIndex + 1) % _modelPool.length;
          continue;
        }

        if (mounted) {
          setState(() {
            _messages.add({
              'role': 'model',
              'text':
                  '⚠️ Hiện tại tất cả máy chủ AI đều bận. Bạn đợi khoảng 30 giây rồi hỏi lại nhé!',
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
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                        title: const Text("Xóa đoạn chat?"),
                        content: const Text(
                            "Lịch sử trò chuyện này sẽ bị xóa vĩnh viễn và không thể khôi phục."),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Hủy",
                                  style: TextStyle(color: Colors.grey))),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _startNewChat();
                              },
                              child: const Text("Xóa",
                                  style: TextStyle(color: Colors.white)))
                        ],
                      ));
            },
          ),
        ],
      ),
      body: _isFetchingHistory
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
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
                              horizontal: 16, vertical: 12),
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
                          // 🔥 ĐÃ CẬP NHẬT: COLUMN CHỨA LATEX VÀ NÚT COPY
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MarkdownBody(
                                data: m['text']!,
                                selectable: true,
                                builders: {
                                  'latex': LatexElementBuilder(
                                    textStyle: TextStyle(
                                      color: isUser
                                          ? Colors.black87
                                          : Colors.black,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                },
                                extensionSet: md.ExtensionSet(
                                  [
                                    ...md.ExtensionSet.gitHubFlavored
                                        .blockSyntaxes,
                                    LatexBlockSyntax()
                                  ],
                                  [
                                    ...md.ExtensionSet.gitHubFlavored
                                        .inlineSyntaxes,
                                    LatexInlineSyntax()
                                  ],
                                ),
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    color:
                                        isUser ? Colors.black87 : Colors.black,
                                  ),
                                  strong: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isUser ? Colors.black87 : Colors.black,
                                  ),
                                  code: TextStyle(
                                    backgroundColor: Colors.grey.shade200,
                                    color: Colors.red.shade800,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: Colors.grey.shade900,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              if (!isUser) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: InkWell(
                                    onTap: () {
                                      Clipboard.setData(
                                          ClipboardData(text: m['text']!));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                              "Đã sao chép câu trả lời!"),
                                          backgroundColor: primaryColor,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.copy,
                                              size: 14,
                                              color: Colors.grey.shade700),
                                          const SizedBox(width: 4),
                                          Text("Copy",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  LinearProgressIndicator(
                    minHeight: 3,
                    color: primaryColor,
                    backgroundColor: primaryColor.withOpacity(0.2),
                  ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
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
                          autocorrect: false,
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
