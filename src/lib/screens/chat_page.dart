import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/constants/var.dart';
import 'package:flutter/services.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String targetUserName;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.targetUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msgController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _webImageBytes;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  // Tự động mở link tải tài liệu/tập tin về máy
  Future<void> _downloadFile(String fileUrl) async {
    final Uri url = Uri.parse(fileUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // Chọn ảnh từ bộ sưu tập
  Future<void> _pickImage() async {
    if (_isUploading) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 256,
        maxHeight: 256,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _selectedImage = image;
          _selectedFile = null;
        });
      }
    } catch (e) {
      debugPrint("Lỗi khi chọn ảnh: $e");
    }
  }

  // Chọn tập tin/tài liệu khác từ máy
  Future<void> _pickFile() async {
    if (_isUploading) return;
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.single;
          _selectedImage = null;
          _webImageBytes = null;
        });
      }
    } catch (e) {
      debugPrint("Lỗi khi chọn file: $e");
    }
  }

  // Xử lý gửi tin nhắn
  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty && _selectedImage == null && _selectedFile == null) return;

    setState(() => _isUploading = true);

    String? imageUrl;
    String? fileUrl;
    String? fileName;

    try {
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_media')
            .child(widget.chatId)
            .child(
                '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}');

        if (_webImageBytes != null) {
          await storageRef.putData(_webImageBytes!);
        } else {
          await storageRef.putFile(File(_selectedImage!.path));
        }
        imageUrl = await storageRef.getDownloadURL();
      }

      if (_selectedFile != null) {
        fileName = _selectedFile!.name;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_media')
            .child(widget.chatId)
            .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

        if (kIsWeb && _selectedFile!.bytes != null) {
          await storageRef.putData(_selectedFile!.bytes!);
        } else if (_selectedFile!.path != null) {
          await storageRef.putFile(File(_selectedFile!.path!));
        }
        fileUrl = await storageRef.getDownloadURL();
      }

      bool isVN = languageNotifier.value == "Tiếng Việt";
      String lastMsgDisplay = text;
      if (imageUrl != null) lastMsgDisplay = isVN ? '[Hình ảnh]' : '[Image]';
      if (fileUrl != null) {
        lastMsgDisplay = isVN ? '[Tập tin: $fileName]' : '[File: $fileName]';
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUserId,
        'text': text,
        'imageUrl': imageUrl,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'deletedBy': [], // Khởi tạo mảng trống để sau này theo dõi việc xóa
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .set({
        'lastMessage': lastMsgDisplay,
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _msgController.clear();
        _selectedImage = null;
        _webImageBytes = null;
        _selectedFile = null;
        _isUploading = false;
      });
    } catch (e) {
      debugPrint("Lỗi gửi tin nhắn: $e");
      setState(() => _isUploading = false);
    }
  }

  // 🔥 HÀM XÓA 1 TIN NHẮN (CHỈ XÓA BÊN MÌNH)
  Future<void> _deleteMessageForMe(String messageId) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedBy': FieldValue.arrayUnion([widget.currentUserId])
    });
  }

  // 🔥 HÀM XÓA 1 TIN NHẮN (XÓA CẢ 2 PHÍA - CHỈ CHO NGƯỜI GỬI)
  Future<void> _deleteMessageForEveryone(String messageId) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // 🔥 HÀM XÓA TOÀN BỘ LỊCH SỬ TRÒ CHUYỆN (CHỈ XÓA BÊN MÌNH)
  Future<void> _clearChatHistory() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep, color: Colors.red),
            const SizedBox(width: 8),
            Text(isVN ? "Xóa lịch sử" : "Clear History"),
          ],
        ),
        content: Text(
          isVN
              ? "Bạn có chắc muốn xóa toàn bộ tin nhắn không? (Lịch sử chỉ bị xóa ở phía bạn, người kia vẫn có thể thấy)"
              : "Are you sure you want to clear all messages? (Only deleted on your side)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVN ? "Hủy" : "Cancel",
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVN ? "Xóa" : "Clear",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final msgs = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in msgs.docs) {
        batch.update(doc.reference, {
          'deletedBy': FieldValue.arrayUnion([widget.currentUserId])
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isVN ? "Đã xóa lịch sử trò chuyện" : "Chat history cleared"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi xóa lịch sử: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Text(
              widget.targetUserName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 1,
            // 🔥 THÊM NÚT XÓA LỊCH SỬ TRÒ CHUYỆN TRÊN APPBAR
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: isVN ? "Xóa lịch sử trò chuyện" : "Clear chat history",
                onPressed: _clearChatHistory,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          isVN
                              ? "Hãy bắt đầu cuộc trò chuyện!"
                              : "Start the conversation!",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(15),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final msg = doc.data() as Map<String, dynamic>;
                        final messageId = doc.id;
                        final bool isMe =
                            msg['senderId'] == widget.currentUserId;

                        // 🔥 KIỂM TRA XEM TIN NHẮN NÀY ĐÃ BỊ MÌNH XÓA CHƯA
                        final deletedBy =
                            List<String>.from(msg['deletedBy'] ?? []);
                        if (deletedBy.contains(widget.currentUserId)) {
                          return const SizedBox.shrink(); // Ẩn tin nhắn này đi
                        }

                        return _buildMessageBubble(
                            messageId, msg, isMe, context, isVN);
                      },
                    );
                  },
                ),
              ),
              if (_selectedImage != null || _selectedFile != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(top: 5, right: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: _selectedImage != null
                                  ? (_webImageBytes != null
                                      ? Image.memory(_webImageBytes!,
                                          fit: BoxFit.cover)
                                      : Image.file(File(_selectedImage!.path),
                                          fit: BoxFit.cover))
                                  : const Icon(Icons.insert_drive_file,
                                      size: 40, color: Colors.grey),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                  _webImageBytes = null;
                                  _selectedFile = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedImage != null
                              ? _selectedImage!.name
                              : _selectedFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildInputArea(isVN),
            ],
          ),
        );
      },
    );
  }

  // 🔥 ĐÃ CẬP NHẬT: Thêm chức năng Long Press (nhấn giữ) để xóa tin nhắn
  // 🔥 ĐÃ CẬP NHẬT: Thêm chức năng Copy tin nhắn
  Widget _buildMessageBubble(String messageId, Map<String, dynamic> msg,
      bool isMe, BuildContext context, bool isVN) {
    final text = msg['text'] as String? ?? '';
    final imageUrl = msg['imageUrl'] as String?;
    final fileUrl = msg['fileUrl'] as String?;
    final fileName = msg['fileName'] as String? ?? 'File';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          // Bật Menu chức năng khi nhấn giữ tin nhắn
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: Wrap(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      isVN ? "Tùy chọn tin nhắn" : "Message Options",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // 🔥 TÍNH NĂNG MỚI: SAO CHÉP TIN NHẮN
                  if (text.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.copy, color: Colors.blue),
                      title: Text(isVN ? "Sao chép tin nhắn" : "Copy message"),
                      onTap: () async {
                        Navigator.pop(ctx); // Đóng menu
                        await Clipboard.setData(
                            ClipboardData(text: text)); // Copy vào bộ nhớ tạm
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isVN
                                  ? "Đã sao chép tin nhắn"
                                  : "Message copied to clipboard"),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),

                  ListTile(
                    leading:
                        const Icon(Icons.delete_sweep, color: Colors.orange),
                    title: Text(isVN ? "Xóa ở phía tôi" : "Delete for me"),
                    subtitle: Text(
                      isVN
                          ? "Tin nhắn sẽ bị ẩn với bạn"
                          : "Message will be hidden for you",
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteMessageForMe(messageId);
                    },
                  ),
                  // Chỉ cho phép xóa cả 2 phía nếu đó là tin nhắn do mình gửi
                  if (isMe)
                    ListTile(
                      leading:
                          const Icon(Icons.delete_forever, color: Colors.red),
                      title: Text(
                          isVN ? "Thu hồi tin nhắn" : "Delete for everyone"),
                      subtitle: Text(
                        isVN
                            ? "Thu hồi hoàn toàn ở cả 2 bên"
                            : "Remove completely for both sides",
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteMessageForEveryone(messageId);
                      },
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight:
                  isMe ? const Radius.circular(0) : const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(0),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            FullScreenImageViewer(imageUrl: imageUrl)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image,
                                size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              if (fileUrl != null && fileUrl.isNotEmpty)
                InkWell(
                  onTap: () => _downloadFile(fileUrl),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 6.0),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file,
                            color: isMe ? Colors.white : primaryColor),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            fileName,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (text.isNotEmpty)
                Text(
                  text,
                  style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isVN) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.image, color: primaryColor),
              onPressed: _pickImage,
            ),
            IconButton(
              icon: Icon(Icons.attach_file, color: primaryColor),
              onPressed: _pickFile,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _msgController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: isVN ? "Nhập tin nhắn..." : "Type a message...",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _isUploading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                : IconButton(
                    icon: Icon(Icons.send, color: primaryColor),
                    onPressed: _sendMessage,
                  ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () async {
              final Uri url = Uri.parse(imageUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            },
          ),
        ),
      ),
    );
  }
}
