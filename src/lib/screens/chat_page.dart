import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:esstudy/constants/colors.dart';
import 'dart:io';

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
  bool _isUploading = false;

  Future<void> _pickImage() async {
    if (_isUploading) return; // Không cho chọn ảnh khi đang upload
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75, // Giảm chất lượng xuống 75%
        maxWidth: 1024,   // 🔥 TỐI ƯU: Giới hạn chiều rộng tối đa
        maxHeight: 1024,  // 🔥 TỐI ƯU: Giới hạn chiều cao tối đa
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      debugPrint("Lỗi chọn ảnh: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không thể mở thư viện ảnh")),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();

    // Kiểm tra nếu không có cả chữ lẫn ảnh hoặc đang upload thì dừng
    if (text.isEmpty && _selectedImage == null) return;
    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      String? imageUrl;

      if (_selectedImage != null) {
        // Sao chép thông tin ảnh ra biến tạm và clear UI preview ngay để giải phóng RAM
        final XFile imageToUpload = _selectedImage!;
        setState(() {
          _selectedImage = null; 
        });

        Uint8List imageData = await imageToUpload.readAsBytes();
        
        // Tạo tên file duy nhất kèm đuôi .jpg
        String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

        Reference ref = FirebaseStorage.instance.ref().child(
              'chat_images/${widget.chatId}/$fileName',
            );

        // Upload dữ liệu dưới dạng byte (Hỗ trợ tốt cho cả Web và Mobile)
        UploadTask uploadTask = ref.putData(
          imageData,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // Xóa chữ ở ô nhập liệu sau khi upload ảnh hoàn tất (hoặc song song)
      _msgController.clear();

      // Lưu thông tin vào Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUserId,
        'text': text,
        'imageUrl': imageUrl ?? '',
        'type': imageUrl != null ? 'image' : 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'deletedBy': [],
      });

      setState(() => _isUploading = false);
    } catch (e) {
      debugPrint("Lỗi khi gửi tin nhắn: $e");
      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không thể gửi tin nhắn. Vui lòng thử lại!"),
          ),
        );
      }
    }
  }

  Future<void> _clearChatHistory() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Xoá trò chuyện?"),
          ],
        ),
        content: const Text(
          "Lịch sử trò chuyện chỉ bị xoá ở phía bạn, người kia vẫn sẽ nhìn thấy. Bạn có chắc chắn không?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Huỷ", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xoá", style: TextStyle(color: Colors.white)),
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
        const SnackBar(content: Text("Đã xoá lịch sử trò chuyện!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            tooltip: "Xoá lịch sử trò chuyện",
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
                  return const Center(
                    child: Text(
                      "Chưa có tin nhắn. Hãy nói xin chào!",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final allMessages = snapshot.data!.docs;

                final visibleMessages = allMessages.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final deletedBy = List<String>.from(data['deletedBy'] ?? []);
                  return !deletedBy.contains(widget.currentUserId);
                }).toList();

                if (visibleMessages.isEmpty) {
                  return const Center(
                    child: Text(
                      "Chưa có tin nhắn. Hãy nói xin chào!",
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
                    final data =
                        visibleMessages[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == widget.currentUserId;
                    bool isImage = data['type'] == 'image' &&
                        data['imageUrl'] != null &&
                        data['imageUrl'].toString().isNotEmpty;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: isImage &&
                                (data['text'] == null ||
                                    data['text'].toString().trim().isEmpty)
                            ? const EdgeInsets.all(5)
                            : const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
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
                          boxShadow: [
                            if (!isMe)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        // 🔥 FIX: Hỗ trợ hiển thị cả ảnh và chữ trong cùng một tin nhắn
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isImage)
                              ClipRRect(
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
                                  data['imageUrl'],
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                ),
                              ),
                            if (data['text'] != null &&
                                data['text'].toString().trim().isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: isImage ? 8.0 : 0,
                                ),
                                child: Text(
                                  data['text'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isMe ? Colors.black87 : Colors.black,
                                  ),
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
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          // 🔥 FIX: Thay đổi cách render ảnh local để tránh tràn RAM gây crash
                          child: kIsWeb
                              ? Image.network(
                                  _selectedImage!.path,
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_selectedImage!.path),
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImage = null),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                      onPressed: _pickImage,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        decoration: InputDecoration(
                          hintText: "Nhập tin nhắn...",
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
  }
}
