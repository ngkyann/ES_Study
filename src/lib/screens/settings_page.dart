import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Đừng quên thêm cái này nhé
import 'package:esstudy/screens/login_page.dart'; // Thay đường dẫn này cho đúng với file của bạn

class SettingsPage extends StatelessWidget {
  final String userName;
  final String selectedClass;
  final String userId;
  final String email;
  const SettingsPage({
    super.key,
    required this.userName,
    required this.selectedClass,
    required this.userId,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Cài đặt",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            _buildSectionHeader("Thông tin cá nhân"),
            _buildInfoTile(Icons.person, "Họ và tên", userName),
            _buildInfoTile(Icons.school, "Lớp", selectedClass),
            _buildInfoTile(Icons.email, "Email", email),
            _buildPasswordTile(context),

            const SizedBox(height: 10),
            _buildSectionHeader("Cài đặt giao diện"),
            _buildThemeSelector(),
            _buildActionTile(Icons.language, "Ngôn ngữ", "Tiếng Việt"),

            const SizedBox(height: 10),
            _buildSectionHeader("Ứng dụng"),
            _buildActionTile(Icons.privacy_tip, "Chính sách bảo mật", ""),
            _buildActionTile(Icons.info, "Thông tin phiên bản", "v1.0.0"),

            const SizedBox(height: 30),
            _buildLogoutButton(context),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGET TIÊU ĐỀ MỤC ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // --- WIDGET HIỂN THỊ THÔNG TIN CƠ BẢN ---
  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  // --- WIDGET MẬT KHẨU (CÓ NÚT ĐẶT LẠI) ---
  Widget _buildPasswordTile(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.lock, color: primaryColor),
        title: const Text("Mật khẩu", style: TextStyle(fontSize: 15)),
        subtitle: const Text(
          "********",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        trailing: TextButton(
          onPressed: () {
            // Gọi hàm mở Dialog nhập mật khẩu mới
            _showChangePasswordDialog(context);
          },
          child: const Text(
            "Đổi mật khẩu",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // --- WIDGET CÁC NÚT BẤM (NGÔN NGỮ, CHÍNH SÁCH...) ---
  Widget _buildActionTile(IconData icon, String title, String trailingText) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: Icon(icon, color: Colors.black54),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trailingText,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
        onTap: () {},
      ),
    );
  }

  // --- WIDGET CHỌN MÀU CHỦ ĐỀ ---
  Widget _buildThemeSelector() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: const Icon(Icons.color_lens, color: Colors.black54),
        title: const Text("Màu sắc chủ đề", style: TextStyle(fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              _buildColorCircle(primaryColor, true),
              _buildColorCircle(Colors.green, false),
              _buildColorCircle(Colors.orange, false),
              _buildColorCircle(Colors.purple, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorCircle(Color color, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.black45, width: 2) : null,
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 18)
          : null,
    );
  }

  // --- WIDGET ĐĂNG XUẤT ---
  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.red, width: 1),
          ),
        ),
        onPressed: () => _showLogoutDialog(context),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout),
            SizedBox(width: 8),
            Text(
              "Đăng xuất",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // --- HỘP THOẠI XÁC NHẬN ĐĂNG XUẤT ---
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Xác nhận"),
        content: const Text("Bạn muốn đăng xuất?"),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Huỷ",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor, // 🔥 đổi từ đỏ sang màu chủ đề
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              try {
                if (!context.mounted) return;

                Navigator.pop(context);

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              } catch (e) {
                print("Lỗi đăng xuất: $e");
              }
            },
            child: const Text(
              "Đăng xuất",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool isLoading = false;
    bool showOld = false;
    bool showNew = false;
    bool showConfirm = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Đổi mật khẩu"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // MẬT KHẨU CŨ
                  TextField(
                    controller: oldPasswordController,
                    obscureText: !showOld,
                    decoration: InputDecoration(
                      labelText: "Mật khẩu cũ",
                      suffixIcon: IconButton(
                        icon: Icon(
                          showOld ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => showOld = !showOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // MẬT KHẨU MỚI
                  TextField(
                    controller: newPasswordController,
                    obscureText: !showNew,
                    decoration: InputDecoration(
                      labelText: "Mật khẩu mới",
                      suffixIcon: IconButton(
                        icon: Icon(
                          showNew ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => showNew = !showNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // XÁC NHẬN
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !showConfirm,
                    decoration: InputDecoration(
                      labelText: "Nhập lại mật khẩu",
                      suffixIcon: IconButton(
                        icon: Icon(
                          showConfirm ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => showConfirm = !showConfirm),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          String oldPass = oldPasswordController.text.trim();
                          String newPass = newPasswordController.text.trim();
                          String confirmPass = confirmPasswordController.text
                              .trim();

                          if (oldPass.isEmpty ||
                              newPass.isEmpty ||
                              confirmPass.isEmpty) {
                            _showSnackBar(context, "Nhập đầy đủ thông tin!");
                            return;
                          }

                          if (newPass.length < 6) {
                            _showSnackBar(
                              context,
                              "Mật khẩu tối thiểu 6 ký tự!",
                            );
                            return;
                          }

                          if (newPass != confirmPass) {
                            _showSnackBar(context, "Mật khẩu không khớp!");
                            return;
                          }

                          try {
                            setState(() => isLoading = true);

                            final userRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId);

                            final doc = await userRef.get();

                            if (!doc.exists) {
                              if (!context.mounted) return;
                              _showSnackBar(
                                context,
                                "Không tìm thấy tài khoản!",
                              );
                              return;
                            }

                            final data = doc.data() as Map<String, dynamic>;

                            final storedPassword = data['password']?.toString();

                            if (storedPassword == null ||
                                storedPassword.isEmpty) {
                              if (!context.mounted) return;
                              _showSnackBar(context, "Tài khoản lỗi!");
                              return;
                            }

                            if (storedPassword != oldPass) {
                              if (!context.mounted) return;
                              _showSnackBar(context, "Sai mật khẩu cũ!");
                              return;
                            }

                            // ✅ Update password
                            await userRef.update({'password': newPass});

                            if (!context.mounted) return;

                            Navigator.pop(context); // đóng dialog

                            // 🔥 delay nhỏ để tránh lỗi context
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Đổi mật khẩu thành công!"),
                                  ),
                                );
                              },
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            _showSnackBar(context, "Lỗi: $e");
                          } finally {
                            if (context.mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Xác nhận"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
