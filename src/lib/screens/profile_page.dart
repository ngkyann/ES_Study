import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Mới thêm
import 'package:image_picker/image_picker.dart'; // Mới thêm
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/settings_page.dart';
import 'package:dio/dio.dart'; // Thêm để dùng cho chức năng tải ảnh, nếu chưa có hãy chạy: flutter pub add dio path_provider gallery_saver
import 'package:path_provider/path_provider.dart';// Thư viện để lưu ảnh vào bộ sưu tập
import 'package:gal/gal.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;


class ProfilePage extends StatefulWidget {
  final String userName;
  final String userId;
  final String selectedClass;
  final String email;
  final int userPoints;
  final int userStreak;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
    required this.email,
    required this.userPoints,
    required this.userStreak,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false; // Trạng thái loading khi upload ảnh

  // --- HÀM 1: CHỌN VÀ UPLOAD ẢNH ---
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('${widget.userId}.jpg');

      // Upload dùng Bytes để chạy được cả Web và Android
      final bytes = await image.readAsBytes();
      await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      // Lấy URL sau khi upload thành công
      String downloadUrl = await storageRef.getDownloadURL();

      // Lưu URL vào Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'avatarUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã đổi ảnh đại diện thành công!")),
        );
      }
    } catch (e) {
      debugPrint("Lỗi upload: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi upload: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- HÀM 2: DOWNLOAD (CHỈ CHẠY KHI CÓ URL) ---
  Future<void> _saveImageUrlToGallery(String? url) async {
    // 1. Kiểm tra xem user đã có ảnh trên server chưa
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bạn chưa có ảnh đại diện để tải về. Hãy đổi ảnh trước nhé!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đang chuẩn bị tải ảnh...")),
      );

      if (kIsWeb) {
        // --- XỬ LÝ CHO WEB (LAPTOP) ---
        // Sử dụng universal_html để tạo lệnh tải xuống của trình duyệt
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "avatar_${widget.userId}.jpg")
          ..click();
          
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ảnh đang được tải xuống trình duyệt!")),
        );
      } else {
        // --- XỬ LÝ CHO MOBILE (ANDROID/IOS) ---
        // 1. Lấy đường dẫn thư mục tạm
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/avatar_download.jpg';

        // 2. Dùng Dio tải ảnh từ URL về file tạm đó
        await Dio().download(url, path);

        // 3. Kiểm tra quyền truy cập thư viện ảnh
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }

        // 4. Lưu file đó vào Bộ sưu tập (Gallery)
        await Gal.putImage(path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đã lưu ảnh thành công vào Bộ sưu tập!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải ảnh: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể tải ảnh: $e")),
        );
      }
    }
  }



  // --- HÀM 3: HIỂN THỊ MENU OPTION KHI CLICK VÀO AVA ---
  void _showAvatarOptionsMenu(BuildContext context, String? currentAvatarUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Tùy chọn ảnh đại diện",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.blue),
                title: const Text('Lưu ảnh về máy'),
                onTap: () {
                  Navigator.of(context).pop(); // Đóng menu
                  _saveImageUrlToGallery(currentAvatarUrl); // Gọi hàm lưu ảnh
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.orange),
                title: const Text('Đổi ảnh đại diện mới'),
                onTap: () {
                  Navigator.of(context).pop(); // Đóng menu
                  _pickAndUploadImage(); // Gọi hàm đổi ảnh
                },
              ),
              // Thêm option xóa ảnh nếu cần
              if (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Xóa ảnh hiện tại (về mặc định)'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      setState(() => _isUploading = true);
                      // Xóa file trên Storage
                      await FirebaseStorage.instance
                          .ref()
                          .child('avatars')
                          .child('${widget.userId}.jpg')
                          .delete();
                      
                      // Cập nhật Firestore về null
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.userId)
                          .update({'avatarUrl': null});
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Đã xóa ảnh đại diện.")),
                        );
                      }
                    } catch (e) {
                       // Nếu file không tồn tại trên storage thì chỉ cần cập nhật firestore
                       await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.userId)
                          .update({'avatarUrl': null});
                    } finally {
                      if (mounted) setState(() => _isUploading = false);
                    }
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Hồ sơ cá nhân",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      userName: widget.userName,
                      selectedClass: widget.selectedClass,
                      userId: widget.userId,
                      email: widget.email,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: Colors.white,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String currentName = widget.userName;
                    String? avatarUrl;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      currentName = data['name'] ?? widget.userName;
                      avatarUrl = data['avatarUrl']; // Lấy URL ảnh từ Firestore
                    }

                    return Column(
                      children: [
                        // --- PHẦN CẬP NHẬT CHÍNH: HIỂN THỊ AVATAR VÀ XỬ LÝ CLICK ---
                        GestureDetector(
                          onTap: () => _showAvatarOptionsMenu(context, avatarUrl), // Click mở menu
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Vòng tròn chứa ảnh
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    )
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white,
                                  // Kiểm tra và hiển thị ảnh mạng hoặc ảnh mặc định
                                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? NetworkImage(avatarUrl) // Dùng ảnh từ Firebase
                                      : null, 
                                  child: (avatarUrl == null || avatarUrl.isEmpty)
                                      ? Icon(
                                          Icons.person,
                                          color: primaryColor,
                                          size: 50,
                                        ) // Hiển thị icon mặc định nếu không có ảnh
                                      : null,
                                ),
                              ),
                              // Hiển thị vòng loading khi đang upload
                              if (_isUploading)
                                const Positioned.fill(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              // Icon nhỏ báo hiệu có thể đổi ảnh
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.orangeAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        Text(
                          currentName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        Text(
                          "@${widget.userId}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Chuỗi ${widget.userStreak} ngày học",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // ... Giữ nguyên phần body bên dưới (các thẻ infoCard) ...
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoCard(
                      Icons.alternate_email,
                      "ID người dùng",
                      "@${widget.userId}",
                    ),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .orderBy('points', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String rankText = "Đang tải...";
                        if (snapshot.hasData) {
                          final docs = snapshot.data!.docs;
                          int myRank = 0;
                          for (int i = 0; i < docs.length; i++) {
                            if (docs[i].id == widget.userId) {
                              myRank = i + 1;
                              break;
                            }
                          }

                          if (myRank == 1) {
                            rankText = "🥇 Hạng 1 (Quán quân)";
                          } else if (myRank >= 2 && myRank <= 10) {
                            rankText = "🥈 Hạng $myRank (Top 10)";
                          } else if (myRank >= 11 && myRank <= 50) {
                            rankText = "🥉 Hạng $myRank (Top 50)";
                          } else if (myRank > 50) {
                            rankText = "Hạng $myRank";
                          } else {
                            rankText = "Chưa xếp hạng";
                          }
                        }
                        return _infoCard(
                          Icons.military_tech,
                          "Xếp hạng",
                          rankText,
                        );
                      },
                    ),

                    _infoCard(
                      Icons.workspace_premium,
                      "Tổng điểm",
                      "${widget.userPoints}",
                    ),

                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String joinDateText = "Đang tải...";
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          if (data['createdAt'] != null) {
                            DateTime date = (data['createdAt'] as Timestamp)
                                .toDate();
                            joinDateText =
                                "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                          }
                        }
                        return _infoCard(
                          Icons.calendar_month,
                          "Ngày gia nhập",
                          joinDateText,
                        );
                      },
                    ),

                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String currentClass = widget.selectedClass;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          currentClass =
                              snapshot.data!.get('class') ?? widget.selectedClass;
                        }
                        return _infoCard(Icons.school, "Lớp", currentClass);
                      },
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(icon, color: primaryColor),
          title: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}