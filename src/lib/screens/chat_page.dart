import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';

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

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
          'senderId': widget.currentUserId,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'deletedBy': [], // 🔥 ĐÃ THÊM: Mảng trống mặc định khi tạo tin nhắn
        });
  }

  // 🔥 ĐÃ THÊM: Hàm xử lý xoá lịch sử trò chuyện từ 1 bên
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
          "Lịch sử trò chuyện sẽ bị xoá ở phía bạn, nhưng người kia vẫn sẽ nhìn thấy. Bạn có chắc chắn không?",
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

    // Lấy tất cả tin nhắn trong phòng chat này
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .get();

    // Dùng Batch để cập nhật hàng loạt cho tối ưu hiệu suất
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {
        // Thêm ID của mình vào danh sách những người đã xoá tin nhắn này
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
          // 🔥 ĐÃ THÊM: Nút thùng rác trên góc phải
          IconButton(
            tooltip: "Xoá lịch sử trò chuyện",
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChatHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // KHU VỰC HIỂN THỊ TIN NHẮN
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

                // 🔥 LỌC TIN NHẮN: Chỉ giữ lại những tin CHƯA BỊ MÌNH XOÁ
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
                  reverse: true, // Cuộn từ dưới lên như Messenger
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 20,
                  ),
                  itemCount: visibleMessages.length,
                  itemBuilder: (context, index) {
                    final data =
                        visibleMessages[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == widget.currentUserId;

                    return Align(
                      alignment: isMe
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
                        child: Text(
                          data['text'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            color: isMe ? Colors.black87 : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // KHU VỰC NHẬP TIN NHẮN
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
            child: Row(
              children: [
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
    );
  }
}
