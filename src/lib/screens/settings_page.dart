import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/screens/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        // 🔥 1. BỌC BẰNG REFRESH INDICATOR
        child: RefreshIndicator(
          color: primaryColor,
          backgroundColor: Colors.white,
          onRefresh: () async {
            // Giả lập load 1 giây để hiện vòng xoay cho mượt
            await Future.delayed(const Duration(seconds: 1));
          },
          // 🔥 2. BÊN TRONG LÀ LISTVIEW CŨ CỦA BẠN
          child: ListView(
            // 🔥 3. BẮT BUỘC: Thêm physics này để nội dung ngắn vẫn vuốt được
            physics: const AlwaysScrollableScrollPhysics(),
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
              _buildActionTile(
                Icons.info,
                "Thông tin phiên bản",
                "Beta 1.0",
                onTap: () => _showVersionInfoDialog(context),
              ),
              const SizedBox(height: 30),
              _buildLogoutButton(context),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---
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
          onPressed: () => _showChangePasswordDialog(context),
          child: const Text(
            "Đổi mật khẩu",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // 🔥 ĐÃ SỬA: Cấp thêm tham số onTap để Widget này bấm được
  Widget _buildActionTile(
    IconData icon,
    String title,
    String trailingText, {
    VoidCallback? onTap,
  }) {
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
        onTap: onTap, // Gắn hành động vào đây
      ),
    );
  }

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

  // --- HỘP THOẠI THÔNG TIN PHIÊN BẢN (MỚI THÊM) ---
  void _showVersionInfoDialog(BuildContext context) {
    // Lấy ngày tháng năm hiện tại
    final DateTime now = DateTime.now();
    final String todayStr =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: const [
              Icon(Icons.info_outline, color: primaryColor, size: 28),
              SizedBox(width: 10),
              Text("Thông tin ứng dụng"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Phiên bản: Beta 1.0",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Cập nhật lần cuối: $todayStr",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),
              const SizedBox(height: 15),
              const Text(
                "Sản phẩm được phát triển nhằm mang lại trải nghiệm học tập tốt nhất cho người dùng.",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Đóng"),
            ),
          ],
        );
      },
    );
  }

  // --- HỘP THOẠI ĐĂNG XUẤT ---
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Xác nhận"),
        content: const Text("Bạn muốn đăng xuất?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Huỷ"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
              FirebaseAuth.instance.signOut();
            },
            child: const Text("Đăng xuất"),
          ),
        ],
      ),
    );
  }

  // --- ĐỔI MẬT KHẨU (ĐÃ CÓ NÚT ẨN/HIỆN MẬT KHẨU HOÀN HẢO) ---
  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    // Khai báo các biến trạng thái ẩn/hiện cho từng ô
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text("Đổi mật khẩu"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      decoration: InputDecoration(
                        labelText: "Mật khẩu cũ",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureOld
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureOld = !obscureOld;
                            });
                          },
                        ),
                      ),
                    ),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: "Mật khẩu mới",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                      ),
                    ),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: "Xác nhận mật khẩu",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          String oldP = oldPasswordController.text.trim();
                          String newP = newPasswordController.text.trim();
                          String confirmP = confirmPasswordController.text
                              .trim();

                          if (oldP.isEmpty ||
                              newP.isEmpty ||
                              confirmP.isEmpty) {
                            _showSnackBar(
                              context,
                              "Vui lòng nhập đủ thông tin!",
                            );
                            return;
                          }

                          if (newP != confirmP) {
                            _showSnackBar(
                              context,
                              "Mật khẩu xác nhận không khớp!",
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            User? user = FirebaseAuth.instance.currentUser;
                            if (user != null && user.email != null) {
                              AuthCredential credential =
                                  EmailAuthProvider.credential(
                                    email: user.email!,
                                    password: oldP,
                                  );
                              await user.reauthenticateWithCredential(
                                credential,
                              );

                              await user.updatePassword(newP);

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!context.mounted) return;
                              _showSnackBar(
                                context,
                                "Đổi mật khẩu thành công!",
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            String msg = "Lỗi: ${e.message}";
                            if (e.code == 'wrong-password' ||
                                e.code == 'invalid-credential') {
                              msg = "Mật khẩu cũ không đúng!";
                            }
                            if (!context.mounted) return;
                            _showSnackBar(context, msg);
                          } finally {
                            if (stateContext.mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
