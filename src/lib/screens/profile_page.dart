import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:esstudy/constants/var.dart';

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
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";

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

      final bytes = await image.readAsBytes();
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      String downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'avatarUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isVN
                  ? "Đã đổi ảnh đại diện thành công!"
                  : "Avatar changed successfully!")),
        );
      }
    } catch (e) {
      debugPrint("Lỗi upload: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVN ? "Lỗi upload: $e" : "Upload error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveImageUrlToGallery(String? url) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVN
                ? "Bạn chưa có ảnh đại diện để tải về. Hãy đổi ảnh trước nhé!"
                : "You don't have an avatar to download. Please set one first!",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isVN
                ? "Đang chuẩn bị tải ảnh..."
                : "Preparing to download...")),
      );

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isVN
                  ? "Ảnh đang được tải xuống trình duyệt!"
                  : "Image is downloading in browser!")),
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/avatar_download.jpg';

        await Dio().download(url, path);

        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }

        await Gal.putImage(path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isVN
                  ? "Đã lưu ảnh thành công vào bộ sưu tập!"
                  : "Image saved to gallery successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải ảnh: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isVN
                  ? "Không thể tải ảnh: $e"
                  : "Cannot download image: $e")),
        );
      }
    }
  }

  void _showAvatarOptionsMenu(BuildContext context, String? currentAvatarUrl) {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  isVN ? "Tùy chọn ảnh đại diện" : "Avatar Options",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.blue),
                title: Text(isVN ? 'Lưu ảnh về máy' : 'Save to device'),
                onTap: () {
                  Navigator.of(context).pop();
                  _saveImageUrlToGallery(currentAvatarUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.orange),
                title: Text(isVN ? 'Đổi ảnh đại diện mới' : 'Change avatar'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUploadImage();
                },
              ),
              if (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(isVN
                      ? 'Xóa ảnh hiện tại (về mặc định)'
                      : 'Remove current avatar (default)'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      setState(() => _isUploading = true);
                      await FirebaseStorage.instance
                          .ref()
                          .child('avatars')
                          .child('${widget.userId}.jpg')
                          .delete();

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.userId)
                          .update({'avatarUrl': null});

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(isVN
                                  ? "Đã xóa ảnh đại diện."
                                  : "Avatar removed.")),
                        );
                      }
                    } catch (e) {
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
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isVN ? "Hồ sơ cá nhân" : "Profile",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            centerTitle: true,
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
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          currentName = data['name'] ?? widget.userName;
                          avatarUrl = data['avatarUrl'];
                        }

                        return Column(
                          children: [
                            GestureDetector(
                              onTap: () => _showAvatarOptionsMenu(
                                context,
                                avatarUrl,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: (avatarUrl != null &&
                                              avatarUrl.isNotEmpty)
                                          ? Image.network(
                                              avatarUrl,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                // Nếu gặp lỗi CORS trên Web, Image.network sẽ rớt vào đây và hiện Icon thay vì làm crash app
                                                return Icon(Icons.person,
                                                    color: primaryColor,
                                                    size: 50);
                                              },
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return const Center(
                                                    child:
                                                        CircularProgressIndicator());
                                              },
                                            )
                                          : Icon(Icons.person,
                                              color: primaryColor, size: 50),
                                    ),
                                  ),
                                  if (_isUploading)
                                    const Positioned.fill(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 16,
                                      ),
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
                                    isVN
                                        ? "Chuỗi ${widget.userStreak} ngày học"
                                        : "${widget.userStreak}-day streak",
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _infoCard(
                          Icons.alternate_email,
                          isVN ? "ID người dùng" : "User ID",
                          "@${widget.userId}",
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .orderBy('points', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            String rankText =
                                isVN ? "Đang tải..." : "Loading...";
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
                                rankText = isVN
                                    ? "🥇 Hạng 1 (Quán quân)"
                                    : "🥇 Rank 1 (Champion)";
                              } else if (myRank >= 2 && myRank <= 10) {
                                rankText = isVN
                                    ? "🥈 Hạng $myRank (Top 10)"
                                    : "🥈 Rank $myRank (Top 10)";
                              } else if (myRank >= 11 && myRank <= 50) {
                                rankText = isVN
                                    ? "🥉 Hạng $myRank (Top 50)"
                                    : "🥉 Rank $myRank (Top 50)";
                              } else if (myRank > 50) {
                                rankText =
                                    isVN ? "Hạng $myRank" : "Rank $myRank";
                              } else {
                                rankText = isVN ? "Chưa xếp hạng" : "Unranked";
                              }
                            }
                            return _infoCard(
                              Icons.military_tech,
                              isVN ? "Xếp hạng" : "Rank",
                              rankText,
                            );
                          },
                        ),
                        _infoCard(
                          Icons.workspace_premium,
                          isVN ? "Tổng điểm" : "Total Points",
                          "${widget.userPoints}",
                        ),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            String joinDateText =
                                isVN ? "Đang tải..." : "Loading...";
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              if (data['createdAt'] != null) {
                                DateTime date =
                                    (data['createdAt'] as Timestamp).toDate();
                                joinDateText =
                                    "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                              }
                            }
                            return _infoCard(
                              Icons.calendar_month,
                              isVN ? "Ngày gia nhập" : "Joined Date",
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
                              currentClass = snapshot.data!.get('class') ??
                                  widget.selectedClass;
                            }
                            String displayClass = isVN
                                ? currentClass
                                : currentClass.replaceFirst('Lớp', 'Class');
                            return _infoCard(Icons.school,
                                isVN ? "Lớp" : "Class", displayClass);
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
      },
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
