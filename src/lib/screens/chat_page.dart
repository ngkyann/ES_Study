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
import 'dart:async'; // Bắt buộc phải có để hủy lắng nghe Stream khi thoát trang
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _messageSubscription;
  bool _isFirstLoad = true;

  // Tự động mở link tải tài liệu/tập tin về máy
  Future<void> _downloadFile(String fileUrl) async {
    final Uri url = Uri.parse(fileUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocalNotifications(); // Khởi tạo thông báo cục bộ
    _listenForNewMessages(); // Bắt đầu lắng nghe tin nhắn mới
  }

  @override
  void dispose() {
    _messageSubscription?.cancel(); // Hủy lắng nghe khi thoát trang chat
    super.dispose();
  }

  // 🛠️ ĐÃ SỬA: Thêm tên tham số `settings:` khi khởi tạo
  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
  }

  // Hàm âm thầm theo dõi bảng tin nhắn trên Firestore
  void _listenForNewMessages() {
    _messageSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (_isFirstLoad) {
        _isFirstLoad = false;
        return;
      }

      if (snapshot.docChanges.isNotEmpty) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            final senderId = data['senderId'];

            String textBody = data['text'] ?? '';
            if (textBody.isEmpty) {
              if (data['imageUrl'] != null) {
                textBody = '📷 Đã gửi một hình ảnh';
              } else if (data['fileUrl'] != null) {
                textBody = '📁 Đã gửi một tệp đính kèm';
              } else {
                textBody = 'Đã gửi một tin nhắn mới';
              }
            }

            if (senderId != widget.currentUserId) {
              _showNotification(
                title: widget.targetUserName,
                body: textBody,
              );
            }
          }
        }
      }
    });
  }

  // 🛠️ ĐÃ SỬA: Chuyển các tham số của hàm .show() sang dạng có tên (id:, title:, body:, notificationDetails:)
  Future<void> _showNotification(
      {required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_active_channel',
      'Tin nhắn trong ứng dụng',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const platformDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
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
        withData: true,
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
      // 1. Xử lý upload Hình ảnh
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_media')
            .child(widget.chatId)
            .child(
                '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}');

        UploadTask uploadTask;
        if (kIsWeb) {
          if (_webImageBytes != null) {
            uploadTask = storageRef.putData(_webImageBytes!);
          } else {
            throw Exception("Không thể đọc dữ liệu ảnh (bytes null) trên Web");
          }
        } else {
          uploadTask = storageRef.putFile(File(_selectedImage!.path));
        }

        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // 2. Xử lý upload Tập tin/Tài liệu
      if (_selectedFile != null) {
        fileName = _selectedFile!.name;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_media')
            .child(widget.chatId)
            .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

        UploadTask uploadTask;
        if (kIsWeb) {
          if (_selectedFile!.bytes != null) {
            uploadTask = storageRef.putData(_selectedFile!.bytes!);
          } else {
            throw Exception("Không thể đọc dữ liệu file (bytes null) trên Web");
          }
        } else {
          if (_selectedFile!.path != null) {
            uploadTask = storageRef.putFile(File(_selectedFile!.path!));
          } else {
            throw Exception(
                "Không tìm thấy đường dẫn file trên thiết bị di động");
          }
        }

        final snapshot = await uploadTask;
        fileUrl = await snapshot.ref.getDownloadURL();
      }

      bool isVN = languageNotifier.value == "Tiếng Việt";
      String lastMsgDisplay = text;
      if (imageUrl != null) lastMsgDisplay = isVN ? '[Hình ảnh]' : '[Image]';
      if (fileUrl != null) {
        lastMsgDisplay = isVN ? '[Tập tin: $fileName]' : '[File: $fileName]';
      }

      try {
        // 🔥 1. LẤY TÊN MÌNH ĐỂ LƯU VÀO NHÓM VÀ LÀM THÔNG BÁO
        final myDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .get();
        String myName =
            myDoc.data()?['name'] ?? (isVN ? "Một người bạn" : "A friend");

        // 🔥 2. LƯU TIN NHẮN (THÊM TRƯỜNG senderName)
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add({
          'senderId': widget.currentUserId,
          'senderName': myName, // Cần lưu tên để UI biết ai vừa nhắn trong nhóm
          'text': text,
          'imageUrl': imageUrl,
          'fileUrl': fileUrl,
          'fileName': fileName,
          'timestamp': FieldValue.serverTimestamp(),
          'deletedBy': [],
        });

        // 🔥 3. CẬP NHẬT LAST MESSAGE CHO KHUNG CHAT
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .set({
          'lastMessage': widget.chatId.startsWith('group_')
              ? "$myName: $lastMsgDisplay"
              : lastMsgDisplay,
          'lastTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 🔥 4. ĐẨY THÔNG BÁO VÀ CẬP NHẬT TAB TƯƠNG ỨNG
        if (widget.chatId.startsWith('group_')) {
          // --- LOGIC DÀNH CHO NHÓM ---
          final groupDoc = await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.chatId)
              .get();
          List<dynamic> members = groupDoc.data()?['members'] ?? [];
          String groupName = groupDoc.data()?['groupName'] ?? "Nhóm";

          // Cập nhật Last Message lên Tab Nhóm
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.chatId)
              .update({
            'lastMessage': "$myName: $lastMsgDisplay",
          });

          // Gửi Push Notification cho từng thành viên (Trừ mình)
          for (String memberId in members) {
            if (memberId != widget.currentUserId) {
              await FirebaseFirestore.instance
                  .collection('notifications')
                  .doc('chat_notif_${widget.chatId}_$memberId')
                  .set({
                'userId': memberId,
                'content_vn':
                    "💬 $myName đã nhắn trong nhóm $groupName : $lastMsgDisplay",
                'content_en':
                    "💬 $myName messaged in $groupName : $lastMsgDisplay",
                'createdAt': FieldValue.serverTimestamp(),
                'isRead': false,
              });
            }
          }
        } else {
          // --- LOGIC DÀNH CHO CHAT 1-1 ---
          List<String> ids = widget.chatId.split('_');
          String targetUserId =
              ids.first == widget.currentUserId ? ids.last : ids.first;

          await FirebaseFirestore.instance
              .collection('notifications')
              .doc('chat_notif_${widget.chatId}_$targetUserId')
              .set({
            'userId': targetUserId,
            'content_vn':
                "💬 $myName đã gửi cho bạn 1 tin nhắn mới: $lastMsgDisplay",
            'content_en': "💬 $myName sent you a new message: $lastMsgDisplay",
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      } catch (e) {
        debugPrint("Lỗi gửi tin/tạo thông báo: $e");
      }

      // Xóa form sau khi gửi thành công
      setState(() {
        _msgController.clear();
        _selectedImage = null;
        _webImageBytes = null;
        _selectedFile = null;
        _isUploading = false;
      });
    } catch (e) {
      debugPrint("Lỗi xử lý file/ảnh: $e");
      setState(() => _isUploading = false);
    }
  }

  // HÀM XÓA 1 TIN NHẮN (CHỈ XÓA BÊN MÌNH)
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

  // HÀM XÓA 1 TIN NHẮN (XÓA CẢ 2 PHÍA - CHỈ CHO NGƯỜI GỬI)
  Future<void> _deleteMessageForEveryone(String messageId) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // HÀM XÓA TOÀN BỘ LỊST SỬ TRÒ CHUYỆN (CHỈ XÓA BÊN MÌNH)
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

// =========================================================
  // 🔥 KHỐI HÀM QUẢN LÝ NHÓM (THÊM THÀNH VIÊN, CHUYỂN QUYỀN, RỜI NHÓM)
  // =========================================================
  Future<void> _showGroupSettings() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.chatId)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    String leaderId = data['leaderId'] ?? '';
    List<String> members = List<String>.from(data['members'] ?? []);
    bool isLeader = widget.currentUserId == leaderId;

    if (!mounted) return;
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return SafeArea(
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(isVN ? "Quản lý nhóm" : "Group Settings",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: Icon(
                    Icons.people,
                    color: primaryColor,
                  ),
                  title: Text(isVN ? "Thành viên" : "Members"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMembersDialog();
                  },
                ),
                if (isLeader)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz, color: Colors.orange),
                    title: Text(
                        isVN ? "Chuyển nhóm trưởng" : "Transfer ownership"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTransferLeaderDialog(members, leaderId);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.blue),
                  title: Text(isVN ? "Mời thêm bạn bè" : "Add members"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddMemberDialog(members);
                  },
                ),
                if (isLeader)
                  ListTile(
                    leading:
                        const Icon(Icons.delete_forever, color: Colors.red),
                    title: Text(isVN ? "Giải tán nhóm" : "Delete group"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteGroup();
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: Text(isVN ? "Rời nhóm" : "Leave group"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _leaveGroup();
                    },
                  ),
                const SizedBox(height: 10),
              ],
            ),
          );
        });
  }

  Future<void> _showAddMemberDialog(List<String> currentMembers) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .get();
    List<String> myFriends = List<String>.from(myDoc.data()?['friends'] ?? []);
    // Chỉ hiện những người bạn CHƯA có trong nhóm
    List<String> availableFriends =
        myFriends.where((f) => !currentMembers.contains(f)).toList();

    if (availableFriends.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isVN
                ? "Tất cả bạn bè đã ở trong nhóm!"
                : "All friends are already in the group!")));
      return;
    }

    List<String> selectedToAdd = [];
    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
                title: Text(isVN ? "Thêm thành viên" : "Add members"),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableFriends.length,
                    itemBuilder: (context, index) {
                      String fId = availableFriends[index];
                      return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(fId)
                              .get(),
                          builder: (context, snap) {
                            if (!snap.hasData) return const SizedBox.shrink();
                            String fName = snap.data!.get('name') ?? 'Unknown';
                            bool isSelected = selectedToAdd.contains(fId);
                            return CheckboxListTile(
                              title: Text(fName),
                              value: isSelected,
                              onChanged: (val) {
                                setDialogState(() {
                                  val == true
                                      ? selectedToAdd.add(fId)
                                      : selectedToAdd.remove(fId);
                                });
                              },
                            );
                          });
                    },
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isVN ? "Hủy" : "Cancel")),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedToAdd.isEmpty) return;
                      await FirebaseFirestore.instance
                          .collection('groups')
                          .doc(widget.chatId)
                          .update({
                        'members': FieldValue.arrayUnion(
                            selectedToAdd) // Thêm vào Database
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isVN
                                ? "Đã thêm thành viên!"
                                : "Members added!"),
                            backgroundColor: Colors.green));
                    },
                    child: Text(isVN ? "Thêm" : "Add"),
                  )
                ]);
          });
        });
  }

  Future<void> _showTransferLeaderDialog(
      List<String> members, String currentLeader) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    List<String> otherMembers =
        members.where((m) => m != currentLeader).toList();

    if (otherMembers.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isVN ? "Nhóm chỉ có mình bạn!" : "You are the only member!")));
      return;
    }

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
              title: Text(isVN ? "Chọn nhóm trưởng mới" : "Select new leader"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: otherMembers.length,
                  itemBuilder: (context, index) {
                    String mId = otherMembers[index];
                    return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(mId)
                            .get(),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox.shrink();
                          String mName = snap.data!.get('name') ?? 'Unknown';
                          return ListTile(
                            title: Text(mName),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () async {
                              await FirebaseFirestore.instance
                                  .collection('groups')
                                  .doc(widget.chatId)
                                  .update({
                                'leaderId': mId // Đổi nhóm trưởng
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(isVN
                                            ? "Đã chuyển quyền nhóm trưởng!"
                                            : "Leadership transferred!"),
                                        backgroundColor: Colors.green));
                            },
                          );
                        });
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(isVN ? "Đóng" : "Close")),
              ]);
        });
  }

  Future<void> _deleteGroup() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: Text(isVN ? "Giải tán nhóm?" : "Delete group?"),
                    content: Text(isVN
                        ? "Nhóm sẽ bị xóa vĩnh viễn."
                        : "Group will be permanently deleted."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(isVN ? "Hủy" : "Cancel")),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(isVN ? "Giải tán" : "Delete",
                              style: const TextStyle(color: Colors.white))),
                    ])) ??
        false;

    if (!confirm) return;

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.chatId)
        .delete();
    if (mounted) Navigator.pop(context); // Bị giải tán thì văng ra ngoài
  }

  Future<void> _leaveGroup() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: Text(isVN ? "Rời nhóm?" : "Leave group?"),
                    content: Text(isVN
                        ? "Bạn sẽ không thể xem tin nhắn nhóm nữa."
                        : "You will no longer see group messages."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(isVN ? "Hủy" : "Cancel")),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(isVN ? "Rời đi" : "Leave",
                              style: const TextStyle(color: Colors.white))),
                    ])) ??
        false;

    if (!confirm) return;

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.chatId)
        .update({
      'members': FieldValue.arrayRemove(
          [widget.currentUserId]) // Xóa mình khỏi mảng members
    });

    if (mounted) Navigator.pop(context); // Rời xong thì văng ra ngoài
  }

// =========================================================
  // HÀM HIỂN THỊ HỘP THOẠI DANH SÁCH THÀNH VIÊN
  // =========================================================
  void _showMembersDialog() {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            isVN ? "Thành viên nhóm" : "Group Members",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<DocumentSnapshot>(
              // 🔥 ĐÃ SỬA: Lắng nghe chính xác collection 'groups'
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.chatId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Text(isVN
                      ? "Không tìm thấy dữ liệu nhóm"
                      : "Group data not found");
                }

                var groupData = snapshot.data!.data() as Map<String, dynamic>;
                List<dynamic> members = groupData['members'] ?? [];

                // 🔥 ĐÃ SỬA: Đồng bộ tên biến trưởng nhóm là 'leaderId'
                String leaderId = groupData['leaderId'] ?? '';

                // Kiểm tra xem người dùng hiện tại có phải nhóm trưởng không
                bool isMeLeader = widget.currentUserId == leaderId;

                if (members.isEmpty) {
                  return Text(
                      isVN ? "Nhóm chưa có thành viên" : "No members in group");
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    String memberId = members[index];
                    bool isMemberLeader = memberId == leaderId;

                    // Lấy thông tin chi tiết từng thành viên từ collection 'users'
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(memberId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(title: Text("..."));
                        }

                        var userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;

                        // 🔥 ĐÃ SỬA: Đồng bộ gọi trường 'name' từ file bạn bè
                        String memberName = userData?['name'] ??
                            userData?['userName'] ??
                            "User";
                        String avatarUrl = userData?['avatarUrl'] ?? '';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.1),
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? Icon(Icons.person, color: primaryColor)
                                : null,
                          ),
                          title: Text(
                            memberId == widget.currentUserId
                                ? "$memberName (${isVN ? "Bạn" : "You"})"
                                : memberName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: isMemberLeader
                              ? Text(
                                  isVN ? "Trưởng nhóm" : "Leader",
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                )
                              : null,
                          // Nút xóa thành viên: Chỉ hiển thị nếu Mình là trưởng nhóm VÀ người này không phải là mình
                          trailing: (isMeLeader && !isMemberLeader)
                              ? IconButton(
                                  icon: const Icon(Icons.person_remove,
                                      color: Colors.redAccent),
                                  onPressed: () {
                                    _confirmKickMember(memberId, memberName);
                                  },
                                )
                              : null,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isVN ? "Đóng" : "Close",
                  style: TextStyle(color: primaryColor)),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // HÀM TIẾN HÀNH XÓA THÀNH VIÊN KHỎI NHÓM
  // =========================================================
  Future<void> _confirmKickMember(String memberId, String memberName) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.person_remove,
              color: Colors.redAccent,
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVN ? "Xác nhận xóa" : "Confirm Remove",
              ),
            ),
          ],
        ),
        content: Text(
          isVN
              ? "Bạn có chắc chắn muốn mời $memberName ra khỏi nhóm không?"
              : "Are you sure you want to remove $memberName from the group?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isVN ? "Hủy" : "Cancel",
                style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isVN ? "Xóa" : "Remove",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 🔥 ĐÃ SỬA: Đồng bộ xóa member ở collection 'groups'
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.chatId)
            .update({
          'members': FieldValue.arrayRemove([memberId])
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isVN
                    ? "Đã xóa thành công $memberName"
                    : "Successfully removed $memberName",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(isVN ? "Có lỗi xảy ra: $e" : "An error occurred: $e"),
                backgroundColor: Colors.red),
          );
        }
      }
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
            actions: [
              if (widget.chatId.startsWith('group_'))
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: isVN ? "Quản lý nhóm" : "Group settings",
                  onPressed: _showGroupSettings,
                ),
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

                        final deletedBy =
                            List<String>.from(msg['deletedBy'] ?? []);
                        if (deletedBy.contains(widget.currentUserId)) {
                          return const SizedBox.shrink();
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
                                  ? (kIsWeb
                                      ? (_webImageBytes != null
                                          ? Image.memory(_webImageBytes!,
                                              fit: BoxFit.cover)
                                          : const Center(
                                              child:
                                                  CircularProgressIndicator()))
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
                  if (text.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.copy, color: Colors.blue),
                      title: Text(isVN ? "Sao chép tin nhắn" : "Copy message"),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Clipboard.setData(ClipboardData(text: text));
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
              if (!isMe && widget.chatId.startsWith('group_'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    msg['senderName'] ?? "Thành viên",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: primaryColor.withOpacity(0.8),
                    ),
                  ),
                ),
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

  void _showAttachmentOptions(BuildContext context, bool isVN) {
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
                isVN ? "Gửi đính kèm" : "Send attachment",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(Icons.image, color: primaryColor),
              title: Text(isVN ? "Gửi hình ảnh" : "Send image"),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file, color: primaryColor),
              title: Text(isVN ? "Gửi tập tin" : "Send file"),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile();
              },
            ),
            const SizedBox(height: 10),
          ],
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
              icon: Icon(Icons.add, color: primaryColor, size: 28),
              onPressed: () => _showAttachmentOptions(context, isVN),
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
