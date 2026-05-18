import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
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
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  // 🔥 HÀM MỚI: Tự động mở link để tải file về máy
  Future<void> _downloadFile(String fileUrl) async {
    final Uri url = Uri.parse(fileUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw languageNotifier.value == "Tiếng Việt"
            ? 'Không thể mở liên kết tải file.'
            : 'Cannot open the download link.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(languageNotifier.value == "Tiếng Việt"
                  ? "Lỗi khi tải file: $e"
                  : "Error downloading file: $e")),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isUploading) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
          _selectedFile = null; // Xóa file nếu chọn ảnh
        });
      }
    } catch (e) {
      debugPrint("Lỗi chọn ảnh: $e");
    }
  }

  Future<void> _pickFile() async {
    if (_isUploading) return;
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt'
        ],
        withData: true, // 🔥 BẮT BUỘC THÊM DÒNG NÀY ĐỂ TRÁNH LỖI ĐỌC FILE
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          _selectedImage = null;
        });
      }
    } catch (e) {
      debugPrint("Lỗi chọn file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(languageNotifier.value == "Tiếng Việt"
                  ? "Không thể chọn file"
                  : "Cannot pick file")),
        );
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.lightBlue),
                title: Text(languageNotifier.value == "Tiếng Việt"
                    ? 'Gửi hình ảnh'
                    : 'Send image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.insert_drive_file, color: Colors.orange),
                title: Text(languageNotifier.value == "Tiếng Việt"
                    ? 'Gửi tài liệu'
                    : 'Send document'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();

    if (text.isEmpty && _selectedImage == null && _selectedFile == null) return;
    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      String? fileUrl;
      String? fileName;
      String msgType = 'text';

      if (_selectedImage != null) {
        final XFile imageToUpload = _selectedImage!;
        setState(() => _selectedImage = null);

        Uint8List imageData = await imageToUpload.readAsBytes();
        fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('chat_images/${widget.chatId}/$fileName');

        TaskSnapshot snapshot = await ref.putData(
            imageData, SettableMetadata(contentType: 'image/jpeg'));
        fileUrl = await snapshot.ref.getDownloadURL();
        msgType = 'image';
      } else if (_selectedFile != null) {
        final PlatformFile fileToUpload = _selectedFile!;
        setState(() => _selectedFile = null);

        fileName = fileToUpload.name;

        // 🔥 Đọc byte an toàn không dùng dấu !
        Uint8List? fileBytes = fileToUpload.bytes;
        if (fileBytes == null && !kIsWeb && fileToUpload.path != null) {
          fileBytes = await File(fileToUpload.path!).readAsBytes();
        }

        if (fileBytes == null)
          throw Exception(languageNotifier.value == "Tiếng Việt"
              ? "Hệ thống không thể đọc tệp này."
              : "System cannot read this file.");

        String uniqueFileName =
            '${DateTime.now().millisecondsSinceEpoch}_$fileName';
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('chat_files/${widget.chatId}/$uniqueFileName');

        TaskSnapshot snapshot = await ref.putData(fileBytes);
        fileUrl = await snapshot.ref.getDownloadURL();
        msgType = 'file';
      }

      _msgController.clear();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUserId,
        'text': text,
        'imageUrl':
            msgType == 'image' ? (fileUrl ?? '') : '', // 🔥 Thêm lại dòng này
        'fileUrl': fileUrl ?? '',
        'fileName': fileName ?? '',
        'type': msgType,
        'timestamp': FieldValue.serverTimestamp(),
        'deletedBy': [],
      });

      setState(() => _isUploading = false);
    } catch (e) {
      debugPrint("Lỗi khi gửi tin nhắn: $e");
      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageNotifier.value == "Tiếng Việt"
                ? "Lỗi: ${e.toString().replaceAll('Exception: ', '')}"
                : "Error: ${e.toString().replaceAll('Exception: ', '')}"),
          ),
        );
      }
    }
  }

  Future<void> _clearChatHistory() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(isVN ? "Xoá trò chuyện?" : "Delete chat?"),
          ],
        ),
        content: Text(
          isVN
              ? "Lịch sử trò chuyện chỉ bị xoá ở phía bạn, người kia vẫn sẽ nhìn thấy. Bạn có chắc chắn không?"
              : "Chat history will only be deleted on your side, the other person will still see it. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isVN ? "Huỷ" : "Cancel",
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isVN ? "Xoá" : "Delete",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {
        'deletedBy': FieldValue.arrayUnion([widget.currentUserId]),
      });
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isVN ? "Đã xoá lịch sử trò chuyện!" : "Chat history deleted!")),
      );
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
              actions: [
                IconButton(
                  tooltip:
                      isVN ? "Xoá lịch sử trò chuyện" : "Delete chat history",
                  icon: const Icon(Icons.delete_outline),
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            isVN
                                ? "Chưa có tin nhắn. Hãy nói xin chào!"
                                : "No messages yet. Say hello!",
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final allMessages = snapshot.data!.docs;

                      final visibleMessages = allMessages.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final deletedBy =
                            List<String>.from(data['deletedBy'] ?? []);
                        return !deletedBy.contains(widget.currentUserId);
                      }).toList();

                      if (visibleMessages.isEmpty) {
                        return Center(
                          child: Text(
                            isVN
                                ? "Chưa có tin nhắn. Hãy nói xin chào!"
                                : "No messages yet. Say hello!",
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 20,
                        ),
                        itemCount: visibleMessages.length,
                        itemBuilder: (context, index) {
                          final data = visibleMessages[index].data()
                              as Map<String, dynamic>;
                          bool isMe = data['senderId'] == widget.currentUserId;

                          // 🔥 Đọc link gom chung để tương thích dữ liệu cũ và mới
                          String linkUrl =
                              data['fileUrl'] ?? data['imageUrl'] ?? '';

                          bool isImage =
                              data['type'] == 'image' && linkUrl.isNotEmpty;
                          bool isFile =
                              data['type'] == 'file' && linkUrl.isNotEmpty;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: isImage &&
                                      (data['text'] == null ||
                                          data['text']
                                              .toString()
                                              .trim()
                                              .isEmpty)
                                  ? const EdgeInsets.all(5)
                                  : const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? primaryColor.withOpacity(0.2)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: isMe
                                      ? const Radius.circular(20)
                                      : const Radius.circular(5),
                                  bottomRight: isMe
                                      ? const Radius.circular(5)
                                      : const Radius.circular(20),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 1. HIỂN THỊ ẢNH
                                  if (isImage)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FullScreenImageViewer(
                                                    imageUrl: linkUrl),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          maxHeight: 300,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            isImage &&
                                                    (data['text'] == null ||
                                                        data['text']
                                                            .toString()
                                                            .trim()
                                                            .isEmpty)
                                                ? 15
                                                : 8,
                                          ),
                                          child: Image.network(
                                            linkUrl,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return const Padding(
                                                  padding: EdgeInsets.all(20),
                                                  child:
                                                      CircularProgressIndicator());
                                            },
                                          ),
                                        ),
                                      ),
                                    ),

                                  // 2. HIỂN THỊ TÀI LIỆU (FILE)
                                  if (isFile)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      // 🔥 SỰ KIỆN CLICK: Gọi hàm tải file về thiết bị
                                      onTap: () => _downloadFile(linkUrl),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.black.withOpacity(0.05)
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border:
                                              Border.all(color: Colors.black12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.insert_drive_file,
                                              color: isMe
                                                  ? primaryColor
                                                  : Colors.orangeAccent,
                                              size: 32,
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Text(
                                                data['fileName'] ??
                                                    (isVN
                                                        ? 'Tài liệu Văn phòng'
                                                        : 'Office Document'),
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.black87
                                                      : Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration
                                                      .underline, // Tạo gạch chân giống link tải
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Icon(
                                              Icons
                                                  .download_for_offline_outlined, // Thêm icon download nhỏ cho trực quan
                                              size: 20,
                                              color: isMe
                                                  ? primaryColor
                                                  : Colors.grey,
                                            )
                                          ],
                                        ),
                                      ),
                                    ),

                                  // 3. HIỂN THỊ CHỮ CHAT
                                  if (data['text'] != null &&
                                      data['text'].toString().trim().isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: (isImage || isFile) ? 8.0 : 0),
                                      child: Text(
                                        data['text'],
                                        style: TextStyle(
                                            fontSize: 15,
                                            color: isMe
                                                ? Colors.black87
                                                : Colors.black),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedFile != null)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8, right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.insert_drive_file,
                                    color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedFile!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () =>
                                      setState(() => _selectedFile = null),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: primaryColor,
                              size: 28,
                            ),
                            onPressed:
                                _isUploading ? null : _showAttachmentMenu,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              decoration: InputDecoration(
                                hintText: isVN
                                    ? "Nhập tin nhắn..."
                                    : "Type a message...",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: primaryColor,
                            child: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: 20,
                                    ),
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

// 🔥 WIDGET MỚI: Xem ảnh toàn màn hình giống Zalo
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
              // Có thể tích hợp tải ảnh về máy ở đây nếu muốn, tạm thời mở bằng trình duyệt để tải
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
          // Cho phép người dùng zoom bằng 2 ngón tay
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
