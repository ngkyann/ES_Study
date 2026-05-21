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
  final int userCoins;
  final int userStreak;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
    required this.email,
    required this.userPoints,
    required this.userCoins,
    required this.userStreak,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // State cho phần Bio
  bool _isEditingBio = false;
  bool _isSavingBio = false;
  final TextEditingController _bioController = TextEditingController();

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  // --- HÀM HỖ TRỢ: CHỌN VÀ UPLOAD ẢNH CÁ NHÂN (HỖ TRỢ AVATAR & BANNER) ---
  Future<void> _pickImage(ImageSource source, bool isBanner) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 75,
      );

      if (image == null) return;
      setState(() => _isUploading = true);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child(isBanner ? 'banners' : 'avatars')
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
          .update({isBanner ? 'bannerUrl' : 'avatarUrl': downloadUrl});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isVN
                ? "Đã cập nhật ảnh cá nhân thành công!"
                : "Personal image updated successfully!"),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Lỗi upload: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVN ? "Lỗi upload: $e" : "Upload error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- HÀM HỖ TRỢ: XÓA ẢNH (KHÔI PHỤC VỀ MẶC ĐỊNH) ---
  Future<void> _deleteImage(bool isBanner) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    try {
      setState(() => _isUploading = true);
      // Xóa trên Firebase Storage nếu tồn tại (Sẽ bỏ qua lỗi nếu là ảnh Shop)
      await FirebaseStorage.instance
          .ref()
          .child(isBanner ? 'banners' : 'avatars')
          .child('${widget.userId}.jpg')
          .delete();
    } catch (e) {
      // Bỏ qua lỗi nếu file không tồn tại trên Storage cá nhân
    }

    try {
      // Cập nhật lại Firestore bằng null để UI tự Reset về mặc định
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({isBanner ? 'bannerUrl' : 'avatarUrl': null});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isVN
                ? "Đã khôi phục ảnh về mặc định hệ thống."
                : "Image reset to system default.")),
      );
    } catch (e) {
      debugPrint("Lỗi xóa: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- HÀM HỖ TRỢ: TẢI ẢNH VỀ MÁY ---
  Future<void> _saveImageUrlToGallery(String? url, bool isBanner) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVN
                ? "Chưa có ${isBanner ? "ảnh nền" : "ảnh đại diện"} để tải về!"
                : "No ${isBanner ? "banner" : "avatar"} image to download!",
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isVN
                  ? "Ảnh đang được tải xuống trình duyệt!"
                  : "Image is downloading in browser!")),
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/${isBanner ? "banner" : "avatar"}_download.jpg';

        await Dio().download(url, path);

        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }

        await Gal.putImage(path);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVN
                ? "Đã lưu ảnh thành công vào bộ sưu tập!"
                : "Image saved to gallery successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi tải ảnh: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isVN ? "Không thể tải ảnh: $e" : "Cannot download image: $e")),
      );
    }
  }

  // --- MENU TÙY CHỌN ẢNH CHUNG (HỖ TRỢ ĐẦY ĐỦ CÁC CHỨC NĂNG) ---
  void _showImageOptionsMenu(BuildContext context, String? currentImageUrl,
      bool isBanner, List<String> ownedItems) {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  isVN
                      ? "Tùy chọn ${isBanner ? 'Ảnh nền' : 'Ảnh đại diện'}"
                      : "${isBanner ? 'Banner' : 'Avatar'} Options",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.blue),
                title: Text(isVN ? 'Lưu ảnh về máy' : 'Save to device'),
                onTap: () {
                  Navigator.pop(context);
                  _saveImageUrlToGallery(currentImageUrl, isBanner);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.orange),
                title: Text(isVN
                    ? 'Đổi ảnh cá nhân (Từ thư viện)'
                    : 'Change image (Gallery)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, isBanner);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: Text(isVN ? 'Chụp ảnh mới' : 'Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, isBanner);
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory, color: Colors.purple),
                title: Text(isVN
                    ? 'Kho ảnh hệ thống & Đã mua'
                    : 'System & Purchased items'),
                onTap: () {
                  Navigator.pop(context);
                  _showSystemImagesDialog(context, isBanner, ownedItems);
                },
              ),
              // Chỉ hiện nút Xóa nếu đang dùng ảnh (Không phải mặc định rỗng)
              if (currentImageUrl != null && currentImageUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(isVN
                      ? 'Xóa ảnh hiện tại (Về mặc định)'
                      : 'Remove current image (Default)'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteImage(isBanner);
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- HIỂN THỊ KHO ẢNH (MẶC ĐỊNH & ĐÃ MUA) ---
  void _showSystemImagesDialog(
      BuildContext context, bool isBanner, List<String> ownedItems) {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isVN
              ? (isBanner ? "Kho Nền của bạn" : "Kho Avatar của bạn")
              : (isBanner ? "Your Banners" : "Your Avatars")),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LUÔN HIỂN THỊ LỰA CHỌN ẢNH MẶC ĐỊNH Ở ĐẦU
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(isBanner ? Icons.wallpaper : Icons.person,
                      color: primaryColor),
                  title: Text(isVN
                      ? "Ảnh mặc định (Hệ thống)"
                      : "Default Image (System)"),
                  onTap: () {
                    _deleteImage(isBanner);
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                if (ownedItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      isVN
                          ? "Bạn chưa mua mục nào từ Cửa hàng!"
                          : "You haven't purchased any items from the Shop!",
                      style: const TextStyle(
                          color: Colors.grey, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isBanner ? 2 : 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isBanner ? 1.5 : 1,
                      ),
                      itemCount: ownedItems.length,
                      itemBuilder: (context, index) {
                        String url = ownedItems[index];
                        return GestureDetector(
                          onTap: () {
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userId)
                                .update({
                              isBanner ? 'bannerUrl' : 'avatarUrl': url,
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isVN
                                    ? "Đã áp dụng thành công!"
                                    : "Applied successfully!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
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

  // --- XỬ LÝ LƯU TIỂU SỬ BIO ---
  Future<void> _saveBio() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    setState(() => _isSavingBio = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'bio': _bioController.text.trim()});

      if (mounted) {
        setState(() {
          _isEditingBio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isVN ? "Đã cập nhật tiểu sử!" : "Bio updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVN ? "Lỗi cập nhật: $e" : "Update error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBio = false);
    }
  }

  // --- CÁC HÀM XỬ LÝ BẠN THÂN NỔI BẬT ---
  String _getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  Future<List<Map<String, dynamic>>> _getValidFeaturedFriends(
      List<dynamic> myFriends) async {
    List<Map<String, dynamic>> validFriends = [];

    for (String friendId in myFriends) {
      String chatId = _getChatId(widget.userId, friendId);
      var streakSnap = await FirebaseFirestore.instance
          .collection('friend_streaks')
          .doc(chatId)
          .get();

      if (streakSnap.exists) {
        var data = streakSnap.data() as Map<String, dynamic>;
        int streak = data['streak'] ?? 0;

        // 🔥 KIỂM TRA CHUỖI ĐÃ QUÁ HẠN CHƯA (NẾU NGHỈ QUÁ 1 NGÀY -> VỀ 0)
        Timestamp? lastTs = data['lastStudyDate'];
        if (lastTs != null) {
          DateTime now = DateTime.now();
          DateTime today = DateTime(now.year, now.month, now.day);
          DateTime lastDay = DateTime(
              lastTs.toDate().year, lastTs.toDate().month, lastTs.toDate().day);
          if (today.difference(lastDay).inDays > 1) {
            streak = 0;
          }
        }

        if (streak >= 3) {
          var userSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .get();
          if (userSnap.exists) {
            var userData = userSnap.data() as Map<String, dynamic>;
            validFriends.add({
              'id': friendId,
              'name': userData['name'] ?? 'Ẩn danh',
              'avatarUrl': userData['avatarUrl'],
              'streak': streak,
            });
          }
        }
      }
    }
    validFriends.sort((a, b) => b['streak'].compareTo(a['streak']));
    return validFriends;
  }

  void _showSelectFeaturedFriendDialog(
      List<dynamic> myFriends, String? currentFeaturedId, bool isVN) {
    String? localSelectedId = currentFeaturedId;

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      isVN ? "Chọn Bạn thân nổi bật" : "Select Featured Friend",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getValidFeaturedFriends(myFriends),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child: CircularProgressIndicator(
                                  color: primaryColor));
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              isVN
                                  ? "Chưa có bạn bè nào đạt chuỗi 3 ngày trở lên."
                                  : "No friends with a 3+ day streak yet.",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        final validFriends = snapshot.data!;
                        return ListView.builder(
                            itemCount: validFriends.length,
                            itemBuilder: (context, index) {
                              final friend = validFriends[index];
                              final bool isSelected =
                                  friend['id'] == localSelectedId;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: friend['avatarUrl'] != null
                                      ? NetworkImage(friend['avatarUrl'])
                                      : null,
                                  child: friend['avatarUrl'] == null
                                      ? const Icon(Icons.person,
                                          color: Colors.grey)
                                      : null,
                                ),
                                title: Text(friend['name'],
                                    style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.black87)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_fire_department,
                                        color: Colors.orange),
                                    Text("${friend['streak']}",
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 10),
                                    if (isSelected)
                                      const Icon(Icons.remove_circle,
                                          color: Colors.red, size: 24)
                                    else
                                      Icon(Icons.circle_outlined,
                                          color: Colors.grey.shade400,
                                          size: 22),
                                  ],
                                ),
                                onTap: () async {
                                  if (isSelected) {
                                    setModalState(() => localSelectedId = null);
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.userId)
                                        .update({
                                      'featuredFriendId': FieldValue.delete()
                                    });

                                    if (context.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(isVN
                                                  ? "Đã gỡ bạn thân nổi bật!"
                                                  : "Featured friend removed!")));
                                    }
                                  } else {
                                    setModalState(
                                        () => localSelectedId = friend['id']);
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.userId)
                                        .update(
                                            {'featuredFriendId': friend['id']});

                                    if (context.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(isVN
                                                  ? "Đã cài đặt bạn thân nổi bật!"
                                                  : "Featured friend set!")));
                                    }
                                  }
                                },
                              );
                            });
                      }),
                ),
              ],
            );
          });
        });
  }

  // --- WIDGET BIO ---
  Widget _buildBioSection(bool isVN, String bio) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      isVN ? "Tiểu sử" : "Bio",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                if (!_isEditingBio)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditingBio = true;
                        _bioController.text = bio;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(isVN ? "Chỉnh sửa" : "Edit"),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isEditingBio)
              Text(
                bio.isNotEmpty
                    ? bio
                    : (isVN ? "Chưa có tiểu sử." : "No bio yet."),
                style: TextStyle(
                  color: bio.isNotEmpty ? Colors.black87 : Colors.grey,
                  fontSize: 14,
                  fontStyle:
                      bio.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                ),
              )
            else ...[
              TextField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 150,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      isVN ? "Nhập tiểu sử của bạn..." : "Enter your bio...",
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditingBio = false;
                      });
                    },
                    child: Text(
                      isVN ? "Hủy" : "Cancel",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSavingBio ? null : _saveBio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _isSavingBio
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isVN ? "Lưu" : "Save"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- WIDGET THÔNG TIN INFO ---
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              isVN ? "Hồ sơ cá nhân" : "Profile",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor.withOpacity(0),
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
          body: RefreshIndicator(
            color: primaryColor,
            backgroundColor: Colors.white,
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) setState(() {});
            },
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                String currentName = widget.userName;
                String? avatarUrl;
                String? bannerUrl;
                String bio = "";
                String currentClass = widget.selectedClass;
                int currentPoints = widget.userPoints;
                int currentStreak = widget.userStreak;
                String joinDateText = isVN ? "Đang tải..." : "Loading...";
                List<dynamic> myFriends = [];
                String? featuredId = widget.userId;

                List<String> ownedAvatars = [];
                List<String> ownedBanners = [];

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final data =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    currentName = data['name']?.toString() ?? widget.userName;
                    avatarUrl = data['avatarUrl']?.toString();
                    bannerUrl = data['bannerUrl']?.toString();
                    bio = data['bio']?.toString() ?? "";
                    currentClass =
                        data['class']?.toString() ?? widget.selectedClass;
                    currentPoints = data['points'] ?? widget.userPoints;
                    currentStreak = data['streak'] ?? widget.userStreak;
                    myFriends = data['friends'] ?? [];
                    featuredId = data['featuredFriendId'];

                    ownedAvatars =
                        List<String>.from(data['ownedAvatars'] ?? []);
                    ownedBanners =
                        List<String>.from(data['ownedBanners'] ?? []);

                    if (data['createdAt'] != null) {
                      DateTime date = (data['createdAt'] as Timestamp).toDate();
                      joinDateText =
                          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                    }
                  }
                }

                String displayClass = isVN
                    ? currentClass
                    : currentClass.replaceFirst('Lớp', 'Class');

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // KHUNG BAO CHO AVATAR VÀ ẢNH NỀN
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showImageOptionsMenu(
                          context,
                          bannerUrl,
                          true, // isBanner = true
                          ownedBanners,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top +
                                kToolbarHeight +
                                -30,
                            bottom: 30,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor, // Nền mặc định
                            image: (bannerUrl != null && bannerUrl.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(bannerUrl),
                                    fit: BoxFit.cover,
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withOpacity(0.35),
                                      BlendMode.darken,
                                    ),
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // NÚT CHỌN AVATAR
                              GestureDetector(
                                onTap: () => _showImageOptionsMenu(
                                  context,
                                  avatarUrl,
                                  false, // isBanner = false
                                  ownedAvatars,
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
                                            color:
                                                Colors.black.withOpacity(0.2),
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
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Icon(Icons.person,
                                                      color: primaryColor,
                                                      size: 50);
                                                },
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
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
                                    color: Colors.white),
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
                                  color: (bannerUrl != null &&
                                          bannerUrl.isNotEmpty)
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.2),
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
                                          ? "Chuỗi $currentStreak ngày học"
                                          : "$currentStreak-day streak",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // KHỐI TIỂU SỬ
                            _buildBioSection(isVN, bio),

                            // KHỐI BẠN THÂN HỌC TẬP
                            Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(
                                      color: Colors.orange.shade200)),
                              color: Colors.orange.shade50,
                              child: ListTile(
                                onTap: () => _showSelectFeaturedFriendDialog(
                                    myFriends, featuredId, isVN),
                                leading: const Icon(Icons.favorite,
                                    color: Colors.redAccent),
                                title: Text(
                                    isVN ? "Bạn thân học tập" : "Study Bestie",
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                                subtitle: featuredId == null
                                    ? Text(
                                        isVN
                                            ? "Chạm để chọn..."
                                            : "Tap to select...",
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontStyle: FontStyle.italic))
                                    : FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(featuredId)
                                            .get(),
                                        builder: (context, fSnap) {
                                          if (!fSnap.hasData)
                                            return const Text("...");
                                          String fName =
                                              fSnap.data!.get('name');
                                          return FutureBuilder<
                                                  DocumentSnapshot>(
                                              future: FirebaseFirestore.instance
                                                  .collection('friend_streaks')
                                                  .doc(_getChatId(widget.userId,
                                                      featuredId!))
                                                  .get(),
                                              builder: (context, sSnap) {
                                                if (!sSnap.hasData)
                                                  return const Text("...");

                                                int streak = 0;
                                                if (sSnap.data!.exists) {
                                                  var data = sSnap.data!.data()
                                                      as Map<String, dynamic>;
                                                  streak = data['streak'] ?? 0;

                                                  // 🔥 TỰ ĐỘNG TÍNH TOÁN LẠI CHUỖI THỰC TẾ TRÊN GIAO DIỆN
                                                  Timestamp? lastTs =
                                                      data['lastStudyDate'];
                                                  if (lastTs != null) {
                                                    DateTime now =
                                                        DateTime.now();
                                                    DateTime today = DateTime(
                                                        now.year,
                                                        now.month,
                                                        now.day);
                                                    DateTime lastDay = DateTime(
                                                        lastTs.toDate().year,
                                                        lastTs.toDate().month,
                                                        lastTs.toDate().day);
                                                    if (today
                                                            .difference(lastDay)
                                                            .inDays >
                                                        1) {
                                                      streak =
                                                          0; // Bị mất chuỗi do nghỉ học
                                                    }
                                                  }
                                                }

                                                // 🔥 NẾU CHUỖI DƯỚI 3, LẬP TỨC TỰ ĐỘNG GỠ BỎ KHỎI TÀI KHOẢN
                                                if (streak < 3) {
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback(
                                                          (_) {
                                                    FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(widget.userId)
                                                        .update({
                                                      'featuredFriendId':
                                                          FieldValue.delete()
                                                    });
                                                  });
                                                  return Text(
                                                    isVN
                                                        ? "Đã mất chuỗi, đang gỡ..."
                                                        : "Streak lost, removing...",
                                                    style: const TextStyle(
                                                        color: Colors.red,
                                                        fontStyle:
                                                            FontStyle.italic),
                                                  );
                                                }

                                                return Row(
                                                  children: [
                                                    Text(fName,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                            color: Colors
                                                                .black87)),
                                                    const SizedBox(width: 8),
                                                    const Icon(
                                                        Icons
                                                            .local_fire_department,
                                                        color: Colors.orange,
                                                        size: 20),
                                                    Text("$streak",
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.orange,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16)),
                                                  ],
                                                );
                                              });
                                        }),
                                trailing: const Icon(Icons.edit,
                                    size: 16, color: Colors.grey),
                              ),
                            ),

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
                                    rankText =
                                        isVN ? "Chưa xếp hạng" : "Unranked";
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
                              "$currentPoints",
                            ),
                            _infoCard(
                              Icons.calendar_month,
                              isVN ? "Ngày gia nhập" : "Joined Date",
                              joinDateText,
                            ),
                            _infoCard(Icons.school, isVN ? "Lớp" : "Class",
                                displayClass),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
