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
  Uint8List?
      _webImageBytes; // Lưu trữ byte ảnh phục vụ hiển thị preview mượt mà trên cả Web & Mobile
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  // Tự động mở link tải tài liệu/tập tin về máy
  Future<void> _downloadFile(String fileUrl) async {
    final Uri url = Uri.parse(fileUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // Chọn ảnh từ bộ sưu tập (Sửa lỗi hiển thị và load ảnh bằng cách đọc bytes trực tiếp)
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

  // Xử lý gửi tin nhắn (Bao gồm cả Chữ, Ảnh, File cho cả Web & Mobile)
  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty && _selectedImage == null && _selectedFile == null) return;

    setState(() => _isUploading = true);

    String? imageUrl;
    String? fileUrl;
    String? fileName;

    try {
      // 1. Upload ảnh lên Firebase Storage nếu có ảnh được chọn (Sửa đổi dùng putData để chạy ổn định hơn)
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

      // 2. Upload tài liệu/tập tin lên Firebase Storage nếu có file được chọn
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

      // 3. Đẩy gói dữ liệu tin nhắn lên Firestore
      bool isVN = languageNotifier.value == "Tiếng Việt";
      String lastMsgDisplay = text;
      if (imageUrl != null) lastMsgDisplay = isVN ? '[Hình ảnh]' : '[Image]';
      if (fileUrl != null)
        lastMsgDisplay = isVN ? '[Tập tin: $fileName]' : '[File: $fileName]';

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
      });

      // Cập nhật dữ liệu tin nhắn cuối cùng để hiển thị ngoài danh sách chat nhóm/bạn bè
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .set({
        'lastMessage': lastMsgDisplay,
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Dọn dẹp dữ liệu tạm thời sau khi gửi thành công
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
          ),
          body: Column(
            children: [
              // Khu vực hiển thị nội dung cuộc trò chuyện cuộc hội thoại
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
                        final msg = docs[index].data() as Map<String, dynamic>;
                        final bool isMe =
                            msg['senderId'] == widget.currentUserId;

                        return _buildMessageBubble(msg, isMe, context);
                      },
                    );
                  },
                ),
              ),

              // --- KHU VỰC HIỂN THỊ XEM TRƯỚC HÌNH ẢNH HOẶC TẬP TIN ĐÃ CHỌN ---
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

              // Thanh công cụ nhập nội dung và các nút gửi dữ liệu
              _buildInputArea(isVN),
            ],
          ),
        );
      },
    );
  }

  // Widget vẽ Bong bóng tin nhắn
  Widget _buildMessageBubble(
      Map<String, dynamic> msg, bool isMe, BuildContext context) {
    final text = msg['text'] as String? ?? '';
    final imageUrl = msg['imageUrl'] as String?;
    final fileUrl = msg['fileUrl'] as String?;
    final fileName = msg['fileName'] as String? ?? 'File';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
            // Hiển thị ảnh nếu có gửi ảnh
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
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ),

            // Hiển thị tập tin nếu có gửi File tài liệu
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

            // Hiển thị Văn bản chữ
            if (text.isNotEmpty)
              Text(
                text,
                style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87, fontSize: 15),
              ),
          ],
        ),
      ),
    );
  }

  // Giao diện Thanh nhập dữ liệu chat dưới cùng
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

// Lớp xem hình ảnh phóng to toàn màn hình
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
