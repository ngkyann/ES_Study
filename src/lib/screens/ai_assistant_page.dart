import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Để dùng nút Copy
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart'; // Để hiển thị Toán/Hóa học
import 'package:markdown/markdown.dart' as md; // Để cấu hình Markdown
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:esstudy/constants/var.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class AIAssistantPage extends StatefulWidget {
  final String userId;
  const AIAssistantPage({super.key, required this.userId});

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
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _webImageBytes;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  final List<String> _modelPool = [
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-3.5-flash',
    'gemini-3-flash',
  ];
  int _currentModelIndex = 0;
  bool _isPlanningMode = false;
  late GenerativeModel _model;

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
      apiKey: geminiApiKey,
      requestOptions: const RequestOptions(apiVersion: 'v1'),
    );
  }

  Future<void> _pickImage() async {
    if (_isLoading || _isUploading) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality:
            80, // Có thể tăng chất lượng một chút để AI đọc rõ chữ hơn
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _selectedImage = image;
          _selectedFile = null; // Huỷ chọn file nếu chọn ảnh
        });
        // Gợi ý: Có thể hiện SnackBar hoặc hiển thị preview nhỏ lên UI để người dùng biết đã chọn thành công
      }
    } catch (e) {
      debugPrint("Lỗi khi chọn ảnh: $e");
    }
  }

  Future<void> _pickFile() async {
    if (_isLoading || _isUploading) return;
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.single;
          _selectedImage = null; // Huỷ chọn ảnh nếu chọn file
          _webImageBytes = null;
        });
      }
    } catch (e) {
      debugPrint("Lỗi khi chọn file: $e");
    }
  }

  Future<void> _loadChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Chỉ lấy tối đa 20-30 tin nhắn gần nhất để tiết kiệm và nhanh
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_chats')
          .orderBy('timestamp', descending: true) // Lấy từ mới nhất
          .limit(25) // Giới hạn số lượng tin nạp lại
          .get();

      if (mounted) {
        setState(() {
          _messages.clear();
          _history.clear();

          if (snapshot.docs.isEmpty) {
            _messages.add({
              'role': 'model',
              'text': languageNotifier.value == "Tiếng Việt"
                  ? 'Chào bạn! Mình là ES Assistant. Mình có thể giúp gì cho bạn hôm nay?'
                  : 'Hello! I am ES Assistant. How can I help you today?',
            });
          } else {
            // 2. Đảo ngược lại danh sách vì mình lấy descending: true
            final docs = snapshot.docs.reversed.toList();

            for (var doc in docs) {
              final data = doc.data();
              final role = data['role'] as String;
              final text = data['text'] as String;

              _messages.add({'role': role, 'text': text});

              // Nạp vào history cho AI
              if (role == 'user') {
                _history.add(Content.text(text));
              } else {
                _history.add(Content.model([TextPart(text)]));
              }
            }

            while (_history.isNotEmpty && _history.first.role == 'model') {
              _history.removeAt(0);
            }
          }
          _isFetchingHistory = false;
        });

        // Đợi UI render xong rồi mới scroll
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Lấy tất cả tin nhắn
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_chats')
          .get();

      if (snapshot.docs.isNotEmpty) {
        // 2. Chia nhỏ batch nếu số lượng tin > 500 (Phòng xa cho chắc)
        final writeBatchSize = 500;
        for (var i = 0; i < snapshot.docs.length; i += writeBatchSize) {
          final batch = FirebaseFirestore.instance.batch();
          final chunk = snapshot.docs.sublist(
              i,
              i + writeBatchSize > snapshot.docs.length
                  ? snapshot.docs.length
                  : i + writeBatchSize);

          for (var doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint("Lỗi khi xóa chat trên Firestore: $e");
      // Có thể hiện một SnackBar thông báo lỗi mạng ở đây
    } finally {
      // 3. Luôn đảm bảo tắt loading dù có lỗi hay không
      if (mounted) {
        setState(() {
          _messages.clear();
          _history.clear();
          _messages.add({
            'role': 'model',
            'text': languageNotifier.value == "Tiếng Việt"
                ? 'Đã xóa lịch sử trò chuyện. Chúng ta bắt đầu chủ đề mới nhé!'
                : 'Chat history deleted. Let\'s start a new topic!',
          });
          _isLoading = false;
        });
      }
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

  // 🔥 Hàm hiển thị menu tùy chọn khi bấm dấu +
  void _showPlusMenu(BuildContext context, bool isVN) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: Text(isVN ? "Gửi ảnh" : "Send Image"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(); // 🔥 Gọi hàm chọn ảnh
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.orange),
                title: Text(isVN ? "Gửi tài liệu" : "Send Document"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFile(); // 🔥 Gọi hàm chọn file tài liệu
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.purple),
                title: Text(isVN ? "Lập kế hoạch" : "Planning"),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isPlanningMode = true;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _autoCreatePlanFromAi(String jsonString, String userId) async {
    try {
      // Làm sạch chuỗi markdown bọc quanh json nếu AI lỡ tay viết thêm ```json ... ```
      String cleanJson =
          jsonString.replaceAll('```json', '').replaceAll('```', '').trim();

      Map<String, dynamic> planMap = jsonDecode(cleanJson);
      String title = planMap['title'] ?? 'Kế hoạch học tập AI';
      List<dynamic> questList = planMap['quest'] ?? [];
      List<String> tasks = questList.map((e) => e.toString()).toList();

      if (tasks.isEmpty) return;

      // Phân tách chuỗi ngày tháng năm từ JSON (Định dạng "D/M/YYYY")
      List<String> dateParts = (planMap['date'] as String).split('/');
      List<String> timeParts = (planMap['time'] as String).split(':');

      int day = int.parse(dateParts[0]);
      int month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      DateTime parsedDate = DateTime(year, month, day, hour, minute);

      // Khớp mốc thời gian nếu rơi vào quá khứ do AI trễ giây, ép về thời gian hiện tại cộng thêm 1 phút để tránh lỗi lịch
      if (parsedDate.isBefore(DateTime.now())) {
        parsedDate = DateTime.now().add(const Duration(minutes: 1));
      }

      // Đẩy trực tiếp vào Firestore bộ sưu tập 'plans' giống hệt logic _addPlan của bạn
      DocumentReference docRef =
          await FirebaseFirestore.instance.collection('plans').add({
        'userId': userId,
        'title': title,
        'time': parsedDate,
        'tasks': tasks,
        'completedTasks': List.generate(tasks.length, (_) => false),
      });

      // Tạo thông báo đẩy đi kèm định dạng hệ thống
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc('plan_${docRef.id}')
          .set({
        'userId': userId,
        'content_vn': "📚 Đến giờ thực hiện kế hoạch: $title",
        'content_en': "📚 Time for your plan: $title",
        'createdAt': Timestamp.fromDate(parsedDate),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: primaryColor,
            content: Text(languageNotifier.value == "Tiếng Việt"
                ? "🎉 Đã tự động đồng bộ kế hoạch \"$title\" vào lịch học của bạn!"
                : "🎉 Successfully synced plan \"$title\" to your schedule!"),
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi phân rã JSON và lưu Plan tự động: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();

    // Sửa lại điều kiện kiểm tra: Nếu text trống VÀ đồng thời không chọn ảnh, không chọn file thì mới chặn không cho gửi
    if (text.isEmpty && _selectedImage == null && _selectedFile == null) return;
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final userLimitDoc =
        FirebaseFirestore.instance.collection('user_limits').doc(user.uid);

    int rpmCount = 0;
    int rpdCount = 0;
    DateTime dayStart = DateTime(now.year, now.month, now.day);

    // ==========================================
    // KIỂM TRA RATE LIMIT (GIỮ NGUYÊN LOGIC CỦA BẠN)
    // ==========================================
    try {
      final doc = await userLimitDoc.get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data()!;
        DateTime lastRequest = (data['lastRequest'] as Timestamp).toDate();
        DateTime lastDayStart = (data['dayStart'] as Timestamp).toDate();
        rpmCount = data['rpmCount'] ?? 0;
        rpdCount = data['rpdCount'] ?? 0;

        if (now.difference(lastDayStart).inDays >= 1) {
          rpdCount = 0;
        } else {
          dayStart = lastDayStart;
        }

        if (now.difference(lastRequest).inMinutes >= 1) {
          rpmCount = 0;
        }
      }

      if (rpdCount >= 100) {
        _showLimitDialog(languageNotifier.value == "Tiếng Việt"
            ? "Bạn đã dùng hết 100 lượt hỏi hôm nay."
            : "You have used all 100 questions for today.");
        return;
      }
      if (rpmCount >= 6) {
        _showLimitDialog(languageNotifier.value == "Tiếng Việt"
            ? "Hỏi nhanh quá! Đợi xíu nhé."
            : "Asking too fast! Please wait a moment.");
        return;
      }
    } catch (e) {
      debugPrint("Lỗi Rate Limit: $e");
    }

    final rawPrompt = _textController.text.trim();
    _textController.clear();

    // ==========================================
    // 1. CHUẨN BỊ HIỂN THỊ TRÊN UI NGƯỜI DÙNG (CÓ THÊM TAG PHÂN BIỆT FILE/ẢNH)
    // ==========================================
    String userDisplayMsg = rawPrompt;
    if (_selectedImage != null) {
      userDisplayMsg =
          rawPrompt.isEmpty ? "📷 [Hình ảnh]" : "📷 [Hình ảnh]\n$rawPrompt";
    } else if (_selectedFile != null) {
      userDisplayMsg = rawPrompt.isEmpty
          ? "📁 [Tài liệu: ${_selectedFile!.name}]"
          : "📁 [Tài liệu: ${_selectedFile!.name}]\n$rawPrompt";
    }

    setState(() {
      _messages.add({'role': 'user', 'text': userDisplayMsg});
      _isLoading = true;
    });
    _scrollToBottom();

    // Lưu lịch sử hiển thị đẹp mắt này vào Firestore chat cá nhân của user
    await _saveMessageToFirestore('user', userDisplayMsg);

    // ==========================================
    // 2. KỸ THUẬT PROMPT ẨN GIẤU CẤU TRÚC JSON (GIỮ NGUYÊN)
    // ==========================================
    String finalPromptForAI = rawPrompt;
    if (_isPlanningMode) {
      String currentDateStr = "${now.day}/${now.month}/${now.year}";
      String currentTimeStr = "${now.hour}:${now.minute}";

      finalPromptForAI = """
Bạn là một trợ lý AI lập kế hoạch học tập chuyên nghiệp. Yêu cầu của người dùng là: "$rawPrompt".
Hãy phân tích yêu cầu này và thực hiện hai nhiệm vụ cùng một lúc:

Nhiệm vụ 1: Viết một bài phản hồi tư vấn lộ trình chi tiết bằng ngôn ngữ tự nhiên thân thiện, dễ hiểu cho người dùng. (Phần này sẽ hiển thị cho họ xem).

Nhiệm vụ 2: BẮT BUỘC kẹp thêm một khối dữ liệu cấu trúc JSON ở ngay cuối cùng bài viết của bạn để hệ thống tự động bóc tách. Khối JSON phải tuân thủ nghiêm ngặt định dạng sau, không được thêm bớt key:
<PLAN_DATA>
{
  "title": "Tên ngắn gọn của kế hoạch",
  "date": "$currentDateStr",
  "time": "$currentTimeStr",
  "quest": [
    "Nhiệm vụ cụ thể 1",
    "Nhiệm vụ cụ thể 2",
    "Nhiệm vụ cụ thể 3"
  ]
}
</PLAN_DATA>

Lưu ý quan trọng: Phải phân tích kỹ yêu cầu của người dùng để sinh ra các nhiệm vụ trong mảng "quest" thật thực tế, khả thi và tuyệt đối không để trống. Ngày giờ thực hiện mặc định ưu tiên lấy mốc hiện tại ($currentDateStr lúc $currentTimeStr).
""";
    }

    // ==========================================
    // 3. ĐÓNG GÓI MULTIMODAL PARTS (BÓC TÁCH ĐỂ TRUYỀN CHO GEMINI)
    // ==========================================
    List<Part> partsToModel = [];

    // Thêm Text Part (Nếu rỗng nhưng có đính kèm file/ảnh thì mồi câu lệnh phân tích dữ liệu)
    if (finalPromptForAI.isNotEmpty) {
      partsToModel.add(TextPart(finalPromptForAI));
    } else if (_selectedImage != null || _selectedFile != null) {
      partsToModel.add(TextPart(
          "Hãy đọc hiểu và phân tích dữ liệu tệp đính kèm này giúp tôi."));
    }

    try {
      // Xử lý nạp byte dữ liệu cho Hình ảnh
      if (_selectedImage != null) {
        Uint8List imageBytes;
        if (kIsWeb) {
          if (_webImageBytes != null) {
            imageBytes = _webImageBytes!;
          } else {
            throw Exception("Không thể đọc dữ liệu bytes ảnh trên Web");
          }
        } else {
          imageBytes = await File(_selectedImage!.path).readAsBytes();
        }
        partsToModel.add(DataPart('image/jpeg', imageBytes));
      }

      // Xử lý nạp byte dữ liệu cho Tập tin/Tài liệu
      if (_selectedFile != null) {
        Uint8List? fileBytes = _selectedFile!.bytes;
        if (!kIsWeb && fileBytes == null && _selectedFile!.path != null) {
          fileBytes = await File(_selectedFile!.path!).readAsBytes();
        }

        if (fileBytes != null) {
          String mimeType = 'application/octet-stream';
          String fileNameLower = _selectedFile!.name.toLowerCase();

          if (fileNameLower.endsWith('.pdf'))
            mimeType = 'application/pdf';
          else if (fileNameLower.endsWith('.txt'))
            mimeType = 'text/plain';
          else if (fileNameLower.endsWith('.png'))
            mimeType = 'image/png';
          else if (fileNameLower.endsWith('.jpg') ||
              fileNameLower.endsWith('.jpeg')) mimeType = 'image/jpeg';

          partsToModel.add(DataPart(mimeType, fileBytes));
        }
      }
    } catch (mediaError) {
      debugPrint("Lỗi nạp byte tệp đính kèm: $mediaError");
    }

    // Cấu trúc gói Content gửi đi
    final Content userContentContent = Content('user', partsToModel);

    // Sau khi xử lý xong các tệp đính kèm hiện tại, xóa sạch bộ nhớ đệm chọn file để chuẩn bị cho tin tiếp theo
    XFile? tempSelectedImage = _selectedImage;
    PlatformFile? tempSelectedFile = _selectedFile;
    setState(() {
      _selectedImage = null;
      _webImageBytes = null;
      _selectedFile = null;
    });

    // ==========================================
    // 4. TIẾN HÀNH GỬI API CHO AI VÀ MODEL POOL LỖI TRẢ VỀ (FAILOVER POOL)
    // ==========================================
    bool success = false;
    int attempt = 0;

    while (!success && attempt < _modelPool.length) {
      try {
        _model = GenerativeModel(
          model: _modelPool[_currentModelIndex],
          apiKey: geminiApiKey,
          requestOptions: const RequestOptions(apiVersion: 'v1'),
        );

        // Thêm Content đa phương thức vừa đóng gói vào luồng Lịch sử bộ nhớ tạm thời
        _history.add(userContentContent);

        final chat = _model.startChat(history: _history);

        // Vì đã add vào history trước đó rồi, ở đây ta chỉ cần gọi sendMessage trống,
        // hoặc truyền trực tiếp Content mới mà không thông qua cơ chế Content.text thuần cũ.
        final response = await chat.sendMessage(userContentContent);

        if (mounted) {
          String aiRawText = response.text ?? '...';
          String displayText = aiRawText;
          String? jsonSegment;

          // Tiến hành bóc tách dữ liệu JSON nội bộ ra khỏi nội dung hiển thị
          if (_isPlanningMode && aiRawText.contains('<PLAN_DATA>')) {
            final parts = aiRawText.split('<PLAN_DATA>');
            displayText =
                parts[0].trim(); // Phần text hội thoại thuần túy phục vụ UI

            if (parts.length > 1) {
              final subParts = parts[1].split('</PLAN_DATA>');
              jsonSegment = subParts[0].trim();
            }
          }

          // Cập nhật lại số lượng câu hỏi lên DB Rate Limit
          await userLimitDoc.set({
            'rpmCount': rpmCount + 1,
            'rpdCount': rpdCount + 1,
            'lastRequest': FieldValue.serverTimestamp(),
            'dayStart': dayStart,
          }, SetOptions(merge: true));

          setState(() {
            // Đưa văn bản sạch lên màn hình chat
            _messages.add({'role': 'model', 'text': displayText});

            // Để tránh gom toàn bộ DataPart khổng lồ bằng Bytes vào mảng _history lâu dài gây tràn RAM máy,
            // Ta chuyển đổi tin nhắn User cũ trong history về dạng Text để tối ưu hóa bộ nhớ.
            _history.removeLast();

            String summaryUserText = rawPrompt;
            if (summaryUserText.isEmpty) {
              summaryUserText = tempSelectedImage != null
                  ? "[Gửi một hình ảnh]"
                  : "[Gửi một tệp đính kèm]";
            }

            _history.add(Content.text(summaryUserText));
            _history.add(Content.model([TextPart(displayText)]));

            if (_history.length > 20) _history.removeRange(0, 2);
            _isLoading = false;
          });

          _scrollToBottom();
          await _saveMessageToFirestore('model', displayText);

          // Nếu bóc tách thành công dữ liệu JSON, tiến hành đẩy tự động vào database
          if (_isPlanningMode && jsonSegment != null) {
            await _autoCreatePlanFromAi(jsonSegment, widget.userId);
            setState(() {
              _isPlanningMode = false;
            });
          }
        }
        success = true;
      } catch (e) {
        debugPrint("Lỗi tại model ${_modelPool[_currentModelIndex]}: $e");

        // Nếu lỗi xảy ra, ta phải dọn dẹp phần Content vừa cố add vào _history ở trên để tránh lỗi lệch cấu trúc
        if (_history.isNotEmpty && _history.last == userContentContent) {
          _history.removeLast();
        }

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
              'text': languageNotifier.value == "Tiếng Việt"
                  ? '⚠️ Hiện tại tất cả mô hình AI đều đang bận hoặc định dạng file không được hỗ trợ. Bạn kiểm tra lại nhé!'
                  : '⚠️ All AI models are currently busy or the file format is not supported. Please try again!',
            });
            _isLoading = false;
            _isPlanningMode = false;
          });
          _scrollToBottom();
        }
        break;
      }
    }
  }

  void _showLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Giới hạn câu hỏi"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đã hiểu"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          // Tạo biến isVN để code ngắn gọn hơn
          bool isVN = lang == "Tiếng Việt";

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
                  // 🔥 SỬA TOOLTIP
                  tooltip: isVN ? "Cuộc trò chuyện mới" : "New chat",
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              // 🔥 SỬA CHỮ TRONG DIALOG
                              title: Text(isVN
                                  ? "Xóa đoạn chat này?"
                                  : "Delete this chat?"),
                              content: Text(isVN
                                  ? "Lịch sử trò chuyện này sẽ bị xóa vĩnh viễn và không thể khôi phục."
                                  : "This chat history will be permanently deleted and cannot be recovered."),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(isVN ? "Hủy" : "Cancel",
                                        style: const TextStyle(
                                            color: Colors.grey))),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _startNewChat();
                                    },
                                    child: Text(isVN ? "Xóa" : "Delete",
                                        style: const TextStyle(
                                            color: Colors.white)))
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
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
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
                                          color: isUser
                                              ? Colors.black87
                                              : Colors.black,
                                        ),
                                        strong: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isUser
                                              ? Colors.black87
                                              : Colors.black,
                                        ),
                                        code: TextStyle(
                                          backgroundColor: Colors.grey.shade200,
                                          color: Colors.red.shade800,
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                        ),
                                        codeblockDecoration: BoxDecoration(
                                          color: Colors.grey.shade900,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    if (!isUser) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(
                                                text: m['text']!));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                // 🔥 SỬA THÔNG BÁO COPY
                                                content: Text(isVN
                                                    ? "Đã sao chép tin nhắn này!"
                                                    : "Message copied!"),
                                                backgroundColor: primaryColor,
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.copy,
                                                    size: 14,
                                                    color: primaryColor
                                                        .withOpacity(0.8)),
                                                const SizedBox(width: 4),
                                                // 🔥 SỬA CHỮ NÚT COPY
                                                Text(isVN ? "Sao chép" : "Copy",
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: primaryColor
                                                            .withOpacity(0.8),
                                                        fontWeight:
                                                            FontWeight.bold)),
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

                      // Đặt đoạn code này ngay PHÍA TRÊN Container thanh công cụ nhập liệu chat:
                      if (_selectedImage != null || _selectedFile != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: Colors.grey.shade200,
                          child: Row(
                            children: [
                              Icon(
                                _selectedImage != null
                                    ? Icons.image
                                    : Icons.description,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedImage != null
                                      ? (languageNotifier.value == "Tiếng Việt"
                                          ? "Đã chọn 1 hình ảnh"
                                          : "1 Image selected")
                                      : _selectedFile!.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                    _webImageBytes = null;
                                    _selectedFile = null;
                                  });
                                },
                              )
                            ],
                          ),
                        ),

                      // --- THANH ĐIỀU KHIỂN VÀ NHẬP LIỆU ---
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, -2),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🔥 KHUNG HIỂN THỊ TRẠNG THÁI CHẾ ĐỘ LẬP KẾ HOẠCH (Kiểu ảnh 2)
                            if (_isPlanningMode)
                              Container(
                                margin: const EdgeInsets.only(
                                    bottom: 8, left: 8, right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.purple.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.auto_awesome,
                                        color: Colors.purple, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isVN
                                            ? "Chế độ: AI Lập kế hoạch học tập"
                                            : "Mode: AI Planning",
                                        style: TextStyle(
                                            color: Colors.purple.shade800,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _isPlanningMode = false),
                                      child: const Icon(Icons.cancel,
                                          color: Colors.grey, size: 18),
                                    ),
                                  ],
                                ),
                              ),

                            // Thanh nhập liệu chính
                            Row(
                              children: [
                                // 🔥 NÚT DẤU + MỞ POPUP MENU BÊN TRÁI
                                IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.blue, size: 28),
                                  onPressed: () => _showPlusMenu(context, isVN),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    keyboardType: TextInputType.multiline,
                                    maxLines: null,
                                    textInputAction: TextInputAction.newline,
                                    onSubmitted: (_) => _sendMessage(),
                                    decoration: InputDecoration(
                                      hintText: _isPlanningMode
                                          ? (isVN
                                              ? "Nhập yêu cầu lập kế hoạch..."
                                              : "Enter planning request...")
                                          : (isVN
                                              ? "Hỏi trợ lý AI học tập..."
                                              : "Ask AI study assistant..."),
                                      hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
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
                                    icon: const Icon(Icons.send,
                                        color: Colors.white),
                                    onPressed: _sendMessage,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        });
  }
}
